# Thomas OS

Un Linux perso, basé sur [Bazzite](https://bazzite.gg) (Fedora Atomic + KDE Plasma), pensé pour remplacer Windows au quotidien :
look façon Windows 11, zéro pub, zéro télémétrie, jeux prêts à l'emploi, et des mises à jour « incassables » (retour en arrière possible).

Il s'installe sur **n'importe quel PC** (x86 64 bits, Intel ou AMD) depuis une **clé USB live** : on teste sans rien installer, puis on installe quand on veut.

> 🚧 **En construction.** Les images système se construisent déjà toutes seules sur GitHub. La clé USB (ISO) arrive à une étape suivante.

## Quelle version pour quelle carte graphique ?

| Ta carte graphique | Version à prendre | Image système |
|---|---|---|
| **AMD Radeon** (RX 400/500, RX 5000, 6000, 7000, 9000…) | `thomas-os` | `ghcr.io/mailprofessionnelthomas-dotcom/thomas-os:stable` |
| **Intel** (graphique intégré, Intel Arc) | `thomas-os` | `ghcr.io/mailprofessionnelthomas-dotcom/thomas-os:stable` |
| **NVIDIA récente** : GTX 1650/1660, RTX 2000, 3000, 4000, 5000 | `thomas-os-nvidia` | `ghcr.io/mailprofessionnelthomas-dotcom/thomas-os-nvidia:stable` |
| **NVIDIA ancienne** : GTX 750 Ti, GTX 900, GTX 1000 (1050, 1060, 1070, 1080), Titan V | `thomas-os-nvidia-legacy` | `ghcr.io/mailprofessionnelthomas-dotcom/thomas-os-nvidia-legacy:stable` |
| **NVIDIA très ancienne** : GTX 700 (sauf 750) et avant | `thomas-os` | pilote libre « nouveau » : le bureau marche, mais pas fait pour jouer |
| **PC portable Intel/AMD + NVIDIA** | la version **NVIDIA** qui correspond à la carte NVIDIA | |

Comment connaître ta carte sous Windows : `Ctrl + Maj + Échap` → onglet **Performances** → **GPU**.

**Pas compatible :** Mac Apple Silicon (M1, M2…), PC à processeur ARM (Snapdragon), PC 32 bits.

## Comment c'est fabriqué

- Tout est construit sur les serveurs GitHub (GitHub Actions), jamais sur un PC.
- Une seule recette (`Containerfile` + `build_files/build.sh`) donne les 3 versions : seule l'image Bazzite de départ change.
- Construction automatique **tous les jours** (pour récupérer les mises à jour de Bazzite) et à chaque modification du repo.
- Les images sont **signées** (Sigstore, sans clé secrète) : on peut prouver qu'elles viennent bien de ce repo.

| Fichier | À quoi il sert |
|---|---|
| `Containerfile` | La recette : « pars de Bazzite et applique `build.sh` » |
| `build_files/build.sh` | Ce qu'on change dans Bazzite pour en faire Thomas OS |
| `system_files/` | Fichiers copiés tels quels dans le système |
| `.github/workflows/build.yml` | Le robot GitHub qui construit et publie les 3 versions |
| `image-template.env` | Réglages (nom, compte GitHub, version de départ) |

## Basé sur

- [ublue-os/image-template](https://github.com/ublue-os/image-template) (licence Apache-2.0)
- [Bazzite](https://github.com/ublue-os/bazzite) / [Universal Blue](https://universal-blue.org)
