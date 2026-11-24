#!/usr/bin/env bash
# Session live de la clé USB : installateur (Anaconda), clé Secure Boot, et réglages propres à la clé.
# Repris de Bazzite (installer/titanoboa_hook_postrootfs.sh), en français, pour Thomas OS.
set -exo pipefail
: "${INSTALL_IMAGE_PAYLOAD:?}"
image="${INSTALL_IMAGE_PAYLOAD%:*}"
canal="${INSTALL_IMAGE_PAYLOAD##*:}"

dnf -qy versionlock clear || :

# Installateur Anaconda (interface web dans Firefox), et petites fenêtres de dialogue
dnf install -qy --enable-repo=fedora-cisco-openh264 --allowerasing firefox anaconda-live libblockdev-{btrfs,lvm,dm}
dnf install -qy --setopt=install_weak_deps=0 yad
mkdir -p /var/lib/rpm-state  # nécessaire à l'interface web d'Anaconda

# Clé publique Secure Boot de Universal Blue : elle signe le noyau de Bazzite, donc celui du système installé.
# Prise dans l'image si elle y est, sinon chez Universal Blue (même clé que l'ISO de Bazzite).
CLE_SB=/usr/share/thomas-os/secureboot.der
mkdir -p /usr/share/thomas-os
cle_locale="$(find /etc/pki/akmods /usr/share/ublue-os /usr/etc/pki/akmods -name '*.der' 2>/dev/null | head -1 || :)"
if [[ -n "${cle_locale}" ]]; then cp "${cle_locale}" "${CLE_SB}"; else
    curl --retry 3 -fLo "${CLE_SB}" https://github.com/ublue-os/akmods/raw/main/certs/public_key.der
fi
openssl x509 -inform der -in "${CLE_SB}" -noout -subject -fingerprint -sha256

# Mot de passe d'enrôlement de la clé (une seule fois, sur l'écran bleu « MOK » au 1er redémarrage). Il n'a rien
# de secret : il prouve seulement que quelqu'un est devant le PC. Choisi sans a/q/z/w/m : il se tape pareil en
# AZERTY et en QWERTY (l'écran MOK est toujours en QWERTY).
MDP_MOK="secureboot"

cat >>/usr/share/anaconda/interactive-defaults.ks <<EOF

%pre
mkdir -p /tmp/thomas-os-journaux
%end

# Partition Windows chiffrée (BitLocker) : prévenir avant de toucher aux disques
%pre --erroronfail --log=/tmp/thomas-os-journaux/bitlocker.log
if [[ \$(lsblk -o FSTYPE --json | jq '.blockdevices | map(select(.fstype == "BitLocker")) | . != []') == true ]]; then
    run0 --user=liveuser yad --on-top --width=520 --title="Thomas OS" \\
        --text="<span size='x-large'>Partition Windows chiffrée (BitLocker)</span>\n\nL'installation peut échouer. Le plus simple : désactiver BitLocker dans Windows, puis recommencer.\n\nContinuer quand même ?" \\
        --button="Continuer":0 --button="Annuler l'installation":10
    if [[ \$? -eq 10 ]]; then pkill liveinst; pkill firefox; exit 0; fi
fi
%end

# Dossier EFI à remplacer (doit correspondre à efi_dir dans le profil de l'installateur)
%pre-install --erroronfail
rm -rf /mnt/sysroot/boot/efi/EFI/fedora
%end

# Étiquette de la partition /boot attendue par les outils de Bazzite
%pre-install --erroronfail --log=/tmp/thomas-os-journaux/partitions.log
set -x
xboot_dev=\$(findmnt -o SOURCE --nofsroot --noheadings -f --target /mnt/sysroot/boot)
[[ -n \$xboot_dev ]] || { echo "ERREUR : partition /boot introuvable"; exit 1; }
e2label "\$xboot_dev" "bazzite_xboot"
%end

%onerror
run0 --user=liveuser yad --timeout=0 --text-info --no-buttons --width=700 --height=450 \\
    --text="L'installation a échoué. Le journal ci-dessous aide à comprendre pourquoi." </tmp/anaconda.log
%end

# Le système installé = l'image Thomas OS copiée dans la clé (sans Internet), puis il suit le canal « ${canal} »
ostreecontainer --url=${image}:${canal} --transport=containers-storage --no-signature-verification

# Écran de connexion graphique au démarrage, imposé : sinon l'installateur le devine (lu dans son code,
# pyanaconda/modules/services/installation.py) et il choisit le mode texte s'il ne trouve pas le paquet.
xconfig --startxonboot

# Logo de démarrage (Plymouth) au lieu du texte qui défile : « rhgb quiet », imposé pour la même raison
# (lu dans pyanaconda/modules/storage/bootloader/base.py : ajouté seulement s'il trouve le paquet plymouth).
bootloader --append="rhgb quiet"

%post --erroronfail --log=/tmp/thomas-os-journaux/canal.log
bootc switch --mutate-in-place --transport registry ${image}:${canal}
%end

# Étiquettes SELinux remises en place (repris de Bazzite : sinon des fichiers de sécurité restent mal étiquetés)
%post --erroronfail --log=/tmp/thomas-os-journaux/selinux.log
setenforce 0 || true
restorecon -R /etc/selinux
restorecon -R /var/lib/flatpak || true
%end

# Pas de dépôt Flatpak de Fedora : Thomas OS installe ses applis depuis Flathub
%post --erroronfail --log=/tmp/thomas-os-journaux/flatpak.log
systemctl disable flatpak-add-fedora-repos.service || :
%end

# Secure Boot : la clé du noyau est proposée au micrologiciel ; elle s'enregistre au 1er redémarrage (écran bleu MOK)
%post --erroronfail --nochroot --log=/tmp/thomas-os-journaux/secureboot.log
set -uo pipefail
[[ -d /sys/firmware/efi ]] || { echo "Démarrage sans UEFI : rien à faire"; exit 0; }
mokutil --timeout -1 || :
echo -e "${MDP_MOK}\n${MDP_MOK}" | mokutil --import "${CLE_SB}" || :
%end

%post --nochroot --log=/tmp/thomas-os-journaux/secureboot-aide.log
LC_ALL=C mokutil -t "${CLE_SB}" | grep -q "is already in the enrollment request" && \\
run0 --user=liveuser yad --timeout=0 --on-top --width=560 --title="Thomas OS : Secure Boot" --button=OK:0 \\
    --text="<b>Encore une étape, au 1er redémarrage :</b>\n\nUn écran bleu « MOK management » apparaît.\n  1. Choisis « Enroll MOK », puis « Continue », puis « Yes ».\n  2. Tape le mot de passe : <b>${MDP_MOK}</b> (puis Entrée).\n  3. Choisis « Reboot ».\n\nC'est tout : Secure Boot reste activé, Windows et FACEIT ne changent pas."
%end
EOF

### Réglages de la session live (ils ne vont pas sur le disque : le système installé vient de l'image) ###
(
    set +e
    for s in rpm-ostree-countme.service tailscaled.service bazzite-hardware-setup.service ublue-hardware-setup.service \
        bootloader-update.service rpm-ostreed-automatic.timer uupd.timer ublue-system-setup.service \
        bazzite-flatpak-manager.service ublue-flatpak-manager.service flatpak-add-fedora-repos.service \
        greenboot-set-rollback-trigger.service greenboot-healthcheck.service check-sb-key.service \
        thomas-flatpak-preinstall.timer thomas-nettoyage.timer; do
        systemctl list-unit-files "${s}" >/dev/null 2>&1 && systemctl disable "${s}"
    done
    for s in podman-auto-update.timer bazzite-user-setup.service ublue-user-setup.service \
        thomas-jeu.timer thomas-surveillance.timer; do
        systemctl --global list-unit-files "${s}" >/dev/null 2>&1 && systemctl --global disable "${s}"
    done
)
# Pas d'écran de bienvenue dans la session live : c'est l'installateur qui s'ouvre (fichiers dans system_files)
rm -f /etc/xdg/autostart/org.thomasos.welcome.desktop
rm -f /etc/profile.d/verify_motd.sh
rm -f /usr/bin/rpm-ostree  # ne doit jamais tourner dans la session live
systemctl enable thomas-live-pret.service
