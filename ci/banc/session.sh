#!/bin/bash
# Banc d'essai Thomas OS (utilisateur « banc ») : KWin + Plasma dans l'écran virtuel, une photo par style et par design.
set -uo pipefail
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE XDG_SESSION_DESKTOP=KDE KDE_FULL_SESSION=true KDE_SESSION_VERSION=6
export LIBGL_ALWAYS_SOFTWARE=1  # pas de carte graphique sur GitHub : rendu OpenGL par le processeur (llvmpipe)
export QT_FORCE_STDERR_LOGGING=1 KWIN_SCREENSHOT_NO_PERMISSION_CHECKS=1
MODE=x11
dire() { echo "[banc] $*"; }
photo() {  # x11 : demande la photo à la machine GitHub ; virtual : photo par Spectacle (outil de capture de KDE)
  if [ "$MODE" = virtual ]; then
    timeout 30 spectacle -b -n -f -o "/sortie/$1.png" >/tmp/spectacle.log 2>&1 || { dire "photo $1 ratée :"; tail -5 /tmp/spectacle.log; }
    return 0
  fi
  echo "$1" > /sortie/demande
  for _ in $(seq 100); do [ -f /sortie/ok ] && { rm -f /sortie/ok; return 0; }; sleep 0.3; done
  dire "photo $1 : pas de réponse"
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

kwin() {  # $@ = options d'affichage ; renvoie 0 si KWin tourne encore après 5 s
  rm -f "$XDG_RUNTIME_DIR"/wayland-banc*
  ( QT_LOGGING_RULES='kwin_*.debug=true' kwin_wayland "$@" --width 1920 --height 1080 \
      --socket wayland-banc --no-lockscreen >/tmp/kwin.log 2>&1; echo "KWin terminé, code $?" >>/tmp/kwin.log ) &
  for _ in $(seq 40); do [ -S "$XDG_RUNTIME_DIR/wayland-banc" ] && break; sleep 0.5; done
  sleep 5
  pgrep -x kwin_wayland >/dev/null && [ -S "$XDG_RUNTIME_DIR/wayland-banc" ] && return 0
  dire "KWin ($MODE) s'est arrêté :"; grep -v '^$' /tmp/kwin.log | tail -25
  return 1
}
if ! kwin --x11-display "$DISPLAY"; then
  MODE=virtual
  kwin --virtual || exit 1
fi
dire "KWin tourne (mode $MODE)"
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
photo "00-demarrage"

for f in /usr/share/thomas-os/styles/*.conf; do
  id="$(basename "$f" .conf)"
  dire "style $id"
  timeout 90 thomas-style appliquer "$id" 2>&1 | tail -4
  sleep 7
  photo "style-$id"
done

for j in /designs/*.json; do
  [ -f "$j" ] || continue
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

dire "terminé. Messages d'erreur les plus fréquents (Plasma, KWin) :"
cat /tmp/plasma.log /tmp/kwin.log | grep -iE "error|failed|cannot|not found" | sed -E 's/[0-9]+//g' | sort | uniq -c | sort -rn | head -20
