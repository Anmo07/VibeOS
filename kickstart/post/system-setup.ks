%post
# ---------------------------------------------------------
# System Setup — DNS, Zsh, Oh My Zsh, Gesture Extensions
# ---------------------------------------------------------

# Fix DNS for the chroot environment (clearing broken symlinks if they exist)
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
chmod 644 /etc/resolv.conf

# Generate machine-id for dbus to work in chroot
systemd-machine-id-setup || dbus-uuidgen > /etc/machine-id || true

# Change default shell to ZSH for future liveuser
echo "/bin/zsh" >> /etc/shells
/usr/sbin/useradd -D -s /bin/zsh || true

# ---------------------------------------------------------
# Oh My Zsh — polished terminal experience for all users
# ---------------------------------------------------------
dnf install -y git curl || true

# Install Oh My Zsh to /usr/share/oh-my-zsh (system-wide)
export ZSH="/usr/share/oh-my-zsh"
git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ZSH" || true

# Install popular plugins
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH/custom/plugins/zsh-autosuggestions" || true
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH/custom/plugins/zsh-syntax-highlighting" || true

# Create default .zshrc for all new users (via /etc/skel)
cat <<'ZSHRC' > /etc/skel/.zshrc
export ZSH="/usr/share/oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh
ZSHRC

# ---------------------------------------------------------
# Install Gesture Improvements GNOME Extension (system-wide)
# ---------------------------------------------------------
GNOME_VER=$(gnome-shell --version 2>/dev/null | awk '{print $3}' | cut -d. -f1)
EXT_UUID="gestureImprovements@gestures"
EXT_URL="https://extensions.gnome.org/extension-data/gestureImprovements%40gestures.v${GNOME_VER:-45}.shell-extension.zip"
EXT_DIR="/usr/share/gnome-shell/extensions/${EXT_UUID}"
mkdir -p "${EXT_DIR}"
wget -qO /tmp/gesture-ext.zip "${EXT_URL}" || curl -sL "${EXT_URL}" -o /tmp/gesture-ext.zip || true
if [ -s /tmp/gesture-ext.zip ] && unzip -t /tmp/gesture-ext.zip >/dev/null 2>&1; then
    unzip -qo /tmp/gesture-ext.zip -d "${EXT_DIR}" || true
    chmod -R 755 "${EXT_DIR}"
    echo "Gesture Improvements extension installed to ${EXT_DIR}"
else
    echo "Warning: Failed to download or extract gesture improvements extension."
fi
rm -f /tmp/gesture-ext.zip

%end
