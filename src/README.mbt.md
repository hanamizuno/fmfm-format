# hanamizuno/fmfm

Parser, validator and exporters for the **fmfm** hiking-log Markdown format.
See the repository `README.md` and `docs/spec/format.md`.

## Packages

- `hanamizuno/fmfm` — facade (`analyze`)
- `hanamizuno/fmfm/diagnostic` — positions, ranges, diagnostics
- `hanamizuno/fmfm/syntax` — front matter split and `:::` directive scanner
- `hanamizuno/fmfm/frontmatter` — position-aware YAML subset tree
- `hanamizuno/fmfm/ast` — the typed document model
- `hanamizuno/fmfm/semantic` — lowering and validation
- `hanamizuno/fmfm/json` — JSON export / dump
- `hanamizuno/fmfm/html` — semantic HTML renderer
