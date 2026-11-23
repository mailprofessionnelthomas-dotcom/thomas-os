#!/usr/bin/python3
"""Thomas OS : fabrique le fond d'écran principal (noir et rouge abstrait + grand T discret au centre).

Usage : fond.py DOSSIER [LARGEUR HAUTEUR]
Écrit un paquet de fond d'écran KDE : DOSSIER/metadata.json, DOSSIER/contents/images/LxH.png,
DOSSIER/contents/screenshot.png. Python standard uniquement (lancé pendant le build de l'image).
"""
import json
import math
import struct
import sys
import zlib
from pathlib import Path

# Mêmes points que identite/logo/thomas-os.svg (repère 0..1)
T_BARRE = [(0.10, 0.14), (0.90, 0.14), (0.84, 0.30), (0.16, 0.30)]
T_JAMBE = [(0.41, 0.36), (0.59, 0.36), (0.59, 0.78), (0.50, 0.90), (0.41, 0.78)]
NOIR = (5, 5, 6)
# lueurs : (centre x, centre y, rayon (× largeur), couleur, intensité)
LUEURS = [(0.12, 0.98, 0.30, (170, 0, 12), 0.75), (0.92, 0.02, 0.20, (130, 0, 10), 0.55),
          (0.50, 0.50, 0.14, (70, 0, 6), 0.40)]
TRAIT = ((0.0, 0.80), (1.0, 0.34), 0.018, (255, 30, 40), 0.09)  # filet lumineux en diagonale


def intervalles(poly, y):
    """Abscisses où la ligne y coupe le polygone convexe (min, max) ou None."""
    xs = []
    n = len(poly)
    for i in range(n):
        (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % n]
        if (y1 <= y < y2) or (y2 <= y < y1):
            xs.append(x1 + (y - y1) * (x2 - x1) / (y2 - y1))
    return (min(xs), max(xs)) if len(xs) >= 2 else None


def rendre(W, H):
    taille_t = 0.40 * H
    ox, oy = (W - taille_t) / 2, (H - taille_t) / 2 - 0.02 * H
    polys = [[(ox + x * taille_t, oy + y * taille_t) for x, y in p] for p in (T_BARRE, T_JAMBE)]
    (ax, ay), (bx, by), larg, coul_t, int_t = TRAIT
    ax, ay, bx, by = ax * W, ay * H, bx * W, by * H
    nx, ny = by - ay, ax - bx
    norme = math.hypot(nx, ny)
    nx, ny = nx / norme, ny / norme
    sig2 = (larg * H) ** 2
    lueurs = [(cx * W, cy * H, (r * W) ** 2, c, k) for cx, cy, r, c, k in LUEURS]
    raw = bytearray()
    for y in range(H):
        yc = y + 0.5
        dy2 = [(yc - cy) ** 2 for _, cy, _, _, _ in lueurs]
        couv = [0.0] * W
        for p in polys:  # couverture du T sur la ligne (bords lissés)
            iv = intervalles(p, yc)
            if iv:
                x0, x1 = iv
                for x in range(max(0, int(x0)), min(W, int(x1) + 1)):
                    couv[x] = max(couv[x], min(1.0, min(x + 1, x1) - max(x, x0)))
        ligne = bytearray(W * 3)
        dl0 = (ax - 0.0) * nx + (ay - yc) * ny
        for x in range(W):
            r, g, b = NOIR
            xc = x + 0.5
            for i, (cx, _, r2, c, k) in enumerate(lueurs):
                f = k * math.exp(-((xc - cx) ** 2 + dy2[i]) / r2)
                r += c[0] * f
                g += c[1] * f
                b += c[2] * f
            d = dl0 - xc * nx
            f = int_t * math.exp(-d * d / sig2)
            r += coul_t[0] * f
            g += coul_t[1] * f
            b += coul_t[2] * f
            if couv[x]:  # T discret : un peu plus clair et plus rouge que le fond
                r += 34 * couv[x]
                g += 6 * couv[x]
                b += 8 * couv[x]
            tr = ((x * 7 + y * 13) % 5 - 2) * 0.35  # tramage : pas de bandes dans les dégradés
            j = x * 3
            ligne[j] = min(255, max(0, int(r + tr)))
            ligne[j + 1] = min(255, max(0, int(g + tr)))
            ligne[j + 2] = min(255, max(0, int(b + tr)))
        raw += b"\x00" + ligne
    return raw


def png(chemin, W, H, raw):
    def bloc(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    chemin.parent.mkdir(parents=True, exist_ok=True)
    chemin.write_bytes(b"\x89PNG\r\n\x1a\n" + bloc(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
                       + bloc(b"IDAT", zlib.compress(bytes(raw), 9)) + bloc(b"IEND", b""))


def main():
    dossier = Path(sys.argv[1])
    W, H = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (2560, 1440)
    png(dossier / f"contents/images/{W}x{H}.png", W, H, rendre(W, H))
    png(dossier / "contents/screenshot.png", 400, 225, rendre(400, 225))
    (dossier / "metadata.json").write_text(json.dumps({"KPlugin": {
        "Id": "ThomasOS", "Name": "Thomas OS", "License": "CC-BY-SA-4.0",
        "Authors": [{"Name": "Thomas OS"}]}}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"fond d'écran écrit : {dossier} ({W}x{H})")


if __name__ == "__main__":
    main()
