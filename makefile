.PHONY: all start-minikube install-crossplane list-resources aws-secret \
        install-function install-provider install-providerconfig \
        apply-crd-resources apply-composition-resources apply-claim \
        verify-resources clean

all: start-minikube install-crossplane aws-secret install-provider \
     install-providerconfig install-function apply-crd-resources \
     apply-composition-resources apply-claim verify-resources

1_start-minikube:
	@echo "🚀 Iniciando cluster Minikube con perfil 'crossplane'..."
	minikube start -p crossplane

2_install-crossplane:
	@echo "📦 Instalando Crossplane..."
	helm repo add crossplane-stable https://charts.crossplane.io/stable || true
	helm install crossplane --create-namespace --namespace crossplane-system crossplane-stable/crossplane

3_list-resources:
	@echo "🔍 Listando recursos en crossplane-system..."
	kubectl get all --namespace crossplane-system

4_aws-secret:
	@echo "🔑 Creando secret AWS..."
	@test -f ./profile.txt || { echo "❌ Error: Archivo profile.txt no encontrado"; exit 1; }
	kubectl create secret generic aws-secret -n crossplane-system --from-file=creds=./profile.txt

5_install-function:
	@echo "🛠️ Instalando funciones de Crossplane..."
	@test -f ./function.yaml || { echo "❌ Error: Archivo function.yaml no encontrado"; exit 1; }
	kubectl apply -f function.yaml

6_install-provider:
	@echo "⚙️ Instalando Provider de Crossplane..."
	@test -f ./provider.yaml || { echo "❌ Error: Archivo provider.yaml no encontrado"; exit 1; }
	kubectl apply -f provider.yaml
	@echo "⏳ Esperando a que los Providers estén listos..."
	@sleep 10  # Espera inicial para que los providers comiencen a instalarse
	@for provider in $(shell kubectl get providers.pkg.crossplane.io -o name); do \
		echo "Verificando $$provider..."; \
		kubectl wait --for=condition=Healthy $$provider --timeout=300s; \
	done

6_1_verify-providers:
	@echo "🔍 Listando recursos en crossplane-system..."
	watch kubectl get all --namespace crossplane-system

7_install-providerconfig:
	@echo "🛠️ Configurando Provider..."
	@test -f ./providerconfig.yaml || { echo "❌ Error: Archivo providerconfig.yaml no encontrado"; exit 1; }
	kubectl apply -f providerconfig.yaml
	@echo "✅ Configuración del Provider aplicada"

8_apply-crd-resources:
	@echo "🌀 Aplicando recursos KCL..."
	@test -f ./resources/compositions/infra/crd.k || { echo "❌ Error: Archivo KCL no encontrado"; exit 1; }
	kcl resources/compositions/infra/crd.k | kubectl apply -f -
	@echo "✅ Recursos KCL aplicados"

9_apply-composition-resources:
	@echo "🧩 Aplicando Composition desde KCL..."
	@test -f ./resources/compositions/infra/composition.k || { echo "❌ Error: Archivo composition.k no encontrado"; exit 1; }
	kcl ./resources/compositions/infra/composition.k | kubectl apply -f -
	@echo "✅ Composition aplicada"

10_apply-claim:
	@echo "📝 Aplicando Claim..."
	@test -f ./resources/claim.yaml || { echo "❌ Error: Archivo claim.yaml no encontrado"; exit 1; }
	kubectl apply -f ./resources/claim.yaml
	@echo "✅ Claim aplicado"
	@echo "⏳ Esperando a que los recursos del Claim estén listos (esto puede tomar varios minutos)..."

11_verify-resources:
	@echo "🔍 Verificando estado de los recursos..."
	@echo "\n=== Providers ==="
	kubectl get providers.pkg.crossplane.io
	@echo "\n=== ProviderConfigs ==="
	kubectl get providerconfigs
	@echo "\n=== Compositions ==="
	kubectl get compositions
	@echo "\n=== Recursos gestionados ==="
	kubectl get managed
	@echo "\n=== Eventos recientes ==="
	kubectl get events --sort-by='.lastTimestamp' | tail -n 10

12_get-lb-hostname:
	@echo "🌐 Obteniendo hostname del LoadBalancer..."
	@kubectl get object k8s-deploy-service-team1-claim -o jsonpath='{.status.atProvider.manifest.status.loadBalancer.ingress[0].hostname}' || \
	{ echo "❌ Error al obtener el hostname. Verifica que el claim existe y el LoadBalancer está provisionado"; exit 1; }

clean:
	@echo "🧹 Limpiando recursos..."
	@kubectl delete -f ./resources/claim.yaml
	@kcl ./resources/compositions/infra/composition.k | kubectl delete -f -
	@kcl ./resources/compositions/infra/crd.k | kubectl delete -f -
	@kubectl delete -f ./providerconfig.yaml
	@kubectl delete -f ./provider.yaml
	@kubectl delete -f ./function.yaml
	@kubectl delete secret aws-secret -n crossplane-system
	helm uninstall crossplane -n crossplane-system
	minikube delete -p crossplane
	@echo "✅ Limpieza completada"