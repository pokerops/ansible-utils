.PHONY: all ${MAKECMDGOALS}

VIRTENV ?=
CI ?= false
MOLECULE_SCENARIO ?= default
MOLECULE_REVISION ?= $$(git rev-parse --abbrev-ref HEAD)
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

LOGIN_ARGS ?=

init overwrite:
	@mkdir -p .github/workflows
	@cp -a {{.Virtenv}}/.yamllint .yamllint
	@for action in {{.Virtenv}}/action_*.yml; do \
		ACTION_NAME=$$(basename $${action}); \
		ACTION_PATH=".github/workflows/$${ACTION_NAME#action_}"; \
		if [ "$@" == "overwrite" ] || [ ! -f "$${ACTION_PATH}" ]; then \
		  echo "Installing $${ACTION_NAME} to $${ACTION_PATH}"; \
			cp -a $${action} $${ACTION_PATH} || true; \
		fi \
	done;

sync install: init
	@devbox run --quiet -- uv sync --no-managed-python

lint: sync
	@devbox run --quiet -- yamllint . -c .yamllint
	@if [[ -f "${GALAXY_FILE}" || -f "${META_FILE}" ]]; then \
		devbox run --quiet -- ansible-lint -p . --exclude ".ansible/*"; \
	fi

requirements: sync
	@mkdir -p ${ROLE_DIR}
	@if [ -f "${ROLE_FILE}" ]; then \
		devbox run --quiet -- ansible-galaxy role install \
			--force --no-deps \
			--roles-path ${ROLE_DIR} \
			--role-file ${ROLE_FILE}; \
	fi
	@if [ -f "${GALAXY_FILE}" ]; then \
		devbox run --quiet -- ansible-galaxy collection install \
			--force-with-deps \
			.; \
	fi
	@find ./ -name "*.ymle*" -delete

build: requirements
	if [ -f "${GALAXY_FILE}" ]; then \
		devbox run --quiet -- uv build; \
		@git status --porcelain | wc -l | grep -q '^0$$' || (echo "Uncommitted build detected, please run build stage and commit changes" && exit 1); \
	fi

update:
	devbox run --quiet -- uv update

ifeq (login,$(firstword $(MAKECMDGOALS)))
    LOGIN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
    $(eval $(subst $(space),,$(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))):;@:)
endif

test dependency create prepare converge idempotence side-effect verify destroy cleanup reset list login:
		find .venv -type d -name ansible_collections | xargs -r -- rm -r
		rm -rf $${HOME}/.ansible/{collections,roles}
		MOLECULE_REVISION=${MOLECULE_REVISION} \
		MOLECULE_KVM_IMAGE=${MOLECULE_KVM_IMAGE} \
		MOLECULE_LOGDIR=${MOLECULE_LOGDIR} \
		devbox run --quiet -- molecule $@ -s ${MOLECULE_SCENARIO} ${LOGIN_ARGS};
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
			devbox run --quiet -- ansible-galaxy collection publish --api-key ${GALAXY_API_KEY} \
				"$${COLLECTION_NAMESPACE}-$${COLLECTION_NAME}-$${COLLECTION_VERSION}.tar.gz"
	fi
