#!/usr/bin/python3
"""Banc d'essai : photo de l'écran demandée directement à KWin (org.kde.KWin.ScreenShot2), sans Spectacle.

Usage : capture.py FICHIER.png
"""
import os
import struct
import sys
import zlib

from gi.repository import Gio, GLib

bus = Gio.bus_get_sync(Gio.BusType.SESSION)
r, w = os.pipe()
opts = {"include-cursor": GLib.Variant("b", False), "native-resolution": GLib.Variant("b", True)}
res, _ = bus.call_with_unix_fd_list_sync(
    "org.kde.KWin", "/org/kde/KWin/ScreenShot2", "org.kde.KWin.ScreenShot2", "CaptureWorkspace",
    GLib.Variant("(a{sv}h)", (opts, 0)), GLib.VariantType("(a{sv})"), Gio.DBusCallFlags.NONE, 30000,
    Gio.UnixFDList.new_from_array([w]), None)
os.close(w)
info = res.unpack()[0]
with os.fdopen(r, "rb") as f:
    data = f.read()
W, H, stride, fmt = info["width"], info["height"], info["stride"], info["format"]
# formats QImage : 4/5/6 = (A)RGB32 -> octets B,G,R,A ; 16/17/18 = RGB(X/A)8888 -> octets R,G,B,A
bgr = fmt in (4, 5, 6)
raw = bytearray()
for y in range(H):
    ligne = data[y * stride:y * stride + W * 4]
    raw += b"\x00"
    if bgr:
        px = bytearray(W * 3)
        px[0::3], px[1::3], px[2::3] = ligne[2::4], ligne[1::4], ligne[0::4]
    else:
        px = bytearray(W * 3)
        px[0::3], px[1::3], px[2::3] = ligne[0::4], ligne[1::4], ligne[2::4]
    raw += px


def bloc(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)


with open(sys.argv[1], "wb") as f:
    f.write(b"\x89PNG\r\n\x1a\n" + bloc(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
            + bloc(b"IDAT", zlib.compress(bytes(raw), 6)) + bloc(b"IEND", b""))
moy = sum(raw[1:W * 3:3]) / max(1, W)
print(f"capture {W}x{H} format {fmt}, rouge moyen 1re ligne {moy:.0f}")
