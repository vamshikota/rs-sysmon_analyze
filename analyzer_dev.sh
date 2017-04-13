clear;
#set -e   

service=$1
arg1=$2
arg2=$3


## FUNCTIONS ##



## =======================================================================


green() {
echo -e "\e[32m$1\e[0m"
}

red() {
echo -e "\e[31m$1\e[0m"
}

yellow() {
echo -e "\e[93m$1\e[0m"
}

lines() {
for i in `seq $1`; do
	echo -n "="
done
echo
}


## =======================================================================
find_os() {
if [[ -a /etc/redhat-release ]]; then
        os=$(for i in $(cat /etc/redhat-release);
                do echo $i | tr "A-Z" "a-z" | awk '$1~ /^(centos|red|hat|[0-9])/';
                done | tr "\n" " " | sed 's/red\ hat/redhat/g');
else
        os=$(grep -i pretty_name /etc/*-release | cut -d= -f2 | sed 's/\"//g'| awk '{print $1,$2}'| tr "A-Z" "a-z");
fi;

#echo -e "\nOS: $os"

os_short() {
if [[ $os == ubuntu* ]]; then 
	os_short="ubuntu"
elif [[ $(echo $os|awk '{print $2}'|cut -d. -f1) -le 6 ]]; then 
	os_short="rhel6"
else 
	os_short="rhel7"
fi
}

os_short

}
## =======================================================================
server_info() {

cpu_count=$(grep -ic proc /proc/cpuinfo);
echo "No. of cpus $cpu_count"

memory=$(free -m | grep Mem | awk '{print $2, "MB"}';)
echo "Memory = $memory"

rpm -q psa 2>&1 > /dev/null

if [[ $? == 1 ]]; then
        plesk_installed="no"
else
        echo "Plesk Server"
        plesk_installed="yes"
        psa_version=$(rpm -q psa)
fi;
l;jlj

}
## =======================================================================

sysmon_recap() {

which rs-sysmon &> /dev/null

if [[ $(echo $?) == 0 ]]; then
	sysmon_installed="yes"
else
	sysmon_installed="no"
fi;


which recap &> /dev/null
if [[ $(echo $?) == 0 ]]; then
	recap_installed="yes"
else
	recap_installed="no"
fi;


if [[ $sysmon_installed == "yes" && $recap_installed == "yes" ]]; then
	sysmon_recap_both="yes"
elif [[ $sysmon_installed == "yes" && $recap_installed == "no" ]]; then
	sysmon_only="yes"
	using="sysmon"
elif [[ $sysmon_installed == "no" && $recap_installed == "yes" ]]; then
	recap_only="yes"
	using="recap"
fi



if [[ $sysmon_recap_both == "yes" ]]; then
	today=$(date +%Y-%m-%d); 
	recap_last_update=$(stat -c %y  $(ls -1tr /var/log/recap/  | tail -1)  | awk '{print $1}');
	sysmon_last_update=$(stat -c %y  $(ls -1tr /var/log/rs-sysmon/  | tail -1)  | awk '{print $1}');

	if [[ $today == $recap_last_update ]]; then
		recap_current="yes"
	else 
		recap_current="no"
	fi

        if [[ $today == $sysmon_last_update ]]; then
                sysmon_current="yes"
        else
                sysmon_current="no"
        fi

if [[ sysmon_current == "yes" && recap_current == "yes" ]]; then
        sysmon_recap_both_current="yes"
	echo "Interstingly, both rs-sysmon and recap are current."
	echo "Using recap.." 
	using="recap"
elif [[ sysmon_current == "yes" && recap_current == "no" ]]; then
        sysmon_current_only="yes"
	using="sysmon"
elif [[ sysmon_current == "no" && recap_current == "yes" ]]; then
        recap_current_only="yes"
	using="recap"
fi

	
fi	

	
}

## =======================================================================


find_os
echo $os
echo $os_short

green green
red red
yellow yellow

lines 30
server_info

sysmon_recap
echo test
echo $using



