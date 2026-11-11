# Collated Class Decisions: Task 435 Dead-Lifecycle-Command Prose Sweep

Collates every per-site class decision recorded across Phases 1-14, per Phase 15's own
instruction ("the 'per-class treatment with a per-site decision recorded for each class' the
dispatch requires is checkable in one place"). This is a report artifact, not a plan phase; it
does not restate the full per-phase detail already recorded in each phase's own progress file
(`specs/435_.../progress/phase-{N}-progress.json`) and handoff — it indexes them.

## Final Corpus State

Corpus-wide measurement command (restricted to `agent-system/extensions`, excluding
`core/docs/`), re-run at Phase 15:

```bash
grep -rlP '(?<![A-Za-z0-9_/.-])/(implement|research|plan)(?![A-Za-z0-9_.-])' \
  --include="*.md" --include="*.json" --include="*.sh" agent-system/extensions \
  | grep -v '^agent-system/extensions/core/docs/'
```

11 files carry a remaining occurrence. Every one maps to a recorded class-3 (leave-alone) decision
below; none is an unresolved/unfinished phase.

## Class-3 Leave-Alone Sites (the command name IS the data, or the phrasing is a genuinely
historical record exempted by the Non-Goals)

| File | Site(s) | Phase | Reason |
|------|---------|-------|--------|
| `core/context/patterns/context-discovery.md` | lines 329, 340, 347 | 2 | Literal jq-matched string values documenting `index.json`'s `load_when.commands` registration; rewording would break the check's own documentation of its literal match targets. |
| `core/context/patterns/multi-task-operations.md` | lines 286-287 | 2 | "Superseded note" — already correctly marked historical/record-versioning-exempt per the `system-overview.md` precedent (Non-Goals: no record-versioning cleanup beyond `revise.md:99`). |
| `core/context/patterns/multi-task-operations.md` | lines 555, 561-563 | 2 | "Historical" note plus a table explicitly retained for "the pattern's original per-command design intent" — same exemption. |
| `core/context/patterns/skill-lifecycle.md` | line 288 | 2 | Correct historical statement that the retired commands are the sentence's own subject matter — same class as the lint's own historical statement (`lint-dead-command-recommendations.sh:8`). |
| `core/context/formats/command-structure.md` | lines 31, 56, 87, 168 | 4 | The entire "Command File Anatomy" worked example rests on the stale premise that `/plan` is a standalone command file. A disclaimer was added immediately before the example (Non-Goals-compliant: reworded, not restructured) rather than hand-editing every internal value, which would have been a partial restructure. |
| `core/scripts/lint/lint-dead-command-recommendations.sh` | lines 8, 53-54 | 7 | Named class-3 site in the dispatch itself: line 8 is the correct historical statement of the lint's purpose; lines 53-54 are illustrative match strings documenting its own detection behavior. Rewording either corrupts the gate this task depends on staying green. |
| `core/scripts/lint/lint-contract-compliance.sh` | lines 174, 188, 197 | 7 | AWK regex-delimiter syntax (`/research\)/` etc.) matching a literal shell case-arm label (`research)`), not a slash command — a pure syntactic coincidence of AWK's `/pattern/` delimiter convention colliding with the measurement regex. |
| `core/hooks/wezterm-preflight-status.sh` | lines 11-14, 68-70 | 7 | Comments accurately describe LIVE executable regex matching against raw user-prompt text for cosmetic tab-coloring, independent of whether a real command exists. Rewording would misdescribe the actual matching behavior of unchanged code. |
| `core/hooks/wezterm-task-number.sh` | line 10 | 7 | Same class as the sibling hook above. |
| `nvim/context/project/neovim/hooks/wezterm-integration.md` | lines 81-83 | 13 | Documents the same live wezterm-task-number.sh regex-matching behavior as the core hooks above. |
| `core/scripts/validate-context-budgets.sh` | lines 280, 330-332, 353-355 | 7 | jq object keys (`/research`, `/plan`, `/implement`) are the documented `load_when.commands[]` field convention other code matches on (per `index.schema.json` and `core/context/README.md`, both corrected in Phase 6 to use a live-command example) — load-bearing data, not a claim that these are runnable commands. |
| `founder/context/project/founder/domain/migration-guide.md` | lines 23, 25 (left column only) | 10 | A "v2.x Pattern" migration table's LEFT column is genuine historical record (what a user used to type); the RIGHT ("v3.0 Equivalent") column's parallel cells, which make present-tense claims, were reworded, not left alone — see Phase 10's progress file for the full per-cell sub-rule this discovered. |

## Class-1/2 Treatment Summary (reworded to phase-dispatch framing)

Every other occurrence across the corpus — approximately 1,600+ sites across Phases 1-14 — was
reworded per the Classification Rubric (`plans/01_dead-lifecycle-command-prose-sweep.md`'s
Classification Rubric section): Class 1 (phase-versus-command prose) became phase-name or
dispatch-noun-phrase framing; Class 2 (architectural/dispatch-model reference) became
`research`/`plan`/`implement`-phase framing, or an `/orchestrate --research`/`--plan`/`--implement`
invocation form where the original text specifically illustrated literal CLI usage. Full per-site
detail lives in each phase's own progress file; this collation does not restate it.

## Gate-24 Blind Spots Discovered (informational — not retargeted here; task 434's territory)

Three distinct blind-spot classes in `lint-dead-command-recommendations.sh`'s own detection
pattern were discovered and worked around during this sweep (each individual recommendation WAS
fixed where found; this section documents the detection gap for whoever next revisits gate 24):

1. **Verb-phrasing outside the anchored shape** (Phase 7, Phase 10): `Consider running /research`,
   `Resume with /research`, `then run /implement to resume` — gate 24 only anchors on `Next:` /
   standalone `Run` immediately before `/<name>`.
2. **Multi-command-per-line** (Phase 11): `commands/grant.md:314`'s `Next: /grant {N} --budget,
   then /plan {N}` — gate 24 exempts the whole line once its FIRST command token is valid,
   missing a dead SECOND command later on the same line.
3. (Both confirmed via direct inspection of gate 24's own Layer-2 shape test, not assumed.)

## Residue Named for a Follow-Up Record (not restructured, per Non-Goals)

1. **`research-workflow.md`'s orphaned `--divide` feature** (Phase 5): the "Topic Subdivision
   (`--divide` flag)" section describes a flag confirmed, via corpus-wide grep, to appear nowhere
   else in the system. Unclear whether it was ever ported to `/orchestrate` or ever existed
   outside this document.
2. **The `status-sync-manager`/`git-workflow-manager` fictional-abstraction language** (Phase 5):
   present across all three `processes/` documents and `command-lifecycle.md`; `command-structure.md`
   already carries the correction inline (Mistake-pattern section) but the `processes/` docs and
   `command-lifecycle.md` do not yet.
3. **`command-lifecycle.md`'s own title and section-header framing** (Phase 5): still frames
   research/plan/implement as command-file-lifecycle subjects even after this sweep's token-level
   rewording; a full restructure separating phase-dispatch lifecycle from live-command lifecycle
   was out of scope.
4. **`command-structure.md`'s worked example premise** (Phase 4): same class as item 3, disclaimed
   rather than restructured.
5. **`core/README.md`'s command table row-count mismatch** (Phase 8): the detailed `## Commands`
   table (now correctly reworded for the 3 phase rows) still has a different row count than the
   page's own "Commands | 15" overview line, and `/orchestrate` itself is absent from the detailed
   table — a missing-content defect, not a dead-command defect, pre-existing and unrelated to this
   sweep's edits.
6. **The `--remember` memory-extension flag** (Phase 12): named in `memory-setup.md` and
   `memory-troubleshooting.md`, confirmed via corpus-wide grep to appear nowhere else in the
   system — likely vestigial from before memory auto-retrieval existed.
7. **The planning/implementation-workflow.md and research-workflow.md command-file References
   sections** (Phase 5): cite nonexistent command files (`.claude/commands/research.md` etc.);
   `command-lifecycle.md`'s equivalent Reference line was corrected inline, but the two
   `processes/` siblings' own References sections were not independently re-verified line-by-line
   given their low measured token count — flagged for the same follow-up record as item 2.

## Pre-Existing, Out-of-Scope Issues Observed and Logged (not fixed; unrelated to this task)

Logged via `issue-record.sh` during Phases 4 and onward (kind: issue, class: gate collision,
severity: minor) and repeatedly re-confirmed clean of regression by this sweep's own edits:

1. **Gate 24's 2 `/ide` violations** (`memory-setup.md:93`, `memory-troubleshooting.md:34`) —
   `/ide` is unrelated to this task's `/implement`/`/research`/`/plan` charter; introduced by an
   unrelated prior task (commit `a146cba6`), predates this task entirely.
2. **Gate 3's `scripts/validate-state.sh` deployed-content drift and the
   `schemas/state-schema.json` line_count mismatch** — both caused by the most-recent commit at
   dispatch time (`ebc532373732`, "specs: migrate 35 mis-sited meta records from BimodalLogic"),
   confirmed via `git log`/`git diff` to predate and be untouched by any phase of this task.
3. **Gate 3's "deployed script content drift" for every `.sh` file this sweep itself edited**
   (Phase 7 onward) — the expected, self-resolving consequence of editing source-store scripts
   before Phase 15's redeploy; resolved by this very phase's redeploy step.

## References

- Plan: `specs/435_reword_dead_lifecycle_command_prose_per_class/plans/01_dead-lifecycle-command-prose-sweep.md`
- Per-phase progress files: `specs/435_reword_dead_lifecycle_command_prose_per_class/progress/phase-{1..14}-progress.json`
- Per-phase handoffs: `specs/435_reword_dead_lifecycle_command_prose_per_class/handoffs/phase-{1..14}-handoff-*.md`
