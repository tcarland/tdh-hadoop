#!/bin/bash
#
#  Sets up an internal IP or pseudo-ip on a given interface. By default
#  vmnet8 (vmware) is used, but vbox works as well.  Primarily for
#  running TDH as pseudo-distributed in a closed environment (no or
#  unstable network) like a laptop.
#

# ----------- preamble
HADOOP_ENV="tdh-env-user.sh"

if [ -r "./etc/$HADOOP_ENV" ]; then
    . ./etc/$HADOOP_ENV
elif [ -r "/etc/hadoop/$HADOOP_ENV" ]; then
    . /etc/hadoop/$HADOOP_ENV
elif [ -r "/opt/TDH/etc/$HADOOP_ENV" ]; then
    . /opt/TDH/etc/$HADOOP_ENV
elif [ -r "$HOME/hadoop/etc/$HADOOP_ENV" ]; then
    . $HOME/hadoop/etc/$HADOOP_ENV
fi

# -----------


usage="
Convenience script for configuring the host IP on the given interface. 
By default, the interface 'vmnet8' is used, but can be defined seperately.
This is primarily intended for detached hosts or hosts with unstable 
network environments (ie. laptop|wifi)

Synopsis:
  $TDH_PNAME [options]  start|stop|status

Options:
  -h|--help      : Display usage info and exit.
  -i|--interface : Name of a system interface; default is 'vmnet8'
  -I|--ip        : Alternate bind address to use, in CIDR format.
                   the default is: \$(hostname -i)/24
  -V|--version   : Display version and exit

   Note the /24 netmask is the default used above, but the netmask
   should always be provided with the -I option
"


hostip_is_valid()
{
    local hostid=`hostname`
    local hostip=`hostname -i`
    local fqdn=`hostname -f`
    local iface=
    local ip=
    local rt=1

    if [ "$hostip" == "127.0.0.1" ]; then
        echo "   <lo> "
        echo "  WARNING! Hostname is set to localhost, aborting.."
        return $rt
    fi

    IFS=$'\n'

    for line in $(ip addr list | grep "inet ")
    do
        IFS=$' '
        iface=$(echo $line | awk -F' ' '{ print $NF }')
        ip=$(echo $line | awk '{ print $2}' | awk -F'/' '{ print $1 }')

        if [ "$ip" == "$hostip" ]; then
            rt=0
            break
        fi
    done

    echo ""
    echo "$fqdn"
    echo -n "[$hostid]"

    if [ $rt -eq 0 ]; then
        echo " : $hostip : <$iface>"
    else
	echo " : <No Interface bound>"
    fi

    return $rt
}


#-------------------------------------------------------------
# Main
ACTION=
BINDIP="$(hostname -i)/24"
IFACE="vmnet8"

# parse options
while [ $# -gt 0 ]; do
    case "$1" in
        'help'|-h|--help)
            echo "$usage"
            exit 0
            ;;
        -i|--interface)
            IFACE="$2"
            shift
            ;;
        -I|--ip)
            BINDIP="$2"
            shift;
            ;;
        'version'|-V|--version)
            tdh_version
            exit 0
            ;;
        *)
            ACTION="$1"
            shift
            ;;
    esac
done

rt=0

if [ "$ACTION" == "start" ]; then

    hostip_is_valid
    rt=$?

    if [ $rt -ne 0 ]; then
        echo ""
	    echo "  Binding $BINDIP to interface $IFACE"
        echo ""

        ( sudo ip addr add $BINDIP dev $IFACE )
        rt=$?

        hostip_is_valid
    fi

elif [ "$ACTION" == "stop" ]; then

    ( sudo ip addr del $BINDIP dev $IFACE )
    rt=$?

    hostip_is_valid

elif [ "$ACTION" == "status" ]; then

    hostip_is_valid
    rt=$?
    echo ""

else
    echo "$usage"
fi

echo ""
exit $rt
