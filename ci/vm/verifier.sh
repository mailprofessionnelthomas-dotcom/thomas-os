#!/bin/bash
# Test de démarrage : exécuté DANS la machine virtuelle (utilisateur « testeur », mot de passe jetable dans $MDP).
#   demarrage : le système a-t-il bien démarré, est-ce bien Thomas OS ?
#   session   : la 1re ouverture de session pose-t-elle le style par défaut (comme sur un vrai PC) ?
#   applis    : les applis Flatpak prévues s'installent-elles toutes seules ? (information seulement)
set -uo pipefail
erreurs=0
ok() { echo "OK      $*"; }
ko() { echo "ECHEC   $*"; erreurs=$((erreurs + 1)); }
info() { echo "INFO    $*"; }
en_root() { echo "${MDP}" | sudo -S -p '' "$@"; }

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
session)
    en_root sh -c 'mkdir -p /etc/sddm.conf.d && printf "[Autologin]\nUser=testeur\nSession=plasma\n" >/etc/sddm.conf.d/zz-test-vm.conf && systemctl restart display-manager'
    for _ in $(seq 60); do pgrep -u testeur -x plasmashell >/dev/null && break; sleep 2; done
    if pgrep -u testeur -x plasmashell >/dev/null; then ok "session Plasma ouverte"; else ko "pas de session Plasma"; fi
    for _ in $(seq 45); do [[ -f ~/.config/thomas-os/actuel.conf ]] && break; sleep 2; done
    if [[ -f ~/.config/thomas-os/actuel.conf ]]; then ok "style posé au 1er login ($(grep -m1 '^id' ~/.config/thomas-os/actuel.conf))"
    else ko "style non posé au 1er login"; fi
    journalctl --user -b --no-pager 2>/dev/null | grep -iE 'thomas-style|⚠️|Erreur :' | tail -6 | sed 's/^/INFO    /'
    ;;
applis)
    for _ in $(seq 72); do [[ -n "$(systemctl show -p ExecMainExitTimestamp --value thomas-flatpak-preinstall.service)" ]] && break; sleep 10; done
    info "service des applis : $(systemctl show -p Result --value thomas-flatpak-preinstall.service)"
    info "applis Flatpak installées : $(flatpak list --app --columns=application | tr '\n' ' ')"
    ;;
*)
    echo "usage : verifier.sh demarrage|session|applis"; exit 2 ;;
esac
exit $((erreurs > 0))
