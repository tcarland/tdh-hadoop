#!/bin/bash
#
#  tdh-env-user.sh  -  Sets up the environment for TDH components.
#
#  Timothy C. Arland <tcarland@gmail.com>
export TDH_ENV_USER=1
export TDH_VERSION="0.9.3"

# JAVA_HOME should already be set or managed by the system.
if [ -z "$JAVA_HOME" ]; then
    echo "Error JAVA_HOME is not set"
    exit 1
fi

export HADOOP_USER="${USER}"
export HADOOP_ROOT="/opt/TDH"
export HADOOP_HOME="$HADOOP_ROOT/hadoop"
export HADOOP_LOGDIR="/var/log/hadoop"
export HADOOP_PID_DIR="/tmp"

# HADOOP_CONF_DIR should always be set by user prior to including
# this file to support switching environments.
if [ -z "$HADOOP_CONF_DIR" ]; then
    echo "=> Warning! HADOOP_CONF_DIR is not set!"
    export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
    echo "=> Setting default HADOOP_CONF_DIR=${HADOOP_CONF_DIR}"
fi

# Set components home
export HADOOP_COMMON_HOME="$HADOOP_HOME"
export HADOOP_HDFS_HOME="$HADOOP_COMMON_HOME"
export HADOOP_MAPRED_HOME="$HADOOP_COMMON_HOME"
export HADOOP_YARN_HOME="$HADOOP_COMMON_HOME"
export HBASE_HOME="$HADOOP_ROOT/hbase"
export HBASE_CONF_DIR="$HBASE_HOME/conf"
export HIVE_HOME="$HADOOP_ROOT/hive"
export KAFKA_HOME="$HADOOP_ROOT/kafka"
export SPARK_HOME="$HADOOP_ROOT/spark"

# bin path
export HADOOP_PATH="\
$HADOOP_ROOT/bin:\
$HADOOP_ROOT/sbin:\
$HADOOP_HOME/bin:\
$HBASE_HOME/bin:\
$HIVE_HOME/bin:\
$KAFKA_HOME/bin:\
$SPARK_HOME/bin"

# set a mysqld docker container by name
export TDH_DOCKER_MYSQL="tdh-mysql1"

# Kafka
if [ -f "/etc/kafka/jaas.conf" ]; then
    export KAFKA_OPTS="-Djava.security.auth.login=/etc/kafka/jaas.conf"
fi

if [ -f "/etc/kafka/conf/kafka-client.conf" ]; then
    export ZKS=$( cat /etc/kafka/conf/kafka-client.conf | awk -F '=' '{ print $2 }' )
fi


# -----------------------------------------------
#  WARNING! Do not edit below this line.
#
#  tdh-env-functions
#
TDH_PNAME=${0##*\/}
PID=

export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:+${LD_LIBRARY_PATH}:}${HADOOP_HOME}/lib/native

if [ -n "$HADOOP_PATH" ]; then
    export PATH=${PATH:+${PATH}:}$HADOOP_PATH
fi


function check_process_pid()
{
    local pid=$1

    if ps ax | grep $pid | grep -v grep 2>&1> /dev/null ; then
        PID=$pid
        return 0
    fi

    return 1
}


function check_process()
{
    local key="$1"
    local rt=1

    if [ -z "$key" ]; then
        return $rt
    fi

    pid=$(ps ax | grep "$key" | grep -v grep | awk '{ print $1 }')

    if [ -n "$pid" ]; then
        check_process_pid $pid
        rt=$?
    fi

    return $rt
}

# Check a process on a remote host (via ssh) and set PID accordingly.
function check_remote_process()
{
    local host="$1"
    local pkey="$2"
    local rt=1

    PID=$( ssh $host "ps ax | grep $pkey | grep -v grep | awk '{ print \$1 }'" )

    rt=$?
    if [ -z "$PID" ]; then
        rt=1
    fi

    return $rt
}


#  Validates that our configured hostname as provided by `hostname -f`
#  locally resolves to an interface other than the loopback
function hostip_is_valid()
{
    local hostid=$(hostname -s)
    local hostip=$(hostname -i)
    local fqdn=$(hostname -f)
    local iface=
    local ip=
    local rt=1

    echo "$fqdn"
    echo -n  "[$hostid] : $hostip"

    if [ "$hostip" == "127.0.0.1" ]; then
        echo "   <lo> "
        echo "  WARNING! Hostname is set to localhost, aborting.."
        return $rt
    fi

    IFS=$'\n'

    #for line in `ifconfig | grep inet`; do ip=$( echo $line | awk '{ print $2 }' )
    for line in $(/sbin/ip addr list | grep "inet ")
    do
        IFS=' '
        iface=$(echo $line | awk -F' ' '{ print $NF }')
        ip=$(echo $line | awk '{ print $2 }' | awk -F'/' '{ print $1 }')

        if [ "$ip" == "$hostip" ]; then
            rt=0
            break
        fi
    done

    if [ $rt -eq 0 ]; then
        echo " : <$iface>"
    fi
    echo ""

    return $rt
}


function hconf()
{
    if [ -n "$1" ]; then
        export HADOOP_CONF_DIR="$1"
    fi
    echo "HADOOP_CONF_DIR=$HADOOP_CONF_DIR"
}