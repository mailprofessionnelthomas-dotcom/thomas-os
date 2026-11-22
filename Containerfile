# Thomas OS : image perso basée sur Bazzite (Fedora Atomic + KDE Plasma)
#
# La MÊME recette fabrique les 3 variantes. Seule l'image de départ change
# (choisie par .github/workflows/build.yml) :
#   thomas-os               <- ghcr.io/ublue-os/bazzite:stable              (AMD, Intel, vieilles NVIDIA)
#   thomas-os-nvidia        <- ghcr.io/ublue-os/bazzite-nvidia-open:stable  (NVIDIA GTX 16xx, RTX 20 à 50)
#   thomas-os-nvidia-legacy <- ghcr.io/ublue-os/bazzite-nvidia:stable       (NVIDIA GTX 900, GTX 1000)

ARG BASE_IMAGE="ghcr.io/ublue-os/bazzite:stable"

# Les scripts de construction sont montés pendant le build, sans être copiés dans l'image finale
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

FROM ${BASE_IMAGE}

ARG BASE_IMAGE="ghcr.io/ublue-os/bazzite:stable"
ARG IMAGE_NAME="thomas-os"
ARG IMAGE_VENDOR="mailprofessionnelthomas-dotcom"
ARG IMAGE_VERSION="dev"
ARG GPU_VARIANT="amd-intel"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    BASE_IMAGE="${BASE_IMAGE}" \
    IMAGE_NAME="${IMAGE_NAME}" \
    IMAGE_VENDOR="${IMAGE_VENDOR}" \
    IMAGE_VERSION="${IMAGE_VERSION}" \
    GPU_VARIANT="${GPU_VARIANT}" \
    /ctx/build.sh

# Vérifie que l'image finale est bien démarrable (bootc)
RUN bootc container lint
