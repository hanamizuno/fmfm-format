///|
fn scalar(
  ctx : Ctx,
  entry : @frontmatter.Entry,
  what : String,
) -> (String, @diagnostic.Range)? {
  match entry.value {
    Scalar(s, r) => Some((s, r))
    other => {
      ctx.error(
        "invalid-value",
        "\{what} must be a single value, not a list or mapping",
        other.range(),
      )
      None
    }
  }
}

///|
fn string_list(
  ctx : Ctx,
  entry : @frontmatter.Entry,
  what : String,
) -> Array[String] {
  match entry.value {
    Sequence(items, _) => {
      let out : Array[String] = []
      for item in items {
        match item {
          Scalar(s, _) => out.push(s)
          other =>
            ctx.error(
              "invalid-value",
              "\{what} must be a list of plain values",
              other.range(),
            )
        }
      }
      out
    }
    other => {
      ctx.error("invalid-value", "\{what} must be a list", other.range())
      []
    }
  }
}

///|
fn date_time(
  ctx : Ctx,
  text : String,
  range : @diagnostic.Range,
  what : String,
) -> @ast.DateTime? {
  try @ast.DateTime::parse(text) catch {
    @ast.DateTimeError(reason) => {
      ctx.error(
        "invalid-value",
        "\{what} must be an RFC 3339 date-time with a UTC offset: \{reason}",
        range,
        suggestion="e.g. 2026-07-10T06:20:00+09:00",
      )
      None
    }
  } noraise {
    v => Some(v)
  }
}

///|
fn non_negative(
  ctx : Ctx,
  text : String,
  range : @diagnostic.Range,
  what : String,
) -> Double? {
  match @ast.parse_number(text) {
    None => {
      ctx.error("invalid-value", "\{what} must be a number in metres", range)
      None
    }
    Some(v) if v < 0.0 => {
      ctx.error("out-of-range", "\{what} must not be negative", range)
      None
    }
    Some(v) => Some(v)
  }
}

///|
fn lower_metadata(
  ctx : Ctx,
  front_matter : @frontmatter.Node?,
  doc_start : @diagnostic.Range,
) -> @ast.Metadata {
  let md = @ast.Metadata::empty()
  let root = match front_matter {
    Some(Mapping(_, _) as m) => m
    Some(other) => {
      ctx.error(
        "invalid-yaml",
        "front matter must be a mapping of keys to values",
        other.range(),
      )
      ctx.error("missing-title", "title is required", doc_start)
      return md
    }
    None => {
      ctx.error(
        "missing-title", "title is required (add a front matter block with a title)",
        doc_start,
      )
      ctx.warning(
        "missing-format", "add format: fmfm and format_version: \"0.1\" to the front matter",
        doc_start,
      )
      return md
    }
  }
  let fm_range = root.range()
  let entries = match root {
    Mapping(entries, _) => entries
    _ => []
  }
  let mut format_version : String? = None
  let mut kind = "hike"
  let mut title : String? = None
  let mut started_at : @ast.DateTime? = None
  let mut ended_at : @ast.DateTime? = None
  let mut summary : String? = None
  let mut track : @ast.Track? = None
  let mut stats : @ast.Stats? = None
  let mut tags : Array[String] = []
  let mut members : Array[String] = []
  let mut license : String? = None
  let extra : Map[String, Json] = Map([])
  let mut saw_format = false
  for entry in entries {
    match entry.key {
      "format" => {
        saw_format = true
        match scalar(ctx, entry, "format") {
          Some(("fmfm", _)) => ()
          Some((other, r)) =>
            ctx.error(
              "invalid-format",
              "format must be \"fmfm\", found \"\{other}\"",
              r,
            )
          None => ()
        }
      }
      "format_version" =>
        match scalar(ctx, entry, "format_version") {
          Some((v, r)) => {
            format_version = Some(v)
            check_version(ctx, v, r)
          }
          None => ()
        }
      "type" =>
        match scalar(ctx, entry, "type") {
          Some((v, _)) => kind = v
          None => ()
        }
      "title" =>
        match scalar(ctx, entry, "title") {
          Some((v, r)) =>
            if v.trim().is_empty() {
              ctx.error("missing-title", "title must not be empty", r)
            } else {
              title = Some(v)
            }
          None => ()
        }
      "started_at" =>
        match scalar(ctx, entry, "started_at") {
          Some((v, r)) => started_at = date_time(ctx, v, r, "started_at")
          None => ()
        }
      "ended_at" =>
        match scalar(ctx, entry, "ended_at") {
          Some((v, r)) => ended_at = date_time(ctx, v, r, "ended_at")
          None => ()
        }
      "summary" =>
        match scalar(ctx, entry, "summary") {
          Some((v, _)) => summary = Some(v)
          None => ()
        }
      "license" =>
        match scalar(ctx, entry, "license") {
          Some((v, _)) => license = Some(v)
          None => ()
        }
      "tags" => tags = string_list(ctx, entry, "tags")
      "members" => members = string_list(ctx, entry, "members")
      "track" => track = lower_track(ctx, entry)
      "stats" => stats = lower_stats(ctx, entry)
      other => {
        ctx.warning(
          "unknown-field",
          "unknown front matter field \"\{other}\" (kept under extra)",
          entry.key_range,
        )
        extra[other] = entry.value.to_json()
      }
    }
  }
  if !saw_format || format_version is None {
    ctx.warning(
      "missing-format", "add format: fmfm and format_version: \"0.1\" to the front matter",
      fm_range,
    )
  }
  let title_value = match title {
    Some(t) => t
    None => {
      if entries.iter().all(e => e.key != "title") {
        ctx.error("missing-title", "title is required", fm_range)
      }
      ""
    }
  }
  match (started_at, ended_at) {
    (Some(s), Some(e)) =>
      if e.compare(s) < 0 {
        let r = match root.get("ended_at") {
          Some(entry) => entry.value.range()
          None => fm_range
        }
        ctx.error(
          "time-order",
          "ended_at (\{e}) is earlier than started_at (\{s})",
          r,
        )
      }
    _ => ()
  }
  {
    format_version,
    kind,
    title: title_value,
    started_at,
    ended_at,
    summary,
    track,
    stats,
    tags,
    members,
    license,
    extra,
  }
}

///|
/// Supported major version of the specification.
const SupportedMajor : Int32 = 0

///|
/// Highest minor version this implementation knows for `SupportedMajor`.
const SupportedMinor : Int32 = 1

///|
fn check_version(ctx : Ctx, v : String, r : @diagnostic.Range) -> Unit {
  let parts = v.split(".").map(p => p.to_owned()).collect()
  let parsed = if parts.length() == 2 {
    let a = Some(@string.parse_int(parts[0])) catch { _ => None }
    let b = Some(@string.parse_int(parts[1])) catch { _ => None }
    match (a, b) {
      (Some(a), Some(b)) if a >= 0 && b >= 0 => Some((a, b))
      _ => None
    }
  } else {
    None
  }
  match parsed {
    None =>
      ctx.error(
        "invalid-format",
        "format_version must look like \"0.1\", found \"\{v}\"",
        r,
        suggestion="format_version: \"0.1\"",
      )
    Some((major, _)) if major != SupportedMajor =>
      ctx.error(
        "invalid-format",
        "format_version \{v} is not supported by this implementation (supports \{SupportedMajor}.x)",
        r,
      )
    Some((_, minor)) if minor > SupportedMinor =>
      ctx.warning(
        "newer-format-version",
        "format_version \{v} is newer than this implementation (\{SupportedMajor}.\{SupportedMinor}); unknown items are preserved",
        r,
      )
    Some(_) => ()
  }
}

///|
fn lower_track(ctx : Ctx, entry : @frontmatter.Entry) -> @ast.Track? {
  match entry.value {
    Mapping(fields, r) => {
      let mut url : String? = None
      let mut format = "gpx"
      for f in fields {
        match (f.key, f.value) {
          ("url", Scalar(v, _)) => url = Some(v)
          ("format", Scalar(v, _)) => format = v
          ("url", other) | ("format", other) =>
            ctx.error(
              "invalid-value",
              "track.\{f.key} must be a single value",
              other.range(),
            )
          (other, _) =>
            ctx.warning(
              "unknown-field",
              "unknown track field \"\{other}\"",
              f.key_range,
            )
        }
      }
      match url {
        Some(u) => Some({ url: u, format, })
        None => {
          ctx.error("invalid-value", "track must have a url", r)
          None
        }
      }
    }
    other => {
      ctx.error(
        "invalid-value",
        "track must be a mapping with a url (track.url: ./track.gpx)",
        other.range(),
      )
      None
    }
  }
}

///|
fn lower_stats(ctx : Ctx, entry : @frontmatter.Entry) -> @ast.Stats? {
  match entry.value {
    Mapping(fields, _) => {
      let mut distance_m : Double? = None
      let mut ascent_m : Double? = None
      let mut descent_m : Double? = None
      for f in fields {
        match (f.key, f.value) {
          ("distance_m", Scalar(v, r)) =>
            distance_m = non_negative(ctx, v, r, "stats.distance_m")
          ("ascent_m", Scalar(v, r)) =>
            ascent_m = non_negative(ctx, v, r, "stats.ascent_m")
          ("descent_m", Scalar(v, r)) =>
            descent_m = non_negative(ctx, v, r, "stats.descent_m")
          ("distance_m", other) | ("ascent_m", other) | ("descent_m", other) =>
            ctx.error(
              "invalid-value",
              "stats.\{f.key} must be a number in metres",
              other.range(),
            )
          (other, _) =>
            ctx.warning(
              "unknown-field",
              "unknown stats field \"\{other}\"",
              f.key_range,
            )
        }
      }
      Some({ distance_m, ascent_m, descent_m, })
    }
    other => {
      ctx.error(
        "invalid-value",
        "stats must be a mapping (distance_m, ascent_m, descent_m)",
        other.range(),
      )
      None
    }
  }
}
