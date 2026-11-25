#!/bin/bash
# Installateur Thomas OS : ce que l'image sait déjà faire avec un fichier téléchargé (.exe, .msi, .deb, .rpm,
# .AppImage…) : types de fichiers reconnus, applis associées, droits Flatpak, outils présents.
t() { echo; echo "===== $*"; }
d="$(mktemp -d)"

t "types de fichiers (base shared-mime-info, comme Dolphin)"
printf 'MZ\x90\x00\x03\x00\x00\x00\x04\x00\x00\x00\xff\xff\x00\x00' >"${d}/SteamSetup.exe"
printf '\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1\x00\x00\x00\x00\x00\x00\x00\x00' >"${d}/EpicInstaller-18.8.1.msi"
printf '!<arch>\ndebian-binary   1700000000  0     0     100644  4         `\n2.0\n' >"${d}/steam_latest.deb"
printf '\xed\xab\xee\xdb\x03\x00\x00\x00\x00\x01' >"${d}/discord-0.0.76.rpm"
printf '\x7fELF\x02\x01\x01\x00AI\x02\x00\x00\x00\x00\x00' >"${d}/Appli-1.0-x86_64.AppImage"
printf '[Flatpak Ref]\nName=org.example.App\n' >"${d}/app.flatpakref"
printf '\x1f\x8b\x08\x00\x00\x00\x00\x00' >"${d}/heroic-2.15.tar.gz"
for f in "${d}"/*; do
  printf '%-32s %s\n' "$(basename "${f}")" "$(gio info -a standard::content-type "${f}" 2>/dev/null | sed -n 's/.*content-type: //p')"
done
python3 - "${d}" <<'EOF'
import sys, os, gi
from gi.repository import Gio
for n in sorted(os.listdir(sys.argv[1])):
    t, incertain = Gio.content_type_guess(n, open(os.path.join(sys.argv[1], n), "rb").read())
    print(f"  python Gio : {n:32} {t} (incertain={incertain})")
EOF

t "parents MIME (ce que KDE considère aussi)"
for m in application/x-ms-dos-executable application/x-msdownload application/x-msi application/vnd.debian.binary-package application/x-rpm application/vnd.appimage; do
  grep -A20 "<mime-type type=\"${m}\"" /usr/share/mime/packages/freedesktop.org.xml 2>/dev/null | grep -E 'sub-class-of|alias|glob ' | tr -s ' ' | head -6 | sed "s#^#${m} : #"
done

t "associations par défaut existantes (mimeapps.list)"
for f in /usr/share/applications/mimeapps.list /usr/share/applications/kde-mimeapps.list /etc/xdg/mimeapps.list \
         /etc/xdg/kde-mimeapps.list /usr/share/applications/defaults.list /usr/share/kde-settings/kde-profile/default/xdg/mimeapps.list; do
  [[ -f "${f}" ]] && { echo "--- ${f} ($(wc -l <"${f}") lignes)"; grep -iE 'exe|msi|deb|rpm|appimage|flatpak|x-compressed|^\[' "${f}" | head -20; }
done
find / -xdev -name '*mimeapps.list' -not -path '/proc/*' 2>/dev/null | head -20

t "applis qui se déclarent pour ces types"
grep -lE 'MimeType=.*(x-ms-dos-executable|x-msi|x-msdownload|debian.binary-package|x-rpm|appimage|flatpak.ref)' \
  /usr/share/applications/*.desktop 2>/dev/null | while read -r f; do echo "${f} : $(grep -m1 '^Exec=' "${f}")"; done

t "Bazaar (fichier .desktop)"
for f in /usr/share/applications/*azaar*.desktop; do echo "--- ${f}"; grep -E '^(Exec|MimeType|Name)=' "${f}"; done
command -v bazaar; bazaar --help 2>&1 | head -40

t "droits Flatpak (polkit)"
ls /usr/share/polkit-1/rules.d/ /etc/polkit-1/rules.d/ 2>/dev/null
cat /usr/share/polkit-1/rules.d/*flatpak* 2>/dev/null
grep -A6 'id="org.freedesktop.Flatpak.\(app-install\|runtime-install\|appstream-update\)"' /usr/share/polkit-1/actions/org.freedesktop.Flatpak.policy 2>/dev/null | grep -E 'action id|allow_'
flatpak remotes --system --columns=name,url 2>&1; flatpak --version
ls /etc/flatpak/remotes.d/ /usr/share/flatpak/remotes.d/ 2>/dev/null

t "outils présents"
for c in flatpak kdialog gio gdbus qdbus qdbus6 busctl notify-send xdg-mime xdg-open python3 wine wine64 umu-run bottles winetricks \
         dolphin ark plasma-discover gearlever appimagelauncherd; do
  printf '%-14s %s\n' "${c}" "$(command -v "${c}" || echo '—')"
done
python3 -c 'import sys; print("python", sys.version.split()[0])'
python3 -c 'import compression.zstd; print("compression.zstd : oui")' 2>&1 | tail -1
rpm -q fuse fuse-libs fuse3 fuse3-libs wine umu-launcher 2>&1
ls /usr/lib64/libfuse.so.2* 2>/dev/null

t "Bazzite : recettes ujust qui parlent de Wine/Bottles/AppImage"
grep -rIlE 'bottles|wine|appimage' /usr/share/ublue-os/just 2>/dev/null | head
grep -rIhE '^[a-z-]+.*:' /usr/share/ublue-os/just/*.just 2>/dev/null | grep -iE 'bottles|wine|appimage' | head

t "portail (ouvrir un fichier depuis un navigateur Flatpak)"
ls /usr/share/xdg-desktop-portal/ 2>/dev/null; cat /usr/share/xdg-desktop-portal/*portals.conf 2>/dev/null | head -20
rpm -q xdg-desktop-portal xdg-desktop-portal-kde 2>&1

t "dossier Téléchargements (xdg-user-dirs)"
grep -i download /etc/xdg/user-dirs.defaults 2>/dev/null; cat /etc/xdg/user-dirs.conf 2>/dev/null | grep -v '^#'
rm -rf "${d}"
