.PHONY: all ${MAKECMDGOALS}

GIT_REPO = $(shell git config --get remote.origin.url | sed -E 's#^git@github.com:##; s#\.git$$##')
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
MAIN_DEPS = $(shell dasel -f pyproject.toml -r toml 'project.dependencies.all()' | \
	sed "s/'//g" | \
	grep -v '^git+' | \
	sed 's/@latest$$//' | \
	sed 's/>=/>/' | \
	sed 's/<=/</' | \
	cut -d'~' -f1 | \
	cut -d'>' -f1 | \
	cut -d'<' -f1 | \
	cut -d'=' -f1 | \
	cut -d'@' -f1 | \
	cut -d' ' -f1 | \
	tr '\n' ' ' | \
	uniq)
PINNED_DEPS = $(shell dasel -f pyproject.toml -r toml 'project.dependencies.all()' | \
	sed "s/'//g" | \
	grep -v '^git+' | \
	cut -d' ' -f1 | \
	cut -d'@' -f1 | \
	cut -d'.' -f 1-2 | \
	sed 's/[><=]=/~=/' | \
	tr '\n' ' ')

upgrade_deps: ## Update all dependencies to latest versions
	@echo "Updating dependencies to latest versions..."
	@\uv sync --upgrade
	@if \uv sync --upgrade; then \
		echo "Dependencies updated successfully"; \
	else \
		exit 1 ; \
	fi
	@\uv lock --upgrade || true
	@echo ${MAIN_DEPS} | xargs -r \uv remove || true
	@echo ${MAIN_DEPS} | xargs -r \uv add

update_deps:
	echo ${PINNED_DEPS}
	@echo "Updating dependencies to latest versions..."
	@echo ${MAIN_DEPS} | xargs -r \uv remove || true
	@echo ${PINNED_DEPS} | xargs -r \uv add
	@\uv lock --upgrade || true

check_deps: ## Check for unpinned dependencies
	@echo "Checking for unpinned dependencies..."
	@UNPINNED_DEPS=$$(dasel -f pyproject.toml -r toml 'project.dependencies.all()' | \
			sed "s/'//g" | \
			grep -v '^git+' | \
			grep -v '=='); \
	if [ -n "$${UNPINNED_DEPS}" ]; then \
		echo "The following dependencies are unpinned:"; \
		echo "$${UNPINNED_DEPS}"; \
		exit 1; \
	fi

lock: ## Regenerate the lock file
	@echo "Updating dependencies to latest versions...";
	TEMPFILE=$$(mktemp); \
	DEPS_REGEX=$$(echo "$(MAIN_DEPS)" | tr ' ' '|' | sort -r); \
	echo $$DEPS_REGEX; \
	VERSIONS=$$(\uv export --format requirements-txt --no-hashes | grep -E "^($$DEPS_REGEX)==" | sort); \
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
	fi;

update: update_deps lock
upgrade: upgrade_deps lock

configure:
	# Update all workflow config files to use current branch instead of @master
	@sed -i \
		-e 's#"\(pokerops-ansible-utils@git+https://github.com\).*#"\1/$(GIT_REPO)@$(GIT_BRANCH)"#' \
		devbox/molecule/config/pyproject.toml
	echo "Updating .gitignore to include .devbox/virtenv/molecule/Makefile"
	@TEMP=$$(mktemp); \
		DEVBOX_MAKEFILE=".devbox/virtenv/molecule/Makefile"; \
		if [ -f $${DEVBOX_MAKEFILE} ]; then \
			echo "include $${DEVBOX_MAKEFILE}" >> $$TEMP; \
			echo "" >> $$TEMP; \
		else \
			echo "# No $${DEVBOX_MAKEFILE} found" >> $$TEMP; \
		fi; \
		grep -v '^include $${DEVBOX_MAKEFILE}$$' Makefile >> $$TEMP || true; \
		mv $$TEMP Makefile

checkout:
	@git checkout -- devbox/molecule/config/pyproject.toml
	@git checkout -- .gitignore
	@git checkout -- Makefile
