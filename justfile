set shell := ["bash", "-cu"]

GIT_REPO := env_var_or_default(
  "GIT_REPO",
  `git config --get remote.origin.url | sed -E 's#^git@github.com:##; s#\.git$##'`)
GIT_BRANCH := env_var_or_default(
  "GIT_BRANCH",
  `printenv GIT_BRANCH 2>/dev/null || git rev-parse --abbrev-ref HEAD`)

# Dependency names, one per line, environment markers and specifiers stripped
MAIN_DEPS := `tomlq -r '.project.dependencies[]' pyproject.toml | \
    grep -v '^git+' | \
    sed -E 's/[[:space:]]*;.*$//' | \
    sed -E 's/[<>=~!@].*$//' | \
    sed -E 's/[[:space:]]+$//' | \
    sort -u`
# Dependency specs pinned to minor version, one per line, markers preserved
PINNED_DEPS := `tomlq -r '.project.dependencies[]' pyproject.toml | \
    grep -v '^git+' | \
    sed -E 's/^([A-Za-z0-9._-]+)[<>=~!]=([0-9]+\.[0-9]+)[^ ;]*/\1~=\2/'`

# Entries may carry environment markers, which contain spaces, so they are always
# handed to uv NUL delimited; word splitting would break them apart
NUL_SPLIT := "tr '\\n' '\\0' | xargs -0 -r"

# Update all dependencies to latest versions
upgrade-deps:
    @echo "Updating dependencies to latest versions..."
    uv sync --upgrade
    uv lock --upgrade || true
    printf '%s\n' "{{MAIN_DEPS}}" | {{NUL_SPLIT}} uv remove || true
    printf '%s\n' "{{MAIN_DEPS}}" | {{NUL_SPLIT}} uv add

update-deps:
    @printf '%s\n' "{{PINNED_DEPS}}"
    @echo "Updating dependencies to latest versions..."
    printf '%s\n' "{{MAIN_DEPS}}" | {{NUL_SPLIT}} uv remove || true
    printf '%s\n' "{{PINNED_DEPS}}" | {{NUL_SPLIT}} uv add
    uv lock --upgrade || true

# Check for unpinned dependencies
check-deps:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking for unpinned dependencies..."
    UNPINNED_DEPS=$(tomlq -r '.project.dependencies[]' pyproject.toml | \
        grep -v '^git+' | \
        grep -v '==' || true)
    if [ -n "${UNPINNED_DEPS}" ]; then
        echo "The following dependencies are unpinned:"
        echo "${UNPINNED_DEPS}"
        exit 1
    fi

# Regenerate the lock file
lock:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Updating dependencies to latest versions..."
    DEPS_REGEX=$(printf '%s\n' "{{MAIN_DEPS}}" | paste -sd'|' -)
    echo "$DEPS_REGEX"
    VERSIONS=$(uv export --format requirements-txt --no-hashes | grep -E "^($DEPS_REGEX)==" | sort)
    if [ -n "$VERSIONS" ]; then
        echo "Found versions:"
        echo "$VERSIONS"
        echo ""
        echo "Updating pyproject.toml ..."
        VERSIONS_JSON=$(echo "$VERSIONS" | jq -R . | jq -s .)
        tomlq -t -i --argjson deps "$VERSIONS_JSON" '.project.dependencies = $deps' pyproject.toml
        echo "pyproject.toml updated successfully"
    else
        echo "No versions found to update"
    fi

update: update-deps lock
upgrade: upgrade-deps lock

# Update workflow config files to use current branch
configure:
    sed -i.bak \
        -e 's#"\(pokerops-ansible-utils@git+https://github.com\).*#"\1/{{GIT_REPO}}@{{GIT_BRANCH}}"#' \
        devbox/molecule/config/pyproject.toml
    rm -f devbox/molecule/config/pyproject.toml.bak
