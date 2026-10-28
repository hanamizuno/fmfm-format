///|
test "analyze runs syntax and semantic stages" {
  let r = @fmfm.analyze(
    (
      #|# No front matter
      #|
      #|:::hazard{severity="warning"}
      #|Fallen tree.
      #|:::
    ),
  )
  debug_inspect(
    r.diagnostics.map(d => d.format()),
    content=(
      #|[
      #|  "<input>:1:1: error[missing-title]: title is required (add a front matter block with a title)",
      #|  "<input>:1:1: warning[missing-format]: add format: fmfm and format_version: \"0.1\" to the front matter",
      #|]
    ),
  )
  inspect(r.document.blocks.length(), content="2")
  inspect(@fmfm.FormatVersion, content="0.1")
}
