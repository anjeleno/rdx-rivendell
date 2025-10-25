#!/usr/bin/env bash
set -euo pipefail

# Unified release helper for RDX Broadcast Control Center
# - Bumps version (or uses provided), updates sources, builds .deb
# - Commits, tags, pushes, and publishes GitHub Release with attached asset
#
# Usage examples:
#   scripts/release-rdx.sh --bump patch --yes --from-changelog
#   scripts/release-rdx.sh --version 3.4.15 --yes --from-changelog
#   scripts/release-rdx.sh --bump minor --dry-run
#
# Flags:
#   --version X.Y.Z         Explicit version to release
#   --bump patch|minor|major  Derive next version from latest v* tag
#   --from-changelog        Use CHANGELOG.md section for release notes
#   --prepare-changelog     If missing, insert a templated section for this version/date at top
#   --yes                   Non-interactive (assume Yes). NOTE: default is dry-run unless --yes is passed.
#   --dry-run               Print what would happen, do not modify repo or push (default)
#   --no-publish            Skip creating GitHub Release
#   --no-push               Skip pushing branch/tag
#   --allow-dirty           Allow non-clean working tree (not recommended)
#
# Requirements: git, gh (if publishing), python3, debuild tools (dpkg-deb), existing scripts

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO_ROOT"

VERSION=""
BUMP=""
FROM_CHANGELOG=false
PREPARE_CHANGELOG=false
ASSUME_YES=false
# Default to dry-run unless --yes is provided
DRY_RUN=true
DO_PUBLISH=true
DO_PUSH=true
ALLOW_DIRTY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION=${2:-}; shift 2;;
    --bump) BUMP=${2:-}; shift 2;;
  --from-changelog) FROM_CHANGELOG=true; shift;;
  --prepare-changelog) PREPARE_CHANGELOG=true; shift;;
    --yes|-y) ASSUME_YES=true; shift;;
    --dry-run) DRY_RUN=true; shift;;
    --no-publish) DO_PUBLISH=false; shift;;
    --no-push) DO_PUSH=false; shift;;
    --allow-dirty) ALLOW_DIRTY=true; shift;;
    -h|--help)
      sed -n '1,80p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

say() { echo -e "$*"; }
run() {
  say "> $*"
  if ! $DRY_RUN; then
    eval "$@"
  fi
}

# If user explicitly passed --yes, disable dry-run
if $ASSUME_YES; then
  DRY_RUN=false
fi

require_clean_tree() {
  if $ALLOW_DIRTY; then return 0; fi
  if [[ -n $(git status --porcelain) ]]; then
    if $DRY_RUN; then
      echo "[dry-run] Working tree is not clean; proceeding due to dry-run. Current status:" >&2
      git status --porcelain
      return 0
    fi
    echo "Working tree not clean. Stash/commit changes or pass --allow-dirty." >&2
    git status --porcelain
    exit 1
  fi
}

current_branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$current_branch" != "main" ]]; then
  echo "Not on main (current: $current_branch). Switch to main before releasing." >&2
  exit 1
fi

# Determine version
latest_tag=$(git tag --list 'v*' --sort=-creatordate | head -n1 || true)
latest_ver=${latest_tag#v}

if [[ -z "$VERSION" ]]; then
  if [[ -z "$BUMP" ]]; then
    echo "Specify --version X.Y.Z or --bump patch|minor|major" >&2
    exit 2
  fi
  if [[ -z "$latest_ver" ]]; then
    echo "No existing v* tags found to bump from. Use --version." >&2
    exit 2
  fi
  IFS='.' read -r MA MI PA <<<"$latest_ver"
  case "$BUMP" in
    patch) ((PA+=1));;
    minor) ((MI+=1)); PA=0;;
    major) ((MA+=1)); MI=0; PA=0;;
    *) echo "Unknown bump: $BUMP" >&2; exit 2;;
  esac
  VERSION="$MA.$MI.$PA"
fi

TAG="v$VERSION"

say "Preparing release $TAG"

# If tag already exists, abort early
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "Tag $TAG already exists. Aborting." >&2
  exit 1
fi

# Ensure upstream is reachable (optional)
origin_url=$(git remote get-url origin)
say "Remote: $origin_url"

require_clean_tree

# Update versions in files
PY_FILE="src/rdx-broadcast-control-center.py"
BUILD_SCRIPT="scripts/build-rdx-broadcast-center.sh"
CHANGELOG="CHANGELOG.md"

if [[ ! -f "$PY_FILE" || ! -f "$BUILD_SCRIPT" ]]; then
  echo "Expected files not found. Are you at the repo root?" >&2
  exit 1
fi

say "Updating versions to $VERSION in tracked files"
run python3 - "$VERSION" <<'PY'
import re, sys, pathlib
ver = sys.argv[1]
root = pathlib.Path('.')

pyf = root / 'src' / 'rdx-broadcast-control-center.py'
s = pyf.read_text(encoding='utf-8')
# Replace occurrences of the app version in common spots
s_new = re.sub(r'(?<=Broadcast Control Center v)\d+\.\d+\.\d+', ver, s)
pyf.write_text(s_new, encoding='utf-8')

bs = root / 'scripts' / 'build-rdx-broadcast-center.sh'
t = bs.read_text(encoding='utf-8')
t_new = re.sub(r'^(PACKAGE_VERSION=")\d+\.\d+\.\d+("\s*)$', fr'\g<1>{ver}\2', t, flags=re.M)
bs.write_text(t_new, encoding='utf-8')
PY

# Optionally prepare a changelog section
if $PREPARE_CHANGELOG; then
  if grep -qE "^## v${VERSION} \(" "$CHANGELOG"; then
    say "CHANGELOG already has v${VERSION}; not inserting template."
  else
    say "Preparing CHANGELOG section for v${VERSION}"
    run bash -c '
      set -e
      tmp=$(mktemp)
      today=$(date +%F)
      {
        echo "## v'"${VERSION}"' (${today})"
        echo "### UI"
        echo "- "
        echo ""
        echo "### Fixed"
        echo "- "
        echo ""
        echo "### Packaging"
        echo "- Bumped package to '"${VERSION}"' and rebuilt \`.deb\`."
        echo ""
      } > "$tmp"
      cat "$CHANGELOG" >> "$tmp"
      mv "$tmp" "$CHANGELOG"
    '
  fi
fi

# Verify CHANGELOG section if using --from-changelog
if $FROM_CHANGELOG; then
  if ! grep -qE "^## v${VERSION} \(" "$CHANGELOG"; then
    echo "CHANGELOG.md has no section for v$VERSION. Add it (use --prepare-changelog) or omit --from-changelog." >&2
    exit 1
  fi
fi

say "Building Debian package for $VERSION"
run bash "$BUILD_SCRIPT"

ASSET="releases/rdx-broadcast-control-center_${VERSION}_amd64.deb"
if [[ ! -f "$ASSET" ]]; then
  echo "Expected asset not found at $ASSET" >&2
  exit 1
fi

say "Staging and committing release changes"
run git add -u

# Compose commit message (include changelog section when available)
COMMIT_MSG_FILE=$(mktemp)
echo "Release ${TAG}" > "$COMMIT_MSG_FILE"
if $FROM_CHANGELOG && [[ -f "$CHANGELOG" ]]; then
  echo -e "\n" >> "$COMMIT_MSG_FILE"
  python3 scripts/extract-changelog-section.py "$TAG" "$CHANGELOG" >> "$COMMIT_MSG_FILE" || true
fi
run git commit -F "$COMMIT_MSG_FILE"
rm -f "$COMMIT_MSG_FILE"

say "Tagging ${TAG}"
run git tag -a "$TAG" -m "RDX Broadcast Control Center ${TAG}"

if $DO_PUSH; then
  say "Pushing main and ${TAG}"
  run git push origin main
  run git push origin "$TAG"
fi

if $DO_PUBLISH; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI not found; cannot publish release. Install gh or pass --no-publish." >&2
    exit 1
  fi
  say "Publishing GitHub Release ${TAG}"
  if $FROM_CHANGELOG; then
    run bash scripts/publish-rdx-release.sh "$TAG" --from-changelog
  else
    run bash scripts/publish-rdx-release.sh "$TAG"
  fi
fi

say "Done. ${TAG} released."
