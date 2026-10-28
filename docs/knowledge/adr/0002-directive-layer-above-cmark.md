---
type: ADR
title: Use moonbit-community/cmark for prose, with fmfm directives scanned in a thin layer above it
description: Why the Markdown library is not patched, and how directive bodies and positions are handled
tags: [dependencies, markdown, accepted]
timestamp: 2026-10-28T00:00:00Z
---

# ADR-0002: Use `moonbit-community/cmark` for prose, with fmfm directives scanned in a thin layer above it

## Status

Accepted — 2026-10-28 (pending a compile spike; see the research note)

## Context

See [research/markdown-yaml-libraries.md](/docs/knowledge/research/markdown-yaml-libraries.md). The brief asked for CommonMark compatibility, source positions, and *not* patching custom syntax deep into a third-party parser. Of the candidates, `moonbit-community/cmark` is the most mature but has no custom block variant; `mizchi/markdown` has a built-in `:::` directive block but pulls in a large unrelated dependency tree; `shiguri-01/markdown` has a clean rule system but is young.

## Decision

* Depend on `moonbit-community/cmark` (`cmark` for parsing, `cmark_html` for rendering) for Markdown prose.
* fmfm's own **directive scanner** runs before cmark. It walks the source line by line, tracks top-level fenced code blocks (so a `:::` inside a code fence is not a directive), and splits the document into `Markdown` segments and `Directive` blocks. Only Markdown segments (and directive bodies, which are Markdown) are given to cmark.
* Directives are recognised only at the top level, at column 0. Indented `:::` lines, or `:::` inside block quotes and list items, are ordinary Markdown text in v0.1.
* Every segment carries its absolute range in the original file. cmark is run with `locs=true` and its line numbers are offset by the segment's start line when fmfm needs positions inside prose (not required for v0.1 diagnostics).
* The Markdown library lives behind one adapter package (`markdown`), which exposes `to_html(source) -> String`. No other package imports cmark.

Rejected:

* `mizchi/markdown` for its directive support: the dependency weight (Mermaid, fonts, layout engines) is unacceptable for a core library that must stay small and Wasm-friendly, and relying on its directive grammar would tie the fmfm syntax to that library's choices.
* Patching cmark's block parser: maintenance burden and drift from upstream.

## Consequences

* fmfm controls the directive grammar completely and can evolve it (attributes on separate lines, nesting) without upstream changes.
* The adapter must handle link reference definitions defined in one segment and used in another (two-pass parse with shared definitions). Until that is done, authors should keep reference definitions inside the segment that uses them; the spec says so.
* If cmark proves unsuitable, `shiguri-01/markdown` can replace it behind the same adapter; the AST does not change ([ADR-0001](/docs/knowledge/adr/0001-pipeline-and-normalized-ast.md)).
