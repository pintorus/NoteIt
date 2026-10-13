"""Génère l'icône de NoteIt (style MeasureIt / ExploreIt : tuile de verre isométrique,
néons cyan/vert sur fond bleu nuit) et toutes les tailles Android/iOS.

    python3 tool/make_icon.py
"""
import json, math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = os.path.join(os.path.dirname(__file__), '..')
N = 1024           # taille finale
SS = 2             # suréchantillonnage
W = N * SS
CYAN = (119, 222, 237)
GREEN = (60, 230, 160)
random.seed(7)


def glow(layer, radius):
    """Superpose un halo flou sous un calque néon."""
    halo = layer.filter(ImageFilter.GaussianBlur(radius))
    out = Image.alpha_composite(halo, halo)
    out = Image.alpha_composite(out, layer.filter(ImageFilter.GaussianBlur(radius / 3)))
    return Image.alpha_composite(out, layer)


def background():
    y, x = np.mgrid[0:W, 0:W].astype(np.float32) / W
    d = np.sqrt((x - 0.5) ** 2 + (y - 0.45) ** 2)
    t = np.clip(d / 0.75, 0, 1)[..., None]
    inner = np.array([16, 44, 66], np.float32)
    outer = np.array([6, 11, 24], np.float32)
    rgb = inner * (1 - t) + outer * t
    img = Image.fromarray(rgb.astype(np.uint8), 'RGB').convert('RGBA')
    d = ImageDraw.Draw(img)
    # étincelles vertes
    for _ in range(26):
        px, py = random.uniform(0.05, 0.95) * W, random.uniform(0.05, 0.95) * W
        r = random.choice([2, 3, 4]) * SS
        d.ellipse([px - r, py - r, px + r, py + r], fill=GREEN + (random.randint(90, 200),))
    return img


def top_face():
    """Face supérieure de la tuile, dessinée à plat (vue de dessus)."""
    face = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    m = int(W * 0.14)
    box = [m, m, W - m, W - m]
    rad = int(W * 0.13)
    d = ImageDraw.Draw(face)
    d.rounded_rectangle(box, rad, fill=(32, 51, 68, 215))
    # reflet de verre
    sheen = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(sheen).rounded_rectangle(box, rad, fill=(255, 255, 255, 28))
    grad = Image.linear_gradient('L').rotate(45, expand=False).resize((W, W))
    sheen.putalpha(ImageChops.multiply(sheen.getchannel('A'), grad))
    face = Image.alpha_composite(face, sheen)

    # grille fine
    grid = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    g = ImageDraw.Draw(grid)
    step = W // 24
    for i in range(m, W - m, step):
        g.line([(i, m), (i, W - m)], fill=CYAN + (22,), width=SS)
        g.line([(m, i), (W - m, i)], fill=CYAN + (22,), width=SS)
    mask = Image.new('L', (W, W), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, rad, fill=255)
    grid.putalpha(ImageChops.multiply(grid.getchannel('A'), mask))
    face = Image.alpha_composite(face, grid)

    # bordure lumineuse
    d = ImageDraw.Draw(face)
    d.rounded_rectangle(box, rad, outline=CYAN + (170,), width=5 * SS)

    # note néon : feuille à coin corné, lignes de texte et tâche cochée
    neon = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    n = ImageDraw.Draw(neon)
    lw = 9 * SS
    x0, y0, x1, y1 = W * 0.30, W * 0.27, W * 0.70, W * 0.73
    fold = W * 0.09
    page = [(x0, y0), (x1 - fold, y0), (x1, y0 + fold), (x1, y1), (x0, y1)]
    n.polygon(page, fill=CYAN + (34,))
    n.line(page + [page[0]], fill=CYAN + (255,), width=lw, joint='curve')
    n.line([(x1 - fold, y0), (x1 - fold, y0 + fold), (x1, y0 + fold)],
           fill=CYAN + (255,), width=6 * SS, joint='curve')
    # lignes de texte (titre plus épais)
    tx = x0 + W * 0.05
    n.line([(tx, y0 + W * 0.07), (tx + W * 0.17, y0 + W * 0.07)], fill=CYAN + (255,), width=10 * SS)
    for k, length in enumerate([0.30, 0.26, 0.29]):
        yy = y0 + W * (0.14 + k * 0.055)
        n.line([(tx, yy), (tx + W * length, yy)], fill=CYAN + (200,), width=5 * SS)
    # tâches : une cochée (verte), une à faire
    for k, done in enumerate([True, False]):
        by = y0 + W * (0.33 + k * 0.075)
        s = W * 0.026
        box = [tx, by - s, tx + 2 * s, by + s]
        n.rounded_rectangle(box, int(W * 0.008), fill=(14, 30, 44, 255),
                            outline=(GREEN if done else CYAN) + (255,), width=5 * SS)
        if done:
            n.line([(tx + s * 0.45, by), (tx + s * 0.9, by + s * 0.5), (tx + s * 1.6, by - s * 0.55)],
                   fill=GREEN + (255,), width=6 * SS, joint='curve')
        n.line([(tx + W * 0.08, by), (tx + W * (0.25 if done else 0.21), by)],
               fill=(GREEN if done else CYAN) + (220,), width=5 * SS)
    face = Image.alpha_composite(face, glow(neon, 14 * SS))

    # traits de mesure sur le bord (clin d'œil à MeasureIt)
    d = ImageDraw.Draw(face)
    for i in range(14):
        x = W * 0.25 + i * W * 0.036
        h = W * (0.03 if i % 5 == 0 else 0.017)
        d.line([(x, W - m - W * 0.035), (x, W - m - W * 0.035 - h)], fill=GREEN + (200,), width=3 * SS)
    return face, mask


def iso(img, scale_y=0.58, size=W):
    """Projection isométrique : rotation 45° puis aplatissement vertical."""
    c = W / 2
    a = math.radians(45)
    k = 0.90  # réduction pour tenir dans le cadre après rotation
    fwd = np.array([
        [k * math.cos(a), -k * math.sin(a), 0],
        [k * scale_y * math.sin(a), k * scale_y * math.cos(a), 0],
        [0, 0, 1]])
    pre = np.array([[1, 0, -c], [0, 1, -c], [0, 0, 1]])
    post = np.array([[1, 0, size / 2], [0, 1, size * 0.44], [0, 0, 1]])
    inv = np.linalg.inv(post @ fwd @ pre)
    return img.transform((size, size), Image.AFFINE, tuple(inv[:2].flatten()), Image.BICUBIC)


def build():
    canvas = background()
    face, mask = top_face()
    top = iso(face)
    m = iso(Image.merge('RGBA', [mask] * 4)).getchannel('A')

    # épaisseur de la dalle de verre
    depth = int(W * 0.05)
    for k in range(depth, 0, -1):
        t = k / depth
        col = (int(12 + 18 * (1 - t)), int(28 + 34 * (1 - t)), int(44 + 46 * (1 - t)), 245)
        slab = Image.new('RGBA', (W, W), col)
        slab.putalpha(m)
        canvas.alpha_composite(slab, (0, k))
    # liseré lumineux au bas de la dalle
    ring = ImageChops.subtract(m.filter(ImageFilter.MaxFilter(7)), m)
    edge = Image.new('RGBA', (W, W), CYAN + (0,))
    edge.putalpha(ring)
    canvas.alpha_composite(glow(edge, 10 * SS), (0, depth))
    # ombre portée douce sous la dalle
    canvas.alpha_composite(top)
    return canvas.resize((N, N), Image.LANCZOS)


def export(icon):
    os.makedirs(os.path.join(ROOT, 'assets', 'icon'), exist_ok=True)
    icon.convert('RGB').save(os.path.join(ROOT, 'assets', 'icon', 'app_icon.png'))
    rgb = icon.convert('RGB')
    for name, size in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        p = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', f'mipmap-{name}', 'ic_launcher.png')
        rgb.resize((size, size), Image.LANCZOS).save(p)
    iconset = os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    for img in json.load(open(os.path.join(iconset, 'Contents.json')))['images']:
        side = float(img['size'].split('x')[0]) * int(img['scale'].rstrip('x'))
        rgb.resize((round(side), round(side)), Image.LANCZOS).save(os.path.join(iconset, img['filename']))


if __name__ == '__main__':
    export(build())
    print('icône générée')
