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
uv add package@latest    # Add to [project].dependencies, then `just lock` to exact-pin
```

This repository declares no `dev` group — the toolchain lives in `[project].dependencies`
and reaches consuming repos transitively through the plugin's dev-group git entry.

**Updating All Dependencies to Latest Versions:**

```bash
just update              # Updates to latest versions and shows formatted output for pyproject.toml
```

### Core Development Commands

The root `justfile` is **standalone by design** — it does not import the plugin
justfile, so only dependency-maintenance recipes exist at the repository root:

```bash
just update              # Re-pin to latest compatible versions, then exact-pin from the lock
just upgrade             # Same, but resolves to latest versions first
just lock                # Rewrite pyproject.toml pins from the resolved lock file
just check-deps          # Fail if any dependency is unpinned
just configure           # Point config/pyproject.toml at the current repo and branch
```

Use `just`. **`make` is deprecated** — see [Make Deprecation](#make-deprecation).

The plugin's `lint`, `build`, `test`, `converge`, `verify`, and `publish` recipes are
**not** available at the repository root, and importing them would be actively harmful:
the plugin's `sync` runs `uv sync --only-dev`, which would resolve to this repository's
`pyproject.toml` — it declares no `dev` group — and prune `.venv` of the entire
toolchain. Exercise those recipes in the consumer projects under `tests/` instead.

## Architecture

### Repository Structure

- `action.yml` - Composite action that runs `devbox run -- <run>` in a target
  repository, defaulting to `just test`
- `.github/workflows/` - Reusable workflows consumed downstream via `workflow_call`
  (`build.yml`, `lint.yml`, `release.yml`, `version.yml`), plus this repository's own
  CI (`devbox.yml`, `dependencies.yml`)
- `devbox/` - Devbox configuration and utilities
  - `molecule/` - Molecule testing configuration
    - `config/` - justfile, pyproject.toml, workflow and skill templates (plus a
      deprecated `Makefile`)
    - `config/{build,lint,release,version,molecule}.yml` - Workflow templates installed
      into consuming repositories as `.github/workflows/*`
    - `config/skill.md` - Claude Code skill installed into consuming repositories
    - `plugin.json` - Devbox plugin definition for molecule
- `tests/` - Consumer projects that exercise the devbox molecule plugin
  - `collection/` - Minimal `pokerops.test` collection (`galaxy.yml`,
    `playbooks/test.yml`, molecule scenario under `extensions/molecule/default/`)
  - `role/` - Minimal role (`meta/main.yml`, molecule scenario under
    `molecule/default/`)

There is no `actions/` directory; the workflow definitions live in the two locations
above.

### Development Workflow

This is an **Ansible actions repository** providing reusable GitHub Actions workflows for Ansible collections. The workflows are designed to be called from other repositories via `workflow_call`.

### Testing the Devbox Molecule Plugin

`tests/collection/` (a `pokerops.test` collection) and `tests/role/` are standalone
devbox projects that include the plugin and define no `justfile` or `pyproject.toml`,
so the full wrapper fallback applies. They are where the plugin's own
recipes get exercised:

```bash
cd tests/collection      # or tests/role
devbox run -- just debug # print every path the wrapper resolved
devbox run -- just lint  # yamllint, then ansible-lint
devbox run -- just test  # full molecule sequence
```

Equivalently, `devbox shell` first and drop the `devbox run --` prefix. Bare `molecule`,
`ansible-lint`, and `yamllint` are not on `PATH` and will not pick up the plugin config.

### Agent Skill Injection

`just init` / `just overwrite` installs
`devbox/molecule/config/skill.md` into the consuming repository at
`.claude/skills/pokerops-ansible/SKILL.md`, alongside the generated workflow files. The
plugin writes a self-ignoring `.gitignore` next to it, so the skill is never committed
downstream and is refreshed from this repository on every `init`.

When changing the targets, conventions, or CI gates that consuming repositories rely on,
update `devbox/molecule/config/skill.md` in the same change.

### Configuration Files

- `devbox.json` - Main devbox configuration, includes molecule plugin
- `devbox/molecule/plugin.json` - Molecule-specific devbox environment with Python, uv, just, and testing tools
- `.ansible-lint.yml` - Ansible-lint configuration
- `devbox/molecule/.yamllint` - YAML linting rules for this repository
- `devbox/molecule/config/.yamllint` - Default yamllint rules for consuming repositories
- `devbox/molecule/config/.ansible-lint.yml` - Default ansible-lint config for consuming repositories

Both defaults are rendered into the plugin virtenv and used by the `lint` target only
when the consuming repository defines none of its own. For ansible-lint the target
also passes `--project-dir`, because ansible-lint derives its project root from the
config file location — without it the root would land in the virtenv and file
discovery would collapse to a single lintable.

### Downstream Python Dependencies

`devbox/molecule/config/pyproject.toml` is both the virtenv fallback and the seed
copied by `just pyproject` into a consuming repository that needs
its own python package. Its `dev` group pulls this repository over git, so the pinned
toolchain in the root `pyproject.toml` reaches downstream transitively — a consuming
repo adds packages alongside that entry and never pins ansible/molecule/lint itself.

A root `pyproject.toml` downstream is supported: the justfile branches on it
(`UV_OPTION_PROJECT`) to point `uv` at the repository.

### The `just` Wrapper

`just` is wrapped by a real script, `devbox/molecule/config/bin/just`, rendered into
`{{.Virtenv}}/bin/just` and put ahead of the raw binary by the plugin's `PATH` entry.
It falls back to `$JUSTFILE` only when the repository has no root `justfile`.

It must stay a `PATH` executable rather than the shell alias it replaced. Devbox
sources its init hook — and therefore any alias — only on the outermost entry into the
environment; a `devbox run` nested inside `devbox shell` or another `devbox run`
carries `__DEVBOX_SKIP_INIT_HOOK_*` and skips it. In those paths bare `just` reached
the raw binary, which searches *parent* directories: a consuming repo failed with "no
justfile found", and a repo nested under another one silently ran the ancestor's
justfile instead. Environment `PATH` has no such gap.

Two invariants the wrapper encodes:

- `--working-directory .` must accompany `--justfile`. Without it just runs recipes
  from the justfile's own directory, putting every relative path — `yamllint .`,
  ansible-lint's discovery root — inside the virtenv, where `lint` passes having
  examined almost nothing.
- Never export `JUST_JUSTFILE` to reach the plugin copy. It *outranks* a repository's
  own `justfile` instead of yielding to it, so it silently disables the override
  documented below. The wrapper only honours it when something else set it.

### Editing `config/` Requires a Forced Re-Render

Files under `devbox/molecule/config/` are `create_files` **sources**. What runs is the
rendered copy in `.devbox/virtenv/molecule/`, and devbox keys re-rendering off the
config hash in `.devbox/state.json` — **not** off the content of the source files.
Editing `config/justfile` or `config/Makefile` and re-running `devbox install` leaves
the old rendered copy in place, and deleting the rendered file does not bring it back.

So testing an edit against a consumer project requires:

```bash
cd tests/collection                       # or tests/role
rm -f .devbox/state.json && devbox install
```

Verify the rendered copy actually changed before trusting a result. Testing a `config/`
edit without this step exercises the previous version and reports it as the new one —
and for a destructive recipe that means running the old command believing it is the
fixed one.

### Project-Scoped Ansible Content

The plugin sets `ANSIBLE_HOME` to `$DEVBOX_PROJECT_ROOT/.ansible`, which relocates both
`COLLECTIONS_PATHS` and `DEFAULT_ROLES_PATH` into the project. `~/.ansible` leaves the
search path entirely rather than being deprioritized — it had been *winning* over the
venv's own bundled collections, so a stale global `community.general` shadowed the
pinned one and `lint` ran against versions nobody selected.

`clean` therefore removes `${ANSIBLE_HOME}/{collections,roles}` and never touches
machine-global state, which matters because it is a dependency of `requirements`,
`build`, `publish`, `destroy`, `cleanup`, and `reset`. Write the braces unquoted —
`"${DIR}/{collections,roles}"` is a literal path that never exists, which is exactly
how this recipe silently did nothing for as long as it did.

`.ansible/` is already gitignored, and `lint` already passes `--exclude ".ansible/*"`.
A consuming repo whose CI caches `~/.ansible` must move that cache key to
`<project>/.ansible`.

### Downstream Wrapper Overrides

A consuming repository may keep its own root `justfile` as long as it re-imports the
plugin copy, whose rendered path is stable at `.devbox/virtenv/molecule/justfile`:

```just
import? '.devbox/virtenv/molecule/justfile'
```

Only the optional forms are safe — a plain `import` fails to parse before
`devbox install` has materialized the virtenv. Import paths cannot interpolate
`$JUSTFILE`/`$VIRTENV`, so the literal path is load-bearing: renaming the plugin in
`devbox/molecule/plugin.json` breaks every downstream import.

`config/justfile` declares `set shell` and `set export`, and just rejects a setting
redeclared by an importing file. Adding a setting there is therefore a breaking change
for any consuming repo whose root justfile already declares it.

### Make Deprecation

`make` is deprecated across this repository and every consuming repository. `just` is
the only supported entry point.

What still exists, and why: `config/Makefile`, the `gnumake` package, and the
`alias make=` line in `plugin.json` remain so that unmigrated consuming repositories
keep working. They are frozen — **new recipes go into `config/justfile` only**, and
`config/Makefile` is no longer kept in sync with it.

Every call site in this repository is on `just`: the reusable workflows, the generated
workflow templates in `config/`, the `run` default in `action.yml`, and the plugin's
`init` devbox script. Do not reintroduce a `make` invocation anywhere, including in
documentation.

`config/skill.md` instructs agents working in a consuming repository to migrate that
repository off `make` before doing anything else. Since `.github/workflows/` files are
generated here, a downstream migration needs `just overwrite` to pick up the templates
rather than hand-editing.

### Key Dependencies

- **Ansible 11.5.0+** - Core automation framework
- **Molecule 25.4.0+** - Testing framework for Ansible roles/collections
- **Python 3.13** - Runtime environment
- **uv** - Fast Python package manager

The workflows expect consuming repositories to have a `galaxy.yml` file for collection metadata and building.
