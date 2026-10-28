# Changelog

All notable changes to this project should be documented in this file.

## [Unreleased]

### Added

- Initial template state.
- Docker Sandboxes (`sbx`) kits in `.sandbox/` for running AI agents in a microVM: a shared mixin (MoonBit toolchain, just, Node, C toolchain, Codex delegation, network allowlist, proxy-injected GitHub credential) and two fork kits that replace the built-in agents' YOLO launch command. See `docs/knowledge/runbooks/agent-sandbox-sbx.md`.

### Changed

- MoonBit dependencies, GitHub Actions, base images (Debian trixie), just, and secretlint bumped; `moon.pkg` uses `pkgtype(kind: "executable")`.
- Sources follow the moon 0.1.20261016 formatter: `Int32` spelling and `start~ : Int32 = 0` for labelled arguments with defaults; `moonbitlang/quickcheck` 0.15.0 (0.14.0 still ships `moon.mod.json`, which current `moon` rejects).
- `fib` now returns F(n) (`fib(10) == 55`); it previously returned F(n+1).

### Removed

- Dev Container (`.devcontainer/`, the Dockerfile `devcontainer` stage) and the Proton Pass (`pass-cli`) secret workflow; AI agents run in Docker Sandboxes (`sbx`).
