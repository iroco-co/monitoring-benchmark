#!/bin/bash

# Initialisation des variables
NB_SECONDS=$1
DESTINATION=$2

echo "Nombre de secondes: $NB_SECONDS"
echo "Destination: $DESTINATION"

network_graph() {
	rrdtool graph $DESTINATION/network_usage.png \
	--width 800 --height 300 \
	--title "Utilisation réseau sur les $NB_SECONDS dernières secondes" \
	--vertical-label "Kilobits par seconde" \
	--start -${NB_SECONDS}sec --end now \
	DEF:tx=$DESTINATION/network.rrd:tx:AVERAGE \
	LINE1:tx#0000FF:"Upload"
}

cpu_graph() {

	rrdtool graph $DESTINATION/cpu_usage.png \
	--width 800 --height 300 \
	--title "Utilisation CPU sur les $NB_SECONDS dernières secondes" \
	--vertical-label "CPU usage" \
	--start -${NB_SECONDS}sec --end now \
	--lower-limit 0 --upper-limit 100 \
	DEF:user=$DESTINATION/cpu.rrd:user:AVERAGE \
	DEF:nice=$DESTINATION/cpu.rrd:nice:AVERAGE \
	DEF:system=$DESTINATION/cpu.rrd:system:AVERAGE \
	DEF:iowait=$DESTINATION/cpu.rrd:iowait:AVERAGE \
	DEF:irq=$DESTINATION/cpu.rrd:irq:AVERAGE \
	DEF:softirq=$DESTINATION/cpu.rrd:softirq:AVERAGE \
	CDEF:total=user,nice,system,iowait,irq,softirq,+,+,+,+,+ \
	AREA:user#FF0000:"User" \
	STACK:nice#00FF00:"Nice" \
	STACK:system#0000FF:"System" \
	STACK:iowait#FFFF00:"I/O Wait" \
	STACK:irq#00FFFF:"IRQ" \
	STACK:softirq#FF00FF:"Soft IRQ" \

}


memory_graph() {
	rrdtool graph $DESTINATION/memory_usage.png \
	--width 800 --height 300 \
	--title "Utilisation mémoire sur les $NB_SECONDS dernières secondes" \
	--vertical-label "Pourcentage" \
	--start -${NB_SECONDS}sec --end now \
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

network_graph
cpu_graph
memory_graph