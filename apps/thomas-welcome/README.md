# Thomas Welcome

L'écran de bienvenue. Il s'ouvre à la **1re ouverture de session seulement**, à la place de « Bazzite Portal » et des annonces de Bazzite. Il est lancé par `/etc/xdg/autostart/org.thomasos.welcome.desktop` avec `--premier-lancement`.

## Les 7 étapes

1. **Bienvenue :** version, canal de mises à jour.
2. **Connexion :** état réel (Thomas Core `Systeme1.Reseau`), et un bouton pour choisir un Wi-Fi.
3. **Carte graphique :** vérifie que la bonne version de Thomas OS est installée (`Systeme1.CarteGraphique`). Sinon, donne la commande pour changer.
4. **Confidentialité :** seulement ce qui est vrai et vérifié.
5. **Style :** des vignettes, dessinées au build par Thomas Studio dans `/usr/share/thomas-os/apercus/`. Un clic applique le style par Thomas Core.
6. **Préférences :** langue, clavier, applis par défaut, écrans, compte (pages de réglages KDE), et Thomas Control.
7. **Raccourcis à connaître**, puis « Commencer ».

« Commencer », ou fermer la fenêtre, écrit `[bienvenue] fait = oui` par Thomas Core (`Config1.Ecrire`) dans `~/.config/thomas-os/thomas.conf`. Ensuite l'écran ne revient plus tout seul. Il se rouvre depuis le menu (« Bienvenue dans Thomas OS »).

## Ce qu'il ne fait pas (encore)

- **Changer de version (NVIDIA) en un clic :** il faut l'aide système avec mot de passe administrateur (polkit), pas encore faite. En attendant, l'étape 3 affiche la commande.
- **Créer le compte :** c'est l'installateur qui le fait (pas de doublon).
- **Les annonces de Bazzite :** retirées de l'ouverture de session, mais toujours lisibles dans `/usr/share/ublue-os/announcements/`.

## Tests (sur GitHub)

- **`compile.yml` :** photo de chaque étape sans écran, et vérification qu'il ne se rouvre pas une fois fini.
- **Test VM :**
  1. ouvert au 1er login, Bazzite Portal absent ;
  2. les 7 étapes sans erreur QML ;
  3. fermé par Alt+F4 au vrai clavier ;
  4. « fait » retenu, ne se rouvre plus.
- **Commande de test :** `thomas-welcome --capture DOSSIER` prend une photo de chaque étape.

## Dépendances

Les mêmes que Thomas Control : Qt 6, Kirigami et Thomas Core. Toutes sont déjà dans l'image.
