#!/bin/bash
#
# rr-script.sh
#
# Site      : https://github.com/raphapr/rr-neat
# Autor     : Raphael P. Ribeiro <raphaelpr01@gmail.com>
#

CONTROLLER=$(/sbin/ifconfig  | sed -ne $'/127.0.0.1/ ! { s/^[ \t]*inet[ \t]\\{1,99\\}\\(addr:\\)\\{0,1\\}\\([0-9.]*\\)[ \t\/].*$/\\2/p; }')
COMPUTE[1]=192.168.82.31
COMPUTE[2]=192.168.82.32
COMPUTE[3]=192.168.82.33
ANSWERFILE=answerfile
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ) # diretório de execução do script

# Controller

# as hostkeys serão adicionadas ao .ssh/known_hosts sem prompt
sed -i '/StrictHostKeyChecking/c\StrictHostKeyChecking no' /etc/ssh/ssh_config

# Configura a segunda interface de rede (eth2) do controller destinada à comunicação com os computes (interface de tunelamento).
cp ifcfg-eth1 /etc/sysconfig/network-scripts/
cd /etc/sysconfig/network-scripts
sed -i 's/CHANGEIP/10.0.10.10/' ifcfg-eth1
cd $DIR
#systemctl restart network

# Configura o eth2 de cada compute node

for i in 1 2 3
do
    scp -i mycloud.pem ifcfg-eth1 centos@${COMPUTE[$i]}:~
    ssh -i mycloud.pem ifcfg-eth1 centos@${COMPUTE[$i]} "sudo su && cp /home/centos/ifcfg-eth1 /etc/sysconfig/network-scripts/"
    ssh -i mycloud.pem centos@${COMPUTE[$i]} "sudo su && cd /etc/sysconfig/network-scripts && sed -i 's/CHANGEIP/10.0.10.11/' ifcfg-eth1 && systemctl restart network"
done

# packstack (controller)

yum update -y
yum install -y https://rdo.fedorapeople.org/rdo-release.rpm
yum install -y tmux vim-minimal git openstack-packstack

# Testa se o packstack foi instalado corretamente
if ! which packstack &> /dev/null; then
    echo ERRO: packstack não está instalado.
    exit 1
fi

packstack --answer-file=$ANSWERFILE

# neat

cd /root && git clone https://github.com/beloglazov/openstack-neat.git && cd /root/openstack-neat # instala o neat e entra no diretório
python setup.py install
./all-start
