#!/bin/sh
#set -x

ZEBRA=/usr/lib/frr/zebra
OSPFD=/usr/lib/frr/ospfd
OSPFD_CONFIG=/ospf-frr/ospf_frr_netns_based_routing

routers="RT1 RT2 RT3 RT4 RT5 RT6 RT7 RT8 RT22"

case "$1" in
create)

  # create router(8)
  for ns in $routers
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

  # IP assign on Specific Router's Interfaces to simulate passive cli 
  ip netns exec RT1 ip addr add 1.1.1.1/24 dev RT1_to_RT2
  # IP assign on Specific Router's Interfaces
  ip netns exec RT1 ip addr add 172.16.13.1/24 dev RT1_to_RT2
  ip netns exec RT1 ip addr add 192.168.4.1/24 dev RT1_to_RT7
  ip netns exec RT1 ip addr add 192.168.1.1/24 dev RT1_to_RT4
  
  ip netns exec RT3 ip addr add 172.19.13.1/24 dev RT3_to_RT2
  ip netns exec RT3 ip addr add 192.168.2.1/24 dev RT3_to_RT5
  ip netns exec RT3 ip addr add 192.168.3.1/24 dev RT3_to_RT6

  ip netns exec RT2 ip addr add 172.16.13.3/24 dev RT2_to_RT1
  ip netns exec RT2 ip addr add 172.19.13.3/24 dev RT2_to_RT3

  ip netns exec RT4 ip addr add 192.168.1.254/24 dev RT4_to_RT1
  ip netns exec RT5 ip addr add 192.168.2.254/24 dev RT5_to_RT3
  ip netns exec RT6 ip addr add 192.168.3.254/24 dev RT6_to_RT3
  ip netns exec RT6 ip addr add 12.0.0.1/24 dev RT6_to_RT8
  ip netns exec RT7 ip addr add 192.168.4.254/24 dev RT7_to_RT1

  ip netns exec RT8 ip addr add 12.0.0.3/24 dev RT8_to_RT6

  # Redundancy IP assign on Specific Router's Interfaces
  ip netns exec RT1 ip addr add 172.17.13.1/24 dev RT1_to_RT22
  ip netns exec RT3 ip addr add 172.18.13.1/24 dev RT3_to_RT22
  ip netns exec RT22 ip addr add 172.17.13.3/24 dev RT22_to_RT1
  ip netns exec RT22 ip addr add 172.18.13.3/24 dev RT22_to_RT3
  # Redundancy IP assign on Specific Router's Interfaces ends

  # local link up for local routing
  for rt in $routers
  do
      ip netns exec ${rt} ip addr add 127.0.0.1/8 dev lo
      ip netns exec ${rt} ip link set lo up
  done
 
  # below support for pinging from VM directly  
  #config for RT4 to OUT 
  ip link add RT4_to_OUT type veth peer name OUT_to_RT4
  ip link set RT4_to_OUT netns RT4 up
  ip netns exec RT4 ip addr add 192.177.164.254/24 dev RT4_to_OUT

  #config for OUT to RT4
  ip link set OUT_to_RT4 up
  ip addr add 192.177.164.1/24 dev OUT_to_RT4
# below route will be dynamically learned via OSPF  
#  ip route add 12.0.0.0/24 via 192.177.164.254 dev OUT_to_RT4


  
  ;; #End of create router

runstdlog)
  mkdir -p /var/run/frr/${OSPFD_CONFIG}
  chown frr:frr /var/run/frr/${OSPFD_CONFIG}
  
  systemctl restart frr

  routers="RT1 RT2 RT3 RT4 RT5 RT6 RT7 RT8 RT22"
#  routers="RT1 RT2"

  for rt in $routers
  do
    ip netns exec ${rt} ${ZEBRA} -d \
      -f /etc/frr/${OSPFD_CONFIG}/${rt}_zebra.conf \
      -i /var/run/frr/${OSPFD_CONFIG}/${rt}_zebra.pid \
      -A 127.0.0.1 \
      -z /var/run/frr/${OSPFD_CONFIG}/${rt}_zebra.vty --log stdout

    ip netns exec ${rt} ${OSPFD} -d \
      -f /etc/frr/${OSPFD_CONFIG}/${rt}_ospfd.conf \
      -i /var/run/frr/${OSPFD_CONFIG}/${rt}_ospfd.pid \
      -A 127.0.0.1 \
      -z /var/run/frr/${OSPFD_CONFIG}/${rt}_zebra.vty --log stdout
    echo "Zebra OSPF Up for Router instance ${rt} \n"
    sleep 5
  done
  ;; #End of run


run)
  mkdir -p /var/run/frr/${OSPFD_CONFIG}
  chown frr:frr /var/run/frr/${OSPFD_CONFIG}

  routers="RT1 RT2 RT3 RT4 RT5 RT6 RT7 RT8 RT22"
#  routers="RT1 RT2"

  systemctl restart frr

  for rt in $routers
  do
    ip netns exec ${rt} ${ZEBRA} -d \
      -f /etc/frr/${OSPFD_CONFIG}/${rt}_zebra.conf \
      -i /var/run/frr/${OSPFD_CONFIG}/${rt}_zebra.pid \
      -A 127.0.0.1 \
      -z /var/run/frr/${OSPFD_CONFIG}/${rt}_zebra.vty
    
    ip netns exec ${rt} ${OSPFD} -d \
      -f /etc/frr/${OSPFD_CONFIG}/${rt}_ospfd.conf \
      -i /var/run/frr/${OSPFD_CONFIG}/${rt}_ospfd.pid \
      -A 127.0.0.1 \
      -z /var/run/frr/${OSPFD_CONFIG}/${rt}_zebra.vty
    echo "Zebra OSPF Up for Router instance ${rt} \n"
  done
  ;; #End of run

stop)
    pkill -feU frr
    systemctl stop frr
  ;;

delete)

   pkill -feU frr

  ip link del OUT_to_RT4
  for ns in $routers
  do
    ip netns delete ${ns}
  done
  echo "delete"
  ;;
show)
  ip netns list
  ps -fU  frr
  ;; #End of show
test)
    echo "Sending 5 ICMP"
  ip netns exec RT4 ping 12.0.0.3 -c 1
    echo "Sending 5 ICMP"
  ip netns exec RT7 ping 12.0.0.3 -c 1
    echo "Sending 5 ICMP"
  ip netns exec RT8 ping 192.168.1.254 -c 1
    echo "Sending 5 ICMP"
  ip netns exec RT5 ping 192.168.4.254 -c 1
    echo "Sending 5 ICMP"
  ip netns exec RT4 ping 192.168.4.254 -c 1
    echo "Sending 5 ICMP"
  ip netns exec RT5 ping 12.0.0.3 -c 1
    
  echo "traceroute 12.0.0.3"
  ip netns exec RT4 traceroute 12.0.0.3
  echo "traceroute 192.168.4.254"
  ip netns exec RT5 traceroute 192.168.4.254
  
  echo "traceroute 12.0.0.3 from VM directly"
  traceroute 12.0.0.3
  echo "Sending 5 ICMP to RT8 12.0.0.8 DIRECTLY-----"
  ping 12.0.0.3 -c 1

  ;; #End of test
*)
  echo "Information - /etc/daemons options needs to be updated as below for data transfer from VM to Namespace instance
zebra_options="  -A 127.0.0.1 -s 90000000 -f /etc/frr/ospf-frr/ospf_frr_netns_based_routing/OUT_zebra.conf -z /var/run/frr/ospf-frr/ospf_frr_netns_based_routing/OUT_zebra.vty"
ospfd_options="  -A 127.0.0.1 -f /etc/frr/ospf-frr/ospf_frr_netns_based_routing/OUT_ospfd.conf -z /var/run/frr/ospf-frr/ospf_frr_netns_based_routing/OUT_zebra.vty"
"
  echo "usage $0 [create|run|delete|show|test]\n"
  ;;
esac





