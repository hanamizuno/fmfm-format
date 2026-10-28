---
type: ADR
title: Parse into a normalized, typed AST; HTML is one exporter among several
description: fmfm never converts Markdown straight to HTML. Every consumer works from the HikeDocument AST.
tags: [architecture, accepted]
timestamp: 2026-10-28T00:00:00Z
---

# ADR-0001: Parse into a normalized, typed AST; HTML is one exporter among several

## Status

Accepted — 2026-10-28

## Context

The project goal is a decentralised hike-log format: the canonical record is a Markdown file on the author's own site, and the same file must be readable by humans, validated in CI, indexed by third-party search or map services, and rendered to HTML. A Markdown→HTML pipeline with ad-hoc post-processing would tie the format to one renderer and make validation and JSON export second-class.

The implementation language is MoonBit (typed AST, enums for closed vocabularies, native and Wasm targets).

## Decision

The processing pipeline is:

```text
source text
  → front matter split                 (syntax)
  → directive scan + attribute parse   (syntax)       → RawDocument + syntax diagnostics
  → lowering / semantic validation     (semantic)     → Document    + semantic diagnostics
  → exporters: HTML, JSON, (GeoJSON, feeds, … later)
```

* `Document` (the "Hike AST") is the **only** public data model. Its types are defined by this project (`Metadata`, `Block`, `Waypoint`, `Hazard`, `TrailCondition`, `GeoPoint`, `Severity`, `DateTime`, …) and never expose types of the Markdown or YAML libraries.
* Syntax and semantics are separate stages with separate diagnostics. The syntax stage produces a loosely-typed `RawDocument` (attribute values are strings with positions). The semantic stage converts it into the typed `Document` and reports every value that does not fit (unknown severity, latitude out of range, missing required attribute, `started_at` after `ended_at`, …).
* **Markdown prose is stored in the AST as source text** (`Block::Markdown { source, range }`) rather than as a parsed inline tree. Exporters that need rendered prose call the Markdown adapter at export time. This keeps the core packages free of the Markdown library and lets the parser be swapped without touching the AST or the JSON shape. A normalized inline AST can be added later as an *additional* representation if a consumer needs it.
* Exporters are pure functions over `Document`. The HTML renderer does not know about validation, and the validator does not know about HTML.

Rejected:

* Direct Markdown→HTML with a plugin that emits HTML for `:::` blocks (what most static-site generators do): no typed model, no JSON, validation would have to re-parse HTML.
* Exposing the Markdown library's AST as the public model: couples every consumer to one library's types and its breaking changes.

## Consequences

* Every exporter and the validator get one stable input; adding GeoJSON or Atom later is a new package, not a parser change.
* Two parses happen (fmfm's directive scan, then CommonMark per segment). This is cheap for hike logs (kilobytes) and simplifies the extension story; see [ADR-0002](/docs/knowledge/adr/0002-directive-layer-above-cmark.md).
* Link reference definitions written outside a directive are not visible inside it unless the adapter merges definitions across segments. This is a known limitation to solve in the Markdown adapter (two-pass parse with shared `defs`), not in the AST.
* Related: [architecture/pipeline-and-packages.md](/docs/knowledge/architecture/pipeline-and-packages.md).
