# Claude Code Configuration

## Project Guidelines Reference

Please refer to `AGENTS.md` for comprehensive project guidelines including:

- Project structure and module organization
- Build, test, and development commands
- Coding style and naming conventions
- Testing guidelines
- Code navigation and API discovery (`moon ide` / `moon doc`)
- Commit and pull request guidelines
- Security and configuration tips

## Key Commands

- Check + test: `just`
- Format: `just fmt`
- Type check: `just check`
- Test: `just test` (update snapshots: `just test-update`)
- Regenerate interfaces: `just info`
- Local CI equivalent: `just ci` (both targets: `just ci-all`)

## Development Setup

Install the [MoonBit toolchain](https://www.moonbitlang.com/download) and [just](https://github.com/casey/just), run `moon update` once, then `just`.
