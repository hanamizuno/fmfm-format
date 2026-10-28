---
type: ADR
title: Directive syntax — fenced containers with inline attributes
description: The :::name{key="value"} … ::: form, its attribute grammar, and the no-nesting rule for v0.1
tags: [format, syntax, accepted]
timestamp: 2026-10-28T00:00:00Z
---

# ADR-0003: Directive syntax — fenced containers with inline attributes

## Status

Accepted — 2026-10-28

## Context

Structured information tied to a point in the narrative (a hazard, a waypoint, a trail-condition report) needs a block syntax that (a) degrades gracefully in a plain CommonMark renderer, (b) is familiar to authors of other Markdown dialects, and (c) can be scanned without a full Markdown parser. The candidates were the remark-directive / markdown-it-container style `:::name{attrs}`, Pandoc fenced divs `::: {.class key=value}`, MyST `{directive}` code fences, and MDX components. MDX was ruled out by the brief (unreadable fallback).

## Decision

```markdown
:::hazard{severity="warning" latitude="35.87" longitude="138.94"}
A fallen tree blocks the trail. Pass on the right.
:::
```

* **Opening line**: `:::` at column 0, immediately followed by the directive name (`[a-z][a-z0-9-]*`), optionally followed by whitespace and an attribute block `{ … }`. Nothing else may follow on the line.
* **Attributes**: whitespace-separated. Each is `key="value"`, `key='value'`, or `key=bare-value` (bare values stop at whitespace, `}` or quotes). Keys are `[a-z][a-z0-9_-]*`. `#foo` is shorthand for `id="foo"`; `.foo` appends to `class`. Values are strings at the syntax level; typing happens in the semantic stage. A repeated key is a syntax error.
* **Body**: CommonMark. Ends at the first line that is exactly `:::` (trailing whitespace allowed).
* **Closing fence** is mandatory. A missing fence is a syntax error (`unclosed-directive`); the parser recovers by treating the rest of the file as the body.
* **Nesting is not allowed in v0.1.** An opening `:::name` inside a body is reported (`nested-directive`) and treated as ordinary body text. The AST already models bodies as `Array[Block]` so nesting can be enabled later without changing the data model.
* Lines inside a top-level fenced code block (```` ``` ```` or `~~~`) are never directive fences.

Rejected:

* Attributes on separate lines (YAML-ish header inside the block): more readable for long attribute lists, but harder to scan, no ecosystem precedent, and unknown renderers would show the header as prose. Can be revisited if attributes grow (the scanner is the only thing that would change).
* Pandoc's `::: {.hazard severity=warning}` (name as a class): the name is not visually distinct and clashes with the `.class` shorthand.
* MyST ```` ```{hazard} ```` code fences: a plain renderer shows the body as a code block, which hides the prose.

## Consequences

* In a plain CommonMark renderer the opening and closing lines appear as short paragraphs (`:::hazard{…}` / `:::`) and the body remains readable prose. This is the accepted fallback.
* The scanner is ~200 lines of MoonBit with no dependencies and is unit-tested with snapshots.
* The spec (`docs/spec/format.md`) is the normative description; this ADR records the rationale.
