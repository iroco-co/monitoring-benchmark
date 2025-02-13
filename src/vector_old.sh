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

# Memory metrics

[sources.memory_host_metrics]
type = "host_metrics"
scrape_interval_secs = 1
collectors = ["memory"]

[transforms.filter_memory_metrics]
type = "filter"
inputs = ["memory_host_metrics"]
condition = '''
  includes(
    ["memory_total_bytes", "memory_used_bytes", "memory_free_bytes", "memory_shared_bytes", "memory_buffered_bytes", "memory_cached_bytes", "memory_available_bytes"],
    .name
  )
'''

[transforms.memory_metrics_to_logs]
type = "metric_to_log"
inputs = ["filter_memory_metrics"]

[sinks.memory_file]
type = "file"
inputs = ["memory_metrics_to_logs"]
encoding.codec = "json"
path = "./memory_run.json"


# CPU metrics

[sources.cpu_host_metrics]
type = "host_metrics"
scrape_interval_secs = 1
collectors = ["cpu"]

[transforms.filter_cpu_metrics]
type = "filter"
inputs = ["cpu_host_metrics"]
condition = '''
  includes(
    ["cpu_seconds_total"],
    .name
  )
'''

[transforms.aggregate_cpu]
type = "reduce"
inputs = ["filter_cpu_metrics"]
group_by = ["tags.mode"]
starts_when = "true"
merge_strategies = { "counter.value" = "sum" }

[transforms.calculate_average]
type = "remap"
inputs = ["aggregate_cpu"]
source = '''
cpu_count = 8.0
.mode = .tags.mode
.average_value = (.counter.value / cpu_count) ?? 0.0
'''

[transforms.cpu_metrics_to_logs]
type = "metric_to_log"
inputs = ["calculate_average"]

[sinks.cpu_file]
type = "file"
inputs = ["aggregate_cpu"]
encoding.codec = "json"
path = "./cpu_run.json"


# Network metrics

[sources.network_host_metrics]
type = "host_metrics"
scrape_interval_secs = 1
network.devices.includes = ["wlp2s0"]
collectors = ["network"]

# [transforms.filter_network_metrics]
# type = "filter"
# inputs = ["network_host_metrics"]
# condition = '''
#   includes(
#     ["*"],
#     .name
#   )
# '''

[transforms.network_metrics_to_logs]
type = "metric_to_log"
inputs = ["network_host_metrics"]

[sinks.network_file]
type = "file"
inputs = ["network_metrics_to_logs"]
encoding.codec = "json"
path = "./network_run.json"

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
