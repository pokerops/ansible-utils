# PokerOps Actions

Reusable GitHub Actions workflows for Ansible collections, featuring devbox-based development environments with molecule testing support.

## Overview

This repository provides standardized CI/CD workflows for Ansible collections and roles, including:

- **Build workflows** - Collection build and validation
- **Lint workflows** - YAML and Ansible linting
- **Release workflows** - Automated publishing to Ansible Galaxy
- **Version workflows** - Collection version validation

The workflows are designed to be consumed by other repositories via `workflow_call`.

## Development Environment

This project uses [Devbox](https://www.jetify.com/devbox) for reproducible development environments with [UV](https://docs.astral.sh/uv/) for Python dependency management.

### Quick Start

```bash
devbox install           # Install all required packages
just check-deps          # Verify every dependency is pinned
just update              # Re-pin dependencies and rewrite pyproject.toml
```

The repository root carries dependency-maintenance recipes only. Linting and molecule
testing run in the consumer projects under `tests/` — see below.

> **`make` is deprecated.** `just` is the only supported entry point. A `Makefile` and a
> `make` alias are still shipped so unmigrated consuming repositories keep working, but
> they receive no new recipes and will be removed. Migrate `make X` call sites to
> `just X`; the recipe names are identical.

## Testing the Devbox Molecule Plugin

A minimal test collection is provided in `tests/collection/` to verify the devbox molecule plugin functionality:

```bash
cd tests/collection/
devbox run -- just lint
devbox run -- just test
```

A minimal role is also available in `tests/role/` for role-specific testing:

```bash
cd tests/role/
devbox run -- just test
```

## Architecture

### Composite Action (`action.yml`)

Runs a devbox command in the target repository — `devbox run -- <run>`, defaulting to
`just test`.

### Reusable Workflows (`.github/workflows/`)

Consumed downstream via `workflow_call`:

- `build.yml` - Collection build and validation
- `lint.yml` - YAML and Ansible linting
- `release.yml` - Publishing to Ansible Galaxy
- `version.yml` - Collection version validation for PRs

`devbox.yml` and `dependencies.yml` are this repository's own CI, not reusable.

### Workflow Templates (`devbox/molecule/config/`)

`just init` / `just overwrite` install these into a consuming repository as
`.github/workflows/*` — `build.yml`, `lint.yml`, `release.yml`, `version.yml`, and
`molecule.yml` (roles only).

### Development Tools (`devbox/`)

- `molecule/` - Molecule testing configuration with Python 3.13, uv, just, and testing tools
- `plugin.json` - Devbox plugin definition for molecule environments
- `molecule/config/skill.md` - Claude Code skill installed into consuming repositories

### Agent Skill

`just init` / `just overwrite` installs `devbox/molecule/config/skill.md` into the
consuming repository as `.claude/skills/pokerops-ansible/SKILL.md`. It teaches coding
agents which `just` recipes exist, which ones are expensive, and which repository
conventions break CI.

The installed copy is self-ignoring (the plugin drops a `.gitignore` alongside it), so it
is never committed downstream and every `just init` picks up the latest version from this
repository. Edit `devbox/molecule/config/skill.md` here — never the installed copy.

Additional skills can be added by dropping a `config/skill_<name>.md`-style entry into
`plugin.json`; any `skill_<name>.md` in the virtenv is installed to
`.claude/skills/<name>/SKILL.md`.

## Usage

Consuming repositories should:

1. Have a `galaxy.yml` file for collection metadata
2. Reference these workflows in their `.github/workflows/` files (`just overwrite`
   generates them). Use `just overwrite` rather than `just init` to refresh: `init`
   only creates files that are missing, so it will not update a workflow that already
   exists.
3. Set up appropriate secrets for Galaxy publishing (`GALAXY_API_KEY`)

Example workflow reference:

```yaml
jobs:
  lint:
    uses: pokerops/ansible-utils/.github/workflows/lint.yml@main
```
