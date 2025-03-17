#!/bin/bash

BASE_TIME=$(date -d "2025-03-12 00:00:00" +%s) # Date de base pour la collecte de données et la génération de graphiques

# Initialisation des variables
DURATION=10 # sec                       # Echantillon de temps pour l'utilisation de l'outil de monitoring
STEP=1 # sec                            # Pas de temps pour la collecte de données
DESTINATION=$PWD/tir_${DURATION}sec     # Répertoire de destination du tir de benchmark
DESTINATION_SERVER="10.0.0.46"          # Adresse IP ou nom DNS du serveur Collectd
CONFIG_DIR=./config                     # Répertoire de configuration de l'outil de monitoring
NETWORK_INTERFACE=wlp2s0                # Interface réseau à surveiller

# Analyse des options de ligne de commande
DURATION=$1

TIME_BEFORE=5 # sec
TIME_AFTER=5 # sec

nb_sec_collect=$(($DURATION + $TIME_BEFORE + $TIME_AFTER))

cleanup() {
  rm -rf ${DESTINATION}
  echo "Nettoyage des fichiers de sortie..."
}

config_vector() {
  echo "Configuration de Vector $1"
  /bin/bash src/vector_config.sh --duration $DURATION --destination-server $DESTINATION_SERVER --time-interval $STEP  --network-interface $NETWORK_INTERFACE --encoding-type $1 $CONFIG_DIR  > /dev/null #2>&1 &
}

config_collectd() {
  echo "Configuration de Collectd"
  /bin/bash src/collectd_config.sh --duration $DURATION --destination-server $DESTINATION_SERVER --time-interval $STEP --network-interface $NETWORK_INTERFACE $CONFIG_DIR  > /dev/null #2>&1 &
}

# Création du répertoire de destination du tir
create_dir() {
  if [ -d ${DESTINATION} ]; then
    echo "Le répertoire ${DESTINATION} existe déjà. Suppression en cours..."
    cleanup
  fi
  echo "Création du répertoire $DESTINATION"
  mkdir -p ${DESTINATION}
  touch ${DESTINATION}/vars
  echo "NB_SECONDS=$nb_sec_collect" > "$DESTINATION/vars"
  echo "BASE_TIME=$BASE_TIME" >> "$DESTINATION/vars"
  echo "Variables enregistrées dans $DESTINATION/vars"
}

stop_collectd() {
  if pgrep -x "collectd" > /dev/null; then
    echo "Une instance de Collectd tourne déjà. Arrêt en cours..."
    kill $(pgrep -x "collectd")
    echo "Arrêt de Collectd"
  fi
}

stop_vector() {
  if pgrep -x "vector" > /dev/null; then
    echo "Une instance de Vector tourne déjà. Arrêt en cours..."
    kill $(pgrep -x "vector")
    echo "Arrêt de Vector"
  fi
}

start_collect_data() {
  echo "Démarrage de la collecte de données pour $1... durée: $nb_sec_collect secondes"
  exec ./src/collect_data.sh --base-time $BASE_TIME --nb-seconds $nb_sec_collect --step $STEP $DESTINATION/$1 > /dev/null 2>&1 &
}

start_vector() {
  echo "Démarage de Vector $1 pour $DURATION secondes"
  timeout $DURATION vector --config-toml $CONFIG_DIR/vector_$1.toml > /dev/null #2>&1
}

start_collectd() {
  echo "Démarage Collectd pour $DURATION secondes"
  timeout $DURATION collectd -C $CONFIG_DIR/collectd.conf -f > /dev/null #2>&1
}

generate_graphs() {
  echo "Generation des graphiques..."
  /bin/bash src/agregate_graph.sh $DESTINATION > /dev/null #2>&1
}

# Lancer un benchmark Vector avec un type d'encodage donné
bench_vector() {
  config_vector $1
  echo "Benchmark Vector $1 en cours..."
  start_collect_data vector-$1
  sleep $TIME_BEFORE
  start_vector $1
  sleep $TIME_AFTER
  echo "Benchmark Vector $1 terminé."
}

# Lancer un benchmark Collectd
bench_collectd() {
  config_collectd
  echo "Benchmark Collectd en cours..."
  start_collect_data collectd
  sleep $TIME_BEFORE
  start_collectd
  sleep $TIME_AFTER
  echo "Benchmark Collectd terminé."
}

# Main
create_dir

stop_vector
stop_collectd

bench_vector csv
bench_vector protobuf
bench_vector json
bench_collectd

sleep 1
generate_graphs
echo "Benchmark terminé."

