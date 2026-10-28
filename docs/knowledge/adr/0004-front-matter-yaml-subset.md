---
type: ADR
title: Front matter is a YAML subset read through moonbit-community/yaml's event API
description: Which YAML features the format admits, and why the tree is built by fmfm instead of using the library's loader
tags: [dependencies, yaml, format, accepted]
timestamp: 2026-10-28T00:00:00Z
---

# ADR-0004: Front matter is a YAML subset read through `moonbit-community/yaml`'s event API

## Status

Accepted — 2026-10-28 (pending a compile spike; see the research note)

## Context

Document-level metadata (title, times, track file, totals, tags) lives in YAML front matter because that is what every static-site generator already understands. Full YAML 1.2 is far larger than the format needs, and semantic diagnostics must be able to point at the offending key's line.

## Decision

* The front matter block is the text between a first line `---` and the next line `---` (or `...`), at the very start of the file. Anything else at the top of the file means "no front matter".
* Admitted YAML subset (v0.1): one document; block mappings; block sequences (`- item`); plain, single-quoted and double-quoted scalars; literal/folded block scalars for `summary`-like fields; comments. **Not admitted**: anchors and aliases, tags, flow collections `{}`/`[]`, multiple documents, complex (non-scalar) keys. Using a non-admitted feature is a syntax error.
* Scalars are **strings** at the syntax level; numbers, booleans and dates are interpreted by the semantic stage according to the field's declared type. This mirrors the directive attribute rule and avoids YAML's implicit typing surprises (`1:30`, `no`, `012`).
* The YAML lexer/parser is `moonbit-community/yaml`, used through its `Parser` + `MarkedEventReceiver` interface so that each key and value receives a source position. fmfm builds its own small `Node` tree (mapping / sequence / scalar, each with a `Range`) from the events and rejects the features above while doing so. Duplicate keys are a syntax error.
* The library is imported only by the `frontmatter` package.

Rejected:

* `Yaml::load_from_string`: convenient but loses positions and does not report duplicate keys.
* Writing an in-house YAML-subset parser: tempting (small subset, exact positions) but YAML scalar and indentation rules are notoriously subtle; reusing a port of yaml-rust2 is safer.
* `moonbitstack/moonyaml` `strict` dialect: a near-perfect match of the subset, but the package is days old; re-evaluate later.

## Consequences

* Semantic errors in metadata (`ended_at` before `started_at`, negative distance) point at the key's line and column.
* The admitted subset is documented in `docs/spec/format.md`; authors using the usual front-matter style never hit the restrictions.
