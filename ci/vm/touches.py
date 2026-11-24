#!/usr/bin/env python3
"""Test de démarrage : appuie sur des touches dans la VM, comme un vrai clavier (moniteur QEMU « sendkey »).

Usage : touches.py SOCKET_MONITEUR TOUCHE [TOUCHE…]   (ex. alt-spc, esc, ctrl-alt-t)
"""
import socket
import sys
import time

s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])
time.sleep(0.5)
s.recv(65536)
for touche in sys.argv[2:]:
    s.sendall(f"sendkey {touche}\n".encode())
    time.sleep(0.6)
s.close()
print("touches :", " ".join(sys.argv[2:]))
