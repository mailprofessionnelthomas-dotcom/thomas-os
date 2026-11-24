#!/usr/bin/env python3
"""Test VM (Phase 9) : le logo de démarrage et le fond de l'écran de connexion se voient-ils sur les photos ?

  logo.py DOSSIER

- DOSSIER/boot-*.png : photos prises pendant le démarrage. On cherche celle où le T rouge de Thomas OS est au
  centre d'un écran noir (thème Plymouth « thomas-os »). Elle est gardée sous 0-logo-demarrage.png, les autres
  sont effacées.
- DOSSIER/1-connexion.png : l'écran de connexion. Le fond Thomas OS est noir et rouge ; celui de Bazzite est
  violet et bleu.
Information seulement (code 0) : les photos dépendent de la vitesse de la VM.
"""
import glob
import os
import sys

from PIL import Image


def mesure_logo(chemin):
    im = Image.open(chemin).convert("RGB")
    w, h = im.size
    zone = list(im.crop((int(w * 0.38), int(h * 0.25), int(w * 0.62), int(h * 0.65))).getdata())
    rouge = sum(1 for r, g, b in zone if r > 170 and g < 80 and b < 80)
    sombre = sum(1 for r, g, b in zone if r < 40 and g < 40 and b < 40)
    return rouge, sombre / len(zone)


def main():
    dossier = sys.argv[1]
    photos = sorted(glob.glob(os.path.join(dossier, "boot-*.png")))
    meilleure, score = None, (0, 0.0)
    for p in photos:
        rouge, sombre = mesure_logo(p)
        if sombre > 0.5 and rouge > score[0]:
            meilleure, score = p, (rouge, sombre)
    if meilleure and score[0] > 300:
        print(f"OK      logo de démarrage Thomas OS affiché ({score[0]} px rouges au centre, fond noir à "
              f"{score[1]:.0%}) : {os.path.basename(meilleure)} sur {len(photos)} photos")
        os.replace(meilleure, os.path.join(dossier, "0-logo-demarrage.png"))
    else:
        print(f"ATTENTION logo de démarrage pas vu sur les {len(photos)} photos du démarrage (trop rapide ?)")
        if photos:  # on garde celle du milieu pour comprendre
            os.replace(photos[len(photos) // 2], os.path.join(dossier, "0-demarrage-milieu.png"))
    for p in glob.glob(os.path.join(dossier, "boot-*.png")):
        os.remove(p)

    connexion = os.path.join(dossier, "1-connexion.png")
    if os.path.exists(connexion):
        px = list(Image.open(connexion).convert("RGB").resize((160, 100)).getdata())
        r = sum(p[0] for p in px) / len(px)
        b = sum(p[2] for p in px) / len(px)
        if r > b:
            print(f"OK      écran de connexion : fond noir et rouge de Thomas OS (rouge moyen {r:.0f} > bleu {b:.0f})")
        else:
            print(f"ATTENTION écran de connexion : fond plutôt bleu/violet (rouge {r:.0f}, bleu {b:.0f}) : fond de Bazzite ?")


if __name__ == "__main__":
    main()
