#!/bin/bash
# So much of effort to run something which is running everywhere aroung us"
# Good to feel it runs now on single VM  

 
#set -x

ZEBRA=/usr/lib/frr/zebra
OSPFD=/usr/lib/frr/ospfd
LDPD=/usr/lib/frr/ldpd
BGPD=/usr/lib/frr/bgpd
CONFIG=`pwd`
VAR_PATH=`basename $CONFIG`

ENABLE_SOURCE_VM_TO_NS_PING=0

routers_instance="RT1 RT2 RT3 RT4 RT5"
#routers_instance="RT1 RT2 RT3"
run_routers="RT1 RT2 RT3 RT4 RT5"
run_ldprouters="RT1 RT2 RT3"
run_bgprouters="RT1 RT3"

#/* Arguments are - $1=enable_loggin, $2=enable_ospf $3=enable_ldpd */
run_frr_daemons () {

    enable_loggin=$1
    enable_zebra=$2
    enable_ospf=$3
    enable_ldpd=$4

    if [ $ENABLE_SOURCE_VM_TO_NS_PING -eq 1 ]
    then 
        systemctl restart frr
    fi

    for rt in $run_routers
    do
        echo -e "----------------------------------------\n"
        if [ $enable_zebra -eq 1 ]
        then
            ip netns exec ${rt} ${ZEBRA} -d \
                -f ${CONFIG}/${rt}_zebra.conf \
                -A 127.0.0.1 \
                -i /var/run/frr/${VAR_PATH}/${rt}_zebra.pid \
                -z /var/run/frr/${VAR_PATH}/${rt}_zebra.vty $enable_loggin

            echo "${rt}: FRR ZEBRA Up for Router instance"
        fi

        if [ $enable_ospf -eq 1 ] 
        then
            ip netns exec ${rt} ${OSPFD} -d \
                -f ${CONFIG}/${rt}_ospfd.conf \
                -A 127.0.0.1 \
                -i /var/run/frr/${VAR_PATH}/${rt}_ospfd.pid \
                -z /var/run/frr/${VAR_PATH}/${rt}_zebra.vty $enable_loggin 

            echo "${rt}: FRR OSPF Up for Router instance"
        fi

        if [ $enable_ldpd -eq 1 ] && [[ " ${run_ldprouters[*]} " =~ " ${rt} " ]];
        then
           sleep 20 &&  ip netns exec ${rt} ${LDPD} -d \
                -f ${CONFIG}/${rt}_ldpd.conf \
                -A 127.0.0.1 \
                -i /var/run/frr/${VAR_PATH}/${rt}_ldpd.pid \
                -z /var/run/frr/${VAR_PATH}/${rt}_zebra.vty $enable_loggin &

            echo "${rt}: FRR LDP Up for Router instance"
        fi
        
        if [[ " ${run_bgprouters[*]} " =~ " ${rt} " ]];
        then
            ip netns exec ${rt} ${BGPD} -d \
                -f ${CONFIG}/${rt}_bgpd.conf \
                -A 127.0.0.1 \
                -i /var/run/frr/${VAR_PATH}/${rt}_bgpd.pid \
                -z /var/run/frr/${VAR_PATH}/${rt}_zebra.vty $enable_loggin

            echo "${rt}: FRR BGP Up for Router instance"
        fi
        sleep 1;
    done
}

case "$1" in
create)

    echo "CONFIG PATH  $CONFIG"
    echo "VAR_PATH  /var/run/frr/$VAR_PATH"
    echo "Going to kill all frr processes "
    systemctl stop frr 

    cat /etc/frr/daemons  | grep $VAR_PATH 
    if [ $? -eq 1 ] && [ $ENABLE_SOURCE_VM_TO_NS_PING -eq 1 ];
    then 
        cp /etc/frr/daemons /etc/frr/daemons.$VAR_PATH.orig
        echo "/etc/frr/daemons options modified "
        echo "zebra_options=\"-A 127.0.0.1 -s 90000000 -f $CONFIG/OUT_zebra.conf -z /var/run/frr/$VAR_PATH/OUT_zebra.vty\"" >> /etc/frr/daemons
        echo "ospfd_options=\"-A 127.0.0.1 -f $CONFIG/OUT_ospfd.conf -z /var/run/frr/$VAR_PATH/OUT_zebra.vty\"" >> /etc/frr/daemons
    fi

    pkill -feU frr
    if [ $ENABLE_SOURCE_VM_TO_NS_PING  -eq  1 ]
    then 
        systemctl stop frr 
    fi
    sleep 2
    mkdir -p /var/run/frr/${VAR_PATH}
    chown frr:frr /var/run/frr/${VAR_PATH}
    modprobe mpls_router
    modprobe mpls_iptunnel
    modprobe mpls_gso

  # create router(8)
  for ns in $routers_instance
  do
    ip netns add ${ns}
  done

  # create link(7)
  ip link add RT1_to_RT2 type veth peer name RT2_to_RT1
  ip link add RT2_to_RT3 type veth peer name RT3_to_RT2
  ip link add RT4_to_RT1 type veth peer name RT1_to_RT4
  ip link add RT7_to_RT1 type veth peer name RT1_to_RT7
  ip link add RT5_to_RT3 type veth peer name RT3_to_RT5
  ip link add RT6_to_RT3 type veth peer name RT3_to_RT6
  ip link add RT6_to_RT8 type veth peer name RT8_to_RT6

  # REdundancy link 
  ip link add RT1_to_RT22 type veth peer name RT22_to_RT1
  ip link add RT22_to_RT3 type veth peer name RT3_to_RT22
  # REdundancy link end

  # Connect wires(7*2way)
  ip link set RT1_to_RT2 netns RT1 up
  ip link set RT1_to_RT4 netns RT1 up
  ip link set RT1_to_RT7 netns RT1 up
  
  ip link set RT2_to_RT1 netns RT2 up
  ip link set RT2_to_RT3 netns RT2 up
  
  ip link set RT3_to_RT2 netns RT3 up
  ip link set RT3_to_RT5 netns RT3 up
  ip link set RT3_to_RT6 netns RT3 up
  
  ip link set RT4_to_RT1 netns RT4 up
  ip link set RT7_to_RT1 netns RT7 up
  
  ip link set RT5_to_RT3 netns RT5 up

  ip link set RT6_to_RT3 netns RT6 up
  ip link set RT6_to_RT8 netns RT6 up
  
  ip link set RT8_to_RT6 netns RT8 up
  
  #Redundancy link up
  ip link set RT1_to_RT22 netns RT1 up
  
  ip link set RT22_to_RT1 netns RT22 up
  ip link set RT22_to_RT3 netns RT22 up
  
  ip link set RT3_to_RT22 netns RT3 up
  #Redundancy link up end
  
  # Vrf Configuration for handling RT4 traffic

  ip netns exec RT1 ip link add RED type vrf table 1
  ip netns exec RT1 ip link set dev RT1_to_RT4 master RED
  ip netns exec RT1 ip link set dev RED up
  
  ip netns exec RT3 ip link add RED type vrf table 1
  ip netns exec RT3 ip link set dev RT3_to_RT5 master RED
  ip netns exec RT3 ip link set dev RED up
  # Vrf Configuration for handling RT4 traffic end
  
 # MPLS Specific Config - Important for enabling MPLS processing 
  ip netns exec RT1  sysctl -w net.mpls.conf.RT1_to_RT2.input=1
  ip netns exec RT1 sysctl -w net.mpls.platform_labels=65535
  
  ip netns exec RT2 sysctl -w net.mpls.conf.RT2_to_RT1.input=1
  ip netns exec RT2 sysctl -w net.mpls.conf.RT2_to_RT3.input=1
  ip netns exec RT2 sysctl -w net.mpls.platform_labels=65535
  
  ip netns exec RT3 sysctl -w net.mpls.conf.RT3_to_RT2.input=1
  ip netns exec RT3 sysctl -w net.mpls.platform_labels=65535
  # MPLS Specific Config

 
  # below support for pinging from VM directly  
  if [ $ENABLE_SOURCE_VM_TO_NS_PING  -eq  1 ]
  then 
  #config for RT4 to OUT 
  ip link add RT4_to_OUT type veth peer name OUT_to_RT4
  ip link set RT4_to_OUT netns RT4 up
  ip netns exec RT4 ip addr add 192.177.164.254/24 dev RT4_to_OUT

  #config for OUT to RT4
  ip link set OUT_to_RT4 up
  ip addr add 192.177.164.1/24 dev OUT_to_RT4
  fi
# below route will be dynamically learned via OSPF  
#  ip route add 12.0.0.0/24 via 192.177.164.254 dev OUT_to_RT4


  
  ;; #End of create router

runstdlog)
    run_frr_daemons "--log=stdout" 1 1 1
  ;; #End of run


run)
    run_frr_daemons "" 1 1 1
  ;; #End of run


runospf)
    run_frr_daemons "" 1 1 0 
  ;; #End of run

runmpls)
    run_frr_daemons "" 0 0 1
  ;; #End of run

stop)
    pkill -feU frr
    if [ $ENABLE_SOURCE_VM_TO_NS_PING  -eq  1 ]
    then 
        systemctl stop frr 
    fi
  ;;

delete)

   pkill -feU frr
   pkill -f "/bin/bash --rcfile"

   if [ $ENABLE_SOURCE_VM_TO_NS_PING  -eq  1 ]
   then 
       systemctl stop frr 
       cp /etc/frr/daemons.$VAR_PATH.orig /etc/frr/daemons 
   fi

  ip link del OUT_to_RT4
  for ns in $routers_instance
  do
    ip netns delete ${ns}
  done
  echo "delete"
  ;;
show)
  ip netns list
  ps -fU frr -o ppid,pid,cmd
  ps -ef | grep watchfrr | grep -v gre
  ;; #End of show
test)
    
    echo -e "\nSending 5 ICMP RT4 to RT5 VRF RED"
    ip netns exec RT4 ping 6.6.6.6 -c 1
    echo -e "\nSending 5 ICMP RT5 to RT4 VRF RED"
    ip netns exec RT5 ping 4.4.4.4 -c 1

    echo -e "\ntraceroute 6.6.6.6 from RT4"
    ip netns exec RT4 traceroute -e 6.6.6.6
    echo -e "\ntraceroute 4.4.4.4 from RT5"
    ip netns exec RT5 traceroute -e 4.4.4.4
    
    
    echo -e "\nSending 5 ICMP RT4 to RT5 VRF RED"
    ip netns exec RT4 ping 192.168.2.4 -c 1
    echo -e "\nSending 5 ICMP RT5 to RT4 VRF RED"
    ip netns exec RT5 ping 192.168.1.4 -c 1

    echo -e "\ntraceroute 192.168.2.4 from RT4"
    ip netns exec RT4 traceroute -e 192.168.2.4
    echo -e "\ntraceroute 192.168.1.4 from RT5"
    ip netns exec RT5 traceroute -e 192.168.1.4
  
  if [ $ENABLE_SOURCE_VM_TO_NS_PING  -eq  1 ] 
  then
      echo -e "\ntraceroute 12.0.0.3 from VM directly"
      traceroute 12.0.0.3
      echo -e "\nSending 5 ICMP to RT8 12.0.0.8 DIRECTLY-----"
      ping 12.0.0.3 -c 1
  fi

  ;; #End of test
*)
  echo "Information - /etc/daemons options needs to be updated as below for data transfer from VM to Namespace instance
zebra_options="  -A 127.0.0.1 -s 90000000 -f /etc/frr/$CONFIG/OUT_zebra.conf -z /var/run/frr/$VAR_PATH/OUT_zebra.vty"
ospfd_options="  -A 127.0.0.1 -f /etc/frr/$CONFIG/OUT_ospfd.conf -z /var/run/frr/$VAR_PATH/OUT_zebra.vty"
"
  echo -e "usage $0 [create|run|delete|show|test|runstdlog|runospf|runmpls]\n"
  ;;
esac





