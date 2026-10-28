///|
/// Escape text for an HTML text node or a double-quoted attribute value.
///
/// ```mbt check
/// test {
///   inspect(
///     @html.escape("a < b & \"c\" 'd'"),
///     content="a &lt; b &amp; &quot;c&quot; &#39;d&#39;",
///   )
/// }
/// ```
pub fn escape(s : String) -> String {
  let sb = StringBuilder(size_hint=s.length())
  for c in s {
    match c {
      '&' => sb.write_string("&amp;")
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      '"' => sb.write_string("&quot;")
      '\'' => sb.write_string("&#39;")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}
