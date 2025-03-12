#!/bin/bash

# Initialisation des variables
DESTINATION=$1

load_variables() {
  if [ -f "$DESTINATION/vars" ]; then
    source "$DESTINATION/vars"
  else
    echo "Fichier de variables introuvable."
  fi
}

load_variables

echo "Nombre de secondes: $NB_SECONDS"
echo "Temps de base: $BASE_TIME"
echo "Destination: $DESTINATION"

end_time=$(( BASE_TIME + NB_SECONDS ))

color_index=0
colors=( "#0000FF" "#FF0000" "#00FF00" "#FFFF00" "#00FFFF" "#FF00FF" )

get_color() {
  local color="${colors[$1]}"
  if [ -z "$color" ]; then
    color="#$(printf '%06X' $(( RANDOM % 16777215 )))"
  fi
  color_index=$((color_index + 1))
  echo "$color"
}

network_graph() {
  local args=()
  local color_index=0

  for dir in "$DESTINATION"/*/; do
    local folder
    folder=$(basename "$dir")
    args+=( DEF:${folder}_tx=${DESTINATION}/${folder}/network.rrd:tx:AVERAGE \
            VDEF:${folder}_average=${folder}_tx,AVERAGE 
            )
    

    args+=( "LINE1:${folder}_tx$(get_color $color_index):${folder} upload" )
    args+=( "LINE2:${folder}_average$(get_color $color_index):Moyenne_${folder}" )
    
    color_index=$((color_index + 1))
  done
  
  rrdtool graph "$DESTINATION/network_usage.png" \
    --width 800 --height 300 \
    --title "Utilisation réseau sur les $NB_SECONDS dernières secondes" \
    --vertical-label "Kilobits par seconde" \
    --start "$BASE_TIME" --end "$end_time" \
    "${args[@]}"
}



cpu_graph() {

  local args=()
  local color_index=0

  for dir in "$DESTINATION"/*/; do
    local folder
    folder=$(basename "$dir")
    args+=( DEF:${folder}_user=$DESTINATION/${folder}/cpu.rrd:user:AVERAGE \
            DEF:${folder}_nice=$DESTINATION/${folder}/cpu.rrd:nice:AVERAGE \
            DEF:${folder}_system=$DESTINATION/${folder}/cpu.rrd:system:AVERAGE \
            DEF:${folder}_iowait=$DESTINATION/${folder}/cpu.rrd:iowait:AVERAGE \
            DEF:${folder}_irq=$DESTINATION/${folder}/cpu.rrd:irq:AVERAGE \
            DEF:${folder}_softirq=$DESTINATION/${folder}/cpu.rrd:softirq:AVERAGE \
            CDEF:${folder}_total=${folder}_user,${folder}_nice,${folder}_system,${folder}_iowait,${folder}_irq,${folder}_softirq,+,+,+,+,+  
            VDEF:${folder}_average=${folder}_total,AVERAGE 
            )
            


    args+=( "LINE1:${folder}_total$(get_color $color_index):${folder} total cpu usage")
    args+=( "LINE2:${folder}_average$(get_color $color_index):Moyenne_${folder}" )


    color_index=$((color_index + 1))
  done

	rrdtool graph $DESTINATION/cpu_usage.png \
    --width 800 --height 300 \
    --title "Utilisation CPU sur les $NB_SECONDS dernières secondes" \
    --vertical-label "CPU usage" \
    --start $BASE_TIME  --end $end_time\
    --lower-limit 0 --upper-limit 100 \
    "${args[@]}"

}


memory_graph() {
  local args=()
  local color_index=0

  for dir in "$DESTINATION"/*/; do
    local folder
    folder=$(basename "$dir")
    args+=(

    )
  done
	rrdtool graph $DESTINATION/memory_usage.png \
	--width 800 --height 300 \
	--title "Utilisation mémoire sur les $NB_SECONDS dernières secondes" \
	--vertical-label "Pourcentage" \
	--start $BASE_TIME  --end $BASE_TIME+$NB_SECONDS\
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