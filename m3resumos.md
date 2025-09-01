Resumo
Expondo porta SSH do Gitea pelo Ingress
O NGINX consegue expôr tanto serviços L4 quanto L7. Para isso vamos configurar o values do Chart:

tcp:
  22: "gitea/gitea-ssh:22"
Com isso, o Service do NGINX vai abrir a porta 22, e qualquer requisição ali, será enviado para o Service gitea-ssh na namespace gitea.

Exposing TCP and UDP services - Ingress-Nginx Controller
https://kubernetes.github.io/ingress-nginx/user-guide/exposing-tcp-udp-services/