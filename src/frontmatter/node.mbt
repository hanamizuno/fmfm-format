///|
/// A position-aware tree for the admitted YAML subset (ADR-0004). Every scalar
/// is a string; typing is the semantic stage's job.
pub(all) enum Node {
  Scalar(String, @diagnostic.Range)
  Sequence(Array[Node], @diagnostic.Range)
  Mapping(Array[Entry], @diagnostic.Range)
} derive(@debug.Debug)

///|
pub(all) struct Entry {
  key : String
  key_range : @diagnostic.Range
  value : Node
} derive(@debug.Debug)

///|
pub fn Node::range(self : Node) -> @diagnostic.Range {
  match self {
    Scalar(_, r) | Sequence(_, r) | Mapping(_, r) => r
  }
}

///|
/// First entry with this key, when the node is a mapping.
pub fn Node::get(self : Node, key : String) -> Entry? {
  match self {
    Mapping(entries, _) => {
      for e in entries {
        if e.key == key {
          return Some(e)
        }
      }
      None
    }
    _ => None
  }
}

///|
/// Lossy conversion for `extra` fields: scalars stay strings, structure is kept.
pub fn Node::to_json(self : Node) -> Json {
  match self {
    Scalar(s, _) => Json::string(s)
    Sequence(items, _) => Json::array(items.map(Node::to_json))
    Mapping(entries, _) => {
      let m : Map[String, Json] = Map([])
      for e in entries {
        m[e.key] = e.value.to_json()
      }
      Json::object(m)
    }
  }
}

///|
/// Build a tree from JSON, giving every node the same `range`. Intended for
/// tests and for callers that already hold decoded data; the YAML reader
/// produces real positions.
pub fn Node::from_json(json : Json, range : @diagnostic.Range) -> Node {
  match json {
    Object(fields) => {
      let entries : Array[Entry] = []
      for k, v in fields {
        entries.push({
          key: k,
          key_range: range,
          value: Node::from_json(v, range),
        })
      }
      Mapping(entries, range)
    }
    Array(items) => Sequence(items.map(v => Node::from_json(v, range)), range)
    String(s) => Scalar(s, range)
    Number(_, repr~) =>
      Scalar(
        match repr {
          Some(r) => r
          None => json.stringify()
        },
        range,
      )
    True => Scalar("true", range)
    False => Scalar("false", range)
    Null => Scalar("", range)
  }
}
