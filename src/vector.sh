#!/bin/bash

# Variables
DURATION=1 # Durée en minutes
TIME_INTERVAL=1 # Intervalle de temps pour la collecte des métriques (en secondes)
DESTINATION_SERVER="http://192.168.1.100:8080" # Adresse de destination (serveur HTTP ou Vector)
HOSTNAME="vector-client"                      # Nom du client pour identification
VECTOR_CONFIG="vector.toml"              # Fichier de configuration temporaire pour Vector

nb_sec=$(($DURATION * 1))                    # Durée en secondes


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
inputs = ["filter_metrics"]

[sinks.file]
type = "file"
inputs = ["metrics_to_logs"]
encoding.codec = "json"
path = "./run.json"
EOL

echo "Configuration Vector générée :"
cat $VECTOR_CONFIG

# Démarrage de Vector
echo "Démarrage de Vector pour une durée de $nb_sec secondes..."
vector --config-toml $VECTOR_CONFIG &

# Attente pour la durée spécifiée
sleep $nb_sec

# Arrêt de Vector
echo "Arrêt de Vector après la durée spécifiée."
kill $(jobs -p)

# Nettoyage
rm -f $VECTOR_CONFIG

echo "Benchmark terminé. Les données ont été envoyées à $DESTINATION_SERVER."
