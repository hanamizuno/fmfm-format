///|
/// Specification version written into exports.
pub const FormatVersion : String = "0.1"

///|
fn obj(pairs : Array[(String, Json?)]) -> Json {
  let m : Map[String, Json] = Map([])
  for p in pairs {
    match p.1 {
      Some(v) => m[p.0] = v
      None => ()
    }
  }
  Json::object(m)
}

///|
fn str(s : String?) -> Json? {
  s.map(Json::string)
}

///|
fn num(d : Double?) -> Json? {
  d.map(v => Json::number(v))
}

///|
fn time(t : @ast.DateTime?) -> Json? {
  t.map(v => Json::string(v.to_string()))
}

///|
fn strings(xs : Array[String]) -> Json? {
  if xs.is_empty() {
    None
  } else {
    Some(Json::array(xs.map(Json::string)))
  }
}

///|
fn string_map(m : Map[String, String]) -> Json? {
  if m.is_empty() {
    None
  } else {
    let o : Map[String, Json] = Map([])
    for k, v in m {
      o[k] = Json::string(v)
    }
    Some(Json::object(o))
  }
}

///|
fn location(p : @ast.GeoPoint?) -> Json? {
  p.map(g => {
    obj([
      ("latitude", Some(Json::number(g.latitude))),
      ("longitude", Some(Json::number(g.longitude))),
    ])
  })
}

///|
fn common(c : @ast.Common, positions~ : Bool) -> Array[(String, Json?)] {
  [
    ("id", str(c.id)),
    ("class", strings(c.classes)),
    ("extra", string_map(c.extra)),
    ("range", if positions { Some(c.range.to_json()) } else { None }),
  ]
}

///|
fn block(b : @ast.Block, positions~ : Bool) -> Json {
  match b {
    Markdown(m) =>
      obj([
        ("type", Some(Json::string("markdown"))),
        ("source", Some(Json::string(m.source))),
        ("range", if positions { Some(m.range.to_json()) } else { None }),
      ])
    Waypoint(w) =>
      obj(
        [
          ("type", Some(Json::string("waypoint"))),
          ("name", Some(Json::string(w.name))),
          ("location", location(w.location)),
          ("elevation_m", num(w.elevation_m)),
          ("arrived_at", time(w.arrived_at)),
          ("departed_at", time(w.departed_at)),
        ] +
        common(w.common, positions~) +
        [("body", Some(blocks(w.body, positions~)))],
      )
    Hazard(h) =>
      obj(
        [
          ("type", Some(Json::string("hazard"))),
          ("severity", Some(Json::string(h.severity.to_string()))),
          ("location", location(h.location)),
          ("observed_at", time(h.observed_at)),
        ] +
        common(h.common, positions~) +
        [("body", Some(blocks(h.body, positions~)))],
      )
    TrailCondition(t) =>
      obj(
        [
          ("type", Some(Json::string("trail-condition"))),
          ("status", Some(Json::string(t.status.to_string()))),
          ("section", str(t.section)),
          ("location", location(t.location)),
          ("observed_at", time(t.observed_at)),
        ] +
        common(t.common, positions~) +
        [("body", Some(blocks(t.body, positions~)))],
      )
    Unknown(u) =>
      obj(
        [
          ("type", Some(Json::string("directive"))),
          ("name", Some(Json::string(u.name))),
          (
            "attributes",
            Some(string_map(u.attributes).unwrap_or(Json::empty_object())),
          ),
        ] +
        common(u.common, positions~) +
        [("body", Some(blocks(u.body, positions~)))],
      )
  }
}

///|
fn blocks(bs : Array[@ast.Block], positions~ : Bool) -> Json {
  Json::array(bs.map(b => block(b, positions~)))
}

///|
fn metadata(m : @ast.Metadata) -> Json {
  let extra = if m.extra.is_empty() {
    None
  } else {
    Some(Json::object(m.extra))
  }
  obj([
    ("type", Some(Json::string(m.kind))),
    ("title", Some(Json::string(m.title))),
    ("started_at", time(m.started_at)),
    ("ended_at", time(m.ended_at)),
    ("summary", str(m.summary)),
    (
      "track",
      m.track.map(t => {
        obj([
          ("url", Some(Json::string(t.url))),
          ("format", Some(Json::string(t.format))),
        ])
      }),
    ),
    (
      "stats",
      m.stats.map(s => {
        obj([
          ("distance_m", num(s.distance_m)),
          ("ascent_m", num(s.ascent_m)),
          ("descent_m", num(s.descent_m)),
        ])
      }),
    ),
    ("tags", strings(m.tags)),
    ("members", strings(m.members)),
    ("license", str(m.license)),
    ("extra", extra),
  ])
}

///|
/// The stable public JSON shape (spec §8.1, the CLI `export` command). Absent optional fields are
/// omitted; no source positions.
pub fn to_json(doc : @ast.Document) -> Json {
  obj([
    ("format", Some(Json::string("fmfm"))),
    ("format_version", Some(Json::string(FormatVersion))),
    ("metadata", Some(metadata(doc.metadata))),
    ("blocks", Some(blocks(doc.blocks, positions=false))),
  ])
}

///|
/// Everything, for debugging: the export shape plus source ranges on every
/// block and the diagnostics. Not a stable contract.
pub fn dump(
  doc : @ast.Document,
  diagnostics : Array[@diagnostic.Diagnostic],
) -> Json {
  obj([
    ("format", Some(Json::string("fmfm"))),
    ("format_version", Some(Json::string(FormatVersion))),
    ("declared_format_version", str(doc.metadata.format_version)),
    ("metadata", Some(metadata(doc.metadata))),
    ("blocks", Some(blocks(doc.blocks, positions=true))),
    ("diagnostics", Some(Json::array(diagnostics.map(d => d.to_json())))),
  ])
}
