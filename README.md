# Thomas OS

Un Linux perso, basé sur [Bazzite](https://bazzite.gg) (Fedora Atomic + KDE Plasma), pensé pour remplacer Windows au quotidien :
look façon Windows 11, zéro pub, zéro télémétrie, jeux prêts à l'emploi, et des mises à jour « incassables » (retour en arrière possible).

**L'idée : optimisé, compact, fluide, épuré.** Chaque choix (applis, styles, notifications, effets) passe par ce filtre.

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

## Ce qui est installé

Thomas OS installe le strict utile : chacun ajoute ses jeux et ses applis depuis la boutique d'applis (Bazaar). Steam, Lutris et l'ancien thème Oxygen de Bazzite sont retirés ; les outils de jeu invisibles (Gamescope, MangoHud…) restent, pour qu'un jeu installé plus tard tourne directement.

| Pour quoi | Applis |
|---|---|
| Internet | Opera GX (par défaut), Firefox (secours) |
| Musique | Spotify |
| Coder | VS Code, Git, Python + pip, Node.js + npm, Claude Code |
| Bureau | LibreOffice, VLC, Gwenview (images), Okular (PDF), KCalc |
| Gérer ses applis | Flatseal, Warehouse, Kontainer |

- Les applis viennent de **Flathub** (Flatpak) : la liste est dans [`system_files/usr/share/thomas-os/flatpaks.list`](system_files/usr/share/thomas-os/flatpaks.list). Une appli ajoutée à la liste s'installe aussi sur les PC déjà installés ; une appli désinstallée volontairement n'est jamais réinstallée.
- En paquets système (car elles marchent mal en Flatpak) : VS Code, Claude Code (dépôt officiel, canal stable), Node.js, Python, Git. Elles se mettent à jour avec Thomas OS.
- **Zéro télémétrie côté système** : le compteur anonyme de Fedora est coupé, KDE n'envoie rien, VS Code a la télémétrie coupée par défaut. ⚠️ Spotify et Opera GX ont leurs propres statistiques, que le système ne peut pas couper (réglages dans chaque appli).

**Ce qui ne marchera pas sous Linux :** FACEIT et les jeux à anti-cheat noyau (Valorant…). Sober (Roblox) n'est pas officiel : Roblox peut le bloquer. Roblox Studio via Vinegar est instable : garde Windows pour ça.

## Mises à jour : 2 canaux

| Canal | Qui | Ce qu'il reçoit |
|---|---|---|
| `testing` | le PC de Thomas | chaque nouvelle version qui a passé les vérifications (et les simulations en VM, bientôt) |
| `stable` | tous les autres PC (c'est le canal installé par la clé USB) | seulement les versions que Thomas a validées |

1. **Une nouvelle version** arrive toute seule (mise à jour de Bazzite, tous les jours) ou après une modification du repo : GitHub la construit, la vérifie, puis la publie sur `testing`. Le PC de Thomas la télécharge en fond et l'applique au redémarrage suivant.
2. **Valider** : onglet **Actions** → **Passer en stable** → **Run workflow** (laisser `testing`). Tous les autres PC la reçoivent.
3. **Revenir en arrière** : sur un PC, choisir la version précédente au démarrage (ou `sudo bootc rollback`) ; pour tout le monde, relancer **Passer en stable** avec `stable-precedent` ou un numéro de version (ex. `20261122.5`).

Chaque version garde un numéro unique (date + numéro de build) : rien n'est reconstruit en changeant de canal, c'est exactement la même image qui a été testée.

## Comment c'est fabriqué

- Tout est construit sur les serveurs GitHub (GitHub Actions), jamais sur un PC.
- Une seule recette (`Containerfile` + `build_files/build.sh`) donne les 3 versions : seule l'image Bazzite de départ change.
- Construction automatique **tous les jours** (pour récupérer les mises à jour de Bazzite) et à chaque modification du repo. Le build ne touche jamais au canal `stable`.
- Les images sont **signées** (Sigstore, sans clé secrète) : on peut prouver qu'elles viennent bien de ce repo.

| Fichier | À quoi il sert |
|---|---|
| `Containerfile` | La recette : « pars de Bazzite et applique `build.sh` » |
| `build_files/build.sh` | Ce qu'on change dans Bazzite pour en faire Thomas OS |
| `system_files/` | Fichiers copiés tels quels dans le système |
| `.github/workflows/build.yml` | Le robot GitHub qui construit les 3 versions et les publie sur `testing` |
| `.github/workflows/promote-stable.yml` | Le bouton « Passer en stable » (valider ou revenir en arrière) |
| `image-template.env` | Réglages (nom, compte GitHub, version de départ) |

## Basé sur

- [ublue-os/image-template](https://github.com/ublue-os/image-template) (licence Apache-2.0)
- [Bazzite](https://github.com/ublue-os/bazzite) / [Universal Blue](https://universal-blue.org)
