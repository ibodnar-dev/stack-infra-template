APP_REPO_DIRECTORY := ../stack-app-template
IMAGE_NAME_DEV := stack-app-template-dev
IMAGE_TAG_DEV := $(IMAGE_NAME_DEV)
CLUSTER_NAME := stack
HELM_CHART_DIR := k8s/helm/app
HELM_RELEASE_NAME := stack-app
CNPG_OPERATOR_PATH := k8s/helm/cnpg/operator
K8S_MANIFESTS_DIR := k8s/manifests

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

# app k8s infra
create-app-ns:
	kubectl apply -f $(K8S_MANIFESTS_DIR)/ns/dev

create-k8s-infra: create-app-ns

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
