#!/usr/bin/env python3
import argparse
import difflib
import re
import sys
from pathlib import Path

def normalize(code: str, path_hint: str = "<source>") -> str:
    lines = code.splitlines()
    out = []
    cls_stack = []
    in_method = False
    method_indent = None
    target_classes = {
        'RDXBroadcastControlCenter',
        'JackMatrixTab',
        'StereoToolManagerTab',
        'ServiceControlTab',
        'SettingsTab'
    }

    def current_class():
        return cls_stack[-1] if cls_stack else None

    for i, line in enumerate(lines):
        stripped = line.lstrip(' ')
        lead = len(line) - len(stripped)

        m_cls = re.match(r'^class\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(', line)
        if m_cls:
            cls_stack.append(m_cls.group(1))
            in_method = False
            method_indent = None
            out.append(line)
            continue
        if current_class() and line.startswith('class '):
            # Close previous implicitly, start new
            m2 = re.match(r'^class\s+([A-Za-z_][A-Za-z0-9_]*)', line)
            if m2:
                cls_stack = [m2.group(1)]
            in_method = False
            method_indent = None
            out.append(line)
            continue

        if current_class() in target_classes and re.match(r'^\s*def\s+[A-Za-z_][A-Za-z0-9_]*\s*\(', line):
            in_method = True
            method_indent = lead
            out.append(line)
            continue

        if in_method and lead <= (method_indent or 0) and stripped and not stripped.startswith('#') and not stripped.startswith('def '):
            in_method = False
            method_indent = None

        if in_method and current_class() in target_classes:
            desired = (method_indent or 0) + 4
            if stripped and not stripped.startswith(('def ', 'class ')):
                if lead < desired:
                    line = ' ' * desired + stripped

        out.append(line)

    fixed = '\n'.join(out)
    # Specific guard for statusBar line that has regressed before
    fixed = re.sub(r'(?m)^(\s{0,4})(self\.statusBar\(\)\.showMessage\(.*\))$', r'        \2', fixed)
    return fixed


def try_compile(code: str, filename: str) -> bool:
    try:
        compile(code, filename, 'exec')
        return True
    except Exception as e:
        print(f"Compile check failed: {e}", file=sys.stderr)
        return False


def main():
    ap = argparse.ArgumentParser(description="Normalize indentation in the RDX app source (opt-in fixer)")
    ap.add_argument('--file', '-f', default='src/rdx-broadcast-control-center.py', help='Path to the app source file')
    ap.add_argument('--write', action='store_true', help='Write changes to file (default: dry-run)')
    ap.add_argument('--backup', action='store_true', help='Create a .bak backup when writing')
    ap.add_argument('--quiet', action='store_true', help='Suppress non-essential output')
    args = ap.parse_args()

    p = Path(args.file)
    src = p.read_text(encoding='utf-8')

    fixed = normalize(src, str(p))
    if fixed == src:
        if not args.quiet:
            print("No indentation changes needed.")
        # still run a compile to confirm
        ok = try_compile(src, str(p))
        sys.exit(0 if ok else 1)

    if not args.write:
        # Dry-run: show a unified diff
        diff = difflib.unified_diff(src.splitlines(), fixed.splitlines(), fromfile=str(p), tofile=str(p)+" (normalized)", lineterm='')
        print('\n'.join(diff))
        ok = try_compile(fixed, str(p))
        sys.exit(0 if ok else 1)

    # Write mode
    if args.backup:
        bak = p.with_suffix(p.suffix + '.bak')
        bak.write_text(src, encoding='utf-8')
        if not args.quiet:
            print(f"Backup written: {bak}")
    p.write_text(fixed, encoding='utf-8')
    if not args.quiet:
        print(f"Normalized and wrote: {p}")
    ok = try_compile(fixed, str(p))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
