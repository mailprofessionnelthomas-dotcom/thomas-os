# Thomas OS : image perso basée sur Bazzite (Fedora Atomic + KDE Plasma)
#
# La MÊME recette fabrique les 3 variantes. Seule l'image de départ change
# (choisie par .github/workflows/build.yml) :
#   thomas-os               <- ghcr.io/ublue-os/bazzite:stable              (AMD, Intel, vieilles NVIDIA)
#   thomas-os-nvidia        <- ghcr.io/ublue-os/bazzite-nvidia-open:stable  (NVIDIA GTX 16xx, RTX 20 à 50)
#   thomas-os-nvidia-legacy <- ghcr.io/ublue-os/bazzite-nvidia:stable       (NVIDIA GTX 900, GTX 1000)

ARG BASE_IMAGE="ghcr.io/ublue-os/bazzite:stable"

# Applis Thomas OS (apps/) compilées à part, à partir de la MÊME image : mêmes versions de Qt et de KDE.
# Seuls les programmes compilés passent dans l'image finale, jamais les outils de développement.
FROM ${BASE_IMAGE} AS compilation
COPY apps /apps
RUN dnf5 install -y --setopt=install_weak_deps=False cmake gcc-c++ qt6-qtbase-devel qt6-qtdeclarative-devel && \
    for app in /apps/*/; do \
        nom="$(basename "${app}")" && \
        cmake -S "${app}" -B "/tmp/build/${nom}" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release && \
        cmake --build "/tmp/build/${nom}" -j"$(nproc)" && \
        DESTDIR=/sortie cmake --install "/tmp/build/${nom}" || exit 1; \
    done

# Les scripts de construction sont montés pendant le build, sans être copiés dans l'image finale
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files
COPY identite /identite

FROM ${BASE_IMAGE}

ARG BASE_IMAGE="ghcr.io/ublue-os/bazzite:stable"
ARG IMAGE_NAME="thomas-os"
ARG IMAGE_VENDOR="mailprofessionnelthomas-dotcom"
ARG IMAGE_VERSION="dev"
ARG GPU_VARIANT="amd-intel"

COPY --from=compilation /sortie/usr /usr

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
