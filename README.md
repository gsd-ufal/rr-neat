# rr-script

- Esse bash script cria um ambiente reproduzível de forma automática, onde é configurado um controller OpenStack e a quantidade de computes desejados através do packstack seguido da instalação do OpenStack Neat.

- O Script deve ser executado pelo usuário root em uma máquina virtual criada no OpenStack (Havana/IceHouse/Juno) utilizando uma imagem cloud do CentOS 7.

- Imagem CentOS utilizada: http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud-20140929_01.qcow2

- Necessário a criação de um arquivo .pem para autenticar-se à máquina controller.

- Instruções:

# git clone https://github.com/raphapr/rr-neat
# chmod +x rr-script.sh
# ./rr-script.sh
