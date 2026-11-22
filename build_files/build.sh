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
