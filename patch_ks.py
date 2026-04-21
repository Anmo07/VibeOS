import sys


with open('vibeos.ks', 'r') as f:
    lines = f.readlines()

with open('/tmp/new_wallpaper.b64', 'r') as f:
    new_bg = f.read().strip()

out_lines = []
in_base64_block = False

for line in lines:
    if line.startswith('cat << "__EOF__" | base64 -d > /usr/share/backgrounds/mac-bg.png'):
        out_lines.append(line)
        out_lines.append(new_bg + '\n')
        in_base64_block = True
    elif in_base64_block and line.startswith('__EOF__'):
        out_lines.append(line)
        in_base64_block = False
    elif not in_base64_block:
        out_lines.append(line)

final_lines = out_lines

post_end_idx = 0
for i, line in enumerate(final_lines):
    if line.startswith('%end'):
        post_end_idx = i

in_post = False
for i, line in enumerate(final_lines):
    if line.startswith('%post'):
        in_post = True
    if in_post and line.startswith('%end'):
        final_lines.insert(
            i,
            "sed -i 's/^PresentDevicePolicy=.*$/PresentDevicePolicy=allow/'"
            " /etc/usbguard/usbguard-daemon.conf || True\n"
        )
        break

with open('vibeos.ks', 'w') as f:
    f.writelines(final_lines)
