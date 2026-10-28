---
type: Architecture Note
title: Pipeline and package layout
description: How a hike-log Markdown file flows through fmfm, which MoonBit package owns each stage, and how the pieces are tested
tags: [architecture, packages, testing]
timestamp: 2026-10-28T00:00:00Z
---

# Pipeline and package layout

## Context

fmfm turns a Markdown hike log (CommonMark + YAML front matter + a few `:::` directives) into a typed `Document`, validates it, and exports HTML and JSON. The user-facing description is in `README.md` and the normative format in `docs/spec/format.md`; this note explains the internal structure and the reasons behind it. Decisions are recorded in [ADR-0001](/docs/knowledge/adr/0001-pipeline-and-normalized-ast.md) … [ADR-0004](/docs/knowledge/adr/0004-front-matter-yaml-subset.md).

## Data flow

```text
                 ┌──────────────┐
  source ──────▶ │   syntax     │  front matter split, directive scan, attribute parse
                 └──────┬───────┘
                        │ RawDocument + syntax Diagnostics
                 ┌──────▼───────┐      ┌──────────────┐
                 │  frontmatter │◀────▶│ (yaml lib)   │  YAML subset → Node tree with positions
                 └──────┬───────┘      └──────────────┘
                        │
                 ┌──────▼───────┐
                 │   semantic   │  typing, required attributes, ranges, cross-field checks
                 └──────┬───────┘
                        │ Document + semantic Diagnostics
          ┌─────────────┼───────────────┐
   ┌──────▼─────┐ ┌─────▼──────┐  ┌─────▼──────┐
   │    json    │ │    html    │  │  (geojson) │   exporters, pure functions over Document
   └────────────┘ └─────┬──────┘  └────────────┘
                        │ prose segments
                 ┌──────▼───────┐      ┌──────────────┐
                 │   markdown   │◀────▶│ (cmark lib)  │  CommonMark → HTML, the only cmark user
                 └──────────────┘      └──────────────┘
```

Diagnostics from both stages share one type (`diagnostic.Diagnostic`) and one text format, `file:line:col: error[code]: message`, so the CLI and future editor integrations print them identically.

## Packages (module `hanamizuno/fmfm`, source root `src/`)

| Package | Depends on | Responsibility |
| --- | --- | --- |
| `diagnostic` | core | `Position`, `Range`, `Level`, `Diagnostic`, text formatting. Shared vocabulary; no logic beyond formatting. |
| `syntax` | `diagnostic` | Line-level scanner: front matter extraction, top-level fenced-code tracking, `:::` directive detection, attribute grammar. Output is `RawDocument` (strings + ranges). Has no opinion about which directives or attributes exist. |
| `frontmatter` | `diagnostic`, `moonbit-community/yaml` | Builds a position-aware `Node` tree from the YAML events, enforcing the admitted subset. |
| `ast` | `diagnostic` | The public model: `Document`, `Metadata`, `Block`, directive payloads, `GeoPoint`, `Severity`, `TrailStatus`, `DateTime` (RFC 3339 subset parser lives here because the type does). |
| `semantic` | `ast`, `syntax`, `frontmatter`, `diagnostic` | Lowering `RawDocument` → `Document`: known directive names, attribute typing, required/unknown attributes, numeric ranges, time ordering. Produces semantic diagnostics. Unknown directives and attributes are preserved with a warning. |
| `json` | `ast` | Stable public JSON shape (`export`) and the full debugging dump including ranges (`dump`). |
| `html` | `ast` | Semantic HTML fragment with `data-*` attributes; takes a `(String) -> String` Markdown renderer as a parameter so it stays free of cmark. HTML escaping lives here. |
| `markdown` | `moonbit-community/cmark` | Adapter: `to_html(source)`. The only package allowed to import cmark. |
| `fmfm` (root) | all of the above | Facade: `parse`, `validate`, `to_json`, `to_html` wired together with the real adapters. Library users import this. |
| `cli` | root, `moonbitlang/core/argparse`, file IO | The `fmfm` executable: `validate`, `render`, `dump`, `export`. Native target. Exit code 0 = no errors, 1 = diagnostics with level error, 2 = usage / IO failure. |
| `css` (asset) | — | Default stylesheet, shipped as a string constant for `render` and as a file in `assets/`. Not part of the format. |

Rules that keep the layout honest:

* Library-specific types (cmark, yaml) never appear in a public signature outside their adapter package.
* `html` and `semantic` do not import each other.
* Nothing OS-specific (file IO, env) below `cli`, so the library compiles for `wasm-gc` later.

## Testing strategy

* Each package has blackbox `*_test.mbt` with `inspect` / `debug_inspect` snapshots. Inputs are multi-line string literals (`#|`), so a fixture and its expectations sit side by side and `moon test --update` refreshes them.
* `examples/` holds complete, valid hike logs that double as documentation; the CLI golden check (`just golden`, to be added with the CLI) runs `validate`, `export` and `render` over them and diffs against `examples/expected/`.
* Invalid inputs live in the same test files as the diagnostics they must produce; the diagnostic text (`file:line:col: …`) is snapshotted so positions are covered.
* Property tests (`moonbitlang/quickcheck`) for the attribute parser (round-trip of quoted values) and the RFC 3339 parser once the dependency can be fetched.

## Operational implications

* Adding a directive type = one enum variant in `ast`, one lowering function in `semantic`, one case each in `json` and `html`, plus spec text. The scanner does not change.
* Changing the Markdown library = rewriting `markdown` only.
* The JSON `export` shape is a public contract from v0.1 on; changes require a `format_version` bump and a CHANGELOG entry. The `dump` shape is not a contract.

## Related

* [open-questions.md](/docs/knowledge/architecture/open-questions.md) — points the brief left open, with options and the current lean.
