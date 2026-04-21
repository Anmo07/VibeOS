import base64


with open('custom-bg.png', 'rb') as f:
    bg_data = f.read()

new_bg = base64.encodebytes(bg_data).decode('utf-8')

replacement_block = (
    f'cat << "__EOF__" | base64 -d > /usr/share/backgrounds/custom-bg.png\n'
    f'{new_bg}__EOF__\n'
)

with open('vibeos.ks', 'r') as f:
    lines = f.readlines()

out_lines = []
in_base64_block = False

for line in lines:
    if ('base64 -d > /usr/share/backgrounds/mac-bg.png' in line or
            'base64 -d > /usr/share/backgrounds/custom-bg.png' in line):
        out_lines.append(replacement_block)
        in_base64_block = True
    elif in_base64_block and line.startswith('__EOF__'):
        in_base64_block = False
    elif not in_base64_block:
        out_lines.append(line)

with open('vibeos.ks', 'w') as f:
    f.writelines(out_lines)

print("Patching complete!")
