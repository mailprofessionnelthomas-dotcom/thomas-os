#!/bin/bash
# Phase 9 : arguments du noyau ajoutés par Bazzite (le logo de démarrage ne s'affiche qu'avec rhgb/splash),
# et images dont un thème Plymouth « two-step » a besoin (fenêtre de mot de passe).
t() { echo; echo "===== $*"; }

t "bazzite-hardware-setup : arguments du noyau"
f="$(command -v bazzite-hardware-setup || ls /usr/libexec/bazzite-hardware-setup* 2>/dev/null | head -1)"
echo "script : ${f:-?}"
[[ -n "${f}" ]] && grep -nE 'kargs|rhgb|splash|quiet|plymouth|reboot' "${f}" | head -60

t "autres scripts de Bazzite qui touchent rhgb/splash/plymouth"
grep -rIlE 'rhgb|splash' /usr/libexec /usr/bin /usr/lib/systemd/system /usr/share/ublue-os 2>/dev/null | head -20

t "thème spinner : fichiers (pour la fenêtre de mot de passe)"
ls /usr/share/plymouth/themes/spinner/ | grep -v '^animation-\|^throbber-'
ls /usr/share/plymouth/themes/spinner/ | grep -c '^throbber-' | sed 's/^/images throbber : /'
ls /usr/share/plymouth/themes/spinner/ | grep -c '^animation-' | sed 's/^/images animation : /'
file /usr/share/plymouth/themes/spinner/throbber-0001.png 2>/dev/null || python3 -c 'import struct;d=open("/usr/share/plymouth/themes/spinner/throbber-0001.png","rb").read(24);print("taille throbber", struct.unpack(">II", d[16:24]))'
cat /usr/share/plymouth/themes/spinner/spinner.plymouth | grep -v '^Name\['

t "modules Plymouth installés"
ls /usr/lib64/plymouth/
rpm -q plymouth-plugin-script plymouth-plugin-fade-throbber 2>&1 | head

t "dracut : module plymouth (ce qu'il copie)"
ls /usr/lib/dracut/modules.d/ | grep -i plymouth
sed -n '1,80p' /usr/lib/dracut/modules.d/*plymouth*/plymouth-populate-initrd.sh 2>/dev/null | grep -nE 'THEME|defaults|ImageDir|inst' | head -30
