.PHONY: all ${MAKECMDGOALS}

# Extract dependency names from pyproject.toml dynamically
MAIN_DEPS = $(shell dasel -f pyproject.toml -r toml 'project.dependencies.all()' | \
	sed "s/'//g" | \
	grep -v '^git+' | \
	sed 's/@latest$$//' | \
	cut -d'=' -f1 | \
	cut -d'@' -f1 | \
	tr '\n' ' ')

help: ## Show dependency management help
	@echo "Dependency Management:"
	@echo "  make sync          Sync dependencies from pyproject.toml"
	@echo "  make update        Update all dependencies to latest versions and update pyproject.toml"

sync: ## Sync dependencies from pyproject.toml
	uv sync

update: ## Update all dependencies to latest versions and update pyproject.toml
	@echo "Updating dependencies to latest versions..."
	uv sync --upgrade
	@if uv sync --upgrade; then \
		echo "Dependencies updated successfully"; \
	else \
		exit 1 ; \
	fi
	uv lock --upgrade || true
	DEPS_REGEX=$$(echo "$(MAIN_DEPS)" | tr ' ' '|'); \
	TEMPFILE=$$(mktemp); \
	VERSIONS=$$(uv export --format requirements-txt --no-hashes | grep -E "^($$DEPS_REGEX)==" | sort); \
	if [ -n "$$VERSIONS" ]; then \
		echo "Found versions:"; \
		echo "$$VERSIONS"; \
		echo ""; \
		echo "Updating pyproject.toml ..."; \
		dasel put -f pyproject.toml -t json -v '[]' 'project.dependencies'; \
		echo "$$VERSIONS" | while read -r version; do \
			if [ -n "$$version" ]; then \
				dasel put -f pyproject.toml -t string -v "$$version" 'project.dependencies.[]'; \
			fi; \
		done; \
		echo "pyproject.toml updated successfully"; \
		dasel -r toml -f pyproject.toml --pretty > $$TEMPFILE; \
		mv $$TEMPFILE pyproject.toml; \
	else \
		echo "No versions found to update"; \
	fi; \

