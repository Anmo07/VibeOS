%post
# ---------------------------------------------------------
# OSTree Update Mechanism — atomic updates & rollback
# ---------------------------------------------------------
# This module installs the vibeos-update CLI and auto-update timer.
# Only functional on OSTree-based deployments (VibeOS Atomic Edition).
# On traditional (kickstart) installs, it serves as a future-ready stub.
# ---------------------------------------------------------

# ---------------------------------------------------------
# 1. vibeos-update CLI tool
# ---------------------------------------------------------
cat <<'SCRIPT' > /usr/local/bin/vibeos-update
#!/bin/bash
# vibeos-update — VibeOS system update manager
# Usage:
#   vibeos-update check       Check for available updates
#   vibeos-update upgrade     Download and stage update (reboot to apply)
#   vibeos-update rollback    Revert to previous deployment
#   vibeos-update status      Show current deployment info
#   vibeos-update history     Show deployment history

set -e
VERSION="1.0.0"

# Detect if running on OSTree
is_ostree() {
    [ -f /run/ostree-booted ] || command -v rpm-ostree &>/dev/null
}

case "${1:-status}" in
    check)
        if is_ostree; then
            echo "🔍 Checking for updates..."
            rpm-ostree upgrade --check 2>&1
        else
            echo "🔍 Checking for updates (DNF)..."
            dnf check-update --quiet 2>&1 || true
        fi
        ;;

    upgrade)
        if is_ostree; then
            echo "⬇️  Downloading update..."
            rpm-ostree upgrade
            echo ""
            echo "✅ Update staged. Reboot to apply:"
            echo "   systemctl reboot"
        else
            echo "⬇️  Upgrading system (DNF)..."
            sudo dnf upgrade -y
        fi
        ;;

    rollback)
        if is_ostree; then
            echo "⏪ Rolling back to previous deployment..."
            rpm-ostree rollback
            echo ""
            echo "✅ Rollback staged. Reboot to apply:"
            echo "   systemctl reboot"
        else
            echo "❌ Rollback is only available on VibeOS Atomic Edition (OSTree)."
            echo "   Consider upgrading to the atomic variant for rollback support."
        fi
        ;;

    status)
        echo "🖥️  VibeOS System Status"
        echo "   Version: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)"
        echo "   Kernel:  $(uname -r)"
        echo "   Arch:    $(uname -m)"
        echo ""
        if is_ostree; then
            echo "📦 OSTree Deployment:"
            rpm-ostree status
        else
            echo "📦 Traditional (RPM) installation"
            echo "   Packages: $(rpm -qa | wc -l) installed"
        fi
        ;;

    history)
        if is_ostree; then
            echo "📋 Deployment History:"
            ostree log $(rpm-ostree status --json 2>/dev/null | jq -r '.deployments[0].origin' 2>/dev/null || echo "vibeos/40/$(uname -m)/desktop") 2>/dev/null | head -40
        else
            echo "📋 DNF Transaction History:"
            dnf history list --reverse 2>/dev/null | tail -20
        fi
        ;;

    --version|-v)
        echo "vibeos-update v${VERSION}"
        ;;

    *)
        echo "vibeos-update — VibeOS System Update Manager"
        echo ""
        echo "Commands:"
        echo "  check      Check for available updates"
        echo "  upgrade    Download and apply updates"
        echo "  rollback   Revert to previous OS version (OSTree only)"
        echo "  status     Show current system info"
        echo "  history    View update history"
        ;;
esac
SCRIPT
chmod +x /usr/local/bin/vibeos-update

# ---------------------------------------------------------
# 2. Automatic update check timer (weekly)
# ---------------------------------------------------------
cat <<'EOF' > /etc/systemd/system/vibeos-update-check.service
[Unit]
Description=VibeOS Automatic Update Check
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vibeos-update check
StandardOutput=journal
EOF

cat <<'EOF' > /etc/systemd/system/vibeos-update-check.timer
[Unit]
Description=Weekly VibeOS Update Check

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=3600

[Install]
WantedBy=timers.target
EOF

systemctl enable vibeos-update-check.timer || true

%end
