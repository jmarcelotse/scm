.DEFAULT_GOAL := kindcreate

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
