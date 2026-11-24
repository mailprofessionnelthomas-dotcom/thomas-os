#!/usr/bin/env python3
"""Vérifie la syntaxe bash de chaque bloc « run: » des workflows, avant de lancer un long test.

  verifier-workflows.py FICHIER.yml...

Exemple attrapé : une apostrophe dans "${x:-n'a pas}" (bash la prend pour un guillemet) ; sans ce contrôle,
l'erreur n'apparaissait qu'après 40 min d'installation.
"""
import os
import re
import subprocess
import sys
import tempfile

import yaml

erreurs = 0
for chemin in sys.argv[1:]:
    doc = yaml.safe_load(open(chemin, encoding="utf-8"))
    for job in (doc.get("jobs") or {}).values():
        for etape in job.get("steps") or []:
            if "run" not in etape:
                continue
            code = re.sub(r"\$\{\{.*?\}\}", "X", etape["run"])  # expressions GitHub remplacées par un mot
            with tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False, encoding="utf-8") as f:
                f.write(code)
            r = subprocess.run(["bash", "-n", f.name], capture_output=True, text=True)
            os.unlink(f.name)
            if r.returncode:
                erreurs += 1
                print(f"ECHEC   {os.path.basename(chemin)} / {etape.get('name')} : {r.stderr.strip()}")
print("OK      syntaxe bash des workflows" if not erreurs else f"ECHEC   {erreurs} bloc(s) avec une erreur de syntaxe")
sys.exit(1 if erreurs else 0)
