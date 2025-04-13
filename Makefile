APP_REPO_DIRECTORY := ../stack-app-template
IMAGE_NAME_DEV := stack-app-template-dev
IMAGE_TAG_DEV := $(IMAGE_NAME_DEV)
CLUSTER_NAME := stack

kd-create:
	kind create cluster --name stack

kd-delete:
	kind delete clusters stack

kd-reset: kd-delete kd-create

build-app-local-image:
	docker build -t $(IMAGE_NAME_DEV) -f docker/local/app.local.dockerfile $(APP_REPO_DIRECTORY)

load-app-local-image:
	kind load docker-image $(IMAGE_NAME_DEV) --name $(CLUSTER_NAME)
