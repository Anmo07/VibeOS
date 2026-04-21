#!/bin/bash
set -e

# ============================================================
# VibeOS ISO Build Script — Modular Architecture with Profiles
# ============================================================
# Usage:
#   ./build.sh                                  # Both arches, full profile
#   ./build.sh --arch=x86_64                    # Single arch, full profile
#   ./build.sh --arch=aarch64 --profile=minimal # ARM64, minimal profile
#   ./build.sh --profile=dev                    # Both arches, dev profile
#   ./build.sh --backend=osbuild --profile=full # Use OSBuild backend
# ============================================================

# Defaults
ARCH="both"
PROFILE="full"      # full | minimal | dev
BACKEND="kickstart"  # kickstart | osbuild
KS_DIR="kickstart"

# Parse CLI arguments
for arg in "$@"; do
    case $arg in
        --arch=*)    ARCH="${arg#*=}" ;;
        --profile=*) PROFILE="${arg#*=}" ;;
        --backend=*) BACKEND="${arg#*=}" ;;
        --exclude-packages=*) EXCLUDE_FILE="${arg#*=}" ;;
        --help)
            echo "Usage: ./build.sh [--arch=...] [--profile=...] [--backend=...]"
            echo ""
            echo "Options:"
            echo "  --arch=x86_64|aarch64|both   Architecture (default: both)"
            echo "  --profile=full|minimal|dev   Package profile (default: full)"
            echo "  --backend=kickstart|osbuild  Build backend (default: kickstart)"
            echo ""
            echo "Profiles:"
            echo "  full    — All packages (default)"
            echo "  minimal — Core system + UI only (fast builds)"
            echo "  dev     — Core + UI + developer tools"
            echo ""
            echo "Backends:"
            echo "  kickstart — livecd-creator + Docker (default, production-ready)"
            echo "  osbuild   — osbuild-composer + TOML blueprints (experimental)"
            echo "  ostree    — rpm-ostree atomic OS commits (immutable)"
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg (use --help for usage)"
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------
# Backend: OSBuild (experimental)
# ---------------------------------------------------------
if [ "$BACKEND" = "osbuild" ]; then
    echo "=== Using OSBuild backend (experimental) ==="
    OSBUILD_SCRIPT="$(dirname "$0")/osbuild/build-osbuild.sh"
    if [ ! -x "$OSBUILD_SCRIPT" ]; then
        chmod +x "$OSBUILD_SCRIPT"
    fi

    if [ "$ARCH" = "both" ]; then
        "$OSBUILD_SCRIPT" "$PROFILE" "x86_64"
        "$OSBUILD_SCRIPT" "$PROFILE" "aarch64"
    else
        "$OSBUILD_SCRIPT" "$PROFILE" "$ARCH"
    fi
    exit 0
fi

# ---------------------------------------------------------
# Backend: OSTree (atomic / immutable)
# ---------------------------------------------------------
if [ "$BACKEND" = "ostree" ]; then
    echo "=== Using OSTree backend (atomic) ==="
    OSTREE_SCRIPT="$(dirname "$0")/ostree/build-ostree.sh"
    if [ ! -x "$OSTREE_SCRIPT" ]; then
        chmod +x "$OSTREE_SCRIPT"
    fi

    # Pass --iso flag if producing an installable image
    "$OSTREE_SCRIPT" --iso
    exit 0
fi

# ---------------------------------------------------------
# Backend: Kickstart + livecd-creator (default)
# ---------------------------------------------------------

# Configuration
IMAGE_NAME_ARM64="fedora-builder-arm64"
IMAGE_NAME_AMD64="fedora-builder-amd64"
ISO_NAME_ARM64="VibeOS-aarch64.iso"
ISO_NAME_AMD64="VibeOS-x86_64.iso"

# Resolve kickstart filename based on profile
# "full" profile uses the default vibeos-<arch>.ks
# Other profiles use vibeos-<arch>-<profile>.ks
resolve_ks() {
    local arch="$1"
    if [ "$PROFILE" = "full" ]; then
        echo "vibeos-${arch}.ks"
    else
        echo "vibeos-${arch}-${PROFILE}.ks"
    fi
}

echo "============================================"
echo "  VibeOS Build System"
echo "  Architecture: $ARCH"
echo "  Profile:      $PROFILE"
echo "============================================"

# ---------------------------------------------------------
# Step 1: Build Docker environments
# ---------------------------------------------------------
echo "=== Step 1: Building Docker environments ==="

if [ "$ARCH" = "both" ] || [ "$ARCH" = "aarch64" ]; then
    echo "Building Native ARM64 Builder Image..."
    docker buildx build --platform linux/arm64 -t "$IMAGE_NAME_ARM64" --load .
fi

if [ "$ARCH" = "both" ] || [ "$ARCH" = "x86_64" ]; then
    echo "Building Native x86_64 Builder Image..."
    docker buildx build --platform linux/amd64 -t "$IMAGE_NAME_AMD64" --load .
fi

# ---------------------------------------------------------
# Step 2: Build ARM64 ISO
# ---------------------------------------------------------
if [ "$ARCH" = "both" ] || [ "$ARCH" = "aarch64" ]; then
    KS_FILE=$(resolve_ks "aarch64")
    echo "=== Step 2: Creating Native ARM64 ISO (profile: $PROFILE) ==="
    echo "    Kickstart: ${KS_DIR}/${KS_FILE}"

    if [ ! -f "${KS_DIR}/${KS_FILE}" ]; then
        echo "ERROR: Kickstart file '${KS_DIR}/${KS_FILE}' not found!"
        echo "Available profiles for aarch64:"
        ls -1 "${KS_DIR}"/vibeos-aarch64*.ks 2>/dev/null || echo "  (none)"
        exit 1
    fi

    rm -f "$ISO_NAME_ARM64"

    docker run --rm --privileged --platform linux/arm64 \
        -v "$(pwd):/workspace" \
        -v vibeos-dnf-cache-arm64:/var/cache/dnf \
        "$IMAGE_NAME_ARM64" \
        bash -c "cd /workspace/${KS_DIR} \
            && cp -v /workspace/live.py /workspace/creator.py /workspace/fs.py /usr/lib/python3.12/site-packages/imgcreate/ \
            && livecd-creator --verbose \
                --config=${KS_FILE} \
                --fslabel=VibeOS_ARM64 \
                --cache=/workspace/cache \
            && mv *.iso /workspace/$ISO_NAME_ARM64"

    if [ ! -f "$ISO_NAME_ARM64" ]; then
        echo "ERROR: ARM64 ISO was not created successfully."
        exit 1
    fi

    echo "✓ ARM64 ISO created: $(ls -lh "$ISO_NAME_ARM64" | awk '{print $5}')"
fi

# ---------------------------------------------------------
# Step 3: Build x86_64 ISO
# ---------------------------------------------------------
if [ "$ARCH" = "both" ] || [ "$ARCH" = "x86_64" ]; then
    KS_FILE=$(resolve_ks "x86_64")
    echo "=== Step 3: Creating Native x86_64 ISO (profile: $PROFILE) ==="
    echo "    Kickstart: ${KS_DIR}/${KS_FILE}"

    if [ ! -f "${KS_DIR}/${KS_FILE}" ]; then
        echo "ERROR: Kickstart file '${KS_DIR}/${KS_FILE}' not found!"
        echo "Available profiles for x86_64:"
        ls -1 "${KS_DIR}"/vibeos-x86_64*.ks 2>/dev/null || echo "  (none)"
        exit 1
    fi

    rm -f "$ISO_NAME_AMD64"

    docker run --rm --privileged --platform linux/amd64 \
        -v "$(pwd):/workspace" \
        -v vibeos-dnf-cache-amd64:/var/cache/dnf \
        "$IMAGE_NAME_AMD64" \
        bash -c "cd /workspace/${KS_DIR} \
            && cp -v /workspace/live.py /workspace/creator.py /workspace/fs.py /usr/lib/python3.12/site-packages/imgcreate/ \
            && livecd-creator --verbose \
                --config=${KS_FILE} \
                --fslabel=VibeOS_AMD64 \
                --cache=/workspace/cache \
            && mv *.iso /workspace/$ISO_NAME_AMD64"

    if [ ! -f "$ISO_NAME_AMD64" ]; then
        echo "ERROR: x86_64 ISO was not created successfully."
        exit 1
    fi

    echo "✓ x86_64 ISO created: $(ls -lh "$ISO_NAME_AMD64" | awk '{print $5}')"
fi

# ---------------------------------------------------------
# Summary
# ---------------------------------------------------------
echo ""
echo "=== Build complete! ==="
echo "Profile: $PROFILE"
echo ""
[ -f "$ISO_NAME_ARM64" ] && echo "  $ISO_NAME_ARM64  $(ls -lh "$ISO_NAME_ARM64" | awk '{print $5}')"
[ -f "$ISO_NAME_AMD64" ] && echo "  $ISO_NAME_AMD64  $(ls -lh "$ISO_NAME_AMD64" | awk '{print $5}')"
echo ""
