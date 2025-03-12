#!/bin/bash

BASE_TIME=$(date -d "2025-03-12 00:00:00" +%s)

# Benchmark durée
DURATION=$1 # sec
STEP=1 # sec

TIME_BEFORE=5 # sec
TIME_AFTER=5 # sec

DESTINATION=$PWD/tir_${DURATION}sec

VECTOR_CONFIG="./config/vector.toml"
COLLECTD_CONF="./config/collectd.conf"
COLLECTD_PID="./config/collectd.pid"

nb_sec_collect=$(($DURATION + $TIME_BEFORE + $TIME_AFTER))

total_sec=$(($nb_sec_collect*2))


# Création des fichiers de sortie
cleanup() {
  rm -rf ${DESTINATION}
  echo "Nettoyage des fichiers de sortie..."
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
  vector --config-toml $VECTOR_CONFIG > /dev/null 2>&1 &
  echo "Vector démaré"
}

start_collectd() {
  collectd -C $COLLECTD_CONF -f > /dev/null 2>&1 &
  echo "Collectd démarré"
}


# Main
cleanup
create_dir
stop_vector
stop_collectd
echo "Preparation terminée. Début du benchmark pendant $total_sec ..."

# Benchmark Vector
start_collect_data vector
sleep $TIME_BEFORE
start_vector
sleep $DURATION
stop_vector
sleep $TIME_AFTER

echo "Benchmark vector terminé."

# Benchmark Collectd
start_collect_data collectd
sleep $TIME_BEFORE

start_collectd
sleep $DURATION
stop_collectd
sleep $TIME_AFTER

echo "Benchmark collectd terminé."

echo "Generation des graphiques..."
exec src/agregate_graph.sh $DESTINATION
sleep 3
kill $(jobs -p)
echo "Benchmark terminé."

