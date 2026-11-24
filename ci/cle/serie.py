#!/usr/bin/env python3
"""Test d'installation de la clé USB (sur GitHub) : pilote la session live par sa console série (socket QEMU).

  serie.py SOCKET JOURNAL KICKSTART

Comme quelqu'un devant le PC, mais au clavier série :
  1. se connecte en « liveuser » (pas de mot de passe dans une session live), puis passe root ;
  2. ferme l'installateur graphique ouvert tout seul, et remplace « yad » par un faux (ses fenêtres attendraient
     un clic : le texte qu'elles auraient montré est gardé dans /tmp/yad.log) ;
  3. copie le kickstart de test et lance l'installateur sans interface, avec les mêmes réglages que le vrai
     (le kickstart inclut /usr/share/anaconda/interactive-defaults.ks) ;
  4. rend la main quand l'installation a écrit son repère de fin ; sinon affiche les journaux et échoue.
"""
import base64
import re
import socket
import sys
import time


class Serie:
    def __init__(self, chemin, journal):
        self.s = socket.socket(socket.AF_UNIX)
        self.s.connect(chemin)
        self.s.settimeout(1)
        self.tampon = ""
        self.tout = ""  # toute la sortie depuis le début (un repère déjà passé n'est jamais perdu)
        self.journal = open(journal, "a", encoding="utf-8", errors="replace")
        self.n = 0

    def lire(self):
        try:
            d = self.s.recv(65536).decode("utf-8", "replace")
        except socket.timeout:
            d = ""
        self.tampon += d
        self.tout += d
        self.journal.write(d)
        self.journal.flush()

    def chercher_depuis(self, motif, depuis, delai):
        fin = time.time() + delai
        while time.time() < fin:
            self.lire()
            m = re.search(motif, self.tout[depuis:])
            if m:
                return m
        return None

    def attendre(self, motif, delai):
        fin = time.time() + delai
        while time.time() < fin:
            self.lire()
            m = re.search(motif, self.tampon)
            if m:
                self.tampon = self.tampon[m.end():]
                return m
        return None

    def envoyer(self, texte):
        # si personne ne lit la console série dans la VM (pas encore d'invite), l'envoi attend : on patiente un peu
        self.s.settimeout(30)
        try:
            self.s.sendall(texte.encode())
        except socket.timeout:
            pass
        finally:
            self.s.settimeout(1)

    def commande(self, c, delai=120):
        """Lance une commande dans le shell root et renvoie son code de sortie (None si pas de réponse)."""
        self.n += 1
        sep = " " if c.rstrip().endswith("&") else "; "  # « &; » est une erreur de syntaxe en bash
        self.envoyer(f"{c}{sep}echo FIN-$?-{self.n}\r")
        m = self.attendre(rf"FIN-(\d+)-{self.n}\b", delai)
        return int(m.group(1)) if m else None


def etape(texte):
    print(f"--- {texte}", flush=True)


def main():
    sock, journal, kickstart = sys.argv[1:4]
    s = Serie(sock, journal)

    etape("attente de la session live (invite de connexion sur la console série)")
    for _ in range(90):  # jusqu'à 15 min
        s.envoyer("\r")
        if s.attendre(r"login: ?", 10):
            break
    else:
        sys.exit("ECHEC : pas d'invite de connexion sur la console série")
    s.envoyer("liveuser\r")
    if not s.attendre(r"\$ ?$|\$ ", 60):
        sys.exit("ECHEC : connexion « liveuser » refusée")
    s.envoyer("sudo -i\r")
    if not s.attendre(r"# ?$|# ", 60):
        sys.exit("ECHEC : pas de shell root (sudo)")
    s.commande("export TERM=dumb PS1='RACINE# '")
    print("OK      connecté en root sur la session live", flush=True)

    etape("préparation : bureau live prêt, installateur graphique fermé, faux yad")
    s.commande("for i in $(seq 60); do pgrep -x plasmashell >/dev/null && break; sleep 5; done; sleep 20", 400)
    s.commande("pkill -f anaconda; pkill -f liveinst; pkill -f firefox; sleep 5; pkill -9 -f anaconda; rm -f /var/run/anaconda.pid", 60)
    faux_yad = base64.b64encode(b'#!/bin/sh\necho "yad (test) : $*" >>/tmp/yad.log\nexit 0\n').decode()
    rc = s.commande(f"mv /usr/bin/yad /usr/bin/yad.vrai && echo {faux_yad} | base64 -d >/usr/bin/yad && chmod 755 /usr/bin/yad")
    if rc != 0:
        sys.exit(f"ECHEC : faux yad pas installé ({rc})")

    etape("copie du kickstart de test")
    contenu = base64.b64encode(open(kickstart, "rb").read()).decode()
    s.commande("rm -f /tmp/ks.b64")
    for i in range(0, len(contenu), 400):
        s.commande(f"echo -n {contenu[i:i + 400]} >>/tmp/ks.b64")
    if s.commande("base64 -d /tmp/ks.b64 >/tmp/test.ks && grep -q interactive-defaults /tmp/test.ks") != 0:
        sys.exit("ECHEC : kickstart mal copié")

    etape("installation (installateur sans interface, mêmes réglages que le vrai)")
    # son propre bus D-Bus de session : sans lui, l'installateur s'arrête net (il veut bloquer la mise en veille)
    depuis = len(s.tout)
    if s.commande("(dbus-run-session -- anaconda --liveinst --cmdline --kickstart=/tmp/test.ks >/tmp/install.log 2>&1; "
                  "echo \"THOMAS-INSTALL: anaconda fini, code $?\" >/dev/ttyS0) </dev/null >/dev/null 2>&1 &") != 0:
        sys.exit("ECHEC : installateur pas lancé")
    debut = time.time()
    m = s.chercher_depuis(r"THOMAS-INSTALL: (post fini[^\r\n]*|anaconda fini, code \d+)", depuis, 60 * 60)
    duree = (time.time() - debut) / 60
    if m and m.group(1).startswith("post fini"):
        print(f"OK      installation finie en {duree:.0f} min ; {m.group(1)}", flush=True)
        s.commande("cat /tmp/yad.log 2>/dev/null | sed 's/^/INFO    fenêtre : /'", 30)
        return 0
    print(f"ECHEC   installation : {m.group(1) if m else 'pas de fin au bout de 60 min'}", flush=True)
    s.commande("tail -n 40 /tmp/install.log; tail -n 60 /tmp/anaconda.log; tail -n 30 /tmp/thomas-os-journaux/*.log", 120)
    return 1


if __name__ == "__main__":
    sys.exit(main())
