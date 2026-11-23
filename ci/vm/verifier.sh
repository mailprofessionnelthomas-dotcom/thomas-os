#!/bin/bash
# Test de démarrage : exécuté DANS la machine virtuelle, en root (clé SSH jetable). $MDP = mot de passe jetable
# du compte « testeur » créé pour ouvrir une vraie session.
#   demarrage : le système a-t-il bien démarré, est-ce bien Thomas OS ?
#   session   : la 1re ouverture de session pose-t-elle le style par défaut (comme sur un vrai PC) ?
#   applis    : les applis Flatpak prévues s'installent-elles toutes seules ? (information seulement)
set -uo pipefail
erreurs=0
ok() { echo "OK      $*"; }
ko() { echo "ECHEC   $*"; erreurs=$((erreurs + 1)); }
info() { echo "INFO    $*"; }
en_root() { "$@"; }

case "${1:-}" in
demarrage)
    etat="$(timeout 300 systemctl is-system-running --wait 2>/dev/null)"
    if [[ "${etat}" == running || "${etat}" == degraded ]]; then ok "démarrage terminé (${etat})"; else ko "démarrage pas terminé (${etat:-?})"; fi
    systemctl --failed --no-legend --plain | awk '{print $1}' | sed 's/^/INFO    service en échec : /'
    if grep -q '^NAME="Thomas OS"' /usr/lib/os-release; then ok "c'est bien Thomas OS"; else ko "os-release"; fi
    if . /usr/share/thomas-os/info.env 2>/dev/null; then ok "version ${THOMAS_OS_VERSION}, variante ${THOMAS_OS_GPU_VARIANT}"; else ko "info.env absent"; fi
    img="$(en_root bootc status --format json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["status"]["booted"]["image"]["image"]["image"])' 2>/dev/null)"
    if [[ "${img}" == *thomas-os* ]]; then ok "les mises à jour suivent ${img}"; else ko "bootc : image suivie inconnue (${img:-?})"; fi
    if systemctl is-active --quiet display-manager; then ok "écran de connexion lancé"; else ko "écran de connexion absent"; fi
    if systemctl is-enabled --quiet thomas-flatpak-preinstall.timer; then ok "installation des applis programmée"; else ko "timer des applis"; fi
    if [[ "$(readlink -f /etc/systemd/system/rpm-ostree-countme.timer)" == /dev/null ]]; then ok "télémétrie Fedora coupée"; else ko "compteur Fedora actif"; fi
    ;;
preparer)
    # compte de test + ouverture de session automatique, puis redémarrage (elle ne se fait qu'au démarrage).
    # Bazzite utilise Plasma Login Manager (constaté), un dérivé de SDDM : même format de config.
    id testeur >/dev/null 2>&1 || useradd -m -G wheel testeur
    echo "testeur:${MDP}" | chpasswd
    info "gestionnaire de connexion : $(systemctl show -p ExecStart --value display-manager | grep -o 'path=[^ ;]*' | head -1)"
    info "ses fichiers : $(find /etc /usr/lib /usr/share -maxdepth 2 -iname '*plasmalogin*' 2>/dev/null | tr '\n' ' ')"
    for d in /etc/plasmalogin.conf.d /etc/sddm.conf.d; do
        mkdir -p "${d}"
        printf "[Autologin]\nUser=testeur\nSession=plasma\n" >"${d}/zz-test-vm.conf"
    done
    systemd-run --on-active=3 systemctl reboot >/dev/null && ok "redémarrage demandé"
    ;;
session)
    for _ in $(seq 90); do pgrep -u testeur -x plasmashell >/dev/null && break; sleep 2; done
    if pgrep -u testeur -x plasmashell >/dev/null; then ok "session Plasma ouverte"; else
        ko "pas de session Plasma"
        loginctl list-sessions --no-legend | sed 's/^/INFO    session : /'
        journalctl -b -u display-manager --no-pager | tail -12 | sed 's/^/INFO    /'
    fi
    actuel="$(getent passwd testeur | cut -d: -f6)/.config/thomas-os/actuel.conf"
    for _ in $(seq 45); do [[ -f "${actuel}" ]] && break; sleep 2; done
    if [[ -f "${actuel}" ]]; then ok "style posé au 1er login ($(grep -m1 '^id' "${actuel}"))"; else ko "style non posé au 1er login"; fi
    journalctl -b --no-pager _UID="$(id -u testeur)" 2>/dev/null | grep -iE 'thomas-style|⚠️|Erreur :' | tail -6 | sed 's/^/INFO    /'
    ;;
situation)
    # le bureau en usage : une fenêtre (Dolphin) et une notification, dans la session de « testeur »
    u="$(id -u testeur)"
    E=(XDG_RUNTIME_DIR="/run/user/${u}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${u}/bus" WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland)
    applets="$(getent passwd testeur | cut -d: -f6)/.config/plasma-org.kde.plasma.desktop-appletsrc"
    n="$(grep -c '^plugin=org.thomasos.barre$' "${applets}" 2>/dev/null)"
    if [[ "${n:-0}" -ge 2 ]]; then ok "barre Thomas OS en place (${n} moitiés autour du logo)"; else ko "barre Thomas OS absente (${n:-0})"; fi
    if grep -q '^plugin=org.thomasos.panneau$' "${applets}" 2>/dev/null; then ok "panneau rapide en place"; else ko "panneau rapide absent"; fi
    # Les réglages optionnels du panneau (Wi-Fi, Bluetooth, volume, luminosité) peuvent manquer sur un PC : information
    journal_qml="$(journalctl -b --no-pager _UID="${u}" 2>/dev/null | grep -i 'thomasos\|Panneau rapide' | grep -iE 'error|is not a type|unavailable|undefined|cannot|indisponible' | sort -u)"
    optionnels="$(grep -E '(Wifi|Bluetooth|Volume|Luminosite)\.qml|réglage indisponible' <<<"${journal_qml}" | tail -6)"
    erreurs_qml="$(grep -vE '(Wifi|Bluetooth|Volume|Luminosite)\.qml|réglage indisponible' <<<"${journal_qml}" | grep . | tail -6)"
    [[ -n "${optionnels}" ]] && echo "${optionnels}" | sed 's/^/INFO    réglage optionnel : /'
    if [[ -z "${erreurs_qml}" ]]; then ok "aucune erreur QML des widgets Thomas OS"; else ko "erreurs QML :"; echo "${erreurs_qml}" | sed 's/^/INFO    /'; fi
    runuser -u testeur -- env "${E[@]}" dolphin >/dev/null 2>&1 &
    sleep 8
    runuser -u testeur -- env "${E[@]}" notify-send -a "Thomas OS" -i thomas-os "Notification de test" "En bas à droite, 5 secondes"
    ;;
menu)
    u="$(id -u testeur)"
    runuser -u testeur -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${u}/bus" gdbus call --session --dest org.kde.plasmashell \
        --object-path /PlasmaShell --method org.kde.PlasmaShell.activateLauncherMenu >/dev/null && ok "menu ouvert"
    ;;
core)
    # Thomas Core : répond à la demande, puis s'arrête seul au repos
    u="$(id -u testeur)"
    appel() { runuser -u testeur -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${u}/bus" gdbus call --session \
        --dest org.thomasos.Core --object-path /org/thomasos/Core --method "$1" 2>&1; }
    r="$(appel org.thomasos.Systeme1.Infos)"
    if [[ "${r}" == *version* ]]; then ok "Thomas Core répond"; info "${r:0:300}"; else ko "Thomas Core ne répond pas : ${r:0:200}"; fi
    r="$(appel org.thomasos.Style1.Liste)"
    if [[ "${r}" == *thomas* ]]; then ok "Thomas Core liste les styles"; else ko "liste des styles : ${r:0:200}"; fi
    info "carte graphique : $(appel org.thomasos.Systeme1.CarteGraphique | head -c 200)"
    info "diagnostic : $(appel org.thomasos.Diagnostic1.Rapport | head -c 300)"
    sleep 75
    if pgrep -u testeur -f /usr/libexec/thomas-core >/dev/null; then ko "Thomas Core tourne encore après 75 s sans appel"
    else ok "Thomas Core s'arrête seul au repos"; fi
    ;;
control)
    # Thomas Control : s'ouvre, reste ouvert, sans erreur QML
    u="$(id -u testeur)"
    E=(XDG_RUNTIME_DIR="/run/user/${u}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${u}/bus" WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=wayland)
    runuser -u testeur -- env "${E[@]}" thomas-control >/tmp/control.log 2>&1 &
    sleep 6
    if pgrep -u testeur -x thomas-control >/dev/null; then ok "Thomas Control ouvert"; else ko "Thomas Control s'est fermé :"; tail -8 /tmp/control.log | sed 's/^/INFO    /'; fi
    e="$(grep -iE 'qml|error|warning' /tmp/control.log | grep -v 'Qt Quick Layouts' | sort -u | tail -6)"
    if [[ -z "${e}" ]]; then ok "aucune erreur QML dans Thomas Control"; else ko "messages de Thomas Control :"; echo "${e}" | sed 's/^/INFO    /'; fi
    ;;
applis)
    for _ in $(seq 72); do [[ -n "$(systemctl show -p ExecMainExitTimestamp --value thomas-flatpak-preinstall.service)" ]] && break; sleep 10; done
    info "service des applis : $(systemctl show -p Result --value thomas-flatpak-preinstall.service)"
    info "applis Flatpak installées : $(flatpak list --app --columns=application | tr '\n' ' ')"
    ;;
*)
    echo "usage : verifier.sh demarrage|preparer|session|situation|menu|core|control|applis"; exit 2 ;;
esac
exit $((erreurs > 0))
