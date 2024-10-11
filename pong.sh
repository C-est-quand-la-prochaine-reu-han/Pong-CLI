#!/bin/bash --posix

# Gets the ball coordinates
# Translates them to match the current screen size
read_ball_coords() {
	LINES=$(expr $(tput lines) - 5)
	COLUMNS=$(expr $(tput cols) - 5)

	COORDS=$(grep -E '^pos:' game.data)
	BALL_X=$(printf "$COORDS\n" | cut -d':' -f2)
	BALL_Y=$(printf "$COORDS\n" | cut -d':' -f3)

	BALL_X=$(printf "%.0f" $(bc -l <<< "$BALL_X * $LINES / 1000"));
	BALL_Y=$(printf "%.0f" $(bc -l <<< "$BALL_Y * $COLUMNS / 1000"))
}

# Reads the ball coordinates
# Computes the delta time between now and the last update
# Computes the new ball coordinates
# Updates the file containing the delta time and the coordinates
update_ball_coords() {
	COORDS=$(grep -E '^pos:' game.data)
	BALL_X=$(echo $COORDS | cut -d':' -f2)
	BALL_Y=$(echo $COORDS | cut -d':' -f3)

	SPEED=$(grep -E '^mov:' game.data)
	SPEED_X=$(echo $SPEED | cut -d':' -f2)
	SPEED_Y=$(echo $SPEED | cut -d':' -f3)

	TIME=$(grep -E '^time:' game.data | cut -d':' -f2)
	DELTATIME=$(date +%s%N)

	BALL_X=$(printf "%.0f" $(bc -l <<< "$BALL_X + (($DELTATIME - $TIME) * $SPEED_X / 1000000000)"))
	BALL_Y=$(printf "%.0f" $(bc -l <<< "$BALL_Y + (($DELTATIME - $TIME) * $SPEED_Y / 1000000000)"))

	# Update time in the file
	sed -i "s/^pos.*/pos:$BALL_X:$BALL_Y/g" game.data
	sed -i "s/^time.*/time:$(date +%s%N)/g" game.data 
}

# Reads the player coordinates
read_player_coords() {
	LINES=$(expr $(tput lines) - 5)
	COLUMNS=$(expr $(tput cols) - 5)

	# echo name : $name
	# echo opponent : $opponent

	J1=$(grep -E "^$name:" game.data | cut -d':' -f2)
	J2=$(grep -E "^$opponent:" game.data | cut -d':' -f2)

	if [ ! -z "$J1" ]
	then
		J1=$(printf "%.0f" $(bc -l <<< "$J1 * $LINES / 1000"))
	fi
	if [ ! -z "$J2" ]
	then
		J2=$(printf "%.0f" $(bc -l <<< "$J2 * $LINES / 1000"))
	fi
}

# Builds and display the pong arena
# Requires BALL_X and BALL_Y to exists
# Creates a file filled with the pong arena, and prints it on the screen at the end of the loop
display() {
	COLUMNS=$(expr $(tput cols) - 5)
	LINES=$(expr $(tput lines) - 5)

	rm arena
	exec 3<>arena
	printf -- "-%.0s" $(seq 6 $COLUMNS) >&3
	for j in $(seq 7 $LINES)
	do
		printf '\n|' >&3
		printf ' %.0s' $(seq 8 $COLUMNS) >&3
		printf '|' >&3
	done
	printf "\n" >&3
	printf -- "-%.0s" $(seq 6 $COLUMNS) >&3
	printf "\n" >&3
	exec 3>&-

	if [ ! -z "$J1" ]
	then
		dd if=<(echo "1") of=./arena bs=1 seek=$(printf "%.0f" $(bc -l <<< "($COLUMNS - 4) * ($J1 + 1) + 5")) count=1 conv=notrunc &> /dev/null
		dd if=<(echo "1") of=./arena bs=1 seek=$(printf "%.0f" $(bc -l <<< "($COLUMNS - 4) * ($J1 + 2) + 5")) count=1 conv=notrunc &> /dev/null
		dd if=<(echo "1") of=./arena bs=1 seek=$(printf "%.0f" $(bc -l <<< "($COLUMNS - 4) * ($J1 + 3) + 5")) count=1 conv=notrunc &> /dev/null
		dd if=<(echo "1") of=./arena bs=1 seek=$(printf "%.0f" $(bc -l <<< "($COLUMNS - 4) * ($J1 + 4) + 5")) count=1 conv=notrunc &> /dev/null
		dd if=<(echo "1") of=./arena bs=1 seek=$(printf "%.0f" $(bc -l <<< "($COLUMNS - 4) * ($J1 + 5) + 5")) count=1 conv=notrunc &> /dev/null
	fi
	if [ ! -z "$J2" ]
	then
		dd if=<(echo "2") of=./arena bs=1 seek=$(printf "%.0f" $(bc -l <<< "($COLUMNS - 4) * ($J2 + 1) + 5")) count=1 conv=notrunc &> /dev/null
		dd if=<(echo "2") of=./arena bs=1 seek=$(printf "%.0f" $(bc -l <<< "($COLUMNS - 4) * ($J2 + 2) + 5")) count=1 conv=notrunc &> /dev/null
		dd if=<(echo "2") of=./arena bs=1 seek=$(printf "%.0f" $(bc -l <<< "($COLUMNS - 4) * ($J2 + 3) + 5")) count=1 conv=notrunc &> /dev/null
		dd if=<(echo "2") of=./arena bs=1 seek=$(printf "%.0f" $(bc -l <<< "($COLUMNS - 4) * ($J2 + 4) + 5")) count=1 conv=notrunc &> /dev/null
		dd if=<(echo "2") of=./arena bs=1 seek=$(printf "%.0f" $(bc -l <<< "($COLUMNS - 4) * ($J2 + 5) + 5")) count=1 conv=notrunc &> /dev/null
	fi
	dd if=<(echo "o") of=./arena bs=1 seek=$(bc -l <<< "($COLUMNS - 4) * $BALL_X + $BALL_Y") count=1 conv=notrunc &> /dev/null

	clear
	cat arena
}

# Calculate the ball movements
game_loop() {
	while [ -f game.data ]
	do
		read_ball_coords
		read_player_coords
		display
		update_ball_coords
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
	echo "time:$(date +%s%N)" >> game.data
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
				J1=$(grep -E "^$name:" game.data | cut -d':' -f2)
				J1=$(expr $J1 + 80)
				sed -i "s/^$name.*$/$name:$J1/g" game.data
				echo "down"
				;;
			"w")
				J1=$(grep -E "^$name:" game.data | cut -d':' -f2)
				J1=$(expr $J1 - 80)
				sed -i "s/^$name.*$/$name:$J1/g" game.data
				echo "up"
				;;
		esac
	done
}

# Receives the server informations and edit the game.data file to guide the display process
handle_output() {
	while [ -f game.data ]
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
				sed -i "s/^pos.*/$line/g" game.data
				;;
			"mov:"*)
				sed -i "s/^mov.*/$line/g" game.data
				;;
			"opponent:"*)
				opponent=$(echo $line | cut -d':' -f2)
				echo "opponent:450:0" >> game.data
				;;
			"youare:"*)
				if [ $(echo $opponent | cut -d':' -f2) == 1 ]
				then
					sed -i "s/^$name:.*/$name:450:100/g" game.data
					sed -i "s/opponent:.*/opponent:450:900/g" game.data
				else
					sed -i "s/^$name:.*/$name:450:900/g" game.data
					sed -i "s/opponent:.*/opponent:450:100/g" game.data
				fi
				;;
			"$opponent:"*)
					line=sed "s/$opponent/opponent/g" line
					sed -i "s/^opponent:.*/$line/g" game.data
				;;
			"$name:"*)
					sed -i "s/^$name:.*/$line/g" game.data
				;;
			"winner:"*)
				rm game.data
				sleep 0.2
				echo "Winner is : " $(echo $line | cut -d':' -f2)
				;;
		esac
	done
}

if [ $# != 1 ]
then
	echo "./pong.sh <url>"
	exit 1
fi

# echo "POSIX ONE-OF-A-KIND NERDY GAME (P.O.N.G.) :"
# echo -n "Please type your name: "
# read -r name
name=CLI_PLAYER

init_game_data
handle_movement | (websocat -k $1 || rm game.data) | handle_output &> /dev/null &
PID=$!

sleep 0.1
if [ -f game.data ]
then
	game_loop
fi

rm arena
