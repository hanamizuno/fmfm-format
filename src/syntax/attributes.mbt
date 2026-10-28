///|
fn is_key_start(c : Char) -> Bool {
  c.is_ascii_lowercase()
}

///|
fn is_key_char(c : Char) -> Bool {
  c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-' || c == '_'
}

///|
fn is_name_char(c : Char) -> Bool {
  c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-'
}

///|
fn is_space(c : Char) -> Bool {
  c == ' ' || c == '\t'
}

///|
/// Parse the attribute text between `{` and `}`.
///
/// `line` is the header line and `base` the UTF-16 column where `text` starts
/// on it, so that every range points into the original file. Returns the
/// attributes (first occurrence wins on duplicates) and diagnostics.
fn parse_attributes(
  line : Line,
  text : String,
  base : Int32,
  diagnostics : Array[@diagnostic.Diagnostic],
) -> Array[Attribute] {
  let attrs : Array[Attribute] = []
  let n = text.length()
  let mut i = 0
  fn at(k : Int32) -> Char? {
    if k < n {
      Some(unit(text, k))
    } else {
      None
    }
  }
  fn add(attr : Attribute) {
    let mut dup = false
    for existing in attrs {
      if existing.key == attr.key {
        dup = true
        break
      }
    }
    if dup {
      diagnostics.push(
        @diagnostic.Diagnostic::error(
          "duplicate-attribute",
          "attribute \"\{attr.key}\" is given more than once",
          attr.key_range,
        ),
      )
    } else {
      attrs.push(attr)
    }
  }
  fn add_class(
    name : String,
    key_range : @diagnostic.Range,
    value_range : @diagnostic.Range,
  ) {
    for idx, existing in attrs {
      if existing.key == "class" {
        attrs[idx] = {
          key: "class",
          value: existing.value + " " + name,
          key_range: existing.key_range,
          value_range: existing.value_range.union(value_range),
        }
        return
      }
    }
    attrs.push({ key: "class", value: name, key_range, value_range, })
  }
  while i < n {
    match at(i) {
      Some(c) if is_space(c) => i += 1
      Some('#') | Some('.') => {
        let marker = at(i).unwrap()
        let start = i
        i += 1
        let vstart = i
        while i < n && !is_space(at(i).unwrap()) && at(i) != Some('}') {
          i += 1
        }
        let value = text[vstart:i].to_owned()
        let key_range = span(line, base + start, base + start + 1)
        let value_range = span(line, base + vstart, base + i)
        if value.is_empty() {
          diagnostics.push(
            @diagnostic.Diagnostic::error(
              "invalid-attribute",
              "expected a name after \"\{marker}\"",
              key_range,
            ),
          )
        } else if marker == '#' {
          add({ key: "id", value, key_range, value_range, })
        } else {
          add_class(value, key_range, value_range)
        }
      }
      Some(c) if is_key_start(c) => {
        let kstart = i
        while i < n && is_key_char(at(i).unwrap()) {
          i += 1
        }
        let key = text[kstart:i].to_owned()
        let key_range = span(line, base + kstart, base + i)
        if at(i) != Some('=') {
          diagnostics.push(
            @diagnostic.Diagnostic::error(
              "invalid-attribute",
              "expected \"=\" after attribute \"\{key}\"",
              key_range,
              suggestion="write \{key}=\"value\"",
            ),
          )
          // Skip to the next whitespace so that one mistake yields one error.
          while i < n && !is_space(at(i).unwrap()) {
            i += 1
          }
          continue
        }
        i += 1
        let vstart = i
        match at(i) {
          Some('"') | Some('\'') => {
            let quote = at(i).unwrap()
            i += 1
            let sb = StringBuilder()
            let mut closed = false
            while i < n {
              let c = at(i).unwrap()
              if c == '\\' && i + 1 < n {
                let next = at(i + 1).unwrap()
                if next == '"' || next == '\'' || next == '\\' {
                  sb.write_char(next)
                  i += 2
                  continue
                }
              }
              if c == quote {
                closed = true
                i += 1
                break
              }
              sb.write_char(c)
              i += 1
            }
            let value_range = span(line, base + vstart, base + i)
            if !closed {
              diagnostics.push(
                @diagnostic.Diagnostic::error(
                  "invalid-attribute",
                  "unterminated quoted value for attribute \"\{key}\"",
                  value_range,
                ),
              )
            }
            add({ key, value: sb.to_string(), key_range, value_range, })
          }
          _ => {
            while i < n {
              let c = at(i).unwrap()
              if is_space(c) || c == '}' || c == '"' || c == '\'' {
                break
              }
              i += 1
            }
            let value = text[vstart:i].to_owned()
            let value_range = span(line, base + vstart, base + i)
            if value.is_empty() {
              diagnostics.push(
                @diagnostic.Diagnostic::error(
                  "invalid-attribute",
                  "attribute \"\{key}\" has no value",
                  key_range,
                ),
              )
            } else {
              add({ key, value, key_range, value_range, })
            }
            if at(i) == Some('"') || at(i) == Some('\'') {
              diagnostics.push(
                @diagnostic.Diagnostic::error(
                  "invalid-attribute",
                  "unexpected quote inside the bare value of \"\{key}\"",
                  span(line, base + i, base + i + 1),
                ),
              )
              i += 1
            }
          }
        }
      }
      Some(_) => {
        let start = i
        while i < n && !is_space(at(i).unwrap()) {
          i += 1
        }
        let junk = text[start:i].to_owned()
        diagnostics.push(
          @diagnostic.Diagnostic::error(
            "invalid-attribute",
            "unexpected \"\{junk}\" in attribute list (keys are lower-case: key=\"value\")",
            span(line, base + start, base + i),
          ),
        )
      }
      None => break
    }
  }
  attrs
}
