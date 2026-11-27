#!/usr/bin/env bash
# Inspection : raccourcis de Konsole (copier/coller), fichiers .rc embarqués, keytabs, outils du presse-papiers.
set -uo pipefail

t() { echo; echo "=== $* ==="; }

t "Versions"
rpm -q konsole kf6-kxmlgui qt6-qtbase python3 2>&1

t "Fichiers de Konsole"
rpm -ql konsole | grep -E '\.so|/bin/|keytab|\.rc$|konsolerc|kxmlgui' | head -40

t "Config système existante"
ls -la /etc/xdg/konsolerc /usr/share/konsole 2>&1
cat /etc/xdg/konsolerc 2>/dev/null

t "Outils presse-papiers"
for c in wl-copy wl-paste qdbus6 qdbus gdbus xclip; do printf '%s : %s\n' "$c" "$(command -v "$c" || echo absent)"; done

t "Fichiers .rc embarqués dans Konsole (ressources Qt)"
python3 -I - <<'EOF'
import re, zlib, glob, os
try:
    from compression import zstd
except Exception:
    zstd = None
libs = [p for p in glob.glob('/usr/lib64/**/*konsole*.so*', recursive=True) + ['/usr/bin/konsole'] if os.path.isfile(p) and not os.path.islink(p)]
vus = set()
def montrer(src, texte):
    m = re.search(r'<gui[^>]*name="([^"]+)"[^>]*', texte)
    if not m:
        return
    entete = m.group(0)
    if entete in vus:
        return
    vus.add(entete)
    print(f'--- {src} : {entete}')
    noms = re.findall(r'<Action name="([^"]+)"', texte)
    print('    actions :', ' '.join(sorted(set(noms))))
    ap = re.search(r'<ActionProperties.*?</ActionProperties>', texte, re.S)
    if ap:
        print('    ActionProperties :', ap.group(0)[:1500])
for lib in libs:
    data = open(lib, 'rb').read()
    print(f'{lib} : {len(data)} octets')
    # texte en clair
    for m in re.finditer(rb'<!DOCTYPE gui|<gui ', data):
        bloc = data[m.start():m.start() + 20000]
        fin = bloc.find(b'</gui>')
        if fin > 0:
            montrer(lib + ' (clair)', bloc[:fin + 6].decode('utf-8', 'replace'))
    # zlib (rcc : 4 octets de taille puis flux zlib)
    for m in re.finditer(rb'\x78[\x9c\xda\x01\x5e]', data):
        try:
            d = zlib.decompressobj().decompress(data[m.start():m.start() + 200000])
        except Exception:
            continue
        if b'<gui' in d[:4000]:
            montrer(lib + ' (zlib)', d.decode('utf-8', 'replace'))
    # zstd
    if zstd:
        for m in re.finditer(rb'\x28\xb5\x2f\xfd', data):
            try:
                d = zstd.ZstdDecompressor().decompress(data[m.start():m.start() + 200000])
            except Exception:
                continue
            if b'<gui' in d[:4000]:
                montrer(lib + ' (zstd)', d.decode('utf-8', 'replace'))
print('fichiers .rc trouvés :', len(vus))
EOF

t "Chaînes utiles (noms d'actions, signaux)"
for lib in /usr/lib64/libkonsoleprivate.so* /usr/lib64/qt6/plugins/konsolepart.so /usr/lib64/qt6/plugins/kf6/parts/konsolepart.so; do
  [[ -f "$lib" && ! -L "$lib" ]] || continue
  echo "--- $lib"
  python3 -I -c '
import re,sys
d=open(sys.argv[1],"rb").read()
mots=set(re.findall(rb"[a-z][a-z0-9]*(?:[-_][a-z0-9]+)+", d))
print(" ".join(sorted(m.decode() for m in mots if re.search(rb"signal|copy|paste|select|clipboard|interrupt|sigint", m))))
' "$lib"
done

t "Keytabs"
ls /usr/share/konsole/*.keytab 2>&1
for k in /usr/share/konsole/default.keytab; do [[ -f "$k" ]] && { echo "--- $k"; grep -nE 'Ctrl|^keyboard' "$k" | head -40; }; done

t "Profils Konsole système"
ls /usr/share/konsole/*.profile 2>&1; cat /usr/share/konsole/*.profile 2>/dev/null | head -40
