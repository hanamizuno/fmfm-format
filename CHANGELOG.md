# Changelog

All notable changes to this project are documented in this file. The format
version of the specification is tracked separately in `docs/spec/format.md`.

## [Unreleased]

### Added

- Project bootstrap on top of the MoonBit template: module renamed to `hanamizuno/fmfm`, README in English and Japanese, MIT license.
- Draft specification v0.1 (`docs/spec/format.md`, Japanese translation in `format.ja.md`): YAML front matter fields, `:::name{…}` directive grammar, `waypoint` / `hazard` / `trail-condition`, data types, diagnostic codes, JSON and HTML export contracts.
- Knowledge bundle: library survey (CommonMark and YAML on mooncakes), ADR-0001…0004, pipeline/package architecture note, open-questions table, diagnostics convention.
- MoonBit packages `diagnostic`, `syntax` (front matter split, directive scanner, attribute grammar), `frontmatter` (position-aware node tree), `ast` (typed model, RFC 3339 date-times, number lexer), `semantic` (lowering and validation), `json` (export and dump), `html` (semantic renderer, page wrapper) and the root facade `analyze`, all with snapshot tests on the js and native targets.
- `examples/kumotori-traverse.md`, a complete sample log.

### Pending

- Markdown adapter (`moonbit-community/cmark`) and YAML reader (`moonbit-community/yaml`), the `fmfm` CLI, default CSS, and golden tests over `examples/`.
