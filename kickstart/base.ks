# base.ks — Fedora base include + partition layout
# Include the default Fedora Workstation configuration
%include /usr/share/spin-kickstarts/fedora-live-workstation.ks

# Increase root partition size to 16GB to fit all VibeOS packages
part / --size=16384 --fstype ext4
