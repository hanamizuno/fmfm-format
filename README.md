# MoonBit + AI Agent Development Template

This repository serves as a template for developing [MoonBit](https://www.moonbitlang.com/) applications and libraries. It comes pre-configured with Docker, GitHub Actions CI, and common development tools.

## Scope

This template provides the **outer scaffolding** (CI, containers, security tooling, knowledge base); the inner MoonBit code is intentionally minimal — a small library (`fib` / `sum`) plus one executable, demonstrating snapshot tests, doc tests, property-based tests, and benchmarks.

`myuser/myapp` is a placeholder module name — rename it for your project (see [Adopting This Template](#adopting-this-template)).

## Features

*   **Modern MoonBit Stack:** Latest MoonBit toolchain, new `moon.mod` / `moon.pkg` config format, `js` as the default target with a `native` matrix in CI.
*   **Testing Batteries Included:**
    *   Snapshot testing with `inspect()` / `debug_inspect()` (`moon test --update`).
    *   Doc tests in `src/README.mbt.md`.
    *   Property-based tests with [`moonbitlang/quickcheck`](https://github.com/moonbitlang/quickcheck).
    *   Benchmarks with `moon bench`.
*   **Task Runner:** [`just`](https://github.com/casey/just) recipes for every workflow (`just ci` mirrors CI exactly).
*   **Containerized Development:**
    *   **Docker & Docker Compose:** Multi-stage builds (`dev`, `build`, `prod`); `prod` ships only the native release binary and runs as a non-root user.
    *   **Docker Sandboxes:** `.sandbox/` holds [sbx](https://docs.docker.com/ai/sandboxes/) kits for running AI agents in a microVM (separate kernel, deny-by-default networking, credentials that never enter the VM).
*   **CI/CD:** GitHub Actions workflows for format/interface verification and a js/native test matrix (Ubuntu + macOS).
*   **Pre-commit Hooks:** `.pre-commit-config.yaml` (`moon check` + `moon fmt`) via [prek](https://github.com/j178/prek).
*   **Shared Knowledge Base:** `docs/knowledge/` is an OKF bundle — a plain-Markdown knowledge base (ADRs, architecture notes, conventions, runbooks, research) that both humans and AI agents read and write. Ships as a labeled-sample skeleton; start at [`docs/knowledge/index.md`](docs/knowledge/index.md).

## Security

This project implements supply chain attack protections.
cf. https://zenn.dev/dajiaji/articles/47164ff27d2123

- **Pinned Dependencies**: `moon add` pins exact versions in `moon.mod`
- **Minimum Privileges**: Workflows use `permissions: {}` at top level
- **SHA Pinning**: All GitHub Actions are pinned to commit SHAs
- **Dependabot Cooldown**: 7-day delay before accepting new versions (github-actions, docker — there is no mooncakes ecosystem, so MoonBit deps are bumped manually)
- **Vulnerability Scanning**: Trivy scans the repository on every push/PR and weekly, failing the check on CRITICAL/HIGH findings (no Security-tab upload, so it works on private repos without GitHub Code Security)
- **Workflow Auditing**: zizmor and actionlint check workflow security and correctness
- **Digest-pinned Base Images**: Dockerfile base images are pinned by digest

Note: the MoonBit toolchain itself tracks the latest release (cli.moonbitlang.com hosts only `latest`); the CI "Moon version" step logs the version each run used.

## Directory Structure

```
.
├── .dockerignore
├── .editorconfig
├── .github/                    # GitHub-specific files
│   ├── copilot-instructions.md # Pointer to AGENTS.md for GitHub Copilot
│   ├── dependabot.yml          # Dependabot configuration
│   ├── ISSUE_TEMPLATE/         # Issue forms (bug, feature, task)
│   ├── labeler.yml             # Path-based PR labeling config (used by label_pr.yml)
│   ├── labels.yml              # Repository label definitions (synced by CI)
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── scripts/
│   │   └── sync-labels.sh
│   └── workflows/              # GitHub Actions CI workflows
│       ├── ci.yml              # fmt/interface verification + js/native test matrix
│       ├── label_pr.yml        # PR auto-labeling (actions/labeler)
│       ├── labels.yml          # Label sync
│       ├── lint_docker.yml     # hadolint
│       ├── lint_gha.yml        # actionlint + zizmor
│       └── security.yml        # Vulnerability scanning (Trivy)
├── .gitignore
├── .pre-commit-config.yaml     # moon check / moon fmt hooks (via prek)
├── .sandbox/                   # Docker Sandboxes (sbx) kits — run on the host
│   ├── kit/spec.yaml           # Shared mixin: MoonBit toolchain, just, network allowlist, GitHub credential injection
│   ├── claude-auto/spec.yaml   # Fork of the built-in claude agent: auto permission mode instead of YOLO
│   ├── codex-approve/spec.yaml # Fork of the built-in codex agent: approve-for-me instead of YOLO
│   └── README.md               # Quick start; details live in docs/knowledge/runbooks/agent-sandbox-sbx.md
├── .vscode/
│   └── settings.json
├── AGENTS.md                   # Project guidelines for AI agents and humans
├── CHANGELOG.md
├── CLAUDE.md                   # Pointer to AGENTS.md for Claude Code
├── Dockerfile                  # Defines container images (dev, build, prod)
├── LICENSE
├── README.md                   # This file
├── compose.dev.yml             # Docker Compose configuration for development
├── compose.yml                 # Docker Compose configuration for production
├── docs/
│   └── knowledge/              # Shared knowledge base (OKF bundle): ADRs, conventions, runbooks, ...
├── justfile                    # Task runner recipes
├── moon.mod                    # Module definition (name, version, pinned dependencies)
└── src/                        # Library package (module source root)
    ├── README.mbt.md           # Package README + doc tests
    ├── lib.mbt                 # Library code
    ├── lib_test.mbt            # Snapshot/unit tests
    ├── lib_bench.mbt           # Benchmarks
    ├── quickcheck_test.mbt     # Property-based tests
    ├── moon.pkg                # Package configuration
    ├── pkg.generated.mbti      # Generated type interfaces (moon info) — do not edit
    └── main/                   # Executable entry point
        ├── main.mbt
        ├── moon.pkg
        └── pkg.generated.mbti
```

## Adopting This Template

After creating a repository from this template:

1. Rename the `myuser/myapp` module to your `<username>/<project>`, then update every reference to it:
    - `moon.mod`: `name`, `repository`, `description`, `keywords`
    - `src/main/moon.pkg`: the `"myuser/myapp" @lib` import
    - `src/README.mbt.md`: the heading and the Package bullet
    - `@myapp.` qualifiers in blackbox tests and doc tests (`src/*_test.mbt`, `src/README.mbt.md`, `///` examples in `src/lib.mbt`) — the alias is the last segment of the package path, e.g. `@project.`
2. Run `just fmt && just info` to regenerate `pkg.generated.mbti` (the generated files embed the module name), then `just ci-all` to confirm the renamed project is healthy.
3. Fill in the `LICENSE` placeholders (`[yyyy]`, `[name of copyright owner]`) and the `license` field in `moon.mod` — or replace the license entirely.
4. Replace the sample documents in `docs/knowledge/` with real project knowledge (each sample carries a "replace me" banner).
5. Optional: set up pre-commit hooks with [prek](https://github.com/j178/prek): `prek install`. For MoonBit linting, install [starlint](https://github.com/mizchi/starlint) (`moon install mizchi/starlint/cmd/starlint`) and uncomment its hook in `.pre-commit-config.yaml`.

## Getting Started

### Prerequisites

*   Docker and Docker Compose
*   MoonBit toolchain + just (if not using Docker)

### Setup Options

#### Option 1: Using Docker Compose Manually

1.  **Build the development image:**
    ```bash
    docker compose -f compose.dev.yml build
    ```
2.  **Run commands inside the container:**
    ```bash
    docker compose -f compose.dev.yml run --rm app <command>
    ```
    For example, to run the local CI suite:
    ```bash
    docker compose -f compose.dev.yml run --rm app just ci
    ```
    To get an interactive shell:
    ```bash
    docker compose -f compose.dev.yml run --rm app bash
    ```

#### Option 2: Using the MoonBit toolchain locally (without Docker)

1.  **Install MoonBit and just** (if not already installed):
    ```bash
    curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
    # just: https://github.com/casey/just?tab=readme-ov-file#installation
    ```
2.  **Fetch the registry index:**
    ```bash
    moon update
    ```
3.  **Run commands:**
    ```bash
    just        # check + test
    ```

### Quick Commands

```bash
just           # check + test
just fmt       # format code
just fmt-check # verify formatting
just check     # type check
just test      # run tests
just test-update  # update snapshot tests
just bench     # run benchmarks
just run       # run main
just info      # generate type definition files
just ci        # local CI equivalent for default target
just ci-all    # lint + js/native test matrix
just release-check-all  # release check on js + native
```

## Release Checklist

Before tagging a release:

1. Update `moon.mod` version and metadata (`repository`, `keywords`, `description`)
2. Update `CHANGELOG.md`
3. Run `just release-check-all`
4. Create annotated tag (for example: `git tag -a v0.2.0 -m "Release v0.2.0"`)
5. Push branch and tag

## AI Agent Sandbox

AI coding agents (Claude Code, Codex, etc.) run in [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`), using the kits in `.sandbox/`. Run from the host:

```bash
sbx create --clone --kit ./.sandbox/kit claude .
sbx exec -it -w "$PWD" claude-<directory-name> claude --permission-mode auto
```

The kit provides the MoonBit toolchain, `just`, Node (js target), and a C toolchain (native target); GitHub credentials are injected by the host-side proxy, so no tokens live inside the sandbox. Quick start: [`.sandbox/README.md`](.sandbox/README.md). Full procedure (auth methods, clone mode, network policy, secrets): [`docs/knowledge/runbooks/agent-sandbox-sbx.md`](docs/knowledge/runbooks/agent-sandbox-sbx.md). Verification status: [`docs/knowledge/research/sbx-verification.md`](docs/knowledge/research/sbx-verification.md).
