# Research Report: Task #458

**Task**: 458 - consolidate_duplicated_todo_implementation
**Started**: 2026-11-13
**Completed**: 2026-11-13
**Effort**: medium (one authoritative implementation + a 6-site bug fix + registry reconciliation)
**Dependencies**: None (revival of an abandoned record; the record it was abandoned into,
`systematic_script_and_test_corpus_efficiency`, is now fully `completed`/archived, so there is
no live record this work could instead land in)
**Sources/Inputs**: Codebase (agent-system/extensions/core/ source store), specs/state.json,
specs/CHANGE_LOG.md, git log, specs/archive/ (prior abandoned-task artifacts)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- All of the dispatch's core claims re-measured TRUE as of 2026-11-13, with figures shifted
  since the dispatch's 2026-11-02 snapshot: `skills/skill-todo/SKILL.md` is now **1027 lines**
  (not 1120 — it lost ~120 lines to task 499 phase 5's memory-harvest strip, landed 2026-11-10),
  `commands/todo.md` is unchanged at **886 lines**. Combined footprint **1913 lines**, of which
  the never-dispatched skill is **~54%**.
- `skill-todo` has **zero live callers in either consumer system**, not just Claude Code: a
  second deployed `/todo` command exists at `.opencode/commands/todo.md` (and its extension
  mirror) for OpenCode, itself a stale/diverged 1016-line copy, and it ALSO never dispatches
  `skill-todo` or calls `Skill(skill-todo)`. The skill's own `system_context` line
  ("OpenCode task archival...") is a vestige, not evidence of a real OpenCode entry point.
- The `archived_projects`-blind bug fix is genuinely trivial: all six sites are a single jq
  array-selector token (`.completed_projects[]` -> `(.completed_projects + .archived_projects)[]`)
  inside an existing one-line jq filter — zero net line change per site.
- The collision-field check in the dispatch is **stale**: a new non-terminal task (626,
  `wire_todo_review_roadmap_regenerate`, not_started) now names `skill-todo/SKILL.md` in its
  `file_scope`. It is not a hazard — 626 already carries an explicit `dependencies: [625, 436,
  458]` edge sequencing it after this task — but the planner should re-run the collision check at
  plan time rather than trust the dispatch's "clear" snapshot, and should flag for 626's author
  that its wiring target may need to become `commands/todo.md` depending on which implementation
  survives.
- One divergence surface beyond the four the dispatch named: `skill-todo` alone implements a
  **"TODO.md orphan"** detection (a task present in the rendered TODO.md but absent from
  `state.json`), which `commands/todo.md` has no equivalent of at all. Under the project's own
  stated invariant ("TODO.md is generated from state.json... never edit TODO.md directly") this
  condition should be structurally unreachable today, but the planner must decide explicitly
  whether to port it or declare it obsolete — not let it disappear silently as a side effect of
  picking a survivor.
- Recommendation: make `commands/todo.md` the sole authoritative implementation (option (b) —
  full removal of `skill-todo` plus its manifest registration and every dangling registry/lint
  reference), because it is the only one either consumer system actually dispatches, it is the
  one `context/reference/state-management-schema.md` already names as the live vault-renumbering
  path (zero change needed there), and it is the smaller, more recently maintained of the two.

## Context & Scope

This is a revival of the abandoned record `todo_consolidate_and_optimize` (archived as task 307,
empty artifact directory — no prior report/plan/summary exists to build from). The record it was
abandoned into, `systematic_script_and_test_corpus_efficiency` (task 328), is now fully
`completed` and archived — so the question of whether that record "could absorb" this work is
now moot on an even stronger ground than the dispatch's stated one (a behavior-preservation
acceptance-criterion mismatch): 328 cannot absorb anything further because it no longer exists as
a live record. Its plan file (`specs/archive/328_.../plans/03_markdown-corpus-consolidation.md`)
mentions `skill-todo` zero times, confirmed; it mentions the literal string `CHANGE_LOG` twice,
but both are incidental references to a different task's own archival record, not to the
CHANGE_LOG-staleness gap this dispatch describes — so the dispatch's substantive claim ("the work
is not in its plan") holds even though its literal "CHANGE_LOG ZERO times" wording does not.

Scope for this research pass: re-verify every measured claim in the dispatch against the live
source store (`agent-system/extensions/core/`), re-run the collision-field check, and surface any
divergence or risk the dispatch did not already name, so the subsequent plan phase can proceed
directly to a phased implementation without re-deriving the same facts.

## Findings

### Codebase Patterns

**Duplication footprint (re-measured, 2026-11-13)**:
- `commands/todo.md`: 886 lines. `skill-todo` string count: 0. `CHANGE_LOG` string count: 0.
  Allowed-tools line carries no `Skill` entry, confirming it structurally cannot dispatch the
  skill.
- `skills/skill-todo/SKILL.md`: **1027 lines** (down from the dispatch's quoted 1120 — task 499
  phase 5, "strip the archive-time memory harvest from /todo", landed 2026-11-10 and removed 120
  lines of memory-harvest stage from this file specifically; `commands/todo.md` never had that
  stage to begin with, confirming the two files have been drifting independently in both
  directions, not just growing in parallel). `CHANGE_LOG` string count: 11.
- Combined: 1913 lines; the never-dispatched skill is 1027/1913 ≈ 53.7% of the combined surface.
- `skill-todo`'s own frontmatter `description`, `<role>`, and `<task>` lines still advertise
  "memory harvest suggestions" even though the actual harvest stage was replaced
  (2026-11-10) with a comment explaining memory_candidates are now harvested elsewhere in bulk.
  This self-description staleness is independent evidence the skill is unmaintained relative to
  its own body, reinforcing the choice of which file should survive.

**Zero live callers, confirmed across BOTH consumer systems** (not just Claude Code, which is
all the dispatch checked):
- `agent-system/extensions/core/commands/todo.md`: no `skill-todo`/`Skill(` reference.
- `.opencode/commands/todo.md` (OpenCode's deployed `/todo`, 1016 lines, itself a stale/diverged
  third copy of the command relative to the current core source — distinct from this task's
  scope, noted only as corroborating evidence) and its extension mirror
  `.opencode/extensions/core/commands/todo.md`: no `skill-todo`/`Skill(` reference either.
- `skill-todo`'s own `<system_context>` line reads "OpenCode task archival with changelog
  tracking and memory suggestions" — the only skill in the whole manifest with "OpenCode" in its
  system_context — but this is not backed by any actual OpenCode dispatch path; it is a vestige
  of an earlier design intent, not a live second entry point.

**Registry/reference footprint of `skill-todo` outside its own directory** (re-enumerated,
2026-11-13; this is larger than the dispatch's "21 files" figure because that figure was itself
presented as approximate and due for re-measurement):
- `manifest.json` (line 82, inside the `extension.skills` registration array — this is the
  registration that must be removed under option (b))
- `README.md`
- `.claude-extensions.json`
- `context/architecture/system-overview.md` (line 417 — the misleading routing row)
- `context/reference/skill-agent-mapping.md` (line 39)
- `merge-sources/claudemd.md` (line 165)
- `context/reference/state-management-schema.md` — **mentioned by the dispatch as needing
  correction, but on inspection it ALREADY names `commands/todo.md`'s Step 5.7.7 as the live
  vault-renumbering path and explicitly quarantines `scripts/deprecated/vault-operation.sh` as
  not-live. Zero change needed here if `commands/todo.md` is kept as the survivor.**
- `scripts/skill-base.sh`, `scripts/validate-state.sh`,
  `scripts/lib/engine-written-state-paths-lib.sh` (code comments only)
- `scripts/tests/test-todo-move-pair-staging.sh` (18+ mentions — a dedicated behavioral+static
  test shape for `skill-todo`'s Stage 15 `moved_paths[]` accumulator pattern; see Risks below)
- `scripts/tests/test-validate-state.sh` (one fixture, "(h)", pins an archive-writer shape
  specific to `skill-todo`'s "Archive TODO.md orphans" step)
- `scripts/lint/lint-state-writer-boundary.sh`, `scripts/lint/lint-postflight-boundary.sh`
- `scripts/deprecated/README.md` (already correctly describes `commands/todo.md` as the
  authoritative implementation for the archival/orphan/vault behaviors it quarantined scripts
  for; does not currently claim `skill-todo` is authoritative anywhere)
- `context/patterns/roadmap-update.md`, `context/patterns/context-protective-lead.md`,
  `context/patterns/task-lock.md`, `context/standards/git-staging-scope.md`,
  `context/standards/task-reference-exemptions.md`
- Three files in the **email extension** (`email/README.md`,
  `email/context/project/email/design/email-to-memory-preferences.md`,
  `email/skills/skill-email-cleanup/SKILL.md`): these cite `skill-todo`'s former memory-harvest
  stages as a design pattern to reuse ("logic only, never its [implementation]"). **Out of this
  task's file_scope and out of scope for this task's plan** — flagged under Risks below because
  at least one of them may already be stale independent of this task (the harvest stage it cites
  was itself removed from `skill-todo` on 2026-11-10), which the planner should not attempt to
  fix here.

None of the index-entries.json files anywhere under `agent-system/extensions/` contain a
`skill-todo` entry, so there is no index-registration dangle to clean up beyond `manifest.json`
itself.

**`file_scope` vs. the full reference footprint**: task 458's own `file_scope` (set at creation)
lists only `commands/todo.md`, `skills/skill-todo/SKILL.md`,
`context/architecture/system-overview.md`, `context/reference/skill-agent-mapping.md`,
`context/reference/state-management-schema.md`, `manifest.json`, and `merge-sources/claudemd.md`
— narrower than the full reference footprint enumerated above. `file_scope` is anticipatory, not
binding, so the plan phase should simply note the wider actual touch-set (particularly the two
test files, the two lint scripts, and the four remaining context/pattern files) rather than treat
the stored `file_scope` as a ceiling.

### The `archived_projects`-blind bug — re-verified, all six sites

Re-derived line numbers (confirmed to match the dispatch's claim exactly, i.e. unchanged since
2026-11-02):
- `commands/todo.md` lines 71, 88, 127 — three jq filters, each
  `'.completed_projects[] | select(.project_number == ($n | tonumber)) | .project_number'`
  against `specs/archive/state.json`, for orphans-in-specs, orphans-in-archive, and the
  misplaced-directory scan (section 2.6) respectively.
- `skills/skill-todo/SKILL.md` lines 246, 263, 294 — the same three scans, same defective filter.

The fix at every site is a single in-place token change inside an already-existing one-line jq
expression: `.completed_projects[]` -> `(.completed_projects + .archived_projects)[]`. This is a
**zero-net-line-change** fix per site (3 sites in whichever file survives); it is not a
structural rewrite.

### A fourth divergence surface not named in the dispatch: "TODO.md orphan" detection

`skills/skill-todo/SKILL.md` (lines 232, 348, 449-499) implements a distinct detection pass:
tasks that appear in the rendered `TODO.md` but have no corresponding `state.json` entry
("TODO.md orphans"), writing a sparse `completed_projects` entry with `created_at:
"TODO.md_orphan"` as a marker. `commands/todo.md` has **zero** matching logic — grep for
`TODO.md_orphan`/"TODO.md orphan" returns nothing in it. `scripts/tests/test-validate-state.sh`'s
fixture (h) specifically pins the archive-validator's acceptance of this exact writer shape,
citing it as "skill-todo's... write shape."

Under this project's own stated invariant (CLAUDE.md: "TODO.md is generated from state.json...
Never edit TODO.md directly for status or artifact changes"), a TODO.md entry with no
corresponding state.json entry should be structurally unreachable under current tooling — this
detection most likely predates (or guards against a regression of) that invariant being
mechanically enforced. It is NOT in this dispatch's acceptance-criteria list of behaviors that
must be preserved. The planner must make an **explicit** call: port it into `commands/todo.md`
(cheap — it is detection-only, not a separate write path) or deliberately drop it as obsolete and
say so in the plan, rather than have it vanish as a side effect of deleting `skill-todo`.
`test-validate-state.sh`'s fixture (h) can keep pinning the *validator's* acceptance of the
`created_at`/no-`task_type` shape regardless of which implementation (if any) still produces it —
the fixture only needs its comment's attribution updated if `skill-todo` is removed.

### External Resources

Not applicable — this is a pure internal consolidation of two markdown-prose implementations and
their registry footprint; no external library or API research was needed.

## Recommendations

1. **Make `commands/todo.md` the sole authoritative implementation; remove `skill-todo` entirely
   (option (b), not the thin-delegator option (a)).** Rationale: it is the only implementation
   either consumer system (Claude Code or OpenCode) ever actually dispatches; it is smaller (886
   vs. 1027 lines) and more recently/consistently maintained (its own description carries no
   stale claims, unlike `skill-todo`'s); and `context/reference/state-management-schema.md`
   already names it as the authoritative vault-renumbering path, so keeping it as the survivor
   requires zero change to that document. A thin delegator would still leave a second registered
   entry point with no current consumer, directly against the dispatch's own net-deletion framing
   and the backlog-wide additive-vs-reductive doctrine it cites.
2. **Fix the `archived_projects`-blind bug in `commands/todo.md` first** (the single-token jq fix
   at lines 71, 88, 127), before removing `skill-todo`, so the fix is validated against a live,
   dispatched file rather than ported from a file about to be deleted.
3. **Explicitly resolve the TODO.md-orphan divergence** (see Findings) in the plan: either add a
   short detection pass to `commands/todo.md` mirroring `skill-todo`'s lines 449-499, or record a
   reasoned decision that it is obsolete under the TODO.md-is-generated invariant. Either way,
   state the decision in the plan text so it is not a silent loss.
4. **Removal checklist for `skill-todo`** (option (b)'s "together with" requirement): delete
   `skills/skill-todo/SKILL.md`; remove its entry from `manifest.json`'s `extension.skills` array
   (line 82); remove its row from `context/reference/skill-agent-mapping.md` (line 39) and
   `merge-sources/claudemd.md` (line 165); correct `context/architecture/system-overview.md` line
   417 (see item 5); update the remaining registry/lint/pattern mentions listed in Findings
   (`context/patterns/roadmap-update.md`, `context/patterns/context-protective-lead.md`,
   `context/patterns/task-lock.md`, `context/standards/git-staging-scope.md`,
   `context/standards/task-reference-exemptions.md`, `scripts/skill-base.sh`,
   `scripts/validate-state.sh`, `scripts/lib/engine-written-state-paths-lib.sh`,
   `scripts/lint/lint-state-writer-boundary.sh`, `scripts/lint/lint-postflight-boundary.sh`) so
   each describes the post-removal state rather than citing a file that no longer exists; leave
   the three email-extension mentions alone (out of file_scope, out of this task's blast radius —
   do not touch another extension's files from this task).
5. **Correct `context/architecture/system-overview.md` line 417** from
   `| /todo | Direct | skill-todo | (no agent) | B |` to name no skill (e.g.
   `| /todo | Direct | (direct execution) | (no agent) | B |`, matching the phrasing already used
   for `/review` and `/errors` two rows above it in the same table) — net zero line-count change,
   text swap only.
6. **Rewrite `scripts/tests/test-todo-move-pair-staging.sh`'s "Stage 15" shape** (the
   `skill-todo`-specific behavioral+static test pair for its `moved_paths[]` accumulator) by
   deleting it rather than porting it: `commands/todo.md`'s own three existing shapes (Step
   5D/5E.1/5F) already fully cover the inline-accumulator pattern it uses, and `skill-todo`'s
   enumerated-list pattern has no surviving subject to test once the file is removed. This
   satisfies the acceptance criterion's "still pass or are updated with their assertions' intent
   preserved" — the intent (pin that every move pairs its destination with its vacated source in
   the commit) is fully preserved by the three remaining shapes.
7. **Add the required fixture/test for the `archived_projects` fix**: no existing test exercises
   `commands/todo.md`'s orphan/misplaced-directory scans directly (`test-deploy-orphans.sh` is an
   unrelated whole-tree deploy-orphan gate, not this scan). The plan should add a small fixture —
   either a new case in `test-todo-move-pair-staging.sh` or a new dedicated test file — that
   plants an abandoned-then-archived task directory (one entry in `specs/archive/state.json`'s
   `archived_projects[]`, matching directory present) and asserts it is NOT reported as an
   orphan, pinning the fix.
8. **Re-run the collision-field check at plan time, not from this report's snapshot.** Task 626
   (`wire_todo_review_roadmap_regenerate`, not_started) now names `skills/skill-todo/SKILL.md` in
   its `file_scope` and already depends on 458 (`dependencies: [625, 436, 458]`) for exactly this
   reason — it is correctly sequenced, not a live collision, but its own wiring target
   (`skill-todo`) will need to become `commands/todo.md` once this task lands, since the file it
   names to wire will no longer exist. Flag this for whoever next revises task 626's description
   or plan; do not silently fix 626 from within this task.

## Decisions

- This task is the correct vehicle for the revived work: the record it was abandoned into
  (`systematic_script_and_test_corpus_efficiency`, task 328) is now fully `completed` and
  archived, so there is no live alternative record this could be folded into instead.
- `commands/todo.md` is recommended as the survivor over `skill-todo`, for the reasons in
  Recommendation 1. This is a recommendation for the plan phase to adopt or override with
  reasoning, not a decision this research report can bind the plan to.
- The CHANGE_LOG staleness evidence (see Risks) is cited only as motivation; per the dispatch,
  fixing CHANGE_LOG itself is explicitly out of scope and owned by
  `cross_task_traceability_and_changelog_verdict`.

## Risks & Mitigations

- **Risk**: deleting `skill-todo` silently drops the "TODO.md orphan" detection capability.
  **Mitigation**: Recommendation 3 above — require an explicit decision in the plan rather than
  let removal be silent.
- **Risk**: `scripts/tests/test-todo-move-pair-staging.sh` and `test-validate-state.sh` fixture
  (h) both carry prose that attributes behavior to `skill-todo` by name; a careless removal could
  leave stale comments even if the mechanical assertions still pass. **Mitigation**:
  Recommendations 6 and the plan's reconciliation pass should explicitly update both files'
  comments, not just their code.
- **Risk** (adjacent, not this task's to fix): the email extension's
  `email-to-memory-preferences.md` cites "skill-todo's... harvest stages" as a design pattern to
  reuse, but those stages were themselves already removed from `skill-todo` on 2026-11-10 (task
  499 phase 5) — independent of whether this task deletes the rest of the file. **Mitigation**:
  none within this task's scope; noted here only so a future task addressing the email design doc
  is not surprised. Do not expand this task's file_scope to cover it.
- **Risk**: the dispatch's measured "73 archived tasks absent from CHANGE_LOG since 2026-10-04"
  figure is now stale in the same direction it describes — CHANGE_LOG.md's newest entry is dated
  2026-11-05, and four further archival runs have landed since (2026-11-06: 25 tasks, 2026-11-10:
  20, 2026-11-11: 12, 2026-11-13: 25 — 82 tasks, re-measured 2026-11-13), confirming the gap is
  still live and widening, not stale evidence of a since-fixed problem. **Mitigation**: none
  needed for this task (CHANGE_LOG fixing is explicitly out of scope); cited only so the plan
  phase does not need to re-derive this corroboration itself.

## Context Extension Recommendations

- **Topic**: cross-consumer `/todo` divergence (Claude Code vs. OpenCode deploy trees).
- **Gap**: this research surfaced that `.opencode/commands/todo.md` is itself a stale,
  independently-diverged 1016-line copy of the command relative to the current
  `agent-system/extensions/core/commands/todo.md` source (missing the `expanded`-status handling,
  roadmap-scan step, and session-id generation the current core version has). No existing context
  file documents OpenCode-deploy staleness as its own tracked category the way
  `context/patterns/jq-escaping-workarounds.md` or similar living-reference docs track other
  recurring gaps.
- **Recommendation**: out of scope for this task to fix (task 458's file_scope is the core source
  store only), but worth a future `/task` or `/spawn` entry if the OpenCode deploy track is meant
  to stay current with the core source store at all. Not acted on here.

## Appendix

- Search queries used: `grep -n "skill-todo"` across `commands/todo.md`, `manifest.json`, and
  every file under `agent-system/extensions/` outside `skills/skill-todo/`; `grep -n
  "completed_projects\|archived_projects"` in both `/todo` implementations; `grep -n "Vault
  Operation\|renumber"` in both; `jq` queries over `specs/state.json`'s `active_projects[]` for
  `file_scope` collisions and over `specs/archive/state.json` for task 328's and task 380's
  terminal status; `git log --oneline -- <path>` for `skills/skill-todo/SKILL.md`'s recent
  history; `git log --format="%ad %s" --date=short -- | grep "todo: archive"` for the CHANGE_LOG
  staleness re-measurement.
- References: `agent-system/extensions/core/commands/todo.md`,
  `agent-system/extensions/core/skills/skill-todo/SKILL.md`,
  `agent-system/extensions/core/manifest.json`,
  `agent-system/extensions/core/context/architecture/system-overview.md`,
  `agent-system/extensions/core/context/reference/state-management-schema.md`,
  `agent-system/extensions/core/scripts/tests/test-todo-move-pair-staging.sh`,
  `agent-system/extensions/core/scripts/tests/test-validate-state.sh`,
  `agent-system/extensions/core/scripts/deprecated/README.md`, `specs/state.json`,
  `specs/CHANGE_LOG.md`, `specs/archive/307_todo_consolidate_and_optimize/` (empty — no prior
  artifacts), `specs/archive/328_systematic_script_and_test_corpus_efficiency/`.
