#!/usr/bin/env bash
# Build a clean release zip of Portly.app for distribution.
# Output: release/Portly-<version>.zip
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-0.1.0}"
OUT_DIR="release"
ZIP="$OUT_DIR/Portly-${VERSION}.zip"

echo "→ Building release artifact for v$VERSION"

./scripts/build.sh

mkdir -p "$OUT_DIR"
rm -f "$ZIP"

# Use ditto so xattrs and signature stay intact.
ditto -c -k --sequesterRsrc --keepParent build/Portly.app "$ZIP"

SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
SIZE=$(du -h "$ZIP" | awk '{print $1}')

echo
echo "✓ $ZIP ($SIZE)"
echo "  sha256: $SHA"
echo
echo "Next steps:"
echo "  gh release create v$VERSION $ZIP --title \"Portly v$VERSION\" --notes-file CHANGELOG.md"
