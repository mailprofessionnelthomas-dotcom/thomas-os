#!/bin/bash
# Phase 9 (suite) : réglages de l'écran de connexion posés par Bazzite, QML de l'accueil, clés écrites par le
# module de Configuration, et fabrication de l'initramfs (pour un thème Plymouth).
t() { echo; echo "===== $*"; }

t "/usr/lib/plasmalogin : defaults.conf et plasmalogin.conf.d"
find /usr/lib/plasmalogin /etc/plasmalogin.conf.d -type f 2>/dev/null | while read -r f; do echo "--- ${f}"; cat "${f}"; done
echo "propriétaire de defaults.conf : $(rpm -qf /usr/lib/plasmalogin/defaults.conf 2>&1)"

t "chemins de config lus par plasmalogin / l'accueil (chaînes du binaire)"
for b in /usr/bin/plasmalogin /usr/libexec/plasma-login-greeter /usr/bin/plasma-login-wallpaper /usr/bin/startplasma-login-wayland; do
    echo "--- ${b}"
    grep -aoE '(/[a-z0-9._-]+)+(\.conf|\.d|\.qml)?|[A-Za-z]+\.(conf|qml)|qrc:[A-Za-z0-9/._-]+|[A-Z][A-Za-z]+PluginId|kdedefaults|state\.conf' "${b}" 2>/dev/null \
        | grep -iE 'plasmalogin|login|greeter|wallpaper|kdedefaults|state|qml|lookandfeel|look-and-feel' | sort -u | head -40
done

t "module de Configuration (kcm) de l'écran de connexion : fichiers et clés"
rpm -qa | grep -iE 'plasma-login|kcm.*login|login.*kcm' | sort
for f in $(find /usr/lib64/qt6/plugins -iname '*login*' 2>/dev/null) $(find /usr/libexec -iname '*login*' 2>/dev/null); do
    echo "--- ${f}"
    grep -aoE '[A-Za-z][A-Za-z0-9_/.-]{3,}' "${f}" 2>/dev/null | grep -E '^(Greeter|Wallpaper|WallpaperPluginId|Theme|Current|CursorTheme|CursorSize|Font|ColorScheme|LookAndFeelPackage|kdeglobals|kdedefaults|plasmarc|kcminputrc|kwinrc|ksplashrc|/var/lib/plasmalogin.*|/etc/plasmalogin.*|org\.kde\.[a-z.]+)$' | sort -u | head -50
done

t "accueil : QML et paquets Plasma (look-and-feel) qui contiennent un écran de connexion / verrouillage"
rpm -ql plasma-workspace 2>/dev/null | grep -iE 'loginlockscreen|lockscreen|login' | head -30
ls -d /usr/share/plasma/look-and-feel/*/ 2>/dev/null
for d in /usr/share/plasma/look-and-feel/*/contents; do ls "${d}" 2>/dev/null | tr '\n' ' '; echo " <- ${d}"; done
ls /usr/share/plasma/shells/ 2>/dev/null

t "état de l'accueil (/var/lib/plasmalogin) dans l'image"
find /var/lib/plasmalogin -maxdepth 4 2>/dev/null | head -30

t "fabrication de l'initramfs : config dracut"
for f in /usr/lib/dracut/dracut.conf.d/* /etc/dracut.conf.d/* /etc/dracut.conf; do [[ -f "${f}" ]] && { echo "--- ${f}"; grep -v '^#' "${f}" | grep .; }; done
k="$(ls /usr/lib/modules | head -1)"
lsinitrd "/usr/lib/modules/${k}/initramfs.img" 2>/dev/null | head -20
lsinitrd -f etc/plymouth/plymouthd.conf "/usr/lib/modules/${k}/initramfs.img" 2>/dev/null
lsinitrd "/usr/lib/modules/${k}/initramfs.img" 2>/dev/null | grep -c . | sed 's/^/fichiers dans l initramfs : /'

t "arguments du noyau prévus par l'image (bootc / ostree)"
ls -la /usr/lib/bootc/kargs.d/ 2>/dev/null; cat /usr/lib/bootc/kargs.d/* 2>/dev/null
cat /usr/lib/ostree/prepare-root.conf 2>/dev/null
grep -rIl 'rhgb' /usr/lib/bootc /usr/lib/ostree /usr/share/ublue-os /usr/libexec 2>/dev/null | head
