---
name: pokerops-ansible
description: >-
  Lint, molecule-test, build, and release a PokerOps Ansible collection or role through
  the devbox just wrappers. Load before running any lint, test, molecule, build,
  publish, or dependency command, and before editing galaxy.yml, meta/runtime.yml,
  requirements.yml, molecule scenarios, or .github/workflows, in any repo whose
  devbox.json includes pokerops/ansible-utils.
---

# PokerOps Ansible collection & role workflow

This file is installed by the `pokerops/ansible-utils` devbox plugin and is gitignored.
Do not edit it here — it is overwritten on every `just init`. Upstream source:
`devbox/molecule/config/skill.md` in `pokerops/ansible-utils`.

## Orient once, then stop guessing

| Marker          | Repo type  | Molecule scenarios live in        |
| --------------- | ---------- | --------------------------------- |
| `galaxy.yml`    | collection | `extensions/molecule/<scenario>/` |
| `meta/main.yml` | role       | `molecule/<scenario>/`            |

`just debug` prints every path the wrapper resolved (galaxy file, meta file,
requirements, role dir, venv, uv invocation). Run it once up front instead of
inferring paths from the tree; it is instant and authoritative.

`just --list`, or reading `$JUSTFILE`, is the authoritative target list. Read it rather
than guessing a target name and eating a failed run.

## How the toolchain is wired

The devbox shell aliases `just` and `uv` so they fall back to plugin-owned files under
`$VIRTENV` whenever the repo has none of its own:

- recipes — `$JUSTFILE`
- python deps — `$PYPROJECT/pyproject.toml`, installed into `.venv/` by `uv`
- yamllint config — `$VIRTENV/.yamllint`, used unless the repo has its own `.yamllint`

Two consequences that cost real time when missed:

1. **Everything runs inside the devbox shell.** From outside, use
   `devbox run -- just <target>`. Bare `molecule`, `ansible-lint`, `yamllint`, and
   `ansible-playbook` are not on `PATH` and will not resolve the right config.
2. **A root `justfile` must re-import the plugin's.** The alias falls back to the
   plugin copy _only_ while that file is absent, so a _standalone_ root justfile
   silently drops every target below. One that imports keeps them all — see
   [Extending the wrappers](#extending-the-wrappers).

A root `pyproject.toml` is **not** covered by that rule and is not a workaround. The
fallback is per-file, and the justfile already branches on this one
(`UV_OPTION_PROJECT`) to point `uv` at the repo instead of the
virtenv. Creating one leaves every target working. See
[Adding a python dependency](#adding-a-python-dependency) — never turn down a package
on the grounds that it would require a root `pyproject.toml`.

### `make` is deprecated — migrate the repo on sight

A `$MAKEFILE` and a `make` alias still exist so unmigrated repos keep working. They
receive no new recipes and will be removed. Never write or document a new `make`
invocation.

If this repo still uses `make` anywhere, **migrate it before doing the work you came
for**, then carry on:

1. `grep -rn 'make ' .github/ *.md Makefile 2>/dev/null` to find every call site.
2. Rewrite each as the identical `just` recipe — the names match one-for-one, so
   `make install requirements test` becomes `just install requirements test`.
3. A root `Makefile` becomes a root `justfile` — see
   [Extending the wrappers](#extending-the-wrappers). Delete the `Makefile`; leaving
   both means the `make` alias keeps resolving to it.
4. Workflow files under `.github/workflows/` are generated. Do not hand-edit them —
   run `just overwrite`, **not `just init`**: `init` only fills in files that are
   missing, so it will leave a `make`-based workflow in place untouched.

Mention the migration in your summary; it is a real change to the repo, not cleanup to
perform silently.

## Targets

| Target                                                                            | Does                                                                                   | Cost                    |
| --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ----------------------- |
| `just debug`                                                                      | print resolved paths                                                                   | free                    |
| `just sync` (`install`)                                                           | `uv sync --only-dev` into `.venv/`                                                     | seconds after first run |
| `just pyproject`                                                                  | seed a repo-local `pyproject.toml`, then sync                                          | seconds                 |
| `just lint`                                                                       | yamllint over the repo, then ansible-lint if `galaxy.yml` or `meta/main.yml` exists    | seconds                 |
| `just requirements`                                                               | wipe `~/.ansible/{collections,roles}`, reinstall from `requirements.yml` / `roles.yml` | slow, network           |
| `just create` / `converge` / `verify` / `idempotence` / `side-effect` / `destroy` | one molecule step                                                                      | varies by driver        |
| `just test`                                                                       | full molecule sequence for the scenario                                                | slowest                 |
| `just login`                                                                      | shell into a running molecule instance                                                 | —                       |
| `just molecule <cmd> [args]`                                                      | escape hatch for any molecule subcommand                                               | —                       |
| `just build`                                                                      | `requirements`, then `ansible-galaxy collection build`                                 | slow                    |
| `just init` | install *missing* `.github/workflows/*`; always refresh `.claude/skills/*` | free |
| `just overwrite` | same, but also replace workflow files that already exist | free |
| `just version-check`                                                              | compare `galaxy.yml` version against the PR base                                       | free                    |

## Working efficiently

- **Lint before you test.** `just lint` takes seconds and catches most of what fails
  CI; molecule takes minutes. Never open a molecule run to find a YAML typo.
- **Iterate on a live instance, do not re-run `just test`.** `just create` once, then
  `just converge` after each edit, `just verify` to check assertions, and
  `just destroy` when finished. `just test` re-runs the whole sequence including
  dependency resolution, and is for a final check or CI parity only.
- **Use `just idempotence`** for the real second-run check instead of eyeballing a
  repeated converge.
- **Leave `~/.ansible` alone unless requirements changed.** `just requirements`,
  `just clean`, `just destroy`, `just cleanup`, and `just reset` all delete
  `~/.ansible/collections` and `~/.ansible/roles`, forcing a full re-download. Only
  run `just requirements` after `requirements.yml` or `roles.yml` actually changed.
- **Select a scenario through the environment, not by editing files:**
  `MOLECULE_SCENARIO=<name> just converge`.
- **Add dependencies with `just pyproject` then `uv add --group dev <pkg>`** — see
  below. Never `pip install`, never hand-build a venv, never edit `.venv/`.
- **Read generated workflow files, do not patch them.** Everything in
  `.github/workflows/` comes from `pokerops/ansible-utils` and is erased by the next
  `just overwrite`. Fix them upstream.

## Adding a python dependency

Repository-specific packages — `bcrypt` for a molecule assertion, `netaddr` for a filter
plugin — are declared in a **repository-local `pyproject.toml`**. Create one; that is the
supported path, and it is the only place such a dependency can survive.

The trap is the reverse of how it looks. While the repo has no root `pyproject.toml` the
`uv` alias carries `--directory $PYPROJECT`, so a bare `uv add` edits the plugin's copy
inside the virtenv: the package is never committed, and devbox regenerates the file out
from under it on the next shell.

```bash
just pyproject             # seeds pyproject.toml from the plugin defaults, then syncs
uv add --group dev bcrypt  # now edits the repository's own file
```

`just pyproject` is a no-op when the file already exists. Run it as its own `just`
invocation — a single run resolves the uv project once, up front.

The seeded file carries the one entry that matters:

```toml
[dependency-groups]
dev = ["pokerops-ansible-utils@git+https://github.com/pokerops/ansible-utils@master"]
```

Every pinned tool — ansible, molecule, ansible-lint, yamllint, boto3, docker — resolves
transitively through that entry, at the versions CI uses. Add packages alongside it.
Never drop it, and never pin those tools locally; a local pin is how a repo drifts off
the shared toolchain.

`uv sync` writes a root `uv.lock`. Commit it, along with `pyproject.toml` — `just build`
refuses a dirty tree.

## Extending the wrappers

Repo-specific recipes are fine, and a root `justfile` is where they go. The requirement
is that it re-import the plugin's, because the alias fallback stops the moment that file
exists.

```just
import? '.devbox/virtenv/molecule/justfile'

my-recipe:
    @echo repo-specific
```

Details that bite:

- **Use the optional forms — `import?` and `-include`.** A plain `import` is a hard
  parse error whenever `.devbox/virtenv/` is absent (fresh clone, or any step running
  before `devbox install`), and that kills every recipe, not just the plugin's.
- **The path must be a literal.** Imports resolve before variables exist, so
  `import '$JUSTFILE'` fails; hardcode `.devbox/virtenv/molecule/justfile`.
- **Name the file exactly `justfile`.** The alias tests `[ -f justfile ]`, so a
  `Justfile` leaves the alias pointing at the virtenv copy and the repo's file is never
  read.
- **Do not repeat the plugin's settings.** The imported justfile already declares
  `set shell := ["bash", "-cu"]` and `set export := true`, and a root file repeating
  either is a hard error — "setting `shell` first set on line 3 is redefined". Opening
  a root justfile with `set shell` is the natural thing to write and the first thing
  that breaks; omit it and inherit both.
- **Reusing a plugin recipe name is a hard error** — "recipe `lint` ... is redefined".
  To override one on purpose, add `set allow-duplicate-recipes := true` at the top of
  the root justfile; the root definition then wins over the imported one.
- Recipes that are not repo-specific still belong upstream in `pokerops/ansible-utils`,
  so every consuming repo gets them.

## Rules that fail CI when broken

- **Collections must bump `version:` in `galaxy.yml` on every PR.** The `version`
  workflow compares against the base commit and requires a strictly greater semver
  `X.Y.Z`. Bump it as part of the change, not as an afterthought.
- **Collections need `meta/runtime.yml` with a `requires_ansible` key** — `just lint`
  fails without it.
- **`just build` refuses to run on a dirty tree.** Commit first, or it exits with
  "Uncommitted build detected".
- yamllint runs with `line-length: max 160`, implicit and explicit octal values
  forbidden, and `truthy` disabled. Match that when writing YAML.

## Do not run these unprompted

`just publish` (pushes to Ansible Galaxy, needs `GALAXY_API_KEY`), `just deploy` and
`just local` (overwrite the user's globally installed collections), `just clean` and
`just reset` (discard the shared ansible cache).

## Environment knobs

`MOLECULE_SCENARIO` (default `default`), `MOLECULE_LOGDIR`, `MOLECULE_DOCKER_IMAGE`,
`MOLECULE_DOCKER_COMMAND`, `MOLECULE_KVM_IMAGE`, `UBUNTU_RELEASE` (default `noble`),
`GALAXY_PATH` (default `galaxy.yml`), `GALAXY_API_KEY`, `DEVBOX_PROJECT_ROOT`,
`BASE_SHA` / `HEAD_SHA` for `version-check`.
