///|
fn document() -> (@ast.Document, Array[@diagnostic.Diagnostic]) {
  let parsed = @syntax.parse(
    (
      #|---
      #|title: Test hike
      #|---
      #|# Test hike
      #|
      #|:::hazard{severity="warning" latitude="35.0" longitude="139.0" note="x"}
      #|倒木あり。
      #|:::
      #|
      #|:::camp{nights=1}
      #|Tent site.
      #|:::
    ),
  )
  let fm = @frontmatter.Node::from_json(
    {
      "format": "fmfm",
      "format_version": "0.1",
      "title": "Test hike",
      "started_at": "2026-07-10T06:20:00+09:00",
      "stats": { "distance_m": "21300", "ascent_m": "1780.5" },
      "tags": ["a", "b"],
      "custom": { "k": "v" },
    },
    parsed.document.front_matter.unwrap().range,
  )
  let lowered = @semantic.lower(parsed.document, front_matter=fm)
  (lowered.document, parsed.diagnostics + lowered.diagnostics)
}

///|
test "export shape" {
  let (doc, _) = document()
  inspect(
    @json.to_json(doc).stringify(indent=2),
    content=(
      #|{
      #|  "format": "fmfm",
      #|  "format_version": "0.1",
      #|  "metadata": {
      #|    "type": "hike",
      #|    "title": "Test hike",
      #|    "started_at": "2026-07-10T06:20:00+09:00",
      #|    "stats": {
      #|      "distance_m": 21300,
      #|      "ascent_m": 1780.5
      #|    },
      #|    "tags": [
      #|      "a",
      #|      "b"
      #|    ],
      #|    "extra": {
      #|      "custom": {
      #|        "k": "v"
      #|      }
      #|    }
      #|  },
      #|  "blocks": [
      #|    {
      #|      "type": "markdown",
      #|      "source": "# Test hike\n\n"
      #|    },
      #|    {
      #|      "type": "hazard",
      #|      "severity": "warning",
      #|      "location": {
      #|        "latitude": 35,
      #|        "longitude": 139
      #|      },
      #|      "extra": {
      #|        "note": "x"
      #|      },
      #|      "body": [
      #|        {
      #|          "type": "markdown",
      #|          "source": "倒木あり。\n"
      #|        }
      #|      ]
      #|    },
      #|    {
      #|      "type": "directive",
      #|      "name": "camp",
      #|      "attributes": {
      #|        "nights": "1"
      #|      },
      #|      "body": [
      #|        {
      #|          "type": "markdown",
      #|          "source": "Tent site.\n"
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
}

///|
test "dump includes ranges and diagnostics" {
  let (doc, diagnostics) = document()
  let dump = @json.dump(doc, diagnostics)
  guard dump is Object(top) else { fail("expected an object") }
  debug_inspect(
    top.keys().to_array(),
    content=(
      #|[
      #|  "format",
      #|  "format_version",
      #|  "declared_format_version",
      #|  "metadata",
      #|  "blocks",
      #|  "diagnostics",
      #|]
    ),
  )
  guard top.get("diagnostics") is Some(Array(ds)) else {
    fail("no diagnostics")
  }
  inspect(
    ds.length(),
    content=(
      #|3
    ),
  )
  guard top.get("blocks") is Some(Array([Object(first), ..])) else {
    fail("no blocks")
  }
  inspect(
    first.get("range").unwrap().stringify(),
    content=(
      #|{"start":{"line":4,"column":1,"offset":25},"end":{"line":5,"column":1,"offset":37}}
    ),
  )
}
