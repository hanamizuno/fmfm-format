///|
/// A location in the source text. `line` and `column` are 1-based and count
/// Unicode code points; `offset` is 0-based and counts UTF-16 code units
/// (the unit JavaScript and LSP use).
pub(all) struct Position {
  line : Int32
  column : Int32
  offset : Int32
} derive(Eq, Compare, ToJson, @debug.Debug)

///|
/// A half-open span `[start, end)` in the source text.
pub(all) struct Range {
  start : Position
  end : Position
} derive(Eq, ToJson, @debug.Debug)

///|
pub fn Range::point(pos : Position) -> Range {
  { start: pos, end: pos, }
}

///|
/// The smallest range covering both.
pub fn Range::union(self : Range, other : Range) -> Range {
  let start = if self.start < other.start { self.start } else { other.start }
  let end = if self.end > other.end { self.end } else { other.end }
  { start, end, }
}

///|
pub(all) enum Level {
  Error
  Warning
} derive(Eq, @debug.Debug)

///|
pub fn Level::to_string(self : Level) -> String {
  match self {
    Error => "error"
    Warning => "warning"
  }
}

///|
pub impl Show for Level with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub impl ToJson for Level with fn to_json(self) {
  Json::string(self.to_string())
}

///|
/// One problem found in a document. `code` is a stable kebab-case identifier
/// listed in the specification; `message` starts lower-case and names the
/// offending field. `suggestion`, when present, is a concrete replacement.
pub(all) struct Diagnostic {
  level : Level
  code : String
  message : String
  range : Range
  suggestion : String?
} derive(Eq, ToJson, @debug.Debug)

///|
pub fn Diagnostic::error(
  code : String,
  message : String,
  range : Range,
  suggestion? : String,
) -> Diagnostic {
  { level: Error, code, message, range, suggestion, }
}

///|
pub fn Diagnostic::warning(
  code : String,
  message : String,
  range : Range,
  suggestion? : String,
) -> Diagnostic {
  { level: Warning, code, message, range, suggestion, }
}

///|
/// Render in the CLI/editor format: `file:line:col: level[code]: message`.
///
/// ```mbt check
/// test {
///   let d = @diagnostic.Diagnostic::error(
///     "invalid-severity",
///     "severity must be one of: info, caution, warning, danger",
///     @diagnostic.Range::point({ line: 42, column: 18, offset: 900, }),
///   )
///   inspect(
///     d.format(file="hike.md"),
///     content="hike.md:42:18: error[invalid-severity]: severity must be one of: info, caution, warning, danger",
///   )
/// }
/// ```
pub fn Diagnostic::format(
  self : Diagnostic,
  file~ : String = "<input>",
) -> String {
  let { line, column, .. } = self.range.start
  let head = "\{file}:\{line}:\{column}: \{self.level}[\{self.code}]: \{self.message}"
  match self.suggestion {
    Some(s) => "\{head} (suggestion: \{s})"
    None => head
  }
}

///|
pub fn has_errors(diagnostics : Array[Diagnostic]) -> Bool {
  diagnostics.iter().any(d => d.level == Error)
}

///|
/// Stable ordering for output: by start position, errors before warnings.
pub fn sort(diagnostics : Array[Diagnostic]) -> Array[Diagnostic] {
  let sorted = diagnostics.copy()
  sorted.sort_by((a, b) => {
    let c = a.range.start.compare(b.range.start)
    if c != 0 {
      c
    } else {
      match (a.level, b.level) {
        (Error, Warning) => -1
        (Warning, Error) => 1
        _ => 0
      }
    }
  })
  sorted
}
