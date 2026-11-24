# Thomas Studio

Crée et modifie les styles de Thomas OS. À gauche les réglages, à droite la maquette qui change tout de suite.

- **Onglets :** couleurs, formes, barre, menu, fenêtres, bureau, texte.
- **Actions :** enregistrer, appliquer pour de vrai, annuler le dernier changement, nouveau, importer, exporter (`.conf`), retirer.

## Ce qu'il propose, et pas plus

Le Studio ne propose que ce que Thomas OS sait vraiment appliquer. Les listes (dispositions, polices, icônes, curseurs, applis…) et les limites viennent de **Thomas Core** (`Style1.Catalogue`). Ce sont les mêmes listes que celles vérifiées au build (`thomas-style verifier-systeme`).

Une valeur impossible n'est pas refusée : elle est **corrigée**, et le bandeau dit ce qui a été corrigé.

## Comment il marche

- **Tout passe par Thomas Core**, D-Bus `org.thomasos.Core`, interface `Style1` : `Catalogue`, `Lire`, `Enregistrer`, `Importer`, `Exporter`, `Supprimer`, `Appliquer`, `Annuler`, `PeutAnnuler`. Le Studio n'écrit jamais lui-même dans les fichiers de KDE ou de styles.
- **Où vont tes styles :** `~/.config/thomas-os/styles/ID.conf`.
  - Pour un style du système, seules tes modifications y sont écrites : les mises à jour de l'original continuent d'arriver.
  - Un style remplacé ou retiré va dans `~/.config/thomas-os/corbeille/` (les 20 derniers). Rien n'est effacé.
- **Annuler :** les 5 derniers styles appliqués sont gardés dans `~/.config/thomas-os/historique/`.
- **Maquette :** `qml/Apercu.qml` suit les règles du moteur :
  - mêmes dispositions que le script Plasma de `thomas-style` ;
  - mêmes couleurs que le schéma KDE généré ;
  - taille de ton écran.

  Les applis réelles peuvent légèrement différer.
- **Pas encore dans le Studio natif :** placer les widgets du bureau. Ça se fait avec le Studio web (`studio/index.html`), dont les designs s'importent ici.

## Tests (sur GitHub, jamais sur le PC)

- **`compile.yml` :** compile l'appli, la lance sans écran avec un vrai Thomas Core, puis enregistre des maquettes et une photo de la fenêtre.
- **Test VM (`vm-test.yml`) :**
  1. lit un style par le Core, le modifie et l'enregistre (avec correction) ;
  2. ouvre le Studio ;
  3. dessine la maquette ;
  4. applique le style pour de vrai et prend une photo, comparée à la maquette ;
  5. annule et vérifie que le style d'avant est revenu.
- **Commandes de test :**
  - `thomas-studio --apercu FICHIER.png [--menu] [--ecran 1920x1080] STYLE` : enregistre la maquette ;
  - `thomas-studio --capture FICHIER.png STYLE` : prend une photo de la fenêtre.

## Dépendances

Toutes sont déjà dans Bazzite : rien n'est ajouté à l'image.

| Quoi | Pourquoi | Licence |
|---|---|---|
| Qt 6 (Core, Gui, Qml, Quick, QuickControls2, DBus, QtQuick.Dialogs) | interface, appels D-Bus, sélecteurs de fichier et de couleur | LGPL-3.0 |
| Kirigami (KDE Frameworks 6) | fenêtre, formulaires, messages | LGPL-2.0+ |
| Thomas Core (`/usr/libexec/thomas-core`) | lit, vérifie et écrit les styles | celle de Thomas OS |

Compilé pendant le build de l'image (étape `compilation` du `Containerfile`), avec les mêmes versions de Qt et de KDE que le système.

## Retour arrière

- **Un style :** « Annuler le dernier changement », ou « Revenir au style de base » dans Thomas Control.
- **Le Studio lui-même :** ce n'est qu'une appli. S'il casse, le reste de Thomas OS n'en dépend pas.
