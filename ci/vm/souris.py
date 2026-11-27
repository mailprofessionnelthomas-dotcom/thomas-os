#!/usr/bin/env python3
"""Test de démarrage : bouge la souris de la VM et clique, comme une vraie souris (moniteur QEMU).

La souris de la VM est relative (PS/2) et l'ordinateur l'accélère : les déplacements sont approximatifs. On part
donc d'un coin de l'écran, et on vise une zone large (par exemple un terminal plein écran rempli de texte).

Usage : souris.py SOCKET_MONITEUR ACTION [ACTION…]
  bas-gauche              pousse le pointeur dans le coin en bas à gauche
  DX,DY                   petit déplacement (en 10 pas lents), par exemple 40,-60 = un peu à droite et vers le haut
  clic | double-clic | triple-clic   bouton gauche
"""
import socket
import sys
import time

s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])
time.sleep(0.5)
s.recv(65536)


def envoyer(commande, pause=0.03):
    s.sendall(f"{commande}\n".encode())
    time.sleep(pause)


for action in sys.argv[2:]:
    if action == "bas-gauche":
        for _ in range(40):
            envoyer("mouse_move -200 200")
    elif action in ("clic", "double-clic", "triple-clic"):
        for _ in range({"clic": 1, "double-clic": 2, "triple-clic": 3}[action]):
            envoyer("mouse_button 1", 0.05)
            envoyer("mouse_button 0", 0.08)
    else:
        dx, dy = (int(v) for v in action.split(","))
        for _ in range(10):
            envoyer(f"mouse_move {round(dx / 10)} {round(dy / 10)}", 0.05)
    time.sleep(0.3)
s.close()
print("souris :", " ".join(sys.argv[2:]))
