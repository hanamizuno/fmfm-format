---
type: Reference
title: Markdown and YAML libraries for MoonBit (2026-10 survey)
description: Comparison of the CommonMark parsers and YAML readers available on mooncakes, and the picks for fmfm v0.1
tags: [research, markdown, yaml, dependencies]
timestamp: 2026-10-28T00:00:00Z
---

# Markdown and YAML libraries for MoonBit (2026-10 survey)

## Question

Which existing MoonBit libraries should fmfm build on for (1) parsing the CommonMark prose and (2) reading the YAML front matter, so that the project does not maintain its own Markdown or YAML implementation and stays usable on the `js`, `native` and (later) `wasm-gc` targets?

## Method

* Searched the mooncakes registry index (`~/.moon/registry/index`, toolchain `moon 0.1.20261023`) for `markdown`, `cmark`, `commonmark`, `yaml`.
* Cloned the source of each serious candidate from GitHub and read `moon.mod`, the README and the generated `pkg.generated.mbti` interfaces. Package downloads from mooncakes were blocked by the sandbox network policy at the time of the survey, so nothing below has been compiled yet; see "Follow-ups".
* The Markdown candidates were judged on CommonMark compliance, source positions, extensibility for custom blocks, dependency weight, license, and maintenance signals (release count, last release).

## Findings — Markdown

| Package | Version / date | License | Positions | Custom blocks | Deps | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `moonbit-community/cmark` | 0.4.12, 2026-10-13 (12 releases; successor of `rami3l/cmark`, 17 more) | Apache-2.0 | Yes: `TextLoc` with line/column and code-unit offsets when `locs=true` | No custom `Block` variant. Extension points are the composable `Renderer` (`Renderer::compose`), `Mapper` and `Folder` | `casefold`, `charclass`, `moonbitlang/async` (only used by its native CLI) | Port of OCaml `cmarkit`. Tables, task lists, footnotes, strikethrough, math. HTML renderer with `safe` mode and a `node_attributes` hook. `cmark_cli` is native-only but is a separate package, so it does not restrict the library's targets. |
| `mizchi/markdown` | 0.8.4, 2026-10-19 (31 releases) | MIT | Yes: `Span { from, to }` offsets | Yes: built-in `Block::Directive(name, meta, children)` for `:::name meta` containers, `Frontmatter` block, `Attributed` blocks | Heavy: `moomaid`, `font`, `layout`, `pixelmatch`, `tui-terminal-buffer`, `css`, `crater-layout`, `syntree`, `parser`, `x` | CommonMark 0.31.2 (all 652 examples), GFM, incremental parsing, mdast-shaped AST. The directive support is attractive but the transitive dependency set (Mermaid rendering, fonts, layout engines) is far larger than a format library should pull in. |
| `shiguri-01/markdown` | 0.1.1, 2026-06-13 (2 releases) | Apache-2.0 | `SourceRange` on elements | Yes: custom block/inline rules (`Rule::block`, `Rule::inline`) and a generic `AstExtension(name, attrs, children)` node | none | Event-driven (`Processor` + `Sink`). The cleanest extension model of the three, but young and with little usage so far. |
| `kokic/cmark` | 0.1.1, 2026-08 | **AGPL-3.0** | — | — | — | Port of pulldown-cmark, native-only. License is incompatible with an MIT project. Excluded. |
| `oilleelssq-wq/moonmarkdown` | 0.2.0, 2026-07 | MIT | — | — | — | Markdown→HTML only, no AST. Excluded. |
| `moonbit-community/tree-sitter-markdown` | 0.5.4, 2026-10-25 | MIT | Yes | Grammar-level | Tree-sitter runtime | A concrete syntax tree for editors; too heavy for rendering and no HTML output. Excluded. |

## Findings — YAML

| Package | Version / date | License | Positions | Subset / limits | Deps | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `moonbit-community/yaml` | 0.0.8, 2026-10-18 (8 releases) | MIT | Errors carry `Marker { index, line, col }`; the event API (`Parser` + `MarkedEventReceiver`) reports a `Marker` **per event**, so a position-aware tree can be built on top | "Simplified YAML subset which can be converted to JSON"; `Yaml` enum maps to `Json` | none | Port of yaml-rust2. `Yaml::load_from_string` returns one value per document; `Map[String, Yaml]` keeps insertion order. Duplicate keys are not reported by the high-level loader, but are detectable from the event stream. |
| `moonbitstack/moonyaml` | 0.1.2, 2026-10-27 (3 releases) | Apache-2.0 | Errors carry `At { at, line, column }`; `Node` (document mode) has no positions | YAML 1.2 core schema; `strict` sub-package (block structure only, every scalar a string, no flow, no anchors, no tags, no repeated keys); configurable depth/budget limits and `Duplicates::Reject` | none | Very new. The `strict` dialect is almost exactly the subset fmfm wants to specify, and it reports repeated keys, which fmfm must diagnose. Worth re-evaluating once it has a few more releases. |
| `ingydotnet/yamlstar` | 0.1.26 | MIT | — | — | external YAMLStar runtime | A binding, not a pure MoonBit implementation. Excluded. |
| `myfreess/yaml` | 0.1.0, 2025-08 | MIT | — | — | — | No repository, no description, single release. Excluded. |

## Recommendation

* **Markdown: `moonbit-community/cmark`.** Most mature CommonMark implementation on mooncakes, permissive license, source locations, small dependency set, and a composable renderer. The lack of a custom `Block` variant is acceptable because fmfm deliberately keeps its directive syntax in a thin layer *above* the Markdown parser (see [ADR-0002](/docs/knowledge/adr/0002-directive-layer-above-cmark.md)): fmfm splits the source into Markdown segments and directive blocks, and only the Markdown segments are handed to cmark. `shiguri-01/markdown` is the fallback if cmark turns out to be unsuitable (its rule system would let the directive become a real block rule).
* **YAML: `moonbit-community/yaml`, through its event API.** It is maintained under the same organisation as cmark, has no dependencies, and its per-event `Marker` lets fmfm attach line/column positions to every front-matter key so that semantic diagnostics (`started_at` after `ended_at`, negative distance, …) can point at the exact line. The subset fmfm accepts (block mappings, block sequences, plain/quoted scalars, one document, no anchors/aliases/tags) is enforced by fmfm's own tree builder; see [ADR-0004](/docs/knowledge/adr/0004-front-matter-yaml-subset.md). `moonbitstack/moonyaml` (`strict` dialect) is the alternative to re-check in a few months.

## Follow-ups

* Compile a spike with both picks as soon as package downloads are possible from the sandbox (the registry now redirects archives to `d251robtodj7m8.cloudfront.net`, which the sbx kit allowlist does not contain yet — see the sbx runbook).
* Confirm cmark's `locs=true` positions are stable enough to offset into the original file (fmfm parses each Markdown segment separately).
* Confirm `moonbit-community/yaml` builds on the `js` target (it is pure MoonBit; expected to work).

## Sources

* mooncakes registry index, read 2026-10-28.
* https://github.com/moonbit-community/cmark.mbt (commit of 2026-10-13, v0.4.12)
* https://github.com/mizchi/markdown.mbt (v0.8.4)
* https://github.com/shiguri-01/markdown.mbt (v0.1.1)
* https://github.com/moonbit-community/yaml.mbt (v0.0.8)
* https://github.com/moonbitstack/moonyaml (v0.1.2)

---

Last verified: 2026-10-28
