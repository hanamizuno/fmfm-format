///|
/// Stand-in Markdown converter until the cmark adapter is wired: wraps each
/// paragraph-ish line in `<p>`.
fn fake_markdown(source : String) -> String {
  source
  .split("\n")
  .filter(l => !l.trim().is_empty())
  .map(l => "<p>" + @html.escape(l.to_owned()) + "</p>\n")
  .join("")
}

///|
fn document() -> @ast.Document {
  let parsed = @syntax.parse(
    (
      #|---
      #|title: x
      #|---
      #|# Test hike
      #|
      #|Intro with <b>html</b> & stuff.
      #|
      #|:::hazard{severity="warning" latitude="35.0" longitude="139.0" note="a \"quoted\" value" #tree .big}
      #|倒木あり。
      #|:::
      #|
      #|:::waypoint{name="Kumotori <hut>" elevation_m=1830.5 arrived_at="2026-07-10T09:00:00+09:00"}
      #|Water.
      #|:::
      #|
      #|:::trail-condition{status="caution" section="hut – summit"}
      #|Snow.
      #|:::
      #|
      #|:::camp{nights=1}
      #|Tent site.
      #|:::
    ),
  )
  let fm = @frontmatter.Node::from_json(
    {
      "format": "fmfm",
      "format_version": "0.1",
      "title": "Test <hike>",
      "summary": "A short & sweet summary",
      "started_at": "2026-07-10T06:20:00+09:00",
      "ended_at": "2026-07-10T17:40:00+09:00",
      "track": { "url": "./track.gpx" },
      "stats": { "distance_m": "21300", "ascent_m": "1780.5" },
      "tags": ["a", "b"],
      "license": "CC-BY-4.0",
    },
    parsed.document.front_matter.unwrap().range,
  )
  @semantic.lower(parsed.document, front_matter=fm).document
}

///|
test "render fragment" {
  let html = @html.render(document(), @html.Options::new(fake_markdown))
  inspect(
    html,
    content=(
      #|<article class="fmfm-document" data-format="fmfm" data-format-version="0.1" data-type="hike">
      #|<header class="fmfm-header">
      #|<h1 class="fmfm-title">Test &lt;hike&gt;</h1>
      #|<p class="fmfm-summary">A short &amp; sweet summary</p>
      #|<dl class="fmfm-meta">
      #|<dt class="fmfm-meta-started-at">Started</dt><dd>2026-07-10T06:20:00+09:00</dd>
      #|<dt class="fmfm-meta-ended-at">Ended</dt><dd>2026-07-10T17:40:00+09:00</dd>
      #|<dt class="fmfm-meta-distance">Distance</dt><dd>21300 m</dd>
      #|<dt class="fmfm-meta-ascent">Ascent</dt><dd>1780.5 m</dd>
      #|<dt class="fmfm-meta-track">Track</dt><dd><a href="./track.gpx">./track.gpx</a></dd>
      #|<dt class="fmfm-meta-tags">Tags</dt><dd>a, b</dd>
      #|<dt class="fmfm-meta-license">License</dt><dd>CC-BY-4.0</dd>
      #|</dl>
      #|</header>
      #|<p># Test hike</p>
      #|<p>Intro with &lt;b&gt;html&lt;/b&gt; &amp; stuff.</p>
      #|<section class="fmfm-hazard big" id="tree" data-severity="warning" data-latitude="35" data-longitude="139" data-note="a &quot;quoted&quot; value">
      #|<p class="fmfm-label fmfm-hazard-label">Hazard: warning</p>
      #|<p>倒木あり。</p>
      #|</section>
      #|<section class="fmfm-waypoint" data-name="Kumotori &lt;hut&gt;" data-elevation-m="1830.5" data-arrived-at="2026-07-10T09:00:00+09:00">
      #|<p class="fmfm-label fmfm-waypoint-label">Kumotori &lt;hut&gt;</p>
      #|<p>Water.</p>
      #|</section>
      #|<section class="fmfm-trail-condition" data-status="caution" data-section="hut – summit">
      #|<p class="fmfm-label fmfm-trail-condition-label">Trail condition: caution (hut – summit)</p>
      #|<p>Snow.</p>
      #|</section>
      #|<section class="fmfm-directive fmfm-directive-camp" data-directive="camp" data-nights="1">
      #|<p>Tent site.</p>
      #|</section>
      #|</article>
      #|
    ),
  )
}

///|
test "render without header and article" {
  let html = @html.render(
    document(),
    @html.Options::new(fake_markdown, header=false, article=false),
  )
  inspect(html.has_prefix("<p>"), content="true")
  inspect(html.contains("<header"), content="false")
}

///|
test "page wrapper" {
  inspect(
    @html.page(
      "<p>x</p>\n",
      title="T <1>",
      css="body { color: red } </style>",
      lang="ja",
    ),
    content=(
      #|<!doctype html>
      #|<html lang="ja">
      #|<head>
      #|<meta charset="utf-8">
      #|<meta name="viewport" content="width=device-width, initial-scale=1">
      #|<title>T &lt;1&gt;</title>
      #|<style>
      #|body { color: red } <\/style>
      #|</style>
      #|</head>
      #|<body>
      #|<p>x</p>
      #|</body>
      #|</html>
      #|
    ),
  )
}
