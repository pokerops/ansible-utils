# PokerOps Actions

Reusable GitHub Actions workflows for Ansible collections, featuring devbox-based development environments with molecule testing support.

## Overview

This repository provides standardized CI/CD workflows for Ansible collections, including:

- **Build workflows** - Collection building and validation
- **Lint workflows** - YAML and Ansible linting
- **Release workflows** - Automated publishing to Ansible Galaxy
- **Version workflows** - PR version validation

The workflows are designed to be consumed by other repositories via `workflow_call`.

## Development Environment

This project uses **devbox** for reproducible development environments with **uv** for Python dependency management.

### Quick Start

```bash
devbox install           # Install all required packages
devbox run uv sync       # Sync Python dependencies
make lint                # Run linting
make test                # Run molecule tests
```

## Testing the Devbox Molecule Plugin

A minimal test collection is provided in `tests/collection/` to verify the devbox molecule plugin functionality:

```bash
cd tests/collection/
devbox shell             # Enter devbox environment
molecule init            # Initialize molecule testing
molecule test            # Run full test suite
```

The test collection includes:

- `galaxy.yml` - Collection metadata for `pokerops.test`
- `playbooks/test.yml` - Simple test playbook that creates and verifies a file

## Architecture

### Workflows (`actions/`)

- `build.yml` - Collection building workflow
- `lint.yml` - Linting workflow
- `release.yml` - Release and publishing workflow
- `version.yml` - Version validation workflow for PRs

### Development Tools (`devbox/`)

- `molecule/` - Molecule testing configuration with Python 3.13, uv, make, and testing tools
- `plugin.json` - Devbox plugin definition for molecule environments

### Configuration

- `devbox.json` - Main devbox configuration
- `.ansible-lint.yml` - Ansible-lint rules (skips run-once[task])
- `actions/.yamllint` - YAML linting with 160 character line length

## Key Dependencies

- **Ansible 11.5.0+** - Core automation framework
- **Molecule 25.4.0+** - Testing framework for roles/collections
- **Python 3.13** - Runtime environment via devbox
- **uv** - Fast Python package manager

## Usage

Consuming repositories should:

1. Have a `galaxy.yml` file for collection metadata
2. Reference these workflows in their `.github/workflows/` files
3. Set up appropriate secrets for Galaxy publishing (`GALAXY_API_KEY`)

Example workflow reference:

```yaml
jobs:
  lint:
    uses: pokerops/ansible-utils/.github/workflows/lint.yml@main
```

