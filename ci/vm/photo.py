#!/usr/bin/env python3
"""Test de démarrage : photo de l'écran de la VM via le moniteur QEMU, en PNG.

Usage : photo.py SOCKET_MONITEUR FICHIER.png
"""
import os
import socket
import sys
import time

from PIL import Image

sock, sortie = sys.argv[1], os.path.abspath(sys.argv[2])
ppm = sortie + ".ppm"
s = socket.socket(socket.AF_UNIX)
s.connect(sock)
time.sleep(0.5)
s.recv(65536)
s.sendall(f"screendump {ppm}\n".encode())
for _ in range(20):
    time.sleep(0.5)
    if os.path.exists(ppm) and os.path.getsize(ppm) > 0:
        break
s.close()
time.sleep(1)
Image.open(ppm).save(sortie, optimize=True)
os.remove(ppm)
print(f"photo : {sortie}")
