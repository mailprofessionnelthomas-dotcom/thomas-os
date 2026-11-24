#!/usr/bin/python3
"""Planche d'images en petit (pour les regarder d'un coup d'œil) : planche.py SORTIE.jpg IMAGE1 IMAGE2 …
Chaque image est réduite à 480 px de large, avec son nom au-dessus. Tourne sur GitHub (Pillow)."""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

L, COLS, TITRE = 480, 3, 18
images = [(Path(p).stem, Image.open(p).convert("RGB")) for p in sys.argv[2:] if Path(p).is_file()]
if not images:
    sys.exit("aucune image")
vignettes = [(nom, im.resize((L, round(im.height * L / im.width)))) for nom, im in images]
h = max(v.height for _, v in vignettes) + TITRE
lignes = -(-len(vignettes) // COLS)
planche = Image.new("RGB", (COLS * L, lignes * h), (30, 30, 30))
dessin = ImageDraw.Draw(planche)
for i, (nom, v) in enumerate(vignettes):
    x, y = (i % COLS) * L, (i // COLS) * h
    dessin.text((x + 4, y + 3), nom, fill=(230, 230, 230))
    planche.paste(v, (x, y + TITRE))
planche.save(sys.argv[1], quality=80)
print(f"{sys.argv[1]} : {len(vignettes)} images")
