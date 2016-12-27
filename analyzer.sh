clear; 

### Is rs-sysmon installed ?
echo "Checking if rs-sysmon is installed..."; 

if [ $(which rs-sysmon) ]; 
	then 
		echo -e "rs-sysmon is installed.\nProceeding.. "; 
	else 
		echo "rs-sysmon is not installed"; 
		exit 0; 
fi; 



### proceeding if installed.. copy logs
echo -n "ticket_no: "; read t; 
mkdir /home/rack/$t; 
echo "Copying files.. please bare with me... "; 
cp -ar /var/log/rs-sysmon /home/rack/$t; 
cd  /home/rack/$t/rs-sysmon; 
clear; echo -e "Done.";  

### Server Config ###
echo -e "\nServer Configuration: \nDisk space Status :"; 
df -h /; 
echo -e "\n"Processors -- `grep proc  /proc/cpuinfo | wc -l`;  
echo -e Memory "\t  " -- `free -m | grep Mem | awk '{print $2, "MB"}'` ;   


### rs-sysmon config
echo -e "\nrs-sysmon Configuration:"; 
cat /etc/rs-sysmon  | egrep -i 'rotate|status|mysql' | grep -v ^#; 
echo "logging every --- `grep -v ^# /etc/cron.d/rs-sysmon | grep "*" | awk '{print $1}' | cut -d \/ -f2` minutes"; 	
echo -e "\nI have copied rs-sysmon logs to the path  /home/rack/$t/rs-sysmon. From the recent logs I see :"; 

### Log Analysis Start
echo -e "\nServer Load: \n============"; 
for i in resources.log.{1..30}; 
	do 
		echo $i -- `head -1 $i` -- `grep "load average" $i | awk '{print ($(NF-4),$(NF-3),$(NF-2),$(NF-1),$(NF-0))}'`; 
	done; 

### Detect Webserver
echo -e "\n\n";ws=`netstat -ntlp | awk '$4~/:80$/' | awk '{split($(NF-0),a,"/");print a[2] }'|uniq`;  
echo -e "$ws is running on port 80 \n\n";  
if [[ $ws == "httpd" ]] || [[ $ws == "httpd.worker" ]]; 
	then 
		echo -e "\nCurrent Apache Config/Status: \n`
		for i in {1..30}; 
			do 
				echo -n "="; 
			done;`
		\n" 
		`ps -H h -ylC httpd | perl -lane '$s+=$F[7];$i++;END{printf"Avg %mem / Apache process = %.1fMB\n",$s/$i/1024}' ` 
		"\n" 
		`grep -i maxclients /etc/httpd/conf/httpd.conf | grep -v ^# | head -1 | awk '{print $1, "is set to --", $2}' ` 

### Current connections
		"\n\nCurrent connections :"; 
		pstree -G | grep http; 
		echo -e  "\n\nIPs conneting now :\n"; 
		netstat -ant | grep \:80 | egrep "ESTABLISHED|SYN_RECV" | awk '{ print $5 }' | sed -e 's/\:\:ffff\://g' | awk -F: '{print $1}' | sort | uniq -c | sort -nr |awk '{print $1 " "$2}' | head; 
		echo -e "\nErrors from apache logs: \n";  
		grep -i maxclients /var/log/httpd/error_log;
		fs=`grep -i fullstatus /etc/rs-sysmon | grep -v ^# | cut -d "=" -f2 | awk '{print $1}'`;
		
		if [ $fs == "no" ]; 
			then 
				echo -e "\n\nApache fullstatus is not being recorded. \nSuggest to enable it in /etc/rs-sysmon"; 
			else 
				echo -e "\nApache Analysis  :"; 
				echo -e "\t Time \t\t Threads CPU% \t Mem % \t File"; 
				for i in `seq 30`; 
					do 
						head -1 resources.log.$i | tr "\n" " "; 
						grep currently resources.log.$i | awk '{print "\t", $1}' | tr "\n" " " ;
						grep http ps.log.$i | awk '{ sum += $3 } END {print "\t", sum }'| tr "\n" " " ;
						grep http ps.log.$i | awk '{ sum += $4 } END {print "\t", sum }' | tr "\n" " "; 
						echo -e "\t resources.log.$i";
					done; 
				echo -e "\nMost visited Sites :" ; 
				egrep 'GET|POST' resources.log.{1..30} |awk '{print $12}' | sort | uniq -c | sort -rn| head; 
				echo -e "\nLocations visited the most : " ; 
				egrep 'GET|POST' resources.log.{1..30} |awk '{print $12,$13,$14}' | sort | uniq -c | sort -rn | head ; 
				echo -e "\nIPs that are hitting the most: "; 
				tf_ip=`mktemp`; 
				egrep 'GET|POST' resources.log.{1..30} |awk '{print $11}' | sort | uniq -c | sort -nr | head > $tf_ip; 
				cat $tf_ip; echo -e "\nIP Analysis"; 

				for i in `cat $tf_ip | awk '{print $2}'`; 
					do 
						echo -e $i "\t"---"\t" `whois $i | grep -i country | head -1`  "\t"---"\t" `whois $i | grep -i netname `; 
					done; 
		fi; 
	rm -rf $tf_ip;
	elif [[ $ws == "nginx" ]];  
		then 
			curl -s nginxctl.rax.io | python - -S; 
			echo "nginx listening on :"; 
			netstat -ntlp | grep nginx | awk '{print $4}' ;  
			echo -e "\nNginx Log files:\n"; 
			ls -ltrh $(lsof -u `grep -i ^user /etc/nginx/nginx.conf  | awk '{print $2}' | cut -d ";" -f1` | grep log$ | awk '{print $(NF-0)}' | sort | uniq); 
	elif  [[ $ws == "varnishd" ]]; 
		then 
			echo "$ws is on port 80"; 
			vconf=`grep -i ^VARNISH_VCL_CONF /etc/sysconfig/varnish  | grep -v ^# | cut -d "=" -f2`; 
			echo "Varnish config file(s) is(are) :" $vconf; 
			echo -e "\n\nLoking at config file :"; 
			host_count=$(grep -i .host $vconf | grep -v "#" | wc -l); 

			if [[ $host_count -gt 1 ]]; 
				then 
					echo "Varnishi has multiple backends ($host_count); Take a look at $vconf"; 
				else 
					echo "Backend is : " `grep -i .host $vconf -c| grep -v "#"` ;
			fi; 
	fi; 


### http count from ps.log
echo -e "\nHTTP Count from Ps.log files :"; 
for lining in `seq 30`; 
	do 
		echo -n "="; 
	done; 

echo "";
for i in ps.log.{1..30}; 
	do 
		echo -e `head -1 $i` "\t---\t" $i "\t---\t" `grep http $i|wc -l`; 
	done; 

### http status from netstat.log
echo -e "\nHTTP connection status from netstat logs:"; 

for lining in `seq 40`; 
	do echo -n "="; 
	done; 

echo ""; echo -e TIME "\t\t\t" FILE "\t\t\t" SYN_RECV "\t"TIME_WAIT "\t" CLOSE_WAIT "\t"ESTABLISHED; 
for i in netstat.log.{1..30}; 
	do echo -e `head -1 $i` "\t" $i"\t\t" `grep -i SYN_RECV $i |wc -l` "\t\t" `grep -i time_wait $i |wc -l` "\t\t" `grep -i close_wait $i |wc -l` "\t\t" `grep -i ESTABLISHED $i |wc -l`; 
	done;

db_temp=$(rpm -qa| egrep -i 'mysql-server|mysql[0-9][0-9]u-server|mariadb-server|mariadb[0-9][0-9][0-9]u-server|percona-server-server ' | tail -1);


##### is mysql installed running  ??? 
if `ps auxf | grep mysqld | grep -v grep > /dev/null `; 
	then 
		pkg=$(rpm -qf $(ps auxf | grep mysqld | grep -vE 'grep|safe' | awk '{print $12}') | tail -1); 
		echo -e "\n\n$pkg \n------ is installed and running"; 
		setto=$(chkconfig --list $(rpm -ql $pkg | grep init.d | awk -F "/" '{print $(NF-0)}')); 
		setto_st=$(echo $setto | awk '{print $5}' |cut -d ":" -f2); 
		if [ $setto_st == "on" ]; 
			then 
				echo -e "\nAnd is set to on"; 
			else echo "\nAnd is not set to on"; 
		fi; 
	echo $setto | column -t; 
	echo -e "\nMySQL configuration : "; 
	mysql -Nse "show variables like 'max_connections'" | awk '{print $1,"\t--\t",$2}'; 
	mysql -Nse "show status like 'max_used%'"| awk '{print $1,"\t--\t",$2}'; 
	echo -e "Mysql Uptime  \t\t--\t" `mysqladmin stat | awk '{print $2/60/60, "Hours"}' `;
elif [ ! -z "$db_temp" ]; 
	then 
		echo -e "\n\n" $db_temp "\n------> is insalled but not running."; 
else 
	echo  -e "\n\nMysql/Mariadb/Percona none of the database is even installed" ;
fi;

a=`grep -i mysqlprocesslist /etc/rs-sysmon | cut -d = -f2`; b="yes";  
if [ "$a" == "$b" ]; 
	then 
		echo -e  "\nMysql Analysis :";  
		echo -e "\t Time \t\t Threads CPU% \t Mem %\t File"; 
		for i in `seq 30`; 
			do 
				head -1 mysql.log.$i | tr "\n" " "; 
				grep -i uptime mysql.log.$i |  awk '{print "\t",$4}' | tr "\n" " " ;
				grep mysql ps.log.$i | awk '{ sum += $3 } END {print "\t", sum }'| tr "\n" " " ;
				grep mysql ps.log.$i | awk '{ sum += $4 } END {print "\t", sum }'| tr "\n" " "; 
				echo -e "\t mysql.log.$i"; 
			done; 

else 
	echo -e "\nAt the moment rs-sysmon is not logging mysql : \n`grep -i mysqlprocesslist /etc/rs-sysmon`"; 
fi; 

