#!/bin/sh

BALL_X=$(expr $(expr $(tput lines) - 5) / 2)
BALL_Y=$(expr $(expr $(tput cols) - 5) / 2)

display() {
	PONG_ARENA=""

	while [ 1 = 1 ]
	do
		LINES=$(expr $(tput lines) - 5)
		COLS=$(expr $(tput cols) - 5)

		BALL_Y=$(expr $BALL_Y - 1)

		for i in $(seq 0 $LINES)
		do
			for j in $(seq 0 $COLS)
			do
				if [ $i = 0 ] || [ $i = $LINES ]
				then
					PONG_ARENA="$PONG_ARENA"'-'
					continue
				fi
				if [ $j = 0 ] || [ $j = $COLS ]
				then
					PONG_ARENA="$PONG_ARENA"'|'
					continue
				fi
				if [ "$i" = "$BALL_X" ] && [ "$j" = "$BALL_Y" ]
				then
					PONG_ARENA="$PONG_ARENA"'o'
					continue
				fi
				PONG_ARENA="$PONG_ARENA"' '
			done
			PONG_ARENA="$PONG_ARENA"$'\n'
		done

		clear
		echo "$PONG_ARENA"
		sleep 0.1
		PONG_ARENA=""
	done
}

input() {
	while IFS=$(read -r line)
	do
		if [ "$line" = "up" ]
		then
			echo "up"
		fi
	done
}

input | websocat ws://$1:$2 | display
