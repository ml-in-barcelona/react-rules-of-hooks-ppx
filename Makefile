project_name = react-rules-of-hooks-ppx

DUNE = opam exec -- dune

.PHONY: help
help: ## Print this help message
	@echo "";
	@echo "List of available make commands";
	@echo "";
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}';
	@echo "";

.PHONY: build
build: ## Build the project
	$(DUNE) build --root . @all

.PHONY: dev
dev: ## Build in watch mode
	$(DUNE) build --root . -w @all

.PHONY: clean
clean: ## Clean artifacts
	$(DUNE) clean --root .

.PHONY: build-demo
build-demo: ## Build demo folder to test ppx errors
	BUILD_DEMO=true $(DUNE) build --root . demo/

.PHONY: dev-demo
dev-demo: ## Build demo folder in watch mode
	BUILD_DEMO=true $(DUNE) build --root . demo/ -w

.PHONY: test
test: ## Run the tests
	$(DUNE) build --root . @runtest

.PHONY: test-watch
test-watch: ## Run the tests in watch mode
	$(DUNE) build --root . @runtest -w

.PHONY: test-promote
test-promote: ## Updates snapshots and promotes it to correct
	$(DUNE) build --root . @runtest --auto-promote

.PHONY: format
format: ## Format the codebase with ocamlformat
	$(DUNE) build --root . @fmt --auto-promote

.PHONY: format-check
format-check: ## Checks if format is correct
	$(DUNE) build --root . @fmt

.PHONY: setup-githooks
setup-githooks: ## Setup githooks
	git config core.hooksPath .githooks

.PHONY: create-switch
create-switch: ## Create opam switch
	opam switch create . 5.4.0 --deps-only --with-test --no-install -y

.PHONY: install
install: ## Install dependencies
	opam install . --deps-only --with-test --with-dev-setup -y

.PHONY: init
init: create-switch install ## Create a local dev environment
