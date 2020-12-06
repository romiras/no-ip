#!/bin/bash 

BASE64AUTH=""
HOSTNAME=""
LOGFILE=""
DETECTIP=""
IP=""
RESULT=""
INTERVAL=0
CONFIG=""

if [ -f "/etc/no-ip/no-ip.conf" ]
then
	CONFIG="/etc/no-ip/no-ip.conf"
fi

for i in "$@"
do
	case $i in
		-a=*|--auth=*)
		BASE64AUTH="${i#*=}"
		;;
		-l=*|--logfile=*)
		LOGFILE="${i#*=}"
		;;
		-h=*|--hostname=*)
		HOSTNAME="${i#*=}"
		;;
		-d=*|--detectip=*)
		DETECTIP="${i#*=}"
		;;
		-i=*|--ip=*)
		IP="${i#*=}"
		;;
		-n=*|--interval=*)
		INTERVAL="${i#*=}"
		;;
		-c=*|--config=*)
		CONFIG="${i#*=}"
		;;
		*)
		;;
	esac
done


if [ -n "$CONFIG" ] && [ -f "$CONFIG" ]
then
	while read line
	do 
		#echo $line	
		case $line in
			auth=*)
			BASE64AUTH="${line#*=}"
			;;
			logfile=*)
			LOGFILE="${line#*=}"
			;;
			hostname=*)
			HOSTNAME="${line#*=}"
			;;
			detectip=*)
			DETECTIP="${line#*=}"
			;;
			ip=*)
			IP="${line#*=}"
			;;
			interval=*)
			INTERVAL="${line#*=}"
			;;
			*)
			;;
		esac
	done < "$CONFIG"
else
	echo "Config file not found."
	exit 10
fi


if [ -z "$BASE64AUTH" ]
then
	echo "No auth was set. Use -a=auth"
	exit 10
fi


if [ -z "$HOSTNAME" ]
then
	echo "No host name. Use -h=host.example.com"
	exit 30
fi


if [ -n "$DETECTIP" ]
then
	IP=$(wget -qO- "http://myexternalip.com/raw")
fi


if [ -n "$DETECTIP" ] && [ -z $IP ]
then
	RESULT="Could not detect external IP."
fi


if [[ $INTERVAL != [0-9]* ]]
then
	echo "Interval is not an integer."
	exit 35
fi


USERAGENT="--user-agent=\"no-ip shell script/1.0 mail@mail.com\""
AUTHHEADER="--header=\"Authorization: $BASE64AUTH\""
AUTH=$(echo "$BASE64AUTH" | base64 -d)
NOIPURL="https://$AUTH@dynupdate.no-ip.com/nic/update"


if [ -n "$IP" ] || [ -n "$HOSTNAME" ]
then
	NOIPURL="$NOIPURL?"
fi

if [ -n "$HOSTNAME" ]
then
	NOIPURL="${NOIPURL}hostname=${HOSTNAME}"
fi

if [ -n "$IP" ]
then
	if [ -n "$HOSTNAME" ]
	then
		NOIPURL="$NOIPURL&"
	fi
	NOIPURL="${NOIPURL}myip=$IP"
fi


while :
do

	RESULT=$(wget -qO- $AUTHHEADER $USERAGENT $NOIPURL)

	if [ -z "$RESULT" ] && [ $? -ne 0 ]
	then
		echo "Problem updating NO-IP."
		case $? in
		1)
		  RESULT="General Error."
		  ;;
		2)
		  RESULT="General Error."
		  ;;
		3)
		  RESULT="File I/O Error"
		  ;;
		4)
		  RESULT="Network Failure"
		  ;;
		5)
		  RESULT="SSL Verfication Error"
		  ;;
		6)
		  RESULT="Authentication Failure"
		  ;;
		7)
		  RESULT="Protocol Error"
		  ;;
		8)
		  RESULT="Server issued an error response"
		  ;;
		esac
	fi 


	if  [ -n "$LOGFILE" ]  
	then
		if [ ! -f "$LOGFILE" ]
		then
			touch "$LOGFILE"
		fi
		DATE=$(date)
		echo "$DATE --  $RESULT" >> "$LOGFILE"
	fi

	if [ $INTERVAL -eq 0 ]
	then
		break
	else
		sleep "${INTERVAL}m" 
	fi

done

exit 0
