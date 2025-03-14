#!/bin/bash

# Initialisation des variables
TIME_INTERVAL=1                     # Intervalle de temps pour la collecte des métriques (en secondes)
DESTINATION_SERVER="10.0.0.46"      # Adresse IP ou nom DNS du serveur Collectd
NETWORK_INTERFACE="wlp2s0"          # Interface réseau à surveiller
CONFIG_DIR="./config"               # Répertoire de configuration

# Constantes
HOSTNAME="client-collectd"          # Nom du client dans les métriques Collectd
DESTINATION_PORT=25826              # Port UDP Collectd par défaut

usage() {
  echo "Usage: $0 --destination-server <destination-server> --network-interface <network-interface> --time-interval <time-interval> <conf-dir>"
  exit 1
}


# Analyse des options de ligne de commande
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --destination-server) DESTINATION_SERVER="$2"; shift ;;
		--network-interface) NETWORK_INTERFACE="$2"; shift ;;
		--time-interval) TIME_INTERVAL="$2"; shift ;;
    --help) usage ;;
    *) CONFIG_DIR="$1" ;;
  esac
  shift
done


# Chemins de configuration et logs
collectd_conf="$CONFIG_DIR/collectd.conf"
collectd_pid="$CONFIG_DIR/collectd.pid"

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

mkdir -p ./config

# Nettoyage des fichiers temporaires
rm -f $collectd_conf

# Création du fichier de configuration temporaire pour Collectd
cat > $collectd_conf <<EOL
PIDFile "$collectd_pid"
Interval $TIME_INTERVAL

LoadPlugin cpu
LoadPlugin memory
LoadPlugin interface
LoadPlugin network

<Plugin "cpu">
  ReportByCpu true
  ReportByState true
</Plugin>

<Plugin "memory">
  ValuesPercentage true
</Plugin>

<Plugin "interface">
  Interface "$NETWORK_INTERFACE"
  IgnoreSelected false
</Plugin>

<Plugin "network">
  Server "$DESTINATION_SERVER" "$DESTINATION_PORT"
</Plugin>
EOL

echo "✅ Configuration Collectd générée :"
cat $collectd_conf

