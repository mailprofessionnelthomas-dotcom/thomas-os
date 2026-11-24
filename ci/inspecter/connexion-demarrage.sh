#!/bin/bash
# Phase 9 : où l'écran de connexion (Plasma Login Manager) et le logo de démarrage (Plymouth) prennent leur look.
t() { echo; echo "===== $*"; }

t "paquet de l'écran de connexion"
pkg="$(rpm -qf /usr/bin/plasmalogin* /usr/libexec/plasmalogin* 2>/dev/null | sort -u | grep -v 'not owned' | head -3)"
echo "${pkg:-?}"
rpm -q --qf '%{NAME} %{VERSION}\n' ${pkg} 2>/dev/null

t "fichiers du paquet (hors traductions, icônes, docs)"
for p in ${pkg}; do rpm -ql "${p}" | grep -vE '/locale/|/doc/|/man/|/icons/'; done | head -150

t "config système : /etc/plasmalogin* et /usr/lib|share/plasmalogin*"
for f in /etc/plasmalogin.conf /etc/plasmalogin.conf.d/* /usr/lib/plasmalogin.conf.d/* /usr/share/plasmalogin/plasmalogin.conf* /usr/lib/sddm/sddm.conf.d/* /etc/sddm.conf.d/*; do
    [[ -f "${f}" ]] && { echo "--- ${f}"; cat "${f}"; }
done

t "dossier de l'utilisateur plasmalogin (accueil)"
getent passwd plasmalogin
ls -la /var/lib/plasmalogin 2>/dev/null; ls -la /usr/share/factory/var/lib/plasmalogin 2>/dev/null
cat /usr/lib/tmpfiles.d/*plasmalogin* 2>/dev/null

t "clés de config connues du binaire (strings)"
for b in /usr/bin/plasmalogin* /usr/libexec/plasmalogin* /usr/lib64/libplasmalogin* /usr/lib64/qt6/plugins/*/*plasmalogin*; do
    [[ -f "${b}" ]] || continue
    echo "--- ${b}"
    grep -aoE '[A-Za-z0-9/._-]{4,}' "${b}" 2>/dev/null | grep -E '^(Greeter|Wallpaper|WallpaperPluginId|Theme|ThemeDir|Current|CursorTheme|Font|ColorScheme|LookAndFeel|Numlock|Background|General|Users|X11|Wayland)[A-Za-z]*$|plasmalogin\.conf|kdedefaults|/var/lib/plasmalogin' | sort -u | head -60
done

t "QML de l'accueil (greeter)"
find / -xdev \( -path /proc -o -path /sys \) -prune -o -type d \( -iname '*plasmalogin*' -o -path '*plasma/login*' \) -print 2>/dev/null | head -30
find /usr/share/plasmalogin /usr/lib64/qt6/qml -path '*login*' -name '*.qml' 2>/dev/null | head -40

t "fond actuel de l'écran de connexion (Bazzite) : où est-il réglé ?"
grep -rIl -E 'Greeter|org\.kde\.image' /etc/plasmalogin* /usr/lib/plasmalogin* /usr/share/plasmalogin* /etc/skel 2>/dev/null | head
grep -rI -iE 'plasmalogin|Greeter' /usr/share/ublue-os /usr/libexec/bazzite* /usr/lib/systemd/system/*bazzite* 2>/dev/null | head -20
ls /usr/share/wallpapers /usr/share/backgrounds 2>/dev/null | head -40

t "Plymouth : thème actuel et thèmes présents"
cat /etc/plymouth/plymouthd.conf 2>/dev/null | grep -v '^#' | grep .
cat /usr/share/plymouth/plymouthd.defaults 2>/dev/null | grep -v '^#' | grep .
ls /usr/share/plymouth/themes/
for d in /usr/share/plymouth/themes/*/; do echo "--- ${d}"; ls "${d}" | head -12; cat "${d}"*.plymouth 2>/dev/null; done 2>/dev/null | head -120
rpm -qa 'plymouth*' | sort

t "Plymouth dans l'initramfs de l'image (bootc : l'initramfs est fabriqué dans l'image)"
k="$(ls /usr/lib/modules | head -1)"; echo "noyau : ${k}"
ls -la "/usr/lib/modules/${k}/initramfs.img" 2>/dev/null
lsinitrd "/usr/lib/modules/${k}/initramfs.img" 2>/dev/null | grep -E 'plymouth/themes|plymouthd.conf|label-|\.ttf|\.otf' | head -30

t "arguments du noyau (rhgb quiet splash ?)"
cat /usr/lib/bootc/kargs.d/*.toml 2>/dev/null
grep -rI -E 'rhgb|splash|quiet' /usr/lib/bootc/kargs.d /usr/lib/kernel/cmdline* /etc/kernel/cmdline* 2>/dev/null

t "dracut : config qui concerne plymouth"
grep -rI -iE 'plymouth|omit' /usr/lib/dracut/dracut.conf.d /etc/dracut.conf.d 2>/dev/null | head -20
command -v dracut plymouth-set-default-theme
