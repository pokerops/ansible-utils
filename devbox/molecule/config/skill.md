---
name: pokerops-ansible
description: >-
  Lint, molecule-test, build, and release a PokerOps Ansible collection or role through
  the devbox just/make wrappers. Load before running any lint, test, molecule, build,
  publish, or dependency command, and before editing galaxy.yml, meta/runtime.yml,
  requirements.yml, molecule scenarios, or .github/workflows, in any repo whose
  devbox.json includes pokerops/ansible-utils.
---

# PokerOps Ansible collection & role workflow

This file is installed by the `pokerops/ansible-utils` devbox plugin and is gitignored.
Do not edit it here — it is overwritten on every `just init`. Upstream source:
`devbox/molecule/config/skill.md` in `pokerops/ansible-utils`.

## Orient once, then stop guessing

| Marker | Repo type | Molecule scenarios live in |
| --- | --- | --- |
| `galaxy.yml` | collection | `extensions/molecule/<scenario>/` |
| `meta/main.yml` | role | `molecule/<scenario>/` |

`just debug` prints every path the wrapper resolved (galaxy file, meta file,
requirements, role dir, venv, uv invocation). Run it once up front instead of
inferring paths from the tree; it is instant and authoritative.

`just --list`, or reading `$JUSTFILE`, is the authoritative target list. Read it rather
than guessing a target name and eating a failed run.

## How the toolchain is wired

The devbox shell aliases `just`, `make`, and `uv` so they fall back to plugin-owned
files under `$VIRTENV` whenever the repo has none of its own:

- recipes — `$JUSTFILE`, mirrored by `$MAKEFILE` (`just X` and `make X` are equivalent; prefer `just`)
- python deps — `$PYPROJECT/pyproject.toml`, installed into `.venv/` by `uv`
- yamllint config — `$VIRTENV/.yamllint`, used unless the repo has its own `.yamllint`

Two consequences that cost real time when missed:

1. **Everything runs inside the devbox shell.** From outside, use
   `devbox run -- just <target>`. Bare `molecule`, `ansible-lint`, `yamllint`, and
   `ansible-playbook` are not on `PATH` and will not resolve the right config.
2. **Never add a root `Makefile`, `justfile`, or `pyproject.toml` just to define a
   target or add a dependency.** The aliases fall back to the plugin copies *only*
   while those files are absent; creating one silently disables every target below.
   Shared needs belong upstream in `pokerops/ansible-utils`.

## Targets

| Target | Does | Cost |
| --- | --- | --- |
| `just debug` | print resolved paths | free |
| `just sync` (`install`) | `uv sync --only-dev` into `.venv/` | seconds after first run |
| `just lint` | yamllint over the repo, then ansible-lint if `galaxy.yml` or `meta/main.yml` exists | seconds |
| `just requirements` | wipe `~/.ansible/{collections,roles}`, reinstall from `requirements.yml` / `roles.yml` | slow, network |
| `just create` / `converge` / `verify` / `idempotence` / `side-effect` / `destroy` | one molecule step | varies by driver |
| `just test` | full molecule sequence for the scenario | slowest |
| `just login` | shell into a running molecule instance | — |
| `just molecule <cmd> [args]` | escape hatch for any molecule subcommand | — |
| `just build` | `requirements`, then `ansible-galaxy collection build` | slow |
| `just init` / `just overwrite` | (re)install `.github/workflows/*` and `.claude/skills/*` from the plugin | free |
| `just version-check` | compare `galaxy.yml` version against the PR base | free |

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
- **Add dependencies with `uv add --group dev <pkg>`** from inside the devbox shell.
  Never `pip install`, never hand-build a venv, never edit `.venv/`.
- **Read generated workflow files, do not patch them.** Everything in
  `.github/workflows/` comes from `pokerops/ansible-utils` and is erased by the next
  `just overwrite`. Fix them upstream.

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
