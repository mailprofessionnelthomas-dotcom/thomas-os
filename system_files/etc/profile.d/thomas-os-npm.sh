# Thomas OS : "npm install -g" installe dans ton dossier perso (~/.local),
# car le système est en lecture seule. Les commandes vont dans ~/.local/bin.
if [ -n "${HOME:-}" ]; then
    export NPM_CONFIG_PREFIX="${HOME}/.local"
fi
