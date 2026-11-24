#!/bin/bash
# Essai de Thomas Studio dans l'étape « compilation » (sans écran, rendu logiciel) : un vrai Thomas Core sur un
# bus D-Bus jetable, quelques styles d'essai, leurs maquettes et une photo de la fenêtre du Studio.
# Lancé par compile.yml dans le conteneur, jamais sur un PC. Dépôt monté en lecture seule sur /depot, résultats dans /essai.
set -uo pipefail
if [[ -z "${DANS_DBUS:-}" ]]; then
    export HOME=/tmp/maison XDG_RUNTIME_DIR=/tmp/run LANG=C.UTF-8
    mkdir -p "${HOME}/.local/share/dbus-1/services" "${XDG_RUNTIME_DIR}"
    chmod 700 "${XDG_RUNTIME_DIR}"
    # Thomas Core démarré à la demande par D-Bus, avec le moteur et les styles du dépôt
    export THOMAS_STYLE_BIN=/depot/system_files/usr/bin/thomas-style THOMAS_STYLES_DIR=/depot/system_files/usr/share/thomas-os/styles
    printf '[D-BUS Service]\nName=org.thomasos.Core\nExec=/usr/bin/python3 /depot/system_files/usr/libexec/thomas-core\n' \
        >"${HOME}/.local/share/dbus-1/services/org.thomasos.Core.service"
    export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1 DANS_DBUS=1
    exec dbus-run-session -- bash "$0" "$@"
fi

erreurs=0
S=/sortie/usr/bin/thomas-studio

# Styles d'essai, créés comme le ferait le Studio (lire « thomas », modifier, enregistrer)
python3 - <<'EOF'
import copy, importlib.machinery, importlib.util, os
chargeur = importlib.machinery.SourceFileLoader("ts", os.environ["THOMAS_STYLE_BIN"])
ts = importlib.util.module_from_spec(importlib.util.spec_from_loader("ts", chargeur))
chargeur.exec_module(ts)
base = ts.lire_style("thomas")["style"]

def essai(sid, **modifs):
    s = copy.deepcopy(base)
    for cle, val in modifs.items():
        sec, k = cle.split("__")
        s[sec][k] = val
    print("style d'essai", *ts.enregistrer(sid, s))

clair = dict(couleurs__principale="#2f6fed", couleurs__barre="#f3f4f7", couleurs__fenetres="#fbfbfd",
             couleurs__texte="#1c1d21", couleurs__bordure="", couleurs__fond_haut="#a9c8ff", couleurs__fond_bas="#eef3ff",
             bureau__fond="degrade", effets__epaisseur_bordure="0", effets__opacite="95")
essai("essai-windows", barre__disposition="windows", **clair)
essai("essai-macos", barre__disposition="macos", menu__favoris="liste", couleurs__principale="#ff9f0a",
      couleurs__bordure="#ff9f0a", bureau__fond="uni", couleurs__fond_haut="#24123a")
essai("essai-vertical", barre__disposition="vertical", fenetres__boutons_gauche="XIA", fenetres__boutons_droite="",
      fenetres__bordures="normale", couleurs__principale="#2fbf71", couleurs__bordure="#2fbf71")
essai("essai-libre", barre__disposition="studio", barre__bord="haut", barre__flottante="oui", barre__longueur="ajustee",
      barre__logo_centre="oui", barre__bureaux="oui", menu__cote="droite", notifications__position="haut-droite")
EOF

for st in thomas essai-windows essai-macos essai-vertical essai-libre; do
    timeout 60 "${S}" --apercu "/essai/maquette-${st}.png" --ecran 1920x1080 "${st}" </dev/null || echo "ECHEC   maquette ${st} (code $?)"
done
timeout 60 "${S}" --apercu /essai/maquette-thomas-menu.png --menu --ecran 1920x1080 thomas </dev/null || echo "ECHEC   maquette avec menu"
timeout 60 "${S}" --apercu /essai/maquette-macos-menu.png --menu --ecran 1920x1080 essai-macos </dev/null || echo "ECHEC   maquette macOS avec menu"
timeout 40 "${S}" --capture /essai/fenetre-studio.png thomas </dev/null || echo "ECHEC   photo de la fenêtre (code $?)"

for f in thomas essai-windows essai-macos essai-vertical essai-libre thomas-menu macos-menu; do
    [[ -s "/essai/maquette-${f}.png" ]] || { echo "ECHEC   maquette-${f}.png absente"; erreurs=$((erreurs + 1)); }
done
[[ -s /essai/fenetre-studio.png ]] || { echo "ECHEC   fenetre-studio.png absente"; erreurs=$((erreurs + 1)); }
exit $((erreurs > 0))
