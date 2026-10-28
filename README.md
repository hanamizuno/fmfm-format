# fmfm — an open Markdown format for hiking logs

> 日本語版: [README.ja.md](README.ja.md)

**fmfm** is a file format and a toolchain for hiking (and similar outdoor) logs that live on your own site. A log is an ordinary Markdown file — readable in any renderer — with two small, optional layers of structure: YAML front matter for the whole hike, and `:::` directives for the places in the story that matter to other hikers: waypoints, hazards, trail conditions.

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

The canonical copy stays with the author. Tools validate it, turn it into JSON for indexers and map services, and render it to semantic HTML. There is no central service and no lock-in: GPX tracks are referenced, not embedded, and anything a tool does not understand is preserved.

Status: **pre-release (v0.1 in progress)**. The format is a draft and may still change incompatibly before 1.0.

## Why

Hiking records in Japan tend to end up in a few centralised apps. This project takes the opposite stance: write the log once, in Markdown, on your blog or in a git repository, and let any number of services read it. The design goals, in order:

1. The file must read as normal Markdown without any tooling.
2. Only the parts worth structuring are structured, and with the smallest possible syntax.
3. Existing open formats do the heavy lifting: CommonMark, YAML, GPX (later GeoJSON, Atom/GeoRSS, OSM and Wikidata identifiers).
4. Every consumer works from one typed model, not from HTML.

## Specification

* [docs/spec/format.md](docs/spec/format.md) — the normative draft (front matter fields, directive grammar, `waypoint` / `hazard` / `trail-condition`, data types, diagnostics, JSON and HTML export contracts).
* [docs/spec/format.ja.md](docs/spec/format.ja.md) — 日本語訳.
* Design rationale: [docs/knowledge/adr/](docs/knowledge/adr/index.md); undecided points: [docs/knowledge/architecture/open-questions.md](docs/knowledge/architecture/open-questions.md).

## Toolchain

The reference implementation is written in [MoonBit](https://www.moonbitlang.com/) (module `hanamizuno/fmfm`). It is a library first and a CLI second, and it never converts Markdown straight to HTML:

```text
source → syntax (front matter + directives) → semantic (typed Document + diagnostics)
       → exporters: JSON · HTML · (GeoJSON, feeds … later)
```

Packages: `diagnostic`, `syntax`, `frontmatter`, `ast`, `semantic`, `json`, `html`, and the root facade. See [docs/knowledge/architecture/pipeline-and-packages.md](docs/knowledge/architecture/pipeline-and-packages.md).

### Planned CLI

```bash
fmfm validate hike.md            # diagnostics as file:line:col: level[code]: message; exit 1 on errors
fmfm render hike.md -o hike.html # semantic HTML with the default stylesheet
fmfm export hike.md --format json
fmfm dump hike.md                # full AST with positions and diagnostics (debugging)
```

### Current state

| Area | State |
| --- | --- |
| Directive scanner, attribute grammar, front matter split | done, snapshot-tested |
| Typed AST, RFC 3339 date-times, number lexing | done |
| Semantic validation (all diagnostic codes in the spec) | done |
| JSON export / dump | done |
| HTML renderer (semantic sections, `data-*`, escaping) | done; takes any Markdown→HTML function |
| CommonMark rendering via `moonbit-community/cmark` | adapter pending (dependency not yet fetched) |
| YAML front matter via `moonbit-community/yaml` | reader pending (dependency not yet fetched) |
| CLI, default CSS, `examples/` golden tests | pending |
| GPX validation, GeoJSON, feeds | after v0.1 |

## Development

Install the [MoonBit toolchain](https://www.moonbitlang.com/download) and [just](https://github.com/casey/just), then:

```bash
moon update     # registry index, once
just            # check + test (js target)
just ci-all     # formatting, generated interfaces, js + native tests — same as CI
```

Other recipes: `just fmt`, `just test-update` (refresh snapshots), `just info` (regenerate `pkg.generated.mbti`), `just target=native test`. Contributor guidelines for humans and AI agents are in [AGENTS.md](AGENTS.md).

Docker and Docker Sandboxes (`sbx`) set-ups are inherited from the project template; see [`.sandbox/README.md`](.sandbox/README.md) and the [runbook](docs/knowledge/runbooks/agent-sandbox-sbx.md).

## Contributing

Issues and pull requests are welcome, in English or Japanese. The format itself is the main thing under discussion right now: if you keep hiking logs and something in the spec does not fit how you write them, say so in an issue.

## License

MIT — see [LICENSE](LICENSE). The specification text is under the same license; logs you write with it are, of course, yours.
