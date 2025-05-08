APP_REPO_DIRECTORY := ../stack-app-template
IMAGE_NAME_DEV := stack-app-template-dev
IMAGE_TAG_DEV := $(IMAGE_NAME_DEV)
CLUSTER_NAME := stack
HELM_CHART_DIR := k8s/helm/app
HELM_RELEASE_NAME := stack-app
CNPG_OPERATOR_PATH := k8s/helm/cnpg/operator
CNPG_CLUSTER_PATH := k8s/helm/cnpg/cluster
CNPG_CLUSTER_RELEASE_NAME := postgres-cluster
K8S_MANIFESTS_DIR := k8s/manifests
ENVOY_GATEWAY_PATH := k8s/helm/envoy-gateway
ENVOY_GATEWAY_RELEASE_NAME := envoy-gateway
ENVOY_GATEWAY_URI := oci://docker.io/envoyproxy/gateway-helm

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
	kubectl apply -f $(K8S_MANIFESTS_DIR)/secrets/dev

create-k8s-infra: create-ns


# app helm
hm-lint:
	helm lint $(HELM_CHART_DIR)

hm-install:
	helm install $(HELM_RELEASE_NAME) $(HELM_CHART_DIR)

hm-uninstall:
	helm uninstall $(HELM_RELEASE_NAME)

hm-upgrade:
	helm upgrade $(HELM_RELEASE_NAME) $(HELM_CHART_DIR)


# cnpg
hm-cnpg-op-update:
	helm dependency update $(CNPG_OPERATOR_PATH)

# Install CNPG operator
hm-cnpg-op-install: hm-cnpg-op-update
	helm install --namespace cnpg-system --create-namespace cnpg-operator $(CNPG_OPERATOR_PATH)

hm-cnpg-uninstall:
	helm uninstall --namespace cnpg-system cnpg-operator
	kubectl get crd | grep cnpg | awk '{print $$1}' | xargs kubectl delete crd # uninstall CDRs too, those are cluster-scoped. Also helm has a deletion protection for CDRs

# cnpg cluster
hm-cnpg-cluster-lint:
	helm lint $(CNPG_CLUSTER_PATH)

hm-cnpg-cluster-install:
	kubectl apply -f $(K8S_MANIFESTS_DIR)/secrets/dev/postgres-credentials.yaml -n stack
	helm install $(CNPG_CLUSTER_RELEASE_NAME) $(CNPG_CLUSTER_PATH) -n stack

hm-cnpg-cluster-uninstall:
	helm uninstall $(CNPG_CLUSTER_RELEASE_NAME) -n stack

hm-cnpg-cluster-upgrade:
	helm upgrade $(CNPG_CLUSTER_RELEASE_NAME) $(CNPG_CLUSTER_PATH) -n stack


# envoy gateway

hm-envoy-install-dev:
	helm install $(ENVOY_GATEWAY_RELEASE_NAME) $(ENVOY_GATEWAY_URI) \
		--namespace envoy-gateway-system \
		--create-namespace \
		-f $(ENVOY_GATEWAY_PATH)/values.dev.yaml

hm-envoy-install-prod:
	helm install $(ENVOY_GATEWAY_RELEASE_NAME) $(ENVOY_GATEWAY_URI) \
		--namespace envoy-gateway-system \
		--create-namespace \
		-f $(ENVOY_GATEWAY_PATH)/values.prod.yaml

hm-envoy-uninstall:
	helm uninstall $(ENVOY_GATEWAY_RELEASE_NAME) --namespace envoy-gateway-system

hm-envoy-upgrade-dev:
	helm upgrade $(ENVOY_GATEWAY_RELEASE_NAME) $(ENVOY_GATEWAY_URI) \
		--namespace envoy-gateway-system \
		-f $(ENVOY_GATEWAY_PATH)/values.dev.yaml

hm-envoy-upgrade-prod:
	helm upgrade $(ENVOY_GATEWAY_RELEASE_NAME) $(ENVOY_GATEWAY_URI) \
		--namespace envoy-gateway-system \
		-f $(ENVOY_GATEWAY_PATH)/values.prod.yaml
