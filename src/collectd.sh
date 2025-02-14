#!/bin/bash

DURATION=1                         # Durée en minutes
TIME_INTERVAL=1                    # Intervalle de temps pour la collecte des métriques (en secondes)
DESTINATION_SERVER="192.168.1.100" # Adresse IP ou nom DNS du serveur Collectd
DESTINATION_PORT=25826             # Port UDP Collectd par défaut
INTERFACE="wlp2s0"                 # Interface réseau à surveiller
HOSTNAME="client-collectd"         # Nom du client dans les métriques Collectd

# Durée en secondes
nb_sec=$(($DURATION * 60))

# Chemins de configuration et logs
BASE_DIR="/tmp/collectd"
COLLECTD_CONF="/tmp/collectd.conf"
COLLECTD_PID="/tmp/collectd.pid"
COLLECTD_LOG="${PWD}/collectd.log"

# Installation de collectd-core si nécessaire
if ! dpkg -l | grep -q "collectd-core"; then
    echo "⚠️  Le paquet collectd-core est manquant. Installation en cours..."
    apt-get update && apt-get install -y collectd-core
fi

# Vérifier si une instance de Collectd tourne déjà et la stopper si nécessaire
if pgrep -x "collectd" > /dev/null; then
    echo "Une instance de Collectd tourne déjà. Arrêt en cours..."
    systemctl stop collectd
    sleep 2
fi

# Vérifier si les plugins nécessaires sont installés
PLUGINS=("cpu" "memory" "interface" "network" "write_log")
for plugin in "${PLUGINS[@]}"; do
    if ! ls /usr/lib/collectd/ | grep -q "$plugin.so"; then
        echo "⚠️  Le plugin $plugin est manquant. Installation en cours..."
        sudo apt install -y collectd-core
        break
    fi
done

# Création du fichier de configuration temporaire pour Collectd
cat > $COLLECTD_CONF <<EOL
Hostname "$HOSTNAME"
BaseDir "$BASE_DIR"
PIDFile "$COLLECTD_PID"
Interval $TIME_INTERVAL

LoadPlugin cpu
LoadPlugin memory
LoadPlugin ethstat
LoadPlugin logfile
LoadPlugin write_log

<Plugin "cpu">
  ReportByCpu true
  ReportByState true
</Plugin>

<Plugin "memory">
  ValuesPercentage true
</Plugin>

<Plugin "ethstat">
  Interface "$INTERFACE"
</Plugin>

<Plugin "logfile">
  LogLevel "info"
  File "$COLLECTD_LOG"
  Timestamp true
  PrintSeverity true
</Plugin>

<Plugin "write_log">
  Format "Graphite"
</Plugin>

EOL

echo "✅ Configuration Collectd générée :"
cat $COLLECTD_CONF

# Supprimer l'ancien fichier de log
rm -f $COLLECTD_LOG

# Démarrage de Collectd en arrière-plan avec gestion du PID
echo "🚀 Démarrage de Collectd pour $nb_sec secondes..."
collectd -C $COLLECTD_CONF -f > /dev/null 2>&1 &
echo $! > $COLLECTD_PID

# Attente pour la durée spécifiée
sleep $nb_sec

# Terminer Collectd proprement
echo "🛑 Arrêt de Collectd après la durée spécifiée."
kill $(cat $COLLECTD_PID)
rm -f $COLLECTD_PID

# Nettoyage des fichiers temporaires
rm -f $COLLECTD_CONF

echo "✅ Benchmark terminé. Les données ont été envoyées à $DESTINATION_SERVER:$DESTINATION_PORT."
echo "📄 Logs disponibles dans $COLLECTD_LOG"
