# multicast-kube-infra: top-level Makefile
#
# All targets idempotent. Override variables on the command line:
#   make all DIST=k0s CNI=calico ENV=reference-k0s

DIST ?= k0s
CNI  ?= calico
ENV  ?= reference-k0s

DIST_DIR := distributions/$(DIST)
KUBECONFIG_PATH := $(CURDIR)/.kube/$(DIST).config

export DIST CNI ENV KUBECONFIG_PATH

.PHONY: help
help:
	@echo 'Targets:'
	@echo '  make preflight     SSH + sysctl reachability checks'
	@echo '  make bootstrap     Bring up the cluster ($(DIST))'
	@echo '  make platform      Install CNI ($(CNI)) + Multus + ESO + NADs'
	@echo '  make apps          Install bitcoin workloads via Helmfile (env=$(ENV))'
	@echo '  make verify        Smoke test (frames flow, beacons received)'
	@echo '  make all           preflight -> bootstrap -> platform -> apps -> verify'
	@echo '  make teardown      Reverse: apps -> platform -> cluster'
	@echo '  make lint          helmfile lint + helm template smoke + yamllint'
	@echo ''
	@echo 'Variables: DIST=$(DIST)  CNI=$(CNI)  ENV=$(ENV)'

.PHONY: preflight
preflight:
	@scripts/preflight.sh

.PHONY: bootstrap
bootstrap:
	@$(DIST_DIR)/bootstrap.sh

.PHONY: kubeconfig
kubeconfig:
	@scripts/fetch-kubeconfig.sh

.PHONY: platform
platform:
	@scripts/platform-apply.sh

.PHONY: label-nodes
label-nodes:
	@scripts/label-nodes.sh

.PHONY: apps
apps: label-nodes
	@KUBECONFIG=$(KUBECONFIG_PATH) helmfile -f apps/helmfile.yaml.gotmpl -e $(ENV) apply

.PHONY: verify
verify:
	@scripts/verify.sh

.PHONY: all
all: preflight bootstrap platform apps verify
	@echo 'All stages green.'

.PHONY: teardown
teardown:
	@KUBECONFIG=$(KUBECONFIG_PATH) helmfile -f apps/helmfile.yaml.gotmpl -e $(ENV) destroy || true
	@scripts/platform-destroy.sh || true
	@$(DIST_DIR)/teardown.sh || true

.PHONY: lint
lint:
	@scripts/lint.sh
