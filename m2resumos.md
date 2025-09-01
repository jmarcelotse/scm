Resumo
Deploy MetalLB
O MetalLB será utilizado para prover endereços IP externos para o LoadBalancer. Dessa forma, poderemos ter um único ponto de entrada (Ingress) roteando para os nossos serviços de infraestrutura internos.

Aqui temos a documentação do MetalLB com Kind (algo mais específico):

kind – LoadBalancer

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml

kubectl wait --namespace metallb-system \
		--for=condition=ready pod \
		--selector=app=metallb \
		--timeout=120s
Podemos adicionar um step no nosso Makefile de pre (pré-requisitos) e executar após subir o cluster.

pre:
	# ref:
	# https://kind.sigs.k8s.io/docs/user/loadbalancer/#installing-metallb-using-default-manifests
	@kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
	@kubectl wait --namespace metallb-system \
		--for=condition=ready pod \
		--selector=app=metallb \
		--timeout=120s
E lembrando que podemos “combar” steps no nosso Makefile.

up: create pre
E não menos importante, ter um passo default do make.

.DEFAULT_GOAL := up
Setup MetalLB
Para que o MetalLB consiga distribuir endereços IP para os Services do tipo LoadBalancer, precisamos configurar a pool.

Vamos escolher um IP baseado na rede do nosso cluster Kubernetes.

Primeiro precisamos identificar qual a rede usada pelo Kind, e com isso a faixa de IP.

$ docker network ls | grep kind
$ docker inspect <network>
$ docker inspect kind | jq -r '.[].IPAM.Config[0].Subnet'
Com isso, vamos preencher o YAML abaixo.

apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: homelab-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.21.0.50-172.21.0.100
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: home-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - homelab-pool
Por exemplo, se o endereço da rede é 172.21.0.0/16, a faixa poderia ser como a acima.

Se você estiver em um MacOS ou Windows, provavelmente terá que usar a faixa de IPs da rede da sua casa (exemplo 192.168…). Somente o Linux suporta o envio de requests direto para o Docker container.

Deploy NGINX Ingress Controller
Helm é a forma meio que “padrão” para instalação de aplicações no Kubernetes por vário motivos. O principal talvez seja ter tudo o que a aplicação precisa empacotado.

Bom, vamos fazer a instalação e personalização do NGINX Ingress Controller e verificar seu comportamento.



$ helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
$ helm repo update
$ helm search repo ingress-nginx
$ helm upgrade --install \
		--namespace ingress-nginx \
		--create-namespace \
		-f values.yaml \
		ingress-nginx ingress-nginx/ingresss
Introdução ao Helmfile
Como você já deve ter percebido, esse processo de configurar values e instalar manualmente é chato. Por mais que isso seja muito mai simples que montar os manifestos um a um, ainda é possível melhorar e cria um processo que possa se repetir mais facilmente.

Com isso em mente, quero apresentar uma ferramenta incrível que poucos conhecem: Helmfile.

Ele é um orquestrador para Helm, uma camada de abstração em cima dele, de forma declarativa.

GitHub - helmfile/helmfile: Declaratively deploy your Kubernetes manifests, Kustomize configs, and Charts as Helm releases. Generate all-in-one manifests for use with ArgoCD.

helmfile

Migrando NGINX para Helmfile
repositories:
  - name: nginx
    url: https://kubernetes.github.io/ingress-nginx

releases:
- name: ingress-nginx
  namespace: ingress-nginx
  createNamespace: true
  chart: nginx/ingress-nginx
  version: 4.4.2
  values:
    - values/nginx/values.yaml
$ helmfile apply
Agora é basicamente ir declarando outras releases de outras ferramentas e ir dando o helmfile apply para instalar.

Também fica legal adicionar isso no nosso Makefile.

helm:
	@helmfile apply

up: create pre helm
Deploy Jenkins
Aqui estão os repos:

GitHub - jenkinsci/helm-charts: Jenkins helm charts

helm-chart

O Jenkins será o nosso CI/CD, e o Gitea será o nosso SCM (onde vamos armazenar o código da aplicação).

A única coisa que vamos modificar nesse primeiro momento é o Ingress, expondo em uma URL que vamos “hardcodar” localmente rsrs.

ingress:
  enabled: true
  className: nginx
  annotations: {}
  hosts:
    - host: gitea.localhost.com
      paths:
        - path: /
          pathType: Prefix
Deploy Harbor
GitHub - goharbor/harbor-helm: The helm chart to deploy Harbor

Quanto ao Harbor, há algumas mudanças que precisamos fazer para que tudo ocorra como planejado.

expose:
  type: ingress
  tls:
    enabled: false

ingress:
  hosts:
    core: harbor.localhost.com

externalURL: http://harbor.localhost.com
Deploy SonarQube
GitHub - SonarSource/helm-chart-sonarqube

Já o Sonarqube vamos alterar somente o Ingress mesmo.

ingress:
  enabled: true
  # Used to create an Ingress record.
  hosts:
    - name: sonarqube.localhost.com
Deploy ArgoCD
Não menos importante, vamos usar o ArgoCD como nossa ferramenta de GitOps (sincronizar o cluster à partir do Git), enquanto o ImagePullSecret-Patcher vai garantir que todas as namespaces e ServiceAccounts tenham o secret necessário para fazer pull de imagens do Harbor.

Começando pelo ArgoCD, vamos configurar ele para rodar como HTTP.

server.insecure: true

ingress:
  enabled: true
  hosts:
  - argocd.localhost.com
Deploy ImagePullSecret-Patcher
Quanto ao ImagePullSecret-Patcher, o único parâmetro que temos que personalizar é o secretName:

secretName: "harbor-credentials"
Isto é, o secret que ele deve injetar em todas as ServiceAccounts de todas as namespaces. Por enquanto esse secret ainda não existe, pois quero mostrar o problema ocorrendo futuramente, para depois ajustarmos tudo.