# GitHub Copilot Instructions

See [AGENTS.md](../AGENTS.md) for the full project guidelines (structure, coding style, testing, commit and PR conventions).

## Key Commands

- Install dependencies: `moon update` (registry index) — dependencies are fetched on demand
- Check + test: `just`
- Format: `just fmt`
- Type check: `just check`
- Test: `just test`
- Update snapshot tests: `just test-update`
- Regenerate interfaces (`.mbti`): `just info`
- Format spec lives in `docs/spec/format.md` (+ `format.ja.md`); keep both in sync
