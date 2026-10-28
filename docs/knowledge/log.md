# Knowledge Bundle Update Log

## 2026-10-20

* **Update**: [research/sbx-verification.md](/docs/knowledge/research/sbx-verification.md) — results of running the kit in a real sandbox (`just ci-all` passes; the CloudFront redirect host was missing from the allowlist); the Dev Container removal criteria are resolved.
* **Update**: [runbooks/agent-sandbox-sbx.md](/docs/knowledge/runbooks/agent-sandbox-sbx.md) — sbx is now the only agent runtime; Dev Container / pass-cli comparisons removed, GitHub PAT scope guidance moved in.

## 2026-09-17

* **Add**: [runbooks/agent-sandbox-sbx.md](/docs/knowledge/runbooks/agent-sandbox-sbx.md) — operating procedure for the Docker Sandboxes (sbx) kits in `.sandbox/`.
* **Add**: [research/sbx-verification.md](/docs/knowledge/research/sbx-verification.md) — verification status of those kits (ported from a sibling template; the MoonBit-specific steps are not yet run on a real sbx host) and the host trial checklist.

## 2026-07-09

* **Bootstrap**: Created `docs/knowledge/` as an OKF v0.1 bundle skeleton.
* **Sample**: Seeded one example document per subdirectory to demonstrate the expected shape. Replace them as real knowledge is added.
  * [architecture/sample-service-overview.md](/docs/knowledge/architecture/sample-service-overview.md)
  * [adr/0001-sample-decision.md](/docs/knowledge/adr/0001-sample-decision.md)
  * [conventions/sample-convention.md](/docs/knowledge/conventions/sample-convention.md)
  * [runbooks/sample-runbook.md](/docs/knowledge/runbooks/sample-runbook.md)
  * [research/sample-research.md](/docs/knowledge/research/sample-research.md)

<!--
Going forward, append entries here when you add, move, or retire a document, or
when a decision in this bundle changes status. Group entries under an ISO date
heading (`## YYYY-MM-DD`). Keep each bullet terse and link to the concrete file.
-->
