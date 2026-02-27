export

.EXPORT_ALL_VARIABLES:
.PHONY: all ${MAKECMDGOALS}

SHELL := /bin/bash

UV := \uv --python-preference=only-managed
PYPROJECT = $(shell if [ ! -f pyproject.toml ]; then echo "--directory {{.Virtenv}}"; fi)
MOLECULE_SCENARIO ?= default
MOLECULE_LOGDIR ?= /tmp/logs
UBUNTU_RELEASE ?= noble
UBUNTU_KVM_IMAGE = https://cloud-images.ubuntu.com/${UBUNTU_RELEASE}/current/${UBUNTU_RELEASE}-server-cloudimg-amd64.img
MOLECULE_KVM_IMAGE ?= $(UBUNTU_KVM_IMAGE)
GALAXY_API_KEY ?=
GALAXY_FILE = ${DEVBOX_PROJECT_ROOT}/galaxy.yml
RUNTIME_FILE= ${DEVBOX_PROJECT_ROOT}/meta/runtime.yml
META_FILE = ${DEVBOX_PROJECT_ROOT}/meta/main.yml
REQUIREMENTS = ${DEVBOX_PROJECT_ROOT}/requirements.yml
ROLE_DIR = ${DEVBOX_PROJECT_ROOT}/roles
ROLE_FILE = ${DEVBOX_PROJECT_ROOT}/roles.yml

GITHUB_REPOSITORY ?= $(shell git config --get remote.origin.url | sed -E 's#(git@|https://|http://)[^/:]+[:/](.+?)(\.git)?$$#\2#')
GITHUB_ORGANIZATION ?= $(shell echo $(GITHUB_REPOSITORY) | cut -d/ -f 1)
GITHUB_REPO ?= $(shell echo $(GITHUB_REPOSITORY) | cut -d/ -f 2)

LOGIN_ARGS ?=
VERSION_CHECK_ARGS ?=

debug:
	@echo "DEVBOX_PROJECT_ROOT=${DEVBOX_PROJECT_ROOT}"
	@echo "GALAXY_FILE=$(GALAXY_FILE)"
	@echo "RUNTIME_FILE=$(RUNTIME_FILE)"
	@echo "META_FILE=$(META_FILE)"
	@echo "REQUIREMENTS=$(REQUIREMENTS)"
	@echo "ROLE_DIR=$(ROLE_DIR)"
	@echo "ROLE_FILE=$(ROLE_FILE)"
	@echo "GITHUB_REPOSITORY=$(GITHUB_REPOSITORY)"
	@echo "GITHUB_ORGANIZATION=$(GITHUB_ORGANIZATION)"
	@echo "GITHUB_REPO=$(GITHUB_REPO)"

init overwrite:
	@mkdir -p .github/workflows
	echo "Processing common actions"
	@for action in {{.Virtenv}}/action_all_*.yml; do \
		ACTION_SOURCE=$$(basename $${action}); \
		ACTION_PATH=".github/workflows/$${ACTION_SOURCE#action_all_}"; \
		if [ "$@" == "overwrite" ] || [ ! -f "$${ACTION_PATH}" ]; then \
			echo "Installing action to $${ACTION_PATH}"; \
			cp -a $${action} $${ACTION_PATH} || true; \
		fi \
	done;
	@if [ -f $(GALAXY_FILE) ]; then \
		echo "Processing collection actions"; \
		for action in {{.Virtenv}}/action_collection_*.yml; do \
			ACTION_SOURCE=$$(basename $${action}); \
			ACTION_PATH=".github/workflows/$${ACTION_SOURCE#action_collection_}"; \
			if [ "$@" == "overwrite" ] || [ ! -f "$${ACTION_PATH}" ]; then \
				echo "Installing action to $${ACTION_PATH}"; \
				cp -a $${action} $${ACTION_PATH} || true; \
			fi \
		done; \
	fi
	@if [ -f $(META_FILE) ]; then \
		echo "Processing role actions"; \
		for action in {{.Virtenv}}/action_role_*.yml; do \
			ACTION_SOURCE=$$(basename $${action}); \
			ACTION_PATH=".github/workflows/$${ACTION_SOURCE#action_role_}"; \
			if [ "$@" == "overwrite" ] || [ ! -f "$${ACTION_PATH}" ]; then \
				echo "Installing action to $${ACTION_PATH}"; \
				cp -a $${action} $${ACTION_PATH} || true; \
			fi \
		done; \
	fi

sync install:
	${UV} $(PYPROJECT) sync --only-dev
	@if [ -f ${GALAXY_FILE} ]; then \
		${UV} run -- ansible-galaxy collection install --force-with-deps .; \
	fi

lint: install
	@${UV} run -- yamllint . -c $$([ -f .yamllint ] && echo .yamllint || echo '{{.Virtenv}}/.yamllint');
	@if [ -f "${GALAXY_FILE}" ]; then \
		if [ ! -f "$(RUNTIME_FILE)" ]; then \
			echo "No $(RUNTIME_FILE) found"; \
		elif [ "$(yq < $(RUNTIME_FILE) '.requires_ansible' -r)" = "null" ]; then \
			echo "No 'requires_ansible' field found in $(RUNTIME_FILE)"; \
			exit 1; \
		fi; \
	fi
	@if [ -f "${GALAXY_FILE}" ] || [ -f "${META_FILE}" ]; then \
		${UV} run -- ansible-lint -p . --exclude ".ansible/*"; \
	fi

requirements: clean install
	@mkdir -p $(ROLE_DIR)
	@if [ -f $(REQUIREMENTS) ]; then \
		${UV} run -- ansible-galaxy collection install \
			--force-with-deps \
			--requirements-file $(REQUIREMENTS); \
	fi
	@if [ -f "$(ROLE_FILE)" ]; then \
		${UV} run -- ansible-galaxy role install \
			--force --no-deps \
			--roles-path $(ROLE_DIR) \
			--role-file $(ROLE_FILE); \
	fi
	@find ./ -name "*.ymle*" -delete

build: requirements
	@echo "Checking for uncommitted build changes..."
	@git status --porcelain
	@git status --porcelain | \
		grep -v "devbox/molecule/config/pyproject.toml$$" | \
		wc -l | \
		grep -q '^0$$' || \
		(echo "Uncommitted build detected, please run build stage and commit changes" && exit 1)
	@if [ -f "$(GALAXY_FILE)" ]; then \
		ansible-galaxy collection build --force .; \
	else \
		echo "No $(GALAXY_FILE) found, skipping ansible collection build"; \
	fi
	@if [ -f pyproject.toml ]; then \
		${UV} build; \
	fi

deploy:
	${UV} run -- ansible-galaxy collection install --force-with-deps .

local:
	${UV} run -- ansible-galaxy collection install --force .

ifeq (login,$(firstword $(MAKECMDGOALS)))
    LOGIN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
    $(eval $(subst $(space),,$(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))):;@:)
endif

test dependency create prepare converge idempotence side-effect verify destroy cleanup reset list login:
		@if [ -d .venv ]; then \
		  find ${PROJECT_ROOT}/.venv -type d -name ansible_collections | xargs -r -- rm -r; \
		fi
		@if [ -f "$(META_FILE)" ]; then \
			SCENARIO_DIR="$$(pwd)/molecule/$(MOLECULE_SCENARIO)/"; \
			if [ -d "$${SCENARIO_DIR}" ]; then \
			  mkdir -p $${SCENARIO_DIR}/roles; \
				ROLE_LINK=$${SCENARIO_DIR}/roles/$$(yq -r '.galaxy_info.author' $(META_FILE)).$$(yq -r '.galaxy_info.role_name' $(META_FILE)); \
				rm -f $${ROLE_LINK} ; \
				ln -sf $$(pwd) $${ROLE_LINK} ; \
			fi; \
		fi
		${UV} run -- molecule $@ -s ${MOLECULE_SCENARIO} $(LOGIN_ARGS);
		@if [ "$@" = "destroy" ] || [ "$@" = "cleanup" ] || [ "$@" = "reset" ]; then \
			$(MAKE) clean; \
		fi

clean:
		rm -rf $${HOME}/.ansible/{collections,roles}

publish: build
	@if [ -z "${GALAXY_API_KEY}" ]; then \
		echo "GALAXY_API_KEY is not set"; \
		exit 1; \
	fi
	@if [ -f "${GALAXY_FILE}" ]; then \
		export COLLECTION_NAMESPACE=$$(yq -r '.namespace' $(GALAXY_FILE)); \
		export COLLECTION_NAME=$$(yq -r '.name' $(GALAXY_FILE)); \
		export COLLECTION_VERSION=$$(yq -r '.version' $(GALAXY_FILE)); \
		echo COLLECTION_NAMESPACE=$${COLLECTION_NAMESPACE}; \
		echo COLLECTION_NAME=$${COLLECTION_NAME}; \
		echo COLLECTION_VERSION=$${COLLECTION_VERSION}; \
		ansible-galaxy collection publish --api-key $${GALAXY_API_KEY} \
			"$${COLLECTION_NAMESPACE}-$${COLLECTION_NAME}-$${COLLECTION_VERSION}.tar.gz"; \
	else \
		echo GITHUB_REPOSITORY=$(GITHUB_REPOSITORY); \
		echo GITHUB_ORGANIZATION=$(GITHUB_ORGANIZATION); \
		echo GITHUB_REPO=$(GITHUB_REPO); \
		ansible-galaxy role import \
			--api-key $(GALAXY_API_KEY) $(GITHUB_ORGANIZATION) $(GITHUB_REPO); \
	fi

version-check:
	if [ -z "$${BASE_SHA}" ] || [ -z "$${HEAD_SHA}" ]; then \
	  BASE_SHA=$$(git rev-parse master); \
		HEAD_SHA=$$(git rev-parse HEAD); \
	fi; \
	if [ "$${BASE_SHA}" = "$${HEAD_SHA}" ]; then \
		echo "No changes detected between base ($${BASE_SHA}) and head ($${HEAD_SHA})"; \
		exit 0; \
	fi; \
	BASE_VERSION=$$(if [ -f $(GALAXY_FILE) ]; then git show $${BASE_SHA}:$(GALAXY_FILE) | yq -r '.version // ""'; else echo ""; fi); \
	HEAD_VERSION=$$(if [ -f $(GALAXY_FILE) ]; then git show $${HEAD_SHA}:$(GALAXY_FILE) | yq -r '.version // ""'; else echo ""; fi); \
	MIN_VERSION=$$(printf '%s\n' "$${BASE_VERSION}" "$${HEAD_VERSION}" | sort -V | head -n1); \
	echo "Running version check for ${GALAXY_FILE}..."; \
	echo "BASE SHA: $${BASE_SHA}"; \
	echo "HEAD SHA: $${HEAD_SHA}"; \
	echo "BASE VERSION: $${BASE_VERSION}"; \
	echo "HEAD VERSION: $${HEAD_VERSION}"; \

code:
	@claude code .
