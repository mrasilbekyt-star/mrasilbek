"""Cuts objects out of a picture with a plain white background.

    python3 -I tool/cutout.py <image> <out_dir> <name> [<name> ...] [--max 256] [--prefix obj_]
                              [--holes ring,forceps]

Objects are found as separate blobs and named in reading order (row by row,
left to right). Each one is saved as <out_dir>/<prefix><name>.png with a
transparent background. Pieces that sit close together (a cluster of stones)
count as one object. Use "-" as a name to skip a blob.

The background is the smooth, light, grey-to-white area reachable from the
image border, so soft shadows go with it while the sharp outline of each
object stops it. Objects named in --holes also lose a light area enclosed in
their middle (the inside of a ring).
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

parser = argparse.ArgumentParser()
parser.add_argument('image')
parser.add_argument('out_dir')
parser.add_argument('names', nargs='+')
parser.add_argument('--max', type=int, default=256, help='longest side of each cut-out, px')
parser.add_argument('--prefix', default='obj_')
parser.add_argument('--edge', type=float, default=10, help='gradient above this is an object outline')
parser.add_argument('--holes', default='', help='comma-separated names whose enclosed middle is background')
parser.add_argument('--merge', type=int, default=31, help='blobs closer than this (px) become one object')
args = parser.parse_args()

src = Image.open(args.image).convert('RGB')
w, h = src.size

# Background candidates: light, grey-ish and smooth (no outline nearby).
rgb = np.asarray(src).astype(np.float32)
gray = rgb.mean(axis=2)
gx = np.zeros_like(gray)
gy = np.zeros_like(gray)
gx[:, 1:-1] = gray[:, 2:] - gray[:, :-2]
gy[1:-1, :] = gray[2:, :] - gray[:-2, :]
grad = Image.fromarray(np.clip(np.hypot(gx, gy), 0, 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))
sat = rgb.max(axis=2) - rgb.min(axis=2)
smooth = (np.asarray(grad) < args.edge) & (gray > 160) & (sat < 30)
# copy(): flood fills do not write into images that wrap a numpy array.
cand = Image.fromarray((smooth * 255).astype(np.uint8)).copy()

BG = 128


def flood_bg(img, x, y):
    if img.getpixel((x, y)) == 255:
        ImageDraw.floodfill(img, (x, y), BG)


for x in range(0, w, 8):
    flood_bg(cand, x, 0)
    flood_bg(cand, x, h - 1)
for y in range(0, h, 8):
    flood_bg(cand, 0, y)
    flood_bg(cand, w - 1, y)
fg = np.asarray(cand) != BG
mask = Image.fromarray((fg * 255).astype(np.uint8))

# Group nearby pieces, then label each group with flood fills.
groups = mask.filter(ImageFilter.MaxFilter(args.merge | 1))
labels = groups.copy()
blobs = []
label = 1
arr = np.asarray(labels)
while True:
    ys, xs = np.nonzero(arr == 255)
    if len(ys) == 0 or label >= 255:
        break
    ImageDraw.floodfill(labels, (int(xs[0]), int(ys[0])), label)
    arr = np.asarray(labels)
    sel = arr == label
    area = int(sel.sum())
    if area > 400:
        yy, xx = np.nonzero(sel)
        blobs.append({'label': label, 'box': (xx.min(), yy.min(), xx.max(), yy.max()), 'area': area})
    label += 1

# Reading order: rows by top edge, then left to right.
blobs.sort(key=lambda b: b['box'][1])
rows = []
for b in blobs:
    if rows and abs(b['box'][1] - rows[-1][0]['box'][1]) < h * 0.1:
        rows[-1].append(b)
    else:
        rows.append([b])
ordered = [b for row in rows for b in sorted(row, key=lambda b: b['box'][0])]
print(f'{len(ordered)} objects found, {len(args.names)} names given')

# Enclosed light middles (inside of a ring) become background too.
holes = set(filter(None, args.holes.split(',')))
for blob, name in zip(ordered, args.names):
    if name not in holes:
        continue
    x0, y0, x1, y1 = blob['box']
    for fx in (0.5, 0.4, 0.6):
        for fy in (0.5, 0.4, 0.6, 0.25, 0.75):
            flood_bg(cand, int(x0 + (x1 - x0) * fx), int(y0 + (y1 - y0) * fy))
fg = np.asarray(cand) != BG
mask = Image.fromarray((fg * 255).astype(np.uint8))

# Soft, slightly shrunk alpha so no white fringe shows on dark tissue.
alpha_full = mask.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(1.2))
os.makedirs(args.out_dir, exist_ok=True)
for blob, name in zip(ordered, args.names):
    x0, y0, x1, y1 = blob['box']
    print(f'  {name:12s} box={blob["box"]} area={blob["area"]}')
    if name == '-':
        continue
    pad = 6
    box = (max(0, x0 - pad), max(0, y0 - pad), min(w, x1 + pad + 1), min(h, y1 + pad + 1))
    group = np.asarray(labels.crop(box)) == blob['label']
    alpha = np.asarray(alpha_full.crop(box)).astype(np.float32) * group
    rgba = np.dstack([np.asarray(src.crop(box)), alpha.astype(np.uint8)])
    out = Image.fromarray(rgba, 'RGBA')
    scale = args.max / max(out.size)
    if scale < 1:
        out = out.resize((max(1, round(out.width * scale)), max(1, round(out.height * scale))), Image.LANCZOS)
    out.save(os.path.join(args.out_dir, f'{args.prefix}{name}.png'), optimize=True)
