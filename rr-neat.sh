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

if [ ! -e "mycloud.pem" ]; then
   echo "ERROR: File 'mycloud.pem' doesn't exist!" 1>&2
   exit 1
fi

#############################################################################################################
# Variáveis
#############################################################################################################

# inserir os respectivos IPs dos computes aqui (eth0)
COMPUTE[1]=<COMPUTE01_IP>
COMPUTE[2]=<COMPUTE02_IP>
COMPUTE[3]=<COMPUTE03_IP>
## pega o IP interno do controller (eth0)
CONTROLLER=$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ' ' -f 10)
SUBNET=$(echo $CONTROLLER | cut -d '.' -f 1-3)
ANSWERFILE=answerfile # arquivo utilizado pelo packstack, contêm todas as informações de configuração necessária para a instalação do OpenStack
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ) # diretório de execução do script

#############################################################################################################
# Preconfiguração de todos os nós: controller e computes 01, 02 e 03
#############################################################################################################

preconfigure() {

    # Configura o SELinux no modo permissivo: permite que o packstack faça uma instalação do OpenStack sem erros.
    setenforce 0
    sed -i '/SELINUX=enforcing/c\SELINUX=permissive' /etc/selinux/config

    # Controller
    # >>> Configuração do controller

    # As hostkeys serão adicionadas ao .ssh/known_hosts sem prompt
    sed -i '/StrictHostKeyChecking/c\StrictHostKeyChecking no' /etc/ssh/ssh_config

    # cria chave ssh para packstack
    yes | ssh-keygen -q -t rsa -N "" -f /root/.ssh/id_rsa

    # Configura a segunda interface de rede (eth2) do controller destinada à comunicação com os computes (interface de tunelamento).
    cp ifcfg-eth1 /etc/sysconfig/network-scripts/
    cd /etc/sysconfig/network-scripts && sed -i 's/CHANGEIP/10.0.10.10/' ifcfg-eth1

    # Se o /etc/hosts já foi modificado, não adiciona os demais hosts
    if ! grep -q "compute01" /etc/hosts; then
        sed -i "\$a# controller\n$CONTROLLER      controller\n\n# compute01\n${COMPUTE[1]}    compute01\n${COMPUTE[1]}    compute01.novalocal\n\n# compute02\n${COMPUTE[2]}     compute02\n${COMPUTE[2]}     compute02.novalocal\n\n# compute03\n${COMPUTE[3]}     compute03\n${COMPUTE[3]}     compute03.novalocal" /etc/hosts
    fi

    # Permite o acesso ssh através do usuário root
    yes | sudo cp -i /home/centos/.ssh/authorized_keys /root/.ssh/authorized_keys
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

    # Reinicia serviço de rede para que todas as configurações entrarem em vigor
    systemctl restart network

    # Computes
    # >>> Configuração dos computes nodes: faz exatamente a mesma coisa que foi feito nas linhas acima para o controller

    for i in 1 2 3
    do
        cd $DIR
        scp -i mycloud.pem ifcfg-eth1 centos@${COMPUTE[$i]}:~
        ssh -t -i mycloud.pem centos@${COMPUTE[$i]} "
    sudo cp /home/centos/ifcfg-eth1 /etc/sysconfig/network-scripts/
    sudo sed -i "s/CHANGEIP/10.0.10.1${i}/" /etc/sysconfig/network-scripts/ifcfg-eth1
    if ! grep -q 'compute01' /etc/hosts; then
        sudo sed -i '\$a# controller\n$CONTROLLER      controller\n\n# compute01\n${COMPUTE[1]}    compute01\n${COMPUTE[1]}    compute01.novalocal\n\n# compute02\n${COMPUTE[2]}     compute02\n${COMPUTE[2]}     compute02.novalocal\n\n# compute03\n${COMPUTE[3]}     compute03\n${COMPUTE[3]}     compute03.novalocal' /etc/hosts
    fi
    yes | sudo cp -i /home/centos/.ssh/authorized_keys /root/.ssh/authorized_keys
    sudo systemctl restart network
    "
       cat /root/.ssh/id_rsa.pub | ssh -i mycloud.pem root@${COMPUTE[$i]} "cat - >> ~/.ssh/authorized_keys"
    done

    # Atualização dos sistemas e pacotes necessários
    yum update -y && yum install -y https://rdo.fedorapeople.org/rdo-release.rpm && yum install -y tmux vim git openstack-packstack httpd iptables-services libvirt ntfs-utils &
    for i in 1 2 3; do                                                                                                                                                                        
        ssh -t root@${COMPUTE[$i]} "yum update -y" &
    done
    wait
}

#############################################################################################################
# packstack
# O script utiliza o packstack para a instalação automatizada do OpenStack. 
# O answerfile não inclui o Cinder e Heat, pois não há necessidades desses módulos para o experimento.
#############################################################################################################

packstack_install()
{

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

    # Criando chave publica para o Nova
    ssh-keygen -t rsa -b 2048 -N '' -f /root/.ssh/demokey
    nova keypair-add --pub-key /root/.ssh/demokey.pub demokey

    # Habilitando live migration

    yum -y install libvirt ntfs-utils nfs4-acl-tools portmap

    echo "/var/lib/nova/instances 10.0.10.0/24(rw,sync,fsid=0,no_root_squash)" > /etc/exports

    systemctl enable nfs-server && systemctl start nfs-server
    systemctl disable iptables && systemctl stop iptables

    for i in 1 2 3
    do
        ssh root@${COMPUTE[$i]} "
        chmod o+x /var/lib/nova/instances
        echo "controller:/ /var/lib/nova/instances nfs4 defaults 0 0" >> /etc/fstab
        sed -i '/live_migration_flag/c\live_migration_flag=VIR_MIGRATE_UNDEFINE_SOURCE, VIR_MIGRATE_PEER2PEER, VIR_MIGRATE_LIVE, VIR_MIGRATE_TUNNELLED' /etc/nova/nova.conf
        "
    done

    systemctl enable libvirtd && systemctl start libvirtd

}

##############################################################################################################
## openstack-neat
## instalação e configuração
##############################################################################################################

neat_install()
{

    cd /root && git clone https://github.com/beloglazov/openstack-neat.git

    # modificando neat.conf
    sed -i "s/neatpassword/noitosfera/" /root/openstack-neat/neat.conf
    sed -i "s/adminpassword/noitosfera/" /root/openstack-neat/neat.conf
    sed -i '/compute_hosts.*/c\compute_hosts = compute01, compute02, compute03' /root/openstack-neat/neat.conf

    # instalando neat
    cd /root/openstack-neat && python setup.py install

    # criando neat db
    mysql -u root -pnoitosfera << EOF
CREATE DATABASE neat;
GRANT ALL ON neat.* TO 'neat'@'controller' IDENTIFIED BY 'noitosfera';
GRANT ALL ON neat.* TO 'neat'@'%' IDENTIFIED BY 'noitosfera';
EOF

    # instalando neat em todos os computes
    for i in 1 2 3
    do
        scp -r /root/openstack-neat root@${COMPUTE[$i]}:~
        ssh root@${COMPUTE[$i]} "cd /root/openstack-neat && python setup.py install"
    done
    
    # openstack-neat deps
    bash /root/openstack-neat/setup/deps-centos.sh &
    for i in 1 2 3; do                               
        ssh -t root@${COMPUTE[$i]} "bash /root/openstack-neat/setup/deps-centos.sh" &
    done
    wait

}

#############################################################################################################
# Main
#############################################################################################################
    
preconfigure
packstack_install
neat_install
