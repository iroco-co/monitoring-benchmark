#!/bin/bash

# Initialisation des variables
TIME_INTERVAL=1                                 # Intervalle de temps pour la collecte des métriques (en secondes)
DESTINATION_SERVER="10.0.0.46"                  # Adresse de destination (serveur HTTP ou Vector)
NETWORK_INTERFACE="wlp2s0"                      # Interface réseau à surveiller
ENCODING_TYPE="csv"                             # Type d'encodage des données (csv, json, protobuf, raw_message)
CONFIG_DIR="./config"                           # Répertoire de configuration


usage() {
  echo "Usage: $0 --destination-server <destination-server> --network-interface <network-interface> --time-interval <time-interval> --encoding-type <encoding-type> <conf-dir>"
  exit 1
}

# Analyse des options de ligne de commande
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --destination-server) DESTINATION_SERVER="$2"; shift ;;
		--network-interface) NETWORK_INTERFACE="$2"; shift ;;
		--time-interval) TIME_INTERVAL="$2"; shift ;;
		--encoding-type) ENCODING_TYPE="$2"; shift ;;
    --help) usage ;;
    *) CONFIG_DIR="$1" ;;
  esac
  shift
done

echo destination server: $DESTINATION_SERVER
echo nework interface: $NETWORK_INTERFACE
echo encoding-type: $ENCODING_TYPE
echo Config directory : $CONFIG_DIR


vector_config="$CONFIG_DIR/vector_$ENCODING_TYPE.tom"            # Fichier de configuration temporaire pour Vector

if [ "$ENCODING_TYPE" == "csv" ]; then
  destination_port=6000
elif [ "$ENCODING_TYPE" == "protobuf" ]; then
  destination_port=6001   
elif [ "$ENCODING_TYPE" == "json" ]; then
  destination_port=6002
else
  echo "Type d'encodage non supporté"
  exit 1
fi

address=$DESTINATION_SERVER:$destination_port   # Adresse de destination complète

mkdir -p $CONFIG_DIR

cp ./src/myproto.desc $CONFIG_DIR/myproto.desc

rm -f $vector_config

# Génération de la configuration Vector
cat > $vector_config <<EOL
# Configuration Vector pour le benchmark

[sources.host_metrics]
type = "host_metrics"
scrape_interval_secs = $TIME_INTERVAL
network.devices.includes = ["$NETWORK_INTERFACE"]
collectors = ["cpu", "memory", "network"]

[transforms.metrics_to_logs]
type = "metric_to_log"
inputs = ["host_metrics"]

[sinks.vector]
type = "socket"
inputs = ["metrics_to_logs"]
address = "$address"
mode = "udp"
# Configuration de l'encodage en fonction du type spécifié
[sinks.vector.encoding]
codec = "$ENCODING_TYPE"
EOL

if [ "$ENCODING_TYPE" == "protobuf" ]; then
cat >> $vector_config <<EOL
protobuf.desc_file = "$PWD/config/myproto.desc"
protobuf.message_type = "ExempleMessage"
EOL
fi

if [ "$ENCODING_TYPE" == "csv" ]; then
cat >> $vector_config <<EOL
csv.fields = ["name", "value"]
EOL
fi

echo "✅ Configuration Vector générée :"
cat $vector_config
