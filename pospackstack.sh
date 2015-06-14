#!/bin/bash

COMPUTE[1]=IP
COMPUTE[2]=IP
COMPUTE[3]=IP

for i in 1 2 3
do
        ssh root@${COMPUTE[$i]} "rm -rf /root/openstack-neat"
        scp -r /root/openstack-neat root@${COMPUTE[$i]}:~
        ssh root@${COMPUTE[$i]} "cd /root/openstack-neat && python setup.py install"
done
