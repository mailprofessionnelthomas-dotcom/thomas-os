# Thomas OS — Architecture (Phase 2)

> Version 1 du 23/11/2026. Ce document fixe **comment** Thomas OS est découpé, ce que chaque module fait, comment les modules se parlent, où vit la configuration et comment on vérifie que c'est fini.
> Il part de l'existant (`AUDIT_COMPLET.md`) et de la vision (« master prompt » du 23/11/2026).
> Il ne décrit que ce qui est **décidé**. Les points à valider sur le banc ou en VM sont marqués « à vérifier ».

## 1. Principes

1. **Bazzite et KDE Plasma 6 restent le socle.** On personnalise par :
   - des thèmes ;
   - des réglages (fichiers de config, D-Bus) ;
   - des widgets Plasma ;
   - des applis Thomas OS.

   On ne réécrit ni KWin, ni Plasma, ni l'installateur, ni le système de mises à jour.
2. **Ne pas dupliquer KDE.**
   - Un réglage que KDE sait faire est **appelé**, pas recodé : page de réglages KDE ouverte depuis Thomas Control, réglage écrit par le Core.
   - Une appli KDE qui fait le travail est **thémée**, pas refaite (exemple : Plasma System Monitor sert de gestionnaire de tâches).
3. **Système immuable.**
   - Tout ce qui est « système » est dans l'image (`/usr`, construit sur GitHub).
   - L'utilisateur n'écrit que dans `/etc`, `/var` et son dossier perso.
   - Retour arrière : `bootc rollback`.
4. **Rien n'est fini sans test.**
   - Chaque module a des critères d'acceptation (§8).
   - Ces critères sont vérifiés automatiquement par l'autotest, le banc (`captures.yml`) ou le test VM (`vm-test.yml`, qui bloque `testing`).
5. **Réversible.** Tout changement de réglage fait par Thomas OS peut être annulé : sauvegarde avant d'appliquer, version précédente de l'image, style de secours.
6. **Léger.**
   - Aucun service Thomas OS ne tourne en permanence sans raison. Les services démarrent à la demande (activation D-Bus) et s'arrêtent seuls.
   - On mesure avant et après chaque optimisation.

## 2. Les 5 modules

```
                ┌──────────────── identité (tokens, logo, fonds) ────────────────┐
                │                                                                 │
 Thomas Welcome ─┐                                                                │
 Thomas Control ─┼──► D-Bus org.thomasos.Core (session) ──► KDE (kwriteconfig, plasma, KWin)
 Thomas Studio  ─┘          │                                   Flatpak, NetworkManager…
 Thomas Desktop ◄───────────┘ (applique thèmes + mise en page)
                            └──► org.thomasos.Systeme (bus système, polkit) ──► bootc, systemd
```

| Module | Rôle | Ce qui existe déjà | Technologie |
|---|---|---|---|
| **Thomas Core** | Services communs : styles et thèmes, configuration, profils, diagnostics, canal de mises à jour, sauvegarde des réglages | `thomas-style` (moteur Python), `info.env`, canaux `testing`/`stable`, service Flatpak | Python 3 + PyGObject (Gio D-Bus, déjà dans l'image) |
| **Thomas Desktop** | Ce qu'on voit : barre capsule, menu, fenêtres, notifications, panneau rapide, bureaux virtuels, widgets, raccourcis | Thème Plasma généré, barre par script, horloge QML | Thème Plasma + widgets QML (Plasma 6) + réglages KWin |
| **Thomas Control** | Centre de contrôle : tableau de bord (CPU, GPU, RAM, disques), réglages groupés par catégories | — | Appli Qt 6 / QML / Kirigami, petit `main` en C++ |
| **Thomas Studio** | Personnalisation avancée : thèmes, palettes, icônes, fonds, aperçu, sauvegarde et restauration | Appli native `apps/thomas-studio` (phase 6) + prototype web `studio/index.html` (placement des widgets) | Même pile que Control ; le prototype web reste l'outil de maquette pour les widgets |
| **Thomas Welcome** | 1er démarrage : présentation, réseau, matériel (variante GPU), confidentialité, style, préférences | Appli `apps/thomas-welcome` (phase 7) : 7 étapes, aperçus des styles dessinés au build (`/usr/share/thomas-os/apercus`), remplace Bazzite Portal et les annonces de Bazzite | Même pile que Control |

**Frontière Control / Studio :**
- **Control** règle **le système et le quotidien** : réseau, matériel, mises à jour, énergie, et les choix d'apparence simples (style, fond, accent).
- **Studio** **crée et modifie** des styles complets : palette, composants, aperçu, export et import.
- Un réglage n'existe qu'à un seul endroit. Control ouvre Studio pour aller plus loin.

**Compte local :** il est créé par l'installateur (Anaconda), comme sur Bazzite. Welcome ne recrée pas de compte, pour ne pas doubler l'installateur. Il complète le reste.

## 3. Thomas Core

### 3.1 Bibliothèque et ligne de commande

- **Le moteur actuel devient une bibliothèque.** `thomas-style` (`system_files/usr/bin/thomas-style`) migre vers un paquet Python `thomas_os` installé dans `/usr/lib/thomas-os/python/` (module `styles`, `config`, `systeme`, `diagnostic`).
- **La commande reste compatible.** `thomas-style` garde ses commandes actuelles (`appliquer`, `importer`, `secours`…). Une commande générale `thomas` regroupe le reste.
- **Migration sans casse :** d'abord on déplace le code, puis la commande `thomas-style` appelle la bibliothèque. L'autotest garde les mêmes résultats.

### 3.2 Service de session D-Bus `org.thomasos.Core`

- **Démarrage :** à la demande, via un fichier `.service` D-Bus dans `/usr/share/dbus-1/services/`. Le service s'arrête après 60 s sans appel.
- **Objet :** `/org/thomasos/Core`.

| Interface | Méthodes (v1) | Signaux |
|---|---|---|
| `org.thomasos.Style1` | `Liste() → a(ss)`, `Actuel() → s`, `Appliquer(s id, s disposition)`, `Secours()`, `Annuler()`, `PeutAnnuler() → b` ; pour le Studio : `Catalogue() → s` (JSON), `Lire(s id) → s` (JSON), `Enregistrer(s id, s reglagesJson) → (s id, as corrections)`, `Importer(s chemin .conf/.json) → (s id, as corrections)`, `Exporter(s id, s chemin)`, `Supprimer(s id)` | `StyleChange(s id)`, `ListeChange()` |
| `org.thomasos.Config1` | `Lire(s section, s cle) → s`, `Ecrire(s section, s cle, s valeur)` (faits, phase 7, dans `~/.config/thomas-os/thomas.conf`) ; `Sauvegarder() → s fichier`, `Restaurer(s fichier)` (à faire) | `ConfigChange(s section, s cle)` |
| `org.thomasos.Systeme1` (lecture seule) | `Infos() → a{ss}` (version, variante, canal, base), `CarteGraphique() → a{ss}` (détectée / attendue), `Reseau() → a{ss}` (etat, type, nom), `Energie() → a{ss}` (profil, profils, jeu), `ChoisirEnergie(s profil)`, `WindowsPresent() → b` (à faire) | — |
| `org.thomasos.Diagnostic1` | `Rapport() → s` (texte : services en échec, espace disque, températures), `Temperatures() → a(sdd)` (nom, °C, limite), `TestReseau() → a{ss}` (latence, stabilité, DNS, signal Wi-Fi), `TestDebit() → a{ss}`, `Nettoyage() → a{ss}` (dernier nettoyage) | `Alerte(s type, s message)` (à faire : les alertes passent aujourd'hui par `thomas-surveillance`) |

**Règles :**
- Les interfaces sont **versionnées** (`…1`, `…2`). On n'enlève jamais une méthode : on crée la version suivante.
- Les applis (Control, Welcome, Studio) n'écrivent **jamais** directement dans les fichiers de KDE. Elles passent par le Core, pour qu'il n'y ait qu'un seul endroit qui sache le faire et qui sache annuler.

### 3.3 Aide système `org.thomasos.Systeme` (bus système)

- **Rôle :** pour les rares actions qui exigent root :
  - changer de canal (`bootc switch …:testing/stable`) ;
  - changer de variante GPU ;
  - « redémarrer sur Windows » (`systemctl reboot --boot-loader-entry=…`, à vérifier sur le matériel) ;
  - nettoyage système (`flatpak uninstall --unused`, `rpm-ostree cleanup`).
- **Autorisation :** chaque action est une action **polkit** (`org.thomasos.systeme.*`), avec mot de passe administrateur. Pas de sudo caché.
- **Démarrage :** à la demande (activation D-Bus système). Le service sort quand l'action est finie.

### 3.4 Mises à jour

On garde **uniquement le mécanisme de Bazzite** : `uupd` + bootc (téléchargement en fond, application au redémarrage, version précédente gardée). Pas de gestionnaire parallèle.

Le Core ne fait que :
- afficher l'état (`bootc status`) ;
- changer de canal (via l'aide système) ;
- proposer le retour arrière.

Le canal par défaut d'un PC installé est `stable`. Le PC du propriétaire passe sur `testing`.

## 4. Configuration

### 4.1 Couches (la dernière gagne)

| Couche | Emplacement | Qui écrit |
|---|---|---|
| Défauts Thomas OS | `/usr/share/thomas-os/` (dans l'image) | le build |
| Réglages de l'administrateur de la machine | `/etc/thomas-os/` | l'aide système |
| Réglages de l'utilisateur | `~/.config/thomas-os/` | le Core (au nom des applis) |

C'est le principe déjà utilisé par les styles (`SYS_DIR` puis `USER_DIR`), étendu à tout.

### 4.2 Formats

- **Styles :** fichiers INI `.conf` (format actuel, sections `style`, `couleurs`, `effets`, `barre`, `menu`, `texte`, `bureau`, `fenetres`, `systeme`). On **étend** ce format, on ne le remplace pas.
- **Chaque fichier porte un numéro de format** (`[style] format = 1`). Le Core sait migrer un ancien format vers le nouveau, et garde l'original en `.bak`.
- **Designs du Studio :** JSON (`format: thomas-os-studio`, `version`). C'est le format d'échange ; le Core le convertit en `.conf` (`importer`).
- **Préférences générales :** `~/.config/thomas-os/thomas.conf` (INI) : canal souhaité, confidentialité, choix de Welcome, profils.
- **Style appliqué :** `~/.config/thomas-os/actuel.conf` (existe déjà). Copie complète, jamais touchée par une mise à jour.

### 4.3 Source unique des catalogues

- **Le fichier :** `/usr/share/thomas-os/catalogue.json`, qui liste les applis, widgets, packs d'icônes, curseurs, polices et boutons de fenêtre.
- **Qui le lit :** le Core, le Studio (copié dans la page au moment de l'export), Control et Welcome.
- **Contrôle au build :** `verifier-systeme` vérifie que tout ce qu'il contient existe vraiment dans l'image.
- **Ce que ça règle :** aujourd'hui, les listes sont recopiées dans `thomas-style` et dans `studio/index.html`.

### 4.4 Sauvegarde des réglages

`Config1.Sauvegarder` produit une archive `~/thomas-os-reglages-AAAAMMJJ.tar.zst` qui contient :
- `~/.config/thomas-os/` ;
- la mise en page Plasma (`plasma-org.kde.plasma.desktop-appletsrc`, `plasmashellrc`) ;
- `kdeglobals`, `kwinrc`, `breezerc`, `kcminputrc` ;
- la liste des Flatpaks installés.

**Règles :**
- **Avant chaque `Appliquer`,** le Core garde automatiquement la mise en page Plasma précédente (5 dernières) : on peut annuler un changement de style, même s'il a reconstruit les barres.
- **Le système complet,** lui, est déjà « sauvegardé » par nature (image + version précédente).
- **Les fichiers personnels :** Pika Backup (Flatpak, Borg) est recommandé dans Control. On n'écrit pas notre propre outil de sauvegarde de fichiers.

## 5. Identité visuelle partagée

Une seule source pour les couleurs, utilisée partout : thème Plasma, applis, écran de connexion, démarrage.

| Élément | Emplacement prévu |
|---|---|
| Jetons de design : couleurs (noir profond, anthracite, rouge, blanc, gris), rayons, espacements, durées d'animation, opacités | `system_files/usr/share/thomas-os/identite/tokens.json` |
| Logo T (SVG, plusieurs tailles, version monochrome) | `…/identite/logo/` + `/usr/share/icons/hicolor/*/apps/thomas-os.*` |
| Fonds d'écran (noir et rouge abstrait + T) | `/usr/share/wallpapers/ThomasOS/` (format paquet de fond KDE) |
| Composants QML partagés (Carte, Interrupteur, Bouton, Barre latérale, Jauge) | module QML `org.thomasos.ui`, installé dans `/usr/lib64/qt6/qml/org/thomasos/ui/` |
| Démarrage (logo T animé) | thème Plymouth `thomas-os` |
| Écran de connexion | thème pour **Plasma Login Manager** (constaté : c'est le gestionnaire de connexion de Bazzite, pas SDDM) |

**Règle :**
- Le style « Thomas OS » par défaut, le thème Plasma, le module `org.thomasos.ui`, Plymouth et l'écran de connexion lisent les **mêmes jetons**. Changer le rouge à un endroit le change partout au build suivant.
- Les styles du Studio peuvent surcharger les jetons, et seulement eux.

## 6. Thomas Desktop : ce qui est natif, ce qui est maison

| Élément de la vision | Réalisation | Natif / maison |
|---|---|---|
| Barre en capsule, noire, bordure rouge fine, halo et trait rouge | Thème Plasma généré par le Core (SVG `panel-background`, `tasks`) | Natif (thème) |
| Logo T au centre, applis autour, agrandissement au survol | Widget **`org.thomasos.barre`** : liste des tâches maison en QML, qui s'appuie sur la bibliothèque officielle `org.kde.taskmanager` (pas de bidouille). Repli automatique sur la liste des tâches de KDE si le widget ne se charge pas | **Maison** |
| Menu démarrer, glissement depuis le bas, Alt+Espace | Kickoff + thème + effet KWin de glissement. Raccourci : Alt+Espace ouvre le menu, la recherche KRunner passe sur Alt+F2 | Natif |
| Fenêtres : noir translucide sans flou, sans bordure, coins arrondis, 100 à 150 ms, réduction vers l'icône | Breeze (sans bordure), vitesse des animations, effet « réduction ». Transparence du **fond** des applis Qt/KDE via Kvantum (Opera GX et Firefox restent opaques) | Natif + Kvantum |
| Notifications : cartes, bas à droite, 5 s, historique, clic qui ouvre l'appli | Notifications Plasma + thème + réglages | Natif |
| Panneau rapide (Wi-Fi, Bluetooth, volume, luminosité) | Widget **`org.thomasos.panneau`** qui réutilise les modules officiels de Plasma (réseau, Bluetooth, son, luminosité). Les modules exacts sont à vérifier sur le banc | **Maison** |
| Bureaux virtuels (bandeau de miniatures, ajout/suppression, visibilité par appli) | Vue d'ensemble de KWin + menu de fenêtre. Limite KWin : 20 bureaux | Natif |
| Widgets du bureau (horloge, date, calendrier) | `org.thomasos.horloge` (existe) + calendrier Plasma | Existant + natif |
| Menu clic droit, ancrage, aperçus, multi-écrans, raccourcis | Natifs KDE + thème | Natif |

## 7. Applis système et outils

| Besoin | Choix | Pourquoi |
|---|---|---|
| Gestionnaire de tâches avancé | **Plasma System Monitor** (natif), thémé + page d'accueil Thomas OS | Il a déjà processus, CPU, RAM, GPU, réseau, disques et graphiques |
| Applis au démarrage | Réglage KDE « Démarrage automatique », ouvert depuis Control | Natif |
| Périphériques | Vue simple dans Control (capteurs et périphériques via KDE) ; vue avancée = **KInfoCenter** | Natif |
| Nettoyage | Timer Thomas OS : caches utilisateur anciens, Flatpaks inutilisés, anciennes versions du système. **Jamais** les documents | Sûr et réversible |
| Mode gaming | Petit service à la demande : profil d'énergie « performance » (power-profiles-daemon) quand un jeu tourne, retour à la normale à la fin. Bazzite retire `gamemode` exprès : on ne le remet pas. **Mesures avant/après obligatoires** | Natif + léger |
| Températures | Lecture des capteurs (hwmon) par le Core, alerte par notification | Léger |
| Réseau | Diagnostic seulement (débit, ping, stabilité). Aucun réglage réseau « universel » | Règle de la vision |
| Accueil Bazzite | « Bazzite Portal » et ses annonces au 1er login (constatés en VM) sont **masqués** et remplacés par Thomas Welcome | Une seule expérience |

## 8. Critères d'acceptation (vérifiés automatiquement)

| Module | Critère | Vérifié par |
|---|---|---|
| Core | `thomas-style autotest` OK ; `org.thomasos.Core` répond à `Infos()` ; `Appliquer` puis annuler rend la mise en page d'avant | autotest (build) + test VM |
| Core | Le service s'arrête seul après 60 s sans appel | test VM |
| Desktop | Photo du vrai bureau conforme pour chaque style (barre, menu ouvert, une fenêtre, une notification) ; écart à la maquette sous un seuil | banc (`captures.yml`) |
| Desktop | Le widget `org.thomasos.barre` se charge ; repli sur la liste des tâches KDE sinon | banc + test VM |
| Control | S'ouvre en moins d'1 s (mesuré en VM) ; chaque page s'ouvre sans erreur QML ; le tableau de bord affiche des valeurs non nulles | test VM |
| Welcome | Se lance au 1er login (et seulement au 1er) ; Bazzite Portal ne s'ouvre plus ; à la fin, on arrive sur le bureau avec le style choisi | test VM (1re session) |
| Studio | Un design importé devient un style appliqué identique (comparaison maquette/vrai) | banc |
| Image | Démarre en VM, version et canal corrects, 1re session OK, Flatpaks installés | test VM (bloque `testing`) |
| Installation | ISO live qui démarre en VM **avec Secure Boot activé** (enrôlement MOK) | test VM Secure Boot (phase 9) |

Chaque module livre aussi :
- son interface (§3) ;
- la liste de ses dépendances, dans son `README.md` ;
- une procédure de retour arrière.

## 9. Construction

### 9.1 Compiler les applis sans rien installer sur le PC

- **Une étape de compilation dans le `Containerfile`,** qui part **de la même image Bazzite** : `FROM ${BASE_IMAGE} AS compilation`, `dnf install` des paquets de développement (Qt 6, KF6, Kirigami, extra-cmake-modules), puis `cmake`.
- **On ne copie que le résultat** dans l'image finale : les outils de développement ne sont jamais dans Thomas OS. Mêmes versions de Qt et KDE que le système, donc pas d'incompatibilité.
- **Une CI rapide `compile.yml`** (sans construire toute l'image) compile les applis et lance leurs tests à chaque modification de `apps/` ou `qml/`.

### 9.2 Arborescence cible

La migration se fait petit à petit, **rien n'est supprimé d'un coup**.

```
apps/
  thomas-control/      CMakeLists.txt, src/main.cpp, qml/, README.md
  thomas-welcome/
  thomas-studio/       (version native, plus tard)
qml/org.thomasos.ui/   composants partagés (QML)
plasmoids/
  org.thomasos.barre/
  org.thomasos.panneau/
  org.thomasos.horloge/   (déplacé depuis system_files au moment de la phase 4)
core/
  thomas_os/           paquet Python (styles, config, systeme, diagnostic)
  bin/                 thomas, thomas-style, thomas-core (service D-Bus)
  dbus/ polkit/        fichiers .service, .conf, .policy
identite/              tokens.json, logo/, fonds/, plymouth/, connexion/
system_files/          fichiers copiés tels quels (comme aujourd'hui)
build_files/           build.sh (+ installation des composants ci-dessus)
studio/                prototype web (outil de maquette)
ci/ banc/ vm/          banc d'essai et test VM
docs/                  ARCHITECTURE.md, guides
```

## 10. Conventions

- **Noms :**
  - préfixe `org.thomasos.` pour D-Bus, polkit, widgets, modules QML et `.desktop` des applis Thomas OS ;
  - commandes `thomas-*` ;
  - noms visibles « Thomas Control », etc.
- **Langue :** interface en **français** d'abord, mais chaque texte passe par la fonction de traduction (`i18n()` en QML/C++, `_()` en Python). Le code et les commentaires restent en français, comme aujourd'hui.
- **Langages :**
  - Python 3 (bibliothèque standard + PyGObject) pour le Core ;
  - QML pour toute interface ;
  - C++ seulement là où QML ne suffit pas (`main`, modèles lourds) ;
  - Bash pour le build et la CI.
- **Pas de dépendance nouvelle** sans ligne dans le `README.md` du module : quoi, pourquoi, d'où, licence.
- **Fichiers texte :** fins de ligne LF (`.gitattributes`). Scripts exécutables marqués dans Git (`git update-index --chmod=+x`).
- **Git :** une modification = un commit qui explique pourquoi. Le dépôt GitHub est la sauvegarde ; une étape importante démarre sur un état vert.
- **Versions :** image = `AAAAMMJJ.N` (numéro de build) ; interfaces D-Bus suffixées `1`, `2`… ; formats de fichiers avec `format = N`.
- **Performances :**
  - pas de minuterie plus rapide qu'1 s dans un widget (sauf animation) ;
  - les services démarrent à la demande ;
  - toute optimisation est mesurée en VM avant et après (`systemd-analyze`, mémoire au repos).

## 11. Retour arrière

| Niveau | Comment |
|---|---|
| Une version de Thomas OS | `bootc rollback`, ou choisir l'entrée précédente au démarrage ; pour tous les PC : « Passer en stable » avec `stable-precedent` |
| Un style | « Revenir au style de base » (secours) ; ou annuler le dernier `Appliquer` (mise en page gardée, §4.4) |
| Les réglages | `Config1.Restaurer(archive)` |
| Un module maison qui casse | Désactivable seul : la barre revient sur la liste des tâches KDE, Welcome se saute, Control n'est qu'une appli |

## 12. Ordre de réalisation

| Phase | Contenu | Première vérification |
|---|---|---|
| 0 ✅ | Test de démarrage VM bloquant, `stable` à jour, restes du modèle retirés | fait le 23/11/2026 |
| 2 ✅ | Ce document | — |
| 3 | Identité : jetons, logo T, fond, module `org.thomasos.ui`, style par défaut refait | banc : photo du nouveau style |
| 4 | Desktop : thème capsule, `org.thomasos.barre`, menu Alt+Espace, fenêtres, notifications, `org.thomasos.panneau` | banc + VM |
| 5 | Core D-Bus + Thomas Control | VM : temps d'ouverture, pages |
| 6 | Thomas Studio natif | VM : style modifié → enregistré → maquette ; appliqué → photo comparée ; annulé → style d'avant |
| 7 | Thomas Welcome (+ masquer Bazzite Portal) | VM : 1re session (Welcome ouvert, Portal absent, 7 étapes, fermé = ne revient plus) |
| 8 | Intégration : nettoyage, gaming, températures, diagnostic réseau | VM (faux jeu Steam, faux capteur à 99 °C, coût mesuré de chaque vérification) ; gain en jeu à mesurer sur le PC réel |
| 9 | ISO live, installation, dual boot, Secure Boot (MOK), logo animé au démarrage | VM avec Secure Boot |
| 10 | Validation sur matériel réel, guides | PC réel (par le propriétaire) |
