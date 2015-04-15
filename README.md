# rr-script: reproducible research script

- Script de pesquisa reproduzível que cria um ambiente OpenStack com OpenStack Neat de forma automática para reprodução de experimentos futuramente realizados.

## Instruções

- O Script deve ser executado pelo usuário root em uma máquina virtual controller criada no OpenStack Juno utilizando uma imagem cloud do CentOS 7.

- Imagem CentOS utilizada: http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud-20140929_01.qcow2

- Configuração e recursos necessários para a reprodução dos experimentos:

- 3x Máquinas virtuais com 4 VCPUS cada, 80gb de disco e 8GB de RAM. (Com os hostnames, respectivamente: compute01, compute02, e compute03)
- 1x Máquina virtual com 2 VCPUS, 40gb de disco e 4GB de RAM. (hostname: controller)

- Necessário a criação de um arquivo .pem para autenticar-se à máquina controller.

##  Modo de uso: no controller, faça:

- git clone https://github.com/raphapr/rr-neat.git && cd rr-neat
- Copie o arquivo .pem do controller para a pasta atual e a renomeie para "mycloud.pem"
- Execute o script: chmod +x rr-neat.sh && ./rr-neat.sh

## TODO

- Detalhar mais o processo;
- Concluir processo do neat.
