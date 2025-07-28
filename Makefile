# Copyright 2024 Red Hat Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

PKG := github.com/openshift/hypershift-oadp-plugin
BIN := hypershift-oadp-plugin
IMG ?= quay.io/hypershift/hypershift-oadp-plugin:latest
VERSION ?= $(shell git describe --tags --always)

# Supported architectures and platforms
ARCHS ?= amd64 arm64
DOCKER_BUILD_ARGS ?= --platform=linux/$(ARCH)
GO=GO111MODULE=on GOWORK=off GOFLAGS=-mod=vendor go

.PHONY: install-goreleaser
install-goreleaser:
 	## Latest version of goreleaser v1. V2 requires go 1.24+
	@echo "Installing goreleaser..."
	@GOFLAGS= go install github.com/goreleaser/goreleaser@v1.26.2
	@echo "Goreleaser installed successfully!"

.PHONY: local
local: verify install-goreleaser build-dirs
	goreleaser build --snapshot --clean
	@mkdir -p dist/$(BIN)_$(VERSION)
	@mv dist/$(BIN)_*/* dist/$(BIN)_$(VERSION)/
	@rm -rf dist/$(BIN)_darwin_* dist/$(BIN)_linux_*

.PHONY: release
release: verify install-goreleaser
	goreleaser release --clean

.PHONY: release-local
release-local: verify install-goreleaser build-dirs
	GORELEASER_CURRENT_TAG=$(VERSION) goreleaser build --clean

.PHONY: tests
test:
	$(GO) test -v -timeout 60s ./...

.PHONY: cover
cover:
	$(GO) test --cover -timeout 60s ./...

.PHONY: deps
deps:
	$(GO) mod tidy && \
	$(GO) mod vendor && \
	$(GO) mod verify && \
	$(GO) list -m -mod=readonly -json all > /dev/null

.PHONY: verify
verify: verify-modules test

.PHONY: docker-build
docker-build:
	docker build -t ${IMG} .

.PHONY: docker-push
docker-push:
	docker push ${IMG}

# verify-modules ensures Go module files are up to date
.PHONY: verify-modules
verify-modules: deps
	@if !(git diff --quiet HEAD -- go.sum go.mod); then \
		echo "go module files are out of date, please commit the changes to go.mod and go.sum"; exit 1; \
	fi

.PHONY: build-dirs
build-dirs:
	@mkdir -p dist

# clean removes build artifacts from the local environment.
.PHONY: clean
clean:
	@echo "cleaning"
	rm -rf _output dist

.PHONY: install-ginkgo
install-ginkgo: ## Make sure ginkgo is in $GOPATH/bin
	go install -v -mod=mod github.com/onsi/ginkgo/v2/ginkgo

.PHONY: login-required
login-required:
ifeq ($(CLUSTER_TYPE),)
	$(error You must be logged in to a cluster to run this command)
else
	$(info $$CLUSTER_TYPE is [${CLUSTER_TYPE}])
endif

PROJECT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
define go-install-tool
@[ -f $(1) ] || { \
set -e ;\
TMP_DIR=$$(mktemp -d) ;\
cd $$TMP_DIR ;\
go mod init tmp ;\
echo "Downloading $(2)" ;\
GOBIN=$(PROJECT_DIR)/bin go install -mod=mod $(2) ;\
rm -rf $$TMP_DIR ;\
}
endef

##.PHONY: build-must-gather
##build-must-gather: ## Build OADP Must-gather binary must-gather/oadp-must-gather
##	cd must-gather && go build -mod=mod -a -o oadp-must-gather cmd/main.go

# CONFIGS FOR CLOUD
# bsl / blob storage cred dir
OADP_CRED_DIR ?= /var/run/oadp-credentials
# vsl / volume/cluster cred dir
CLUSTER_PROFILE_DIR ?= /Users/drajds/.aws

# bsl cred file
OADP_CRED_FILE ?= ${OADP_CRED_DIR}/new-aws-credentials
# vsl cred file
CI_CRED_FILE ?= ${CLUSTER_PROFILE_DIR}/.awscred

# aws configs - default
BSL_REGION ?= us-west-2
VSL_REGION ?= ${LEASED_RESOURCE}
BSL_AWS_PROFILE ?= default
# BSL_AWS_PROFILE ?= migration-engineering

# bucket file
OADP_BUCKET_FILE ?= ${OADP_CRED_DIR}/new-velero-bucket-name
# azure cluster resource file - only in CI
AZURE_RESOURCE_FILE ?= /var/run/secrets/ci.openshift.io/multi-stage/metadata.json
AZURE_CI_JSON_CRED_FILE ?= ${CLUSTER_PROFILE_DIR}/osServicePrincipal.json
AZURE_OADP_JSON_CRED_FILE ?= ${OADP_CRED_DIR}/azure-credentials

OPENSHIFT_CI ?= true
OADP_BUCKET ?= $(shell cat $(OADP_BUCKET_FILE))
SETTINGS_TMP=/tmp/test-settings

.PHONY: test-e2e-setup
test-e2e-setup: login-required #build-must-gather
	mkdir -p $(SETTINGS_TMP)
	TMP_DIR=$(SETTINGS_TMP) \
	OPENSHIFT_CI="$(OPENSHIFT_CI)" \
	PROVIDER="$(VELERO_PLUGIN)" \
	AZURE_RESOURCE_FILE="$(AZURE_RESOURCE_FILE)" \
	CI_JSON_CRED_FILE="$(AZURE_CI_JSON_CRED_FILE)" \
	OADP_JSON_CRED_FILE="$(AZURE_OADP_JSON_CRED_FILE)" \
	OADP_CRED_FILE="$(OADP_CRED_FILE)" \
	BUCKET="$(OADP_BUCKET)" \
	TARGET_CI_CRED_FILE="$(CI_CRED_FILE)" \
	VSL_REGION="$(VSL_REGION)" \
	BSL_REGION="$(BSL_REGION)" \
	BSL_AWS_PROFILE="$(BSL_AWS_PROFILE)" \
    SKIP_MUST_GATHER="$(SKIP_MUST_GATHER)" \
	/bin/bash "tests/e2e/scripts/$(CLUSTER_TYPE)_settings.sh"