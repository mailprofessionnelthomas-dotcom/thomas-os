#!/bin/bash
# Lance « verifier.sh PHASE » dans la VM par SSH. Réessaie si c'est la connexion SSH elle-même qui échoue
# (code 255, par exemple pendant la fin du démarrage), pas si une vérification échoue.
phase="$1"
for essai in 1 2 3 4 5 6; do
    # shellcheck disable=SC2086
    ${SSH} "MDP='${MDP}' bash -s ${phase}" <ci/vm/verifier.sh
    rc=$?
    [[ "${rc}" -ne 255 ]] && exit "${rc}"
    echo "connexion SSH perdue, nouvel essai dans 15 s (${essai}/6)" >&2
    sleep 15
done
exit 255
