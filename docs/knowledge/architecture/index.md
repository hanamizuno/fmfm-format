---
type: Index
title: Architecture
description: System structure, data flow, and staged-build plans
tags: [architecture]
timestamp: 2026-10-28T00:00:00Z
---

# Architecture

Notes that explain **how the system is put together and why**. Use this directory for service topologies, data-flow diagrams, staged-build plans, and other structural decisions whose rationale is not obvious from the code.

Keep these documents complementary to the code and to `README.md` — record the *why* and the *operational implications*, not the configuration values themselves.

## Index

* [pipeline-and-packages.md](pipeline-and-packages.md) — The syntax → semantic → exporter pipeline, which package owns each stage, and the testing strategy
* [open-questions.md](open-questions.md) — Design points the brief left open, with options and the current v0.1 recommendation
