#!/bin/bash
# Banc d'essai Thomas OS (utilisateur « banc ») : KWin + Plasma dans l'écran virtuel, une photo par style et par design.
set -uo pipefail
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE XDG_SESSION_DESKTOP=KDE KDE_FULL_SESSION=true KDE_SESSION_VERSION=6
export LIBGL_ALWAYS_SOFTWARE=1  # pas de carte graphique sur GitHub : rendu OpenGL par le processeur (llvmpipe)
export QT_FORCE_STDERR_LOGGING=1 KWIN_SCREENSHOT_NO_PERMISSION_CHECKS=1
dire() { echo "[banc] $*"; }
photo() {  # photo de tout l'écran, demandée à KWin ; Spectacle (l'outil de capture de KDE) en secours
  timeout 30 python3 /banc/capture.py "/sortie/$1.png" >/tmp/capture.log 2>&1 \
    || timeout 30 spectacle -b -n -f -o "/sortie/$1.png" >>/tmp/capture.log 2>&1
  if [ -s "/sortie/$1.png" ]; then dire "photo $1 : $(stat -c %s "/sortie/$1.png") octets, $(tail -1 /tmp/capture.log)"
  else dire "photo $1 ratée :"; grep -v '^$' /tmp/capture.log | tail -6; fi
}
pret() { gdbus introspect --session --dest "$1" --object-path "$2" >/dev/null 2>&1; }
placer() {  # place la fenêtre Dolphin comme dans la maquette (script KWin)
  cat > /tmp/placer.js <<EOF
workspace.windowList().forEach(function (w) {
  if (String(w.resourceClass).indexOf("dolphin") >= 0) w.frameGeometry = {x: $1, y: $2, width: $3, height: $4};
});
EOF
  local n
  n="$(gdbus call --session --dest org.kde.KWin --object-path /Scripting --method org.kde.kwin.Scripting.loadScript \
    /tmp/placer.js "placer$RANDOM" | grep -oE '[0-9]+' | head -1)"
  gdbus call --session --dest org.kde.KWin --object-path "/Scripting/Script${n}" --method org.kde.kwin.Script.run >/dev/null 2>&1 \
    || dire "placement de la fenêtre impossible"
}

dire "périphériques de rendu : $(ls /dev/dri 2>/dev/null | tr '\n' ' ')"
( QT_LOGGING_RULES='kwin_*.debug=true' kwin_wayland --virtual --width 1920 --height 1080 \
    --socket wayland-banc --no-lockscreen >/tmp/kwin.log 2>&1; echo "KWin terminé, code $?" >>/tmp/kwin.log ) &
for _ in $(seq 40); do [ -S "$XDG_RUNTIME_DIR/wayland-banc" ] && break; sleep 0.5; done
sleep 5
pgrep -x kwin_wayland >/dev/null || { dire "KWin s'est arrêté :"; grep -v '^$' /tmp/kwin.log | tail -25; exit 1; }
command -v spectacle >/dev/null || { dire "Spectacle absent de l'image : pas de photo possible"; exit 1; }
dire "KWin tourne"
export WAYLAND_DISPLAY=wayland-banc QT_QPA_PLATFORM=wayland
gdbus call --session --dest org.kde.KWin --object-path /KWin --method org.kde.KWin.supportInformation 2>/dev/null \
  | sed 's/\\n/\n/g' | grep -E "KWin version|Compositing Type|OpenGL renderer string|OpenGL version string" | sed 's/^/[banc] /'
dire "journal KWin :"; grep -v '^$' /tmp/kwin.log | tail -8

plasma() {  # $1 = délai d'attente
  plasmashell --no-respawn >/tmp/plasma.log 2>&1 &
  for _ in $(seq "$1"); do pret org.kde.plasmashell /PlasmaShell && return 0; pgrep -x plasmashell >/dev/null || break; sleep 1; done
  dire "Plasma ne démarre pas ($( [ -n "${QT_QUICK_BACKEND:-}" ] && echo 'rendu logiciel' || echo 'OpenGL')) :"
  grep -v '^$' /tmp/plasma.log | tail -25
  return 1
}
plasma 90 || { export QT_QUICK_BACKEND=software; plasma 90; } || exit 1
sleep 12
dire "processus : $(pgrep -l -f 'plasmashell|kded6|kactivitymanagerd' | tr '\n' ' ')"
echo 'workspace.windowList().forEach(function (w) { print("FENETRE " + w.resourceClass + " | " + w.caption + " | " + w.frameGeometry.width + "x" + w.frameGeometry.height + " | bureau=" + w.desktopWindow + " | visible=" + !w.hidden); });' > /tmp/liste.js
n="$(gdbus call --session --dest org.kde.KWin --object-path /Scripting --method org.kde.kwin.Scripting.loadScript /tmp/liste.js liste | grep -oE '[0-9]+' | head -1)"
gdbus call --session --dest org.kde.KWin --object-path "/Scripting/Script${n}" --method org.kde.kwin.Script.run >/dev/null 2>&1
sleep 2; grep -o 'FENETRE.*' /tmp/kwin.log | sed 's/^/[banc] /' | head -12
photo "00-demarrage"
timeout 30 spectacle -b -n -f -o /sortie/00-spectacle.png >/tmp/spectacle.log 2>&1
dire "Spectacle : $(stat -c %s /sortie/00-spectacle.png 2>/dev/null || echo 'rien') octets $(grep -v '^$' /tmp/spectacle.log | tail -2 | tr '\n' ' ')"

for f in /usr/share/thomas-os/styles/*.conf; do
  pgrep -x kwin_wayland >/dev/null || break
  id="$(basename "$f" .conf)"
  dire "style $id"
  timeout 90 thomas-style appliquer "$id" 2>&1 | tail -4
  sleep 7
  photo "style-$id"
done

for j in /designs/*.json; do
  [ -f "$j" ] && pgrep -x kwin_wayland >/dev/null || continue
  id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("id",""))' "$j")"
  [ -f "/usr/share/thomas-os/styles/$id.conf" ] || { dire "design $id : pas encore transformé en style"; continue; }
  dire "design $id"
  timeout 90 thomas-style appliquer "$id" 2>&1 | tail -4
  read -r x y l h < <(python3 -c 'import json,sys; f=json.load(open(sys.argv[1]))["fenetres"]; print(f["x"],f["y"],f["l"],f["h"])' "$j")
  dolphin --new-window "$HOME" >/dev/null 2>&1 &
  sleep 8
  placer "$x" "$y" "$l" "$h"
  sleep 3
  photo "design-$id"
  gdbus call --session --dest org.kde.plasmashell --object-path /PlasmaShell --method org.kde.PlasmaShell.activateLauncherMenu >/dev/null 2>&1
  sleep 3
  photo "design-$id-menu"
  gdbus call --session --dest org.kde.plasmashell --object-path /PlasmaShell --method org.kde.PlasmaShell.activateLauncherMenu >/dev/null 2>&1
  pkill -x dolphin
  sleep 2
done

pgrep -x kwin_wayland >/dev/null || { dire "KWin s'est arrêté pendant le banc :"; grep -v '^$' /tmp/kwin.log | tail -15; }
n="$(ls /sortie/*.png 2>/dev/null | wc -l)"
dire "terminé : $n photo(s). Messages d'erreur les plus fréquents (Plasma, KWin) :"
cat /tmp/plasma.log /tmp/kwin.log | grep -iE "error|failed|cannot|not found" | sed -E 's/[0-9]+//g' | sort | uniq -c | sort -rn | head -20
[ "$n" -gt 0 ]
