# Implementation Summary: Task #603

- **Task**: 603 - Make specs/ROADMAP.md a wholly generated artifact backed by state.json roadmap
  entries, and add a `/roadmap [instruction]` command/skill/agent that maintains them
- **Status**: [COMPLETED]
- **Started**: 2026-11-12T00:00:00Z
- **Completed**: 2026-11-12T06:30:00Z
- **Effort**: ~13 hours (matches the plan's estimate)
- **Dependencies**: None declared on this record.
- **Artifacts**: plans/01_roadmap-generated-from-state.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`## Next` and `## Open work` in `specs/ROADMAP.md` are now rendered wholly from new
`roadmap_batches`/`roadmap_notes` state entries (plus per-task `roadmap_annotation`/
`roadmap_ext_blocked` fields) — there is no retention parser anywhere in the generator's path.
A new `/roadmap [instruction]` command/skill/judgment-bearing agent trio maintains those
entries: the agent decides batch membership, order, descriptions, rationale, and missing
dependency edges; the renderer (`roadmap-integration.sh`) makes no judgment calls. The live
file's prior hand-authored judgment was migrated into state via a new one-time script with a
hard, line-level losslessness accounting gate, and both `/roadmap` invocation forms were
demonstrated end-to-end against this repository's live roadmap.

## What Changed

- `agent-system/extensions/core/context/schemas/state-schema.json` — added top-level
  `roadmap_batches` (array of `{task_ids, description, rationale?, flags?}`) and `roadmap_notes`
  (`{next_preamble, next_postamble, open_work_trailer}`), plus per-task `roadmap_annotation`/
  `roadmap_ext_blocked`.
- `agent-system/extensions/core/scripts/validate-state.sh` — extended both known-field arrays;
  added Check 13 (roadmap_batches integrity: membership, non-terminal, no duplicate members,
  description bound), WARN-only per the Checks 8-11 precedent.
- `agent-system/extensions/core/context/reference/state-management-schema.md` — field
  documentation for all four new fields, plus the `priority`-is-never-batch-order and
  `roadmap_items`-is-dead-and-not-the-batch-carrier rulings the research pass surfaced.
- `agent-system/extensions/core/context/formats/roadmap-entry-template.md` — new: the
  entry/rendered-shape template, the 100-character `description` bound, and a worked
  compliant/non-compliant example pair.
- `agent-system/extensions/core/context/formats/roadmap-format.md` — rewrote the
  Authored-vs-Generated table (`## Next`/`## Open work` now `generated`), the Next/Open-work
  grammars as rendering contracts, added the per-section ruling for all six non-batch sections
  (`## Gate state` ruled impossible to generate), and a sentence on why the Destructive-Overwrite
  Refusal is now *more* important with nothing authored left in the rendering path.
- `agent-system/extensions/core/context/patterns/roadmap-update.md` — `--regenerate`'s contract
  updated; `--prune` documented as a deprecated alias; the advisory batch-proposal lint's
  disposition recorded (see below).
- `agent-system/extensions/core/scripts/roadmap-integration.sh` — added `render_next()` and
  `covered_ids_from_batches()`; rewrote both regenerate arms (classic and stage) to render `##
  Next` wholly from state; rewrote `render_open_work()`/`status_token()` to read
  `roadmap_annotation`/`roadmap_ext_blocked` from state instead of a retention override; deleted
  `parse_retention()`, `extract_open_work_trailer()` (replaced by `open_work_trailer_from_notes()`),
  `strip_coverage_appendix()`, `covered_ids_from()`, and all six prune-mode functions; `--prune`
  is now a one-line deprecated alias dispatching to `--regenerate`. Net deletion: ~674 lines
  removed across phases 3-4.
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` — extensive new
  coverage for state-backed rendering (batch order, no-rationale-no-bullet, all-terminal
  omission, preamble/postamble positions) and the `--prune`-is-now-an-alias behavior, replacing
  the obsolete retention/line-dropping assertions.
- `agent-system/extensions/core/commands/roadmap.md`,
  `agent-system/extensions/core/skills/skill-roadmap/SKILL.md`,
  `agent-system/extensions/core/agents/roadmap-agent.md` — new command/skill/agent trio.
  `roadmap-agent` (model: opus) owns the judgment; writes go through `state-write.sh` (entries)
  and the existing `edge_only` arm (edges) exclusively, and it invokes
  `roadmap-integration.sh --regenerate` itself rather than ever writing `specs/ROADMAP.md`
  directly. `skill-roadmap` is a thin delegate-then-postflight wrapper (dispatch the agent;
  verify `validate-state.sh` and a fresh-render sanity check; commit the two in-scope files).
- `agent-system/extensions/core/manifest.json`,
  `agent-system/extensions/core/merge-sources/claudemd.md`,
  `agent-system/extensions/core/index-entries.json`,
  `agent-system/extensions/core/README.md` — registration for the new trio and the two new
  scripts, including the new template's index entry and corrected `line_count`s.
- `agent-system/extensions/core/scripts/tests/test-roadmap-command-registration.sh` — new:
  structural registration suite (existence, manifest membership, agent frontmatter validity,
  index entry, `claudemd.md` table rows).
- `agent-system/extensions/core/scripts/migrate-roadmap-next-to-state.sh` — new: the one-time
  migration, with a hard losslessness accounting gate (every non-blank line outside the fence
  must be accounted for in a `roadmap_notes` slot or a batch's rationale, named explicitly on
  failure) and a separate verbatim-comment-preservation assertion. Discovered and fixed two bugs
  against the live file during Phase 7: GFM "tight" lists (no blank line between consecutive
  bullets) were merging an entire bullet list into one unsplit block, and a free-standing prose
  paragraph that merely *mentioned* a batch's task id in passing was being mis-attributed to
  that batch's rationale instead of staying in `next_postamble`. Both are now regression-tested.
- `agent-system/extensions/core/scripts/tests/test-migrate-roadmap-next-to-state.sh` — new:
  18 fixture cases plus 5 more for the tight-list/mis-attribution regression (23 total).
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — added `roadmap-agent.md`
  to the Check E/F exclusion lists (console-only text return to its dispatching skill; no
  per-invocation task directory to write `.return-meta.json` into), matching the existing
  `code-reviewer-agent.md` precedent.
- `specs/state.json` / `specs/ROADMAP.md` — live migration run (9 batches seeded from the prior
  authored `## Next` body, losslessness accounting passed), `--regenerate` run for real
  (idempotence proven), and two live `/roadmap` demonstrations (see below) layered on top.

## Decisions

- **Array position is the batch's priority.** No new priority field; the existing per-task
  `priority` enum is explicitly ruled to never govern batch order (two independent axes, kept
  deliberately separate).
- **Two authored text fields per batch**: a bounded `description` (<=100 chars, the anti-fluff
  rendered line) and an unbounded `rationale` (the lossless "Why this order" home).
- **"Wholly generated" is read narrowly and explicitly**: only `## Next` and `## Open work`
  become generated; the other six classic sections stay authored, each with a recorded ruling.
  `## Gate state` in particular is ruled *impossible* to generate — every bullet cites a
  freshly-run measurement, not a state field.
- **`--prune` becomes a deprecated alias for `--regenerate`**, not a second rendering path: a
  file rendered wholly from live state cannot accumulate terminal cruft by construction, so there
  is nothing left for a separate prune pass to do.
- **No second edge-writing path.** The agent's only edge-writing mechanism is the pre-existing
  `update-task-status.sh preflight <N> edge_only <SID> --depends-on-add=[M]` arm; its
  `not_started`-only resolution constraint is documented verbatim in the agent's write contract.

## Plan Deviations

- **Phase 2/3/5's own `verify-deploy.sh`/doc-lint verification criteria were satisfied with
  known, explicitly-recorded deferrals** rather than a clean pass at the time each phase closed:
  each phase's own newly-touched files produced expected deploy-tree-content-drift and
  index-entries line-count-drift findings that could only be resolved once Phase 5's registration
  edits and Phase 7's redeploy landed. Each phase's own progress file records this deferral
  explicitly; Phase 7's redeploy resolved every one of them except three independently-confirmed
  pre-existing, unrelated failures (see Verification below).
- **This dispatch's own Batch Gate Deferral directive overrides Phase 7's plan-text
  verification instruction** ("No --skip-slow and no --only-gate narrowing"): the dispatch file
  explicitly instructs discharging the final phase against a scoped narrowing invocation instead
  of the complete gate set, deferring that complete run to the batch-level stage. The scoped
  discharge (`run-all.sh --only test-roadmap-generation.sh,test-migrate-roadmap-next-to-state.sh,
  test-roadmap-command-registration.sh,test-validate-state.sh,test-manifest-scripts-sync.sh`,
  5/5 passed) is recorded as the formal discharge; the full `verify-deploy.sh` additionally ran
  four times during this phase as corroborating evidence (see Verification).
- **The `/roadmap` demonstrations ran through a general-purpose agent standing in for
  `roadmap-agent`**, not the literal `roadmap-agent` subagent type: the harness's Agent-tool
  subagent roster does not recognize an agent type created earlier in the same session (no
  mid-session reload). Both demonstrations explicitly instructed the stand-in agent to read and
  follow `agents/roadmap-agent.md` as its own operating contract verbatim — the Self-Execution
  Fallback path `skill-roadmap/SKILL.md`'s own Stage 2 already documents for this exact
  situation. The write contract (entries via `state-write.sh`, edges via the `edge_only` arm, the
  renderer invoked by the agent itself) was followed exactly either way.
- **Two real bugs in the migration script were found and fixed only by running it against the
  live file**, not the plan's own fixture: GFM tight-list block splitting, and prose-paragraph
  mis-attribution by incidental task-id mention. Both are now covered by dedicated regression
  fixtures in `test-migrate-roadmap-next-to-state.sh`.

## Verification

- Build: N/A (no compiled artifact)
- Tests: `test-roadmap-generation.sh` 93/93 (source-store), `test-validate-state.sh` 78/78,
  `test-migrate-roadmap-next-to-state.sh` 23/23, `test-roadmap-command-registration.sh` 14/14 —
  all passing against the deployed tree after redeploy.
- `lint-agent-contracts.sh`, `lint-shellcheck.sh` (repo-wide), `lint-state-writer-boundary.sh`,
  `lint-subject-resolution-declaration.sh`, `lint-postflight-boundary.sh`,
  `check-extension-docs.sh` (doc-lint) — all clean.
- `bash .claude/scripts/deploy-headless.sh` ran four times during Phase 7 (three to fix
  genuine findings, one final clean pass). Its own full `verify-deploy.sh` reported exactly
  three failures every time, all independently confirmed pre-existing and unrelated to this
  task: `gate10` (`validate-state.sh --deep`)'s 60s timeout is a marginal, load-dependent
  timing issue (measured standalone at 57.8s, passing); the eager-load budget overage and
  `skills/skill-orchestrate/SKILL.md`'s context-ceiling overage were both last touched by an
  unrelated task per `git log`.
- `validate-state.sh` passes Check 13 against the now-populated `roadmap_batches` (0 failed,
  warnings only for terminal members in a batch left deliberately unedited and one unrelated
  pre-existing schema gap).
- Live migration's losslessness accounting gate exited 0, naming zero unaccounted lines.
- A second consecutive `--regenerate` is byte-identical (`cmp -s`, exit 0) both immediately
  after the migration and after each `/roadmap` demonstration.
- The unclassifiable-layout refusal was re-confirmed against a scratch fixture after the live
  migration: exit 1, named reason, no write.
- Both `/roadmap` invocation forms were demonstrated against the live repository (see Follow-ups
  for the resulting content changes) and committed.

## Impacts

- `specs/ROADMAP.md` is no longer hand-maintained prose with a generated skeleton; its judgment
  now lives in `specs/state.json` and is revised through `/roadmap`, not by editing the rendered
  file directly.
- The advisory batch-proposal lint record (titled "Advisory lint for hand-authored /orchestrate
  batch proposals in ROADMAP.md phase blocks", `[COMPLETED]`) is reported here, as the dispatch
  required, rather than edited: its parse layer's subject matter — a hand-authored `## Next` Run
  line to check — no longer exists in the shape it was written against now that `## Next` is
  rendered wholly from `roadmap_batches`. Disposition: **superseded in its parse layer, not
  merely narrowed**. It is wired into no gate (zero references in `verify-deploy.sh`,
  `gate-registry.data`, or `tests/run-all.sh`), so nothing breaks mechanically in the interim.
  The rescoping-or-retirement decision is left to that record's own owner, per the dispatch's
  explicit instruction not to silently edit it.
- The dependent next-batch-suggestion record (which wires `roadmap-integration.sh` and asks a
  `--prune`-into-the-conclusion-stage question) now reads differently: `--prune` dissolves into
  `--regenerate`, so there is no separate prune pass left to wire in.

## Follow-ups

- The live `/roadmap` full-pass demonstration flagged (and left unresolved, per its own
  instructed scope) that `roadmap_batches[0]`'s eight-member `task_ids` array now names six
  terminal tasks (515, 600, 597, 490, 601, 531, all completed during this same batch run);
  rendering already omits them, but trimming the array itself was left to a future `/roadmap`
  pass or operator action rather than done here.
- `roadmap_items` (the dead per-task field) is ruled explicitly not the batch carrier but is not
  retired in this task; retirement belongs to `migrate-state-legacy-fields.sh`'s purview.
- The two edges the full-pass `/roadmap` demonstration added that are not yet reflected in any
  other task's own declared dependency expectations (`572` behind `585`, `591` behind both,
  `492` behind `479`, `476` behind `568`) are now live in `specs/state.json` and should be
  treated as authoritative by any subsequent `/orchestrate` cycle in this same batch.

## References

- `specs/603_roadmap_command_generated_from_state/plans/01_roadmap-generated-from-state.md`
- `specs/603_roadmap_command_generated_from_state/reports/01_roadmap-generated-artifact-research.md`
- `agent-system/extensions/core/context/formats/roadmap-format.md`
- `agent-system/extensions/core/context/formats/roadmap-entry-template.md`
- `agent-system/extensions/core/context/patterns/roadmap-update.md`
