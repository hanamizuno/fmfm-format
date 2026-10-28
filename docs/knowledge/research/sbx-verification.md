---
type: Research
title: sbx kit verification status and open questions
description: What is verified, carried over, or still untested for the Docker Sandboxes (sbx) kits, plus the host trial checklist
tags: [sandbox, verification]
timestamp: 2026-10-20T00:00:00Z
---

# sbx kit verification status and open questions

Snapshot of what is known about the kits in `.sandbox/` ([operating procedure](/docs/knowledge/runbooks/agent-sandbox-sbx.md)). The spec files follow the [kit spec reference](https://docs.docker.com/ai/sandboxes/customize/kit-reference/).

**Status in one line: the kit (`moonbit-agent-env`) has been run in daily use on a real sbx host, and the Dev Container was removed on that basis (2026-10).** The kits were ported from a sibling template (pnpm + Biome); "Verified in a real sandbox" below lists what has been observed here, the other sections keep carried-over and still-open items apart.

## Verified in a real sandbox (2026-10)

Observed in a `claude` sandbox created with this kit (clone mode, linux):

- The toolchain resolves from agent shells: `moon` 0.1.20260920 / `moonc` v0.10.14, `just`, Node v22, and a C toolchain
- **`just ci-all` passes** — fmt/info checks plus js and native tests. The native build prints a `-Wunused-result` warning from `moonbitlang/async`'s C stub; harmless
- **The domain list was incomplete.** `download.mooncakes.io` answers GET with `302 Found` to `https://d15l9c1mnzh3r.cloudfront.net/...` (package archives and `symbols.zip`), which the default policy blocked until approved on the host. The kit now allows exactly that host
- `gh` API calls and HTTPS `git push` go through header injection. The host's `origin` is mirrored as-is; when it is an SSH URL (`git@github.com:...`) the push fails (no key in the VM), so push to the HTTPS URL instead — now in `agentInstructions`
- Docker builds (`dev` / `prod` targets) work with the per-sandbox daemon


## Carried over from the sibling template (observed there, not re-verified here)

Observed on the built-in claude template (`docker/sandbox-templates:claude-code-docker`), Apple Silicon host, clone mode, with a kit of the same structure (mixin + two fork kits, same `credentials` / `agentInstructions` blocks).

Environment:

- Base image Ubuntu 26.04 / arm64, bundled Node v22, `~/.codex` empty, agent user (uid 1000, home `/home/agent`) with passwordless sudo and the docker group
- `${WORKDIR}` in `setup.files` content expands to the workspace's absolute path. In clone mode the workspace path **mirrors the host's absolute path**, so `[projects."..."]` in the Codex config resolves the same as in direct mode

Behaviour:

- **The built-in claude template launches `claude --dangerously-skip-permissions`** (seen with `ps` in the VM). A mixin alone cannot override it
- **Method A works**: `sbx create` completes the kit install without starting the agent, and the `sbx exec` process shows as `claude --permission-mode auto` in `ps` with no bypass flag. **Subscription auth is kept — no re-login.** `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` / `CLAUDE_CODE_OAUTH_TOKEN` are unset and the tokens in `~/.claude/.credentials.json` are sentinels
- **`git push` (https) goes through header injection** (`format: "token %s"`); `gh api user`, `git ls-remote`, `git push --dry-run` succeed. `GH_TOKEN` is a sentinel (`proxy-managed`)
- Deny-by-default networking is effective (blocked domains get 403 `no matching allow rule`). **The default policy does not allow `console.anthropic.com` / `claude.ai`**, hence the kit's allow entries. `claude.ai` returns 403 even when allowed — the body is a Cloudflare bot challenge, not a policy block
- Running `pkill -f <pattern>` inside the VM matches the caller's own shell and kills it — hence the `agentInstructions` entry
- An `mcp-gateway` (`http://mcp-gateway.docker.internal/mcp`) that no kit declares is registered and connected; it appears to be provided by sbx
- The `claude mcp list` warning "claude.ai connectors are disabled because ANTHROPIC_API_KEY or another auth source is set" comes from the proxy-managed credential counting as "another auth source". Only claude.ai organization connectors are disabled; Claude Code itself is unaffected

## Checked before the sandbox trial (in the former Dev Container)

Done on linux-aarch64 (Debian bookworm devcontainer), which matches the sbx template's architecture but not its distribution:

- **`moon` works through a symlink.** With only symlinks to `~/.moon/bin/*` on a minimal `PATH` (`env -i`, no `~/.moon/bin`), `moon check --deny-warn --target js`, `moon test` on js and native, and `moon info` all pass, including dependency download. This is what the kit's `/usr/local/bin` symlink step relies on
- The MoonBit installer supports `Linux aarch64` and only appends `~/.moon/bin` to `PATH` in the rc file of `$SHELL` — never read by the non-interactive shells agents spawn, which is why the symlink step exists
- Domains were derived from the binaries and installers rather than guessed: `cli.moonbitlang.com` (installer, toolchain and core archives), `mooncakes.io` (registry index git remote `https://mooncakes.io/git/index`), `download.mooncakes.io` (package archives), `just.systems` (installer; with `--tag` it skips `api.github.com` and downloads the GitHub release asset directly)
- `claude --permission-mode auto` and `codex --approve-for-me` exist as flags (Claude Code and codex-cli 0.154.0 in the devcontainer)
- The three spec files parse as YAML and use only fields from the kit reference

## Not verified

Update the spec files and this section as these get answered.

1. ~~**The whole MoonBit install path on the real Ubuntu template**~~ — done (see "Verified in a real sandbox"): that the installer runs as uid 1000 with `$HOME=/home/agent`, that `build-essential` installs under the default policy, that the symlinks resolve, and that `just ci-all` passes in the VM (native needs the C toolchain)
2. ~~**Whether the domain list is complete.**~~ Answered: `download.mooncakes.io` redirects to `d15l9c1mnzh3r.cloudfront.net` (added). Still watch for further redirects: Release assets may redirect to a host other than `release-assets.githubusercontent.com` / `objects.githubusercontent.com`, and `download.mooncakes.io` may itself redirect to a storage backend. A block shows up as `Blocked by network policy: domain <host>` — add that host
3. **`sbx kit validate`** on all three kits, including how `extends:` resolves
4. **Method B (fork kits)** — untested in the sibling template as well: whether stacking `--kit` twice applies both, whether `ps` shows no bypass flag, and where the no-OAuth constraint surfaces. How `entrypoint` / `command` inheritance resolves is unpublished, so **always confirm with `ps`**
5. **The codex template** — everything above was observed with the claude template only. If the codex template seeds `~/.codex/config.toml`, `onlyIfMissing` means the kit's seed is not applied; method A with a ChatGPT subscription is untested
6. **Secret persistence across `sbx rm`** — whether a sandbox-scoped secret survives recreation. Re-check with `gh api user` after recreating
7. **Host-only checks** (there is no `sbx` inside the VM) — checklist items 5, 12 and the second half of 13

## Host trial checklist

1. `sbx version`
2. `sbx login`
3. `sbx kit validate ./.sandbox/kit`, `./.sandbox/claude-auto`, `./.sandbox/codex-approve`
4. Launch-mode override. Method A: starts on subscription auth without asking to log in again. Method B: note where it demands an API key. For both, inside the VM: `git remote -v` and `ls /run/sandbox/source` show clone mode, and `ps -eo args | grep claude` shows no bypass flag
5. `sbx secret set github --sandbox <sandbox-name>` then `sbx secret ls` — the scope is the sandbox, not global
6. In the VM: `command -v moon just node cc` all resolve; `moon version --all`; `ls -l /usr/local/bin/moon` points into `/home/agent/.moon/bin`. Repeat `command -v moon` from a non-interactive shell (`sbx exec <sandbox-name> sh -c 'command -v moon'`)
7. In the VM: `just ci-all` (fmt/info checks, js and native tests). `git status` stays clean afterwards — `_build/` and `.mooncakes/` are gitignored
8. `claude plugin list` shows `codex@openai-codex`; `cat ~/.codex/config.toml` shows the seed with `${WORKDIR}` expanded
9. `gh api user` succeeds while `echo "$GH_TOKEN"` prints a sentinel. Also `git ls-remote` and `git push --dry-run`
10. Audit `sbx policy ls`. `curl` to a domain outside the allowlist is refused; `moon update` and a cold `moon check` (after `rm -rf .mooncakes`) are not
11. Codex the same way as 4 — `${WORKDIR}` expansion and the launch arguments in `ps`
12. Leave and re-enter: reconnects without re-running install. `sbx rm` and recreate: install runs again. **With method A, reconnect through `sbx exec` too**
13. Commit in the VM and `git push` — it reaches GitHub. From the host, `git fetch sandbox-<sandbox-name>` retrieves it as well

## Criteria for removing agents from the devcontainer (resolved)

Resolved 2026-10: after running in daily use on sbx, the Dev Container was removed entirely (not just shrunk), together with the pass-cli layer. The original criteria, kept for the record:

- The everyday task set (tests on both targets, gh / PR operations, unattended Codex delegation) has run on sbx for 2–4 weeks without falling back to the devcontainer
- Every pass-cli use case (gh, git push, task API keys) is covered by credential injection
- The removal scope is settled: the agent install block in `post-create.sh`, the pass-cli layer in the `Dockerfile`, the auth volumes in `.devcontainer/compose.yaml`, `codex-config.toml`, `pass-relogin`, and the pass-cli documentation
