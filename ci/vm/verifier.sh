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
# nom de l'écran Wayland de la session de « testeur » (pas forcément wayland-0 : constaté en VM)
ecran_wayland() { basename "$(ls /run/user/"$1"/wayland-[0-9]* 2>/dev/null | grep -v '\.lock$' | head -1)"; }
# appel d'une méthode de Thomas Core (interface Systeme1 par défaut) dans la session de « testeur »
style_core_systeme() {
    local u
    u="$(id -u testeur)"
    runuser -u testeur -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${u}/bus" gdbus call --session --timeout 90 \
        --dest org.thomasos.Core --object-path /org/thomasos/Core --method "org.thomasos.${2:-Systeme1}.$1" 2>&1
}
# appel d'une méthode Style1 de Thomas Core dans la session de « testeur » (arguments au format GVariant : "'texte'")
style_core() {
    local u
    u="$(id -u testeur)"
    runuser -u testeur -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${u}/bus" gdbus call --session \
        --dest org.thomasos.Core --object-path /org/thomasos/Core --method "org.thomasos.Style1.$1" "${@:2}" 2>&1
}
# Installateur : une commande lancée comme dans la vraie session de « testeur » (environnement de son plasmashell :
# écran X/Wayland pour Wine/Proton, bus de session…), et son dossier Téléchargements
comme_testeur() {
    local p
    local -a e
    p="$(pgrep -u testeur -x plasmashell | head -1)"
    mapfile -t e < <(tr '\0' '\n' <"/proc/${p}/environ" | grep -E '^(DISPLAY|WAYLAND_DISPLAY|XAUTHORITY|DBUS_SESSION_BUS_ADDRESS|XDG_RUNTIME_DIR|XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|KDE_FULL_SESSION|KDE_SESSION_VERSION|LANG|LANGUAGE|PATH|HOME|USER|LOGNAME|XDG_DATA_DIRS|XDG_CONFIG_DIRS|QT_QPA_PLATFORMTHEME)=')
    runuser -u testeur -- env -i "${e[@]}" "$@"
}
# ouvre un fichier comme KDE (commande donnée), et dit si l'installateur s'est lancé pour lui ($1 = motif du nom)
ouvre_installateur() {
    local motif="$1" r
    shift
    comme_testeur "$@" </dev/null >/tmp/ouvrir.log 2>&1 &
    for _ in $(seq 30); do pgrep -u testeur -f "thomas-installateur.*${motif}" >/dev/null && break; sleep 1; done
    pgrep -u testeur -f "thomas-installateur.*${motif}" >/dev/null
    r=$?
    sleep 2
    pkill -u testeur -x kdialog; pkill -u testeur -f 'bin/thomas-installateur'; pkill -u testeur -f 'kde-open|kioclient'
    sleep 1
    return "${r}"
}
# raccourci FICHIER ACTION : le raccourci d'une action dans un fichier de raccourcis KDE (.rc), lu comme du XML
# (l'ordre des attributs change quand KDE réécrit le fichier)
raccourci() {
    python3 -c 'import sys, xml.dom.minidom as m
d = m.parse(sys.argv[1])
print(next((a.getAttribute("shortcut") for a in d.getElementsByTagName("Action")
            if a.getAttribute("name") == sys.argv[2] and a.hasAttribute("shortcut")), ""))' "$1" "$2" </dev/null 2>/dev/null
}
telechargements() {
    local d maison
    maison="$(getent passwd testeur | cut -d: -f6)"
    d="$(comme_testeur xdg-user-dir DOWNLOAD 2>/dev/null </dev/null)"
    [[ -n "${d}" && "${d}" != "${maison}" ]] || d="${maison}/Téléchargements"
    comme_testeur mkdir -p "${d}" </dev/null
    echo "${d}"
}

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
    if grep -q 'wallpapers/ThomasOS' /usr/lib/plasmalogin/defaults.conf 2>/dev/null; then ok "écran de connexion : fond Thomas OS"; else ko "écran de connexion : fond pas réglé"; fi
    if [[ "$(plymouth-set-default-theme 2>/dev/null)" == thomas-os && -f /usr/share/plymouth/themes/thomas-os/thomas-os.plymouth ]]; then
        ok "logo de démarrage : thème thomas-os"
    else ko "logo de démarrage : thème $(plymouth-set-default-theme 2>/dev/null || echo ?)"; fi
    info "arguments du noyau : $(cat /proc/cmdline)"
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
    maison="$(getent passwd testeur | cut -d: -f6)"
    actuel="${maison}/.config/thomas-os/actuel.conf"
    for _ in $(seq 45); do [[ -f "${actuel}" ]] && break; sleep 2; done
    if [[ -f "${actuel}" ]]; then ok "style posé au 1er login ($(grep -m1 '^id' "${actuel}"))"; else ko "style non posé au 1er login"; fi
    # Thomas Welcome à la place de Bazzite Portal et des annonces de Bazzite
    for _ in $(seq 30); do pgrep -u testeur -x thomas-welcome >/dev/null && break; sleep 2; done
    if pgrep -u testeur -x thomas-welcome >/dev/null; then ok "Thomas Welcome ouvert au 1er login"; else ko "Thomas Welcome pas ouvert au 1er login"; fi
    if pgrep -u testeur -f yafti >/dev/null; then ko "Bazzite Portal s'est ouvert"; else ok "Bazzite Portal ne s'ouvre plus"; fi
    if [[ -e "${maison}/.config/autostart/bazzite-portal.desktop" || -e /etc/xdg/autostart/bazzite-announcement.desktop ]]; then
        ko "Portal ou annonces de Bazzite encore lancés à l'ouverture de session"
    else ok "annonces de Bazzite retirées de l'ouverture de session"; fi
    journalctl -b --no-pager _UID="$(id -u testeur)" 2>/dev/null | grep -iE 'thomas-style|⚠️|Erreur :' | tail -6 | sed 's/^/INFO    /'
    ;;
bienvenue)
    # Thomas Welcome : chaque étape s'affiche sans erreur (photos dans /tmp/bienvenue, récupérées par GitHub)
    u="$(id -u testeur)"
    E=(XDG_RUNTIME_DIR="/run/user/${u}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${u}/bus" WAYLAND_DISPLAY="$(ecran_wayland "${u}")"
       QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true QT_FORCE_STDERR_LOGGING=1)
    rm -rf /tmp/bienvenue
    install -d -o testeur /tmp/bienvenue
    runuser -u testeur -- env "${E[@]}" timeout 90 thomas-welcome --capture /tmp/bienvenue </dev/null >/tmp/bienvenue.log 2>&1
    n="$(ls /tmp/bienvenue/etape-*.png 2>/dev/null | wc -l)"
    if [[ "${n}" -eq 7 ]]; then ok "les 7 étapes de Thomas Welcome s'affichent"; else
        ko "${n} étape(s) de Thomas Welcome sur 7 :"; grep . /tmp/bienvenue.log | tail -8 | sed 's/^/INFO    /'
    fi
    e="$(grep -iE 'qml|error|warning' /tmp/bienvenue.log | grep -v 'Qt Quick Layouts' | sort -u | tail -8)"
    if [[ -z "${e}" ]]; then ok "aucune erreur QML dans Thomas Welcome"; else ko "messages de Thomas Welcome :"; echo "${e}" | sed 's/^/INFO    /'; fi
    info "aperçus des styles dans l'image : $(ls /usr/share/thomas-os/apercus/*.png 2>/dev/null | wc -l)"
    ;;
bienvenue-fermee)
    # fermé par l'utilisateur (Alt+F4, envoyé par QEMU) : retenu comme « fait », il ne revient plus
    u="$(id -u testeur)"
    maison="$(getent passwd testeur | cut -d: -f6)"
    E=(XDG_RUNTIME_DIR="/run/user/${u}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${u}/bus" WAYLAND_DISPLAY="$(ecran_wayland "${u}")"
       QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true)
    for _ in $(seq 10); do pgrep -u testeur -x thomas-welcome >/dev/null || break; sleep 1; done
    if pgrep -u testeur -x thomas-welcome >/dev/null; then
        ko "Thomas Welcome encore ouvert après Alt+F4"
        pkill -u testeur -x thomas-welcome
    else ok "Thomas Welcome se ferme (Alt+F4)"; fi
    if grep -q '^fait = oui$' "${maison}/.config/thomas-os/thomas.conf" 2>/dev/null; then ok "« bienvenue faite » retenu"; else ko "« bienvenue faite » pas retenu"; fi
    if runuser -u testeur -- env "${E[@]}" timeout 15 thomas-welcome --premier-lancement </dev/null >/dev/null 2>&1; then
        ok "Thomas Welcome ne se rouvre plus aux sessions suivantes"
    else
        ko "Thomas Welcome se rouvrirait à chaque session"
        pkill -u testeur -x thomas-welcome
    fi
    ;;
situation)
    # le bureau en usage : une fenêtre (Dolphin) et une notification, dans la session de « testeur »
    u="$(id -u testeur)"
    E=(XDG_RUNTIME_DIR="/run/user/${u}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${u}/bus" WAYLAND_DISPLAY="$(ecran_wayland "${u}")" QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true)
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
avant-alt-espace)
    # vrai clavier : la touche est envoyée par QEMU entre « avant » et « apres »
    maison="$(getent passwd testeur | cut -d: -f6)"
    if pgrep -u testeur -x krunner >/dev/null; then echo oui >/tmp/krunner-avant; else echo non >/tmp/krunner-avant; fi
    info "KRunner lancé avant la touche : $(cat /tmp/krunner-avant)"
    grep -B1 -iE 'alt\+space' "${maison}/.config/kglobalshortcutsrc" 2>/dev/null | sed 's/^/INFO    raccourci : /'
    ;;
apres-alt-espace)
    if [[ "$(cat /tmp/krunner-avant)" == non ]] && pgrep -u testeur -x krunner >/dev/null; then
        ko "Alt+Espace a ouvert la recherche KRunner au lieu du menu"
    else ok "Alt+Espace n'ouvre pas KRunner"; fi
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
    E=(XDG_RUNTIME_DIR="/run/user/${u}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${u}/bus" WAYLAND_DISPLAY="$(ecran_wayland "${u}")"
       QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true QT_FORCE_STDERR_LOGGING=1)
    runuser -u testeur -- env "${E[@]}" thomas-control >/tmp/control.log 2>&1 &
    sleep 6
    if pgrep -u testeur -x thomas-control >/dev/null; then ok "Thomas Control ouvert"; else
        ko "Thomas Control s'est fermé :"
        { cat /tmp/control.log; journalctl -b --no-pager -o cat _COMM=thomas-control 2>/dev/null; } | grep . | tail -12 | sed 's/^/INFO    /'
    fi
    e="$(grep -iE 'qml|error|warning' /tmp/control.log | grep -v 'Qt Quick Layouts' | sort -u | tail -6)"
    if [[ -z "${e}" ]]; then ok "aucune erreur QML dans Thomas Control"; else ko "messages de Thomas Control :"; echo "${e}" | sed 's/^/INFO    /'; fi
    ;;
studio)
    # Thomas Studio : lire un style par Thomas Core, le modifier, l'enregistrer (avec correction),
    # dessiner sa maquette, puis ouvrir le Studio dessus
    u="$(id -u testeur)"
    E=(XDG_RUNTIME_DIR="/run/user/${u}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${u}/bus" WAYLAND_DISPLAY="$(ecran_wayland "${u}")"
       QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true QT_FORCE_STDERR_LOGGING=1)
    if ! runuser -u testeur -- env "${E[@]}" python3 - <<'EOF'
import json, sys
from gi.repository import Gio, GLib
bus = Gio.bus_get_sync(Gio.BusType.SESSION)
def appel(methode, signature=None, *args):
    r = bus.call_sync("org.thomasos.Core", "/org/thomasos/Core", "org.thomasos.Style1", methode,
                      GLib.Variant(signature, args) if signature else None, None, Gio.DBusCallFlags.NONE, 60000, None)
    return r.unpack()
bon = True
def verif(condition, texte):
    global bon
    print(("OK      " if condition else "ECHEC   ") + texte)
    bon = bon and condition
cat = json.loads(appel("Catalogue")[0])
verif("capsule" in cat["choix"]["barre.disposition"], "le Studio reçoit la liste de ce qui est possible (catalogue)")
lu = json.loads(appel("Lire", "(s)", "thomas")[0])
verif(lu["style"]["couleurs"]["principale"].lower() == "#ff0000", "le Studio lit le style Thomas OS")
s = lu["style"]
s["style"]["nom"] = "Essai VM"
s["couleurs"].update(principale="#00b4ff", bordure="#00b4ff", fond_haut="#00264d", fond_bas="#00060f")
s["bureau"]["fond"] = "degrade"
s["barre"]["disposition"] = "windows"
s["effets"]["coins"] = "99"
sid, corr = appel("Enregistrer", "(ss)", "essai-vm", json.dumps(s))
verif(sid == "essai-vm" and any("coins" in c for c in corr), f"style enregistré, valeur impossible corrigée ({'; '.join(corr)})")
verif(any(i == "essai-vm" for i, _ in appel("Liste")[0]), "le nouveau style apparaît dans la liste")
sys.exit(0 if bon else 1)
EOF
    then erreurs=$((erreurs + 1)); fi
    rm -f /tmp/maquette-essai-vm.png
    runuser -u testeur -- env "${E[@]}" timeout 60 thomas-studio --apercu /tmp/maquette-essai-vm.png essai-vm </dev/null >/tmp/maquette.log 2>&1
    if [[ -s /tmp/maquette-essai-vm.png ]]; then ok "maquette du style dessinée par le Studio"; else
        ko "pas de maquette :"; grep . /tmp/maquette.log | tail -8 | sed 's/^/INFO    /'
    fi
    runuser -u testeur -- env "${E[@]}" thomas-studio essai-vm </dev/null >/tmp/studio.log 2>&1 &
    sleep 8
    if pgrep -u testeur -x thomas-studio >/dev/null; then ok "Thomas Studio ouvert"; else
        ko "Thomas Studio s'est fermé :"; grep . /tmp/studio.log | tail -12 | sed 's/^/INFO    /'
    fi
    e="$(cat /tmp/maquette.log /tmp/studio.log | grep -iE 'qml|error|warning' | grep -v 'Qt Quick Layouts' | sort -u | tail -8)"
    if [[ -z "${e}" ]]; then ok "aucune erreur QML dans Thomas Studio"; else ko "messages de Thomas Studio :"; echo "${e}" | sed 's/^/INFO    /'; fi
    ;;
style-studio)
    # le style créé avec le Studio, appliqué pour de vrai : la photo est comparée à la maquette
    u="$(id -u testeur)"
    maison="$(getent passwd testeur | cut -d: -f6)"
    E=(XDG_RUNTIME_DIR="/run/user/${u}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${u}/bus" WAYLAND_DISPLAY="$(ecran_wayland "${u}")"
       QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true)
    pkill -u testeur -x thomas-studio; pkill -u testeur -x thomas-control; pkill -u testeur -x dolphin; sleep 1
    style_core Appliquer "'essai-vm'" "''" >/dev/null
    for _ in $(seq 60); do grep -q '^id = essai-vm$' "${maison}/.config/thomas-os/actuel.conf" && break; sleep 2; done
    if grep -q '^id = essai-vm$' "${maison}/.config/thomas-os/actuel.conf"; then ok "style du Studio appliqué"; else ko "style du Studio pas appliqué"; fi
    if grep -q 'ThomasOS-essai-vm' "${maison}/.config/kdeglobals"; then ok "couleurs du style en place"; else ko "couleurs du style absentes de kdeglobals"; fi
    if [[ "$(style_core PeutAnnuler)" == *true* ]]; then ok "l'ancien style est gardé pour « Annuler »"; else ko "rien à annuler"; fi
    sleep 6
    runuser -u testeur -- env "${E[@]}" dolphin </dev/null >/dev/null 2>&1 &
    sleep 8
    runuser -u testeur -- env "${E[@]}" notify-send -a "Thomas OS" -i thomas-os "Notification de test" "Style créé avec le Studio"
    ;;
annuler)
    # « Annuler le dernier changement » : le style d'avant (Thomas OS, barre capsule) revient
    maison="$(getent passwd testeur | cut -d: -f6)"
    pkill -u testeur -x dolphin
    style_core Annuler >/dev/null
    for _ in $(seq 60); do grep -q '^id = thomas$' "${maison}/.config/thomas-os/actuel.conf" && break; sleep 2; done
    if grep -q '^id = thomas$' "${maison}/.config/thomas-os/actuel.conf"; then ok "« Annuler » remet le style d'avant"; else ko "« Annuler » n'a pas remis le style d'avant"; fi
    applets="${maison}/.config/plasma-org.kde.plasma.desktop-appletsrc"
    for _ in $(seq 20); do [[ "$(grep -c '^plugin=org.thomasos.barre$' "${applets}")" -ge 2 ]] && break; sleep 2; done
    if [[ "$(grep -c '^plugin=org.thomasos.barre$' "${applets}")" -ge 2 ]]; then ok "la barre capsule est revenue"; else ko "la barre capsule n'est pas revenue"; fi
    sleep 4
    ;;
phase8)
    # mode jeu (faux jeu Steam), nettoyage, diagnostic réseau, puis une fausse surchauffe (photographiée ensuite)
    u="$(id -u testeur)"
    SU=(runuser -u testeur -- env XDG_RUNTIME_DIR="/run/user/${u}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${u}/bus")
    for t in thomas-jeu.timer thomas-surveillance.timer; do
        if "${SU[@]}" systemctl --user is-active --quiet "${t}"; then ok "${t} actif dans la session"; else ko "${t} inactif dans la session"; fi
    done
    if systemctl is-enabled --quiet thomas-nettoyage.timer; then ok "nettoyage chaque semaine programmé"; else ko "nettoyage pas programmé"; fi
    pp=(org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles)
    profil() { busctl get-property "${pp[@]}" ActiveProfile 2>/dev/null | cut -d'"' -f2; }
    profils="$(busctl get-property "${pp[@]}" Profiles 2>/dev/null | grep -o '"Profile" s "[a-z-]*"' | cut -d'"' -f4 | tr '\n' ' ')"
    avant="$(profil)"
    info "énergie : profil « ${avant:-aucun service} », profils possibles : ${profils:-aucun}"
    cout() { "${SU[@]}" bash -c "TIMEFORMAT=%3R; for i in 1 2 3 4 5; do time $1 >/dev/null; done" 2>&1 | awk '{s+=$1} END {printf "%.0f", s/NR*1000}'; }
    info "mesure : une vérification du mode jeu (sans jeu) prend $(cout /usr/libexec/thomas-jeu) ms, toutes les 15 s"
    info "mesure : un passage de la surveillance prend $(cout /usr/libexec/thomas-surveillance) ms, toutes les 2 min"
    "${SU[@]}" bash -c 'exec -a "SteamLaunch AppId=480 -- jeu-de-test" sleep 120' </dev/null >/dev/null 2>&1 &
    sleep 1
    "${SU[@]}" systemctl --user start thomas-jeu.service
    for _ in $(seq 15); do "${SU[@]}" systemctl --user is-active --quiet thomas-jeu-maintien.service && break; sleep 1; done
    if "${SU[@]}" systemctl --user is-active --quiet thomas-jeu-maintien.service; then ok "mode jeu : le faux jeu Steam est reconnu"; else ko "mode jeu : jeu pas reconnu"; fi
    if [[ " ${profils} " == *" performance "* ]]; then
        for _ in $(seq 10); do [[ "$(profil)" == performance ]] && break; sleep 1; done
        if [[ "$(profil)" == performance ]]; then ok "mode jeu : profil « performance » pendant le jeu"; else ko "mode jeu : profil resté « $(profil) »"; fi
        e="$(style_core_systeme Energie)"
        if [[ "${e}" == *"'jeu': 'oui'"* ]]; then ok "Thomas Core voit le mode jeu actif"; else ko "Thomas Core ne voit pas le mode jeu : ${e:0:200}"; fi
    else info "le profil « performance » n'existe pas dans cette VM : seule la reconnaissance du jeu est vérifiée"; fi
    pkill -u testeur -f 'SteamLaunch AppId=480'
    for _ in $(seq 15); do "${SU[@]}" systemctl --user is-active --quiet thomas-jeu-maintien.service || break; sleep 1; done
    if "${SU[@]}" systemctl --user is-active --quiet thomas-jeu-maintien.service; then ko "mode jeu : toujours actif après le jeu"
    elif [[ "$(profil)" == "${avant}" ]]; then ok "jeu fini : profil d'avant remis (« ${avant:-aucun} »)"
    else ko "jeu fini mais profil « $(profil) » au lieu de « ${avant} »"; fi
    "${SU[@]}" journalctl --user -u thomas-jeu-maintien.service --no-pager -o cat 2>/dev/null | tail -3 | sed 's/^/INFO    /'
    # nettoyage (en root, comme le minuteur)
    if systemctl start thomas-nettoyage.service && [[ -s /var/lib/thomas-os/nettoyage.json ]]; then ok "nettoyage : $(cat /var/lib/thomas-os/nettoyage.json)"; else ko "nettoyage en échec"; fi
    r="$(style_core_systeme Nettoyage Diagnostic1)"
    if [[ "${r}" == *libere_mo* ]]; then ok "Thomas Core lit le dernier nettoyage"; else ko "Core Nettoyage : ${r:0:200}"; fi
    # diagnostic réseau (mesure seulement)
    r="$(style_core_systeme TestReseau Diagnostic1)"
    if [[ "${r}" == *latence_ms* ]]; then ok "diagnostic réseau : ${r:0:220}"; else ko "diagnostic réseau : ${r:0:220}"; fi
    r="$(style_core_systeme TestDebit Diagnostic1)"
    if [[ "${r}" == *debit_mbps* ]]; then ok "débit mesuré : ${r:0:160}"; else ko "débit : ${r:0:200}"; fi
    # surveillance avec les vrais capteurs et un état neuf : rien d'anormal dans la VM => aucune alerte
    rm -rf /tmp/etat-neuf
    install -d -o testeur /tmp/etat-neuf
    r="$("${SU[@]}" XDG_STATE_HOME=/tmp/etat-neuf /usr/libexec/thomas-surveillance)"
    if [[ -z "${r}" ]]; then ok "surveillance : aucune fausse alerte (disque, températures)"; else ko "surveillance : fausse alerte (${r})"; fi
    info "disques vus par la surveillance : $("${SU[@]}" python3 -c 'import sys; sys.path.insert(0, "/usr/lib/thomas-os/python"); from thomas_os import capteurs; print([(p, l // 2**30) for p, _, l in capteurs.disques()])')"
    # surveillance : faux capteur à 99 °C => une alerte (photographiée juste après)
    rm -rf /tmp/faux-hwmon /tmp/faux-etat
    install -d -o testeur /tmp/faux-hwmon/hwmon0 /tmp/faux-etat
    echo k10temp >/tmp/faux-hwmon/hwmon0/name
    echo 99000 >/tmp/faux-hwmon/hwmon0/temp1_input
    r="$("${SU[@]}" THOMAS_HWMON=/tmp/faux-hwmon XDG_STATE_HOME=/tmp/faux-etat /usr/libexec/thomas-surveillance)"
    if [[ "${r}" == *"chauffe : 99"* ]]; then ok "surveillance : alerte envoyée pour une surchauffe (faux capteur à 99 °C)"; else ko "surveillance : pas d'alerte (${r})"; fi
    r="$("${SU[@]}" THOMAS_HWMON=/tmp/faux-hwmon XDG_STATE_HOME=/tmp/faux-etat /usr/libexec/thomas-surveillance)"
    if [[ -z "${r}" ]]; then ok "surveillance : pas de 2e alerte dans les 30 min"; else ko "surveillance : alerte répétée (${r})"; fi
    sleep 2
    ;;
control-pages)
    # Thomas Control : chacune des 13 catégories s'ouvre sans erreur (photos dans /tmp/control)
    u="$(id -u testeur)"
    E=(XDG_RUNTIME_DIR="/run/user/${u}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${u}/bus" WAYLAND_DISPLAY="$(ecran_wayland "${u}")"
       QT_QPA_PLATFORM=wayland XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true QT_FORCE_STDERR_LOGGING=1)
    rm -rf /tmp/control
    install -d -o testeur /tmp/control
    runuser -u testeur -- env "${E[@]}" timeout 120 thomas-control --capture /tmp/control </dev/null >/tmp/control-pages.log 2>&1
    n="$(ls /tmp/control/page-*.png 2>/dev/null | wc -l)"
    if [[ "${n}" -eq 13 ]]; then ok "les 13 pages de Thomas Control s'ouvrent"; else
        ko "${n} page(s) de Thomas Control sur 13 :"; grep . /tmp/control-pages.log | tail -8 | sed 's/^/INFO    /'
    fi
    e="$(grep -iE 'qml|error|warning' /tmp/control-pages.log | grep -v 'Qt Quick Layouts' | sort -u | tail -8)"
    if [[ -z "${e}" ]]; then ok "aucune erreur QML dans les pages de Thomas Control"; else ko "messages des pages de Thomas Control :"; echo "${e}" | sed 's/^/INFO    /'; fi
    ;;
systeme)
    # Aide système (bus système, root, polkit) : lancée à la demande, entrées piégées refusées, polkit actif pour un
    # utilisateur sans mot de passe, « redémarrer sur Windows » sur une fausse entrée UEFI (créée hors de l'ordre de
    # démarrage, puis supprimée).
    aide() { busctl --system --json=short call org.thomasos.Systeme /org/thomasos/Systeme org.thomasos.Systeme1 "$@" 2>&1; }
    champ() { python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["data"][0].get(sys.argv[1], "?"))' "$1" 2>/dev/null; }
    etat="$(aide Etat)"
    if [[ "${etat}" == *'"canal"'* ]]; then
        ok "aide système lancée à la demande : canal $(champ canal <<<"${etat}"), variante $(champ variante <<<"${etat}"), Windows $(champ windows <<<"${etat}")"
    else ko "aide système : ${etat}"; fi
    r="$(aide ChangerCanal s 'stable; reboot')"
    if [[ "${r}" == *"Canal inconnu"* ]]; then ok "entrée piégée refusée (canal « stable; reboot »)"; else ko "entrée piégée : ${r}"; fi
    r="$(aide ChangerVariante s '../autre-image')"
    if [[ "${r}" == *"Variante inconnue"* ]]; then ok "entrée piégée refusée (variante « ../autre-image »)"; else ko "variante piégée : ${r}"; fi
    r="$(runuser -u testeur -- busctl --system call org.thomasos.Systeme /org/thomasos/Systeme org.thomasos.Systeme1 ChangerCanal s stable 2>&1)"
    if [[ "${r}" == *"Autorisation refusée"* ]]; then ok "polkit : un utilisateur sans mot de passe administrateur est refusé"; else ko "polkit : ${r}"; fi
    if [[ -d /sys/firmware/efi ]]; then
        avant="$(efibootmgr | grep -E '^BootOrder' || true)"
        disque="/dev/$(lsblk -no PKNAME "$(findmnt -no SOURCE /boot/efi 2>/dev/null || findmnt -no SOURCE /boot)" 2>/dev/null | head -1)"
        [[ -b "${disque}" ]] || disque=/dev/vda
        efibootmgr -q -C -d "${disque}" -p 1 -L "Windows Boot Manager" -l '\EFI\Microsoft\Boot\bootmgfw.efi' >/dev/null 2>&1
        num="$(efibootmgr | sed -nE 's/^Boot([0-9A-F]{4})\*? Windows Boot Manager.*/\1/p' | head -1)"
        if [[ -n "${num}" ]]; then
            etat="$(aide Etat)"
            if [[ "$(champ windows <<<"${etat}")" == oui ]]; then ok "Windows détecté dans les entrées UEFI (fausse entrée Boot${num})"; else ko "Windows pas détecté : ${etat}"; fi
            r="$(aide RedemarrerWindows b false)"
            # relu plusieurs fois : une fois (run 45713419172), BootNext n'était pas encore visible juste après la réponse
            for _ in 1 2 3 4 5; do efibootmgr | grep -q "^BootNext: ${num}" && break; sleep 2; done
            if efibootmgr | grep -q "^BootNext: ${num}"; then ok "« redémarrer sur Windows » : démarrage suivant réglé sur Boot${num} (${r})"
            else
                ko "BootNext pas réglé : ${r}"
                efibootmgr | head -12 | sed 's/^/INFO    efibootmgr : /'
                journalctl -u thomas-systeme --no-pager | tail -6 | sed 's/^/INFO    /'
            fi
            if [[ "$(efibootmgr | grep -E '^BootOrder' || true)" == "${avant}" ]]; then ok "ordre de démarrage inchangé"; else ko "ordre de démarrage modifié"; fi
            efibootmgr -q -N >/dev/null 2>&1; efibootmgr -q -b "${num}" -B >/dev/null 2>&1
            if efibootmgr | grep -qE "^BootNext|Windows Boot Manager"; then ko "fausse entrée Windows pas nettoyée"; else ok "fausse entrée Windows supprimée"; fi
        else ko "fausse entrée UEFI pas créée (${disque})"; fi
    else info "VM sans UEFI : test Windows sauté"; fi
    ;;
systeme-bascule)
    # Vrai changement de canal par l'aide système (téléchargement de l'image) : prêt au prochain redémarrage
    r="$(busctl --system call org.thomasos.Systeme /org/thomasos/Systeme org.thomasos.Systeme1 ChangerCanal s testing 2>&1)"
    info "changement de canal : ${r}"
    debut=$SECONDS
    for _ in $(seq 150); do
        sleep 10
        t="$(busctl --system --json=short call org.thomasos.Systeme /org/thomasos/Systeme org.thomasos.Systeme1 Etat 2>/dev/null \
            | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"][0].get("travail",""))' 2>/dev/null)"
        [[ -z "${t}" ]] && break
    done
    attente="$(bootc status --format json 2>/dev/null | python3 -c 'import json,sys; s=json.load(sys.stdin)["status"]; print(((s.get("staged") or {}).get("image") or {}).get("image",{}).get("image",""))' 2>/dev/null)"
    if [[ "${attente}" == *:testing ]]; then ok "changement de canal prêt en $((SECONDS - debut)) s : ${attente} au prochain redémarrage"
    else ko "changement de canal pas prêt (${attente:-rien en attente}) ; journal :"; journalctl -u thomas-systeme --no-pager | tail -8 | sed 's/^/INFO    /'; fi
    ;;
applis)
    for _ in $(seq 72); do [[ -n "$(systemctl show -p ExecMainExitTimestamp --value thomas-flatpak-preinstall.service)" ]] && break; sleep 10; done
    info "service des applis : $(systemctl show -p Result --value thomas-flatpak-preinstall.service)"
    info "applis Flatpak installées : $(flatpak list --app --columns=application | tr '\n' ' ')"
    ;;
installateur-ouvrir)
    # Installateur Thomas OS : le vrai double-clic dans Dolphin. Ici : écran rallumé et déverrouillé (veille constatée
    # en VM à ce moment du test), fichiers « téléchargés », Dolphin ouvert sur SteamSetup.exe sélectionné. Le runner
    # appuie ensuite sur Entrée (= double-clic), puis sur « Lancer » si KDE le demande, et prend les photos 11a à 11c.
    loginctl unlock-sessions 2>/dev/null
    comme_testeur kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false </dev/null
    comme_testeur kwriteconfig6 --file powerdevilrc --group AC --group Display --key TurnOffDisplayWhenIdle false </dev/null
    comme_testeur gdbus call --session --dest org.kde.Solid.PowerManagement --object-path /org/kde/Solid/PowerManagement \
        --method org.kde.Solid.PowerManagement.reparseConfiguration </dev/null >/dev/null 2>&1
    tele="$(telechargements)"
    maison="$(getent passwd testeur | cut -d: -f6)"
    # vrai programme Windows (compilé sur GitHub), sous le nom de l'installateur de Steam
    install -o testeur -g testeur -m 0644 /tmp/appli-test.exe "${tele}/SteamSetup.exe"
    comme_testeur python3 - "${tele}" <<'EOF'
import os, sys
d = sys.argv[1]
fichiers = {  # débuts de fichiers réels : le type est reconnu par le contenu, comme un vrai téléchargement
    "steam_latest.deb": b"!<arch>\ndebian-binary   1700000000  0     0     100644  4         `\n2.0\n",
    "EpicInstaller-18.8.1.msi": b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1" + bytes(56),
    "Appli-1.0-x86_64.AppImage": b"\x7fELF\x02\x01\x01\x00AI\x02" + bytes(53),
}
for nom, contenu in fichiers.items():
    open(os.path.join(d, nom), "wb").write(contenu)
print("INFO    fichiers « téléchargés » dans", d)
EOF
    for f in SteamSetup.exe steam_latest.deb EpicInstaller-18.8.1.msi; do
        info "${f} : type vu par KDE $(comme_testeur kmimetypefinder "${tele}/${f}" </dev/null 2>&1 | head -1)"
    done
    rm -f "${maison}/.cache/thomas-os/installateur.log"
    pkill -u testeur -x dolphin; sleep 1
    comme_testeur dolphin --select "${tele}/SteamSetup.exe" </dev/null >/dev/null 2>&1 &
    sleep 6
    if pgrep -u testeur -x dolphin >/dev/null; then ok "Dolphin ouvert sur Téléchargements, SteamSetup.exe sélectionné (photo 11a)"
    else ko "Dolphin pas ouvert"; fi
    ;;
installateur-etat)
    # après Entrée dans Dolphin : l'installateur est-il déjà ouvert ? (sinon KDE demande « Lancer ce fichier ? »)
    if pgrep -u testeur -f 'thomas-installateur.*SteamSetup' >/dev/null; then info "après Entrée : installateur déjà ouvert"; exit 0; fi
    info "après Entrée : installateur pas encore ouvert (KDE demande « Lancer ce fichier ? », photo 11b)"
    exit 3
    ;;
installateur)
    tele="$(telechargements)"
    maison="$(getent passwd testeur | cut -d: -f6)"
    # 1. le vrai double-clic dans Dolphin (photos 11a à 11c)
    for _ in $(seq 10); do pgrep -u testeur -x kdialog >/dev/null && break; sleep 1; done
    if pgrep -u testeur -f 'thomas-installateur.*SteamSetup' >/dev/null && pgrep -u testeur -x kdialog >/dev/null; then
        ok "double-clic dans Dolphin sur SteamSetup.exe : fenêtre « Installer Steam ? » de l'installateur (photo 11c)"
    else ko "double-clic dans Dolphin sur SteamSetup.exe : pas de fenêtre de l'installateur (photos 11a à 11c)"; fi
    grep -h 'fichier :' "${maison}/.cache/thomas-os/installateur.log" 2>/dev/null | tail -1 | sed 's/^/INFO    /'
    pkill -u testeur -x kdialog; pkill -u testeur -f 'bin/thomas-installateur'; pkill -u testeur -x dolphin; sleep 1
    # 2. même chemin sans clavier : .exe (comme après « Lancer », kioclient exec), .deb et .msi (kde-open)
    kio="$(command -v kioclient6 || command -v kioclient || echo kioclient)"
    if ouvre_installateur SteamSetup "${kio}" exec "${tele}/SteamSetup.exe"; then ok "SteamSetup.exe ouvert par KDE → installateur Thomas OS"
    else ko "SteamSetup.exe ouvert par KDE : installateur pas lancé ($(tr '\n' ' ' </tmp/ouvrir.log | head -c 300))"; fi
    if ouvre_installateur steam_latest kde-open "${tele}/steam_latest.deb"; then ok "double-clic sur steam_latest.deb → installateur Thomas OS (plus Ark)"
    else ko "double-clic sur un .deb : installateur pas lancé ($(tr '\n' ' ' </tmp/ouvrir.log | head -c 300))"; fi
    if ouvre_installateur EpicInstaller kde-open "${tele}/EpicInstaller-18.8.1.msi"; then ok "double-clic sur EpicInstaller.msi → installateur Thomas OS"
    else ko "double-clic sur un .msi : installateur pas lancé ($(tr '\n' ' ' </tmp/ouvrir.log | head -c 300))"; fi
    # 3. décisions sur les vrais fichiers de Thomas (Steam, Epic Games)
    r="$(comme_testeur thomas-installateur --choix "${tele}/SteamSetup.exe" "${tele}/steam_latest.deb" "${tele}/EpicInstaller-18.8.1.msi" </dev/null)"
    if [[ "$(grep -c '"id": "com.valvesoftware.Steam"' <<<"${r}")" == 2 && "${r}" == *'"id": "com.heroicgameslauncher.hgl"'* ]]; then
        ok "Steam (.exe et .deb) → Steam de la boutique ; Epic Games (.msi) → Heroic"
    else ko "décisions : ${r}"; fi
    # 4. AppImage : rangée dans ~/Applications et ajoutée au menu
    comme_testeur thomas-installateur --oui "${tele}/Appli-1.0-x86_64.AppImage" </dev/null >/tmp/appimage.log 2>&1
    d="${maison}/.local/share/applications/thomas-appimage-appli.desktop"
    if [[ -x "${maison}/Applications/Appli-1.0-x86_64.AppImage" && -f "${d}" ]] && grep -q '^Exec="' "${d}"; then
        ok "AppImage rangée dans ~/Applications et ajoutée au menu"
    else ko "AppImage : $(tail -3 /tmp/appimage.log | tr '\n' ' ')"; fi
    if command -v desktop-file-validate >/dev/null; then
        if v="$(desktop-file-validate "${d}" /usr/share/applications/org.thomasos.installateur.desktop 2>&1)"; then ok "raccourcis valides (desktop-file-validate)"
        else ko "raccourcis : ${v}"; fi
    fi
    ;;
installateur-boutique)
    # Vraie installation depuis la boutique (Internet) : Epic Games → Heroic, comme Thomas le ferait
    tele="$(telechargements)"
    debut=$SECONDS
    comme_testeur timeout 900 thomas-installateur --oui "${tele}/EpicInstaller-18.8.1.msi" </dev/null >/tmp/boutique.log 2>&1
    if flatpak info com.heroicgameslauncher.hgl >/dev/null 2>&1 || comme_testeur flatpak info com.heroicgameslauncher.hgl >/dev/null 2>&1 </dev/null; then
        ok "EpicInstaller.msi → Heroic installé depuis la boutique en $((SECONDS - debut)) s ($(grep -oE 'installé \((system|user)\)' /tmp/boutique.log | head -1))"
    else ko "Heroic pas installé : $(tail -4 /tmp/boutique.log | tr '\n' ' ')"; fi
    # toutes les applis que l'installateur connaît existent bien sur Flathub
    ids="$(python3 - <<'EOF'
import importlib.machinery, importlib.util
l = importlib.machinery.SourceFileLoader("ti", "/usr/bin/thomas-installateur")
m = importlib.util.module_from_spec(importlib.util.spec_from_loader("ti", l))
l.exec_module(m)
print(" ".join(sorted({c[1] for c in m.CONNUS if c[1]})))
EOF
)"
    manquants=""
    for i in ${ids}; do flatpak remote-info flathub "${i}" >/dev/null 2>&1 || manquants+=" ${i}"; done
    if [[ -z "${manquants}" ]]; then ok "les $(wc -w <<<"${ids}") applis connues de l'installateur existent sur Flathub"
    else ko "introuvables sur Flathub :${manquants}"; fi
    ;;
installateur-windows)
    # Programme Windows avec Proton (Internet : Proton est téléchargé la 1re fois). installeur-test.exe (compilé sur
    # GitHub) copie appli-test.exe dans « C:\Program Files\Thomas Test » et crée son raccourci du menu Démarrer.
    tele="$(telechargements)"
    maison="$(getent passwd testeur | cut -d: -f6)"
    install -o testeur -g testeur -m 0644 /tmp/appli-test.exe /tmp/installeur-test.exe "${tele}/"
    debut=$SECONDS
    comme_testeur timeout 1500 thomas-installateur --oui "${tele}/installeur-test.exe" </dev/null >/tmp/windows.log 2>&1
    rc=$?
    info "programme Windows : code ${rc} en $((SECONDS - debut)) s"
    tail -6 /tmp/windows.log | sed 's/^/INFO    /'
    d="${maison}/.local/share/applications/thomas-windows-thomas-test.desktop"
    if [[ -f "${d}" ]]; then ok "programme Windows installé avec Proton : « Thomas Test » ajouté au menu"
    else
        ko "programme Windows : pas de raccourci dans le menu ; journal de Proton :"
        tail -15 "${maison}"/.cache/thomas-os/windows-installeur-test.log 2>/dev/null | sed 's/^/INFO    /'
    fi
    exe="$(sed -nE 's/^Exec=thomas-installateur --lancer "(.*)"$/\1/p' "${d}" 2>/dev/null)"
    rm -f "$(dirname "${exe:-/x}")/thomas-test-ok.txt"
    [[ -n "${exe}" ]] && comme_testeur timeout 300 thomas-installateur --lancer "${exe}" </dev/null >/tmp/lancer.log 2>&1
    if [[ -n "${exe}" && -f "$(dirname "${exe}")/thomas-test-ok.txt" ]]; then ok "le raccourci du menu lance le programme Windows (il a écrit son fichier)"
    else ko "programme Windows pas lancé par son raccourci : $(tail -3 /tmp/lancer.log 2>/dev/null | tr '\n' ' ')"; fi
    ;;
konsole-ouvrir)
    # Konsole comme sur Windows : Ctrl+C copie, Ctrl+V colle, Ctrl+Maj+C arrête la commande. Un petit programme
    # tourne dans Konsole et note ce qu'il reçoit ; les touches sont de vraies touches (QEMU sendkey).
    maison="$(getent passwd testeur | cut -d: -f6)"
    f="${maison}/.local/share/kxmlgui5/konsole/sessionui.rc"
    d="${maison}/.cache/thomas-test-konsole"
    pkill -u testeur -x dolphin; pkill -u testeur -x kdialog; pkill -u testeur -x konsole; sleep 1
    loginctl unlock-sessions 2>/dev/null
    if [[ "$(raccourci "${f}" edit_copy)" == Ctrl+C && "$(raccourci "${f}" edit_paste)" == Ctrl+V* ]]; then
        ok "raccourcis Ctrl+C / Ctrl+V de Konsole posés à l'ouverture de session"
    else ko "raccourcis de Konsole pas posés (${f})"; fi
    clavier="$(comme_testeur kreadconfig6 --file kxkbrc --group Layout --key LayoutList </dev/null 2>/dev/null)"
    [[ -n "${clavier}" ]] || clavier="$(localectl status 2>/dev/null | sed -nE 's/.*X11 Layout: *//p')"
    info "clavier : ${clavier:-us}"
    rm -rf "${d}" /tmp/konsole-n
    cat >/tmp/konsole-test.py <<'EOF'
import pathlib, signal, sys
d = pathlib.Path.home() / ".cache/thomas-test-konsole"
d.mkdir(parents=True, exist_ok=True)
n = 0
def interruption(signum, frame):
    global n
    n += 1
    (d / "interruptions").write_text(str(n))
signal.signal(signal.SIGINT, interruption)
(d / "interruptions").write_text("0")
print("copie-test-4815", flush=True)
(d / "pret").write_text("oui")
while True:
    ligne = sys.stdin.readline()
    if ligne:
        with open(d / "lignes", "a") as sortie:
            sortie.write(ligne)
EOF
    chmod 0644 /tmp/konsole-test.py
    comme_testeur konsole -e python3 /tmp/konsole-test.py </dev/null >/tmp/konsole.log 2>&1 &
    for _ in $(seq 20); do [[ -f "${d}/pret" ]] && break; sleep 1; done
    if [[ -f "${d}/pret" ]]; then ok "Konsole ouvert avec le programme de test (photo 12a)"; else ko "Konsole pas ouvert : $(tail -3 /tmp/konsole.log | tr '\n' ' ')"; fi
    echo 0 >/tmp/konsole-n
    sleep 2
    # KDE a repris nos raccourcis dans son propre fichier (plus récent) et réécrit le nôtre en entier
    v="$(sed -nE 's/.*<gui [^>]*version="([0-9]+)".*/\1/p' "${f}" 2>/dev/null | head -1)"
    if [[ "${v:-0}" -gt 1 && "$(raccourci "${f}" edit_copy)" == Ctrl+C ]] && grep -q '<Menu' "${f}"; then
        ok "Konsole a repris Ctrl+C / Ctrl+V dans son propre fichier de raccourcis (n° ${v}, menus gardés)"
    else ko "fichier de raccourcis pas repris par Konsole (n° ${v:-?})"; head -c 600 "${f}" 2>/dev/null | sed 's/^/INFO    /'; fi
    ;;
konsole-presse-papiers)
    # met un texte dans le presse-papiers de la session (Klipper, sinon wl-copy)
    comme_testeur gdbus call --session --dest org.kde.klipper --object-path /klipper \
        --method org.kde.klipper.klipper.setClipboardContents 'colle-test-2342' </dev/null >/dev/null 2>&1 \
        || { comme_testeur wl-copy 'colle-test-2342' </dev/null >/dev/null 2>&1 & sleep 1; }
    sleep 1
    ;;
konsole-etat)
    maison="$(getent passwd testeur | cut -d: -f6)"
    d="${maison}/.cache/thomas-test-konsole"
    n="$(cat "${d}/interruptions" 2>/dev/null)"
    avant="$(cat /tmp/konsole-n 2>/dev/null)"
    presse_papiers() {
        comme_testeur gdbus call --session --dest org.kde.klipper --object-path /klipper \
            --method org.kde.klipper.klipper.getClipboardContents </dev/null 2>/dev/null \
            || comme_testeur timeout 5 wl-paste --no-newline </dev/null 2>/dev/null
    }
    case "${2:-}" in
    ctrl-c-seul)
        if [[ "${n}" == "$((avant + 1))" ]]; then info "Ctrl+C sans texte sélectionné : arrête la commande (comme sur Windows)"
        else info "Ctrl+C sans texte sélectionné : n'arrête pas la commande (Konsole le garde pour Copier) ; pour arrêter : Ctrl+Maj+C"; fi
        ;;
    ctrl-maj-c)
        if [[ "${n}" == "$((avant + 1))" ]]; then ok "Ctrl+Maj+C arrête la commande en cours (le programme a reçu l'interruption)"
        else ko "Ctrl+Maj+C : pas d'interruption (${avant} → ${n:-?})"; fi
        ;;
    copie)
        r="$(presse_papiers)"
        if [[ "${r}" == *copie-test-4815* ]]; then ok "texte sélectionné + Ctrl+C : copié dans le presse-papiers (photo 12b)"
        else ko "Ctrl+C n'a pas copié le texte sélectionné (presse-papiers : ${r:0:120})"; fi
        if [[ "${n}" == "${avant}" ]]; then ok "Ctrl+C sur du texte sélectionné n'arrête pas la commande"
        else ko "Ctrl+C sur du texte sélectionné a arrêté la commande (${avant} → ${n:-?})"; fi
        ;;
    colle)
        if grep -q 'colle-test-2342' "${d}/lignes" 2>/dev/null; then ok "Ctrl+V colle le presse-papiers dans Konsole (photo 12c)"
        else ko "Ctrl+V n'a pas collé (presse-papiers : $(presse_papiers | head -c 120) ; reçu : $(head -c 120 "${d}/lignes" 2>/dev/null))"; fi
        pkill -u testeur -x konsole
        ;;
    *) ko "konsole-etat : étape inconnue « ${2:-} »" ;;
    esac
    echo "${n:-0}" >/tmp/konsole-n
    ;;
*)
    echo "usage : verifier.sh demarrage|preparer|session|bienvenue|bienvenue-fermee|situation|menu|avant-alt-espace|apres-alt-espace|core|control|studio|style-studio|annuler|phase8|control-pages|systeme|systeme-bascule|applis|installateur-ouvrir|installateur-etat|installateur|installateur-boutique|installateur-windows|konsole-ouvrir|konsole-presse-papiers|konsole-etat ÉTAPE"; exit 2 ;;
esac
exit $((erreurs > 0))
