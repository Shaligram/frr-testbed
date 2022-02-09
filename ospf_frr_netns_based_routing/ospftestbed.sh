#!/bin/sh

ZEBRA=/usr/lib/frr/zebra
OSPFD=/usr/lib/frr/ospfd
OSPFD_CONFIG=ospf_frr_netns_based_routing

case "$1" in
create)

  # create router
  ip netns add R1
  ip netns add R2

  # create link
  ip link add R1_to_R2 type veth peer name R2_to_R1

  ip link set R1_to_R2 netns R1 up

  ip link set R2_to_R1 netns R2 up


  # IP assign
  ip netns exec R1 ip addr add 172.17.13.1/24 dev R1_to_R2
  ip netns exec R2 ip addr add 172.17.13.3/24 dev R2_to_R1
  
  ip netns exec R1 ip addr add 127.0.0.1/8 dev lo
  ip netns exec R2 ip addr add 127.0.0.1/8 dev lo

  # link up
  ip netns exec R1 ip link set lo up
  ip netns exec R2 ip link set lo up
  
  ;; #End of create router

run)
  mkdir -p /var/run/frr/${OSPFD_CONFIG}
  chown frr:frr /var/run/frr/${OSPFD_CONFIG}

  for rt in R1 R2
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
  ;; #End of run

delete)
  pkill ospfd
  pkill zebra

  for ns in R1 R2
  do
    ip netns delete ${ns}
  done
  echo "delete"
  ;;
show)
  ip netns list
  ;; #End of show
*)
  echo "usage $0 [create|run|delete|show]"
  ;;
esac


