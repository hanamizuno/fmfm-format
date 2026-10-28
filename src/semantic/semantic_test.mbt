///|
fn analyze(source : String, front_matter : Json?) -> @semantic.LowerResult {
  let parsed = @syntax.parse(source)
  let fm = match (front_matter, parsed.document.front_matter) {
    (Some(json), Some(raw)) =>
      Some(@frontmatter.Node::from_json(json, raw.range))
    (Some(json), None) =>
      Some(
        @frontmatter.Node::from_json(
          json,
          @diagnostic.Range::point({ line: 1, column: 1, offset: 0, }),
        ),
      )
    (None, _) => None
  }
  let lowered = @semantic.lower(parsed.document, front_matter?=fm)
  {
    document: lowered.document,
    diagnostics: parsed.diagnostics + lowered.diagnostics,
  }
}

///|
fn messages(r : @semantic.LowerResult) -> Array[String] {
  @diagnostic.sort(r.diagnostics).map(d => d.format())
}

///|
test "vertical slice: valid document" {
  let r = analyze(
    (
      #|---
      #|format: fmfm
      #|format_version: "0.1"
      #|title: Test hike
      #|started_at: 2026-07-10T06:20:00+09:00
      #|ended_at: 2026-07-10T17:40:00+09:00
      #|track:
      #|  url: ./track.gpx
      #|stats:
      #|  distance_m: 21300
      #|  ascent_m: 1780.5
      #|tags: [奥多摩, 雲取山]
      #|---
      #|
      #|# Test hike
      #|
      #|:::hazard{severity="warning" latitude="35.0" longitude="139.0" observed_at="2026-07-10T09:12:00+09:00"}
      #|倒木あり。
      #|:::
      #|
      #|:::waypoint{name="Kumotori hut" elevation_m=1830 #hut}
      #|Water available.
      #|:::
      #|
      #|:::trail-condition{status="caution" section="hut – summit"}
      #|Snow patches.
      #|:::
    ),
    Some({
      "format": "fmfm",
      "format_version": "0.1",
      "title": "Test hike",
      "started_at": "2026-07-10T06:20:00+09:00",
      "ended_at": "2026-07-10T17:40:00+09:00",
      "track": { "url": "./track.gpx" },
      "stats": { "distance_m": "21300", "ascent_m": "1780.5" },
      "tags": ["奥多摩", "雲取山"],
    }),
  )
  debug_inspect(
    messages(r),
    content=(
      #|[]
    ),
  )
  debug_inspect(
    r.document.metadata,
    content=(
      #|{
      #|  format_version: Some("0.1"),
      #|  kind: "hike",
      #|  title: "Test hike",
      #|  started_at: Some(
      #|    {
      #|      year: 2026,
      #|      month: 7,
      #|      day: 10,
      #|      hour: 6,
      #|      minute: 20,
      #|      second: 0,
      #|      nanosecond: 0,
      #|      offset_minutes: 540,
      #|      text: "2026-07-10T06:20:00+09:00",
      #|    },
      #|  ),
      #|  ended_at: Some(
      #|    {
      #|      year: 2026,
      #|      month: 7,
      #|      day: 10,
      #|      hour: 17,
      #|      minute: 40,
      #|      second: 0,
      #|      nanosecond: 0,
      #|      offset_minutes: 540,
      #|      text: "2026-07-10T17:40:00+09:00",
      #|    },
      #|  ),
      #|  summary: None,
      #|  track: Some({ url: "./track.gpx", format: "gpx" }),
      #|  stats: Some({ distance_m: Some(21300), ascent_m: Some(1780.5), descent_m: None }),
      #|  tags: ["奥多摩", "雲取山"],
      #|  members: [],
      #|  license: None,
      #|  extra: {},
      #|}
    ),
  )
  debug_inspect(
    r.document.blocks.map(b => {
      match b {
        Markdown(_) => "markdown"
        Waypoint(w) =>
          "waypoint \{w.name} id=\{w.common.id.unwrap_or("-")} elev=\{w.elevation_m.unwrap_or(-1)}"
        Hazard(h) =>
          "hazard \{h.severity} " +
          (match h.location {
            Some(p) => "\{p.latitude},\{p.longitude}"
            None => "-"
          }) +
          " " +
          h.observed_at.map(t => t.to_string()).unwrap_or("-")
        TrailCondition(t) =>
          "trail-condition \{t.status} \{t.section.unwrap_or("-")}"
        Unknown(u) => "unknown \{u.name}"
      }
    }),
    content=(
      #|[
      #|  "markdown",
      #|  "hazard warning 35,139 2026-07-10T09:12:00+09:00",
      #|  "waypoint Kumotori hut id=hut elev=1830",
      #|  "trail-condition caution hut – summit",
      #|]
    ),
  )
}

///|
test "missing front matter" {
  let r = analyze("# Just prose\n", None)
  debug_inspect(
    messages(r),
    content=(
      #|[
      #|  "<input>:1:1: error[missing-title]: title is required (add a front matter block with a title)",
      #|  "<input>:1:1: warning[missing-format]: add format: fmfm and format_version: \"0.1\" to the front matter",
      #|]
    ),
  )
  inspect(r.document.metadata.title, content="")
}

///|
test "metadata errors and warnings" {
  let r = analyze(
    (
      #|---
      #|x
      #|---
      #|body
    ),
    Some({
      "format": "hike-md",
      "format_version": "2.0",
      "title": "  ",
      "started_at": "2026-07-10T17:40:00+09:00",
      "ended_at": "2026-07-10T06:20:00+09:00",
      "track": "./track.gpx",
      "stats": { "distance_m": "-5", "ascent_m": "lots", "pace": "1" },
      "tags": "solo",
      "weather": { "sky": "clear" },
    }),
  )
  debug_inspect(
    messages(r),
    content=(
      #|[
      #|  "<input>:2:1: error[invalid-format]: format must be \"fmfm\", found \"hike-md\"",
      #|  "<input>:2:1: error[invalid-format]: format_version 2.0 is not supported by this implementation (supports 0.x)",
      #|  "<input>:2:1: error[missing-title]: title must not be empty",
      #|  "<input>:2:1: error[invalid-value]: track must be a mapping with a url (track.url: ./track.gpx)",
      #|  "<input>:2:1: error[out-of-range]: stats.distance_m must not be negative",
      #|  "<input>:2:1: error[invalid-value]: stats.ascent_m must be a number in metres",
      #|  "<input>:2:1: error[invalid-value]: tags must be a list",
      #|  "<input>:2:1: error[time-order]: ended_at (2026-07-10T06:20:00+09:00) is earlier than started_at (2026-07-10T17:40:00+09:00)",
      #|  "<input>:2:1: warning[unknown-field]: unknown stats field \"pace\"",
      #|  "<input>:2:1: warning[unknown-field]: unknown front matter field \"weather\" (kept under extra)",
      #|]
    ),
  )
  debug_inspect(
    r.document.metadata.extra,
    content=(
      #|{ "weather": Object({ "sky": String("clear") }) }
    ),
  )
}

///|
test "format version handling" {
  let out : Array[(String, Array[String])] = []
  for v in ["0.1", "0.2", "0.0", "1.0", "0", "a.b", "0.1.0"] {
    let r = analyze(
      "---\nx\n---\n",
      Some({ "format": "fmfm", "format_version": v, "title": "t" }),
    )
    out.push((v, messages(r)))
  }
  debug_inspect(
    out,
    content=(
      #|[
      #|  ("0.1", []),
      #|  (
      #|    "0.2",
      #|    ["<input>:2:1: warning[newer-format-version]: format_version 0.2 is newer than this implementation (0.1); unknown items are preserved"],
      #|  ),
      #|  ("0.0", []),
      #|  (
      #|    "1.0",
      #|    ["<input>:2:1: error[invalid-format]: format_version 1.0 is not supported by this implementation (supports 0.x)"],
      #|  ),
      #|  (
      #|    "0",
      #|    ["<input>:2:1: error[invalid-format]: format_version must look like \"0.1\", found \"0\" (suggestion: format_version: \"0.1\")"],
      #|  ),
      #|  (
      #|    "a.b",
      #|    ["<input>:2:1: error[invalid-format]: format_version must look like \"0.1\", found \"a.b\" (suggestion: format_version: \"0.1\")"],
      #|  ),
      #|  (
      #|    "0.1.0",
      #|    ["<input>:2:1: error[invalid-format]: format_version must look like \"0.1\", found \"0.1.0\" (suggestion: format_version: \"0.1\")"],
      #|  ),
      #|]
    ),
  )
}

///|
test "directive errors" {
  let r = analyze(
    (
      #|:::hazard{latitude="91" longitude="abc" colour="red"}
      #|:::
      #|:::hazard{severity="severe" latitude="35"}
      #|:::
      #|:::waypoint{arrived_at="2026-07-10T10:00:00+09:00" departed_at="2026-07-10T09:00:00+09:00" elevation_m="high"}
      #|:::
      #|:::trail-condition{status="closed" observed_at="2026-07-10"}
      #|:::
      #|:::water-source{kind="spring" latitude="35.1" longitude="139.1"}
      #|Cold and clear.
      #|:::
    ),
    Some({ "format": "fmfm", "format_version": "0.1", "title": "t" }),
  )
  debug_inspect(
    messages(r),
    content=(
      #|[
      #|  "<input>:1:1: error[missing-attribute]: \":::hazard\" requires the attribute \"severity\"",
      #|  "<input>:1:20: error[out-of-range]: latitude must be between -90 and 90, found 91",
      #|  "<input>:1:35: error[invalid-value]: longitude must be decimal degrees, found \"abc\"",
      #|  "<input>:1:41: warning[unknown-attribute]: unknown attribute \"colour\" on \":::hazard\" (kept as extra)",
      #|  "<input>:3:20: error[invalid-severity]: severity must be one of: info, caution, warning, danger, found \"severe\"",
      #|  "<input>:3:29: error[missing-coordinate]: \"latitude\" is given without \"longitude\" (both are required for a location)",
      #|  "<input>:5:1: error[missing-attribute]: \":::waypoint\" requires the attribute \"name\"",
      #|  "<input>:5:1: error[time-order]: departed_at (2026-07-10T09:00:00+09:00) is earlier than arrived_at (2026-07-10T10:00:00+09:00)",
      #|  "<input>:5:104: error[invalid-value]: elevation_m must be a number, found \"high\"",
      #|  "<input>:7:27: error[invalid-status]: status must be one of: good, caution, impassable, found \"closed\"",
      #|  "<input>:7:48: error[invalid-value]: observed_at must be an RFC 3339 date-time with a UTC offset: a time and a UTC offset are required (suggestion: e.g. 2026-07-10T06:20:00+09:00)",
      #|  "<input>:9:4: warning[unknown-directive]: unknown directive \":::water-source\" (kept as-is)",
      #|]
    ),
  )
  match r.document.blocks[4] {
    Unknown(u) =>
      debug_inspect(
        (u.name, u.attributes),
        content=(
          #|(
          #|  "water-source",
          #|  { "kind": "spring", "latitude": "35.1", "longitude": "139.1" },
          #|)
        ),
      )
    _ => fail("expected an unknown directive")
  }
  match r.document.blocks[0] {
    Hazard(h) =>
      debug_inspect(
        h.common.extra,
        content=(
          #|{ "colour": "red" }
        ),
      )
    _ => fail("expected a hazard")
  }
}
