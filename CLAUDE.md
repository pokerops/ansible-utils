# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Environment

This project uses **devbox** for development environment management with **uv** for Python dependency management. The environment is configured for Ansible collection development with molecule testing.

### Setup Commands

```bash
devbox install           # Install all required packages and dependencies
devbox run uv sync       # Sync Python dependencies
```

### Dependency Management

**Initial Setup:**

```bash
uv lock                  # Create uv.lock with pinned versions
```

**Updating Dependencies:**

```bash
uv sync --upgrade        # Update to latest compatible versions
uv lock --upgrade        # Update lock file with new versions
```

**Adding New Dependencies:**

```bash
uv add --group dev package@latest  # Add to dev dependency group
```

**Updating All Dependencies to Latest Versions:**

```bash
just update              # Updates to latest versions and shows formatted output for pyproject.toml
```

### Core Development Commands

**Linting and Code Quality:**

```bash
make lint                # Alternative via Makefile (uses devbox internally)
```

**Building:**

```bash
make build               # Alternative via Makefile
```

**Testing with Molecule:**

```bash
make test                # Run molecule test with default scenario
make converge            # Run molecule converge step
make verify              # Run molecule verify step
make destroy             # Clean up molecule test environment
```

**Publishing:**

```bash
make publish             # Publish collection to Ansible Galaxy (requires GALAXY_API_KEY)
```

## Architecture

### Repository Structure

- `actions/` - GitHub Actions workflow definitions for CI/CD
  - `build.yml` - Collection building workflow
  - `lint.yml` - Linting workflow
  - `release.yml` - Release and publishing workflow
  - `version.yml` - Version validation workflow for PRs
- `devbox/` - Devbox configuration and utilities
  - `molecule/` - Molecule testing configuration
    - `config/` - Makefile, justfile, pyproject.toml, workflow and skill templates
    - `config/skill.md` - Claude Code skill installed into consuming repositories
    - `plugin.json` - Devbox plugin definition for molecule
- `tests/` - Testing resources
  - `collection/` - Minimal test collection for verifying devbox molecule plugin
    - `galaxy.yml` - Collection metadata for `pokerops.test`
    - `playbooks/test.yml` - Simple test playbook for validation

### Development Workflow

This is an **Ansible actions repository** providing reusable GitHub Actions workflows for Ansible collections. The workflows are designed to be called from other repositories via `workflow_call`.

### Testing the Devbox Molecule Plugin

A minimal test collection is provided in `tests/collection/` to verify the devbox molecule plugin functionality:

```bash
cd tests/collection/
devbox shell             # Enter devbox environment
molecule init            # Initialize molecule testing
molecule test            # Run full test suite
```

### Agent Skill Injection

`make init` / `make overwrite` (equivalently `just init` / `just overwrite`) installs
`devbox/molecule/config/skill.md` into the consuming repository at
`.claude/skills/pokerops-ansible/SKILL.md`, alongside the generated workflow files. The
plugin writes a self-ignoring `.gitignore` next to it, so the skill is never committed
downstream and is refreshed from this repository on every `init`.

When changing the targets, conventions, or CI gates that consuming repositories rely on,
update `devbox/molecule/config/skill.md` in the same change. Both `config/justfile` and
`config/Makefile` install skills — keep the two in sync.

### Configuration Files

- `devbox.json` - Main devbox configuration, includes molecule plugin
- `devbox/molecule/plugin.json` - Molecule-specific devbox environment with Python, uv, make, and testing tools
- `.ansible-lint.yml` - Ansible-lint configuration
- `actions/.yamllint` - YAML linting rules
- `devbox/molecule/config/.yamllint` - Default yamllint rules for consuming repositories
- `devbox/molecule/config/.ansible-lint.yml` - Default ansible-lint config for consuming repositories

Both defaults are rendered into the plugin virtenv and used by the `lint` target only
when the consuming repository defines none of its own. For ansible-lint the target
also passes `--project-dir`, because ansible-lint derives its project root from the
config file location — without it the root would land in the virtenv and file
discovery would collapse to a single lintable.

### Key Dependencies

- **Ansible 11.5.0+** - Core automation framework
- **Molecule 25.4.0+** - Testing framework for Ansible roles/collections
- **Python 3.13** - Runtime environment
- **uv** - Fast Python package manager

The workflows expect consuming repositories to have a `galaxy.yml` file for collection metadata and building.
