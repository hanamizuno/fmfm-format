# Repository Guidelines

This is the reference implementation of **fmfm**, a Markdown-based hiking-log format, written in [MoonBit](https://docs.moonbitlang.com). Read `README.md` for the goals and `docs/spec/format.md` for the format; this file is about working in the repository.

## Project Structure & Module Organization

- `moon.mod` — module `hanamizuno/fmfm`, `source = "src"`, pinned dependencies.
- `src/` — one package per directory; each has a `moon.pkg` (imports, `warnings`), `*.mbt` sources, `*_test.mbt` blackbox tests, and a generated `pkg.generated.mbti` (`moon info`, never edited by hand).
  - `diagnostic/` positions, ranges, diagnostics · `syntax/` front matter split, `:::` directive scanner, attribute grammar · `frontmatter/` position-aware YAML-subset tree · `ast/` the typed document model (+ RFC 3339 date-times) · `semantic/` lowering and validation · `json/` export and dump · `html/` semantic HTML renderer · root package: the `analyze` facade.
  - Planned: `markdown/` (cmark adapter, the only package allowed to import the Markdown library), `cli/` (the `fmfm` executable, native target).
- `docs/spec/` — the normative format specification, English (`format.md`, canonical) and Japanese (`format.ja.md`). Change both together.
- `docs/knowledge/` — OKF knowledge bundle: ADRs, architecture notes, conventions, research, runbooks. Record decisions and rationale there, not in chat logs. Start at `docs/knowledge/index.md`.
- `examples/` — complete sample logs; they double as documentation and (soon) golden-test inputs.
- `Dockerfile`, `compose*.yml`, `.sandbox/` — containers and Docker Sandboxes (`sbx`) kits inherited from the template; see `docs/knowledge/runbooks/agent-sandbox-sbx.md`.

Architecture rules (see ADR-0001/0002): no package but the adapters may import the Markdown or YAML library; `html` and `semantic` never import each other; nothing OS-specific below `cli`.

## Language

Public documents (`README.md`, `docs/spec/format.md`, `CHANGELOG.md`, issue and PR text) are written in English, with a Japanese counterpart kept alongside where one exists (`README.ja.md`, `format.ja.md`). Internal knowledge-bundle notes and code comments are English only.

## Build, Test, and Development Commands

```bash
just           # check + test (default target: js)
just fmt       # format code
just fmt-check # verify formatting
just check     # type check (moon check --deny-warn)
just test      # run tests
just test-update  # update snapshot tests
just info      # generate type definition files (.mbti)
just info-check   # verify generated .mbti files are up to date
just ci        # local CI equivalent for default target
just ci-all    # lint + js/native test matrix
just release-check-all  # release check on js + native
```

- Switch target: `just target=native check test`.
- Docker Compose (dev): `docker compose -f compose.dev.yml run --rm app just ci`.

## Coding Style & Naming Conventions

- `moon fmt` is the single source of truth for formatting (2-space indent). It spells the 32-bit integer type `Int32`; write `Int` and let the formatter normalise.
- Each top-level block is separated by `///|`; `///` doc comments attach to the following block.
- Naming: `snake_case` for variables/functions; `UpperCamelCase` for types, enums and variants. Diagnostic codes are kebab-case strings listed in the spec.
- Type parameter after `fn`: `fn[T] foo(x : T) -> T`. No `return` needed for the last expression. `nobreak` (not `else`) for functional for-loop exit values.
- Errors: declare with `raise` (`fn parse(s : String) -> Int raise ParseError`); handle with `expr catch { … } noraise { … }` or `try Some(expr) catch { _ => None }`. `try?` and `f!()` / `f()?` no longer exist.
- Current core API spellings (moon 0.1.20261023): slices instead of `substring` (`s[a:b]`, `s[a:]`), `StringView::to_owned()` to get a `String`, `trim()` not `trim_space()`, `StringBuilder()` not `StringBuilder::new()`, `Map([])` for an empty map, `x is None` not `x.is_empty()`, `@string.parse_double` / `parse_int` (import `moonbitlang/core/string`), `Int::unsafe_to_char` for code-unit → char.
- Derive `@debug.Debug` (import `moonbitlang/core/debug`), not `Show`; implement `Show` by hand only for types that are interpolated into user-facing strings. Every library `moon.pkg` sets `warnings = "-79"` to silence the "implicit impl promoted as method" deprecation that derives trigger; do not call derived trait methods with dot syntax across packages (use `ToJson::to_json(x)` style if you must).
- Keep messages single-line and in the shape described in `docs/knowledge/conventions/diagnostics.md`.

## Testing Guidelines

- Blackbox tests in `*_test.mbt`, qualified with the package alias (`@syntax.parse(...)`); whitebox tests in `*_wbtest.mbt` when private helpers need coverage.
- Snapshots: `inspect(value, content="…")` for strings/scalars, `debug_inspect(value, content="…")` for composed values. Write `content=""`, run `just test-update`, then **review the diff** — the snapshot is the spec. Never put a `debug_inspect` inside a loop; collect into an array first.
- Fixtures are multi-line string literals (`#|`) next to their expectations. Invalid inputs are tested through the formatted diagnostic text so positions are covered.
- Run both targets before a PR: `just ci-all`. `moon info` must leave `pkg.generated.mbti` unchanged (`just info-check`).
- Doc tests: ` ```mbt check ` blocks in `///` comments and `*.mbt.md` are compiled; keep the examples in `diagnostic.mbt`, `scanner.mbt`, `datetime.mbt`, `escape.mbt` runnable.

## Code Navigation & API Discovery

- Prefer `moon ide` over grep: `moon ide peek-def <Symbol>`, `moon ide find-references <Symbol>`, `moon ide outline <file|.>`, `moon ide rename <old> <new>`.
- `moon doc '<Type>'` for core APIs; `~/.moon/lib/core/*/pkg.generated.mbti` is the authoritative list of what exists in the installed toolchain.
- `moon check --deny-warn` treats warnings as errors — fix deprecations instead of suppressing them (the single package-level exception is documented above).

## Commit & Pull Request Guidelines

- Conventional Commits: `feat: add trail-condition section attribute`, `fix: scanner accepts CRLF`, `docs(spec): define severity levels`, `chore: bump moonbit-community/cmark`.
- Spec changes: update `docs/spec/format.md` **and** `format.ja.md`, the diagnostic table, and the snapshot tests in the same PR; add a CHANGELOG line. A change to the JSON `export` shape or HTML class/`data-*` names is a format change and needs an ADR or an open-questions entry.
- Before PR: `just ci-all`. Include diagnostics output or rendered snippets when behaviour or CLI output changes.
- PR description: purpose, summary, how to test, related issues (`Closes #123`).

## Security & Configuration Tips

- Do not commit secrets. AI agents run in Docker Sandboxes (`sbx`); credentials are injected by the host proxy and never readable inside the VM.
- Dependencies are pinned in `moon.mod`; update deliberately and rerun `just ci-all`. The mooncakes registry redirects package archives to a CloudFront host that must be on the sandbox network allowlist (`.sandbox/kit/spec.yaml`); a `403 Approval required for …cloudfront.net` from `moon add` means the host changed again.
- The MoonBit toolchain tracks the latest release; CI logs the version in the "Moon version" step.
