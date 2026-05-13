# Copyright 2024 The Kubernetes Authors.
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

# Go parameters
GO ?= go
GOFMT ?= gofmt
GOLINT ?= golangci-lint
GOBUILD = $(GO) build
GOTEST = $(GO) test
GOVET = $(GO) vet

# Build parameters
BINARY_NAME ?= agent-sandbox
BUILD_DIR ?= bin
CMD_DIR ?= cmd/agent-sandbox

# Version information
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
GIT_COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

LDFLAGS := -ldflags "-X main.version=$(VERSION) -X main.gitCommit=$(GIT_COMMIT) -X main.buildDate=$(BUILD_DATE)"

# Image parameters
IMAGE_REGISTRY ?= gcr.io/k8s-staging-agent-sandbox
IMAGE_NAME ?= agent-sandbox
IMAGE_TAG ?= $(VERSION)
IMAGE ?= $(IMAGE_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: all
all: build

## build: Build the binary
.PHONY: build
build:
	@mkdir -p $(BUILD_DIR)
	$(GOBUILD) $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) ./$(CMD_DIR)/...

## test: Run unit tests
.PHONY: test
test:
	$(GOTEST) -v -race -coverprofile=coverage.out ./...

## test-coverage: Run tests and display coverage report
.PHONY: test-coverage
test-coverage: test
	$(GO) tool cover -html=coverage.out

## lint: Run linter
.PHONY: lint
lint:
	$(GOLINT) run ./...

## fmt: Format Go code
.PHONY: fmt
fmt:
	$(GOFMT) -s -w .

## fmt-check: Check Go code formatting
.PHONY: fmt-check
fmt-check:
	@diff=$$($(GOFMT) -s -d .); \
	if [ -n "$$diff" ]; then \
		echo "$$diff"; \
		exit 1; \
	fi

## vet: Run go vet
.PHONY: vet
vet:
	$(GOVET) ./...

## verify: Run all verification checks
.PHONY: verify
verify: fmt-check vet lint

## docker-build: Build Docker image
.PHONY: docker-build
docker-build:
	docker build -t $(IMAGE) .

## docker-push: Push Docker image
.PHONY: docker-push
docker-push:
	docker push $(IMAGE)

## clean: Clean build artifacts
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR) coverage.out

## generate: Run code generation
.PHONY: generate
generate:
	$(GO) generate ./...

## tidy: Tidy Go modules
.PHONY: tidy
tidy:
	$(GO) mod tidy

## deps: Download and verify dependencies
.PHONY: deps
deps:
	$(GO) mod download
	$(GO) mod verify

## help: Display this help message
.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@awk '/^## / { \
		sub(/^## /, ""); \
		split($$0, a, ":"); \
		printf "  %-20s %s\n", a[1], a[2] \
	}' $(MAKEFILE_LIST)
