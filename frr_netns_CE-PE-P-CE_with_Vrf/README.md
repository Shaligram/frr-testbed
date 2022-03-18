#

./testbedCEtoCE.sh 
Information - /etc/daemons options needs to be updated as below for data transfer from VM to Namespace instance
zebra_options= -A 127.0.0.1 -s 90000000 -f /etc/frr//etc/frr/ospf-frr/frr_netns_CE-PE-P-CE_with_Vrf/OUT_zebra.conf -z /var/run/frr/frr_netns_CE-PE-P-CE_with_Vrf/O
UT_zebra.vty
ospfd_options= -A 127.0.0.1 -f /etc/frr//etc/frr/ospf-frr/frr_netns_CE-PE-P-CE_with_Vrf/OUT_ospfd.conf -z /var/run/frr/frr_netns_CE-PE-P-CE_with_Vrf/OUT_zebra.vty

**usage** ./testbedCEtoCE.sh [create|run|delete|show|test|runstdlog|runospf|runmpls]


Will update details later...
![alt text](https://github.com/Shaligram/frr-testbed/blob/main/frr_netns_CE-PE-P-CE_with_Vrf/e2e.jpg)

VRF leak not added. 
VRF RED talks to RED
VRF BLUE talks to BLUE
