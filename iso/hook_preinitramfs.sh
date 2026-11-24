#!/usr/bin/env bash
# Session live : le noyau de Bazzite (signé par la clé Universal Blue) est remplacé par le noyau de Fedora,
# signé par Fedora et accepté par Secure Boot sans rien faire. La clé USB démarre donc avec Secure Boot activé.
# (Le système installé garde le noyau de Bazzite : sa clé est ajoutée à l'installation, voir hook_postrootfs.sh.)
# Repris de Bazzite (installer/titanoboa_hook_preinitramfs.sh).
set -exo pipefail

paquets_noyau=(kernel kernel-core kernel-devel kernel-devel-matched kernel-modules kernel-modules-core kernel-modules-extra)
dnf -y versionlock delete "${paquets_noyau[@]}" || :
dnf --setopt=protect_running_kernel=False -y remove "${paquets_noyau[@]}"
(cd /usr/lib/modules && rm -rf -- ./*)
dnf -y --repo fedora,updates --setopt=tsflags=noscripts install kernel kernel-core
kernel=$(find /usr/lib/modules -maxdepth 1 -type d -printf '%P\n' | grep .)
depmod "${kernel}"

# micrologiciels des cartes NVIDIA (pilote libre « nouveau » dans la session live)
dnf install -yq nvidia-gpu-firmware || :
dnf clean all -yq
