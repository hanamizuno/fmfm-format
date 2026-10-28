---
type: Runbook
title: AI agent sandbox (Docker Sandboxes / sbx)
description: Operating a microVM-isolated agent runtime with sbx and the kits in .sandbox/
tags: [sandbox, agents, security]
timestamp: 2026-10-20T00:00:00Z
---

# AI agent sandbox (Docker Sandboxes / sbx)

Runs AI agents inside a microVM with [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`). The kits live in `.sandbox/`. This is the only supported agent runtime for this repository (the Dev Container was removed in 2026-10 once sbx proved itself in daily use).

What it guarantees:

- **microVM boundary** — a separate kernel, so a container-escape kernel exploit stays contained
- **deny-by-default networking** — outbound TCP only to allowlisted domains (UDP / ICMP are blocked)
- **credentials never enter the VM** — a host-side proxy injects tokens into HTTP headers; the VM only sees sentinels
- **a Docker daemon per sandbox** — the host's Docker is never touched

What has and has not been verified is tracked in [sbx verification](/docs/knowledge/research/sbx-verification.md).

> `sbx` runs **on the host OS**. There is no `sbx` inside the VM.

## Prerequisites and install

macOS 14+ / Apple Silicon, Windows 11, or Ubuntu 24.04+ (KVM enabled). Docker Desktop / Engine is not required.

```bash
brew install docker/tap/sbx   # macOS; see the official docs for other OSes
sbx version
sbx login                     # required — every command fails with an auth error otherwise
```

You may be asked to pick a default network policy on first use. Choose **Locked Down or Balanced**; the kit adds the domains it needs through `allow`.

## First-time setup

The built-in agents launch in YOLO mode by default, so the launch command is overridden (next section). The steps below are **method A**, which keeps subscription auth (Claude Max / ChatGPT).

```bash
cd <checkout of this repository>

# 1) Create the sandbox only (the agent is not started). The positional argument
#    is the built-in agent type. --clone is mandatory (see below). Approve the
#    credentials prompt shown at creation.
sbx create --clone --kit ./.sandbox/kit claude .

# 2) Launch with the permission mode you want. Always enter this way —
#    `sbx run` would start the YOLO entrypoint.
sbx exec -it -w "$PWD" claude-<directory-name> claude --permission-mode auto

# 3) Register a fine-grained GitHub PAT scoped to that sandbox (value is prompted for)
sbx secret set github --sandbox claude-<directory-name>

# Codex works the same way.
sbx create --clone --kit ./.sandbox/kit codex .
sbx exec -it -w "$PWD" codex-<directory-name> codex --approve-for-me
```

Without `--name`, the sandbox is called `<agent>-<directory-name>` (check with `sbx ls`, or `$SANDBOX_NAME` inside the VM). Pass `--name` only when you want several sandboxes on the same checkout. Each agent needs its own first-time authentication (browser login etc.); VM state persists until `sbx rm`.

> **Never use `-g` (global).** A global secret can be injected into other repositories' sandboxes, which defeats per-repository scoping. The argument shape of `sbx secret set` has changed between CLI versions — if it differs, check `sbx secret set --help`.

What the kit (`.sandbox/kit/spec.yaml`) sets up at creation:

- the MoonBit toolchain (latest, same as the Dockerfile and CI), symlinked into `/usr/local/bin` so non-interactive agent shells find it
- `just` (pinned to the Dockerfile's version), Node for the js target, `build-essential` for the native target
- a populated mooncakes registry index (`moon update`)
- the Codex CLI plus its Claude Code plugin registration, and a Codex config seed (never overwrites an existing one)
- the network allowlist and the GitHub PAT header-injection rule

Confirm from inside the VM:

```bash
moon version --all && just --version
just ci-all          # fmt/info checks + js and native tests
```

## Overriding the YOLO default

The built-in defaults are `claude --dangerously-skip-permissions` and `codex --dangerously-bypass-approvals-and-sandbox`. In the sandbox they are replaced with `claude --permission-mode auto` (the model decides, but nothing is bypassed) and `codex --approve-for-me` (keeps workspace-write and routes approval requests to the automatic reviewer).

The microVM contains the blast radius either way; the permission layer is what keeps an agent from, say, force-pushing over a branch through the injected GitHub credential.

**Pass-through with `--` cannot do this** — leading flags are appended after the default ones, so the bypass flag stays. There are two ways; choose by how you authenticate.

### Method A: `sbx create` + `sbx exec` (subscription auth)

The procedure under "First-time setup". `sbx create` builds the sandbox without starting the agent, so the YOLO entrypoint is never hit and the agent type stays the built-in one. Credential injection is done by the host-side proxy intercepting traffic, so a process started through `sbx exec` is inside the same boundary.

Caveat: **reconnect through `sbx exec` too.** Entering with `sbx run` starts the default YOLO entrypoint.

### Method B: fork kits (when API-key billing is acceptable)

`sandbox.entrypoint` / `sandbox.command` are only valid in a `kind: sandbox` kit (a mixin must not declare `sandbox:`), so thin fork kits that `extends` the built-in agents are provided (`.sandbox/claude-auto/`, `.sandbox/codex-approve/`).

```bash
sbx run claude-auto   --clone --kit ./.sandbox/kit --kit ./.sandbox/claude-auto
sbx run codex-approve --clone --kit ./.sandbox/kit --kit ./.sandbox/codex-approve
```

A fork kit inherits everything but the launch command from its parent. **Both** `entrypoint` and `command` are declared because it is not published which one carries the parent's bypass flag; replacing only one could leave YOLO in place with no visible error.

> **Auth constraint:** a kit that `extends` a built-in agent cannot use the proxy-managed OAuth. Register an API key on the host before launching (`sbx secret set anthropic` / `openai`). Running `/login` inside the VM would store a real token in the VM, which breaks the model. To stay on subscription billing, use method A.

### Relationship to config files

The Codex `config.toml` seed follows the same policy, but **launch flags win**. sbx also plants `"defaultMode": "bypassPermissions"` in the VM's `~/.claude/settings.json`, so do not expect repository-side settings to take precedence — always state the mode with a flag, and confirm with `ps -eo args | grep -E 'claude|codex'` that no bypass flag is present.

## Day-to-day operation

- Re-entering from the same workspace reconnects to the existing sandbox (install steps do not re-run)
- `sbx ls` lists, `sbx stop <name>` stops, `sbx rm <name>` removes (**all VM state is lost** — unpushed commits included)
- After changing a kit, apply it with `sbx rm` and recreate (`sbx kit add` rejects kits that contain `setup.files`)
- The MoonBit toolchain tracks `latest` and is installed once at creation. To pick up a new release, recreate the sandbox (or re-run the installer inside the VM)

## Always use clone mode

`sbx run` / `sbx create` default to direct mode (host filesystem pass-through). **Always pass `--clone` in this repository.** Direct mode has problems that cannot be worked around by convention:

1. `_build/` and `.mooncakes/` would be shared with the host, so platform-specific artifacts (darwin vs. linux native builds, `moon` caches) clash. The host's pre-commit hooks (`language: system`, running the host's `moon`) would then operate on a build directory the VM keeps rewriting
2. virtiofs reports `st_size` 0 for symlinks, so a tracked symlink shows up as a "content deleted" diff and can be committed broken. This repository tracks none today, but nothing would warn you when one appears
3. Build I/O over virtiofs is slow

In clone mode the workspace is an independent git clone inside the VM (not a worktree), so none of this applies.

What changes operationally:

- **Uncommitted changes and gitignored files are not in the clone.** Commit work in progress first. `.env` does not come along either — and is not needed (see "Task secrets")
- **Results come back via push.** `git push` (https) goes through the proxy's header injection, so pushing a branch and opening a PR is the main path
- To take commits to the host without pushing, use the git daemon the sandbox exposes (only while it runs): `git fetch sandbox-<sandbox-name>` — see [`.sandbox/README.md`](/.sandbox/README.md)
- Conversely, commits added on the host after creation are pulled from the read-only bind mount of the host repository: `git fetch /run/sandbox/source` (`origin` points at GitHub and lacks the host's unpushed commits)
- **`sbx rm` destroys unpushed commits.** Have long unattended runs push frequently

## Giving the agent access to other host folders

Append paths to the positional arguments of `sbx create` / `sbx run`. The first path is the primary workspace; the rest are extra mounts.

```bash
sbx create --clone --kit ./.sandbox/kit claude . ~/develop/other-repo:ro ~/docs/design-notes:ro
```

- Extra workspaces are outside `--clone` and always direct-mounted, visible in the VM under the host's absolute path
- **Always add `:ro` for reference material** — being direct mounts, the direct-mode problems above apply in full. Do not pass folders containing `_build/` or `node_modules/`
- Workspaces can only be added at creation; adding one later means recreating

Other hand-off options: single files with `sbx cp ./config.json <sandbox-name>:/home/agent/` (works both ways), this repository's latest commits via `/run/sandbox/source`, and VM-local scratch space via the kit's `volumes:` (not a host bind mount).

## What sbx inherits on its own

Some host config is inherited automatically (observed with the claude template):

- git identity (`user.name` / `user.email`) comes from the host
- the global gitignore is placed at `/home/agent/.gitignore_global`
- `~/.claude/skills` is a **read-write virtiofs bind mount** from the host — if the agent edits it, the host sees the change

Not inherited (created fresh in the VM): `~/.claude/settings.json`, `statusline-command.sh`, `~/.claude.json`.

Three ways to bring host-specific Claude Code config in: the kit's `setup.files` for anything the team should share (it is committed), `sbx cp` for personal settings (repeat after every recreate), and an extra `<path>:ro` workspace for reference-only files (**never pass `~/.claude` wholesale** — `.credentials.json` holds the host's real tokens).

```bash
sbx cp ~/.claude/statusline-command.sh <sandbox-name>:/home/agent/.claude/statusline-command.sh
```

Do not overwrite `settings.json` wholesale (the VM-side `apiKeyHelper` and other proxy-managed auth keys would be lost). Append only the keys you need and rewrite home paths to `/home/agent`.

## Auditing the network policy

Outbound traffic is deny-by-default, but **the default allowlist contains broad wildcards**. Review it once with `sbx policy ls`. The kit's `permissions.network.allow` adds to the default — it does not trim it (narrowing is done on the host with `sbx policy`; deny beats allow).

When probing from inside the VM, **judge by the body, not the HTTP status**. Allowed domains return 4xx routinely (`claude.ai` answers 403 with a Cloudflare bot challenge, `api.anthropic.com` answers 404 on GET `/`). A denial has a body that starts with `Blocked by network policy`.

```bash
curl -s https://example.com/ | head -1
# Blocked by network policy: domain example.com:443
#   detail: no matching allow rule — blocked by default deny policy
```

MoonBit-specific domains in the kit: `cli.moonbitlang.com` (installer + binaries), `mooncakes.io` (registry index, fetched over git), `download.mooncakes.io` (package archives and `symbols.zip`) and `d15l9c1mnzh3r.cloudfront.net` (the CloudFront distribution `download.mooncakes.io` 302-redirects to — allow exactly this host, never `*.cloudfront.net`). If `moon update` or a dependency download is blocked, the body above names the missing domain — add it to the kit and recreate.

## Task secrets

```bash
sbx secret set example --sandbox <sandbox-name>   # the name matches the kit's credentials `service`
```

Adding an entry to the kit's `credentials` (spec.yaml has a commented template) makes the host-side proxy inject the header only on requests to the listed domains. The VM's environment variable holds a sentinel. Kit changes need a recreate, but sandbox-scoped secrets take effect immediately, even while running.

Values live on the host only and never enter the VM; injection is per domain (HTTP header), so a compromised VM leaks nothing and abuse is limited to the allowed domains. Revoke by replacing the secret and revoking at the issuer.

If a tool genuinely needs the real value in an environment variable, decide case by case, knowing the value then enters the VM.

### GitHub PAT scope

The injected `github` credential is whatever PAT you register, so scope it to this repository with a fine-grained PAT. A [prefilled template](https://github.com/settings/personal-access-tokens/new?name=agent-sbx&description=Agent%20sandbox%20baseline&expires_in=90&contents=write&pull_requests=write&issues=write&metadata=read&actions=read&workflows=write) gives the baseline below (90-day expiry); narrow it by editing the URL.

| Operation the agent should perform | Permission |
|---|---|
| Read issues / PRs / repo metadata | `Issues: Read`, `Pull requests: Read`, `Metadata: Read` |
| Comment on / open / close PRs | `+ Pull requests: Write`, `Issues: Write` |
| HTTPS `git push` / commit | `+ Contents: Write` (repo-scoped) |
| GitHub Actions read/dispatch | `+ Actions: Read` (or `Write` if dispatch needed) |
| Edit workflow YAML in `.github/workflows/` | `+ Workflows: Write` |
| Repository creation / settings | `+ Administration: Write` (not in the baseline; add only when needed) |

Fine-grained PATs do not cover every `gh` subcommand — on a 403 / "PAT not supported", fall back to a tightly scoped classic PAT.

### Registering a token without leaving it on screen or in history

The CLI reference itself flags `-t/--token` as "less secure: visible in shell history" — do not use it. Instead:

- **Interactive prompt (default)** — omit `-t` and you are asked for the value; nothing lands on the command line or in history
- **`--ref "op://<vault>/<item>/<field>"`** — supports 1Password references and AWS Secrets Manager ARNs (the matching CLI must be authenticated on the host)
- **`--command '<command that prints the value to stdout>'`** — for managers `--ref` does not support (e.g. Proton Pass via `pass-cli` on the host). `--command 'gh auth token'` works too, but that is your user-wide token, which goes against the scoping policy

`--ref` / `--command` store the source rather than the value and cache it per `--refresh` (default 55m), so rotation only happens at the issuer. `--show-error` can leak the secret into error output; do not use it routinely. Whether the interactive prompt exists depends on the CLI version — if it does not appear, use `--ref` / `--command`.

## Orchestration (several agents in one sandbox)

A sandbox is built from one template image, but the kit installs the delegate alongside, so a claude sandbox works as an orchestration environment with Claude Code as the parent.

- The kit installs the Codex CLI and registers it as a Claude Code plugin (`codex-rescue` + `/codex`); a no-op in a codex sandbox thanks to the `command -v` guard
- The shared Codex config seed keeps delegated runs from stalling on an approval prompt
- The delegate authenticates either by interactive login inside the sandbox (persists until `sbx rm`) or by proxy injection (`sbx secret set openai --sandbox <sandbox-name>`). With subscription auth, interactive login is the only option

**Cooperation across sandboxes is essentially impossible** (filesystems and networks are isolated, and in clone mode each holds its own clone). Hand-offs would have to go through GitHub, so keep tightly coupled orchestration inside one sandbox.

## Troubleshooting (auth)

There is no dedicated equivalent of `gh auth status`. In practice **`sbx ls` is the auth probe**: a list means auth is alive, an auth error means it is not.

If "cannot prompt the user for password", "store is locked" and similar persist after `sbx login`, `sandboxd` may be holding the auth store's lock. Recovery (macOS):

```bash
pkill sandboxd
rm -f ~/.docker/caches/com.docker.sandboxes/sandboxes/.posixage.lock
rm -f ~/.docker/caches/com.docker.sandboxes-auth/sandboxes-auth/.posixage.lock
rm -rf ~/.docker/caches/com.docker.sandboxes-auth/sandboxes-auth/ZG9ja2VyL2F1dGgvbWV0YWRhdGEvaHViL2RlZmF1bHQ=/
sbx ls && sbx login
```

Do not delete the sandbox data itself (the `com.docker.sandboxes` side).

**SSH / headless sessions:** sbx keeps credentials in the OS keychain, so `sbx login` fails over SSH / headless while the keychain is locked ([#180](https://github.com/docker/sbx-releases/issues/180) / [#186](https://github.com/docker/sbx-releases/issues/186)). Over SSH to macOS, run `security unlock-keychain ~/Library/Keychains/login.keychain-db` in the same shell; failing that, run `sbx login` once from a GUI session. On headless Linux, start a session D-Bus plus `gnome-keyring-daemon --components=secrets` and make sure `DBUS_SESSION_BUS_ADDRESS` is inherited. Auth is under active development upstream, so update `sbx` first.
