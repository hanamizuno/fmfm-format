///|
test "parse accepted forms" {
  let a = @ast.DateTime::parse("2026-07-10T06:20:00+09:00")
  let b = @ast.DateTime::parse("2026-07-09t21:20:00Z")
  let c = @ast.DateTime::parse("2026-07-10 06:20:00.5+09:00")
  inspect(a.epoch_seconds() == b.epoch_seconds(), content="true")
  inspect(a.compare(b), content="0")
  inspect(c.nanosecond, content="500000000")
  inspect(c.compare(a) > 0, content="true")
  inspect(
    @ast.DateTime::parse("2024-02-29T00:00:00-05:30").offset_minutes,
    content="-330",
  )
}

///|
test "parse rejects date-only, missing offset and bad fields" {
  let cases = [
    "2026-07-10", "2026-07-10T06:20:00", "2026-13-01T00:00:00Z", "2025-02-29T00:00:00Z",
    "2026-07-10T24:00:00Z", "2026-07-10T06:20:00+09", "2026-07-10T06:20:00+09:00 extra",
    "yesterday",
  ]
  let out = cases.map(c => {
    try @ast.DateTime::parse(c) catch {
      @ast.DateTimeError(m) => m
    } noraise {
      _ => "ok"
    }
  })
  debug_inspect(
    out,
    content=(
      #|[
      #|  "a time and a UTC offset are required",
      #|  "a UTC offset is required (\"Z\" or \"+09:00\")",
      #|  "month out of range",
      #|  "day out of range",
      #|  "time out of range",
      #|  "expected \":\" at position 23",
      #|  "unexpected trailing text at position 26",
      #|  "expected 4 digits at position 1",
      #|]
    ),
  )
}

///|
test "parse_number" {
  debug_inspect(
    ["21300", "1780.5", "-3", " 35.87 ", "1e3", "1,000", ".5", "5.", "+1", ""].map(
      @ast.parse_number,
    ),
    content=(
      #|[
      #|  Some(21300),
      #|  Some(1780.5),
      #|  Some(-3),
      #|  Some(35.87),
      #|  None,
      #|  None,
      #|  None,
      #|  None,
      #|  None,
      #|  None,
      #|]
    ),
  )
}

///|
test "severity and status vocabularies" {
  debug_inspect(
    ["info", "caution", "warning", "danger", "severe"].map(
      @ast.Severity::from_string,
    ),
    content=(
      #|[Some(Info), Some(Caution), Some(Warning), Some(Danger), None]
    ),
  )
  debug_inspect(
    ["good", "caution", "impassable", "closed"].map(
      @ast.TrailStatus::from_string,
    ),
    content=(
      #|[Some(Good), Some(Caution), Some(Impassable), None]
    ),
  )
}
