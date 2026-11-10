# Implementation Summary: Task #496

- **Task**: 496 - Add per-repo storage and injection to the sapience extension
- **Status**: [COMPLETED]
- **Started**: 2026-11-10T08:15:00Z
- **Completed**: 2026-11-10T09:50:00Z
- **Effort**: ~1.5 hours of active work (interleaved with long verification waits: two full
  `verify-deploy.sh` battery runs plus two `deploy-headless.sh` redeploys, each 8-15 minutes)
- **Dependencies**: 360, 449, 450, 487, 488 (all `completed`)
- **Artifacts**: plans/01_sapience-per-repo-storage-injection.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Gave the sapience extension repo-scoped knowledge storage and per-dispatch context injection,
replacing the local memory extension's injection role in core's dispatch builder. Two new
scripts (`sapience-retrieve.sh`, `sapience-remember.sh`) implement a repo-tag-filtered read and
an `explicit: true` write against the hosted vault; the dispatch call site now injects from
Sapience instead of the local `.memory/` vault; the extension's own design record was amended to
stop contradicting the shipped mechanism, and the three known hazards (no delete API, unreviewed
permanent writes, two differently-shaped vault populations) are documented.

## What Changed

- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` — new file. Repo-filtered
  `GET /v1/search?source=[repo:<slug>]` read, reusing `memory-retrieve.sh`'s keyword-extraction
  stage and token budget/entry cap, emitting the same `<memory-context>` envelope shape.
- `agent-system/extensions/sapience/scripts/sapience-remember.sh` — new file. Repo-tagged,
  unconditional `explicit: true` write via `POST /ingest-kos`, treating `gated >= 1`, a non-empty
  `set_aside`, or `written == 0` as a loud, non-zero-exit failure rather than a silent success.
- `agent-system/extensions/sapience/manifest.json` — both scripts declared in `provides.scripts`.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — the Stage 3.5
  `memory_context` call-site basename swapped from `memory-retrieve.sh` to
  `sapience-retrieve.sh`; the `--clean` guard, failure-swallowing wrapper, variable name, and
  argument list are byte-identical to before.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` and
  `test-orchestrate-context-growth.sh` — the fixture stub installed by both suites renamed to
  `sapience-retrieve.sh` (the second site was discovered via the plan's own Scope Hypothesis
  grep, not originally named).
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` — new
  file documenting the scoping mechanism, both scripts' contracts, and the three hazards.
- `agent-system/extensions/sapience/context/project/sapience/domain/subagent-orientation.md` —
  item 3 of "The Deliberate Alternative" replaced with the accepted position via a dated
  `**Amended by**` cross-document note.
- `agent-system/extensions/sapience/context/project/sapience/domain/vault-model.md` — its own
  independent "no per-dispatch, shell-invoked retrieval mechanism exists" claim corrected (a
  second contradiction site the Scope Hypothesis's narrower grep missed).
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md` —
  added a subsection noting `sapience-remember.sh` bypasses the same `auto_approve: false` gate
  the four MCP write tools bypass.
- `agent-system/extensions/sapience/context/project/sapience/README.md`,
  `agent-system/extensions/sapience/index-entries.json`,
  `agent-system/extensions/sapience/EXTENSION.md` — navigation/index/pointer updates for the new
  domain file and the two scripts.

## Decisions

- Per-repo scoping works only through a literal `[repo:<slug>]` tag in a KO's `provenance`
  string, filtered on read by `source=`; `project=` and `source_loc` are both dead ends on this
  vault. This was settled by prior research and re-confirmed live during Phase 4.
- `sapience-remember.sh` is not wired into any call site by this task. Its sanctioned call site
  (task-boundary postflight, a bounded 3-8-note set) is documented but not implemented here.
- The host/token/slug resolution logic is deliberately duplicated between the two scripts rather
  than factored into a shared `scripts/lib/` helper, to avoid adding a path outside this task's
  declared `file_scope`.

## Plan Deviations

- **Phase 1/2**: deep invocation verification (real curl calls, `--dry-run` JSON shape) is
  structurally deferred to Phase 4's post-deploy checks, since both scripts source `lib/common.sh`
  relative to their own `SCRIPT_DIR`, which exists only in the deployed `.claude/scripts/` tree.
- **Phase 3/4/6/7 verification**: `bash .claude/scripts/verify-deploy.sh`'s "complete gate set
  exits 0" criterion could not be satisfied cleanly pre-deploy (gate 5 correctly flagged the
  manifest declaring scripts not yet deployed — expected, resolved by Phase 4's redeploy) and,
  even post-deploy, 6-7 of ~41-42 checks fail identically at every full-battery run across this
  dispatch: gate3/4/10 60s timeouts, gate8 (`run-all.sh`) failing/undiscoverable suites, gate20
  eager-load budget, gate22 shellcheck (3 findings, none in this task's two new scripts — directly
  confirmed), gate24 dead-command-recommendation (no "sapience" match — directly confirmed). Gate
  5 passes at every post-deploy run. This task's own Phase 5 nine-suite and Phase 6 five-suite
  `run-all.sh --only` subsets, covering every file this task actually touched, are 100% green at
  every run. Task 476 ("isolate seven RED gate8 shell suites") independently tracks this repo's
  known baseline gate8-adjacent red state, corroborating that the remaining failures are
  pre-existing and out of this task's scope.
- **Phase 5 Scope Hypothesis**: the plan assumed one stub-installation site in the test suite;
  `grep -rn 'memory-retrieve'` surfaced a second (`test-orchestrate-context-growth.sh`), renamed
  the same way and re-verified green.
- **Phase 6 Scope Hypothesis**: the plan assumed `subagent-orientation.md` was the sole
  contradicting file; `vault-model.md` independently carried the same claim in different words
  and was amended too.
- **Testing & Validation**: the `set_aside` silent-loss response shape was verified by code
  review only (branch order matches the vendor client, confirmed by direct reading), not by a
  live server response — no reliable way to deliberately provoke that specific noise-gate
  outcome (distinct from `gated`) was found during verification.

## Verification

- Build: N/A (shell scripts, no compile step)
- Tests: `shellcheck` clean on both new scripts; Phase 5's nine-suite and Phase 6's five-suite
  `run-all.sh --only` subsets both 100% green; `sync-manifest-scripts.sh --check` exits 0
- Live round trip: V2 write (`written=1`, hash `aeea7c9425b7ffb2`), V3a matching-filter read
  found it, V3b non-matching-filter read did not (vault holds 2163 objects overall), V4 gated
  write correctly surfaced as a loud failure (exit 2) via a temporarily-patched, diff-confirmed
  reverted local copy
- Degradation: V5 (unreachable host, 0.19s elapsed, dispatch built, no `<memory-context>` block),
  V6 (`--clean` still suppresses with a reachable host), V7 (envelope structurally identical to
  `memory-retrieve.sh`'s — same tags, preamble, heading form, blank-line separation)
- Files verified: Yes — all 13 touched files confirmed present with the expected content

## Impacts

- Every `/orchestrate` dispatch's Stage 3.5 `memory_context` block now performs a network
  round-trip to the hosted Sapience vault instead of a local `.memory/memory-index.json` lookup,
  bounded by `--connect-timeout 3 --max-time 8` and degrading to no injection on any failure.
- `memory-retrieve.sh` and `.memory/` remain on disk and deployed, unused by this call site but
  available as a rollback path until a separate record retires them.
- This is the dependency root of the broader sapience migration strand (`specs/ROADMAP.md`'s
  "nine waves deep" tracking); task `499` (retiring the memory extension) can now proceed.

## Follow-ups

- Manual app.spnc.ai cleanup item (no delete API exists): KO hashes `806180dc43c5cb34` and
  `9ba2b479b5e4a7e2` (orphaned research probes from the prior research phase), plus
  `aeea7c9425b7ffb2` (this task's own Phase 4 V2 write — a genuinely useful note, not a throwaway
  probe, so removal is optional, recorded for completeness).
- `sapience-remember.sh` is built but not wired into any call site; a future record would add the
  task-boundary postflight call this task documents but does not implement.
- The two-population asymmetry (repo-tagged live writes vs. untagged transcript-extraction
  writes) is documented as a deliberate, unfixed design tradeoff, not a defect.
- The pre-existing gate3/4/8/10/20/22/24 baseline failures observed throughout this dispatch are
  out of this task's scope; task 476 already tracks the gate8-adjacent subset.

## References

- `specs/496_sapience_per_repo_storage_and_injection/plans/01_sapience-per-repo-storage-injection.md`
- `specs/496_sapience_per_repo_storage_and_injection/reports/01_sapience-per-repo-storage-injection.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
