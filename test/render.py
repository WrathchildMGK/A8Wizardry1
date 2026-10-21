"""Render the ANTIC display from a 64K memory dump (modes 4 and E only)."""
import sys
from PIL import Image

m = open(sys.argv[1], 'rb').read()
w = lambda a: m[a] | m[a + 1] << 8
dl = w(0x230)
chbase = m[0x2F4] << 8
import colorsys


def atari_rgb(c):
    """Rough NTSC GTIA colour: hue = high nibble (0 = grey), luma = low."""
    lum = (c & 0x0E) / 14.0
    hue = c >> 4
    if hue == 0:
        g = int(lum * 255)
        return (g, g, g)
    # hue 1 gold, 2 orange, 4 red, 5 purple, 7 blue, 10 cyan, 12 green, 15 olive:
    # about 24 degrees backwards round the wheel per step
    h = (45 - (hue - 1) * 24.0) % 360 / 360.0
    r, g, b2 = colorsys.hls_to_rgb(h, 0.15 + lum * 0.7, 0.75)
    return (int(r * 255), int(g * 255), int(b2 * 255))


# the colour registers the VBI copies (COLOR4 background, COLOR0..2, COLOR3)
COL = [atari_rgb(m[0x2C8]), atari_rgb(m[0x2C4]), atari_rgb(m[0x2C5]),
       atari_rgb(m[0x2C6]), atari_rgb(m[0x2C7])]
img = Image.new('RGB', (160, 240))
px = img.load()
y, pc, lms, steps = 8, dl, 0, 0
while y < 240 and steps < 300:
    steps += 1
    ins = m[pc]; pc += 1
    mode = ins & 15
    if mode == 0:
        y += ((ins >> 4) & 7) + 1
        continue
    if mode == 1:
        if ins & 0x40:
            break
        pc = w(pc)
        continue
    if ins & 0x40:
        lms = w(pc); pc += 2
    if mode == 4:
        for r in range(8):
            for c in range(40):
                ch = m[lms + c]
                b = m[chbase + (ch & 0x7F) * 8 + r]
                for p in range(4):
                    v = (b >> (6 - 2 * p)) & 3
                    if v == 3 and ch & 0x80:
                        v = 4
                    if y + r < 240:
                        px[c * 4 + p, y + r] = COL[v]
        lms += 40; y += 8
    elif mode == 0xE:
        for c in range(40):
            b = m[lms + c]
            for p in range(4):
                px[c * 4 + p, y] = COL[(b >> (6 - 2 * p)) & 3]
        lms += 40; y += 1
    else:
        y += 1
img.resize((160 * 4, 240 * 2), Image.NEAREST).save(sys.argv[2])
print('DL $%04X -> %s' % (dl, sys.argv[2]))
