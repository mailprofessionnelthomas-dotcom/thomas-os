#!/usr/bin/bash
# Thomas OS : script lancé pendant la construction de l'image (sur les serveurs GitHub).
# Les variables viennent du Containerfile (build-args).

set -euxo pipefail

: "${BASE_IMAGE:?}" "${IMAGE_NAME:?}" "${IMAGE_VENDOR:?}" "${IMAGE_VERSION:?}" "${GPU_VARIANT:?}"

IMAGE_REF="ghcr.io/${IMAGE_VENDOR}/${IMAGE_NAME}"
# Canal par défaut des PC installés depuis la clé USB. Le PC de Thomas passe sur "testing".
# La même image passe de "testing" à "stable" sans être reconstruite : on n'écrit donc
# pas le canal réel ici, on le lit au démarrage avec "bootc status".
DEFAULT_CHANNEL="stable"
REPO_URL="https://github.com/${IMAGE_VENDOR}/thomas-os"

# 1. Fichiers maison (system_files/ du repo -> / de l'image)
cp -avf /ctx/system_files/. /

# 1a. Ce que Thomas ne veut pas, livré par Bazzite (choix du 2026-11-22) :
#     Steam et Lutris (chacun installe ses jeux lui-même depuis la boutique),
#     ancien thème Oxygen (inutile avec les styles Thomas OS).
#     Les outils de jeu invisibles (Gamescope, MangoHud...) restent : un jeu installé
#     plus tard tournera directement.
REMOVE_PKGS=(steam lutris plasma-oxygen oxygen-icon-theme)
installed_remove=()
for pkg in "${REMOVE_PKGS[@]}"; do
    rpm -q "${pkg}" >/dev/null 2>&1 && installed_remove+=("${pkg}")
done
if ((${#installed_remove[@]})); then
    dnf5 -y remove "${installed_remove[@]}"
fi
# Lanceurs automatiques de Steam laissés par Bazzite (s'ils existent)
rm -f /etc/skel/.config/autostart/steam.desktop /etc/xdg/autostart/steam.desktop

# 1b. Applis en paquets système (seulement celles qui marchent mal en Flatpak)
#     - VS Code : en Flatpak il ne voit pas Python, Node.js ni Git du système
#     - Claude Code : dépôt officiel d'Anthropic, canal "stable" ; mis à jour avec Thomas OS
#     - Node.js, pip, Git : outils système
#     Les dépôts sont désactivés après installation : les mises à jour arrivent
#     avec l'image Thomas OS (reconstruite chaque jour), pas par dnf.

cat >/etc/yum.repos.d/vscode.repo <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# Clé de signature Claude Code : on vérifie que c'est bien celle d'Anthropic avant de lui faire confiance
CLAUDE_KEY_FPR="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"
command -v gpg >/dev/null || dnf5 install -y gnupg2
curl --retry 3 -fsSL https://downloads.claude.ai/keys/claude-code.asc -o /tmp/claude-code.asc
# Pendant le build, /root n'existe pas : gpg travaille dans un dossier temporaire
GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
gpg --show-keys --with-colons /tmp/claude-code.asc | grep '^fpr:' | cut -d: -f10 | grep -qx "${CLAUDE_KEY_FPR}" || {
    echo "ERREUR : la clé de signature Claude Code n'a pas l'empreinte attendue"
    exit 1
}
rm -rf "${GNUPGHOME}"
unset GNUPGHOME
install -D -m 0644 /tmp/claude-code.asc /etc/pki/rpm-gpg/RPM-GPG-KEY-claude-code
cat >/etc/yum.repos.d/claude-code.repo <<'EOF'
[claude-code]
name=Claude Code
baseurl=https://downloads.claude.ai/claude-code/rpm/stable
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-claude-code
EOF

dnf5 install -y \
    code \
    claude-code \
    nodejs \
    nodejs-npm \
    python3-pip \
    git \
    papirus-icon-theme
# Outils système KDE retenus par Thomas (23/11/2026) : en paquets système (Spectacle a besoin d'être natif
# pour capturer l'écran sous Wayland). Déjà présents dans Bazzite ? dnf ne fait alors rien.
dnf5 install -y konsole spectacle ark
# Papirus sombre : paquet à part dans Fedora (nom vérifié par « thomas-style verifier-systeme » plus bas)
dnf5 install -y papirus-icon-theme-dark || echo "ATTENTION : paquet papirus-icon-theme-dark introuvable"

sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/vscode.repo /etc/yum.repos.d/claude-code.repo

# 1c. Applis Flatpak : la liste system_files/usr/share/thomas-os/flatpaks.list devient un
#     fichier "preinstall" de Flatpak. Le service thomas-flatpak-preinstall installe ce qui
#     manque au démarrage, et ne réinstalle jamais une appli désinstallée volontairement.
install -d /etc/flatpak/remotes.d
if [[ ! -s /etc/flatpak/remotes.d/flathub.flatpakrepo ]]; then
    curl --retry 3 -fsSL https://dl.flathub.org/repo/flathub.flatpakrepo -o /etc/flatpak/remotes.d/flathub.flatpakrepo
fi

FLATPAK_LIST=/usr/share/thomas-os/flatpaks.list
PREINSTALL=/usr/share/flatpak/preinstall.d/thomas-os.preinstall
install -d "$(dirname "${PREINSTALL}")"
DEJA_RPM=/tmp/flatpak-deja-rpm.txt
: >"${DEJA_RPM}"
{
    echo "# Généré depuis ${FLATPAK_LIST} au build de Thomas OS : ne pas modifier ici"
    grep -Ev '^[[:space:]]*(#|$)' "${FLATPAK_LIST}" | while IFS=/ read -r kind app_id arch branch; do
        [[ "${kind}" == "app" || "${kind}" == "runtime" ]] || { echo "ERREUR ligne invalide : ${kind}/${app_id}" >&2; exit 1; }
        [[ -n "${app_id}" && "${arch}" == "x86_64" && -n "${branch}" ]] || { echo "ERREUR ligne invalide : ${kind}/${app_id}/${arch}/${branch}" >&2; exit 1; }
        # Pas de doublon : si l'appli est déjà là en paquet système, on n'installe pas aussi le Flatpak
        if [[ "${kind}" == "app" && -f "/usr/share/applications/${app_id}.desktop" ]]; then
            echo "${app_id}" >>"${DEJA_RPM}"
            continue
        fi
        echo ""
        echo "[Flatpak Preinstall ${app_id}]"
        echo "Branch=${branch}"
        if [[ "${kind}" == "runtime" ]]; then echo "IsRuntime=true"; else echo "IsRuntime=false"; fi
    done
} >"${PREINSTALL}"
chmod 0644 "${PREINSTALL}"
echo "Flatpaks non installés car déjà en paquet système : $(tr '\n' ' ' <"${DEJA_RPM}")"
for f in /usr/share/flatpak/preinstall.d/*.preinstall; do
    [[ "${f}" == "${PREINSTALL}" ]] || echo "Flatpaks prévus par Bazzite ($(basename "${f}")) : $(grep -o '^\[Flatpak Preinstall [^]]*' "${f}" | cut -d' ' -f3 | tr '\n' ' ')"
done
systemctl enable thomas-flatpak-preinstall.timer

# 1d. Zéro télémétrie : on coupe le compteur anonyme de Fedora (rpm-ostree countme).
#     KDE n'envoie rien par défaut ; on le fixe quand même (/etc/xdg/PlasmaUserFeedback).
systemctl mask rpm-ostree-countme.timer rpm-ostree-countme.service

# 1e. Styles Thomas OS (thomas-style + 12 styles + horloge de bureau)
#     Polices libres (licence OFL) depuis le dépôt officiel Google Fonts
FONT_DIR=/usr/share/fonts/thomas-os
LIC_DIR=/usr/share/licenses/thomas-os-fonts
install -d "${FONT_DIR}" "${LIC_DIR}"
GF=https://raw.githubusercontent.com/google/fonts/main/ofl
for f in "manrope/Manrope[wght].ttf" "opensans/OpenSans[wdth,wght].ttf" "outfit/Outfit[wght].ttf" \
    "nunito/Nunito[wght].ttf" "ibmplexsans/IBMPlexSans[wdth,wght].ttf" "jetbrainsmono/JetBrainsMono[wght].ttf" \
    "rajdhani/Rajdhani-Light.ttf" "rajdhani/Rajdhani-Regular.ttf" "rajdhani/Rajdhani-Medium.ttf" "rajdhani/Rajdhani-Bold.ttf"; do
    url="${GF}/${f//\[/%5B}"
    url="${url//\]/%5D}"
    curl --retry 3 -fsSL "${url}" -o "${FONT_DIR}/$(basename "${f}" | tr -d '[]' | tr ',' '-')"
done
for fam in manrope opensans outfit nunito ibmplexsans jetbrainsmono rajdhani; do
    curl --retry 3 -fsSL "${GF}/${fam}/OFL.txt" -o "${LIC_DIR}/${fam}-OFL.txt"
done
fc-cache -f "${FONT_DIR}"

#     Coins arrondis des fenêtres (KDE Rounded Corners). Optionnel : si le paquet ne
#     s'installe pas pour cette version de KDE, Thomas OS marche sans (coins Breeze).
if dnf5 -y copr enable matinlotfali/KDE-Rounded-Corners && dnf5 -y install kwin-effect-roundcorners; then
    echo "Coins arrondis : installés"
else
    echo "::warning::Coins arrondis indisponibles pour cette version de KDE (Thomas OS marche sans)"
fi
dnf5 -y copr disable matinlotfali/KDE-Rounded-Corners || true

#     Identité visuelle (identite/) : jetons de design, logo T, fond d'écran fabriqué ici (Python standard)
install -D -m 0644 /ctx/identite/tokens.json /usr/share/thomas-os/identite/tokens.json
install -D -m 0644 /ctx/identite/logo/thomas-os.svg /usr/share/icons/hicolor/scalable/apps/thomas-os.svg
install -D -m 0644 /ctx/identite/logo/thomas-os.svg /usr/share/thomas-os/identite/logo/thomas-os.svg
python3 /ctx/identite/fond.py /usr/share/wallpapers/ThomasOS
#     Alt+Espace ouvre le menu Thomas OS : la recherche KRunner garde Alt+F2 et la touche Recherche
for f in /usr/share/applications/org.kde.krunner.desktop /usr/share/kglobalaccel/org.kde.krunner.desktop; do
    [[ -e "${f}" ]] && sed -i --follow-symlinks 's/^X-KDE-Shortcuts=.*/X-KDE-Shortcuts=Alt+F2,Search/' "${f}"
done
grep -q '^X-KDE-Shortcuts=Alt+F2,Search$' /usr/share/applications/org.kde.krunner.desktop \
    || echo "::warning::raccourci de KRunner non trouvé : Alt+Espace peut rester à la recherche"
#     Favoris du menu (mécanisme Fedora/Bazzite) : ceux de Thomas OS, à la place de ceux de Bazzite
KICKER_FAV=/usr/share/kde-settings/kde-profile/default/xdg/kicker-extra-favoritesrc
install -d "$(dirname "${KICKER_FAV}")"
python3 - "${KICKER_FAV}" <<'EOF'
import importlib.machinery, importlib.util, sys
chargeur = importlib.machinery.SourceFileLoader("ts", "/usr/bin/thomas-style")
ts = importlib.util.module_from_spec(importlib.util.spec_from_loader("ts", chargeur))
chargeur.exec_module(ts)
open(sys.argv[1], "w", encoding="utf-8").write(
    "[General]\nPrepend=" + "".join(f"{a}.desktop;" for a in ts.FAVORIS) + "\nIgnoreDefaults=true\n")
EOF
#     Fenêtres de choix (partie de base de Styles Thomas OS)
rpm -q kdialog >/dev/null || dnf5 -y install kdialog
chmod 0755 /usr/bin/thomas-style /usr/libexec/thomas-core
gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true

# 2. Nom de l'OS : "Thomas OS" partout où le système affiche son nom.
#    On garde ID=, ID_LIKE= et VERSION_ID= de Bazzite pour que ses outils continuent de marcher.
OS_RELEASE=/usr/lib/os-release
FEDORA_VERSION="$(rpm -E %fedora)"
sed -i \
    -e "s|^NAME=.*|NAME=\"Thomas OS\"|" \
    -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"Thomas OS ${FEDORA_VERSION} (base Bazzite)\"|" \
    -e "s|^HOME_URL=.*|HOME_URL=\"${REPO_URL}\"|" \
    -e "s|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL=\"${REPO_URL}#readme\"|" \
    -e "s|^SUPPORT_URL=.*|SUPPORT_URL=\"${REPO_URL}/issues\"|" \
    -e "s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"${REPO_URL}/issues\"|" \
    "${OS_RELEASE}"
grep -q '^DOCUMENTATION_URL=' "${OS_RELEASE}" || echo "DOCUMENTATION_URL=\"${REPO_URL}#readme\"" >>"${OS_RELEASE}"
grep -q '^SUPPORT_URL=' "${OS_RELEASE}" || echo "SUPPORT_URL=\"${REPO_URL}/issues\"" >>"${OS_RELEASE}"

# 3. Les outils de Bazzite (mises à jour, changement de version) lisent ce fichier :
#    on le fait pointer vers l'image Thomas OS, pas vers celle de Bazzite.
IMAGE_INFO=/usr/share/ublue-os/image-info.json
if [[ -f "${IMAGE_INFO}" ]]; then
    tmp="$(mktemp)"
    jq \
        --arg name "${IMAGE_NAME}" \
        --arg vendor "${IMAGE_VENDOR}" \
        --arg ref "ostree-unverified-registry:docker://${IMAGE_REF}" \
        --arg tag "${DEFAULT_CHANNEL}" \
        '. + {"image-name": $name, "image-vendor": $vendor, "image-ref": $ref, "image-tag": $tag}' \
        "${IMAGE_INFO}" >"${tmp}"
    install -m 0644 "${tmp}" "${IMAGE_INFO}"
    rm -f "${tmp}"
fi

# 4. Carte d'identité de Thomas OS (servira à l'écran de bienvenue pour vérifier
#    que la variante installée correspond bien à la carte graphique du PC)
install -d /usr/share/thomas-os
cat >/usr/share/thomas-os/info.env <<EOF
THOMAS_OS_IMAGE_NAME=${IMAGE_NAME}
THOMAS_OS_IMAGE_REF=${IMAGE_REF}
THOMAS_OS_VERSION=${IMAGE_VERSION}
THOMAS_OS_DEFAULT_CHANNEL=${DEFAULT_CHANNEL}
THOMAS_OS_GPU_VARIANT=${GPU_VARIANT}
THOMAS_OS_BASE_IMAGE=${BASE_IMAGE}
THOMAS_OS_BUILD_DATE=$(date -u +%Y-%m-%d)
EOF
chmod 0644 /usr/share/thomas-os/info.env

# 5. Vérifications : si un de ces tests rate, le build s'arrête (rouge sur GitHub)
grep -q '^NAME="Thomas OS"' "${OS_RELEASE}"
test -s /usr/share/thomas-os/info.env
for pkg in code claude-code nodejs nodejs-npm python3 python3-pip git papirus-icon-theme; do
    rpm -q "${pkg}" >/dev/null || { echo "ERREUR : paquet ${pkg} absent"; exit 1; }
done
# Ce qu'on a retiré est bien parti...
for pkg in "${REMOVE_PKGS[@]}"; do
    if rpm -q "${pkg}" >/dev/null 2>&1; then echo "ERREUR : ${pkg} est encore là"; exit 1; fi
done
# ...et le retrait n'a rien emporté d'important avec lui (bureau, boutique, mises à jour)
for pkg in plasma-workspace kwin dolphin konsole flatpak bazaar uupd NetworkManager; do
    rpm -q "${pkg}" >/dev/null || { echo "ERREUR : ${pkg} a disparu avec le retrait de ${REMOVE_PKGS[*]}"; exit 1; }
done
for cmd in claude code node npm python3 pip3 git; do
    command -v "${cmd}" >/dev/null || { echo "ERREUR : commande ${cmd} introuvable"; exit 1; }
done
test "$(grep -c '^\[Flatpak Preinstall ' "${PREINSTALL}")" -eq "$(( $(grep -Evc '^[[:space:]]*(#|$)' "${FLATPAK_LIST}") - $(wc -l <"${DEJA_RPM}") ))"
for pkg in konsole spectacle ark; do
    rpm -q "${pkg}" >/dev/null || { echo "ERREUR : paquet ${pkg} absent"; exit 1; }
done
flatpak preinstall --help >/dev/null
test -L /etc/systemd/system/timers.target.wants/thomas-flatpak-preinstall.timer
test "$(readlink /etc/systemd/system/rpm-ostree-countme.timer)" = "/dev/null"
# Styles : les 12 styles se génèrent sans erreur, les polices et l'horloge sont là
for cmd in thomas-style kwriteconfig6 plasma-apply-colorscheme plasma-apply-desktoptheme gdbus notify-send kdialog; do
    command -v "${cmd}" >/dev/null || { echo "ERREUR : commande ${cmd} introuvable"; exit 1; }
done
HOME="$(mktemp -d)" /usr/bin/thomas-style autotest
test "$(ls /usr/share/thomas-os/styles/*.conf | wc -l)" -ge 12
# Identité : fond d'écran présent, et le style par défaut utilise bien les jetons de design (une seule source)
test -s /usr/share/wallpapers/ThomasOS/contents/images/2560x1440.png
python3 - <<'EOF'
import configparser, json
j = json.load(open("/usr/share/thomas-os/identite/tokens.json", encoding="utf-8"))
c = configparser.ConfigParser(interpolation=None)
c.read("/usr/share/thomas-os/styles/thomas.conf", encoding="utf-8")
attendu = {("couleurs", "principale"): j["couleurs"]["rouge"], ("couleurs", "bordure"): j["couleurs"]["rouge"],
           ("couleurs", "barre"): j["couleurs"]["noir"], ("couleurs", "fenetres"): j["couleurs"]["anthracite"],
           ("couleurs", "texte"): j["couleurs"]["blanc"], ("effets", "coins"): str(j["rayons"]["barre"]),
           ("effets", "coins_menus"): str(j["rayons"]["menus"]), ("fenetres", "coins"): str(j["rayons"]["fenetres"]),
           ("effets", "opacite"): str(j["opacites"]["barre"]), ("effets", "opacite_menus"): str(j["opacites"]["menus"]),
           ("barre", "epaisseur"): str(j["barre"]["epaisseur"])}
ecarts = [f"{s}.{k} = {c.get(s, k)} (jeton : {v})" for (s, k), v in attendu.items() if c.get(s, k).lower() != v.lower()]
if ecarts:
    raise SystemExit("ERREUR : thomas.conf ne suit pas identite/tokens.json : " + " ; ".join(ecarts))
print("OK      style par défaut = jetons de design")
EOF
# Studio : tout ce qu'il propose (widgets, menus, icônes, curseurs, applis) doit exister dans l'image
/usr/bin/thomas-style verifier-systeme
[[ "$(fc-list : family)" == *Manrope* ]] || { echo "ERREUR : police Manrope absente"; exit 1; }
test -f /usr/share/plasma/plasmoids/org.thomasos.horloge/contents/ui/main.qml
# Thomas Core (service D-Bus lancé à la demande) et Thomas Control (appli compilée)
test -f /usr/share/dbus-1/services/org.thomasos.Core.service
HOME="$(mktemp -d)" /usr/libexec/thomas-core --test
command -v thomas-control >/dev/null || { echo "ERREUR : Thomas Control absent"; exit 1; }
test -f /usr/share/applications/org.thomasos.control.desktop
command -v thomas-studio >/dev/null || { echo "ERREUR : Thomas Studio absent"; exit 1; }
test -f /usr/share/applications/org.thomasos.studio.desktop
test -f /etc/xdg/autostart/thomas-style.desktop
case "${GPU_VARIANT}" in
    amd-intel) ;;
    nvidia | nvidia-legacy)
        # Les variantes NVIDIA doivent contenir le module noyau du pilote NVIDIA
        find /usr/lib/modules -name 'nvidia.ko*' -print -quit | grep -q . || {
            echo "ERREUR : pilote NVIDIA absent de l'image ${IMAGE_NAME}"
            exit 1
        }
        ;;
    *)
        echo "ERREUR : GPU_VARIANT inconnu : ${GPU_VARIANT}"
        exit 1
        ;;
esac

echo "Thomas OS (${IMAGE_NAME}, variante ${GPU_VARIANT}) : construction OK"
