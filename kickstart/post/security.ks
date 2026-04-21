%post
# ---------------------------------------------------------
# Security — Firewall, Bluetooth, USBGuard, SSH hardening
# ---------------------------------------------------------

# Enable Application Firewall (Block inbound by default)
systemctl enable firewalld

# Enable Bluetooth
systemctl enable bluetooth

# Enable USB Accessory Security (Block new USBs on lock)
systemctl enable usbguard

# Restrict Root SSH (if openssh is installed)
sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config || true

# Ensure a balanced power profile by default
cat <<'EOF' > /etc/systemd/system/vibeos-powerprofiles.service
[Unit]
Description=Set VibeOS power profile to balanced
After=power-profiles-daemon.service
ConditionPathExists=/usr/bin/powerprofilesctl

[Service]
Type=oneshot
ExecStart=/usr/bin/powerprofilesctl set balanced
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
systemctl enable vibeos-powerprofiles.service || true

%end
