///|
/// Specification version implemented by this module (`format_version`).
pub const FormatVersion : String = "0.1"

///|
/// Result of analysing one fmfm document: the typed AST plus every syntax and
/// semantic diagnostic, in source order.
pub(all) struct Analysis {
  document : @ast.Document
  diagnostics : Array[@diagnostic.Diagnostic]
}

///|
/// Parse and validate a document whose front matter has already been decoded
/// into a [`@frontmatter.Node`] (or is absent). The front-matter YAML decoder
/// is wired in separately so that this function stays free of the YAML
/// dependency.
pub fn analyze(source : String, front_matter? : @frontmatter.Node) -> Analysis {
  let parsed = @syntax.parse(source)
  let lowered = @semantic.lower(parsed.document, front_matter?)
  let diagnostics = parsed.diagnostics + lowered.diagnostics
  { document: lowered.document, diagnostics, }
}
