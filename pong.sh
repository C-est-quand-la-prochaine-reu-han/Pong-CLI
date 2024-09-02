#i!/bin/sh

BALL_X=$(expr $(expr $(tput lines) - 5) / 2)
BALL_Y=$(expr $(expr $(tput cols) - 5) / 2)

# Builds and display the pong arena
# Requires BALL_X and BALL_Y to exists
# Creates a string filled with the pong arena, and prints it on the screen at the end of the loop
display() {
	PONG_ARENA=""

	LINES=$(expr $(tput lines) - 5)
	COLS=$(expr $(tput cols) - 5)

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
}

get_ball_position() {
	exec 3< game.data
	read ball_position <&3
	read ball_movement <&3
	read p1_position <&3
	read p2_position <&3
	BALL_X=$(cut -d':' -f 2 <(echo $ball_position))
	BALL_Y=$(cut -d':' -f 3 <(echo $ball_position))
	exec 3<&-
}

game_loop() {
	while [ 1 = 1 ]
	do
		get_ball_position
		display
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
# Handle user inputs and translate them for the websocket
# W -> up
# S -> down
function init {
	if [ $# != 2 ]
	then
		echo "./pong.sh <host> <port>"
		exit 1
	fi
	echo "pos:450:450" > game.data
	echo "mov:7:1" >> game.data
	echo "j1:450:100" >> game.data
	echo "j2:450:900" >> game.data
	echo "cli_player"
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

handle_output() {
	while [ 1 = 1 ]
	do
		read -r line
		if [ -z "$line" ]
		then
			continue
		fi
		echo $line
		case $line in
			"")
				continue
				;;
			"pos"*)
				sed -i "s/^pos.*/$line/g" game.data
				;;
		esac
	done
}

touch game.data
init $1 $2 | websocat ws://$1:$2 | handle_output &
game_loop
rm game.data
