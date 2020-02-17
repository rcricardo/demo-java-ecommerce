Projeto AppDemoJava

    ansible/ccc-ansible-build.sh      - script que gera o inventario do ansible
    ansible/playbook-demo-java.yml    - playbook do ansible que instala softwares nas VMs
    cloudcenter/ccc-tier-addresses.sh - script que retorna enderecos das VMs criadas pelo cloud center
    gobetween/gobetween-build-conf.sh - script que gera configuracao do balanceador
    gobetween/gobetween.service       - servico gobetween empurrado via ansible para VMs dos balanceadores
    gobetween/gobetween.toml.header   - cabecalho da configuracao do balanceador
    route53/update-route53.sh         - script que atualiza o route53 com os IPs dos balanceadores
    telegram-bot-send/main.go         - script usado em pipeline jenkins para solicitar aprovacao via telegram/bot
    tomcat/tomcat.service             - servico tomcat empurrado via ansible para VMs da aplicacao
    uol                               - aplicacao JSP empurrada via ansible para VMs da aplicacao
