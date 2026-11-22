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
    git

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
{
    echo "# Généré depuis ${FLATPAK_LIST} au build de Thomas OS : ne pas modifier ici"
    grep -Ev '^[[:space:]]*(#|$)' "${FLATPAK_LIST}" | while IFS=/ read -r kind app_id arch branch; do
        [[ "${kind}" == "app" || "${kind}" == "runtime" ]] || { echo "ERREUR ligne invalide : ${kind}/${app_id}" >&2; exit 1; }
        [[ -n "${app_id}" && "${arch}" == "x86_64" && -n "${branch}" ]] || { echo "ERREUR ligne invalide : ${kind}/${app_id}/${arch}/${branch}" >&2; exit 1; }
        echo ""
        echo "[Flatpak Preinstall ${app_id}]"
        echo "Branch=${branch}"
        if [[ "${kind}" == "runtime" ]]; then echo "IsRuntime=true"; else echo "IsRuntime=false"; fi
    done
} >"${PREINSTALL}"
chmod 0644 "${PREINSTALL}"
systemctl enable thomas-flatpak-preinstall.timer

# 1d. Zéro télémétrie : on coupe le compteur anonyme de Fedora (rpm-ostree countme).
#     KDE n'envoie rien par défaut ; on le fixe quand même (/etc/xdg/PlasmaUserFeedback).
systemctl mask rpm-ostree-countme.timer rpm-ostree-countme.service

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
for pkg in code claude-code nodejs nodejs-npm python3 python3-pip git; do
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
test "$(grep -c '^\[Flatpak Preinstall ' "${PREINSTALL}")" -eq "$(grep -Evc '^[[:space:]]*(#|$)' "${FLATPAK_LIST}")"
flatpak preinstall --help >/dev/null
test -L /etc/systemd/system/timers.target.wants/thomas-flatpak-preinstall.timer
test "$(readlink /etc/systemd/system/rpm-ostree-countme.timer)" = "/dev/null"
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
