///|
pub(all) struct LowerResult {
  document : @ast.Document
  diagnostics : Array[@diagnostic.Diagnostic]
} derive(@debug.Debug)

///|
/// Collects diagnostics while lowering.
priv struct Ctx {
  diagnostics : Array[@diagnostic.Diagnostic]
}

///|
fn Ctx::error(
  self : Ctx,
  code : String,
  message : String,
  range : @diagnostic.Range,
  suggestion? : String,
) -> Unit {
  self.diagnostics.push(
    @diagnostic.Diagnostic::error(code, message, range, suggestion?),
  )
}

///|
fn Ctx::warning(
  self : Ctx,
  code : String,
  message : String,
  range : @diagnostic.Range,
  suggestion? : String,
) -> Unit {
  self.diagnostics.push(
    @diagnostic.Diagnostic::warning(code, message, range, suggestion?),
  )
}

///|
/// Convert the syntax tree into the typed document, reporting every value
/// that does not fit the specification. `front_matter` is the decoded YAML
/// tree (absent when the file has no front matter or it failed to parse; the
/// caller reports that failure).
pub fn lower(
  raw : @syntax.RawDocument,
  front_matter? : @frontmatter.Node,
) -> LowerResult {
  let ctx = Ctx::{ diagnostics: [], }
  let doc_start = @diagnostic.Range::point({ line: 1, column: 1, offset: 0, })
  let metadata = lower_metadata(ctx, front_matter, doc_start)
  let blocks = lower_blocks(ctx, raw.blocks)
  { document: { metadata, blocks, }, diagnostics: ctx.diagnostics, }
}

///|
fn lower_blocks(ctx : Ctx, raw : Array[@syntax.RawBlock]) -> Array[@ast.Block] {
  raw.map(b => {
    match b {
      Markdown(m) => @ast.Block::Markdown({ source: m.source, range: m.range, })
      Directive(d) => lower_directive(ctx, d)
    }
  })
}
