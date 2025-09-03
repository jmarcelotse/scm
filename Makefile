.PHONY: pre helm create up destroy stop start status test passwd

pre:

	@kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml
	@kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=300s
	@kubectl apply -f ../k8s/manifests

helm:
	@helmfile apply || true
	@echo "Aguardando Ingress NGINX ficar pronto..."
	@kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s
	@echo "Instalando ArgoCD..."
	@helmfile -l name=argocd apply

create:
	@kind create cluster --config ../k8s/config.yaml

  up: create pre helm

destroy:
	@kind delete clusters kind

stop:
	@echo "🛑 Parando projeto CI/CD..."
	@docker stop $$(docker ps -q --filter name=kind) 2>/dev/null || echo "ℹ️  Nenhum container Kind rodando"
	@echo "✅ Projeto parado - dados preservados"

start:
	@echo "🚀 Reiniciando projeto CI/CD..."
	@docker start $$(docker ps -a -q --filter name=kind) 2>/dev/null || { echo "❌ Execute 'make up' primeiro"; exit 1; }
	@echo "⏳ Aguardando cluster..."
	@sleep 10
	@kubectl cluster-info --request-timeout=30s > /dev/null 2>&1 && echo "✅ Cluster pronto!" || echo "⏳ Ainda inicializando..."

status:
	@echo "📊 Status do Projeto CI/CD"
	@echo "=========================="
	@if [ -z "$$(docker ps -a -q --filter name=kind)" ]; then \
		echo "❌ Projeto não existe - Execute: make up"; \
	elif [ -z "$$(docker ps -q --filter name=kind)" ]; then \
		echo "🛑 Projeto PARADO - Execute: make start"; \
	else \
		echo "✅ Projeto RODANDO"; \
		kubectl get pods -A --no-headers 2>/dev/null | grep -v Running | grep -v Completed || echo "✅ Todos os pods rodando"; \
	fi

test:
	@echo "🔗 Testando conectividade dos serviços..."
	@services="jenkins.localhost.com gitea.localhost.com harbor.localhost.com sonarqube.localhost.com argocd.localhost.com"; \
	for service in $$services; do \
		echo -n "$$service: "; \
		if curl -s --connect-timeout 5 --max-time 10 -o /dev/null http://$$service; then \
			echo "✅ OK"; \
		else \
			echo "❌ FALHA"; \
		fi; \
	done

passwd:
	@echo "=== CI/CD Services Credentials ==="
	@echo ""
	@echo "Jenkins (http://jenkins.localhost.com)"
	@echo "User: admin"
	@echo -n "Password: "
	@kubectl get secrets -n jenkins jenkins -o json | jq -r '.data."jenkins-admin-password"' | base64 -d
	@echo ""
	@echo ""
	@echo "SonarQube (http://sonarqube.localhost.com)"
	@echo "User: admin"
	@echo "Password: admin (change on first login)"
	@echo ""
	@echo "Harbor (http://harbor.localhost.com)"
	@echo "User: admin"
	@echo "Password: Harbor12345"
	@echo ""
	@echo "ArgoCD (http://argocd.localhost.com)"
	@echo "User: admin"
	@echo -n "Password: "
	@kubectl get secrets -n argocd argocd-initial-admin-secret -o json | jq -r '.data."password"' | base64 -d
	@echo ""
