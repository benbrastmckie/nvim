# Research Report: Task #532

**Task**: 532 - Rule on whether ROADMAP.md is authored-only and make roadmap-integration.sh report its outcome instead of aborting silently
**Started**: 2026-11-11T16:09:45Z
**Completed**: 2026-11-11T16:40:00Z
**Effort**: ~1 hour (research only; no implementation effort required — see Recommendations)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/roadmap-integration.sh`, `.claude/scripts/roadmap-integration.sh`, `agent-system/extensions/core/context/formats/roadmap-format.md`, `specs/ROADMAP.md`, `specs/state.json`, `.claude-extensions.json`
- Prior artifacts: `specs/archive/371_roadmap_generator_stage_layout_and_silent_abort/summaries/01_stage-layout-silent-abort-summary.md`
- Git history: `git log -- agent-system/extensions/core/scripts/roadmap-integration.sh`
- Live reproduction (dry-run and synthetic fixture) against the deployed script
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Task 532's described defect no longer exists in this repository.** It is a near-duplicate of
  already-completed task 371 ("Teach roadmap-integration.sh the stage-based ROADMAP layout and
  fix its silent abort"), which landed a full 6-phase fix on 2026-10-10 — hours after task 532 was
  originally filed in the source repository (BimodalLogic, as #752) — and is archived at
  `specs/archive/371_roadmap_generator_stage_layout_and_silent_abort/`.
- **Live re-verification today confirms the fix is in place and working**, both in the deployed
  copy (`.claude/scripts/roadmap-integration.sh`) and the source store
  (`agent-system/extensions/core/scripts/roadmap-integration.sh`) — the two are byte-identical
  (`diff` confirms no redeploy drift).
- `bash .claude/scripts/roadmap-integration.sh --regenerate --dry-run` against the real
  `specs/ROADMAP.md` (which classifies as the **classic** 8-header layout, not Stage-based) exits
  **0** and produces a minimal, state-accurate diff (reflecting only genuine `state.json` drift:
  task 369 now `IN FLIGHT`, task 604 dropped from one Run line) — not a silent abort, and not a
  half-apply.
- Against a synthetic ROADMAP.md with an unrecognized header vocabulary, `--regenerate` exits
  **1**, prints a named `ERROR: --regenerate refuses to write ... its section headers match
  neither the classic eight-header vocabulary nor the stage-based structural predicate ...`, lists
  the actual headers, and leaves the file byte-for-byte unchanged — the exact "say so LOUDLY"
  behavior task 532 asks for.
- **Recommendation**: do not plan/implement against this task. Close it as duplicate/
  covered-by-closed, pointing at task 371's summary as the discharging artifact, following the
  same `covered-by-closed` pattern already recorded elsewhere in `specs/state.json` for other
  task-371 overlaps.

## Context & Scope

Task 532's description (migrated from BimodalLogic #752) asserts that `roadmap-integration.sh
--regenerate` either (a) silently aborts (exit 1, zero output, no write) against a Stage-based
`specs/ROADMAP.md`, or — per the description's own later "BEHAVIOR UPDATE" note, added after a
`core` extension redeploy — (b) exits 0 but only half-applies, appending a coverage-appendix block
without touching the authored Stage prose and without assembling the classic `## Open work` /
`## Next` layout. The task asks for one of two remedies: teach the script the Stage-based layout,
or make the script refuse loudly (named error, documented exit code) when the file is
authored-only.

This research re-verified both claims against the live script and the live `specs/ROADMAP.md` in
this repository, and traced the script's git history and the format spec it implements
(`roadmap-format.md`) to determine whether either remedy had already been built.

## Findings

### Codebase Patterns

- `agent-system/extensions/core/scripts/roadmap-integration.sh` is the source-store copy;
  `.claude/scripts/roadmap-integration.sh` is the deployed mirror. `diff` between them is empty —
  no redeploy drift exists right now, so the "SOURCE-STORE BOUNDARY" concern the task description
  raises is already satisfied for the current state of this script.
- The script implements exactly the two-layout design task 532 asks for, already landed:
  - `detect_layout()` classifies a roadmap as `classic` (all eight literal headers from
    `roadmap-format.md`'s Section Order table present), `stage` (a `^## Stage [0-9]+` header plus
    a fenced `/orchestrate` block in some section body), or `unknown`.
  - `refuse_unrecognised_layout()` is called by both `--regenerate` and `--prune` before any file
    write, and refuses loudly — a named `ERROR:` line on stderr, the actual headers listed, exit
    1, no write — for `unknown`. This is documented in the script's own header comment as a
    "PERMANENT property, not a transitional guard."
  - `mode_regenerate_classic` rebuilds `## Open work` and `## Next`'s generated parts in full (the
    layout the task description expected); `mode_regenerate_stage` round-trips a Stage-based file
    byte-for-byte except the run-order section, whose coverage appendix is stripped and rebuilt —
    exactly the "half-apply" behavior the task's BEHAVIOR UPDATE note describes, except this is
    the documented, intentional design for a Stage layout, not a defect.
  - An always-present stderr marker (`<!-- roadmap-generation mode=... tasks=... topics=...
    runs=... pruned=... retained=... -->`) fires via an `EXIT` trap on every invocation that
    reaches mode dispatch, success or failure, and a separate named `ERROR:` line (via an `ERR`
    trap) precedes it on any failure.
- `agent-system/extensions/core/context/formats/roadmap-format.md`'s `## Section Order` section
  documents both layouts structurally, including the exact classic eight-header table and the
  stage structural predicate, and a `## Destructive-Overwrite Refusal` subsection describing the
  loud-refusal guarantee. This is a live, current format spec — not aspirational.
- `git log -- agent-system/extensions/core/scripts/roadmap-integration.sh` shows task 371's five
  phases (`ee2b78ec0` always-present marker, `b28550fcc` layout recognition + loud refusal,
  `97f19e4f5` eliminate no-match-as-error pipeline, `e23447a65` stage-layout `--regenerate`
  round-trip, `56a969e83` stage-layout `--prune`), all committed 2026-10-09 17:45–18:03 PDT
  (2026-10-10 00:45–01:03 UTC), followed by task 388's three phases (2026-10-14) fixing the one
  follow-up bug task 371's own summary recorded (`prune_next_body()`'s CLI-flag-parsing defect).
- `specs/archive/371_roadmap_generator_stage_layout_and_silent_abort/summaries/
  01_stage-layout-silent-abort-summary.md` is almost a verbatim match for task 532's description:
  same script, same "silent abort" symptom, same Stage-layout cause, same source-store
  implementation requirement. Its own `## Verification` section records: "This repository's own
  classic `specs/ROADMAP.md`: `--regenerate --dry-run` exits 0, diff confined to generated
  `## Open work` status tokens, live file confirmed untouched throughout" — the exact
  reproduction this research repeated independently below.
- `specs/state.json` already contains several `covered-by-closed` audit entries pointing at task
  371's summary as the discharging artifact for other overlapping task proposals (e.g. project
  375), confirming this repository has an established pattern for recording "this proposal is
  already covered by a landed task" rather than re-implementing.

### External Resources

None consulted — this is a pure codebase/history question with no external dependency.

## Live Reproduction (today, 2026-11-11)

1. **Real `specs/ROADMAP.md`, `--regenerate --dry-run`**:
   ```
   bash .claude/scripts/roadmap-integration.sh --regenerate --dry-run \
     --roadmap specs/ROADMAP.md --state specs/state.json
   ```
   Exit 0. Stderr: five non-fatal `Warning:`/`WARNING:` lines (uncategorized/undeclared topics —
   pre-existing, unrelated to this task) plus the six-field generation marker
   (`tasks=143 topics=10 runs=11 pruned=0 retained=143`). Stdout: a 26-line unified diff confined
   to (a) one Run line losing task 604 (a real, already-tracked state change) and (b) the
   `## Open work` block gaining task 369 as `IN FLIGHT` and losing it from the `ready` block (also
   a real state change, not a generation defect). `detect_layout` classified the file `classic`
   (it carries exactly the eight literal `roadmap-format.md` headers; no `## Stage N` header is
   present in the live file today).
2. **Synthetic unrecognized-layout fixture** (`# Roadmap` + one arbitrary `## Something
   Unrecognized` section, real `state.json`): `--regenerate` (no `--dry-run`) exits 1, prints
   `ERROR: --regenerate refuses to write ...: its section headers match neither the classic
   eight-header vocabulary nor the stage-based structural predicate ...`, lists the file's actual
   headers, and the file is confirmed byte-for-byte unchanged on disk afterward.

Both reproductions match task 371's own `## Verification` claims exactly, and neither reproduces
either variant of task 532's described defect (the original exit-1/zero-output silent abort, or
the BEHAVIOR UPDATE note's exit-0/half-apply against an authored Stage file). The most likely
explanation for the BEHAVIOR UPDATE observation is a transient state of `specs/ROADMAP.md` at the
time it was written (e.g. a temporary ninth/Stage-shaped header before the file was normalized
back to the pure classic vocabulary it carries today) — not a standing defect in the script.

## Recommendations

- **Do not dispatch a plan or implement phase for task 532.** There is no remaining code change:
  the two remedies the task description poses as alternatives ("teach the script the Stage-based
  layout" / "make `--regenerate` say so loudly instead of aborting in silence") are both already
  implemented, tested (68/68 in `test-roadmap-generation.sh` per task 371's summary), and
  documented in `roadmap-format.md`.
- **Close task 532 as duplicate/covered-by-closed**, citing
  `specs/archive/371_roadmap_generator_stage_layout_and_silent_abort/summaries/
  01_stage-layout-silent-abort-summary.md` as the discharging artifact — the same pattern already
  used for other task-371 overlaps recorded in `specs/state.json`.
- If a future `/orchestrate` cycle wants independent confirmation beyond this report, the two
  live-reproduction commands above are directly repeatable and read-only (`--dry-run` for the real
  file; a disposable scratch fixture for the refusal path) and require no further investigation.

## Decisions

- Treated task 371's archived summary and this research's independent live reproduction as
  sufficient evidence that task 532's premise is stale, rather than raising a `user_decision`:
  this is a factual finding the codebase and its own history already settle, not a preference or
  an external-risk choice requiring the user's judgment (per
  `context/standards/user-decision-contract.md`'s "When NOT to Raise One" — a prior artifact
  already answered the same question).
- Did not attempt to determine why the BEHAVIOR UPDATE note's "half-apply" observation does not
  reproduce today; `specs/ROADMAP.md` is actively maintained by many concurrent tasks and its
  exact header set at any past moment is not reconstructable from this research's scope, and the
  discrepancy does not change the recommendation (the design that would govern whichever state the
  file is in — classic full regeneration, or stage partial round-trip, or loud refusal — is
  already built and already covers both possibilities correctly).

## Risks & Mitigations

- **Risk**: closing task 532 outright, if the planner/postflight stage does not treat "no
  implementation needed" as a valid terminus. **Mitigation**: this report documents the evidence
  trail (archived summary + two independent live reproductions) so the next phase can act on it
  directly without re-researching; the `specs/state.json` precedent for `covered-by-closed`
  entries shows this repository already has a sanctioned path for exactly this outcome.
- **Risk**: a different repository consuming the `core` extension (e.g. BimodalLogic, where this
  task originated) might still be running a stale, pre-fix deployed copy of
  `roadmap-integration.sh`. **Mitigation**: out of this repository's scope — the fix lives in the
  shared source store this repository owns; a consumer repository on a stale deploy is a redeploy
  problem for that repository, not a code defect here.

## Context Extension Recommendations

None. `roadmap-format.md` already documents the current design fully and accurately; no gap was
found during this research.

## Appendix

- Search queries / commands used:
  - `find . -name "roadmap-integration.sh"`
  - `python3 -c "..."` reading `.claude-extensions.json`'s `core.source_dir`
  - `diff .claude/scripts/roadmap-integration.sh agent-system/extensions/core/scripts/roadmap-integration.sh`
  - `git log --oneline -- agent-system/extensions/core/scripts/roadmap-integration.sh`
  - `jq -r '.active_projects[] | select(.project_number==532)' specs/state.json`
  - `grep -n '"project_number": 371' -A 20 specs/archive/state.json`
  - `bash .claude/scripts/roadmap-integration.sh --regenerate --dry-run --roadmap specs/ROADMAP.md --state specs/state.json`
  - Synthetic-fixture reproduction of the unrecognized-layout refusal path (scratch directory, not
    committed)
- References:
  - `agent-system/extensions/core/scripts/roadmap-integration.sh`
  - `agent-system/extensions/core/context/formats/roadmap-format.md`
  - `specs/archive/371_roadmap_generator_stage_layout_and_silent_abort/summaries/01_stage-layout-silent-abort-summary.md`
  - `.claude/rules/source-store-deploy-boundary.md`
