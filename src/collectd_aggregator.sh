#!/bin/bash

LISTENING_PORT=25826                    # Port UDP Collectd par défaut
CONFIG_DIR="./config"                   # Répertoire de configuration             

# Analyse des options de ligne de commande
if [ -n "$1" ]; then
  CONFIG_DIR=$1
fi

collectd_conf="${CONFIG_DIR}/collectd.conf"

# Vérifier si une instance de Collectd tourne déjà et la stopper si nécessaire
if pgrep -x "collectd" > /dev/null; then
    echo "Une instance de Collectd tourne déjà. Arrêt en cours..."
    systemctl stop collectd
    sleep 2
fi

if [ ! -d $CONFIG_DIR ]; then
    echo "Le répertoire de configuration $CONFIG_DIR n'existe pas"
    # Création du répertoire de configuration
    mkdir -p $CONFIG_DIR
    echo "Création du répertoire de configuration $CONFIG_DIR"
fi

rm -f $collectd_conf

# Création du fichier de configuration temporaire pour Collectd
cat > $collectd_conf <<EOL
LoadPlugin network
LoadPlugin write_log

<Plugin "network">
  Listen "0.0.0.0" "$LISTENING_PORT"
</Plugin>

<Plugin "write_log">
  Format "Graphite"
</Plugin>
EOL

echo "✅ Configuration Collectd générée :"
cat $collectd_conf

# Démarrage de Collectd en arrière-plan avec gestion du PID
echo "🚀 Démarrage de Collectd"
collectd -C $collectd_conf -f
echo "Collectd démarré avec succès !"
