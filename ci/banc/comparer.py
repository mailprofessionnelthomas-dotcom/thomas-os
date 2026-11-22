#!/usr/bin/env python3
"""Banc d'essai : planche des styles + maquette du Studio à côté du vrai bureau (petites images).

Usage : comparer.py DOSSIER_PHOTOS DOSSIER_DESIGNS DOSSIER_SORTIE
"""
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageStat

src, designs, out = map(Path, sys.argv[1:4])
(out / "vrai").mkdir(parents=True, exist_ok=True)


def petite(p, w):
    im = Image.open(p).convert("RGB")
    return im.resize((w, round(w * im.height / im.width)), Image.LANCZOS)


for p in sorted(src.glob("*.png")):
    petite(p, 960).save(out / "vrai" / p.name, optimize=True)
if (src / "journal.txt").exists():
    shutil.copy(src / "journal.txt", out / "journal.txt")

# planche de tous les styles (4 par ligne)
styles = sorted(src.glob("style-*.png"))
if styles:
    cw, ch, cols = 480, 270, 4
    pl = Image.new("RGB", (cols * cw, -(-len(styles) // cols) * (ch + 22)), "#111111")
    d = ImageDraw.Draw(pl)
    for i, p in enumerate(styles):
        x, y = (i % cols) * cw, (i // cols) * (ch + 22)
        pl.paste(petite(p, cw), (x, y + 22))
        d.text((x + 6, y + 5), p.stem[6:], fill="#ffffff")
    pl.save(out / "planche-styles.png", optimize=True)

# maquette / vrai bureau, côte à côte
lignes = [f"{len(styles)} styles photographiés"]
for p in sorted(src.glob("design-*.png")):
    if p.stem.endswith("-menu"):
        continue
    sid = p.stem[7:]
    maq = designs / f"{sid}.png"
    if not maq.exists():
        continue
    a, b = petite(maq, 800), petite(p, 800)
    im = Image.new("RGB", (1620, a.height + 30), "#111111")
    im.paste(a, (0, 30))
    im.paste(b, (820, 30))
    d = ImageDraw.Draw(im)
    d.text((8, 9), "Maquette (Studio)", fill="#ffffff")
    d.text((828, 9), "Vrai Thomas OS (KDE)", fill="#ffffff")
    im.save(out / f"{sid}-comparaison.png", optimize=True)
    ecart = ImageStat.Stat(ImageChops.difference(petite(maq, 192).convert("L"), petite(p, 192).convert("L"))).mean[0]
    lignes.append(f"design {sid} : écart moyen {ecart:.1f} / 255 (0 = identique)")
(out / "resume.txt").write_text("\n".join(lignes) + "\n", encoding="utf-8")
print("\n".join(lignes))
