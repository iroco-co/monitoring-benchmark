#!/bin/bash

BASE_TIME=$(date -d "2025-03-12 00:00:00" +%s)

# Benchmark durée
DURATION=$1 # sec
STEP=1 # sec
DESTINATION=$PWD/tir_${DURATION}sec
DESTINATION_SERVER="10.0.0.46"
CONFIG_DIR=./config
NETWORK_INTERFACE=wlp2s0


TIME_BEFORE=5 # sec
TIME_AFTER=5 # sec

nb_sec_collect=$(($DURATION + $TIME_BEFORE + $TIME_AFTER))

total_sec=$(($nb_sec_collect*2))


# Création des fichiers de sortie
cleanup() {
  rm -rf ${DESTINATION}
  echo "Nettoyage des fichiers de sortie..."
}

config_vector() {
  mkdir -p $CONFIG_DIR
  exec src/vector_config.sh --duration $DURATION --destination-server $DESTINATION_SERVER --time-interval $STEP  --network-interface $NETWORK_INTERFACE --encoding-type $1 $CONFIG_DIR  > /dev/null 2>&1 &
}

config_collectd() {
  mkdir -p $CONFIG_DIR
  exec src/collectd_config.sh --duration $DURATION --destination-server $DESTINATION_SERVER --time-interval $STEP $CONFIG_DIR  > /dev/null 2>&1 &
}

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
  exec ./src/collect_data.sh --base-time $BASE_TIME --nb-seconds $nb_sec_collect $DESTINATION/$1 > /dev/null 2>&1 &
}

start_vector() {
  echo "Démarage de Vector $1"
  timeout $DURATION vector --config-toml $CONFIG_DIR/vector_$1.toml #> /dev/null 2>&1 &
}

start_collectd() {
  echo "Démarage Collectd"
  timeout $DURATION collectd -C $CONFIG_DIR -f #> /dev/null 2>&1 &
}

bench_vector() {
  config_vector $1
  echo "Benchmark Vector $1 en cours..."
  start_collect_data vector-$1
  sleep $TIME_BEFORE
  start_vector $1
  sleep $TIME_AFTER
  echo "Benchmark Vector $1 terminé."
}

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
cleanup
create_dir

stop_vector
stop_collectd

bench_vector csv
bench_vector protobuf
bench_vector json
bench_collectd

sleep 1
echo "Generation des graphiques..."
exec src/agregate_graph.sh $DESTINATION
kill $(jobs -p)
echo "Benchmark terminé."

