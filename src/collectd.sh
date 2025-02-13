#!/bin/bash

# Vérifier si le script est exécuté en root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté en root. Relance avec sudo."
   exit 1
fi

# Variables
DURATION=1 # Durée en minutes
DESTINATION_SERVER="192.168.1.100" # Adresse IP ou nom DNS du serveur Collectd
DESTINATION_PORT=25826             # Port UDP Collectd par défaut
INTERFACE="wlp2s0"                 # Interface réseau à surveiller
HOSTNAME="client-collectd"         # Nom du client dans les métriques Collectd

# Durée en secondes
nb_sec=$(($DURATION * 60))

# Chemins de configuration et logs
COLLECTD_CONF="/tmp/collectd.conf"
COLLECTD_LOG="/home/arthurb/envs/iroco/src/monitoring-benchmark/collectd.log"
COLLECTD_PID="/tmp/collectd_benchmark.pid"

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
BaseDir "/tmp/collectd"
PIDFile "$COLLECTD_PID"
Interval 1
LoadPlugin cpu
LoadPlugin memory
LoadPlugin interface
LoadPlugin network
LoadPlugin logfile

<Plugin "interface">
  Interface "$INTERFACE"
  IgnoreSelected false
</Plugin>

<Plugin cpu>
  ReportByCpu true
  ReportByState true
  ValuesPercentage true
</Plugin>

<Plugin memory>
  ValuesAbsolute true
  ValuesPercentage true
</Plugin>

<Plugin "network">
  Server "$DESTINATION_SERVER" "$DESTINATION_PORT"
</Plugin>

<Plugin "logfile">
  File "$COLLECTD_LOG"
  Timestamp true
  PrintSeverity true
  LogLevel "info"
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

# Vérifier si Collectd a bien démarré
sleep 2
if ! ps -p $(cat $COLLECTD_PID) > /dev/null 2>&1; then
    echo "❌ Échec du démarrage de Collectd. Vérifiez les logs."
    exit 1
fi

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
