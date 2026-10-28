///|
/// An RFC 3339 date-time with a mandatory UTC offset (spec §5). The original
/// text is kept so exports reproduce what the author wrote.
pub(all) struct DateTime {
  year : Int32
  month : Int32
  day : Int32
  hour : Int32
  minute : Int32
  second : Int32
  /// Fractional second in nanoseconds (0 when absent).
  nanosecond : Int32
  /// UTC offset in minutes, e.g. `+09:00` is 540.
  offset_minutes : Int32
  text : String
} derive(Eq, @debug.Debug)

///|
pub(all) suberror DateTimeError {
  DateTimeError(String)
} derive(Eq, @debug.Debug)

///|
fn digits(s : String, at : Int32, count : Int32) -> Int32 raise DateTimeError {
  let mut v = 0
  for k in 0..<count {
    match s.get_char(at + k) {
      Some(c) if c.is_ascii_digit() => v = v * 10 + (c.to_int() - '0'.to_int())
      _ => raise DateTimeError("expected \{count} digits at position \{at + 1}")
    }
  }
  v
}

///|
fn expect(s : String, at : Int32, c : Char) -> Unit raise DateTimeError {
  if s.get_char(at) != Some(c) {
    raise DateTimeError("expected \"\{c}\" at position \{at + 1}")
  }
}

///|
fn days_in_month(year : Int32, month : Int32) -> Int32 {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    _ =>
      if (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 {
        29
      } else {
        28
      }
  }
}

///|
/// Parse `YYYY-MM-DDTHH:MM:SS[.fraction](Z|±HH:MM)`. `T` may be lower-case or
/// a space. Date-only values and missing offsets are errors.
///
/// ```mbt check
/// test {
///   let t = @ast.DateTime::parse("2026-07-10T06:20:00+09:00")
///   inspect(t.hour, content="6")
///   inspect(t.offset_minutes, content="540")
///   inspect(
///     t.epoch_seconds(),
///     content=(
///       #|1783632000
///     ),
///   )
/// }
/// ```
pub fn DateTime::parse(text : String) -> DateTime raise DateTimeError {
  let s = text.trim().to_owned()
  let year = digits(s, 0, 4)
  expect(s, 4, '-')
  let month = digits(s, 5, 2)
  expect(s, 7, '-')
  let day = digits(s, 8, 2)
  match s.get_char(10) {
    Some('T') | Some('t') | Some(' ') => ()
    None => raise DateTimeError("a time and a UTC offset are required")
    _ => raise DateTimeError("expected \"T\" between date and time")
  }
  let hour = digits(s, 11, 2)
  expect(s, 13, ':')
  let minute = digits(s, 14, 2)
  expect(s, 16, ':')
  let second = digits(s, 17, 2)
  let mut i = 19
  let mut nanosecond = 0
  if s.get_char(i) == Some('.') {
    i += 1
    let start = i
    let mut scale = 100_000_000
    while i < s.length() && unit(s, i).is_ascii_digit() {
      if scale > 0 {
        nanosecond += (unit(s, i).to_int() - '0'.to_int()) * scale
        scale /= 10
      }
      i += 1
    }
    if i == start {
      raise DateTimeError("expected digits after \".\"")
    }
  }
  let offset_minutes = match s.get_char(i) {
    Some('Z') | Some('z') => {
      i += 1
      0
    }
    Some('+') | Some('-') => {
      let sign = if s.get_char(i) == Some('-') { -1 } else { 1 }
      let oh = digits(s, i + 1, 2)
      expect(s, i + 3, ':')
      let om = digits(s, i + 4, 2)
      if oh > 23 || om > 59 {
        raise DateTimeError("UTC offset out of range")
      }
      i += 6
      sign * (oh * 60 + om)
    }
    None =>
      raise DateTimeError("a UTC offset is required (\"Z\" or \"+09:00\")")
    _ =>
      raise DateTimeError(
        "expected a UTC offset (\"Z\" or \"+09:00\") at position \{i + 1}",
      )
  }
  if i != s.length() {
    raise DateTimeError("unexpected trailing text at position \{i + 1}")
  }
  if month < 1 || month > 12 {
    raise DateTimeError("month out of range")
  }
  if day < 1 || day > days_in_month(year, month) {
    raise DateTimeError("day out of range")
  }
  if hour > 23 || minute > 59 || second > 60 {
    raise DateTimeError("time out of range")
  }
  {
    year,
    month,
    day,
    hour,
    minute,
    second,
    nanosecond,
    offset_minutes,
    text: s,
  }
}

///|
/// Days since 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's
/// `days_from_civil`).
fn days_from_civil(y0 : Int32, m : Int32, d : Int32) -> Int64 {
  let y = if m <= 2 { y0 - 1 } else { y0 }
  let era = (if y >= 0 { y } else { y - 399 }) / 400
  let yoe = y - era * 400
  let mp = (m + 9) % 12
  let doy = (153 * mp + 2) / 5 + d - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era.to_int64() * 146097L + doe.to_int64() - 719468L
}

///|
/// Seconds since the Unix epoch, in UTC. Used for ordering checks.
pub fn DateTime::epoch_seconds(self : DateTime) -> Int64 {
  let days = days_from_civil(self.year, self.month, self.day)
  let local_seconds = days * 86400L +
    (self.hour * 3600 + self.minute * 60 + self.second).to_int64()
  local_seconds - (self.offset_minutes * 60).to_int64()
}

///|
pub fn DateTime::compare(self : DateTime, other : DateTime) -> Int32 {
  let c = self.epoch_seconds().compare(other.epoch_seconds())
  if c != 0 {
    c
  } else {
    self.nanosecond.compare(other.nanosecond)
  }
}

///|
/// The value as written (trimmed).
pub fn DateTime::to_string(self : DateTime) -> String {
  self.text
}

///|
pub impl Show for DateTime with fn output(self, logger) {
  logger.write_string(self.text)
}

///|
/// Parse a number in the spec's lexical form: optional `-`, digits, optional
/// fraction. No exponent, no thousands separators, no leading `+`.
pub fn parse_number(text : String) -> Double? {
  let s = text.trim()
  let n = s.length()
  if n == 0 {
    return None
  }
  let mut i = 0
  if s.get_char(0) == Some('-') {
    i = 1
  }
  let int_start = i
  while i < n && unit(s, i).is_ascii_digit() {
    i += 1
  }
  if i == int_start {
    return None
  }
  if i < n && s.get_char(i) == Some('.') {
    i += 1
    let frac_start = i
    while i < n && unit(s, i).is_ascii_digit() {
      i += 1
    }
    if i == frac_start {
      return None
    }
  }
  if i != n {
    return None
  }
  Some(@string.parse_double(s)) catch {
    _ => None
  }
}

///|
fn unit(s : StringView, i : Int32) -> Char {
  s.at(i).to_int().unsafe_to_char()
}
