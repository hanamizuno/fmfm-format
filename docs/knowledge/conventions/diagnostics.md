---
type: Convention
title: Diagnostics
description: Codes, wording and positions for every error or warning fmfm reports
tags: [diagnostics, cli]
timestamp: 2026-10-28T00:00:00Z
---

# Diagnostics

## Rule

Every problem fmfm reports is a `diagnostic.Diagnostic` with a **level** (`error` or `warning`), a stable kebab-case **code**, a one-sentence **message**, a **range** in the source file, and an optional **suggestion**. The CLI prints it as

```text
hike.md:42:18: error[invalid-severity]: severity must be one of: info, caution, warning, danger
```

`error` means the document does not conform to the spec and the CLI exits 1. `warning` means the document conforms but something is probably unintended (unknown attribute, missing recommended field); the CLI exits 0 unless `--strict` is given.

## Why

CI pipelines need stable exit codes and codes they can allow-list; editors need positions; humans need a message they can act on without reading the spec. Keeping all three in one struct from the start avoids a later retrofit.

## How to apply

* Codes are documented in `docs/spec/format.md` ("Diagnostics" section) and never renamed once released; retire with a note instead.
* Syntax codes come from `syntax` / `frontmatter`; semantic codes from `semantic`. A code belongs to exactly one stage.
* Messages: lower-case start, no trailing period, name the offending field or attribute, list the allowed values when the set is small.
* Range: the smallest span that identifies the problem (the attribute value, not the whole directive; the key, not the whole front matter). When no better span exists use the opening line of the block.
* Positions: 1-based line and column; column counts Unicode code points; `offset` is 0-based in UTF-16 code units.
* Suggestions are optional and must be a concrete replacement or action (`use "warning"`), not advice.

## Exceptions

* Fatal conditions outside the document (file not found, unreadable UTF-8) are CLI errors with exit code 2 and are not diagnostics.
