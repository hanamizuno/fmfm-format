///|
/// A source line without its terminator. `start` / `end` are UTF-16 offsets
/// of the text; `index` is 0-based.
priv struct Line {
  index : Int32
  text : String
  start : Int32
}

///|
/// Split on `\n` or `\r\n`. A trailing newline does not produce an extra empty
/// line, so a file ending in `\n` has as many lines as newline characters.
fn split_lines(source : String) -> Array[Line] {
  let lines : Array[Line] = []
  let n = source.length()
  let mut start = 0
  let mut i = 0
  while i < n {
    let c = source.at(i)
    if c == '\n'.to_int().to_uint16() {
      let text_end = if i > start &&
        source.at(i - 1) == '\r'.to_int().to_uint16() {
        i - 1
      } else {
        i
      }
      lines.push({
        index: lines.length(),
        text: source[start:text_end].to_owned(),
        start,
      })
      start = i + 1
    }
    i += 1
  }
  if start < n {
    lines.push({
      index: lines.length(),
      text: source[start:n].to_owned(),
      start,
    })
  }
  lines
}

///|
/// Position of the UTF-16 column `col` (0-based) on `line`.
fn position(line : Line, col : Int32) -> @diagnostic.Position {
  let clamped = if col > line.text.length() { line.text.length() } else { col }
  {
    line: line.index + 1,
    column: line.text.char_length(end_offset=clamped) + 1,
    offset: line.start + clamped,
  }
}

///|
fn line_range(line : Line) -> @diagnostic.Range {
  { start: position(line, 0), end: position(line, line.text.length()), }
}

///|
fn span(line : Line, from : Int32, to : Int32) -> @diagnostic.Range {
  { start: position(line, from), end: position(line, to), }
}

///|
/// Range from the start of `first` to the end of `last`.
fn lines_range(first : Line, last : Line) -> @diagnostic.Range {
  { start: position(first, 0), end: position(last, last.text.length()), }
}

///|
fn join_lines(lines : ArrayView[Line]) -> String {
  let sb = StringBuilder()
  for l in lines {
    sb.write_string(l.text)
    sb.write_char('\n')
  }
  sb.to_string()
}

///|
fn is_blank(s : StringView) -> Bool {
  s.trim().is_empty()
}

///|
/// The UTF-16 code unit at `i` as a `Char`. The grammar only ever compares
/// against ASCII, so a surrogate half is simply "some other character".
fn unit(s : String, i : Int32) -> Char {
  s.at(i).to_int().unsafe_to_char()
}
