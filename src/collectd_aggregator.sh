#!/bin/bash

LISTENING_PORT=25826             # Port UDP Collectd par défaut

# Chemins de configuration et logs
COLLECTD_CONF="./config/collectd.conf"

# Vérifier si une instance de Collectd tourne déjà et la stopper si nécessaire
if pgrep -x "collectd" > /dev/null; then
    echo "Une instance de Collectd tourne déjà. Arrêt en cours..."
    systemctl stop collectd
    sleep 2
fi

rm -f $COLLECTD_CONF

# Création du fichier de configuration temporaire pour Collectd
cat > $COLLECTD_CONF <<EOL
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
cat $COLLECTD_CONF

# Démarrage de Collectd en arrière-plan avec gestion du PID
echo "🚀 Démarrage de Collectd"
collectd -C $COLLECTD_CONF -f
echo "Collectd démarré avec succès !"
