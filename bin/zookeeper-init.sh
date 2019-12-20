#!/bin/bash
#
#  Init script for Zookeeper
#
#  Timothy C. Arland <tcarland@gmail.com>
#

# ----------- preamble
HADOOP_ENV="tdh-env-user.sh"
HADOOP_ENV_PATH="/opt/TDH/etc"

if [ -r "./etc/$HADOOP_ENV" ]; then
    . ./etc/$HADOOP_ENV
    HADOOP_ENV_PATH="./etc"
elif [ -r "/etc/hadoop/$HADOOP_ENV" ]; then
    . /etc/hadoop/$HADOOP_ENV
    HADOOP_ENV_PATH="/etc/hadoop"
elif [ -r "${HADOOP_ENV_PATH}/${HADOOP_ENV}" ]; then
    . $HADOOP_ENV_PATH/$HADOOP_ENV
fi

if [ -z "$TDH_VERSION" ]; then
    echo "Fatal! Unable to locate TDH Environment '$HADOOP_ENV'"
    exit 1
fi
# -----------

if [ -z "$ZOOKEEPER_HOME" ]; then
    echo "Error! ZOOKEEPER_HOME is not set. Check your hadoop env."
    exit 1
fi

HOST=$(hostname -s)
ZK_VER=$(readlink $ZOOKEEPER_HOME)
ZK_CONFIG="${ZOOKEEPER_HOME}/conf/masters"
ZK_ID="server.quorum"

# -----------

usage()
{
    echo "$TDH_PNAME {start|stop|status}"
    echo "  TDH Version: $TDH_VERSION"
}


show_status()
{
    local rt=0

    for zk in $(cat ${ZK_CONFIG}); do
        check_remote_process $zk $ZK_ID
        rt=$?

        if [ $rt -eq 0 ]; then
            echo -e " Zookeeper              | \e[32m\e[1m OK \e[0m | [${zk}:${PID}]"
        else
            echo -e " Zookeeper              | \e[31m\e[1mDEAD\e[0m | [${zk}]"
        fi
    done

    return $rt
}


# =================
#  MAIN
# =================


ACTION="$1"
rt=0
IFS=$'\n'

if ! [ -e ${ZK_CONFIG} ]; then
    echo "Error locating Zookeeper host config: '${ZK_CONFIG}'"
    exit 1
fi

echo -e " ------ \e[96m$ZK_VER\e[0m ------- "

case "$ACTION" in
    'start')
        for zk in $(cat ${ZK_CONFIG}); do
            check_remote_process $zk $ZK_ID

            rt=$?

            if [ $rt -eq 0 ]; then
                echo " Zookeeper [${zk}:${PID}] is already running"
                exit $rt
            fi

            echo "Starting Zookeeper  [${zk}]"
            ( ssh $zk "${ZOOKEEPER_HOME}/bin/zkServer.sh start 2>&1 > /dev/null" )

            rt=$?
        done
        ;;

    'stop')
        for zk in $(cat ${ZK_CONFIG}); do
            check_remote_process $zk $ZK_ID

            rt=$?
            if [ $rt -eq 0 ]; then
                echo "Stopping Zookeeper [${zk}:${PID}]"
                ( ssh $zk "$ZOOKEEPER_HOME/bin/zkServer.sh stop 2>&1 > /dev/null" )
                rt=$?
            else
                echo "Zookeeper not found."
                rt=0
            fi
        done
        ;;

    'status'|'info')
        show_status
        rt=$?
        ;;

    --version|-V)
        version
        ;;
    *)
        usage
        ;;
esac

exit $rt