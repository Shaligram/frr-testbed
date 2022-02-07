#!/bin/sh

ZEBRA=/usr/lib/frr/zebra
OSPFD=/usr/lib/frr/ospfd

case "$1" in
create)
  # create bridge
  brctl addbr SW1

  # create router
  ip netns add RT1
  ip netns add RT2
  ip netns add RT3
  ip netns add RT4
  ip netns add CE1
  ip netns add CE2

  # create link
  ip link add CE1_to_RT1 type veth peer name RT1_to_CE1
  ip link add CE1_to_RT3 type veth peer name RT3_to_CE1

  ip link add CE2_to_RT2 type veth peer name RT2_to_CE2
  ip link add CE2_to_RT4 type veth peer name RT4_to_CE2

  ip link add RT1_to_RT3 type veth peer name RT3_to_RT1
  ip link add RT2_to_RT4 type veth peer name RT4_to_RT2
  ip link add RT3_to_RT4 type veth peer name RT4_to_RT3

  ip link add RT1_to_SW1 type veth peer name SW1_to_RT1
  ip link add RT2_to_SW1 type veth peer name SW1_to_RT2
  ip link add RT3_to_SW1 type veth peer name SW1_to_RT3
  ip link add RT4_to_SW1 type veth peer name SW1_to_RT4



  # IF assign
  brctl addif SW1 SW1_to_RT1
  brctl addif SW1 SW1_to_RT2
  brctl addif SW1 SW1_to_RT3
  brctl addif SW1 SW1_to_RT4

  ip link set RT1_to_CE1 netns RT1 up
  ip link set RT1_to_RT3 netns RT1 up
  ip link set RT1_to_SW1 netns RT1 up

  ip link set RT2_to_CE2 netns RT2 up
  ip link set RT2_to_RT4 netns RT2 up
  ip link set RT2_to_SW1 netns RT2 up

  ip link set RT3_to_CE1 netns RT3 up
  ip link set RT3_to_RT1 netns RT3 up
  ip link set RT3_to_RT4 netns RT3 up
  ip link set RT3_to_SW1 netns RT3 up

  ip link set RT4_to_CE2 netns RT4 up
  ip link set RT4_to_RT2 netns RT4 up
  ip link set RT4_to_RT3 netns RT4 up
  ip link set RT4_to_SW1 netns RT4 up

  ip link set CE1_to_RT1 netns CE1 up
  ip link set CE1_to_RT3 netns CE1 up

  ip link set CE2_to_RT2 netns CE2 up
  ip link set CE2_to_RT4 netns CE2 up


  # IP assign
  ip netns exec RT1 ip addr add 192.168.1.1/24 dev RT1_to_CE1
  ip netns exec RT1 ip addr add 172.16.0.1/24  dev RT1_to_SW1
  ip netns exec RT1 ip addr add 172.17.13.1/24 dev RT1_to_RT3

  ip netns exec RT2 ip addr add 192.168.2.2/24 dev RT2_to_CE2
  ip netns exec RT2 ip addr add 172.16.0.2/24  dev RT2_to_SW1
  ip netns exec RT2 ip addr add 172.19.24.2/24 dev RT2_to_RT4

  ip netns exec RT3 ip addr add 192.168.3.3/24 dev RT3_to_CE1
  ip netns exec RT3 ip addr add 172.16.0.3/24  dev RT3_to_SW1
  ip netns exec RT3 ip addr add 172.17.13.3/24 dev RT3_to_RT1
  ip netns exec RT3 ip addr add 172.18.34.3/24 dev RT3_to_RT4

  ip netns exec RT4 ip addr add 192.168.4.4/24 dev RT4_to_CE2
  ip netns exec RT4 ip addr add 172.16.0.4/24  dev RT4_to_SW1
  ip netns exec RT4 ip addr add 172.19.24.4/24 dev RT4_to_RT2
  ip netns exec RT4 ip addr add 172.18.34.4/24 dev RT4_to_RT3


  ip netns exec CE1 ip addr add 192.168.1.254/24 dev CE1_to_RT1
  ip netns exec CE1 ip addr add 192.168.3.254/24 dev CE1_to_RT3

  ip netns exec CE2 ip addr add 192.168.2.254/24 dev CE2_to_RT2
  ip netns exec CE2 ip addr add 192.168.4.254/24 dev CE2_to_RT4

  ip netns exec RT1 ip addr add 127.0.0.1/8 dev lo
  ip netns exec RT2 ip addr add 127.0.0.1/8 dev lo
  ip netns exec RT3 ip addr add 127.0.0.1/8 dev lo
  ip netns exec RT4 ip addr add 127.0.0.1/8 dev lo
  ip netns exec CE1 ip addr add 127.0.0.1/8 dev lo
  ip netns exec CE2 ip addr add 127.0.0.1/8 dev lo

  # link up
  ip netns exec RT1 ip link set lo up
  ip netns exec RT2 ip link set lo up
  ip netns exec RT3 ip link set lo up
  ip netns exec RT4 ip link set lo up
  ip netns exec CE1 ip link set lo up
  ip netns exec CE2 ip link set lo up

  ip link set SW1_to_RT1 up
  ip link set SW1_to_RT2 up
  ip link set SW1_to_RT3 up
  ip link set SW1_to_RT4 up
  ip link set SW1 up
  ;;

run)
  for rt in RT1 RT2 RT3 RT4 CE1 CE2
  do
    ip netns exec ${rt} ${ZEBRA} -d \
	  -f /etc/frr/${rt}_zebra.conf \
	  -i /var/run/frr/${rt}_zebra.pid \
	  -A 127.0.0.1 \
	  -z /var/run/frr/${rt}_zebra.vty --log stdout

    ip netns exec ${rt} ${OSPFD} -d \
	  -f /etc/frr/${rt}_ospfd.conf \
	  -i /var/run/frr/${rt}_ospfd.pid \
	  -A 127.0.0.1 \
	  -z /var/run/frr/${rt}_zebra.vty --log stdout

  done
  ;;

delete)
  pkill ospfd
  pkill zebra

  ip link set SW1 down
  brctl delbr SW1
  for ns in RT1 RT2 RT3 RT4 CE1 CE2
  do
    ip netns delete ${ns}
  done
  echo "delete"
  ;;
show)
  ip netns list
  ;;
*)
  echo "usage $0 [create|run|delete|show]"
  ;;
esac


