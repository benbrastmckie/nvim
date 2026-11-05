# Implementation Plan: Task #428

- **Task**: 428 - Enforce and detect planner-agent terminal return-meta write
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None (task 378 completed; task 426 completed and already discharged this task's contract/detection scope — see Overview)
- **Research Inputs**: specs/428_enforce_planner_agent_terminal_write/reports/01_terminal-write-enforcement.md
- **Artifacts**: plans/01_terminal-write-enforcement-scope.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research phase established that both fix locations this task names — `planner-agent.md`'s own
terminal-write contract and `orchestrate-cycle-postflight.sh`'s detection of a non-terminal
`.return-meta.json` — are already correct and already closed against the cited incident. The
contract states the write as a MUST at Stage 0, Stage 6b, Stage 6c, and in four separate MUST-DO
items; the detection discriminates `STATUS_IN_PROGRESS` as its own named reason, records a
`RECOVERY_DECLINED` defect attributed to the dispatched agent's own file, and carries
stall/strand corroboration so a reader can tell an abandoned wrap-up from an agent-contract
violation. The one genuinely open gap is **structural**: no mechanism on the `/orchestrate`
direct-dispatch path can *prevent* the missing write, because the codebase's only
`SubagentStop`-level block (`hooks/subagent-postflight.sh`, keyed on a `.postflight-pending`
marker) is never armed for that path — `skill-orchestrate` dispatches core-type agents directly
via `command-route-agent.sh`, with no intermediate skill to call
`skill_create_postflight_marker()`.

This plan therefore closes the task by **documenting that scope boundary** at the three places a
future author would look for it, rather than by editing a contract that is already correct, a
detector that already fires, or by building new prevention infrastructure whose design risk the
research deliberately left unresolved. Two phases, markdown-only, three existing files, no new
files and no index-entries churn.

### Research Integration

Findings carried directly into the phases below:

- The marker-wiring claim was independently re-verified during planning, not taken on trust:
  `grep -rn 'postflight-pending\|skill_create_postflight_marker'` over
  `agent-system/extensions/core/skills/skill-orchestrate/` and
  `agent-system/extensions/core/scripts/orchestrate-cycle-*.sh` returns **zero** matches, while
  the same symbol appears in 18 other source-store files (`skill-reviser`, `skill-spawn`, and
  the extension `skill-{domain}-*` skills). Phase 1's statement cites this grep so a future
  reader can re-run it rather than trust the prose.
- Research recommended siting the primary statement in `docs/architecture/handoff-schema.md`'s
  `## Postflight Boundary` section. This plan sites it one section earlier, in
  `## Outcome Channels`, as a planning judgment: that section already owns the fail-closed
  `.return-meta.json` recovery rules, already names `in_progress` by value, and already states
  what a non-success status does — the boundary statement belongs beside the mechanism it
  qualifies, not beside the lead's do-not-do list. `## Postflight Boundary` bounds what the
  *lead* does; this fact is about what *nothing upstream* does.
- Research's recommendation 2 (do not re-open task 426's `test-orchestrate-cycle-postflight.sh`
  I2/J1/J2/J3 fixtures) is honored: no test file is in scope.
- Research's recommendation 1(b) (genuine prevention via marker wiring into
  `skill-orchestrate`'s dispatch flow) is scoped **out** — see Non-Goals.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; ROADMAP.md was not
consulted and is not modified.

## Goals & Non-Goals

**Goals**:
- State, once and authoritatively, that after-the-fact `RECOVERY_DECLINED` detection is this
  system's **sole** enforcement of a dispatched agent's terminal `.return-meta.json` write on the
  `/orchestrate` direct-dispatch path, and that no `SubagentStop`-level prevention covers that
  path.
- Make that fact reachable from the two files a future author would consult first when reaching
  for `subagent-postflight.sh` as "the" terminal-write enforcement mechanism.
- Leave the handoff-staleness gate, the `RECOVERY_DECLINED` classification, and every existing
  detection trigger expression byte-for-byte unchanged.

**Non-Goals**:
- **Editing `agents/planner-agent.md`.** Its terminal-write contract is already complete on
  paper (Stage 0, 6b, 6c, Error Handling, MUST-DO items 1/2/7/9). Adding more MUST language to a
  contract whose failure mode is execution-time interruption, not textual omission, would change
  no behavior.
- **Any change to detection logic** in `orchestrate-cycle-postflight.sh` or
  `orchestrate-recover-outcome.sh`, and any change to the handoff-staleness gate (this task's
  hard constraint).
- **Building the prevention mechanism** (wiring `skill_create_postflight_marker()` — or a new
  dispatch-scoped marker — into `skill-orchestrate`'s own Agent-tool call, plus a
  `SubagentStop`-level terminal-status check). This is new cross-cutting infrastructure with
  three live design constraints the research surfaced: the existing marker's purpose (force the
  *orchestrator's* own postflight) must not be silently overloaded; `SubagentStop` can fire more
  than once per loop-guard continuation, so a naive check would false-block a legitimately
  in-flight multi-phase dispatch; and no `transcript_path`-based correlation precedent exists as
  a fallback. It belongs in its own task with its own plan, and the decision to fund it is
  surfaced as a non-blocking `user_decision` on this dispatch's return metadata.
- **Redeploying the `.claude/` tree.** The deployed tree is already stale for `core`, `lean`, and
  `literature` at planning time, and three sibling tasks are editing the same source store this
  same cycle. A whole-tree regeneration here would deploy siblings' in-flight work; it is the
  user's manual step, not this task's.
- **Adding a `.postflight-pending` row** to `context/standards/orchestrator-runtime-files.md`'s
  runtime-file table, or a matching pattern to `scripts/lib/runtime-file-patterns.sh`. Its
  sibling `.postflight-loop-guard` has both; `.postflight-pending` has neither. This was observed
  during planning and recorded in `issues.jsonl` as a minor, open, follow-up-channel item — it is
  a different defect class (runtime-file tracking coverage) from this task's subject.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Pre-existing deploy staleness makes the final phase's complete gate run red for reasons unrelated to this task | M | H | Phase 1 step 1 captures a pre-edit findings baseline (`verify-deploy.sh --findings --skip-slow`). The final phase closes on "no finding new relative to that baseline, and no finding naming any of this task's three files" — never on an absolute green that the stale tree cannot produce. Staleness is reported, never remedied by hand-patching `.claude/**` (forbidden by `rules/source-store-deploy-boundary.md`). |
| A sibling task (414, 469, 470) edits one of this task's three files mid-dispatch | H | L | None of the three files appears in any sibling's declared `file_scope` (verified against this dispatch's `concurrent_siblings` payload). Each phase still re-reads its target file immediately before editing, and stages an explicit file list — never a directory or glob. |
| The documented claim silently goes stale if marker wiring is later added to `skill-orchestrate` | M | L | The Phase 1 text embeds the exact verifying `grep` invocation rather than asserting the fact bare, so a reader who re-runs it gets the current answer instead of trusting the paragraph. |
| Three near-duplicate statements drift apart | M | M | Single-sourcing is a hard requirement of Phase 2: the full statement lives **only** in `handoff-schema.md`; the other two files carry one sentence plus a pointer to that heading by name, never a second copy of the reasoning. |
| Added text trips the task-reference or record-version lints | L | M | All three targets are outside `specs/**`, so `rules/no-task-references-in-deliverables.md` and `rules/no-record-versioning-in-deliverables.md` both apply in full: the added prose cites durable anchors (file names, section headings, defect-class names, the grep) and names no task number, no "previously", and no draft lineage. Gate 4 (task-reference lint) covers the former mechanically in both phases' verification. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Site the primary scope-boundary statement in handoff-schema.md [NOT STARTED]

**Goal**: One authoritative subsection in `## Outcome Channels` stating that the fail-closed
recovery it already documents is detection-only, and that nothing upstream prevents the missing
terminal write on the direct-dispatch path.

**Tasks**:
- [ ] Capture the pre-edit gate baseline for the final phase's comparison, using the **same
      invocation shape Phase 2 will run** (`--findings`, no `--skip-slow`, same default TARGET) so
      the two runs are comparable rather than differing by gate 8's presence:
      `bash .claude/scripts/verify-deploy.sh --findings` > a scratch file under this session's
      scratchpad; record that path and the run's exit status in `progress-file.md`. A baseline
      taken with a narrower flag set is not a baseline for a wider run.
- [ ] Re-read `agent-system/extensions/core/docs/architecture/handoff-schema.md`'s
      `## Outcome Channels` section in full immediately before editing (sibling-concurrency rule),
      confirming the `---` terminator that currently closes the section.
- [ ] Insert a new `###` subsection as the last subsection of `## Outcome Channels` (immediately
      before that `---`), titled so it is citable by name from the other two files — e.g.
      `### No Preventive Enforcement of the Terminal Write (Direct-Dispatch Path)`. It states, in
      four short movements and no more:
      (i) the accept-list and freshness rules above are **detection after the fact**;
      `RECOVERY_DECLINED` — recorded by `orchestrate-cycle-postflight.sh`'s WORK (d)
      absent-handoff branch, attributed to the dispatched agent's own file — is this system's sole
      enforcement of a dispatched agent's terminal `.return-meta.json` write on the `/orchestrate`
      path;
      (ii) the codebase's one `SubagentStop`-level block (`hooks/subagent-postflight.sh`, keyed on
      a `.postflight-pending` marker written by `skill-base.sh`'s
      `skill_create_postflight_marker()`) cannot fire for that path, because core task types
      (`general`, `meta`, `markdown`) route directly to agents via `command-route-agent.sh` with
      no intermediate skill to arm the marker — with the verifying invocation quoted inline:
      `grep -rn 'postflight-pending\|skill_create_postflight_marker' <source_dir>/skills/skill-orchestrate/ <source_dir>/scripts/orchestrate-cycle-*.sh`
      (currently zero matches);
      (iii) consequently an `in_progress` terminal write on this path is **detected and recorded,
      never prevented**, and extending `subagent-postflight.sh`'s own check would not change that
      — marker creation would have to be armed in `skill-orchestrate`'s dispatch flow first;
      (iv) this statement describes the return-meta recovery path only and says nothing about,
      and changes nothing in, the handoff mtime-staleness gate.
- [ ] Re-read the inserted text against `rules/no-task-references-in-deliverables.md` and
      `rules/no-record-versioning-in-deliverables.md`: no task numbers, no "previously"/"no
      longer"/"formerly", no supersession framing — durable anchors only.
- [ ] Commit this phase's single file with an explicit one-file pathspec.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: a single markdown file under `docs/architecture/` with no executable
surface, for which `suite_selection_select` returns `__FULL_SWEEP__` (plan-format.md sub-case (b),
source-store non-`specs/**` markdown), so the covering check is the explicit-TARGET gate subset
`bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim/agent-system/extensions/core`
plus the `local` row's diff read-through.

**Scope Hypothesis**: this phase asserts exactly **one** file touched and **one** inserted `###`
subsection, with the `## Outcome Channels` section currently spanning roughly lines 584-662 and
terminated by a `---`. Confirm by re-reading the section immediately before editing and checking
that the `---` terminator is still where the heading map puts it; if a sibling or a prior edit has
restructured the section, re-site the subsection within `## Outcome Channels` rather than forcing
the recorded line range.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - add one `###` subsection at the end of `## Outcome Channels` stating the terminal-write enforcement scope boundary

**Verification**:
- The gate subset named in Tier Justification above exits 0 (gates 3 and 4 both run and neither
  SKIPs — a selection in which every gate SKIPs attests to nothing and exits 2, which is a
  failure, not a pass).
- `grep -n 'No Preventive Enforcement of the Terminal Write' agent-system/extensions/core/docs/architecture/handoff-schema.md` returns exactly one line, inside `## Outcome Channels`.
- Diff read-through confirms every changed hunk is additive prose inside that one section — no
  edit to the accept-list paragraph, the freshness paragraph, or any other section.
- `git diff --staged` names exactly one file.

---

### Phase 2: Add the two single-sourced pointers and discharge the complete gate set [NOT STARTED]

**Goal**: Make the Phase 1 statement reachable from the two files a future author reaches for
first, without copying its reasoning, and close the task against the full gate set.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/patterns/skill-lifecycle.md` around its
      lifecycle stage table (Stage 3, `Create Postflight Marker`) immediately before editing.
- [ ] Add **one sentence** there: Stage 3's marker is created only by skills that import the
      shared block, so `skill-orchestrate`'s direct-to-agent dispatch for core task types arms no
      marker and is covered by no `SubagentStop`-level enforcement — citing
      `docs/architecture/handoff-schema.md`'s new subsection by heading name for the full
      statement. No second copy of the reasoning.
- [ ] Re-read `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`'s
      `RECOVERY_DECLINED` prose paragraph (the "fifteenth instance" paragraph, around lines
      184-199) and its registry row (around line 303) immediately before editing.
- [ ] Add **one clause or sentence** to the prose paragraph — not the already-overlong registry
      row — naming `handoff-schema.md`'s new subsection as the home of the "this detection is the
      only enforcement on that path" statement. Leave the row, the class definition, the
      discriminating `.reason` set, and the severity unchanged.
- [ ] Re-read both inserted texts against the task-reference and record-version rules, as in
      Phase 1.
- [ ] Confirm single-sourcing: the full four-movement statement appears in exactly one file;
      `grep -rn 'No Preventive Enforcement of the Terminal Write' agent-system/` returns the
      Phase 1 heading plus the two pointers that cite it, and nothing else.
- [ ] Run the complete gate set and compare against the Phase 1 baseline (see Verification).
- [ ] Commit this phase's two files with an explicit two-file pathspec.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts exactly **two** files and **two** one-sentence pointers.
Confirm before closing by grepping the source store for other files that document the marker
(`context/patterns/skill-preflight-flow.md`, `docs/guides/creating-skills.md`,
`context/standards/orchestrator-runtime-files.md` are the known three) and checking that each
either already scopes the caller set correctly or is about a different file
(`.postflight-loop-guard`, not `.postflight-pending`). Add a third pointer only if one of those
three actively asserts coverage the Phase 1 statement contradicts; a file that is merely silent
needs none. If the count changes, say so in the handoff rather than quietly widening.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/skill-lifecycle.md` - one sentence beside the Stage 3 marker row scoping which dispatch paths arm the marker, pointing at the Phase 1 subsection
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` - one clause in the `RECOVERY_DECLINED` prose paragraph pointing at the Phase 1 subsection as the home of the enforcement-scope statement

**Verification**:
- Run the complete gate set: `bash .claude/scripts/verify-deploy.sh --findings` (source-store
  copy: `agent-system/extensions/core/scripts/verify-deploy.sh`), not a hand-picked subset.
- **Closure criterion — exit status first, baseline only as the pre-existing-red exception**:
  the primary criterion is the invoked command's own **exit status 0**. A non-zero exit is
  admissible as closure ONLY when both hold: every finding it reports is present verbatim in the
  Phase 1 baseline (no new finding), and no finding names any of this task's three files. A
  baseline diff alone never substitutes for the exit-status check — it only classifies an already
  non-zero exit as pre-existing rather than as this task's regression, and the handoff states
  the exit status and that classification explicitly. The deployed tree is known stale for `core`, `lean`, and
  `literature` at planning time; every deploy-freshness finding traceable to that staleness is
  pre-existing, is reported verbatim in the handoff, and is **not** remedied by hand-patching any
  file under `.claude/**` (`rules/source-store-deploy-boundary.md`). If the implement dispatch's
  own dispatch file carries a `## Batch Gate Deferral` section, that override's narrowed
  invocation applies instead for this dispatch, the complete set stays owed to the
  once-per-invocation batch gate stage, and this phase's notes record the deferral — the
  `**Verification Tier**: full` field above is never edited or demoted.
- The single-sourcing grep above returns exactly three hits (one heading, two pointers).
- `git log --oneline -2` shows exactly two commits for this task (one per phase), and
  `git diff --staged` named exactly the files listed per phase.

---

## Testing & Validation

- [ ] Gates 3 and 4 (doc-lint, task-reference lint) run — not SKIP — against the resolved source
      store and exit 0 after each phase's edits.
- [ ] Complete gate set run once in Phase 2, with findings compared line-for-line against the
      Phase 1 pre-edit baseline; zero new findings, zero findings naming this task's files.
- [ ] `grep -rn 'postflight-pending\|skill_create_postflight_marker' agent-system/extensions/core/skills/skill-orchestrate/ agent-system/extensions/core/scripts/orchestrate-cycle-*.sh` still returns zero matches, confirming the documented claim is true at the moment it is committed.
- [ ] No file under `.claude/**` modified (`git status --short` shows no `.claude/` path; the tree
      is gitignored, so also confirm by `git diff --stat` over the staged set).
- [ ] No file in any sibling task's declared `file_scope` modified.
- [ ] `agents/planner-agent.md`, `scripts/orchestrate-cycle-postflight.sh`,
      `scripts/orchestrate-recover-outcome.sh`, and every test file unmodified — the hard
      constraint, checked mechanically rather than asserted.

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/docs/architecture/handoff-schema.md` (one new `###`
  subsection).
- Modified: `agent-system/extensions/core/context/patterns/skill-lifecycle.md` (one sentence).
- Modified: `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` (one
  clause).
- `specs/428_enforce_planner_agent_terminal_write/summaries/01_*-summary.md` at completion.
- Two commits, one per phase, each with an explicit file-list pathspec.
- No new files, no `index-entries.json` change, no deploy.

## Rollback/Contingency

Every change is additive markdown prose in three existing files, committed one phase at a time
with explicit pathspecs, so reverting is `git revert` of one or both commits — no schema, no
script, no test fixture, and no deployed artifact is involved. If the complete gate run in Phase 2
surfaces a finding that names one of this task's three files, fix forward (correct the added
prose) rather than discarding uncommitted work; if it surfaces only pre-existing staleness
findings, report them and close — the remedy is the user's own manual
`timeout 540 bash .claude/scripts/deploy-headless.sh`, never a hand-patch under `.claude/**`.
