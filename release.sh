#!/bin/bash
set -e

# ============================================================
# VibeOS Release Script — Local release preparation
# ============================================================
# Usage:
#   ./release.sh                    # Auto-version (YYYY.MM.N)
#   ./release.sh 2026.03.1          # Explicit version
#   ./release.sh 2026.03.1 --tag    # Also create git tag
# ============================================================

VERSION="${1:-$(date +%Y.%m).1}"
CREATE_TAG=false

for arg in "$@"; do
    [ "$arg" = "--tag" ] && CREATE_TAG=true
done

echo "============================================"
echo "  VibeOS Release v${VERSION}"
echo "============================================"

# ---------------------------------------------------------
# Step 1: Verify ISOs exist
# ---------------------------------------------------------
ISOS=()
for ISO in VibeOS-x86_64.iso VibeOS-aarch64.iso; do
    if [ -f "$ISO" ]; then
        ISOS+=("$ISO")
        echo "✓ Found: $ISO ($(ls -lh "$ISO" | awk '{print $5}'))"
    else
        echo "⚠ Missing: $ISO"
    fi
done

if [ ${#ISOS[@]} -eq 0 ]; then
    echo "ERROR: No ISOs found. Run ./build.sh first."
    exit 1
fi

# ---------------------------------------------------------
# Step 2: Generate checksums
# ---------------------------------------------------------
echo ""
echo "=== Generating checksums ==="
for ISO in "${ISOS[@]}"; do
    shasum -a 256 "$ISO" > "${ISO}.sha256"
    echo "✓ ${ISO}.sha256"
done

# ---------------------------------------------------------
# Step 3: Generate build metadata
# ---------------------------------------------------------
echo ""
echo "=== Generating build metadata ==="
for ISO in "${ISOS[@]}"; do
    ARCH=$(echo "$ISO" | sed 's/VibeOS-\(.*\)\.iso/\1/')
    cat > "VibeOS-${ARCH}-build.json" << METADATA
{
  "name": "VibeOS",
  "version": "${VERSION}",
  "arch": "${ARCH}",
  "build_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
  "iso_size": $(stat -f%z "$ISO" 2>/dev/null || stat -c%s "$ISO" 2>/dev/null || echo 0),
  "sha256": "$(awk '{print $1}' "${ISO}.sha256")"
}
METADATA
    echo "✓ VibeOS-${ARCH}-build.json"
done

# ---------------------------------------------------------
# Step 4: Create git tag (if requested)
# ---------------------------------------------------------
if [ "$CREATE_TAG" = true ]; then
    echo ""
    echo "=== Creating git tag ==="
    git tag -a "v${VERSION}" -m "VibeOS v${VERSION}"
    echo "✓ Tagged: v${VERSION}"
    echo "  Push with: git push origin v${VERSION}"
fi

# ---------------------------------------------------------
# Summary
# ---------------------------------------------------------
echo ""
echo "=== Release v${VERSION} prepared ==="
echo ""
echo "Artifacts:"
for ISO in "${ISOS[@]}"; do
    ARCH=$(echo "$ISO" | sed 's/VibeOS-\(.*\)\.iso/\1/')
    echo "  $ISO"
    echo "  ${ISO}.sha256"
    echo "  VibeOS-${ARCH}-build.json"
done
echo ""
if [ "$CREATE_TAG" = true ]; then
    echo "To release on GitHub:"
    echo "  git push origin v${VERSION}"
    echo "  (GitHub Actions will create the release automatically)"
else
    echo "To create a git tag:"
    echo "  ./release.sh ${VERSION} --tag"
fi
