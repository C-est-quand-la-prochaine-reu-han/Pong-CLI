#!/bin/sh

BALL_X=$(expr $(expr $(tput lines) - 5) / 2)
BALL_Y=$(expr $(expr $(tput cols) - 5) / 2)

read_ball_coords() {
	LINES=$(expr $(tput lines) - 5)
	COLUMNS=$(expr $(tput cols) - 5)

	COORDS=$(grep -E '^pos:' game.data)
	BALL_X=$(cut -d':' <(echo $COORDS) -f2)
	BALL_Y=$(cut -d':' <(echo $COORDS) -f3)

	BALL_X=$(printf "%.0f" $(bc -l <<< "$BALL_X * $LINES / 1000"))
	BALL_Y=$(printf "%.0f" $(bc -l <<< "$BALL_Y * $COLUMNS / 1000"))
}

update_ball_coords() {
	until [ ! -f lock ]
	do
		sleep 0.1
	done
	COORDS=$(grep -E '^pos:' game.data)
	BALL_X=$(cut -d':' <(echo $COORDS) -f2)
	BALL_Y=$(cut -d':' <(echo $COORDS) -f3)

	SPEED=$(grep -E '^mov:' game.data)
	SPEED_X=$(cut -d':' <(echo $SPEED) -f2)
	SPEED_Y=$(cut -d':' <(echo $SPEED) -f3)

	TIME=$(grep -E '^time:' game.data | cut -d':' -f2)
	DELTATIME=$(date +%s%N | tail -c 11 | head -c 6)
	DELTA=$(bc -l <<< "($DELTATIME - $TIME) / 10000")

	BALL_X=$(printf "%.0f" $(bc -l <<< "$BALL_X + $DELTA * $SPEED_X"))
	BALL_Y=$(printf "%.0f" $(bc -l <<< "$BALL_Y + $DELTA * $SPEED_Y"))

	# Update time in the file
	sed -i "s/^pos.*/pos:$BALL_X:$BALL_Y/g" game.data
	sed -i "s/^time.*/time:$(date +%s%N | tail -c 11 | head -c 6)/g" game.data 
}

read_player_coords() {
	LINES=$(expr $(tput lines) - 5)
	COLUMNS=$(expr $(tput cols) - 5)

	J1=$(grep -E "^$name:" game.data)
	J2=$(grep -E "^$opponent:" game.data)
}

# Builds and display the pong arena
# Requires BALL_X and BALL_Y to exists
# Creates a string filled with the pong arena, and prints it on the screen at the end of the loop
display() {
	LINES=$(expr $(tput lines) - 5)
	COLUMNS=$(expr $(tput cols) - 5)
	PONG_ARENA=""

	for i in $(seq 0 $LINES)
	do
		for j in $(seq 0 $COLUMNS)
		do
			if [ $i = 0 ] || [ $i = $LINES ]
			then
				PONG_ARENA="$PONG_ARENA"'-'
				continue
			fi
			if [ $j = 0 ] || [ $j = $COLUMNS ]
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
}

# Calculate the ball movements
game_loop() {
	while [ -f game.data ]
	do
		read_ball_coords
		display
		update_ball_coords
		sleep 0.1
	done
}

# Posix readchar - taken from
# https://unix.stackexchange.com/questions/464930/can-i-read-a-single-character-from-stdin-in-posix-shell
readc() { # arg: <variable-name>
	if [ -t 0 ]; then
		# if stdin is a tty device, put it out of icanon, set min and
		# time to sane value, but don't otherwise touch other input or
		# or local settings (echo, isig, icrnl...). Take a backup of the
		# previous settings beforehand.
		saved_tty_settings=$(stty -g)
		stty -icanon min 1 time 0
	fi
	eval "$1="
	while
		# read one byte, using a work around for the fact that command
		# substitution strips trailing newline characters.
		c=$(dd bs=1 count=1 2> /dev/null; echo .)
		c=${c%.}
		
		# break out of the loop on empty input (eof) or if a full character
		# has been accumulated in the output variable (using "wc -m" to count
		# the number of characters).
		[ -n "$c" ] &&
			eval "$1=\${$1}"'$c
				[ "$(($(printf %s "${'"$1"'}" | wc -m)))" -eq 0 ]'; do
		continue
	done
	if [ -t 0 ]; then
		# restore settings saved earlier if stdin is a tty device.
		stty "$saved_tty_settings"
	fi
}

# Build the initial game.data file
function init_game_data {
	echo "pos:500:500" > game.data
	echo "mov:0:0" >> game.data
	echo "$name:450:100" >> game.data
	echo "time:$(date +%s%N | tail -c 11 | head -c 6)" >> game.data
}

# Handle user inputs and translate them for the websocket
# w -> up
# s -> down
function handle_movement {
	echo "$name"
	while [ -f game.data ]
	do
		readc input
		case $input in
			"s")
				echo "down"
				;;
			"w")
				echo "up"
				;;
		esac
	done
}

# Receives the server informations and edit the game.data file to guide the display process
handle_output() {
	while [ 1 = 1 ]
	do
		read -r line
		if [ -z "$line" ]
		then
			continue
		fi
		case $line in
			"")
				continue
				;;
			"pos:"*)
				touch lock
				sed -i "s/^pos.*/$line/g" game.data
				rm lock
				;;
			"mov:"*)
				touch lock
				sed -i "s/^mov.*/$line/g" game.data
				rm lock
				;;
			"opponent:"*)
				touch lock
				opponent=$(echo $line | cut -d':' -f2)
				echo $opponent":450:0" >> game.data
				rm lock
				;;
			"youare:"*)
				touch lock
				if [ $(echo $opponent | cut -d':' -f2) == 1 ]
				then
					sed -i "s/^$name.*/$name:450:100/g" game.data
					sed -i "s/^$opponent.*/$opponent:450:900/g" game.data
				else
					sed -i "s/^$name.*/$name:450:900/g" game.data
					sed -i "s/^$opponent.*/$opponent:450:100/g" game.data
				fi
				rm lock
				;;
			"winner:"*)
				rm game.data
				;;
		esac
	done
}

if [ $# != 2 ]
then
	echo "./pong.sh <host> <port>"
	exit 1
fi

# echo "POSIX ONE-OF-A-KIND NERDY GAME (P.O.N.G.) :"
# echo -n "Please type your name: "
# read -r name
name=CLI_PLAYER

init_game_data
handle_movement | (websocat ws://$1:$2 || rm game.data) | handle_output &
PID=$!

sleep 0.1
if [ -f game.data ]
then
	game_loop
fi

kill $PID
