///|
/// Attribute multiset of one directive, consumed key by key so that whatever
/// is left over is "unknown".
priv struct Attrs {
  ctx : Ctx
  directive : @syntax.RawDirective
  remaining : Map[String, @syntax.Attribute]
}

///|
fn Attrs::new(ctx : Ctx, d : @syntax.RawDirective) -> Attrs {
  let remaining : Map[String, @syntax.Attribute] = Map([])
  for a in d.attributes {
    if !remaining.contains(a.key) {
      remaining[a.key] = a
    }
  }
  { ctx, directive: d, remaining, }
}

///|
fn Attrs::take(self : Attrs, key : String) -> @syntax.Attribute? {
  let a = self.remaining.get(key)
  self.remaining.remove(key)
  a
}

///|
fn Attrs::string(self : Attrs, key : String) -> String? {
  self.take(key).map(a => a.value)
}

///|
fn Attrs::required(self : Attrs, key : String) -> @syntax.Attribute? {
  match self.take(key) {
    Some(a) => Some(a)
    None => {
      self.ctx.error(
        "missing-attribute",
        "\":::\{self.directive.name}\" requires the attribute \"\{key}\"",
        self.directive.header_range,
      )
      None
    }
  }
}

///|
fn Attrs::number(self : Attrs, key : String) -> Double? {
  match self.take(key) {
    None => None
    Some(a) =>
      match @ast.parse_number(a.value) {
        Some(v) => Some(v)
        None => {
          self.ctx.error(
            "invalid-value",
            "\{key} must be a number, found \"\{a.value}\"",
            a.value_range,
          )
          None
        }
      }
  }
}

///|
fn Attrs::date_time(self : Attrs, key : String) -> @ast.DateTime? {
  match self.take(key) {
    None => None
    Some(a) => date_time(self.ctx, a.value, a.value_range, key)
  }
}

///|
/// `latitude` / `longitude`: both or neither, each within range.
fn Attrs::location(self : Attrs) -> @ast.GeoPoint? {
  let lat = self.take("latitude")
  let lon = self.take("longitude")
  match (lat, lon) {
    (None, None) => None
    (Some(a), None) | (None, Some(a)) => {
      let missing = if lat is None { "latitude" } else { "longitude" }
      self.ctx.error(
        "missing-coordinate",
        "\"\{a.key}\" is given without \"\{missing}\" (both are required for a location)",
        a.key_range,
      )
      None
    }
    (Some(a), Some(b)) => {
      let la = coordinate(self.ctx, a, 90.0)
      let lo = coordinate(self.ctx, b, 180.0)
      match (la, lo) {
        (Some(latitude), Some(longitude)) => Some({ latitude, longitude, })
        _ => None
      }
    }
  }
}

///|
fn coordinate(ctx : Ctx, a : @syntax.Attribute, limit : Double) -> Double? {
  match @ast.parse_number(a.value) {
    None => {
      ctx.error(
        "invalid-value",
        "\{a.key} must be decimal degrees, found \"\{a.value}\"",
        a.value_range,
      )
      None
    }
    Some(v) if v < -limit || v > limit => {
      ctx.error(
        "out-of-range",
        "\{a.key} must be between -\{limit} and \{limit}, found \{a.value}",
        a.value_range,
      )
      None
    }
    Some(v) => Some(v)
  }
}

///|
/// Pull out `id` / `class`, warn about everything still unconsumed and keep
/// it in `extra`.
fn Attrs::finish(self : Attrs) -> @ast.Common {
  let id = self.string("id")
  let classes = match self.string("class") {
    Some(c) =>
      c.split(" ").filter(s => !s.is_empty()).map(s => s.to_owned()).collect()
    None => []
  }
  let extra : Map[String, String] = Map([])
  for key, a in self.remaining {
    self.ctx.warning(
      "unknown-attribute",
      "unknown attribute \"\{key}\" on \":::\{self.directive.name}\" (kept as extra)",
      a.key_range,
    )
    extra[key] = a.value
  }
  { id, classes, extra, range: self.directive.range, }
}

///|
fn lower_directive(ctx : Ctx, d : @syntax.RawDirective) -> @ast.Block {
  let attrs = Attrs::new(ctx, d)
  let body = lower_blocks(ctx, d.body)
  match d.name {
    "waypoint" => {
      let name = attrs.required("name").map(a => a.value)
      let location = attrs.location()
      let elevation_m = attrs.number("elevation_m")
      let arrived_at = attrs.date_time("arrived_at")
      let departed_at = attrs.date_time("departed_at")
      match (arrived_at, departed_at) {
        (Some(a), Some(b)) if b.compare(a) < 0 =>
          ctx.error(
            "time-order",
            "departed_at (\{b}) is earlier than arrived_at (\{a})",
            d.header_range,
          )
        _ => ()
      }
      let common = attrs.finish()
      Waypoint({
        name: name.unwrap_or(""),
        location,
        elevation_m,
        arrived_at,
        departed_at,
        common,
        body,
      })
    }
    "hazard" => {
      let severity = match attrs.required("severity") {
        None => @ast.Severity::Info
        Some(a) =>
          match @ast.Severity::from_string(a.value) {
            Some(s) => s
            None => {
              ctx.error(
                "invalid-severity",
                "severity must be one of: \{@ast.SeverityValues}, found \"\{a.value}\"",
                a.value_range,
              )
              Info
            }
          }
      }
      let location = attrs.location()
      let observed_at = attrs.date_time("observed_at")
      let common = attrs.finish()
      Hazard({ severity, location, observed_at, common, body, })
    }
    "trail-condition" => {
      let status = match attrs.required("status") {
        None => @ast.TrailStatus::Good
        Some(a) =>
          match @ast.TrailStatus::from_string(a.value) {
            Some(s) => s
            None => {
              ctx.error(
                "invalid-status",
                "status must be one of: \{@ast.TrailStatusValues}, found \"\{a.value}\"",
                a.value_range,
              )
              Good
            }
          }
      }
      let section = attrs.string("section")
      let location = attrs.location()
      let observed_at = attrs.date_time("observed_at")
      let common = attrs.finish()
      TrailCondition({ status, section, location, observed_at, common, body, })
    }
    other => {
      ctx.warning(
        "unknown-directive",
        "unknown directive \":::\{other}\" (kept as-is)",
        d.name_range,
      )
      let id = attrs.string("id")
      let classes = match attrs.string("class") {
        Some(c) =>
          c
          .split(" ")
          .filter(s => !s.is_empty())
          .map(s => s.to_owned())
          .collect()
        None => []
      }
      let attributes : Map[String, String] = Map([])
      for key, a in attrs.remaining {
        attributes[key] = a.value
      }
      Unknown({
        name: other,
        attributes,
        common: { id, classes, extra: Map([]), range: d.range, },
        body,
      })
    }
  }
}
