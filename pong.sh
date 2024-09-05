#!/bin/sh

BALL_X=$(expr $(expr $(tput lines) - 5) / 2)
BALL_Y=$(expr $(expr $(tput cols) - 5) / 2)

update_ball_coords() {

	COORDS=$(grep -E '^pos:' game.data)
	BALL_X=$(expr $(cut -d':' <(echo $COORDS) -f2) '*' $LINES / 1000)
	BALL_Y=$(expr $(cut -d':' <(echo $COORDS) -f3) '*' $COLUMNS / 1000)
}

# Builds and display the pong arena
# Requires BALL_X and BALL_Y to exists
# Creates a string filled with the pong arena, and prints it on the screen at the end of the loop
display() {
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

# Read informations from the game.data file
# get_ball_position() {
# 	exec 3< game.data
# 	read ball_position <&3
# 	sed -i "s/^pos.*/$ball_position/g" game.data
# 	read ball_movement <&3
# 	sed -i "s/^mov.*/$ball_movement/g" game.data
# 	read p1_position <&3
# 	sed -i "s/^j1.*/$p1_position/g" game.data
# 	read p2_position <&3
# 	sed -i "s/^mov.*/$p2_position/g" game.data
# 	exec 3<&-
# }

game_loop() {
	while [ 1 = 1 ]
	do
		LINES=$(expr $(tput lines) - 5)
		COLUMNS=$(expr $(tput cols) - 5)
		update_ball_coords $LINES $COLS
		display
		sleep 0.0166
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
# Handle user inputs and translate them for the websocket
# w -> up
# s -> down
function init {
	echo "pos:450:450" > game.data
	echo "mov:7:1" >> game.data
	echo "j1:450:100" >> game.data
	echo "j2:450:900" >> game.data
	echo "$name"
	rm -f input.log
	while [ 1 = 1 ]
	do
		readc input
		echo "$(date +%::z) : $input" >> input.log

		case $input in
			"s")
				echo "sending down..." >> input.log
				echo "down"
				;;
			"w")
				echo "sending up..." >> input.log
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
			"pos"*)
				sed -i "s/^pos.*/$line/g" game.data
				;;
			"winner"*)
				exit 0
				;;
		esac
	done
}

if [ $# != 2 ]
then
	echo "./pong.sh <host> <port>"
	exit 1
fi

echo "POSIX ONE-OF-A-KIND NERDY GAME (P.O.N.G.) :"
echo -n "Please type your name: "
read -r name

touch game.data

init $1 $2 | websocat ws://$1:$2 | handle_output &
PID=$!

game_loop

kill $PID

rm game.data
