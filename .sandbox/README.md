# .sandbox

Kits for running AI agents inside a microVM with [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`).

- `kit/` — shared mixin (MoonBit toolchain + just + Node + C toolchain, Codex delegation, network / credential rules)
- `claude-auto/` / `codex-approve/` — fork kits that replace the built-in agents' default YOLO launch command

## Usage

**Run these on the host** — there is no `sbx` inside the VM. Sandbox names are listed by `sbx ls` (default: `<agent>-<directory-name>`).

```bash
# Create the sandbox (--clone is mandatory; the agent is not started yet)
sbx create --clone --kit ./.sandbox/kit claude .

# Launch the agent. Always enter this way: `sbx run` would start the default YOLO entrypoint.
sbx exec -it -w "$PWD" claude-<directory-name> claude --permission-mode auto

# Register a fine-grained GitHub PAT for this sandbox only (the value is prompted for)
sbx secret set github --sandbox claude-<directory-name>

# List / stop / remove (rm wipes all VM state, including commits that were not pushed)
sbx ls
sbx stop <sandbox-name>
sbx rm <sandbox-name>
```

After changing a kit, apply it with `sbx rm` and recreate the sandbox.

## Reviewing the sandbox's changes on the host

With `--clone`, commits made in the sandbox do not reach the host on their own. A running sandbox exposes a git daemon, reachable as the `sandbox-<sandbox-name>` remote.

```bash
# Just look at the changes
git fetch sandbox-<sandbox-name>
git diff HEAD...sandbox-<sandbox-name>/<branch>

# Bring them into a local branch (set the upstream once)
git branch --set-upstream-to=sandbox-<sandbox-name>/<branch> <branch>
git config branch.<branch>.pushRemote origin   # keep pushes going to origin

# From then on, follow with fetch + pull
git fetch sandbox-<sandbox-name>
git pull --ff-only
```

Stopping or removing the sandbox takes the git daemon with it, so push any commit you want to keep to `origin` first.

Details: [docs/knowledge/runbooks/agent-sandbox-sbx.md](../docs/knowledge/runbooks/agent-sandbox-sbx.md) / verification status: [docs/knowledge/research/sbx-verification.md](../docs/knowledge/research/sbx-verification.md)
