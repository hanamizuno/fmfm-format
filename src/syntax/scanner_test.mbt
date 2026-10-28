///|
fn render_diagnostics(r : @syntax.ParseResult) -> Array[String] {
  r.diagnostics.map(d => d.format(file="t.md"))
}

///|
fn outline(blocks : Array[@syntax.RawBlock]) -> Array[String] {
  blocks.map(b => {
    match b {
      Markdown(m) => "markdown \{m.range.start.line}-\{m.range.end.line}"
      Directive(d) => {
        let attrs = d.attributes.map(a => "\{a.key}=\{a.value}").join(" ")
        "directive \{d.name} [\{attrs}] \{d.range.start.line}-\{d.range.end.line} body=[" +
        outline(d.body).join(", ") +
        "]"
      }
    }
  })
}

///|
test "front matter and one hazard" {
  let r = @syntax.parse(
    (
      #|---
      #|title: Test hike
      #|---
      #|
      #|# Test hike
      #|
      #|:::hazard{severity="warning" latitude="35.0" longitude="139.0"}
      #|倒木あり。
      #|:::
      #|
      #|After the tree.
    ),
  )
  debug_inspect(
    render_diagnostics(r),
    content=(
      #|[]
    ),
  )
  debug_inspect(
    r.document.front_matter,
    content=(
      #|Some(
      #|  {
      #|    source: "title: Test hike\n",
      #|    range: {
      #|      start: { line: 2, column: 1, offset: 4 },
      #|      end: { line: 2, column: 17, offset: 20 },
      #|    },
      #|  },
      #|)
    ),
  )
  debug_inspect(
    outline(r.document.blocks),
    content=(
      #|[
      #|  "markdown 4-6",
      #|  "directive hazard [severity=warning latitude=35.0 longitude=139.0] 7-9 body=[markdown 8-8]",
      #|  "markdown 10-11",
      #|]
    ),
  )
}

///|
test "no front matter, CRLF, BOM" {
  let r = @syntax.parse(
    "\u{FEFF}# Hi\r\n:::waypoint{name=Hut}\r\ntext\r\n:::\r\n",
  )
  debug_inspect(
    render_diagnostics(r),
    content=(
      #|[]
    ),
  )
  inspect(r.document.front_matter is None, content="true")
  debug_inspect(
    outline(r.document.blocks),
    content=(
      #|[
      #|  "markdown 1-1",
      #|  "directive waypoint [name=Hut] 2-4 body=[markdown 3-3]",
      #|]
    ),
  )
  match r.document.blocks[1] {
    Directive(d) =>
      debug_inspect(
        d.body,
        content=(
          #|[
          #|  Markdown(
          #|    {
          #|      source: "text\n",
          #|      range: {
          #|        start: { line: 3, column: 1, offset: 29 },
          #|        end: { line: 3, column: 5, offset: 33 },
          #|      },
          #|    },
          #|  ),
          #|]
        ),
      )
    _ => fail("expected a directive")
  }
}

///|
test "fenced code hides fences; indented and stray fences are prose" {
  let r = @syntax.parse(
    (
      #|```
      #|:::hazard{severity="info"}
      #|:::
      #|```
      #|  :::hazard{severity="info"}
      #|:::
      #|::: not a directive
      #|:::Hazard
      #|
      #|~~~md
      #|:::waypoint{name="x"}
      #|~~~
    ),
  )
  debug_inspect(
    render_diagnostics(r),
    content=(
      #|[]
    ),
  )
  debug_inspect(
    outline(r.document.blocks),
    content=(
      #|["markdown 1-12"]
    ),
  )
}

///|
test "code fence inside a directive body" {
  let r = @syntax.parse(
    (
      #|:::waypoint{name="Hut"}
      #|```text
      #|:::
      #|```
      #|still inside
      #|:::
      #|after
    ),
  )
  debug_inspect(
    render_diagnostics(r),
    content=(
      #|[]
    ),
  )
  debug_inspect(
    outline(r.document.blocks),
    content=(
      #|[
      #|  "directive waypoint [name=Hut] 1-6 body=[markdown 2-5]",
      #|  "markdown 7-7",
      #|]
    ),
  )
}

///|
test "attribute grammar" {
  let r = @syntax.parse(
    (
      #|:::waypoint{name="Shiraiwa \"hut\"" elevation_m=1920 #top .big .red arrived_at='2026-07-10T09:00:00+09:00'}
      #|:::
    ),
  )
  debug_inspect(
    render_diagnostics(r),
    content=(
      #|[]
    ),
  )
  match r.document.blocks[0] {
    Directive(d) =>
      debug_inspect(
        d.attributes.map(a => {
          (a.key, a.value, a.value_range.start.column, a.value_range.end.column)
        }),
        content=(
          #|[
          #|  ("name", "Shiraiwa \"hut\"", 18, 36),
          #|  ("elevation_m", "1920", 49, 53),
          #|  ("id", "top", 55, 58),
          #|  ("class", "big red", 60, 68),
          #|  ("arrived_at", "2026-07-10T09:00:00+09:00", 80, 107),
          #|]
        ),
      )
    _ => fail("expected a directive")
  }
}

///|
test "attribute errors" {
  let r = @syntax.parse(
    (
      #|:::hazard{severity="warning" severity="info" Bad=1 lonely="unterminated}
      #|:::
      #|:::hazard{severity=warn"ing" name}
      #|:::
      #|:::hazard{severity="info"
      #|:::
      #|:::hazard{severity="info"} trailing
      #|:::
      #|:::hazard trailing
      #|:::
      #|:::hazard{# .}
      #|:::
    ),
  )
  debug_inspect(
    render_diagnostics(r),
    content=(
      #|[
      #|  "t.md:1:30: error[duplicate-attribute]: attribute \"severity\" is given more than once",
      #|  "t.md:1:46: error[invalid-attribute]: unexpected \"Bad=1\" in attribute list (keys are lower-case: key=\"value\")",
      #|  "t.md:1:59: error[invalid-attribute]: unterminated quoted value for attribute \"lonely\"",
      #|  "t.md:3:24: error[invalid-attribute]: unexpected quote inside the bare value of \"severity\"",
      #|  "t.md:3:25: error[invalid-attribute]: expected \"=\" after attribute \"ing\" (suggestion: write ing=\"value\")",
      #|  "t.md:3:30: error[invalid-attribute]: expected \"=\" after attribute \"name\" (suggestion: write name=\"value\")",
      #|  "t.md:5:10: error[invalid-directive-header]: attribute block of \":::hazard\" is not closed with \"}\"",
      #|  "t.md:7:27: error[invalid-directive-header]: unexpected text after the attribute block of \":::hazard\"",
      #|  "t.md:9:11: error[invalid-directive-header]: unexpected text after \":::hazard\" (attributes go in braces: :::hazard{key=\"value\"})",
      #|  "t.md:11:11: error[invalid-attribute]: expected a name after \"#\"",
      #|  "t.md:11:13: error[invalid-attribute]: expected a name after \".\"",
      #|]
    ),
  )
  inspect(r.document.blocks.length(), content="6")
}

///|
test "unclosed and nested directives" {
  let r = @syntax.parse(
    (
      #|:::waypoint{name="A"}
      #|text
      #|:::hazard{severity="info"}
      #|inner
      #|:::
      #|:::trail-condition{status="good"}
      #|never closed
    ),
  )
  debug_inspect(
    render_diagnostics(r),
    content=(
      #|[
      #|  "t.md:3:1: error[nested-directive]: directive \":::hazard\" cannot start inside \":::waypoint\" (directives do not nest)",
      #|  "t.md:6:1: error[unclosed-directive]: directive \":::trail-condition\" is not closed with \":::\" before the end of the file",
      #|]
    ),
  )
  debug_inspect(
    outline(r.document.blocks),
    content=(
      #|[
      #|  "directive waypoint [name=A] 1-5 body=[markdown 2-4]",
      #|  "directive trail-condition [status=good] 6-7 body=[markdown 7-7]",
      #|]
    ),
  )
}

///|
test "unclosed front matter" {
  let r = @syntax.parse(
    (
      #|---
      #|title: x
      #|
      #|# Not closed
    ),
  )
  debug_inspect(
    render_diagnostics(r),
    content=(
      #|["t.md:1:1: error[unclosed-front-matter]: front matter opened with \"---\" is never closed"]
    ),
  )
  inspect(r.document.front_matter is None, content="true")
  debug_inspect(
    outline(r.document.blocks),
    content=(
      #|["markdown 1-4"]
    ),
  )
}

///|
test "positions count code points, offsets count code units" {
  let r = @syntax.parse(
    (
      #|:::hazard{severity="🙂" latitude="1"}
      #|:::
    ),
  )
  match r.document.blocks[0] {
    Directive(d) =>
      debug_inspect(
        d.attributes[1].key_range,
        content=(
          #|{
          #|  start: { line: 1, column: 24, offset: 24 },
          #|  end: { line: 1, column: 32, offset: 32 },
          #|}
        ),
      )
    _ => fail("expected a directive")
  }
}
