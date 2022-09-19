#! /bin/sh

request_retart_signal() {
	return curl http://playr.biz/restart?player_id=$DEVICE_ID
}
confirm_restart=1
reboot() {
	system(shutdown --reboot now)
}

while true; do
	# first loop until chrome has started
	while [ $(ps aux | grep -ie "chrome" | wc -l) = 0 ];
	do
		if [ request_restart_signal() = confirm_restart ]; then
			reboot()
		fi
		sleep 30 # 30 seconds
	done

	sum_elapsed_time_chrome_processes=0
	previous_sum_elapsed_time_chrome_processes=0
	chrome_running=true
	while chrome_running
	do
		# check processor time consumed by chrome
		# check remote restart command

		# if chrome is no longer present, jump back to initial check (as chrome will be 
		# restarted automatically by Webconverger setup)
		if [ $(ps aux | grep -ie "chrome" | wc -l) = 0 ]; then
			chrome_running=false 
		else
			# check sum processor time spend on different chrome processes
			sum_elapsed_time_chrome_processes=`ps aux | grep -iE "chrome --type=" | awk 'BEGIN {sum=0}; {gsub(/:/,"",$10); sum+=$10} END {sum}'`;
			# ps aux | grep -ie "chrome.*type=render" | awk 'BEGIN {sum=0};{gsub(/:|\./,"",$10); sum+=$10} END{print sum}'


			# if time does not increase => chrome has frozen/crashed/aw snap showing
			# ==>> kill chrome main process
			# ==>> goto first loop
			if [ sum_elapsed_time_chrome_processes eq previous_sum_elapsed_time_chrome_processes ]; then
				chrome_main_process_id=$(ps aux | grep -iE "chrome.*--kiosk" | awk 'NR==1{print $2}')
				if [ chrome_main_process_id neq '' ]; then
					kill chrome_main_process_id
				fi
				sleep 5 # 5 seconds to wait for chrome to be killed
				chrome_running=false
			else
				# request remote restart signal

				# request did not result in result

				# result is negative => no restart

				# result is positive => reboot requested
				# ==>> shutdown and reboot Webconverger

				# wait for one minute
				sleep 60 # 1 minute
			fi

		fi
	done

done