# frr test bed for CE to CE data transfer
1. FRR installed with Ubuntu 20.04  - https://docs.frrouting.org/en/latest/index.html
2. All instances uses OSPF for routing table updates. 
3. Download the configuration files & run ./testbed.sh
4. Network Namespace is used for simulating router instances.
5. frr-testbed simulate only route sharing via switch to avoid routing loops running STP.
6. Refer to https://github.com/Shaligram/frr-testbed/tree/main/frr_netns_based_routing for CE -> PE -> P -> PE -> CE 
