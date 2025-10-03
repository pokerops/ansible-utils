.PHONY: all ${MAKECMDGOALS}

MOLECULE_SCENARIO ?= default
MOLECULE_REVISION ?= $$(git rev-parse --abbrev-ref HEAD)
UBUNTU_RELEASE ?= noble
UBUNTU_KVM_IMAGE = https://cloud-images.ubuntu.com/${UBUNTU_RELEASE}/current/${UBUNTU_RELEASE}-server-cloudimg-amd64.img
MOLECULE_KVM_IMAGE := $(UBUNTU_KVM_IMAGE)
GALAXY_API_KEY ?=
GALAXY_FILE = galaxy.yml
REQUIREMENTS = requirements.yml
ROLE_DIR = roles
ROLE_FILE = roles.yml

LOGIN_ARGS ?=

sync install:
	devbox run uv sync

lint: install
	devbox run uv run yamllint . -c .yamllint
	devbox run uv run ansible-lint -p playbooks/ --exclude ".ansible/*"

requirements: install
	@python --version
	devbox run uv run ansible-galaxy role install \
		--force --no-deps \
		--roles-path ${ROLE_DIR} \
		--role-file ${ROLE_FILE}
	devbox run uv run ansible-galaxy collection install \
		--force-with-deps .
	@find ./ -name "*.ymle*" -delete

build: requirements
	if [ -f "${GALAXY_FILE}" ]; \
		@uv run build; \
		@git status --porcelain | wc -l | grep -q '^0$$' || (echo "Uncommitted build detected, please run build stage and commit changes" && exit 1); \
	fi

update:
	devbox run uv run update

ifeq (login,$(firstword $(MAKECMDGOALS)))
    LOGIN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
    $(eval $(subst $(space),,$(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))):;@:)
endif

test dependency create prepare converge idempotence side-effect verify destroy cleanup reset list login:
	rm -rf ansible_collections/
	find .venv -type d -name ansible_collections | xargs -r -- rm -r
	MOLECULE_HOME=$$(mktemp -d); \
	if [ -n "$${CI:-}" ]; then \
		export MOLECULE_EPHEMERAL_DIR=.molecule/${MOLECULE_SCENARIO}; \
	else \
	fi; \
	HOME=$${MOLECULE_HOME} \
	MOLECULE_REVISION=${MOLECULE_REVISION} \
	MOLECULE_KVM_IMAGE=${MOLECULE_KVM_IMAGE} \
	MOLECULE_LOGDIR=${MOLECULE_LOGDIR} \
	devbox run uv run dotenv molecule $@ -s ${MOLECULE_SCENARIO} ${LOGIN_ARGS}; \
	if [ -n "$${CI:-}" ]; then \
		rm -r $${MOLECULE_EPHEMERAL_DIR}; \
	fi; \
	rm -r $${MOLECULE_HOME};

publish: build
	if [ -z "${GALAXY_API_KEY}" ]; \
		then echo "GALAXY_API_KEY is not set"; \
		exit 1; \
	fi
	if [ -f "${GALAXY_FILE}" ]; \
		COLLECTION_NAMESPACE=$$(yq -r '.namespace' ${GALAXY_FILE}) \
		COLLECTION_NAME=$$(yq -r '.name' ${GALAXY_FILE}) \
		COLLECTION_VERSION=$$(yq -r '.version' ${GALAXY_FILE}) \
			devbox run uv run ansible-galaxy collection publish --api-key ${GALAXY_API_KEY} \
				"$${COLLECTION_NAMESPACE}-$${COLLECTION_NAME}-$${COLLECTION_VERSION}.tar.gz"
	fi
