#!/bin/bash
#
# rr-script.sh
#
# Site      : https://github.com/raphapr/rr-neat
# Autor     : Raphael P. Ribeiro <raphaelpr01@gmail.com>
#

# set SELinux permissive

setenforce 0
sed -i '/SELINUX=enforcing/c\SELINUX=permissive' /etc/selinux/config

CONTROLLER=$(/sbin/ifconfig  | sed -ne $'/127.0.0.1/ ! { s/^[ \t]*inet[ \t]\\{1,99\\}\\(addr:\\)\\{0,1\\}\\([0-9.]*\\)[ \t\/].*$/\\2/p; }')
# TODO: Pegar IP dinamicamente
COMPUTE[1]=10.0.4.181
COMPUTE[2]=10.0.4.192
COMPUTE[3]=10.0.4.183
ANSWERFILE=answerfile
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ) # diretório de execução do script

# Controller

# as hostkeys serão adicionadas ao .ssh/known_hosts sem prompt
sed -i '/StrictHostKeyChecking/c\StrictHostKeyChecking no' /etc/ssh/ssh_config

# Configura a segunda interface de rede (eth2) do controller destinada à comunicação com os computes (interface de tunelamento).
cp ifcfg-eth1 /etc/sysconfig/network-scripts/
cd /etc/sysconfig/network-scripts && sed -i 's/CHANGEIP/10.0.10.10/' ifcfg-eth1

# Se o /etc/hosts já foi modificado, não adiciona os demais hosts
if ! grep -q "compute01" /etc/hosts; then
	sed -i "\$a# controller\n10.0.10.10	controller\n\n# compute01\n10.0.10.11	compute01\n\n# compute02\n10.0.10.12	compute02\n\n# compute03\n10.0.10.13	compute03" /etc/hosts
fi
yes | sudo cp -i /home/centos/.ssh/authorized_keys /root/.ssh/authorized_keys

# Reinicia serviço de rede para que todas as configurações entrarem em vigor
#systemctl restart network

# Configura o eth2 de cada compute node

for i in 1 2 3
do
    cd $DIR
    scp -i mycloud.pem ifcfg-eth1 centos@${COMPUTE[$i]}:~
    ssh -t -i mycloud.pem centos@${COMPUTE[$i]} "
sudo cp /home/centos/ifcfg-eth1 /etc/sysconfig/network-scripts/
sudo sed -i "s/CHANGEIP/10.0.10.1${i}/" /etc/sysconfig/network-scripts/ifcfg-eth1
if ! grep -q 'compute01' /etc/hosts; then
	sudo sed -i '\$a# controller\n10.0.10.10	controller\n\n# compute01\n10.0.10.11	compute01\n\n# compute02\n10.0.10.12	compute02\n\n# compute03\n10.0.10.13	compute03' /etc/hosts
yes | sudo cp -i /home/centos/.ssh/authorized_keys /root/.ssh/authorized_keys
fi
sudo systemctl restart network
"
done

# packstack (controller)

yum update -y
yum install -y https://rdo.fedorapeople.org/rdo-release.rpm
yum install -y tmux vim-minimal git openstack-packstack

## Testa se o packstack foi instalado corretamente
if ! which packstack &> /dev/null; then
    echo ERRO: packstack não está instalado.
    exit 1
fi

# Instalando openstack: aproximadamente 30min de instalação.
#
# packstack tem problemas em iniciar iptables e httpd. INICIAR MANUALMENTE! (systemctl start httpd | systemctl start iptables)

packstack --answer-file=$ANSWERFILE



## neat
#
#cd /root && git clone https://github.com/beloglazov/openstack-neat.git && cd /root/openstack-neat # instala o neat e entra no diretório
#python setup.py install
#./all-start
