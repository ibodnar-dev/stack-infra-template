APP_REPO_DIRECTORY := ../stack-app-template
APP_NS := app
IMAGE_NAME_DEV := stack-app-template-dev
IMAGE_TAG_DEV := $(IMAGE_NAME_DEV)
CLUSTER_NAME := stack
HELM_CHART_DIR := k8s/helm/app
HELM_RELEASE_NAME := app
CNPG_OPERATOR_PATH := k8s/helm/cnpg/operator
CNPG_CLUSTER_PATH := k8s/helm/cnpg/cluster
CNPG_CLUSTER_RELEASE_NAME := postgres-cluster
K8S_MANIFESTS_DIR := k8s/manifests
GATEWAY_PATH := k8s/helm/gateway
EG_RELEASE_NAME := envoy-gateway
EG_URI := oci://docker.io/envoyproxy/gateway-helm
EG_NS := envoy-gateway-system
KG_RELEASE_NAME := k8s-gateway
KG_NS := app


# kind
kd-create:
	kind create cluster --name stack

kd-delete:
	kind delete clusters stack

kd-reset: kd-delete kd-create

build-app-local-image:
	docker build -t $(IMAGE_NAME_DEV):latest -f docker/local/app.local.dockerfile $(APP_REPO_DIRECTORY)

load-app-local-image:
	kind load docker-image $(IMAGE_NAME_DEV) --name $(CLUSTER_NAME)


# k8s infra
create-ns:
	kubectl apply -f $(K8S_MANIFESTS_DIR)/ns/dev

create-secrets:
	kubectl apply -f $(K8S_MANIFESTS_DIR)/secrets/dev -n $(APP_NS)

create-k8s-infra: create-ns create-secrets


# cnpg operator
cnpg-op-install: cnpg-op-update
	helm install --namespace cnpg-system --create-namespace cnpg-operator $(CNPG_OPERATOR_PATH)

cnpg-uninstall:
	helm uninstall --namespace cnpg-system cnpg-operator
	kubectl get crd | grep cnpg | awk '{print $$1}' | xargs kubectl delete crd # uninstall CDRs too, those are cluster-scoped. Also helm has a deletion protection for CDRs

cnpg-op-update:
	helm dependency update $(CNPG_OPERATOR_PATH)


# cnpg cluster
cnpg-cluster-lint:
	helm lint $(CNPG_CLUSTER_PATH)

cnpg-cluster-install:
	kubectl apply -f $(K8S_MANIFESTS_DIR)/secrets/dev/postgres-credentials.yaml -n $(APP_NS)
	helm install $(CNPG_CLUSTER_RELEASE_NAME) $(CNPG_CLUSTER_PATH) -n $(APP_NS)

cnpg-cluster-uninstall:
	helm uninstall $(CNPG_CLUSTER_RELEASE_NAME) -n $(APP_NS)

cnpg-cluster-upgrade:
	helm upgrade -f $(CNPG_CLUSTER_PATH)/values.yaml $(CNPG_CLUSTER_RELEASE_NAME) $(CNPG_CLUSTER_PATH) -n $(APP_NS)


# app helm
app-lint:
	helm lint $(HELM_CHART_DIR)

app-install:
	helm install $(HELM_RELEASE_NAME) $(HELM_CHART_DIR) -n $(APP_NS)

app-uninstall:
	helm uninstall $(HELM_RELEASE_NAME) -n $(APP_NS)

app-upgrade:
	helm upgrade -f $(HELM_CHART_DIR)/values.yaml $(HELM_RELEASE_NAME) $(HELM_CHART_DIR) -n $(APP_NS)


# envoy gateway
eg-install-dev:
	helm install $(EG_RELEASE_NAME) $(EG_URI) \
		--version v0.0.0-latest \
		-n $(EG_NS) \
		--create-namespace \
		-f $(GATEWAY_PATH)/envoy-gateway/values.yaml

eg-upgrade-dev:
	helm upgrade $(EG_RELEASE_NAME) $(EG_URI) \
		--version v0.0.0-latest \
		--namespace $(EG_NS) \
		-f $(GATEWAY_PATH)/envoy-gateway/values.yaml

eg-uninstall:
	helm uninstall $(EG_RELEASE_NAME) -n $(EG_NS)

# k8s gateway
kg-install-dev:
	helm install $(KG_RELEASE_NAME) $(GATEWAY_PATH)/k8s-gateway\
		-n $(APP_NS) \
		-f $(GATEWAY_PATH)/k8s-gateway/values.yaml

kg-upgrade-dev:
	helm upgrade $(KG_RELEASE_NAME) $(GATEWAY_PATH)/k8s-gateway \
		-n $(APP_NS) \
		-f $(GATEWAY_PATH)/k8s-gateway/values.yaml

kg-uninstall:
	helm uninstall $(KG_RELEASE_NAME) -n $(APP_NS)
