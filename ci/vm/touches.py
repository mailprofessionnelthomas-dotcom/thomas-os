#!/usr/bin/env python3
"""Test de démarrage : appuie sur des touches dans la VM, comme un vrai clavier (moniteur QEMU « sendkey »).

Usage : touches.py SOCKET_MONITEUR TOUCHE [TOUCHE…]
  TOUCHE : nom QEMU (alt-spc, esc, ret, down, end, ctrl-x…), ou « texte:… » pour taper un texte
  (clavier américain, comme le menu de démarrage et l'écran MOK).
"""
import socket
import sys
import time

SPECIAUX = {" ": "spc", "=": "equal", ",": "comma", ".": "dot", "/": "slash", "-": "minus", ":": "shift-semicolon",
            "_": "shift-minus", ";": "semicolon"}


def touches_du_texte(texte):
    for c in texte:
        if c in SPECIAUX:
            yield SPECIAUX[c]
        elif c.isupper():
            yield f"shift-{c.lower()}"
        else:
            yield c


s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])
time.sleep(0.5)
s.recv(65536)
for arg in sys.argv[2:]:
    for touche in (touches_du_texte(arg[6:]) if arg.startswith("texte:") else [arg]):
        s.sendall(f"sendkey {touche}\n".encode())
        time.sleep(0.15 if arg.startswith("texte:") else 0.6)
    time.sleep(0.3)
s.close()
print("touches :", " ".join(a if not a.startswith("texte:") else "(texte)" for a in sys.argv[2:]))
