#!/bin/bash
set -euo pipefail

# ============================================================
# VibeOS OSTree Backend — Compose atomic OS commits
# ============================================================
# This builds an OSTree commit from the treefile, then optionally
# generates an ISO installer image from that commit.
#
# Requirements:
#   - rpm-ostree (for compose)
#   - ostree (for repo management)
#   - lorax (for ISO generation from OSTree)
#
# Usage:
#   ./ostree/build-ostree.sh [--iso]
# ============================================================

TREEFILE="$(dirname "$0")/vibeos.yaml"
REPO="$(pwd)/ostree-repo"
CACHE="$(pwd)/ostree-cache"
GENERATE_ISO=false

for arg in "$@"; do
    case $arg in
        --iso) GENERATE_ISO=true ;;
    esac
done

echo "============================================"
echo "  VibeOS OSTree Build"
echo "  Treefile: $TREEFILE"
echo "  Repo:     $REPO"
echo "============================================"

# ---------------------------------------------------------
# Step 1: Initialize the OSTree repository
# ---------------------------------------------------------
if [ ! -d "$REPO" ]; then
    echo "=== Initializing OSTree repository ==="
    mkdir -p "$REPO"
    ostree --repo="$REPO" init --mode=archive
    echo "✓ Repository created at $REPO"
fi

mkdir -p "$CACHE"

# ---------------------------------------------------------
# Step 2: Compose the OSTree commit
# ---------------------------------------------------------
echo "=== Composing OSTree commit ==="
rpm-ostree compose tree \
    --repo="$REPO" \
    --cachedir="$CACHE" \
    "$TREEFILE"

# Get the latest commit
REF=$(grep '^ref:' "$TREEFILE" | awk '{print $2}')
COMMIT=$(ostree --repo="$REPO" rev-parse "$REF" 2>/dev/null || echo "unknown")
echo "✓ Commit: $COMMIT"
echo "✓ Ref: $REF"

# ---------------------------------------------------------
# Step 3: Generate summary
# ---------------------------------------------------------
echo "=== Generating repository summary ==="
ostree --repo="$REPO" summary -u
echo "✓ Summary updated"

# ---------------------------------------------------------
# Step 4: Optionally generate ISO installer
# ---------------------------------------------------------
if [ "$GENERATE_ISO" = true ]; then
    echo "=== Generating ISO from OSTree commit ==="
    ISO_DIR="$(pwd)/ostree-iso"
    ISO_NAME="VibeOS-Atomic-$(uname -m).iso"

    mkdir -p "$ISO_DIR"

    lorax --product="VibeOS" \
        --version="40" \
        --release="40" \
        --source="$REPO" \
        --variant="Atomic" \
        --nomacboot \
        --resultdir="$ISO_DIR" \
        --ostree-ref="$REF" \
        --ostree-repo="$REPO" \
        || echo "WARNING: lorax ISO generation may require additional setup"

    if [ -f "$ISO_DIR"/*.iso ]; then
        mv "$ISO_DIR"/*.iso "$(pwd)/$ISO_NAME"
        echo "✓ ISO: $(pwd)/$ISO_NAME ($(ls -lh "$(pwd)/$ISO_NAME" | awk '{print $5}'))"
    fi
fi

# ---------------------------------------------------------
# Summary
# ---------------------------------------------------------
echo ""
echo "=== OSTree build complete ==="
echo "  Repository: $REPO"
echo "  Ref:        $REF"
echo "  Commit:     $COMMIT"
echo ""
echo "To serve this repo for updates:"
echo "  python3 -m http.server -d $REPO 8080"
echo ""
echo "To install on a client machine:"
echo "  ostree remote add vibeos http://<server>:8080"
echo "  rpm-ostree rebase vibeos:$REF"
echo ""
