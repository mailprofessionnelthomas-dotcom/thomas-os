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
applis)
    for _ in $(seq 72); do [[ -n "$(systemctl show -p ExecMainExitTimestamp --value thomas-flatpak-preinstall.service)" ]] && break; sleep 10; done
    info "service des applis : $(systemctl show -p Result --value thomas-flatpak-preinstall.service)"
    info "applis Flatpak installées : $(flatpak list --app --columns=application | tr '\n' ' ')"
    ;;
*)
    echo "usage : verifier.sh demarrage|preparer|session|applis"; exit 2 ;;
esac
exit $((erreurs > 0))
