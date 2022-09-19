#! /bin/bash

# NOTE: Do not change the name of this script to involve the name in browser_name
# since pkill is used to kill all threads/processes of this browser using that name
# using the same name in the name of this script will end this script as well.
# TODO: Make killing of the browser more precise.
# TODO: Include measure of network traffic in the decision to restart browser
# NOTE: Having the name of the browser in the name of this script also makes that the greps on
# the results of ps or top need to exclude this script.
# This can be done by adding a more precise resular expression,
# if this script is called chrome_watchdog.sh the expression to use
# is: grep -ie "[c]hrome[^_]"

# Server settings
server_url=${browser_watchdog_server_url:-"http://ajax.playr.biz/watchdogs/$webc_id/command"}
return_value_restart=${browser_watchdog_return_value_restart:-1}
return_value_no_restart=${browser_watchdog_return_value_no_restart:-0}

# Cycle time for the status of the browser, default 1 minute
cycle_time=${browser_watchdog_cycle_time:-60} # in seconds
# Cycle time for machine reboot check as a factor of the cycle time
# of the browser check. Default 5 (once every 5 minutes) to keep server load low
reboot_check_cycle_factor=${browser_watchdog_reboot_check_cycle_factor:-5}
browser_name=${browser_watchdog_browser_name:-"chrome"}
# Use [x]yz instead of xyz to prevent incuding the grep process
# see http://unix.stackexchange.com/questions/74185/how-can-i-prevent-grep-from-showing-up-in-ps-results
browser_process_name="[${browser_name:0:1}]${browser_name:1}"
main_process_cpu_delta=${browser_watchdog_main_process_cpu_delta:-5} # in 1/100th of a second
other_processes_cpu_delta=${browser_watchdog_other_processes_cpu_delta:-5} # in 1/100th of a second
short_cycle_time=30 # in seconds
short_time=10 # in seconds
one_minute=60 # in seconds
five_minutes=300 # in seconds
script_name=$(basename $0)
script_process_name="[${script_name:0:1}]${script_name:1}"
browser_is_running=1
browser_is_not_running=0
log_file_name=${browser_watchdog_log_file_name:-"/home/webc/.browser_watchdog.log"}
# log_file_name="./browser_watchdog.log"

# Function that checks a server for a restart signal
# by doing a http GET request to the server_url.
# The result from the get request is stripped of spaces
# and checked for being an integer value and then returned.
# If the result of the request is empty or not an integer value
# return_value_no_restart is returned to minimize the risk of an
# unintended restart of Webconverger
request_restart_signal() {
	# local result="$(curl --silent --verbose "$server_url" >> $log_file_name 2>&1)"
	local result="$(curl --silent "$server_url")"
	local result_without_spaces=${result// }
	#printf "|$result|$result_without_spaces|" >> $log_file_name
	if [[ -z $result_without_spaces ]]; then
		#printf "$return_value_no_restart(1)>" >> $log_file_name
		echo $return_value_no_restart
	elif [[ "$result_without_spaces" =~ ^[0-9]+$ ]]; then
		#printf "$result_without_spaces(2)>" >> $log_file_name
		echo $result_without_spaces
	else
		#printf "$return_value_no_restart(3)>" >> $log_file_name
		echo $return_value_no_restart
	fi
}
# Get a list of processes associated with the browser;
# sort on ascending PID, and remove processes that start the browser (from a bash process)
all_browser_processes='ps x -o pid,cmd --sort +pid | grep -ie $browser_process_name | grep -vie "bash"'
nr_browser_processes() {
	echo $(eval "$all_browser_processes" | wc -l)
}
browser_processes_present() {
	ps x -o pid,cmd --sort +pid | grep -ie $browser_process_name | grep -vie "bash" > /dev/null
}
browser_main_pid() {
	# the main browser process is the one with the smallest PID, it launches the other processes that
	# therefore have greater PIDs
	# NOTE: the PID numbering can restart after it reaches 32768 so we should take the PID that is started last
	#      in order to do that the start_time should be added as an output column. That will have the
	#      time or date the process was started:
	#      Only the year will be displayed if the process was not started the same year ps was invoked, or
	#      "MmmDD" if it was not started the same day, or "HH:MM" otherwise.
	# since the browser is started from a bash script we have to exclude that process since it will be
	# included if we grep only for the browser name
	# echo $(ps x -o pid,cmd | grep -ie $browser_process_name | grep -vie "bash" | awk 'BEGIN {pid=0}; {pid = (pid == 0 ? $1 : ($1 < pid ? $1 : pid)) } END {print pid}')
	echo $(eval "$all_browser_processes" | awk 'NR==1{print $1}')
}
all_browser_pids() {
	echo $(eval "$all_browser_processes" | awk '{print $1}')
}
all_browser_pids_except_main() {
	echo $(eval "$all_browser_processes" | awk 'NR>1{print $1}')
}
# Get system defined number of clock ticks per second
clock_ticks_per_second() {
	getconf CLK_TCK
}
# CPU total time used by a PID defined as the sum of
# utime (time that has been scheduled in user mode) and
# stime (time that has been scheduled in kernel mode)
# in clock ticks (see man proc)
# assumed are 100 ticks per second, ie time in hundreths of a second
precise_cpu_time_for_pid() {
	cat /proc/$1/stat | awk '{ print (( $14 + $15 )) }'
}
sum_cpu_time() {
	sum=0
	for item in "$@"; do
		sum=$(( sum + $(precise_cpu_time_for_pid ${item// }) ))
	done
	echo $sum
}
sum_cpu_time_over_all_browser_processes() {
	echo $(sum_cpu_time $(all_browser_pids))
}
cpu_time_main_browser_process() {
	echo $(sum_cpu_time $(browser_main_pid))
}
sum_cpu_time_over_all_browser_processes_except_main() {
	echo $(sum_cpu_time $(all_browser_pids_except_main))
}
# reboot the computer
reboot_machine() {
	printf "\nREBOOT at $(date)\n" >> $log_file_name
	sync
	sudo shutdown --reboot now
}

# The responsibility of making sure that this script is only
# running once is presumed to be delegated to the calling script.
# The best way to do this in this script is probably by creating
# a "mutex" directory since that is an atomic operation in Linux/*nix
# see: http://unix.stackexchange.com/questions/48505/how-to-make-sure-only-one-instance-of-a-bash-script-runs
# The below manner is a simpler way that should be sufficient.
# Exit value 0 is used becasue we do not want to upset the calling script,
# since that also controls starting the browser.
# [[ $(ps x | grep -ie "[b]rowser_watchdog.sh" | wc -l) > 2 ]] && printf "\nEXIT on ps\n" >> $log_file_name && sync && exit 0
# [[ $(lsof | grep -ie "[b]rowser_watchdog.sh" | wc -l) > 1 ]] && printf "\nEXIT on lsof\n" >> $log_file_name && sync && exit 0

printf "\nStart browser_watchdog at: $(date) \n" >> $log_file_name
printf "Name of this script      : $script_name\n" >> $log_file_name
printf "Script process name      : $script_process_name\n" >> $log_file_name
printf "browser_name             : $browser_name \n" >> $log_file_name
printf "browser_process_name     : $browser_process_name \n" >> $log_file_name
printf "webc_id                  : $webc_id \n" >> $log_file_name
printf "cycle_time               : $cycle_time \n" >> $log_file_name
printf "short_cycle_time         : $short_cycle_time \n" >> $log_file_name
printf "short_time               : $short_time \n" >> $log_file_name
printf "reboot_check_cycle_factor: $reboot_check_cycle_factor \n" >> $log_file_name
printf "server_url               : $server_url \n" >> $log_file_name
printf "return_value_restart     : $return_value_restart \n" >> $log_file_name
printf "return_value_no_restart  : $return_value_no_restart \n" >> $log_file_name
printf "main_process_cpu_delta   : $main_process_cpu_delta \n" >> $log_file_name
printf "other_processes_cpu_delta: $other_processes_cpu_delta \n" >> $log_file_name
printf "====================================================================================\n" >> $log_file_name

# Wait for five minutes to allow the browser to start up properly
# When a browser starts up it is waiting for network connections
# and therefore does not use a lot of CPU, it might trigger reboot.
# Another point is that in most cases it is best if the browser
# connects to the backend first before this script does to enable
# the backend to properly initiate the necessary context.
#printf "initial wait " >> $log_file_name
sleep $five_minutes

restart_check_index=0
cpu_time_main_browser_process=0
sum_cpu_time_other_browser_processes=0
previous_cpu_time_main_browser_process=0
previous_sum_cpu_time_other_browser_processes=0
browser_state=$(browser_processes_present)
while true; do
	#printf "browser state:$browser_state " >> $log_file_name
	if [ "$browser_state" -eq "$browser_is_not_running" ]; then
		#printf "-" >> $log_file_name
		if ["restart_check_index" -lt "$reboot_check_cycle_factor" ]; then
			((restart_check_index+=1))
		else
			restart_check_index=0
			if [ "$(request_restart_signal)" -eq "$return_value_restart" ]; then
				$(reboot_machine)
			#else
				#printf "<no reboot>" >> $log_file_name
			fi
		fi
		sleep $cycle_time
		cpu_time_main_browser_process=0
		sum_cpu_time_other_browser_processes=0
		previous_cpu_time_main_browser_process=0
		previous_sum_cpu_time_other_browser_processes=0
		browser_state=$(browser_processes_present)
	else
		#printf "+" >> $log_file_name
		# Check processor time spend on different browser processes.
		browser_main_process_id=$(browser_main_pid)
		cpu_time_main_browser_process=$(cpu_time_main_browser_process)
		sum_cpu_time_other_browser_processes=$(sum_cpu_time_over_all_browser_processes_except_main)
		#printf "$browser_main_process_id," >> $log_file_name

		# If the browser crashes and gets restarted not initiated by this script the
		# current cpu times can become lower than the previous values, in that case reset
		# previous values to 0.
		if [ $cpu_time_main_browser_process -lt $previous_cpu_time_main_browser_process ]; then
			previous_cpu_time_main_browser_process=0
		fi
		if [ $sum_cpu_time_other_browser_processes -lt $previous_sum_cpu_time_other_browser_processes ]; then
			previous_sum_cpu_time_other_browser_processes=0
		fi

		# From measurments on Webconverger after ONE MINUTE CLOCK TIME
		# (not cpu/system time) using the Chrome browser on an Intel 5th gen i5
		# (please note; that is why the default value of the cycle_time is 60 seconds,
		# please take this into consideration when altering cycle_time):
		# * When Chrome shows the "Aw snap" message
		# 	the CPU-time (user and kernel summed) of the main Chrome process has not increased
		# 	more than 0.1 second and the sum over the other Chrome processes has increased
		# 	even less than 0.1 second.
		# * When Chrome showed a frozen video (no error message) in one case in one minute
		#   the main process was max. 0.4 seconds CPU-time (user and kernel summed) and
		#   the rest of the processes were between 0.8 an just over 1 second
		#   a second time when a video froze
		#   the CPU-time (user and kernel summed) of the main process was max.
		#   0.4 seconds and the rest of the processes were around 1.2 seconds
		# * When a slow and light playlist is running on an Intel 5th gen i5
		# 	the CPU-time of the main Chrome process has increased about 5 seconds and
		# 	the other Chrome processes has increased about 1-2 seconds.
		# * When however the playlist (running on an Intel 5th gen i5)
		# 	has a page transition every 1 minute and only one page
		#   the CPU-time of the main Chrome process only increases about 5/100th of a second
		# 	the other Chrome processes about the same.
		# * When a heavy playlist is running the main and other Chrome processes will increase
		# 	more than in the case of the light playlist.
		# * To make sure no unwanted restarts are triggered the CPU times of the lightest
		#   playlists are used
		# * When the browser starts up it takes some time before it starts to measurably
		# 	consume CPU cycles, do not restart browser until it has consumed at least
		# 	a second of CPU time.
		# TODO: currenlty it is assumed that the the number of clock ticks per second is 100
		#       using the clock_ticks_per_second this shoudl be verified/corrected if need be
		if [ $(( $cpu_time_main_browser_process - $previous_cpu_time_main_browser_process )) -lt $main_process_cpu_delta ] && [ $(( $sum_cpu_time_other_browser_processes - $previous_sum_cpu_time_other_browser_processes )) -lt $other_processes_cpu_delta ] && [ $cpu_time_main_browser_process -gt 100 ]; then
			printf "\nKilling $browser_name at $(date)" >> $log_file_name
			printf "\nmain PID $(browser_main_pid)" >> $log_file_name
			printf "\ncpu_time_main_browser_process: $cpu_time_main_browser_process" >> $log_file_name
			printf "\nprevious_cpu_time_main_browser_process: $previous_cpu_time_main_browser_process" >> $log_file_name
			printf "\ndelta: $(($cpu_time_main_browser_process - $previous_cpu_time_main_browser_process))" >> $log_file_name
			printf "\nsum_cpu_time_other_browser_processes: $sum_cpu_time_other_browser_processes" >> $log_file_name
			printf "\nprevious_sum_cpu_time_other_browser_processes: $previous_sum_cpu_time_other_browser_processes" >> $log_file_name
			printf "\ndelta: $(($sum_cpu_time_other_browser_processes - $previous_sum_cpu_time_other_browser_processes)) \n" >> $log_file_name
			printf "====================================================================================\n" >> $log_file_name
			sync
			# Here pkill is used instead of killing the main browser PID because
			# that sometimes does not kill all processes leaving ghost processes running.
			# This interferes with the function that finds the browser main pid.
			pkill -9 $browser_name
			sleep $short_time
			# Jump back to initial loop (as browser will be
			# restarted automatically by Webconverger setup).
			browser_state=$browser_is_not_running
			# since this branch takes only short_time instead of cycle time
			# it is not counted against the reboot_check_cycle_factor
			# ((restart_check_index+=1))
		else
			#printf "CPU main process:$(cpu_time_main_browser_process" >> $log_file_name
			#printf ",top:$cpu_time_main_browser_process,$sum_cpu_time_other_browser_processes" >> $log_file_name
			#printf ",CPU all processes: $(sum_cpu_time_over_all_browser_processes)" >> $log_file_name
			# request remote restart signal

			if ["restart_check_index" -lt "$reboot_check_cycle_factor" ]; then
				((restart_check_index+=1))
			else
				restart_check_index=0
				if [ "$(request_restart_signal)" -eq "$return_value_restart" ]; then
					$(reboot_machine)
				#else
					#printf "<no reboot>" >> $log_file_name
				fi
			fi
			sleep $cycle_time
			browser_state=$(browser_processes_present)
		fi
		previous_cpu_time_main_browser_process=$cpu_time_main_browser_process
		previous_sum_cpu_time_other_browser_processes=$sum_cpu_time_other_browser_processes
	fi
done
