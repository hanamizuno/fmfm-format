# Repository Guidelines

This is a [MoonBit](https://docs.moonbitlang.com) project.

## Project Structure & Module Organization

- `moon.mod` — module definition (name, version, dependencies, `source = "src"`). Placeholder module name: `myuser/myapp` — rename for your project.
- `src/` — library package:
  - `moon.pkg` — per-directory package configuration (imports, options).
  - `*.mbt` — source files; `*_test.mbt` — blackbox tests; `*_wbtest.mbt` — whitebox tests; `*.mbt.md` — doc tests.
  - `pkg.generated.mbti` — generated type interfaces (`moon info`); never edit by hand.
- `src/main/` — executable entry point (`pkgtype(kind: "executable")` in `moon.pkg`).
- Docs & shared knowledge: `docs/knowledge/` — an OKF bundle (ADRs, architecture notes, conventions, runbooks, research) that both humans and AI agents read and write. Start at `docs/knowledge/index.md`; record decisions and rationale there instead of leaving them in chat logs.
- Containers: `Dockerfile` (multi-stage: `dev`, `build`, `prod`), `compose.dev.yml` (dev), `compose.yml` (prod).
- Agent sandbox: `.sandbox/` — [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) (`sbx`) kits for running AI agents in a microVM. `sbx` runs on the host. See `docs/knowledge/runbooks/agent-sandbox-sbx.md`.

## Build, Test, and Development Commands

```bash
just           # check + test (default target: js)
just fmt       # format code
just fmt-check # verify formatting
just check     # type check (moon check --deny-warn)
just test      # run tests
just test-update  # update snapshot tests
just bench     # run benchmarks
just run       # run main
just info      # generate type definition files (.mbti)
just info-check   # verify generated .mbti files are up to date
just ci        # local CI equivalent for default target
just ci-all    # lint + js/native test matrix
just release-check-all  # release check on js + native
```

- Switch target: `just target=native check test`.
- Docker Compose (dev): `docker compose -f compose.dev.yml run --rm app just ci`.

## Coding Style & Naming Conventions

- `moon fmt` is the single source of truth for formatting (2-space indent).
- Each top-level block is separated by `///|`; `///` doc comments attach to the following block.
- Naming: `snake_case` for variables/functions (lowercase only); `UpperCamelCase` for types, enums, and enum variants.
- Type parameter comes after `fn`: `fn[T] foo(x : T) -> T`.
- No `return` needed — the last expression is the return value.
- `nobreak` (not `else`) for functional for-loop exit values; multi-value `loop (a, b) { ... }` is deprecated — use `for i = a, j = b; cond; updates { ... } nobreak { ... }`.
- No `try` needed for error propagation — automatic; declare with `raise` (e.g. `fn parse(s : String) -> Int32 raise ParseError`).
- `moon fmt` spells integer types `Int32` / `UInt32` (not `Int` / `UInt`), and a labelled argument with a default value is `name~ : T = default` (`name? : T` is reserved for optional arguments without a default, seen as `Option[T]` in the body).
- Legacy `function_name!(...)` and `function_name(...)?` are deprecated.

## Testing Guidelines

- Blackbox tests live in `*_test.mbt`; whitebox tests in `*_wbtest.mbt`.
- Blackbox tests and doc tests must qualify the package under test (`@myapp.fib(10)`, not `fib(10)`); unqualified access is the `test_unqualified_package` warning, an error under `--deny-warn`.
- Snapshot testing: `inspect(value, content="...")` for scalars, `debug_inspect(value, content="...")` for composed values (arrays, maps, tuples — their `Show`-based `inspect` is deprecated). Write the call with empty `content` and run `moon test --update` to fill it, then review the diff.
- Doc tests: ` ```mbt check ` / ` ```mbt test ` blocks in `*.mbt.md` files and `///` comments are checked/executed.
- Property-based tests: `moonbitlang/quickcheck` (`@qc.quick_check_fn`, see `src/quickcheck_test.mbt`).
- Benchmarks: `test "name" (b : @bench.T)` in `*_bench.mbt`, run with `just bench`.
- Run both targets before release: `just ci-all`.

## Code Navigation & API Discovery

- Prefer `moon ide` commands over grep for code navigation (semantic, distinguishes definitions from call sites):
  - `moon ide peek-def <Symbol>` — show symbol definition
  - `moon ide find-references <Symbol>` — find all references
  - `moon ide outline <file|.>` — package/file outline
  - `moon ide rename <old> <new>` — project-wide rename
- Use `moon doc '<Type>'` (or `moon ide doc`) to explore APIs before implementing.
- `moon check --deny-warn` treats warnings as errors — deprecation warnings must be fixed, not ignored.

## Commit & Pull Request Guidelines

- Commit style: prefer Conventional Commits when possible
  - Examples: `feat: add fib iterator`, `fix: correct sum bounds`, `chore: bump moonbitlang/quickcheck`.
- Before PR: run `just ci` (or `just release-check`) locally/inside the container and fix issues.
- PR description: purpose, summary of changes, how to test, related issues (`Closes #123`).
- Include logs or snapshots when changing behavior or CLI output.

## Security & Configuration Tips

- Do not commit secrets; prefer env vars and Compose overrides.
- AI agents run in Docker Sandboxes (`sbx`). GitHub credentials and other secrets are injected by the host-side proxy (`sbx secret set ...`); never try to read, print, or copy token values from the environment.
- Dependencies are pinned to exact versions in `moon.mod` (`moon add <pkg>` pins the latest); update deliberately and rerun `just ci-all`.
- The MoonBit toolchain tracks the latest release (cli.moonbitlang.com hosts only `latest`); CI logs the version used in the "Moon version" step.
- CI runs format/interface checks and a js/native test matrix via GitHub Actions; keep the pipeline green before merging.
