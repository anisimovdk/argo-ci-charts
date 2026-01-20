.PHONY: help build push lint clean login

# Configuration
REGISTRY ?= docker.io
REPOSITORY ?= anisimovdk
CHARTS_DIR := charts
DIST_DIR := dist

# Get all chart directories
CHARTS := $(shell find $(CHARTS_DIR) -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

$(DIST_DIR):
	@mkdir -p $(DIST_DIR)

lint: ## Lint all charts
	@echo "Linting charts..."
	@for chart in $(CHARTS); do \
		echo "Linting $$chart..."; \
		helm lint $(CHARTS_DIR)/$$chart || exit 1; \
	done
	@echo "All charts passed linting"

build: $(DIST_DIR) lint ## Build (package) all charts
	@echo "Building charts..."
	@for chart in $(CHARTS); do \
		echo "Packaging $$chart..."; \
		helm package $(CHARTS_DIR)/$$chart -d $(DIST_DIR) || exit 1; \
	done
	@echo "All charts built successfully"

login: ## Login to Docker Hub registry (requires DOCKER_PASSWORD env var, DOCKER_USERNAME defaults to REPOSITORY)
	@if [ -z "$(DOCKER_PASSWORD)" ]; then \
		echo "Error: DOCKER_PASSWORD must be set"; \
		exit 1; \
	fi
	@USERNAME=$${DOCKER_USERNAME:-$(REPOSITORY)}; \
	echo "$(DOCKER_PASSWORD)" | helm registry login $(REGISTRY) --username $$USERNAME --password-stdin
	@echo "Logged in to $(REGISTRY)"

push: build ## Build and push all charts to OCI registry
	@echo "Pushing charts to $(REGISTRY)/$(REPOSITORY)..."
	@for chart in $(CHARTS); do \
		CHART_VERSION=$$(helm show chart $(CHARTS_DIR)/$$chart | grep '^version:' | awk '{print $$2}'); \
		CHART_PACKAGE=$(DIST_DIR)/$$chart-$$CHART_VERSION.tgz; \
		if [ ! -f $$CHART_PACKAGE ]; then \
			echo "Error: Chart package $$CHART_PACKAGE not found"; \
			exit 1; \
		fi; \
		echo "Pushing $$chart version $$CHART_VERSION..."; \
		helm push $$CHART_PACKAGE oci://$(REGISTRY)/$(REPOSITORY) || exit 1; \
	done
	@echo "All charts pushed successfully"

clean: ## Remove build artifacts
	@echo "Cleaning up..."
	@rm -rf $(DIST_DIR)
	@echo "Cleaned dist directory"

# Individual chart targets
define CHART_TARGETS
lint-$(1): ## Lint specific chart: $(1)
	@echo "Linting $(1)..."
	@helm lint $(CHARTS_DIR)/$(1)

build-$(1): $(DIST_DIR) lint-$(1) ## Build specific chart: $(1)
	@echo "Building $(1)..."
	@helm package $(CHARTS_DIR)/$(1) -d $(DIST_DIR)

push-$(1): build-$(1) ## Build and push specific chart: $(1)
	@CHART_VERSION=$$$$(helm show chart $(CHARTS_DIR)/$(1) | grep '^version:' | awk '{print $$$$2}'); \
	CHART_PACKAGE=$(DIST_DIR)/$(1)-$$$$CHART_VERSION.tgz; \
	echo "Pushing $(1) version $$$$CHART_VERSION to $(REGISTRY)/$(REPOSITORY)..."; \
	helm push $$$$CHART_PACKAGE oci://$(REGISTRY)/$(REPOSITORY)
endef

$(foreach chart,$(CHARTS),$(eval $(call CHART_TARGETS,$(chart))))
