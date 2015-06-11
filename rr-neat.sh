#!/bin/bash
#
# rr-script.sh
#
# Site      : https://github.com/raphapr/rr-neat
# Autor     : Raphael P. Ribeiro <raphaelpr01@gmail.com>
#

# Checa se o script está sendo executado por usuário root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root!" 1>&2
   exit 1
fi

#############################################################################################################
# Variáveis
#############################################################################################################

## pega o IP interno do controller (eth0)
CONTROLLER=$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ' ' -f 10)
COMPUTE[1]=<COMPUTE01_IP>
COMPUTE[2]=<COMPUTE02_IP>
COMPUTE[3]=<COMPUTE03_IP>
SUBNET=$(echo $CONTROLLER | cut -d '.' -f 1-3)
ANSWERFILE=answerfile # arquivo utilizado pelo packstack, contêm todas as informações de configuração necessária para a instalação do OpenStack
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ) # diretório de execução do script

function preconfigure() {

    #############################################################################################################
    # Configura o SELinux no modo permissivo: permite que o packstack faça uma instalação do OpenStack sem erros.
    #############################################################################################################

    setenforce 0
    sed -i '/SELINUX=enforcing/c\SELINUX=permissive' /etc/selinux/config

    #############################################################################################################
    # Atualização do sistema e pacotes necessários
    #############################################################################################################

    yum update -y
    yum install -y https://rdo.fedorapeople.org/rdo-release.rpm
    yum install -y nmap tmux vim git openstack-packstack httpd iptables-services

    # Não está funcionando
    #############################################################################################################
    # Pega o IP dos computes de forma dinâmica
    # Estimativa: 10 segundos
    #############################################################################################################

    #nmap -sP ${SUBNET}.*
    #targets=($(nmap -sP ${SUBNET}.* | grep ^Nmap | awk '{print $5;}' | grep ^[0-9].*)) # Pega todos os endereços IP da sub-rede e armazena em um array
    #
    ##ping -c 1 -b ${SUBNET}.255
    ##targets=($(arp -a | sed '/eth1/d' | cut -d "(" -f2,3 | cut -d ")" -f1,3)) # Pega todos os endereços IP da sub-rede e armazena em um array
    #
    #for i in "${targets[@]}"
    #do
    #        ssh -i mycloud.pem -q -o "BatchMode=yes" centos@${i} "echo 2>&1" &&
    #        output="$(ssh -t -i mycloud.pem centos@${i} "cat /etc/hostname | cut -d "." -f1")" &&
    #        if [[ $output == *"compute01"* ]]; then
    #                COMPUTE[1]=$i
    #        elif [[ $output == *"compute02"* ]]; then
    #                COMPUTE[2]=$i
    #        elif [[ $output == *"compute03"* ]]; then
    #                COMPUTE[3]=$i
    #        fi
    #done

    #############################################################################################################
    # Controller
    # Configurações do controller
    #############################################################################################################

    # As hostkeys serão adicionadas ao .ssh/known_hosts sem prompt
    sed -i '/StrictHostKeyChecking/c\StrictHostKeyChecking no' /etc/ssh/ssh_config

    # cria chave ssh para packstack
    yes | ssh-keygen -q -t rsa -N "" -f /root/.ssh/id_rsa

    # Configura a segunda interface de rede (eth2) do controller destinada à comunicação com os computes (interface de tunelamento).
    cp ifcfg-eth1 /etc/sysconfig/network-scripts/
    cd /etc/sysconfig/network-scripts && sed -i 's/CHANGEIP/10.0.10.10/' ifcfg-eth1

    # Se o /etc/hosts já foi modificado, não adiciona os demais hosts
    if ! grep -q "compute01" /etc/hosts; then
        sed -i "\$a# controller\n10.0.10.10	controller\n\n# compute01\n10.0.10.11	compute01\n\n# compute02\n10.0.10.12	compute02\n\n# compute03\n10.0.10.13	compute03" /etc/hosts
    fi

    # Permite o acesso ssh através do usuário root
    # Não aconselhável em sistema de produção, porém como é uma reprodução de experimentos, não tem problemas.
    yes | sudo cp -i /home/centos/.ssh/authorized_keys /root/.ssh/authorized_keys
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

    # Reinicia serviço de rede para que todas as configurações entrarem em vigor
    systemctl restart network

    #############################################################################################################
    # Computes
    # Configurações dos computes nodes: faz exatamente a mesma coisa que foi feito nas linhas acima para o controller
    #############################################################################################################

    for i in 1 2 3
    do
        cd $DIR
        scp -i mycloud.pem ifcfg-eth1 centos@${COMPUTE[$i]}:~
        ssh -t -i mycloud.pem centos@${COMPUTE[$i]} "
    sudo cp /home/centos/ifcfg-eth1 /etc/sysconfig/network-scripts/
    sudo sed -i "s/CHANGEIP/10.0.10.1${i}/" /etc/sysconfig/network-scripts/ifcfg-eth1
    if ! grep -q 'compute01' /etc/hosts; then
        sudo sed -i '\$a# controller\n10.0.10.10	controller\n\n# compute01\n10.0.10.11	compute01\n\n# compute02\n10.0.10.12	compute02\n\n# compute03\n10.0.10.13	compute03' /etc/hosts
    fi
    yes | sudo cp -i /home/centos/.ssh/authorized_keys /root/.ssh/authorized_keys
    sudo systemctl restart network
    "
       cat /root/.ssh/id_rsa.pub | ssh -i mycloud.pem root@${COMPUTE[$i]} "cat - >> ~/.ssh/authorized_keys"
    done

}

#############################################################################################################
# Main
#############################################################################################################

if ! grep -q 'REBOOTED' /etc/bashrc; then # se não reiniciou, reinicia todos os nós, se reiniciou instala packstack
    # preconfigure to packstack
    preconfigure
	echo "REBOOTED # created by rr-neat script" >> /etc/bashrc
	echo "### Rebooting compute01"
	ssh root@compute01 "reboot"
	echo "### Rebooting compute02"
	ssh root@compute02 "reboot"
	echo "### Rebooting compute03"
	ssh root@compute03 "reboot"
	echo "### Rebooting controller"
	reboot
fi

#############################################################################################################
# packstack
# O script utiliza o packstack para a instalação automatizada do OpenStack. 
# O answerfile não inclui o Cinder e Heat, pois não há necessidades desses módulos para o experimento.
#############################################################################################################

## substituição das variáveis para endereços ips no arquivo answerfile 
yes | cp -i answerfile-modelo answerfile
sed -i "s/controllerhost/${CONTROLLER}/" answerfile
for i in 1 2 3
do
       sed -i "s/compute0$i/${COMPUTE[$i]}/" answerfile
done

# packstack tem problemas em iniciar iptables e httpd, iniciando pelo script
systemctl enable httpd && systemctl start httpd
systemctl enable iptables && systemctl start iptables

## Instalando openstack
## ESTIMATIVA: 20~30min

packstack --answer-file=$ANSWERFILE

## Alterações packstack pós instalação

source /root/keystonerc_admin

neutron net-create ext-net --router:external
neutron subnet-create --disable-dhcp ext-net 172.12.12.0/24 --gateway=172.12.12.1

source /root/keystonerc_demo

neutron net-create int-net
neutron subnet-create --name int-subnet --dns-nameserver 8.8.8.8 int-net 10.1.1.0/24

neutron router-create extrouter
neutron router-gateway-set extrouter ext-net
neutron router-interface-add extrouter int-subnet

# Criando chave publica para o Nova
ssh-keygen -t rsa -b 2048 -N '' -f /root/.ssh/demokey
nova keypair-add --pub-key /root/.ssh/demokey.pub demokey

# Abrindo porta para ssh
neutron security-group-rule-create --protocol icmp default
neutron security-group-rule-create --protocol tcp --port-range-min 22 --port-range-max 22 default

#ip addr add 172.12.12.1/24 dev br-ex
#iptables -t nat -I POSTROUTING 1 -s 172.12.12.0/24 -j MASQUERADE

#nova floating-ip-create ext-net
#nova add-floating-ip cirros <IP>

##TODO: Concluir configuração do openstack-neat
#
##############################################################################################################
## openstack-neat
## instalação e configuração
##############################################################################################################

pip install -e git+git://github.com/rlgomes/contracts.git#egg=contracts
cd /root && git clone https://github.com/beloglazov/openstack-neat.git
cd /root/openstack-neat && python setup.py install

for i in 1 2 3
do
	scp -r /root/openstack-neat root@${COMPUTE[$i]}:~
	ssh root@${COMPUTE[$i]} "cd /root/openstack-neat && python setup.py install"
done
