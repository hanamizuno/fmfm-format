///|
/// Marker that opens and closes a directive.
const Fence : String = ":::"

///|
priv struct CodeFence {
  marker : Char
  length : Int32
}

///|
/// Recognise a CommonMark fenced-code opening line (up to three spaces of
/// indentation, then three or more backticks or tildes; a backtick fence's
/// info string may not contain a backtick).
fn code_fence_open(text : String) -> CodeFence? {
  let mut i = 0
  while i < 3 && text.get_char(i) == Some(' ') {
    i += 1
  }
  match text.get_char(i) {
    Some(marker) if marker == '`' || marker == '~' => {
      let start = i
      while text.get_char(i) == Some(marker) {
        i += 1
      }
      let length = i - start
      if length < 3 {
        return None
      }
      if marker == '`' && text[i:].to_owned().contains("`") {
        return None
      }
      Some({ marker, length, })
    }
    _ => None
  }
}

///|
fn code_fence_close(text : String, fence : CodeFence) -> Bool {
  let mut i = 0
  while i < 3 && text.get_char(i) == Some(' ') {
    i += 1
  }
  let start = i
  while text.get_char(i) == Some(fence.marker) {
    i += 1
  }
  i - start >= fence.length && is_blank(text[i:].to_owned())
}

///|
priv struct Header {
  name : String
  name_end : Int32
  attributes : Array[Attribute]
}

///|
/// Parse `:::name{…}` (the line is known to start with `:::`). Returns `None`
/// when the line is not a directive opener at all (`::: foo`, `:::Foo`), in
/// which case it is ordinary prose.
fn parse_header(
  line : Line,
  diagnostics : Array[@diagnostic.Diagnostic],
) -> Header? {
  let text = line.text
  let n = text.length()
  let mut i = Fence.length()
  let name_start = i
  match text.get_char(i) {
    Some(c) if c.is_ascii_lowercase() => ()
    _ => return None
  }
  while i < n && is_name_char(unit(text, i)) {
    i += 1
  }
  let name = text[name_start:i].to_owned()
  let name_end = i
  while i < n && is_space(unit(text, i)) {
    i += 1
  }
  let attributes : Array[Attribute] = []
  if i < n {
    if text.get_char(i) == Some('{') {
      let open = i
      let close = match text[i:].to_owned().find("}") {
        Some(k) => i + k
        None => {
          diagnostics.push(
            @diagnostic.Diagnostic::error(
              "invalid-directive-header",
              "attribute block of \":::\{name}\" is not closed with \"}\"",
              span(line, open, n),
            ),
          )
          n
        }
      }
      let inner = text[open + 1:close].to_owned()
      for a in parse_attributes(line, inner, open + 1, diagnostics) {
        attributes.push(a)
      }
      i = if close < n { close + 1 } else { n }
      if !is_blank(text[i:].to_owned()) {
        diagnostics.push(
          @diagnostic.Diagnostic::error(
            "invalid-directive-header",
            "unexpected text after the attribute block of \":::\{name}\"",
            span(line, i, n),
          ),
        )
      }
    } else {
      diagnostics.push(
        @diagnostic.Diagnostic::error(
          "invalid-directive-header",
          "unexpected text after \":::\{name}\" (attributes go in braces: :::\{name}{key=\"value\"})",
          span(line, i, n),
        ),
      )
    }
  }
  Some({ name, name_end, attributes, })
}

///|
/// Accumulates prose lines and flushes them as one `RawMarkdown` block.
priv struct Prose {
  lines : Array[Line]
}

///|
fn Prose::flush(self : Prose, into : Array[RawBlock]) -> Unit {
  if self.lines.is_empty() {
    return
  }
  let source = join_lines(self.lines[:])
  if !is_blank(source) {
    into.push(
      Markdown({
        source,
        range: lines_range(self.lines[0], self.lines[self.lines.length() - 1]),
      }),
    )
  }
  self.lines.clear()
}

///|
priv struct OpenDirective {
  header : Header
  header_line : Line
  body : Prose
}

///|
/// Split the body (everything after the front matter) into prose and
/// directives. See ADR-0003 for the grammar.
fn scan_body(
  lines : ArrayView[Line],
  diagnostics : Array[@diagnostic.Diagnostic],
) -> Array[RawBlock] {
  let blocks : Array[RawBlock] = []
  let top = Prose::{ lines: [], }
  let mut open : OpenDirective? = None
  let mut code : CodeFence? = None
  fn current() -> Prose {
    match open {
      Some(d) => d.body
      None => top
    }
  }
  fn close(d : OpenDirective, last : Line) {
    let body : Array[RawBlock] = []
    d.body.flush(body)
    blocks.push(
      Directive({
        name: d.header.name,
        attributes: d.header.attributes,
        body,
        range: lines_range(d.header_line, last),
        header_range: line_range(d.header_line),
        name_range: span(d.header_line, Fence.length(), d.header.name_end),
      }),
    )
  }
  for line in lines {
    let text = line.text
    match code {
      Some(fence) => {
        if code_fence_close(text, fence) {
          code = None
        }
        current().lines.push(line)
        continue
      }
      None => ()
    }
    match code_fence_open(text) {
      Some(fence) => {
        code = Some(fence)
        current().lines.push(line)
        continue
      }
      None => ()
    }
    if !text.has_prefix(Fence) {
      current().lines.push(line)
      continue
    }
    if is_blank(text[Fence.length():]) {
      // Closing fence (a stray `:::` outside a directive is prose).
      match open {
        Some(d) => {
          close(d, line)
          open = None
        }
        None => top.lines.push(line)
      }
      continue
    }
    match parse_header(line, diagnostics) {
      None => current().lines.push(line)
      Some(header) =>
        match open {
          Some(d) => {
            diagnostics.push(
              @diagnostic.Diagnostic::error(
                "nested-directive",
                "directive \":::\{header.name}\" cannot start inside \":::\{d.header.name}\" (directives do not nest)",
                line_range(line),
              ),
            )
            d.body.lines.push(line)
          }
          None => {
            top.flush(blocks)
            open = Some({ header, header_line: line, body: { lines: [], }, })
          }
        }
    }
  }
  match open {
    Some(d) => {
      diagnostics.push(
        @diagnostic.Diagnostic::error(
          "unclosed-directive",
          "directive \":::\{d.header.name}\" is not closed with \":::\" before the end of the file",
          line_range(d.header_line),
        ),
      )
      let last = if lines.length() > 0 {
        lines[lines.length() - 1]
      } else {
        d.header_line
      }
      close(d, last)
    }
    None => top.flush(blocks)
  }
  blocks
}

///|
fn is_front_matter_fence(text : String, allow_dots~ : Bool) -> Bool {
  let t = text.trim_end()
  t == "---" || (allow_dots && t == "...")
}

///|
/// Split the document into its front matter (if any) and body blocks.
///
/// ```mbt check
/// test {
///   let r = @syntax.parse(
///     (
///       #|---
///       #|title: Test
///       #|---
///       #|# Hi
///       #|
///       #|:::hazard{severity="warning"}
///       #|Fallen tree.
///       #|:::
///     ),
///   )
///   inspect(r.diagnostics.length(), content="0")
///   inspect(r.document.front_matter.unwrap().source, content="title: Test\n")
///   inspect(r.document.blocks.length(), content="2")
/// }
/// ```
pub fn parse(source : String) -> ParseResult {
  let diagnostics : Array[@diagnostic.Diagnostic] = []
  let text = match source.strip_prefix("\u{FEFF}") {
    Some(v) => v.to_owned()
    None => source
  }
  let lines = split_lines(text)
  let mut front_matter : RawFrontMatter? = None
  let mut body_start = 0
  if lines.length() > 0 &&
    is_front_matter_fence(lines[0].text, allow_dots=false) {
    let mut close = -1
    for k in 1..<lines.length() {
      if is_front_matter_fence(lines[k].text, allow_dots=true) {
        close = k
        break
      }
    }
    if close < 0 {
      diagnostics.push(
        @diagnostic.Diagnostic::error(
          "unclosed-front-matter",
          "front matter opened with \"---\" is never closed",
          line_range(lines[0]),
        ),
      )
    } else {
      let inner = lines[1:close]
      let range = if close > 1 {
        lines_range(lines[1], lines[close - 1])
      } else {
        @diagnostic.Range::point(position(lines[0], lines[0].text.length()))
      }
      front_matter = Some({ source: join_lines(inner), range, })
      body_start = close + 1
    }
  }
  let blocks = scan_body(lines[body_start:], diagnostics)
  { document: { front_matter, blocks, }, diagnostics, }
}
