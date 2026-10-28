# fmfm format specification — draft v0.1

> Status: **draft**. This document is the normative description of the format. Rationale lives in the ADRs under `docs/knowledge/adr/`. 日本語版: [format.ja.md](format.ja.md).

fmfm is a Markdown-based file format for hiking (and similar outdoor activity) logs. A file is ordinary CommonMark that any Markdown renderer can display, plus two small, optional layers of structure:

1. a **YAML front matter** block with document-level metadata, and
2. **directives** (`:::name{…}` … `:::`) that mark points in the narrative — waypoints, hazards, trail-condition reports — with machine-readable attributes.

The canonical copy of a log stays wherever the author publishes it (a blog, a static site, a git repository). Tools read it; they do not own it.

## 1. Document

A document is a UTF-8 text file, conventionally `*.md`. It consists of an optional front matter block followed by the body.

```markdown
---
format: fmfm
format_version: "0.1"
title: Kumotori-yama traverse from Mitsumine
started_at: 2026-07-10T06:20:00+09:00
ended_at: 2026-07-10T17:40:00+09:00
track:
  url: ./track.gpx
stats:
  distance_m: 21300
  ascent_m: 1780
tags: [okutama, kumotori]
---

# Kumotori-yama traverse

Left the Mitsumine shrine at 06:20 …

:::hazard{severity="warning" latitude="35.87" longitude="138.94"}
A fallen tree blocks the trail just below Shiraiwa hut. Pass on the right.
:::
```

Line endings may be LF or CRLF. A UTF-8 byte-order mark is ignored.

## 2. Front matter

The front matter is present when the **first line** of the file is exactly `---`. It ends at the next line that is exactly `---` or `...`. The lines in between are YAML (subset below). A file that does not start with `---` has no front matter.

### 2.1 Admitted YAML subset

* One document.
* Block mappings (`key: value`) and block sequences (`- item`), nested by indentation.
* Plain, single-quoted and double-quoted scalars; literal (`|`) and folded (`>`) block scalars.
* Comments (`# …`).

Not admitted (syntax error): anchors and aliases, tags (`!!str`), flow collections (`{…}`, `[…]`) **except** a flat sequence of scalars such as `tags: [a, b]`, multiple documents, non-scalar keys, duplicate keys.

All scalars are strings at the syntax level. Their interpretation (integer, decimal, date-time, …) is defined per field below.

### 2.2 Fields

| Key | Type | Required | Meaning |
| --- | --- | --- | --- |
| `format` | string, must be `fmfm` | recommended | Identifies the file as an fmfm document. Missing → warning `missing-format`; any other value → error `invalid-format`. |
| `format_version` | string `MAJOR.MINOR` | recommended | Version of this specification the document targets. Missing → warning; a major version this tool does not know → error. Quote it (`"0.1"`) to stop YAML readers turning it into a number. |
| `type` | string | optional | Activity kind. v0.1 defines only `hike` (the default). |
| `title` | string | **required** | Title of the log. |
| `started_at` | date-time | optional | When the activity started. |
| `ended_at` | date-time | optional | When it ended. Must not be earlier than `started_at`. |
| `summary` | string | optional | One-paragraph summary for listings and feeds. |
| `track.url` | string (URL or relative path) | optional | The GPX file with the recorded track. The file is referenced, never embedded. |
| `track.format` | string | optional | Defaults to `gpx`. Reserved for other track formats. |
| `stats.distance_m` | number ≥ 0 | optional | Total distance in metres. |
| `stats.ascent_m` | number ≥ 0 | optional | Total ascent in metres. |
| `stats.descent_m` | number ≥ 0 | optional | Total descent in metres. |
| `tags` | sequence of strings | optional | Free-form tags (areas, peaks, …). |
| `members` | sequence of strings | optional | Participants, as the author wishes to name them. |
| `license` | string | optional | License of the log, preferably an SPDX identifier (`CC-BY-4.0`). |

Unknown keys are preserved (exported under `extra`) and reported as warning `unknown-field`.

Information that applies to the whole document goes in the front matter. Information tied to a place or moment in the narrative goes in a directive. The same fact is never expected in both.

## 3. Body

The body is CommonMark. GitHub-flavoured extensions supported by the rendering library (tables, task lists, footnotes, strikethrough) may be used but carry no fmfm meaning.

Link reference definitions should be placed in the same Markdown segment (the prose between two directives, or a directive body) where they are used; a conforming tool may resolve them across segments but is not required to in v0.1.

## 4. Directives

### 4.1 Syntax

```text
:::NAME{ATTRIBUTES}
BODY
:::
```

* The opening fence is `:::` at **column 0**, immediately followed by `NAME` (`[a-z][a-z0-9-]*`), then optional whitespace and an optional attribute block `{…}`. Nothing else may follow on the line.
* `ATTRIBUTES` is a whitespace-separated list of `key="value"`, `key='value'` or `key=value` (bare values end at whitespace, `}` or a quote and may not contain quotes). Keys match `[a-z][a-z0-9_-]*`. Inside quoted values `\"`, `\'` and `\\` are the only escapes. `#foo` is shorthand for `id=foo`; `.foo` appends `foo` to the `class` attribute. A key given twice is a syntax error (`duplicate-attribute`).
* `BODY` is CommonMark and ends at the first following line that is exactly `:::` (trailing whitespace allowed). The closing fence is **mandatory** (`unclosed-directive` otherwise; the tool recovers by taking the rest of the file as the body).
* Directives **do not nest** in v0.1. An opening fence inside a body is reported (`nested-directive`) and treated as text.
* A `:::` line inside a top-level fenced code block is not a fence.
* Directives are recognised only at the top level of the document; indented `:::` or `:::` inside a block quote or list item is ordinary text.

Attribute values are strings at the syntax level; each directive type below says how its attributes are interpreted.

### 4.2 Common attributes

| Attribute | Type | Meaning |
| --- | --- | --- |
| `id` | string | Stable identifier; becomes the HTML `id`. |
| `class` | string | Extra CSS classes, space-separated. |
| `latitude`, `longitude` | decimal degrees (WGS 84); `latitude` in [−90, 90], `longitude` in [−180, 180] | Location. Both or neither must be given (`missing-coordinate`). |
| `elevation_m` | number | Elevation in metres. |
| `observed_at` | date-time | When the observation was made. |

Unknown attributes are preserved (JSON `extra`, HTML `data-*`) and reported as warning `unknown-attribute`.

### 4.3 `waypoint`

A named place on the route.

| Attribute | Required | Notes |
| --- | --- | --- |
| `name` | **yes** | Display name (hut, pass, summit, trailhead, …). |
| `latitude` / `longitude` | no | See common attributes. |
| `elevation_m` | no | |
| `arrived_at` | no | date-time |
| `departed_at` | no | date-time, not earlier than `arrived_at`. |

The body is free prose about the place.

### 4.4 `hazard`

Something that endangers or impedes hikers at a place.

| Attribute | Required | Notes |
| --- | --- | --- |
| `severity` | **yes** | `info`, `caution`, `warning` or `danger` (below). |
| `latitude` / `longitude` | no | |
| `observed_at` | no | |

Severity levels:

* `info` — worth knowing; no risk in normal conditions (signage missing, water source dry).
* `caution` — needs attention; ordinary hiking skills suffice (slippery roots, short exposed section).
* `warning` — real risk; consider a detour or extra care and equipment (fallen tree over an exposed slope, washed-out bridge with a wade).
* `danger` — life-threatening; do not proceed without specific preparation (active rockfall, avalanche terrain, missing fixed ropes on a vertical section).

### 4.5 `trail-condition`

The state of a stretch of trail at the time of the hike.

| Attribute | Required | Notes |
| --- | --- | --- |
| `status` | **yes** | `good`, `caution` or `impassable`. |
| `section` | no | Free-text name of the stretch (`Shiraiwa hut – Kumotori summit`). |
| `latitude` / `longitude` | no | A representative point. |
| `observed_at` | no | |

* `good` — passable as expected.
* `caution` — passable with extra care (snow patches, mud, overgrowth, minor erosion).
* `impassable` — could not be passed at the time (collapse, deep snow, flooding). Administrative closures are described in the prose for v0.1.

### 4.6 Unknown directives

A directive whose name is not defined here is preserved: its name, attributes and body survive into the AST, JSON and HTML, and a warning `unknown-directive` is reported. This lets authors experiment and lets newer documents degrade in older tools.

## 5. Data types

| Type | Lexical form |
| --- | --- |
| string | any text |
| number | optional `-`, digits, optional `.` digits (`21300`, `1780.5`); no exponent, no thousands separators |
| date-time | RFC 3339 subset: `YYYY-MM-DDTHH:MM:SS[.fraction](Z\|±HH:MM)`. The time-zone offset is **mandatory**; `T` may be lower-case; a space instead of `T` is accepted. Date-only values are rejected. |
| decimal degrees | number within the range given for the attribute |

## 6. Versioning

`format_version` is `MAJOR.MINOR`. Within a major version new optional fields, attributes and directive types may be added; existing meanings do not change, and unknown items are preserved as described above. A tool that supports major version N must accept every N.x document and should warn (not fail) on a minor version newer than it knows. This document is `0.1`; pre-1.0 minor versions may still change incompatibly, which the CHANGELOG records.

## 7. Diagnostics

A conforming validator reports problems as `FILE:LINE:COLUMN: LEVEL[CODE]: MESSAGE`. Line and column are 1-based. Levels are `error` (the document does not conform) and `warning` (it conforms, but something looks unintended).

| Code | Level | Stage | Meaning |
| --- | --- | --- | --- |
| `unclosed-front-matter` | error | syntax | `---` opened a front matter block that never closes. |
| `invalid-yaml` | error | syntax | The front matter is not valid YAML or uses a non-admitted feature. |
| `duplicate-key` | error | syntax | A front-matter key appears twice in one mapping. |
| `invalid-directive-header` | error | syntax | The opening fence has text after the name or a malformed attribute block. |
| `invalid-attribute` | error | syntax | An attribute is not `key=value`, has a bad key, or an unterminated quote. |
| `duplicate-attribute` | error | syntax | The same attribute key appears twice. |
| `unclosed-directive` | error | syntax | No closing `:::` before end of file. |
| `nested-directive` | error | syntax | An opening fence inside a directive body. |
| `missing-title` | error | semantic | `title` is absent or empty. |
| `missing-format` | warning | semantic | `format` / `format_version` absent. |
| `invalid-format` | error | semantic | `format` is not `fmfm`, or `format_version` is malformed or has an unsupported major version. |
| `newer-format-version` | warning | semantic | `format_version` has a minor version newer than the tool knows; unknown items are preserved. |
| `unknown-field` | warning | semantic | Front-matter key not defined by this spec (preserved). |
| `invalid-value` | error | semantic | A field or attribute does not have the lexical form of its type (bad number, bad date-time). |
| `invalid-severity` | error | semantic | `severity` not one of the four levels. |
| `invalid-status` | error | semantic | `status` not one of the three values. |
| `out-of-range` | error | semantic | Latitude/longitude outside their ranges, or a negative distance/ascent/descent. |
| `missing-attribute` | error | semantic | A required attribute is absent. |
| `missing-coordinate` | error | semantic | Only one of `latitude` / `longitude` given. |
| `unknown-attribute` | warning | semantic | Attribute not defined for this directive (preserved). |
| `unknown-directive` | warning | semantic | Directive name not defined by this spec (preserved). |
| `time-order` | error | semantic | `ended_at` before `started_at`, or `departed_at` before `arrived_at`. |

## 8. Exports

### 8.1 JSON

The `export --format json` shape is a public contract:

```json
{
  "format": "fmfm",
  "format_version": "0.1",
  "metadata": {
    "type": "hike",
    "title": "Kumotori-yama traverse from Mitsumine",
    "started_at": "2026-07-10T06:20:00+09:00",
    "ended_at": "2026-07-10T17:40:00+09:00",
    "track": { "url": "./track.gpx", "format": "gpx" },
    "stats": { "distance_m": 21300, "ascent_m": 1780 },
    "tags": ["okutama", "kumotori"]
  },
  "blocks": [
    { "type": "markdown", "source": "# Kumotori-yama traverse\n\nLeft the …\n" },
    {
      "type": "hazard",
      "severity": "warning",
      "location": { "latitude": 35.87, "longitude": 138.94 },
      "body": [ { "type": "markdown", "source": "A fallen tree …\n" } ]
    }
  ]
}
```

Optional fields that are absent in the document are omitted. Unknown front-matter keys appear under `metadata.extra`; unknown attributes under the block's `extra`; unknown directives are `{ "type": "directive", "name": "...", "attributes": {...}, "body": [...] }`.

### 8.2 HTML

The HTML export is semantic and readable without CSS or JavaScript. Directives become `<section>` elements whose class is `fmfm-NAME` and whose machine-readable attributes are `data-*`:

```html
<section class="fmfm-hazard" data-severity="warning" data-latitude="35.87" data-longitude="138.94">
  <p>A fallen tree blocks the trail just below Shiraiwa hut. Pass on the right.</p>
</section>
```

The document is wrapped in `<article class="fmfm-document" data-format="fmfm" data-format-version="0.1">` with an optional `<header>` carrying the title and metadata. Class names and `data-*` names are part of the contract; the default stylesheet is not.

## 9. Conformance

A document conforms to fmfm 0.1 when a validator reports no `error` diagnostics. A processor conforms when it accepts every conforming document, preserves unknown directives and attributes, and produces the JSON shape of §8.1.
