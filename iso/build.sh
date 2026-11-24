#!/usr/bin/bash
# Image « installateur » de Thomas OS (clé USB). Exécuté pendant « podman build iso/ » sur GitHub.
# Repris de Bazzite (installer/build.sh), sans les Flatpaks : sur Thomas OS ils s'installent au 1er démarrage.
#   BASE_IMAGE             : l'image Thomas OS qui sert de session live (même look que le système installé)
#   INSTALL_IMAGE_PAYLOAD  : l'image installée sur le disque (copiée dans l'ISO : installation sans Internet)
set -exo pipefail
: "${BASE_IMAGE:?}" "${INSTALL_IMAGE_PAYLOAD:?}"

mkdir -p "$(realpath /root)"
# podman (pour copier l'image à installer) a besoin d'écrire dans /proc/sys
mount -o remount,rw /proc/sys

# 1. L'image à installer, dans le stockage de conteneurs de la session live
podman pull "${INSTALL_IMAGE_PAYLOAD}"

# 2. Fichiers de la session live (profil de l'installateur, clavier français, installateur au démarrage…)
cp -a /src/system_files/. /

# 3. Noyau Fedora signé (démarrage de la clé avec Secure Boot), initramfs « live »
/src/hook_preinitramfs.sh
dnf install -y dracut-live
kernel=$(kernel-install list --json pretty | jq -r '.[] | select(.has_kernel == true) | .version')
DRACUT_NO_XATTR=1 dracut -v --force --reproducible --no-hostonly \
    --add "dmsquash-live dmsquash-live-autooverlay" \
    "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

# 4. Session live KDE (compte « liveuser » ouvert tout seul)
dnf install -y livesys-scripts
sed -i "s/^livesys_session=.*/livesys_session=kde/" /etc/sysconfig/livesys
systemctl enable livesys.service livesys-late.service

# 5. Installateur (Anaconda), clé Secure Boot, réglages de la session live
INSTALL_IMAGE_PAYLOAD="${INSTALL_IMAGE_PAYLOAD}" /src/hook_postrootfs.sh

# 6. Démarrage de l'ISO : titanoboa attend shim/grub dans /boot/efi et gcdx64.efi
dnf install -y grub2-efi-x64-cdboot
mkdir -p /boot/efi
cp -av /usr/lib/efi/*/*/EFI /boot/efi/
cp -v /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/fbx64.efi

# 7. Langue, clavier et heure de la session live : français (l'installateur redemande tout)
rm -f /etc/localtime
systemd-firstboot --timezone Europe/Paris
dnf install -y glibc-langpack-fr || :
echo 'LANG=fr_FR.UTF-8' >/etc/locale.conf
printf 'KEYMAP=fr\n' >/etc/vconsole.conf

# 8. Une session live écrit dans /run (petit) : ostree a besoin de place dans /var/tmp pendant l'installation
rm -rf /var/tmp
mkdir /var/tmp
cat >/etc/systemd/system/var-tmp.mount <<'EOF'
[Unit]
Description=Plus de place pour /var/tmp dans la session live

[Mount]
What=tmpfs
Where=/var/tmp
Type=tmpfs
Options=size=50%%,nr_inodes=1m,x-systemd.graceful-option=usrquota

[Install]
WantedBy=local-fs.target
EOF
systemctl enable var-tmp.mount

# systemd-tmpfiles n'étiquette pas la cible d'installation si /mnt est un lien
rm /mnt
mkdir /mnt

# 9. Réglages de l'ISO pour titanoboa (nom du volume, menu de démarrage)
mkdir -p /usr/lib/bootc-image-builder
cp /src/iso.yaml /usr/lib/bootc-image-builder/iso.yaml

dnf clean all
