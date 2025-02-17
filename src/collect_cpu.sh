#!/bin/bash

NB_SECONDS=$1 #$((NB_MINUTES * 60))
DESTINATION=$2

# NB_MINUTES=10
STEP=1 # 1 seconde

echo $NB_SECONDS

NETWORK_INTERFACE="wlp2s0"

create_dir() {
  if [ -d ${DESTINATION} ]; then
    echo "Le répertoire ${DESTINATION} existe déjà. Suppression en cours..."
    cleanup
  fi
  echo "Création du répertoire $DESTINATION"
  mkdir -p ${DESTINATION}
}

create_dir

# Création de la base de données RRD pour le CPU 
# DS-> Data Source : user -> nom de la métrique, COUNTER -> type de données, 5 -> facteur de normalisation, 0 -> valeur minimale, U -> valeur maximale illimitée
# RRA -> Round Robin Archive : AVERAGE -> type de stockage, 0.5 -> facteur de normalisation, 1 -> nombre de données à moyenner, $((NB_MINUTES * 60)) -> nombre de points de données à stocker


rrdtool create $DESTINATION/cpu.rrd \
--step $STEP \
DS:user:COUNTER:5:0:U \
DS:nice:COUNTER:5:0:U \
DS:system:COUNTER:5:0:U \
DS:idle:COUNTER:5:0:U \
DS:iowait:COUNTER:5:0:U \
DS:irq:COUNTER:5:0:U \
DS:softirq:COUNTER:5:0:U \
RRA:AVERAGE:0.5:1:$NB_SECONDS

rrdtool create $DESTINATION/memory.rrd \
--step $STEP \
DS:used:GAUGE:5:0:U \
DS:free:GAUGE:5:0:U \
DS:available:GAUGE:5:0:U \
RRA:AVERAGE:0.5:1:$NB_SECONDS

rrdtool create $DESTINATION/network.rrd \
--step $STEP \
DS:rx:GAUGE:5:0:15 \
DS:tx:GAUGE:5:0:15 \
RRA:AVERAGE:0.5:1:$NB_SECONDS

collect_network () {
	NETWORK_DATA=$(sar -n DEV 1 $STEP | grep $NETWORK_INTERFACE | tail -n 1 | awk '{print $5":"$6}' | sed 's/,/./g')
	echo $NETWORK_DATA
	rrdtool update $DESTINATION/network.rrd N:$NETWORK_DATA
}

collect_cpu () {
	CPU_DATA=$(awk '/^cpu  /{print $2":"$3":"$4":"$5":"$6":"$7":"$8}' /proc/stat)
	rrdtool update $DESTINATION/cpu.rrd N:$CPU_DATA
	echo $CPU_DATA
}

collect_memory () {
	MEMORY_DATA=$(free | awk '/Mem/{print $3":"$4":"$7}')
	rrdtool update $DESTINATION/memory.rrd N:$MEMORY_DATA
	echo $MEMORY_DATA
}

network_graph() {
	rrdtool graph $DESTINATION/network_usage.png \
	--width 800 --height 300 \
	--title "Utilisation réseau sur les $NB_SECONDS dernières secondes" \
	--vertical-label "Kilobits par seconde" \
	--start -${NB_SECONDS}sec --end now \
	DEF:rx=$DESTINATION/network.rrd:rx:AVERAGE \
	DEF:tx=$DESTINATION/network.rrd:tx:AVERAGE \
	LINE1:rx#FF0000:"Download" \
	LINE1:tx#0000FF:"Upload"
}

cpu_graph() {
	rrdtool graph $DESTINATION/cpu_usage.png \
	--width 800 --height 300 \
	--title "Utilisation CPU sur les $NB_SECONDS dernières secondes" \
	--vertical-label "Pourcentage" \
	--start -${NB_SECONDS}sec --end now \
	--lower-limit 0 --upper-limit 100 \
	DEF:user=$DESTINATION/cpu.rrd:user:AVERAGE \
	DEF:nice=$DESTINATION/cpu.rrd:nice:AVERAGE \
	DEF:system=$DESTINATION/cpu.rrd:system:AVERAGE \
	DEF:idle=$DESTINATION/cpu.rrd:idle:AVERAGE \
	DEF:iowait=$DESTINATION/cpu.rrd:iowait:AVERAGE \
	DEF:irq=$DESTINATION/cpu.rrd:irq:AVERAGE \
	DEF:softirq=$DESTINATION/cpu.rrd:softirq:AVERAGE \
	'CDEF:total=user,nice,+,system,+,idle,+,iowait,+,irq,+,softirq,+' \
	'CDEF:user_pct=user,total,/,100,*' \
	'CDEF:nice_pct=nice,total,/,100,*' \
	'CDEF:system_pct=system,total,/,100,*' \
	'CDEF:idle_pct=idle,total,/,100,*' \
	'CDEF:iowait_pct=iowait,total,/,100,*' \
	'CDEF:irq_pct=irq,total,/,100,*' \
	'CDEF:softirq_pct=softirq,total,/,100,*' \
	AREA:user_pct#FF0000:"User     " \
	STACK:nice_pct#00FF00:"Nice     " \
	STACK:system_pct#0000FF:"System   " \
	STACK:iowait_pct#FFFF00:"I/O Wait " \
	STACK:irq_pct#00FFFF:"IRQ      " \
	STACK:softirq_pct#FF00FF:"Soft IRQ " \
	LINE1:idle_pct#000000:"Idle     "
}

memory_graph() {
	rrdtool graph $DESTINATION/memory_usage.png \
	--width 800 --height 300 \
	--title "Utilisation mémoire sur les $NB_SECONDS dernières secondes" \
	--vertical-label "Pourcentage" \
	--start -${NB_SECONDS}sec --end now \
	--lower-limit 0 --upper-limit 100 \
	DEF:used=$DESTINATION/memory.rrd:used:AVERAGE \
	DEF:free=$DESTINATION/memory.rrd:free:AVERAGE \
	DEF:available=$DESTINATION/memory.rrd:available:AVERAGE \
	'CDEF:total=used,free,+,available,+' \
	'CDEF:used_pct=used,total,/,100,*' \
	'CDEF:free_pct=free,total,/,100,*' \
	'CDEF:available_pct=available,total,/,100,*' \
	AREA:used_pct#FF0000:"Used     " \
	STACK:free_pct#00FF00:"Free     " \
	STACK:available_pct#0000FF:"Available"
}


for i in $(seq 1 $NB_SECONDS); do
	collect_network &
	collect_cpu &
	collect_memory &
	sleep $STEP
done

network_graph
cpu_graph
memory_graph