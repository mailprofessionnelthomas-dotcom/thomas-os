# Installer Thomas OS à côté de Windows (clé USB)

Durée : environ 1 h, dont 20 min d'installation. **Secure Boot reste activé** : Windows et FACEIT ne changent pas.
Thomas OS s'installe dans de l'espace libre ; Windows n'est pas effacé.

## 1. Récupérer l'ISO (sur Windows)

1. Va dans les [Releases](https://github.com/mailprofessionnelthomas-dotcom/thomas-os/releases). Prends la plus récente qui s'appelle « Clé USB Thomas OS ».
2. Télécharge **tous** les fichiers `.part`, et `Assembler-ISO.cmd`, dans un même dossier.
3. Double-clique sur `Assembler-ISO.cmd`.
   - Il recolle l'ISO et vérifie qu'elle est intacte : il doit afficher « OK ».
   - Ensuite, tu peux supprimer les `.part`.

## 2. Faire la clé USB (outil graphique)

Il te faut une clé de **16 Go ou plus**. **Tout ce qu'il y a dessus sera effacé.** Choisis un des deux outils :

- **Fedora Media Writer** (l'outil officiel de Fedora, à installer) :
  1. Choisis « Sélectionner un fichier .iso » et prends l'ISO.
  2. Choisis ta clé.
  3. Clique sur « Écrire ».
- **Rufus** (version portable, rien à installer) :
  1. Choisis ta clé, puis l'ISO, puis « Démarrer ».
  2. Quand Rufus demande le mode d'écriture, choisis **« Image DD »**. C'est obligatoire : le mode ISO ne marche pas avec cette clé.

## 3. Préparer Windows (une seule fois)

1. **Sauvegarde tes fichiers importants**, par précaution.
2. **BitLocker / chiffrement de l'appareil :**
   - Va dans Paramètres → Confidentialité et sécurité → Chiffrement de l'appareil.
   - S'il est activé, note ta **clé de récupération** (compte Microsoft → Appareils), ou désactive-le.
   - L'installateur prévient s'il trouve une partition chiffrée.
3. **Faire de la place :**
   1. Clic droit sur Démarrer → **Gestion des disques**.
   2. Clic droit sur `C:` → **Réduire le volume**.
   3. Réduis d'**au moins 100 Go**. Laisse cet espace « Non alloué » : ne crée rien dedans.
4. **Démarrage rapide :**
   1. Va dans Panneau de configuration → Options d'alimentation → « Choisir l'action des boutons d'alimentation ».
   2. Décoche « Activer le démarrage rapide ».

   Sans ça, Linux peut voir les disques de Windows comme « en cours d'utilisation ».

## 4. Démarrer sur la clé

1. Branche la clé, puis redémarre le PC.
2. Au démarrage, appuie sur la touche du **menu de démarrage** :
   - ASUS : F8 ;
   - MSI : F11 ;
   - Gigabyte : F12 ;
   - sinon, l'écran du fabricant l'indique.
3. Choisis la clé, avec « UEFI » dans son nom.
4. Menu « Thomas OS : essayer et installer » : appuie sur Entrée. Si l'écran reste noir, redémarre et prends « affichage de secours ».

Tu n'as **rien à changer dans le BIOS** : Secure Boot reste activé.

## 5. Installer

Le bureau Thomas OS s'ouvre, puis l'installateur s'ouvre tout seul. Si tu le fermes, tu peux essayer Thomas OS sans rien installer.

1. **Langue :** Français.
2. **Disque :**
   1. Choisis le disque où tu as fait de la place.
   2. Choisis l'option qui **garde Windows** : « utiliser l'espace libre ».
   3. Ne choisis **pas** « effacer le disque ».
3. **Ton compte :** nom et mot de passe, que tu choisis toi-même.
4. **Installer.** Ça dure environ 15 à 20 min, sans Internet nécessaire.

À la fin, une fenêtre te rappelle l'étape Secure Boot ci-dessous.

## 6. Premier redémarrage : la clé Secure Boot (écran bleu)

Enlève la clé USB et redémarre. Un **écran bleu « MOK management »** apparaît. Il faut le faire une seule fois :

1. Avec la flèche ↓, choisis **Enroll MOK** (pas « Continue boot »), puis Entrée. Ensuite **Continue**, puis **Yes**.
2. Tape le mot de passe **`secureboot`** puis Entrée.
   - Cet écran est en clavier QWERTY, mais ce mot se tape pareil en AZERTY.
   - Ce mot de passe n'a rien de secret : il prouve seulement que quelqu'un est devant le PC.
3. Choisis **Reboot**.

Si tu as choisi « Continue boot » par erreur, Thomas OS ne démarre pas : c'est normal, la clé n'est pas encore enregistrée. Ce n'est pas grave :
- éteins puis rallume le PC : l'écran bleu revient ;
- s'il ne revient pas, redémarre sur la clé USB, ouvre Konsole et tape `sudo mokutil --import /usr/share/thomas-os/secureboot.der`, avec le même mot de passe `secureboot` deux fois.

Pourquoi cet écran ? Le noyau de Thomas OS (celui de Bazzite) est signé par Universal Blue. Cette étape l'ajoute aux clés de confiance, sans désactiver Secure Boot.

Photos de ces écrans (prises en VM) : `captures/vm/mok-1-menu.png` à `mok-4-reboot.png`.

**Juste après :** au tout 1er démarrage, Thomas OS affiche « Preparing System », règle le matériel puis **redémarre une fois tout seul**. C'est normal. Ne touche à rien.

## 7. Ensuite

- **Au démarrage :** Thomas OS démarre par défaut. Le logo T rouge s'affiche pendant le chargement (photo : `captures/vm/logo-demarrage.png`), puis l'écran de connexion (`captures/vm/ecran-connexion.png`).
- **Aller sur Windows :** dans Thomas Control → Système → « Redémarrer sur Windows » (le PC redémarre une fois sur Windows). Sinon : la touche du menu de démarrage du PC (étape 4), puis « Windows Boot Manager ».
- **Thomas Welcome** s'ouvre au 1er login : connexion, carte graphique, style, préférences.
- **Les applis** (Opera GX, Firefox, Spotify…) s'installent toutes seules dès que tu es connecté à Internet.
- **Installer autre chose :**
  - soit dans **Bazaar**, la boutique d'applis ;
  - soit comme sur Windows : télécharge le fichier sur le site, puis double-clique dessus. L'installateur Thomas OS s'en occupe :
    - Steam, Discord… : il installe la version boutique ;
    - Epic Games : il installe **Heroic**, qui le remplace sous Linux ;
    - les autres `.exe` : il les lance avec Proton. Beaucoup marchent, pas tous. Les jeux avec anti-triche ne marchent jamais.
  - Pour un `.exe`, KDE demande d'abord « Lancer ce fichier ? » (sécurité, comme l'avertissement de Windows) : clique sur **Lancer**.
- **Konsole (le terminal) :** comme sur Windows :
  - texte sélectionné + **Ctrl+C** = copier ;
  - **Ctrl+C** sans rien de sélectionné = arrêter la commande ;
  - **Ctrl+V** = coller.

  Si Ctrl+C n'arrête pas une commande, c'est qu'il reste du texte sélectionné : clique une fois dans le terminal, ou fais **Ctrl+Maj+C** (arrête toujours). Photos : `captures/vm/konsole-1-selection.png`, `konsole-2-colle.png`.
- **Claude sur Thomas OS :** l'appli Claude n'existe pas pour Thomas OS (sur Linux, seulement Ubuntu et Debian), mais **Claude Code** est déjà installé. La 1re fois, dans Konsole, tape ces deux commandes (elles récupèrent le projet et ses règles pour Claude, `CLAUDE.md`) :
  ```
  git clone https://github.com/mailprofessionnelthomas-dotcom/thomas-os ~/thomas-os
  ```
  ```
  mkdir -p ~/.claude && { [ -e ~/.claude/CLAUDE.md ] || echo '@~/thomas-os/CLAUDE.md' > ~/.claude/CLAUDE.md; }
  ```
  Ensuite, à chaque fois : tape `claude`. La 1re fois, connecte-toi avec ton compte Claude et accepte qu'il lise `~/thomas-os/CLAUDE.md`. Ce n'est pas la même conversation que sur Windows : Claude repart des règles et de l'état du projet écrits dans ce fichier.
- **Si quelque chose ne va pas :** Windows reste toujours accessible, par le menu de démarrage du PC (« Windows Boot Manager »).
- **Changer de canal ou de version (carte graphique) :** Thomas Control → Système (mot de passe administrateur), puis redémarre. Photo : `captures/vm/control-systeme.png`.

**Ne marchent pas sous Linux :** FACEIT et les jeux à anti-triche noyau (Valorant…). Pour eux, démarre sur Windows.
