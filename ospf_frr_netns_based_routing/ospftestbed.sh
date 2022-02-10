#!/bin/sh

ZEBRA=/usr/lib/frr/zebra
OSPFD=/usr/lib/frr/ospfd
OSPFD_CONFIG=/ospf-frr/ospf_frr_netns_based_routing

case "$1" in
create)

  # create router(8)
  for ns in RT1 RT2 RT3 RT4 RT5 RT6 RT7 RT8
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


  # local link up for local routing
  for rt in RT1 RT2 RT3 RT4 RT5 RT6 RT7 RT8
  do
      ip netns exec ${rt} ip addr add 127.0.0.1/8 dev lo
      ip netns exec ${rt} ip link set lo up
  done
  
  ;; #End of create router

run)
  mkdir -p /var/run/frr/${OSPFD_CONFIG}
  chown frr:frr /var/run/frr/${OSPFD_CONFIG}

  for rt in RT1 RT2 RT3 RT4 RT5 RT6 RT7 RT8
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
  done
  ;; #End of run

delete)
  pkill -u frr 
  pkill -u frr 

  for ns in RT1 RT2 RT3 RT4 RT5 RT6 RT7 RT8
  do
    ip netns delete ${ns}
  done
  echo "delete"
  ;;
show)
  ip netns list
  ps -ef | grep frr
  ;; #End of show
*)
  echo "usage $0 [create|run|delete|show]"
  ;;
esac


