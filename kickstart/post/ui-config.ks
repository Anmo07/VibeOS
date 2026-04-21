%post
# ---------------------------------------------------------
# UI Configuration — dconf profile, GNOME extensions, themes
# ---------------------------------------------------------

# Configure dconf profile for custom defaults
mkdir -p /etc/dconf/profile
cat <<EOF > /etc/dconf/profile/user
user-db:user
system-db:local
EOF

# Create the local dconf database directory
mkdir -p /etc/dconf/db/local.d

# Set macOS-like GNOME Desktop Override
cat <<EOF > /etc/dconf/db/local.d/99-mac-ui
[org/gnome/shell]
enabled-extensions=['dash-to-dock@micxgx.gmail.com', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'blur-my-shell@aunetx', 'appindicatorsupport@rgcjonas.gmail.com', 'gestureImprovements@gestures', 'gsconnect@andyholmes.github.io', 'ding@rastersoft.com', 'tiling-assistant@s-ol.github.be']
favorite-apps=['google-chrome.desktop', 'code.desktop', 'chatgpt.desktop', 'gemini.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop']
[org/gnome/shell/extensions/dash-to-dock]
dock-position='BOTTOM'
extend-height=false
dock-fixed=false
autohide-in-fullscreen=true
transparency-mode='DYNAMIC'
custom-theme-shrink=true
show-trash=true
show-mounts=true
show-apps-at-top=true
click-action='minimize-or-previews'
scroll-action='cycle-windows'

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/custom-bg.png'
picture-uri-dark='file:///usr/share/backgrounds/custom-bg.png'
picture-options='zoom'

[org/gnome/desktop/interface]
gtk-theme='Materia'
icon-theme='Papirus'
cursor-theme='La-Capitaine'
show-battery-percentage=true
font-antialiasing='rgba'
font-name='Noto Sans 11'
document-font-name='Noto Sans 11'
monospace-font-name='Fira Mono 12'
color-scheme='prefer-dark'

[org/gnome/settings-daemon/plugins/color]
night-light-enabled=true
night-light-schedule-automatic=true
night-light-temperature=uint32 3500

[org/gnome/desktop/wm/preferences]
button-layout='close,minimize,maximize:'

[org/gnome/desktop/peripherals/touchpad]
tap-to-click=true
natural-scroll=true
two-finger-scrolling-enabled=true
speed=0.35

[org/gnome/settings-daemon/plugins/media-keys]
custom-keybindings=['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ulauncher/']

[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ulauncher]
name='Ulauncher'
command='ulauncher-toggle'
binding='<Control>space'

[org/gnome/desktop/wm/keybindings]
switch-input-source=['<Super>space']
switch-input-source-backward=['<Shift><Super>space']

[org/gnome/mutter]
overlay-key=''

[org/gnome/shell/extensions/gestureImprovements]
pinch-3-finger-gesture='NONE'
pinch-4-finger-gesture='SHOW_DESKTOP'
forward-back-gesture-workspace=true
default-overview-gesture-direction=true
allow-minimize-window=true
touchpad-speed-scale=1.0
EOF

# Apply high-fidelity UI settings (override layer)
cat << "__EOF__" > /etc/dconf/db/local.d/01-custom-branding
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/custom-bg.png'
picture-uri-dark='file:///usr/share/backgrounds/custom-bg.png'

[org/gnome/desktop/interface]
font-name='Inter 11'
icon-theme='Papirus-Dark'
gtk-theme='Materia-dark'
cursor-theme='La-Capitaine'
enable-animations=false
show-battery-percentage=true

[org/gnome/mutter]
edge-tiling=true
dynamic-workspaces=true
experimental-features=['variable-refresh-rate', 'scale-monitor-framebuffer']

[org/gnome/shell/extensions/just-perfection]
animation=2
panel=true
dash=true

[org/gnome/login-screen]
logo=''
__EOF__

dconf update

%end
