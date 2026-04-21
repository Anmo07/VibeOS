%post
# ---------------------------------------------------------
# Applications — Flatpak-First Delivery
# ---------------------------------------------------------
# Strategy: Only RPM Fusion codecs and drivers are installed via DNF.
# All end-user apps (browser, editor, media player) are delivered
# via Flatpak on first boot for:
#   - Architecture independence (no Chrome vs Chromium branching)
#   - Sandboxed, auto-updating apps
#   - Smaller base ISO size
# ---------------------------------------------------------

# RPM Fusion (still needed for codecs that Flatpak can't provide)
dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
  || true

# Broadcom Wireless Drivers for MacBook compatibility
dnf install -y broadcom-wl akmod-wl || true

# System-level codecs (used by all apps including Flatpak sandboxes)
dnf install -y gstreamer1-plugins-ugly gstreamer1-plugins-bad-free ffmpeg-free || true

# ---------------------------------------------------------
# Flatpak Setup + First-Boot App Installer
# ---------------------------------------------------------
dnf install -y flatpak jq || true
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

# Copy the app manifest into the system
mkdir -p /usr/share/vibeos
# The manifest is at /workspace/kickstart/ during Docker build (host mount)
if [ -f /workspace/kickstart/flatpak-apps.json ]; then
    cp /workspace/kickstart/flatpak-apps.json /usr/share/vibeos/flatpak-apps.json
fi

# Create the first-boot Flatpak installer (reads from JSON manifest)
cat <<'SCRIPT' > /usr/local/bin/vibeos-flatpak-init.sh
#!/bin/bash
set -e
LOG="/var/log/vibeos-flatpak-init.log"
MANIFEST="/usr/share/vibeos/flatpak-apps.json"
PROFILE_FILE="/etc/vibeos-profile"

# Read the build profile (default: full)
PROFILE="full"
[ -f "$PROFILE_FILE" ] && PROFILE=$(cat "$PROFILE_FILE")

echo "$(date): VibeOS Flatpak Init — Profile: $PROFILE" | tee -a "$LOG"

# Wait for network
echo "Waiting for network..." | tee -a "$LOG"
for i in $(seq 1 60); do
    ping -c 1 dl.flathub.org &>/dev/null && break
    sleep 5
done

if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: Manifest not found at $MANIFEST" | tee -a "$LOG"
    exit 1
fi

# Parse manifest and install apps for this profile
APP_IDS=$(jq -r ".profiles.\"${PROFILE}\".apps[].id" "$MANIFEST" 2>/dev/null)

if [ -z "$APP_IDS" ]; then
    echo "No apps defined for profile '$PROFILE'" | tee -a "$LOG"
else
    for APP_ID in $APP_IDS; do
        APP_NAME=$(jq -r ".profiles.\"${PROFILE}\".apps[] | select(.id==\"${APP_ID}\") | .name" "$MANIFEST")
        echo "Installing: $APP_NAME ($APP_ID)..." | tee -a "$LOG"
        flatpak install -y --noninteractive flathub "$APP_ID" 2>&1 | tee -a "$LOG" || true
    done
fi

# Set default applications based on manifest
echo "Setting default applications..." | tee -a "$LOG"
MIME_ENTRIES=$(jq -r ".profiles.\"${PROFILE}\".apps[] | select(.set_default_for != null) | \"\(.id) \(.set_default_for[])\"" "$MANIFEST" 2>/dev/null)
if [ -n "$MIME_ENTRIES" ]; then
    mkdir -p /etc/skel/.config
    MIMEAPPS="/etc/skel/.config/mimeapps.list"
    echo "[Default Applications]" > "$MIMEAPPS"
    echo "$MIME_ENTRIES" | while read -r APP_ID MIME_TYPE; do
        # Flatpak desktop files use the app ID as basename
        echo "${MIME_TYPE}=${APP_ID}.desktop" >> "$MIMEAPPS"
    done
fi

echo "$(date): Flatpak initialization complete" | tee -a "$LOG"

# Self-disable after first run
systemctl disable vibeos-flatpak-init.service
SCRIPT
chmod +x /usr/local/bin/vibeos-flatpak-init.sh

# Systemd service for first-boot
cat <<'EOF' > /etc/systemd/system/vibeos-flatpak-init.service
[Unit]
Description=VibeOS First-Boot Flatpak App Installer
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vibeos-flatpak-init.sh
RemainAfterExit=true
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

systemctl enable vibeos-flatpak-init.service || true

# ---------------------------------------------------------
# Write the build profile for the first-boot service to read
# ---------------------------------------------------------
# This is set by the build system based on which kickstart was used.
# The vibeos-flatpak-init.sh reads this to determine which apps to install.
echo "full" > /etc/vibeos-profile

# ---------------------------------------------------------
# ChatGPT & Google Gemini Web Apps (lightweight .desktop stubs)
# These use whatever browser Flatpak installs
# ---------------------------------------------------------
BROWSER_CMD="flatpak run org.chromium.Chromium"

cat << EOF_DESKTOP > /usr/share/applications/chatgpt.desktop
[Desktop Entry]
Name=ChatGPT
Exec=${BROWSER_CMD} --app=https://chat.openai.com/
Icon=browser
Type=Application
Categories=Network;WebBrowser;
EOF_DESKTOP

cat << EOF_DESKTOP > /usr/share/applications/gemini.desktop
[Desktop Entry]
Name=Google Gemini
Exec=${BROWSER_CMD} --app=https://gemini.google.com/
Icon=browser
Type=Application
Categories=Network;WebBrowser;
EOF_DESKTOP

# ---------------------------------------------------------
# Ulauncher Autostart & Extensions
# ---------------------------------------------------------
mkdir -p /etc/skel/.config/autostart
cp /usr/share/applications/ulauncher.desktop /etc/skel/.config/autostart/ || true

mkdir -p /etc/skel/.local/share/ulauncher/extensions
curl -L https://github.com/tuanpham-dev/ulauncher-better-calculator/archive/refs/heads/master.zip -o /tmp/calc.zip && unzip -q /tmp/calc.zip -d /etc/skel/.local/share/ulauncher/extensions/ && mv /etc/skel/.local/share/ulauncher/extensions/ulauncher-better-calculator-master /etc/skel/.local/share/ulauncher/extensions/ulauncher-calculator && rm /tmp/calc.zip || true
curl -L https://github.com/brpaz/ulauncher-file-search/archive/refs/heads/master.zip -o /tmp/fs.zip && unzip -q /tmp/fs.zip -d /etc/skel/.local/share/ulauncher/extensions/ && mv /etc/skel/.local/share/ulauncher/extensions/ulauncher-file-search-master /etc/skel/.local/share/ulauncher/extensions/ulauncher-file-search && rm /tmp/fs.zip || true
curl -L https://github.com/tjquillan/ulauncher-system/archive/refs/heads/master.zip -o /tmp/sys.zip && unzip -q /tmp/sys.zip -d /etc/skel/.local/share/ulauncher/extensions/ && mv /etc/skel/.local/share/ulauncher/extensions/ulauncher-system-master /etc/skel/.local/share/ulauncher/extensions/ulauncher-system && rm /tmp/sys.zip || true

%end
