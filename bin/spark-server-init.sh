#!/bin/bash
#
#  Init script for Spark Standalone
#
#  Timothy C. Arland <tcarland@gmail.com>
#
PNAME=${0##*\/}
AUTHOR="Timothy C. Arland <tcarland@gmail.com>"

HADOOP_ENV="hadoop-env-user.sh"
SPARK_PID="org.apache.spark.deploy.master.Master"

# source the hadoop-env-user script
if [ -r "./etc/$HADOOP_ENV" ]; then
    . ./etc/$HADOOP_ENV
elif [ -r "/etc/hadoop/$HADOOP_ENV" ]; then
    . /etc/hadoop/$HADOOP_ENV
elif [ -r "$HOME/hadoop/etc/$HADOOP_ENV" ]; then
    . $HOME/hadoop/etc/$HADOOP_ENV
fi

if [ -z "$HADOOP_ENV_USER_VERSION" ]; then
    echo "Fatal! Unable to locate TDH Environment '$HADOOP_ENV'"
    exit 1
fi

if [ -z "$SPARK_USER" ]; then
    SPARK_USER="$HADOOP_USER"
fi


usage()
{
    echo "$PNAME {start|stop|status}"
    echo "  Version: $HADOOP_ENV_USER_VERSION"
}


show_status()
{
    local rt=0

    check_process $SPARK_ID

    rt=$?
    if [ $rt -ne 0 ]; then
        echo " Spark Standalone      [$PID]"
    else
        echo " Spark Standalone Server is not running"
    fi

    return $rt
}


ACTION="$1"
rt=0

case "$ACTION" in
    'start')
        check_process $SPARK_ID

        rt=$?
        if [ $rt -ne 0 ]; then
            echo "Error: Spark Master is already running [$PID]"
            exit $rt
        fi

        echo "Starting Spark Standalone..."
        ( sudo -u $HADOOP_USER $SPARK_HOME/sbin/start-all.sh )
        ;;

    'stop')
        check_process $SPARK_ID

        rt=$?
        if [ $rt -ne 0 ]; then
            echo "Stopping Spark Standalone..."
            ( sudo -u $HADOOP_USER $SPARK_HOME/sbin/stop-all.sh )
            rt=0
        else
            echo " Spark Master not running.."
            exit $rt
        fi
        ;;

    'status'|'info')
        show_status
        ;;
    *)
        usage
        ;;
esac

exit $rt
