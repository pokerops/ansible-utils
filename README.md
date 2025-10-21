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
make install             # Install dependencies
make lint                # Run linting
make test                # Run molecule tests
```

## Testing the Devbox Molecule Plugin

A minimal test collection is provided in `tests/collection/` to verify the devbox molecule plugin functionality:

```bash
cd tests/collection/
devbox shell
make test
```

A minimal role is also available in `tests/role/` for role-specific testing:

```bash
cd tests/role/
devbox shell
make test
```

## Architecture

### Workflows (`actions/`)

- `build.yml` - Collection building workflow
- `lint.yml` - Linting workflow
- `release.yml` - Release and publishing workflow
- `version.yml` - Version validation workflow for PRs

### Development Tools (`devbox/`)

- `molecule/` - Molecule testing configuration with Python 3.13, uv, make, and testing tools
- `plugin.json` - Devbox plugin definition for molecule environments

## Usage

Consuming repositories should:

1. Have a `galaxy.yml` file for collection metadata
2. Reference these workflows in their `.github/workflows/` files (`make override` will generate common workflow files)
3. Set up appropriate secrets for Galaxy publishing (`GALAXY_API_KEY`)

Example workflow reference:

```yaml
jobs:
  lint:
    uses: pokerops/ansible-utils/.github/workflows/lint.yml@main
```
