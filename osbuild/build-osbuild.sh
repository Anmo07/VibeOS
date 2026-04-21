#!/bin/bash
set -e

# ============================================================
# VibeOS OSBuild Backend — Build ISO via osbuild-composer
# ============================================================
# This script is called by the main build.sh when --backend=osbuild
# is specified. It uses declarative TOML blueprints instead of kickstarts.
#
# Requirements:
#   - osbuild-composer service running (systemd or Docker)
#   - composer-cli available
#
# Usage (standalone):
#   ./osbuild/build-osbuild.sh --profile=full --arch=x86_64
# ============================================================

PROFILE="${1:-full}"
ARCH="${2:-$(uname -m)}"
BLUEPRINT_DIR="$(dirname "$0")"
BLUEPRINT_FILE="${BLUEPRINT_DIR}/vibeos-${PROFILE}.toml"
COMPOSE_TYPE="live-iso"
OUTPUT_DIR="$(pwd)"

if [ ! -f "$BLUEPRINT_FILE" ]; then
    echo "ERROR: Blueprint not found: $BLUEPRINT_FILE"
    echo "Available blueprints:"
    ls -1 "${BLUEPRINT_DIR}"/vibeos-*.toml 2>/dev/null || echo "  (none)"
    exit 1
fi

BLUEPRINT_NAME=$(grep '^name' "$BLUEPRINT_FILE" | head -1 | sed 's/.*= *"\(.*\)"/\1/')

echo "============================================"
echo "  VibeOS OSBuild Backend"
echo "  Blueprint: $BLUEPRINT_NAME"
echo "  Profile:   $PROFILE"
echo "  Arch:      $ARCH"
echo "  Output:    $COMPOSE_TYPE"
echo "============================================"

# Step 1: Push the blueprint to composer
echo "=== Pushing blueprint to osbuild-composer ==="
composer-cli blueprints push "$BLUEPRINT_FILE"
echo "✓ Blueprint '$BLUEPRINT_NAME' loaded"

# Step 2: Verify dependencies resolve
echo "=== Checking dependency resolution ==="
composer-cli blueprints depsolve "$BLUEPRINT_NAME"
echo "✓ All dependencies resolved"

# Step 3: Start the compose
echo "=== Starting ISO compose ==="
COMPOSE_OUTPUT=$(composer-cli compose start "$BLUEPRINT_NAME" "$COMPOSE_TYPE" 2>&1)
COMPOSE_ID=$(echo "$COMPOSE_OUTPUT" | grep -oP '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')

if [ -z "$COMPOSE_ID" ]; then
    echo "ERROR: Failed to start compose."
    echo "$COMPOSE_OUTPUT"
    exit 1
fi

echo "✓ Compose started: $COMPOSE_ID"

# Step 4: Wait for completion
echo "=== Waiting for compose to complete ==="
while true; do
    STATUS=$(composer-cli compose status | grep "$COMPOSE_ID" | awk '{print $2}')
    case "$STATUS" in
        FINISHED)
            echo "✓ Compose completed successfully"
            break
            ;;
        FAILED)
            echo "ERROR: Compose failed!"
            composer-cli compose log "$COMPOSE_ID"
            exit 1
            ;;
        *)
            echo "  Status: $STATUS (waiting...)"
            sleep 30
            ;;
    esac
done

# Step 5: Download the ISO
echo "=== Downloading ISO ==="
ISO_NAME="VibeOS-${ARCH}.iso"
composer-cli compose image "$COMPOSE_ID"

# Rename the output
DOWNLOADED=$(ls -1t "${COMPOSE_ID}"*.iso 2>/dev/null | head -1)
if [ -n "$DOWNLOADED" ]; then
    mv "$DOWNLOADED" "${OUTPUT_DIR}/${ISO_NAME}"
    echo "✓ ISO saved: ${OUTPUT_DIR}/${ISO_NAME} ($(ls -lh "${OUTPUT_DIR}/${ISO_NAME}" | awk '{print $5}'))"
else
    echo "WARNING: Could not find downloaded ISO file"
fi

# Cleanup compose
composer-cli compose delete "$COMPOSE_ID" || true

echo ""
echo "=== OSBuild compose complete ==="
echo "  ISO: ${OUTPUT_DIR}/${ISO_NAME}"
