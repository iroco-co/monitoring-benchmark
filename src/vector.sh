#!/bin/bash

# Variables
DURATION=60                                      # Durée en minutes
TIME_INTERVAL=1                                 # Intervalle de temps pour la collecte des métriques (en secondes)
DESTINATION_SERVER="10.0.0.46:6000"             # Adresse de destination (serveur HTTP ou Vector)
VECTOR_CONFIG="./config/vector.toml"                     # Fichier de configuration temporaire pour Vector

nb_sec=$(($DURATION * 1))                      # Durée en secondes

mkdir -p ./config

# Nettoyage
rm -f $VECTOR_CONFIG

# Génération de la configuration Vector
cat > $VECTOR_CONFIG <<EOL
# Configuration Vector pour le benchmark

[sources.host_metrics]
type = "host_metrics"
scrape_interval_secs = $TIME_INTERVAL
network.devices.includes = ["wlp2s0"]
collectors = ["cpu", "memory", "network"]

[transforms.metrics_to_logs]
type = "metric_to_log"
inputs = ["host_metrics"]

[transforms.lite_logs]
type = "remap"
inputs = ["metrics_to_logs"]
source = '''
  .value = if .counter != null { del(.counter).value } else { del(.gauge).value }  
  del(.namespace)
  .name,err = if .tags.cpu != null {"cpu-" + to_string(.tags.cpu) + "-" + to_string(.tags.mode)} else {del(.name)}
  .name,err = del(.host)+"."+del(.name)
  # .message,err = .name+" "+ to_string(.value)

  del(.tags)
  del(.kind)
  del(.timestamp)
  '''



[sinks.console]
type = "console"
inputs = ["lite_logs"]
# encoding.codec = "json"

encoding.codec = "protobuf"
encoding.protobuf.desc_file = "$PWD/config/myproto.desc"
encoding.protobuf.message_type = "ExempleMessage"

# encoding.codec = "csv"
# encoding.csv.fields = ["host", "name", "value"]

[sinks.vector]
type = "socket"
inputs = ["lite_logs"]
address = "$DESTINATION_SERVER"
mode = "udp"

encoding.codec = "protobuf"
encoding.protobuf.desc_file = "$PWD/config/myproto.desc"
encoding.protobuf.message_type = "ExempleMessage"


# encoding.codec = "raw_message"

# encoding.codec = "csv"
# encoding.csv.fields = ["host", "name", "value"]
EOL

echo "Configuration Vector générée :"
cat $VECTOR_CONFIG

# Démarrage de Vector
echo "Démarrage de Vector pour une durée de $nb_sec secondes..."
vector --config-toml $VECTOR_CONFIG &
echo "Vector démarré avec succès sur le port : $PORT"

# Attente pour la durée spécifiée
sleep $nb_sec

# Arrêt de Vector
echo "Arrêt de Vector après la durée spécifiée."
kill $(jobs -p)


echo "Benchmark terminé. Les données ont été envoyées à $DESTINATION_SERVER."
