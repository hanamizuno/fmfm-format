///|
/// How to render a document. `markdown` converts a CommonMark segment to HTML;
/// the facade supplies the real converter so this package stays free of the
/// Markdown library.
pub(all) struct Options {
  markdown : (String) -> String
  /// Emit the `<header>` with title and metadata (spec §8.2).
  header : Bool
  /// Wrap the output in `<article class="fmfm-document">`.
  article : Bool
}

///|
pub fn Options::new(
  markdown : (String) -> String,
  header~ : Bool = true,
  article~ : Bool = true,
) -> Options {
  { markdown, header, article, }
}

///|
priv struct Writer {
  sb : StringBuilder
  options : Options
}

///|
fn Writer::raw(self : Writer, s : String) -> Unit {
  self.sb.write_string(s)
}

///|
fn Writer::text(self : Writer, s : String) -> Unit {
  self.sb.write_string(escape(s))
}

///|
/// Write ` name="value"` with escaping; `None` writes nothing.
fn Writer::attr(self : Writer, name : String, value : String?) -> Unit {
  match value {
    Some(v) => {
      self.raw(" ")
      self.raw(name)
      self.raw("=\"")
      self.text(v)
      self.raw("\"")
    }
    None => ()
  }
}

///|
fn number(d : Double) -> String {
  if d == d.floor() && d.abs() < 1.0e15 {
    d.to_int64().to_string()
  } else {
    d.to_string()
  }
}

///|
fn Writer::open_section(
  self : Writer,
  kind : String,
  common : @ast.Common,
  data : Array[(String, String?)],
) -> Unit {
  self.raw("<section")
  let classes = ["fmfm-" + kind] + common.classes
  self.attr("class", Some(classes.join(" ")))
  self.attr("id", common.id)
  for pair in data {
    self.attr("data-" + pair.0, pair.1)
  }
  for key, value in common.extra {
    self.attr("data-" + key, Some(value))
  }
  self.raw(">\n")
}

///|
fn location(p : @ast.GeoPoint?) -> Array[(String, String?)] {
  match p {
    Some(g) =>
      [
        ("latitude", Some(number(g.latitude))),
        ("longitude", Some(number(g.longitude))),
      ]
    None => [("latitude", None), ("longitude", None)]
  }
}

///|
fn time(t : @ast.DateTime?) -> String? {
  t.map(v => v.to_string())
}

///|
fn Writer::label(self : Writer, kind : String, text : String) -> Unit {
  self.raw("<p class=\"fmfm-label fmfm-\{kind}-label\">")
  self.text(text)
  self.raw("</p>\n")
}

///|
fn Writer::body(self : Writer, blocks : Array[@ast.Block]) -> Unit {
  for b in blocks {
    self.block(b)
  }
}

///|
fn Writer::block(self : Writer, b : @ast.Block) -> Unit {
  match b {
    Markdown(m) => {
      let html = (self.options.markdown)(m.source)
      self.raw(html)
      if !html.has_suffix("\n") {
        self.raw("\n")
      }
    }
    Waypoint(w) => {
      self.open_section(
        "waypoint",
        w.common,
        [("name", Some(w.name))] +
        location(w.location) +
        [
          ("elevation-m", w.elevation_m.map(number)),
          ("arrived-at", time(w.arrived_at)),
          ("departed-at", time(w.departed_at)),
        ],
      )
      self.label("waypoint", w.name)
      self.body(w.body)
      self.raw("</section>\n")
    }
    Hazard(h) => {
      self.open_section(
        "hazard",
        h.common,
        [("severity", Some(h.severity.to_string()))] +
        location(h.location) +
        [("observed-at", time(h.observed_at))],
      )
      self.label("hazard", "Hazard: " + h.severity.to_string())
      self.body(h.body)
      self.raw("</section>\n")
    }
    TrailCondition(t) => {
      self.open_section(
        "trail-condition",
        t.common,
        [("status", Some(t.status.to_string())), ("section", t.section)] +
        location(t.location) +
        [("observed-at", time(t.observed_at))],
      )
      let label = match t.section {
        Some(s) => "Trail condition: \{t.status} (\{s})"
        None => "Trail condition: \{t.status}"
      }
      self.label("trail-condition", label)
      self.body(t.body)
      self.raw("</section>\n")
    }
    Unknown(u) => {
      let data : Array[(String, String?)] = [("directive", Some(u.name))]
      for k, v in u.attributes {
        data.push((k, Some(v)))
      }
      self.raw("<section")
      let classes = ["fmfm-directive", "fmfm-directive-" + u.name] +
        u.common.classes
      self.attr("class", Some(classes.join(" ")))
      self.attr("id", u.common.id)
      for pair in data {
        self.attr("data-" + pair.0, pair.1)
      }
      self.raw(">\n")
      self.body(u.body)
      self.raw("</section>\n")
    }
  }
}

///|
fn Writer::meta_row(
  self : Writer,
  key : String,
  label : String,
  value : String?,
) -> Unit {
  match value {
    Some(v) => {
      self.raw("<dt class=\"fmfm-meta-\{key}\">")
      self.text(label)
      self.raw("</dt><dd>")
      self.text(v)
      self.raw("</dd>\n")
    }
    None => ()
  }
}

///|
fn Writer::header(self : Writer, m : @ast.Metadata) -> Unit {
  self.raw("<header class=\"fmfm-header\">\n<h1 class=\"fmfm-title\">")
  self.text(m.title)
  self.raw("</h1>\n")
  match m.summary {
    Some(s) => {
      self.raw("<p class=\"fmfm-summary\">")
      self.text(s)
      self.raw("</p>\n")
    }
    None => ()
  }
  self.raw("<dl class=\"fmfm-meta\">\n")
  self.meta_row("started-at", "Started", time(m.started_at))
  self.meta_row("ended-at", "Ended", time(m.ended_at))
  match m.stats {
    Some(s) => {
      self.meta_row(
        "distance",
        "Distance",
        s.distance_m.map(v => number(v) + " m"),
      )
      self.meta_row("ascent", "Ascent", s.ascent_m.map(v => number(v) + " m"))
      self.meta_row(
        "descent",
        "Descent",
        s.descent_m.map(v => number(v) + " m"),
      )
    }
    None => ()
  }
  match m.track {
    Some(t) => {
      self.raw("<dt class=\"fmfm-meta-track\">Track</dt><dd><a href=\"")
      self.text(t.url)
      self.raw("\">")
      self.text(t.url)
      self.raw("</a></dd>\n")
    }
    None => ()
  }
  if !m.tags.is_empty() {
    self.meta_row("tags", "Tags", Some(m.tags.join(", ")))
  }
  if !m.members.is_empty() {
    self.meta_row("members", "Members", Some(m.members.join(", ")))
  }
  self.meta_row("license", "License", m.license)
  self.raw("</dl>\n</header>\n")
}

///|
/// Render the document as an HTML fragment (spec §8.2).
pub fn render(doc : @ast.Document, options : Options) -> String {
  let w = Writer::{ sb: StringBuilder(), options, }
  if options.article {
    w.raw("<article class=\"fmfm-document\" data-format=\"fmfm\"")
    w.attr("data-format-version", doc.metadata.format_version)
    w.attr("data-type", Some(doc.metadata.kind))
    w.raw(">\n")
  }
  if options.header {
    w.header(doc.metadata)
  }
  w.body(doc.blocks)
  if options.article {
    w.raw("</article>\n")
  }
  w.sb.to_string()
}

///|
/// Wrap a fragment in a complete HTML page. `css` is inlined when given.
pub fn page(
  fragment : String,
  title~ : String,
  css? : String,
  lang~ : String = "en",
) -> String {
  let sb = StringBuilder()
  sb.write_string("<!doctype html>\n<html lang=\"")
  sb.write_string(escape(lang))
  sb.write_string(
    "\">\n<head>\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n<title>",
  )
  sb.write_string(escape(title))
  sb.write_string("</title>\n")
  match css {
    Some(c) => {
      sb.write_string("<style>\n")
      sb.write_string(c.replace_all(old="</", new="<\\/"))
      sb.write_string("\n</style>\n")
    }
    None => ()
  }
  sb.write_string("</head>\n<body>\n")
  sb.write_string(fragment)
  sb.write_string("</body>\n</html>\n")
  sb.to_string()
}
