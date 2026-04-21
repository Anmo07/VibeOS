%post
# ---------------------------------------------------------
# Cleanup — Boot optimization, initramfs rebuild, cache purge
# ---------------------------------------------------------

# Disable NetworkManager-wait-online to speed up boot times
systemctl disable NetworkManager-wait-online.service || true

# Final initramfs rebuild to bake in the changes
echo "Baking custom branding into initramfs..."
# Aggressively remove ide_cd from all dracut configs
find /etc/dracut.conf.d/ -type f -exec sed -i 's/ide_cd//g' {} + || true
[ -f /etc/dracut.conf ] && sed -i 's/ide_cd//g' /etc/dracut.conf || true
dracut -f --no-hostonly --omit "poll" --kver $(ls -1 /lib/modules | sort -V | tail -n 1) || true

# Fix VMware mouse freeze by allowing currently present devices in USBGuard
[ -f /etc/usbguard/usbguard-daemon.conf ] && sed -i 's/^PresentDevicePolicy=.*$/PresentDevicePolicy=allow/' /etc/usbguard/usbguard-daemon.conf || true

# Purge any caches or logs to drastically shrink the ISO footprint
echo "Cleaning up package manager caches to reduce ISO size..."
dnf clean all
rm -rf /var/cache/dnf/*
# We do not rm -rf /tmp/* here because kickstart is currently running from /tmp/ks-script!

%end
