#!/usr/bin/python3
"""Thomas OS : fabrique le thème de démarrage Plymouth « thomas-os » (logo T animé sur fond noir).

Usage : plymouth.py DOSSIER
Écrit DOSSIER/thomas-os.plymouth et les images du module « two-step » de Plymouth :
  throbber-0001.png… : le T rouge, un halo qui respire et un reflet qui le traverse (boucle de 1,6 s) ;
  animation-0001.png : image fixe (fin d'animation, inutilisée mais attendue par le module).
Les images de la fenêtre de mot de passe (lock.png, entry.png…) sont copiées depuis le thème « spinner » par
build.sh. Couleurs : identite/tokens.json. Python standard uniquement (lancé pendant le build de l'image).
"""
import json
import math
import struct
import sys
import zlib
from pathlib import Path

# Mêmes points que identite/logo/thomas-os.svg et identite/fond.py (repère 0..1)
T_BARRE = [(0.10, 0.14), (0.90, 0.14), (0.84, 0.30), (0.16, 0.30)]
T_JAMBE = [(0.41, 0.36), (0.59, 0.36), (0.59, 0.78), (0.50, 0.90), (0.41, 0.78)]
TAILLE = 160          # côté des images (px) ; le T en occupe 62 %
IMAGES = 48           # images par boucle (Plymouth en affiche environ 30 par seconde)
SURECH = 4            # suréchantillonnage pour lisser les bords du T


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def dedans(poly, x, y):
    """Point dans un polygone convexe (sommets dans le sens horaire ou anti-horaire)."""
    signe = 0
    n = len(poly)
    for i in range(n):
        (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % n]
        c = (x2 - x1) * (y - y1) - (y2 - y1) * (x - x1)
        if c:
            s = 1 if c > 0 else -1
            if signe and s != signe:
                return False
            signe = s
    return True


def dist_segment(px, py, a, b):
    (x1, y1), (x2, y2) = a, b
    dx, dy = x2 - x1, y2 - y1
    t = max(0.0, min(1.0, ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (x1 + t * dx), py - (y1 + t * dy))


def formes():
    """Couverture du T (0..1) et distance au T (px), calculées une seule fois."""
    cote = 0.62 * TAILLE
    o = (TAILLE - cote) / 2
    polys = [[(o + x * cote, o + y * cote) for x, y in p] for p in (T_BARRE, T_JAMBE)]
    couv = [0.0] * (TAILLE * TAILLE)
    dist = [0.0] * (TAILLE * TAILLE)
    pas = 1.0 / SURECH
    for y in range(TAILLE):
        for x in range(TAILLE):
            n = 0
            for sy in range(SURECH):
                for sx in range(SURECH):
                    px, py = x + (sx + 0.5) * pas, y + (sy + 0.5) * pas
                    if dedans(polys[0], px, py) or dedans(polys[1], px, py):
                        n += 1
            i = y * TAILLE + x
            couv[i] = n / (SURECH * SURECH)
            if couv[i] < 1.0:
                cx, cy = x + 0.5, y + 0.5
                dist[i] = min(dist_segment(cx, cy, p[k], p[(k + 1) % len(p)]) for p in polys for k in range(len(p)))
    return couv, dist


def image(couv, dist, k, rouge, clair):
    """Image k de la boucle, en RGBA (non prémultiplié)."""
    phase = 2 * math.pi * k / IMAGES
    halo = 0.22 + 0.26 * (0.5 - 0.5 * math.cos(phase))     # le halo respire
    moitie = IMAGES // 2
    reflet = -0.25 + 1.5 * k / moitie if k < moitie else None  # le reflet traverse pendant la 1re moitié
    sigma = 0.075 * TAILLE
    raw = bytearray()
    for y in range(TAILLE):
        raw.append(0)
        for x in range(TAILLE):
            i = y * TAILLE + x
            c = couv[i]
            a_halo = halo * math.exp(-(dist[i] / sigma) ** 2) * (1.0 - c) if dist[i] < 4 * sigma else 0.0
            h = 0.0
            if c and reflet is not None:
                u = (x + y) / (2.0 * TAILLE)
                h = 0.85 * math.exp(-((u - reflet) / 0.07) ** 2)
            t_col = [rouge[j] + (clair[j] - rouge[j]) * h for j in range(3)]
            a = c + a_halo
            if a <= 0.0:
                raw += b"\x00\x00\x00\x00"
                continue
            col = [(t_col[j] * c + rouge[j] * a_halo) / a for j in range(3)]
            raw += bytes([min(255, int(col[0] + 0.5)), min(255, int(col[1] + 0.5)),
                          min(255, int(col[2] + 0.5)), min(255, int(min(1.0, a) * 255 + 0.5))])
    return raw


def png(chemin, W, H, raw):
    def bloc(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    chemin.write_bytes(b"\x89PNG\r\n\x1a\n" + bloc(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0))
                       + bloc(b"IDAT", zlib.compress(bytes(raw), 9)) + bloc(b"IEND", b""))


def theme(dossier, fond):
    f = "0x%02x%02x%02x" % fond
    sections_maj = [("updates", "Installation des mises à jour…"), ("system-upgrade", "Mise à niveau du système…"),
                    ("firmware-upgrade", "Mise à jour du micrologiciel…"), ("system-reset", "Réinitialisation…")]
    texte = f"""[Plymouth Theme]
Name=Thomas OS
Description=Logo T de Thomas OS, animé, sur fond noir
ModuleName=two-step

[two-step]
Font=Cantarell 12
TitleFont=Cantarell Light 30
ImageDir={dossier}
DialogHorizontalAlignment=.5
DialogVerticalAlignment=.382
TitleHorizontalAlignment=.5
TitleVerticalAlignment=.382
HorizontalAlignment=.5
VerticalAlignment=.45
Transition=none
TransitionDuration=0.0
BackgroundStartColor={f}
BackgroundEndColor={f}
ProgressBarBackgroundColor=0x222328
ProgressBarForegroundColor=0xff0000
MessageBelowAnimation=true

[boot-up]
UseEndAnimation=false
UseFirmwareBackground=false

[shutdown]
UseEndAnimation=false
UseFirmwareBackground=false

[reboot]
UseEndAnimation=false
UseFirmwareBackground=false
"""
    for nom, titre in sections_maj:
        texte += f"""
[{nom}]
SuppressMessages=true
ProgressBarShowPercentComplete=true
UseProgressBar=true
Title={titre}
SubTitle=N'éteins pas l'ordinateur
"""
    return texte


def main():
    dossier = Path(sys.argv[1])
    dossier.mkdir(parents=True, exist_ok=True)
    racine = Path(__file__).resolve().parent
    jetons = json.loads((racine / "tokens.json").read_text(encoding="utf-8"))["couleurs"]
    rouge, clair, fond = hex_rgb(jetons["rouge"]), (255, 196, 196), hex_rgb(jetons["noir"])
    couv, dist = formes()
    for k in range(IMAGES):
        png(dossier / f"throbber-{k + 1:04d}.png", TAILLE, TAILLE, image(couv, dist, k, rouge, clair))
    png(dossier / "animation-0001.png", TAILLE, TAILLE, image(couv, dist, IMAGES - 1, rouge, clair))
    (dossier / "thomas-os.plymouth").write_text(theme(dossier, fond), encoding="utf-8")
    print(f"thème Plymouth écrit : {dossier} ({IMAGES} images de {TAILLE} px)")


if __name__ == "__main__":
    main()
