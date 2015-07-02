#!/bin/bash

COMPUTE[1]=<COMPUTE01_IP>
COMPUTE[2]=<COMPUTE02_IP>
COMPUTE[3]=<COMPUTE03_IP>

#mkfs.ext4 /dev/disk/by-id/virtio-*
#mkdir -p /var/lib/nova/instances
#mount /dev/disk/by-id/virtio-* /var/lib/nova/instances/
#chown nova:nova /var/lib/nova/instances

#nova boot --flavor m1.small --image cirros --nic net-id=a1a836f6-0ff5-47c7-ab4c-627bda24d455 --key-name test teste4 --availability-zone nova:compute01

systemctl stop iptables
sleep 2
for i in 1 2 3
do
    ssh root@${COMPUTE[$i]} "mount -o hard,intr,noatime controller:/ /var/lib/nova/instances"
done
sleep 2
systemctl start iptables

#nova boot --flavor m1.small --image cirros --nic net-id=a1a836f6-0ff5-47c7-ab4c-627bda24d455 --key-name test teste4 --availability-zone nova:compute0
