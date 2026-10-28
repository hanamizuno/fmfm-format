///|
/// Hazard severity. The boundaries are defined in the specification (§4.4).
pub(all) enum Severity {
  Info
  Caution
  Warning
  Danger
} derive(Eq, @debug.Debug)

///|
pub fn Severity::to_string(self : Severity) -> String {
  match self {
    Info => "info"
    Caution => "caution"
    Warning => "warning"
    Danger => "danger"
  }
}

///|
pub impl Show for Severity with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub fn Severity::from_string(s : String) -> Severity? {
  match s {
    "info" => Some(Info)
    "caution" => Some(Caution)
    "warning" => Some(Warning)
    "danger" => Some(Danger)
    _ => None
  }
}

///|
pub const SeverityValues : String = "info, caution, warning, danger"

///|
/// Trail-condition status (spec §4.5).
pub(all) enum TrailStatus {
  Good
  Caution
  Impassable
} derive(Eq, @debug.Debug)

///|
pub fn TrailStatus::to_string(self : TrailStatus) -> String {
  match self {
    Good => "good"
    Caution => "caution"
    Impassable => "impassable"
  }
}

///|
pub impl Show for TrailStatus with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub fn TrailStatus::from_string(s : String) -> TrailStatus? {
  match s {
    "good" => Some(Good)
    "caution" => Some(Caution)
    "impassable" => Some(Impassable)
    _ => None
  }
}

///|
pub const TrailStatusValues : String = "good, caution, impassable"

///|
/// WGS 84 coordinates in decimal degrees.
pub(all) struct GeoPoint {
  latitude : Double
  longitude : Double
} derive(Eq, @debug.Debug)

///|
pub(all) struct Track {
  url : String
  format : String
} derive(Eq, @debug.Debug)

///|
pub(all) struct Stats {
  distance_m : Double?
  ascent_m : Double?
  descent_m : Double?
} derive(Eq, @debug.Debug)

///|
/// Document-level metadata from the front matter (spec §2.2). Unknown keys are
/// kept verbatim in `extra`.
pub(all) struct Metadata {
  format_version : String?
  kind : String
  title : String
  started_at : DateTime?
  ended_at : DateTime?
  summary : String?
  track : Track?
  stats : Stats?
  tags : Array[String]
  members : Array[String]
  license : String?
  extra : Map[String, Json]
} derive(@debug.Debug)

///|
pub fn Metadata::empty() -> Metadata {
  {
    format_version: None,
    kind: "hike",
    title: "",
    started_at: None,
    ended_at: None,
    summary: None,
    track: None,
    stats: None,
    tags: [],
    members: [],
    license: None,
    extra: Map([]),
  }
}

///|
/// A run of CommonMark prose, kept as source text (ADR-0001).
pub(all) struct Markdown {
  source : String
  range : @diagnostic.Range
} derive(@debug.Debug)

///|
/// Attributes every directive shares (spec §4.2) plus the unknown ones.
pub(all) struct Common {
  id : String?
  classes : Array[String]
  extra : Map[String, String]
  range : @diagnostic.Range
} derive(@debug.Debug)

///|
pub(all) struct Waypoint {
  name : String
  location : GeoPoint?
  elevation_m : Double?
  arrived_at : DateTime?
  departed_at : DateTime?
  common : Common
  body : Array[Block]
} derive(@debug.Debug)

///|
pub(all) struct Hazard {
  severity : Severity
  location : GeoPoint?
  observed_at : DateTime?
  common : Common
  body : Array[Block]
} derive(@debug.Debug)

///|
pub(all) struct TrailCondition {
  status : TrailStatus
  section : String?
  location : GeoPoint?
  observed_at : DateTime?
  common : Common
  body : Array[Block]
} derive(@debug.Debug)

///|
/// A directive whose name this version does not define. Preserved so that
/// newer documents survive older tools (spec §4.6).
pub(all) struct UnknownDirective {
  name : String
  attributes : Map[String, String]
  common : Common
  body : Array[Block]
} derive(@debug.Debug)

///|
pub(all) enum Block {
  Markdown(Markdown)
  Waypoint(Waypoint)
  Hazard(Hazard)
  TrailCondition(TrailCondition)
  Unknown(UnknownDirective)
} derive(@debug.Debug)

///|
/// The typed hike document: the only public data model of fmfm.
pub(all) struct Document {
  metadata : Metadata
  blocks : Array[Block]
} derive(@debug.Debug)
