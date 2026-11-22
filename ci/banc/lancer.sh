#!/bin/bash
# Banc d'essai Thomas OS (dans l'image, en root) : crée un utilisateur de test puis lance sa session KDE.
set -uo pipefail
mkdir -p /var/home
id banc >/dev/null 2>&1 || useradd -m -s /bin/bash banc
install -d -o banc -g banc -m 700 /tmp/xdg-banc
chmod 777 /sortie
echo "[banc] $(grep PRETTY_NAME /etc/os-release) / $(rpm -q plasma-workspace kwin 2>/dev/null | tr '\n' ' ')"
# setpriv (pas runuser) : dans un conteneur, PAM refuse d'ouvrir une session
exec setpriv --reuid=banc --regid=banc --init-groups env -i HOME=/home/banc USER=banc LOGNAME=banc SHELL=/bin/bash LANG=fr_FR.UTF-8 \
  PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin XDG_RUNTIME_DIR=/tmp/xdg-banc DISPLAY="${DISPLAY}" \
  dbus-run-session -- bash /banc/session.sh
