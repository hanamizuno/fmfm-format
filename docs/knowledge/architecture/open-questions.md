---
type: Architecture Note
title: Open design questions (v0.1)
description: Points the project brief deliberately left undecided, each with the options considered and the current recommendation
tags: [format, design, open]
timestamp: 2026-10-28T00:00:00Z
---

# Open design questions (v0.1)

The brief asked that larger specification choices not be fixed silently. Each item lists the options, the current recommendation (what the v0.1 code does), and what would make us revisit it. Resolved items move into an ADR.

| # | Question | Options | Current recommendation (v0.1) | Revisit when |
| --- | --- | --- | --- | --- |
| 1 | Directive syntax | `:::name{attrs}` inline; attributes on separate lines; Pandoc fenced div; MyST fence | `:::name{attrs}` — [ADR-0003](/docs/knowledge/adr/0003-directive-syntax.md) | A directive needs more than ~6 attributes |
| 2 | Directive nesting | allow; forbid; allow only `waypoint > hazard` | Forbid; report `nested-directive`, treat as text. AST bodies are `Array[Block]` so enabling later is additive | Real logs show the need |
| 3 | Attribute value typing | all strings, typed in semantic stage; typed at parse time | Strings at syntax level, typed by the semantic stage (same rule for YAML scalars) — keeps the scanner schema-free | — |
| 4 | DateTime | RFC 3339 with mandatory offset; allow offset-less local time; allow date-only | RFC 3339 subset, **offset mandatory** (`Z` or `±HH:MM`); fractional seconds allowed; date-only rejected. Hike logs cross time zones rarely but the ambiguity costs more than the typing | Users push back on typing `+09:00` → could add a document-level `timezone` default |
| 5 | Coordinate key names | `lat`/`lon`; `latitude`/`longitude` | `latitude` / `longitude` (public spec; readability over brevity). Both attributes required together. WGS 84 decimal degrees | — |
| 6 | Units in key names | `elevation_m`; `elevation` + unit attr | Unit suffix in the key: `elevation_m`, `distance_m`, `ascent_m`, `descent_m`. Integers or decimals, metres only | — |
| 7 | Severity vocabulary | info / caution / warning / danger | Adopted, with definitions in the spec: *info* = worth knowing, no risk; *caution* = needs attention, normal skills suffice; *warning* = real risk, consider detour or extra care; *danger* = life-threatening, do not proceed without specific preparation | Feedback from authors |
| 8 | Trail-condition vocabulary | free text; `status` enum | `status` enum: `good`, `caution`, `impassable`, plus free prose. Administrative closure is prose for now | Need for `closed` (administrative) vs `impassable` (physical) |
| 9 | Unknown attributes | error; warning; preserve silently | **Preserve + warning** (`unknown-attribute`); kept in `extra` and exported in JSON; rendered as `data-*` | — |
| 10 | Unknown directives | error; warning + preserve; drop | **Preserve + warning** (`unknown-directive`); `Block::Unknown`, HTML renders a generic `<section class="fmfm-directive">` with the body | — |
| 11 | YAML scope | full 1.2; library subset; in-house subset | Subset enforced by fmfm over the library's event stream — [ADR-0004](/docs/knowledge/adr/0004-front-matter-yaml-subset.md) | — |
| 12 | Format identification | none; `format: fmfm` + `format_version`; single `fmfm: "0.1"` key | `format: fmfm` and `format_version: "0.1"` in front matter, both **recommended**; missing → warning, mismatch → error. `type: hike` reserved for the activity kind (default `hike`) | Second activity type arrives |
| 13 | Name of the format / CLI | — | Working name `fmfm`, CLI `fmfm`, module `hanamizuno/fmfm`. **Needs the owner's confirmation.** | Immediately |
| 14 | Header rendering in HTML | render metadata header; prose only | Render a `<header>` (title, dates, totals) by default; `header=false` option for sites that template their own | — |
| 15 | Source positions in JSON | always; never; opt-in | `export`: no positions (stable, compact); `dump`: everything including ranges and diagnostics | — |
| 16 | Position units | UTF-16 code units; code points; bytes | Line/column 1-based in code points for display; `offset` 0-based in UTF-16 code units (matches JS and LSP) | A non-JS editor integration needs bytes |
| 17 | Test fixtures | in-source literals; `tests/` directory with embeds | Both: unit snapshots in `*_test.mbt`, `examples/` + CLI golden check | — |
