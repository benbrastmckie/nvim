# Research Report: Task #305

**Task**: 305 - Trim agent-system/extensions/core/commands/orchestrate.md below its 21,000 B ceiling, then promote ORCHESTRATOR_BUDGET_GATE_MODE from warn to hard
**Started**: 2026-10-01
**Completed**: 2026-10-01
**Effort**: small (documentation restatement trim + one env-var default flip)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/commands/orchestrate.md` (source store, the file to trim)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (the non-eager destination the duplicated content already exists in)
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` (ceiling/derivation record)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (Gate 20, `ORCHESTRATOR_BUDGET_GATE_MODE` default)
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` (13-case suite; actually ran it)
- `specs/ROADMAP.md` (status table referencing this overage)
**Artifacts**:
- This report: `specs/305_trim_orchestrate_md_and_promote_budget_gate/reports/01_trim-orchestrate-md-budget-gate.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `agent-system/extensions/core/commands/orchestrate.md` is 21,328 B, 328 B over its 21,000 B
  ceiling. The remedy named in both `orchestrator-context-budget.json`'s derivation and
  `specs/ROADMAP.md`'s status row is a **restatement trim**: the Options table's
  `--fast`/`--research`/`--plan`/`--implement` rows and the forced-phase bullet in the
  Constraints section duplicate content that already lives, in full and in greater detail, in
  `docs/architecture/orchestrate-state-machine.md` (verified below, section by section).
- A concrete trimmed version of those five spots was drafted and byte-measured: it reclaims
  roughly 2,300 B (table rows: 3,207 B -> ~1,125 B; Constraints bullet: 896 B -> ~674 B),
  landing the file near **19,000 B** — well under both the 21,000 B ceiling and the
  constraint-mandated ~20,500 B headroom target, consistent with constraint (d)'s concern that
  this file has been pushed over ceiling by sibling commits three times.
- The `ORCHESTRATOR_BUDGET_GATE_MODE` default flip is a single line in `verify-deploy.sh`
  (`ORCHESTRATOR_BUDGET_GATE_MODE="${ORCHESTRATOR_BUDGET_GATE_MODE:-warn}"` -> `:-hard`), plus
  its preceding dated comment block, which currently narrates the deferred 2026-10-01 promotion
  attempt and should be updated to narrate the successful one.
- The 13-case test suite (`test-verify-deploy-context-budget.sh`) does **not** need code changes:
  every case sets `ORCHESTRATOR_BUDGET_GATE_MODE` explicitly per-case via fixtures built with
  `pad_file`, independent of the script's own default. I ran the suite against the current
  (untrimmed, still-over-ceiling) repo: **14 passed, 1 failed** — the one failure is the
  `baseline fixture is clean` check, and it is NOT actually about the 328 B overage (that
  overage alone only produces a `warn()`-tier finding, which never flips exit code). It is
  caused by **unrelated, pre-existing FAILs** when the suite runs the full 20-gate battery over
  a copy of the real repo — confirmed by direct re-run below.

## Context & Scope

Researched: (1) what exactly duplicates `docs/architecture/orchestrate-state-machine.md` in
`commands/orchestrate.md`'s Options table and Constraints section, with byte-level sizing of a
candidate trim; (2) the exact code location and mechanics of the
`ORCHESTRATOR_BUDGET_GATE_MODE` promotion; (3) whether the test suite depends on the real file's
current size or the env var's default (it does not — confirmed by reading and running it); (4)
what else in the repo references this overage and may need a follow-up update (ROADMAP.md,
the config file's own narrative fields).

Out of scope per the dispatch: moving `ceiling_bytes`/`baseline_bytes`; the ~10 KB STAGE 0 bash
block (code, not documentation); anything beyond this one file and the gate-mode flip.

## Findings

### Codebase Patterns

**File measurement** (confirmed directly):
```
$ wc -c agent-system/extensions/core/commands/orchestrate.md
21328
```

**The four Options-table rows named in the task description** (`grep -n` line numbers in the
current file):
- Line 53, `--fast` row: 668 B
- Line 59, `--research` row: 981 B
- Line 60, `--plan` row: 706 B
- Line 61, `--implement` row: 852 B
- **Subtotal: 3,207 B**

**The forced-phase Constraints bullet** (lines 28–37, the `--research`/`--plan`/`--implement`
bullet immediately after the "dependency-aware wave dispatch" bullet): **896 B**.

**Verified duplication target**: every clause in these five spots already exists, in more detail,
in `docs/architecture/orchestrate-state-machine.md`:
- The `--fast`/`needs_research` content is covered by that doc's `## The \`needs_research\` Fork
  (the \`--fast\` Escape Hatch)` section (line 75).
- The artifact-keyed admission rules (`--plan` always admitted via reviser-agent/planner-agent;
  `--implement` only when a plan exists) are covered verbatim, with MORE precision, in `###
  Forced Phases on a Terminal or Archived Task` (line 752): "`--research` is always admitted
  regardless of task state. `--plan` is always admitted too, but resolves to one of two agents
  depending on artifact state... `--implement` is admitted ONLY when a plan artifact already
  exists..."
- The terminal/archived-task status-preservation behavior (never regresses `completed`/
  `abandoned`/`expanded`) is covered by the same section's "Status is never regressed" paragraph,
  with implementation detail (the `monotonic-max` clamp) that `commands/orchestrate.md` does not
  even attempt to restate.
- The "stops once its own forced sequence is exhausted for the rest of this run" behavior
  (currently in the Constraints bullet) is the exact scenario documented, with a full worked
  example, in that same doc's second "Worked example (NON-terminal task, forced, SAME run)"
  block — the "observed live incident this fix closes" — which is strictly more authoritative
  than the one-sentence restatement in `commands/orchestrate.md`.
- The `Dependency Gating Model` section (line 720) independently covers the eligibility-exemption
  mechanics ("A terminal task with a pending forced phase is admitted to `eligible_tasks`
  exactly as if it were non-terminal...").

One asymmetry to fix as part of the edit: `docs/architecture/orchestrate-state-machine.md`
currently says *"see `commands/orchestrate.md`'s Options table for the full per-flag wording"*
(line 754) and again *"See `commands/orchestrate.md`'s Options table for the full per-flag
wording"* (line 767) — i.e. it currently treats `commands/orchestrate.md` as the authoritative
long-form source. After the trim, `commands/orchestrate.md` will be the short pointer and
`orchestrate-state-machine.md` will be the long-form source, so these two backward-pointing
sentences should be dropped or reworded (they would otherwise point a reader at a now-short
summary expecting "full" wording). This is a small, in-scope cleanup alongside the trim — both
files live under the same source-store tree and the task's constraint (b) ("verify every
relocated clause is present in its non-eager destination before cutting the eager copy") is about
content presence, not about leaving a stale cross-reference.

**Drafted replacement text, byte-measured** (not applied — this is a research dispatch):

Options table rows (table syntax preserved, each `| flag | description | false |`):
```
| `--fast` | Low-effort mode: lighter reasoning, AND skips the default research-first phase for a `not_started` task (planner can still route back via `needs_research`); `--research` still forces research even under `--fast`. See `docs/architecture/orchestrate-state-machine.md`'s "The `needs_research` Fork" | false |
| `--research` | Force a research round, including on a TERMINAL/archived task; composable with `--plan`/`--implement` in canonical order; never regresses status. See `docs/architecture/orchestrate-state-machine.md`'s "Forced Phases on a Terminal or Archived Task" for the full per-flag contract (admission rules, status preservation, archived-task directory resolution) | false |
| `--plan` | Force a plan round on the same terms as `--research` above. Always admitted: dispatches `reviser-agent` when a plan already exists, `planner-agent` otherwise. See the same doc section | false |
| `--implement` | Force an implement round on the same terms as `--research` above. Admitted only when a plan artifact exists, else blocked with "no plan artifact; run --plan first". See the same doc section | false |
```
Measured: **1,125 B** (vs. 3,207 B original — saves ~2,082 B).

Constraints bullet:
```
- `--research`/`--plan`/`--implement` (phase-forcing flags): honored uniformly across every
  task_number in multi-task mode too, via `scripts/orchestrate-cycle-plan.sh`'s `--force-phases`.
  Each task stops (never falls through to ordinary status-derived classification) once its own
  forced sequence is exhausted for the rest of this run; re-invoke `/orchestrate` to continue.
  Admission is artifact-keyed, not status-keyed (`--plan` always admitted; `--implement` only
  when a plan artifact exists). See `docs/architecture/orchestrate-state-machine.md`'s "Forced
  Phases on a Terminal or Archived Task" and "Dependency Gating Model" sections for the full
  contract.
```
Measured: **674 B** (vs. 896 B original — saves ~222 B).

**Combined estimated savings: ~2,304 B**, landing the file at roughly **19,024 B** — comfortably
under both the 21,000 B ceiling and the ~20,500 B headroom target named in the task description.
(A future implementer should re-measure with `wc -c` after the actual edit, not trust this
estimate as exact — markdown table row wrapping/line endings can shift it by a few bytes.)

### `ORCHESTRATOR_BUDGET_GATE_MODE` promotion mechanics

Single line in `agent-system/extensions/core/scripts/verify-deploy.sh` (line 192):
```bash
ORCHESTRATOR_BUDGET_GATE_MODE="${ORCHESTRATOR_BUDGET_GATE_MODE:-warn}"
```
changes to `:-hard`. Preceded by a dated comment block (lines 179–191) that currently narrates
the 2026-10-01 deferred-promotion story ("Promotion is deferred again until
commands/orchestrate.md is back under ceiling") — this should be updated to a dated note
recording the successful promotion, per this codebase's convention of narrating ceiling/mode
history inline (seen identically in `orchestrator-context-budget.json`'s `_comment` and
per-file `derivation` fields).

Gate 20's per-file ceiling sub-check (around line 1045–1075) uses `fail()` when
`ORCHESTRATOR_BUDGET_GATE_MODE=hard` and `warn()` otherwise — `warn()` increments `CHECKS` but
never `FAILURES`, so a warn-tier ceiling breach never flips the script's exit code; only
`hard` mode does. This matters for interpreting the test run below.

### Test suite: already verified to not depend on the real file's current size

I ran `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` against
the current (untrimmed) repo:
```
[FAIL] baseline fixture is not clean (rc=1, gate20 finding lines=1) -- fixture setup is broken; later cases are unreliable
[PASS] case1 … case2 … case5 … case3 … case4 …
14 passed, 1 failed
```
Reading the suite confirms every other case (`run_gate20 hard`, `run_gate20 warn`, pad_file
mutations) sets `ORCHESTRATOR_BUDGET_GATE_MODE` explicitly per-case against a synthetically
padded fixture file, completely independent of the real file's current size or the script's
default — so **no test-suite code changes are needed** for either the trim or the mode-default
flip. The only case affected by the real file's state is the "baseline fixture is clean" check,
which already tolerates "at most one pre-existing per-file ceiling WARN" (`-le 1` on
`gate20_lines`) and will see 0 such lines once the file is back under ceiling.

**Important for the implementer**: the baseline failure above is NOT caused by the 328 B
overage. I confirmed this by running `verify-deploy.sh --findings` directly over the real repo
(not the fixture) and found these FINDINGs, none touching gate20 except the one expected line:
```
FINDING gate16 lean still declares routing_hard/routing_agents_hard
FINDING gate20 orchestrator context budget: commands/orchestrate.md over ceiling   <- the only relevant one
FINDING gate3 [lean] FAIL: Rule R: index-entries.json entry 'project/lean4/README.md' line_count mismatch …
FINDING gate5 core: Content differs from source: context/contracts/adversarial-verification.md
FINDING gate5 core: Content differs from source: context/contracts/anti-analysis.md
FINDING gate5 core: Content differs from source: context/contracts/reference-grounding.md
FINDING gate5 lean: Content differs from source: context/project/lean4/README.md
FINDING gate5 lean: Missing context: project/lean4/domain/metadata-trust-surfaces.md
```
All of the gate3/gate5/gate16 findings are **pre-existing lean-extension deploy staleness**,
exactly the condition this dispatch's own `<deploy-freshness-context>` block already warns about
("this repo's deployed .claude/ tree is STALE relative to the source store... for: lean"). They
are unrelated to task 305 and out of scope. The implementer should verify success narrowly —
`grep gate20` on a `--only-gate 20` run, or the suite's per-case asserts — rather than expecting
a totally clean full-battery `verify-deploy.sh` run, which currently fails for unrelated reasons
documented in `specs/ROADMAP.md`'s own status table ("`verify-deploy.sh` | **FAIL — 3 of 33**").

### External Resources

None needed; this is a self-contained in-repo documentation/config change.

## Recommendations

1. **Trim `commands/orchestrate.md`** at the five spots identified above (Options table's
   `--fast`/`--research`/`--plan`/`--implement` rows; the forced-phase Constraints bullet),
   replacing restated detail with the short summaries drafted above plus a pointer to
   `docs/architecture/orchestrate-state-machine.md`'s relevant sections. Re-measure with `wc -c`
   after editing to confirm landing near the ~19,000–20,500 B target, not just under 21,000 B,
   per constraint (d)'s headroom concern.
2. **Fix the two now-backward cross-references** in
   `docs/architecture/orchestrate-state-machine.md` (lines ~754 and ~767, "See
   `commands/orchestrate.md`'s Options table for the full per-flag wording") — after the trim
   those sentences point at a short summary, not "full" wording; drop them or reword to make
   `orchestrate-state-machine.md` self-sufficient as the long-form source.
3. **Flip `ORCHESTRATOR_BUDGET_GATE_MODE` default** to `hard` in `verify-deploy.sh` line 192,
   and update the preceding dated comment block to narrate the successful promotion (matching
   this repo's convention of inline dated history, as already done in
   `orchestrator-context-budget.json`).
4. **Refresh `orchestrator-context-budget.json`**'s `commands/orchestrate.md` entry
   (`measured_bytes`, `measured_at`, and `derivation` narrative) to record the trim and the
   successful promotion — the file's own `_comment` explicitly says `measured_bytes`/
   `measured_at` "may be refreshed freely," and constraint (a) only forbids moving
   `ceiling_bytes`/`baseline_bytes`, not updating the narrative/measurement fields.
5. **Update `specs/ROADMAP.md`'s status table row** for `commands/orchestrate.md` (currently
   reads "328 B OVER (new)... blocks promoting `ORCHESTRATOR_BUDGET_GATE_MODE` to `hard`") to
   reflect the closed state, consistent with how the adjacent eager-load and SKILL.md rows in
   that same table already narrate their own closures.
6. **Verify narrowly, not via a full clean `verify-deploy.sh` run**: run the 13-case test suite
   (expect 15/15 once the trim lands and removes the one pre-existing baseline WARN) and a
   `--only-gate 20` run over the real repo to confirm the gate20 FINDING disappears. Do not
   expect or chase a fully clean full-battery run — the gate3/gate5/gate16 lean-staleness
   findings are pre-existing and out of scope (see Findings above); conflating them with this
   task's verification would be a scope error.

## Decisions

- The restatement-trim approach (shrink `commands/orchestrate.md`'s duplicated detail to a
  pointer, keep `docs/architecture/orchestrate-state-machine.md` as the authoritative long-form
  source) is confirmed as both sufficient and already-verified-safe: every clause slated for
  removal is already present, often in greater and more precise detail, in the non-eager
  destination. No new content needs to be written into the destination file before cutting the
  eager copy — constraint (b) is already satisfied by the status quo; only the two backward
  cross-references need fixing.
- No ceiling or baseline move is needed or recommended; the drafted trim alone clears the task's
  own ~20,500 B headroom target with margin to spare, so there is no pressure to also revisit
  `ceiling_bytes`.
- The test suite requires no code changes — verified by direct execution, not just by reading.

## Risks & Mitigations

- **Risk**: an implementer might try to make `verify-deploy.sh --findings` on the real repo
  fully clean before declaring success, chasing the unrelated lean-staleness findings
  (gate3/gate5/gate16). **Mitigation**: documented explicitly above and in Recommendation 6 —
  verify narrowly (gate20 only / the test suite), consistent with the dispatch's own
  `<deploy-freshness-context>` note that these are pre-existing and out of scope.
- **Risk**: trimming too aggressively could drop a clause not actually present in the
  destination doc, silently losing information. **Mitigation**: this report cross-references
  every clause in the current Options rows/Constraints bullet against specific named sections
  and even specific sentences in `orchestrate-state-machine.md` (see Findings); the implementer
  should do a final read-through diff against those same anchors before cutting.
- **Risk**: re-trimming again pushes the file to a razor-thin margin like `skill-orchestrate/
  SKILL.md`'s current 7 B-under-ceiling state (noted in `orchestrator-context-budget.json`'s
  derivation as fragile). **Mitigation**: the drafted trim already targets ~19,000 B, well
  below the ~20,500 B headroom floor the task asks for, specifically to avoid repeating that
  fragility — this is constraint (d)'s explicit concern given the file's 3-times-over-ceiling
  growth history.

## Context Extension Recommendations

None — this is a self-contained, already-well-documented config/doc trim with no new pattern or
undocumented topic to capture.

## Appendix

- Searches/commands run: `wc -c` on the target file and each candidate row/bullet; `grep -n` for
  `ORCHESTRATOR_BUDGET_GATE_MODE` across `scripts/`/`docs/`; `grep -n '^#|^##'` for section maps
  of both `commands/orchestrate.md` and `docs/architecture/orchestrate-state-machine.md`; a full
  run of `test-verify-deploy-context-budget.sh` against the real repo; a direct `--findings` run
  of `verify-deploy.sh --skip-slow` over the real repo to separate in-scope from pre-existing
  findings.
- References: `agent-system/extensions/core/commands/orchestrate.md`,
  `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`,
  `agent-system/extensions/core/context/config/orchestrator-context-budget.json`,
  `agent-system/extensions/core/scripts/verify-deploy.sh`,
  `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`,
  `specs/ROADMAP.md`.
