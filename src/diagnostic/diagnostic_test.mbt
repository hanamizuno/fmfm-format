///|
test "format with and without suggestion" {
  let range : @diagnostic.Range = {
    start: { line: 3, column: 5, offset: 40, },
    end: { line: 3, column: 12, offset: 47, },
  }
  let plain = @diagnostic.Diagnostic::warning(
    "unknown-attribute", "unknown attribute \"colour\"", range,
  )
  inspect(
    plain.format(),
    content="<input>:3:5: warning[unknown-attribute]: unknown attribute \"colour\"",
  )
  let hinted = @diagnostic.Diagnostic::error(
    "invalid-status",
    "status must be one of: good, caution, impassable",
    range,
    suggestion="use \"caution\"",
  )
  inspect(
    hinted.format(file="a.md"),
    content="a.md:3:5: error[invalid-status]: status must be one of: good, caution, impassable (suggestion: use \"caution\")",
  )
}

///|
test "sort orders by position then level" {
  let p1 : @diagnostic.Position = { line: 1, column: 1, offset: 0, }
  let p2 : @diagnostic.Position = { line: 2, column: 1, offset: 10, }
  let w1 = @diagnostic.Diagnostic::warning(
    "w",
    "w",
    @diagnostic.Range::point(p2),
  )
  let e1 = @diagnostic.Diagnostic::error("e", "e", @diagnostic.Range::point(p2))
  let e0 = @diagnostic.Diagnostic::error(
    "first",
    "f",
    @diagnostic.Range::point(p1),
  )
  let sorted = @diagnostic.sort([w1, e1, e0])
  debug_inspect(
    sorted.map(d => d.code),
    content=(
      #|["first", "e", "w"]
    ),
  )
  inspect(@diagnostic.has_errors([w1]), content="false")
  inspect(@diagnostic.has_errors([w1, e1]), content="true")
}
