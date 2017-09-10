#!/bin/bash

scriptDir=$(cd "$(dirname "$0")"; pwd)
eapHome=/var/vcap/packages/eapcontroller
eapHome_logs=/var/vcap/sys/log/eapcontroller/
JRE_HOME=${eapHome}"/jre"
JAVA_TOOL=${JRE_HOME}/bin/java

ERROR=0

help() {
    echo "usage: $0 help"
    echo "       $0 (start|stop|status)"
    cat <<EOF

help       - this screen
start      - start the service(s)
stop       - stop  the service(s)
status     - show the status of the service(s)

EOF
}

# return: 0,running; 1, not running;
is_running_expired() {
    ps -U root -u root u | grep eap | grep -v grep >/dev/null
    eap_running=$?
    if [ $eap_running -ne 0 ]; then
	    return 1
    fi

    ps -U root -u root u | grep mongod |grep -v grep >/dev/null
    mongod_running=$?
    if [ $mongod_running -ne 0 ]; then
	    return 1
    fi

    return 0
}


# ---------------os detect----------------------------
OS_CENTOS="centos"
OS_REDHAT="redhat"
OS_FEDORA="fedora"
OS_UBUNTU="ubuntu"

PORTT_TOOL="${eapHome}/bin/portt"

#---------------------------------------------------

# return: 1,running; 0, not running;
is_running() {

	${PORTT_TOOL} 127.0.0.1 8088 500

	is_disconnected=$?
    if [ $is_disconnected == 0 ]; then
	    return 1
    fi
    return 0
}


start() {
    is_running
    if  [ 1 == $? ]; then
	    echo "EAP Controller is already running."
	    exit
    fi

    echo -n "Starting EAP Controller "

	if [ ! -e ${eapHome_logs} ]; then
        mkdir ${eapHome_logs}
    fi

    nohup $JAVA_TOOL -server -Xms128m -Xmx1024m -XX:MaxHeapFreeRatio=60 -XX:MinHeapFreeRatio=30 -XX:+UseSerialGC -XX:+HeapDumpOnOutOfMemoryError -Deap.home="${eapHome}" -cp ${eapHome}"/lib/com.tp-link.eap.start-0.0.1-SNAPSHOT.jar:"${eapHome}"/lib/*:"${eapHome}"/external-lib/*" com.tp_link.eap.start.EapMain start > ${eapHome_logs}/startup.log 2>&1 &
    ERROR=$?
    count=0

    while true
    do
        is_running
        if  [ 1 == $? ]; then
            break
        else
            sleep 1
            echo -n "."
            count=`expr $count + 1`
            if [ $count -gt 120 ]; then
                break
            fi
        fi
    done

    echo "."

    is_running
    if  [ 1 == $? ]; then
        echo "Start successfully."
        echo "You can browse URL http://127.0.0.1:8088 for more."
    else
        echo "Start failed."
    fi
}

stop() {
    is_running
    if  [ 0 == $? ]; then
	    echo "EAP Controller not running."
	    exit
    fi

    echo -n "Stopping EAP Controller "
    $JAVA_TOOL -Deap.home="${eapHome}" -cp ${eapHome}"/lib/com.tp-link.eap.start-0.0.1-SNAPSHOT.jar:"${eapHome}"/lib/*:"${eapHome}"/external-lib/*" com.tp_link.eap.start.EapMain stop > ${eapHome_logs}/stop.log 2>&1 &
    ERROR=$?

    count=0

    while true
    do
        is_running
        if  [ 0 == $? ]; then
            break
        else
            sleep 1
            count=`expr $count + 1`
            echo -n "."
            if [ $count -gt 30 ]; then
                break
            fi
        fi
    done

    echo ""

    is_running
    if  [ 0 == $? ]; then
        echo "Stop successfully."
    else
        echo "Stop failed. Try again."
    fi
}

status() {
    is_running 
    if  [ 0 == $? ]; then
	    echo "EAP Controller not running."
    else
	    echo "EAP Controller is running."
    fi
}

# parameter check
if [ $# != 1 ]
then 
    help
    exit
elif [[ $1 != "start" && $1 != "stop" && $1 != "status" ]]
then 
    help
    exit
fi

# root permission check
ROOT_UID=0
if [ $UID != ${ROOT_UID} ]
then
   echo "The script need root permission. Exit."
   exit
fi



if [ $1 == "start" ]; then
    start
elif [ $1 == "stop" ]; then
    stop
elif [ $1 == "status" ]; then
    status
fi

if [ $ERROR -gt 0 ]; then
    exit $ERROR
fi
