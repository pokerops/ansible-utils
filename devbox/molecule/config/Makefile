.PHONY: all ${MAKECMDGOALS}

UV := $(shell if [ -f pyproject.toml ]; then echo uv; else echo "uv --directory {{.Virtenv}}"; fi)
MOLECULE_SCENARIO ?= default
MOLECULE_LOGDIR ?= /tmp/logs
UBUNTU_RELEASE ?= noble
UBUNTU_KVM_IMAGE = https://cloud-images.ubuntu.com/${UBUNTU_RELEASE}/current/${UBUNTU_RELEASE}-server-cloudimg-amd64.img
MOLECULE_KVM_IMAGE ?= $(UBUNTU_KVM_IMAGE)
GALAXY_API_KEY ?=
GALAXY_FILE = galaxy.yml
META_FILE = meta/main.yml
REQUIREMENTS = requirements.yml
ROLE_DIR = roles
ROLE_FILE = roles.yml

BASE_SHA ?= $$(git rev-parse origin)
HEAD_SHA ?= $$(git rev-parse HEAD)
BASE_VERSION := $$(git show $(BASE_SHA):galaxy.yml | yq -r .version)
HEAD_VERSION := $$(git show $(HEAD_SHA):galaxy.yml | yq -r .version)

LOGIN_ARGS ?=
VERSION_CHECK_ARGS ?=

init overwrite:
	@mkdir -p .github/workflows
	@for action in {{.Virtenv}}/action_*.yml; do \
		ACTION_NAME=$$(basename $${action}); \
		ACTION_PATH=".github/workflows/$${ACTION_NAME#action_}"; \
		if [[ "$@" == "overwrite" ]] || [[ ! -f "$${ACTION_PATH}" ]]; then \
			echo "Installing $${ACTION_NAME} to $${ACTION_PATH}"; \
			cp -a $${action} $${ACTION_PATH} || true; \
		fi \
	done;

sync install: init
	@${UV} sync --no-managed-python

lint: sync
	@yamllint . -c $$([ -f .yamllint ] && echo .yamllint || echo '{{.Virtenv}}/.yamllint');
	@if [[ -f "${GALAXY_FILE}" || -f "${META_FILE}" ]]; then \
		ansible-lint -p . --exclude ".ansible/*"; \
	fi

requirements: clean sync
	@mkdir -p ${ROLE_DIR}
	@if [ -f "${ROLE_FILE}" ]; then \
		ansible-galaxy role install \
			--force --no-deps \
			--roles-path ${ROLE_DIR} \
			--role-file ${ROLE_FILE}; \
	fi
	@if [ -f "${GALAXY_FILE}" ]; then \
		ansible-galaxy collection install \
			--force-with-deps \
			.; \
	fi
	@find ./ -name "*.ymle*" -delete

build: requirements
	if [ -f "${GALAXY_FILE}" ]; then \
		${UV} build; \
		@git status --porcelain | wc -l | grep -q '^0$$' || (echo "Uncommitted build detected, please run build stage and commit changes" && exit 1); \
	else
		echo "No ${GALAXY_FILE} found, skipping build"; \
	fi

update:
	${UV} update

ifeq (login,$(firstword $(MAKECMDGOALS)))
    LOGIN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
    $(eval $(subst $(space),,$(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))):;@:)
endif

test dependency create prepare converge idempotence side-effect verify destroy cleanup reset list login:
		find .venv -type d -name ansible_collections | xargs -r -- rm -r
		MOLECULE_KVM_IMAGE=${MOLECULE_KVM_IMAGE} \
		MOLECULE_LOGDIR=${MOLECULE_LOGDIR} \
		molecule $@ -s ${MOLECULE_SCENARIO} ${LOGIN_ARGS};
		@if [ "$@" = "destroy" ] || [ "$@" = "cleanup" ] || [ "$@" = "reset" ]; then \
			$(MAKE) clean; \
		fi

clean:
		rm -rf $${HOME}/.ansible/{collections,roles}

publish: build
	if [ -z "${GALAXY_API_KEY}" ]; \
		then echo "GALAXY_API_KEY is not set"; \
		exit 1; \
	fi
	if [ -f "${GALAXY_FILE}" ]; \
		COLLECTION_NAMESPACE=$$(yq -r '.namespace' ${GALAXY_FILE}) \
		COLLECTION_NAME=$$(yq -r '.name' ${GALAXY_FILE}) \
		COLLECTION_VERSION=$$(yq -r '.version' ${GALAXY_FILE}) \
			ansible-galaxy collection publish --api-key ${GALAXY_API_KEY} \
				"$${COLLECTION_NAMESPACE}-$${COLLECTION_NAME}-$${COLLECTION_VERSION}.tar.gz"
	fi

version-check:
		# Validate semver format
		if ! echo "$(HEAD_VERSION)" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'; then
			echo "$(HEAD_VERSION) does not follow standard semver format (X.Y.Z)"
			exit 1
		fi
		# Check version is updated
		if [ "$(BASE_VERSION)" = "$(HEAD_VERSION)" ]; then
			echo "::error title=Version Not Updated::Version has not been updated in galaxy.yml (still $(BASE_VERSION))"
			exit 1
		fi
		# Verify version update sequence
		LOWER_VERSION=$(printf '%s\n' "$BASE_VERSION" "$HEAD_VERSION" | sort -V | head -n1)
		if [ "$(LOWER_VERSION)" = "$(HEAD_VERSION)" ]; then
			echo "New version ($(HEAD_VERSION)) must be greater than base version ($(BASE_VERSION))"
			exit 1
		fi
		echo "Version updated from $(BASE_VERSION) to $(HEAD_VERSION)"
