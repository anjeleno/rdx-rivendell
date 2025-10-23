#!/usr/bin/env python3
import sys
import re
from pathlib import Path

def extract_section(changelog_path: Path, tag: str) -> str:
    ver = tag.lstrip('v')
    text = changelog_path.read_text(encoding='utf-8')
    # Match headings like '## v3.3.1 (date)'
    pattern = re.compile(rf"^##\s+v{re.escape(ver)}\b.*$", re.MULTILINE)
    m = pattern.search(text)
    if not m:
        raise SystemExit(f"Version {tag} not found in {changelog_path}")
    start = m.start()
    # Find next heading starting at beginning of a line
    next_m = re.search(r"^##\s+v[0-9].*$", text[m.end():], re.MULTILINE)
    if next_m:
        end = m.end() + next_m.start()
    else:
        end = len(text)
    section = text[start:end].strip() + "\n"
    return section

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: extract-changelog-section.py vX.Y.Z [CHANGELOG.md]", file=sys.stderr)
        sys.exit(2)
    tag = sys.argv[1]
    path = Path(sys.argv[2]) if len(sys.argv) > 2 else Path('CHANGELOG.md')
    print(extract_section(path, tag))
