"""Capteurs de Thomas OS : températures et espace disque. Lecture seule, rien n'est modifié.

Températures : /sys/class/hwmon (processeur, carte graphique AMD/Intel, SSD…) et nvidia-smi pour le pilote NVIDIA.
THOMAS_HWMON permet aux tests de donner un faux dossier de capteurs.
"""
import os
import shutil
import subprocess
from pathlib import Path

HWMON = Path(os.environ.get("THOMAS_HWMON", "/sys/class/hwmon"))
NOMS = {"k10temp": "Processeur (AMD)", "zenpower": "Processeur (AMD)", "coretemp": "Processeur (Intel)",
        "amdgpu": "Carte graphique (AMD)", "radeon": "Carte graphique (AMD)", "nouveau": "Carte graphique (NVIDIA)",
        "i915": "Carte graphique (Intel)", "xe": "Carte graphique (Intel)", "nvme": "SSD NVMe", "drivetemp": "Disque",
        "acpitz": "Carte mère", "pch_cannonlake": "Chipset", "pch_skylake": "Chipset"}
SEUIL_PAR_DEFAUT = 95.0  # °C, quand le capteur ne donne pas sa limite


def _nombre(p):
    try:
        return int(p.read_text().strip())
    except (OSError, ValueError):
        return None


def temperatures():
    """[(nom, °C, limite °C)] : une ligne par puce, sa valeur la plus haute (ex. « Package » ou « junction »).
    limite = valeur critique donnée par le capteur, sinon 0."""
    sortie = []
    for puce in sorted(HWMON.glob("hwmon*")):
        try:
            nom_puce = (puce / "name").read_text().strip()
        except OSError:
            nom_puce = puce.name
        mesures = []
        for f in sorted(puce.glob("temp*_input")):
            v = _nombre(f)
            if v is None or v <= 0:
                continue
            base = f.name[: -len("_input")]
            limite = _nombre(puce / f"{base}_crit") or _nombre(puce / f"{base}_max") or 0
            mesures.append((v / 1000, limite / 1000))
        if mesures:
            v, limite = max(mesures)
            sortie.append((NOMS.get(nom_puce, nom_puce), round(v, 1), round(limite, 1)))
    if shutil.which("nvidia-smi"):
        try:
            r = subprocess.run(["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits"],
                               capture_output=True, text=True, timeout=5)
            sortie += [("Carte graphique (NVIDIA)", float(x), 0.0) for x in r.stdout.split()]
        except (OSError, ValueError, subprocess.TimeoutExpired):
            pass
    return sortie


def seuil(limite):
    """Température à partir de laquelle on prévient : 5 °C sous la limite du capteur."""
    return limite - 5 if limite > 0 else SEUIL_PAR_DEFAUT


def disques():
    """[(point de montage, octets au total, octets libres)], une fois par système de fichiers."""
    vus, sortie = set(), []
    for point in ("/var/home", "/", "/var"):
        try:
            dev = os.stat(point).st_dev
        except OSError:
            continue
        if dev in vus:
            continue
        vus.add(dev)
        u = shutil.disk_usage(point)
        sortie.append((point, u.total, u.free))
    return sortie
