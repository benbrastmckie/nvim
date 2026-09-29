# Implementation Plan: Task #162

- **Task**: 162 - Formalize "Files to modify" and harvest file_scope
- **Status**: [NOT STARTED]
- **Effort**: 6.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/162_formalize_files_to_modify_and_harvest_file_scope/reports/01_files-to-modify-harvest.md
- **Artifacts**: plans/01_files-to-modify-harvest.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Formalize the already-universal `**Files to modify**:` per-phase plan convention in
`plan-format.md`, build a harvester that unions every phase's list into a deduplicated JSON array,
and wire that harvest into every plan-postflight call site so `state.json`'s
`active_projects[].file_scope` is populated at PLAN time via the existing mutex-guarded
`state-write.sh` path. A second, reuse-only deliverable (absorbed from a former sibling task)
backfills `file_scope` for existing plan-bearing tasks across repos by calling the same harvester,
with a dry-run, idempotence, and an explicit recorded disposition for plan-less tasks. The
convention is not being invented and the heading string is not changing — three named consumers
depend on that string verbatim and stay untouched.

### Research Integration

The research report (`reports/01_files-to-modify-harvest.md`) changes the shape of this work in
four ways that this plan adopts directly:

1. **Coverage is 18/18 local plan files, not 10/10** (the dispatch figure was accurate when
   written; more tasks exist now). Only the colon-outside-bold form `**Files to modify**:` is
   attested locally (zero occurrences of `**Files to modify:**`), but both forms must be accepted
   per plan-format.md's existing field-punctuation-tolerance rule.
2. **No new write path is needed.** `update-task-status.sh` already implements exactly the required
   union-merge under `--file-scope-add=<json-array>`
   (`.file_scope = ((.file_scope // []) + $add | unique)`), riding inside its existing single
   `state-write.sh` invocation. It is hard-restricted to
   `operation==postflight && target_status==research`; widening that restriction to also accept
   `target_status==plan` is the whole change.
3. **`postflight ... plan ...` is called from four locations, not one**:
   `orchestrator-postflight.sh` Stage 7 (~line 360), `reconcile-task-status.sh:558` and `:678`,
   and `skill-reviser/SKILL.md:324`. All four already hold the plan path in a local variable.
   Wiring only the first would silently leave `/revise` and the reconciliation self-heal path
   uncovered.
4. **Grammar has three real-world wrinkles** the harvester must handle: backtick-quoted path plus
   trailing ` - {description}`; indented wrapped continuation lines that are NOT new entries; and
   at least one attested prose/"none planned" sentinel line that must contribute nothing rather
   than erroring the harvest.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; ROADMAP.md was not consulted.

## Goals & Non-Goals

**Goals**:
- `plan-format.md` enumerates `**Files to modify**:` in its per-phase field list, marked
  **required**, with its list-item grammar and both accepted punctuation forms, positioned between
  `Scope Hypothesis` and `Owner` to match the planner template's own emission order.
- `plan-format.md` records the field's consumers (the three heading-name-stability consumers plus
  the new grammar-parsing harvester), mirroring the existing "Consumers of this heading contract"
  subsection, and states that `**Scope Hypothesis**:` is deliberately NOT a harvest source.
- A new `plan-file-scope-harvest.sh` extracts the deduplicated union of every phase's
  `Files to modify` paths from a plan file and emits a JSON array on stdout.
- Every plan postflight (including `/revise` and reconciliation self-heal) additively merges that
  harvest into `file_scope` through `update-task-status.sh --file-scope-add`, never a hand-rolled
  jq read-modify-write.
- A one-shot backfill script populates `file_scope` for existing plan-bearing tasks, reusing the
  harvester (never re-implementing extraction), with `--dry-run`, idempotence, `--state-file` for
  cross-repo targets, and a never-overwrite guard.
- All new and changed shell is shellcheck-clean per `context/standards/shell-strict-mode.md`.

**Non-Goals**:
- Changing the heading string `Files to modify` in any way. The three consumers named in the
  dispatch embed it verbatim in prompt directives with no parse error on mismatch; it is frozen.
- Filesystem-validating harvested paths or dropping paths that do not yet exist. `file_scope` is
  documented prospective, and new files are exactly what a plan creates.
- Overwrite or subtractive semantics on `file_scope` anywhere (see Decision 1).
- Parsing `**Scope Hypothesis**:` prose for paths (see Decision 5).
- Promoting `validate-artifact.sh` to check for a missing `**Files to modify**:` field. Documenting
  a field as required and gating validation on it are separate concerns, and plan-format.md's own
  "Enforcement level" subsection already establishes the advisory-first-then-promote staging for
  exactly this situation. No acceptance criterion in this task asks for validator enforcement; it
  is a clean follow-up once this field's documentation has landed.
- Inferring a provisional `file_scope` for plan-less tasks, and writing an `[]` sentinel for them
  (see Decision 6).
- Editing any deployed `.claude/**` file by hand. All source edits target
  `/home/benjamin/.config/nvim/agent-system/extensions/core/`; `.claude/` is regenerated by the
  loader in Phase 6.

## Decisions

These resolve every "DECIDE, DO NOT ASSUME" item in the dispatch. Each must be recorded in the
implementation summary as well as in the code/doc comments named in its phase.

1. **Union, not overwrite.** The harvest additively merges into any existing `file_scope`. Every
   existing writer in this codebase is additive (creation-time declaration; the research-time
   `proposed_file_scope` consumer), and `update-task-status.sh`'s own flag documents itself as
   "never a replacement, never subtractive". Overwriting would discard a creation-time declaration
   and any research-round merge already landed.
2. **Yes, a plan revision re-harvests.** Every `postflight ... plan ...` call re-runs the harvest,
   including `/revise` and reconciliation self-heal. This is safe and idempotent precisely because
   the merge is additive: a revision that drops a phase's file mention does not retract it from
   `file_scope` (consistent with "prospective, never dropped" — `file_scope` is not expected to
   shrink), and a revision that adds phases contributes their new files. This is why Phase 4 wires
   all four call sites rather than only `orchestrator-postflight.sh`.
3. **A harvest failure is a loud non-fatal warning, never fatal to postflight.** This matches the
   surrounding posture verbatim: `orchestrator-postflight.sh` Stage 7 already wraps its
   `update-task-status.sh` call in `|| echo "[postflight] WARNING: ... (non-blocking)"`, and
   `update-task-status.sh`'s own no-op file_scope merge branch already prints
   `"Warning: ... (non-fatal)"`. A plan postflight must never be blocked by a plan file with
   unusual formatting or by a script bug.
4. **The field is documented required; validator gating is deferred.** Coverage is already 18/18
   and the planner template emits it unconditionally, so "required" describes reality rather than
   aspiring to it — unlike `Verification Tier`, which started sparse and needed an advisory-first
   rollout. Validator enforcement is an explicit Non-Goal above, not an oversight.
5. **`**Scope Hypothesis**:` does not inform the harvest.** It is free-form prose about a claim to
   confirm, not a structured file enumeration, and its own definition in plan-format.md routes
   structured file-list content through the `Files to modify` carrier. No attested phase names a
   file in Scope Hypothesis that is absent from that same phase's `Files to modify` list. Parsing
   it would require fragile prose-parsing for zero new information. Phase 1 records this inline so
   a future reader does not "fix" the harvester into doing it.
6. **Plan-less tasks: leave `file_scope` absent (option (a)).** Rejecting the alternatives
   explicitly: option (b), inferring from the description, produces a value that is *worse than
   absence* when wrong, because the collision guard then reports false confidence rather than a
   known gap; option (c), an `[]` sentinel, reads as "touches nothing" to a consumer and would
   suppress the very absent-scope warning that should stay lit. With plan-time harvest now in
   place (Phases 1-4), a plan-less task acquires a real `file_scope` the moment it is planned, so
   the gap closes on its own along the normal lifecycle rather than being papered over. The
   backfill script must report this population by count, so the gap is visible rather than silent.
7. **The backfill is cross-repo capable via `--state-file`, deriving the repo root from that
   path.** The measured need is not local: this repo is at 29/30 with `file_scope` and its one
   uncovered task has no plan (so Decision 6 applies and the local backfill is a legitimate
   no-op), whereas `~/Projects/BimodalLogic` is at 27/62, of which 8 uncovered tasks are
   plan-bearing and therefore reachable. A repo-local-only tool would not address the motivating
   case. `state-write.sh` already supports `--state-file` for non-default targets.
8. **A cross-repo real run leaves the target repo uncommitted.** Phase 6 runs the backfill against
   `~/Projects/BimodalLogic` after inspecting its dry-run diff, but does NOT commit inside another
   repository; the resulting `specs/state.json` change is reported in the summary for the user to
   review and commit themselves.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer wires only `orchestrator-postflight.sh`, reading the dispatch's singular "plan postflight" narrowly | `file_scope` silently stops accumulating on `/revise` and reconciliation paths; behavior differs by invocation path | Medium | Phase 4 enumerates all four call sites as separate checklist items with file:line anchors, and its verification greps for four `--file-scope-add` occurrences |
| Harvester mistakes an indented wrapped continuation line for a new path entry | Bogus path added to `file_scope`, polluting the collision guard | Medium (plans are prose, hand/LLM-authored) | Anchor a new entry strictly on `^- \`` after the field header; treat every other line in the block as a continuation contributing nothing. Dedicated test case in Phase 2 |
| A phase legitimately says "none planned" in prose (attested once in 18 files) | Harvester errors out, or fabricates a path from prose | Low | Explicit no-match-contributes-nothing behavior; non-zero exit reserved for usage errors only (missing/unreadable file argument), never for "found nothing". Dedicated test case |
| Widening `--file-scope-add`'s restriction regresses the existing test that asserts the research-only rejection | `test-update-task-status.sh` case 11f fails | Medium (case 11f exists at line ~513 and exercises `preflight`/`implement`) | Phase 3 reads case 11f before editing, updates the restriction's error text to name both allowed target statuses, and keeps 11f meaningful by leaving its `preflight` axis intact while adding a `plan`-accepted case |
| Backfill re-implements path extraction instead of calling the harvester | Two divergent parsers for one convention — precisely the defect this work removes | Low-Medium | Phase 5 requires the backfill to invoke `plan-file-scope-harvest.sh` as a subprocess; its verification greps the backfill for any independent `Files to modify` pattern and fails if one exists |
| Backfill overwrites an existing non-empty `file_scope` | Loss of a hand-declared scope | Low | Hard guard: skip any task whose `file_scope` is already non-empty; dedicated idempotence and never-overwrite test cases |
| Cross-repo write corrupts another repo's state.json | Another repo's task state damaged | Low | All writes go through `state-write.sh --state-file` (mutex-guarded, staged); dry-run inspected before any real cross-repo run; changes left uncommitted for user review (Decision 8) |
| Sibling tasks are dispatched into this same working tree this cycle | A file is changed underneath this task, or this task's commit captures foreign hunks | Medium (the dispatch names several concurrent siblings) | No sibling's declared `file_scope` overlaps this plan's file set; still, re-read every file immediately before editing, stage only this task's own explicit file list (never a directory or glob pathspec), and STOP and report any foreign commit or modification observed |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4, 5 | 2, 3 (Phase 4); 2 (Phase 5) |
| 3 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Formalize the field in plan-format.md [NOT STARTED]

**Goal**: `plan-format.md` enumerates `**Files to modify**:` as a required per-phase field with its
grammar, names its consumers as compatibility constraints, and forecloses Scope Hypothesis as a
second harvest source.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/formats/plan-format.md`'s
      "Implementation Phases (format)" per-phase field list immediately before editing.
- [ ] Insert a `- **Files to modify:** (required)` bullet between the `Scope Hypothesis` bullet and
      the `Owner` bullet, matching the planner template's own field order
      (`agents/planner-agent.md` emits `Files to modify` directly after `Scope Hypothesis`).
- [ ] State the list-item grammar in that bullet: one `- \`path\`` entry per line, each optionally
      followed by ` - {description}` free text that is not part of the path; wrapped continuation
      lines belong to the preceding entry; a line that is not a backtick-path entry (e.g. a
      "none planned" prose sentinel) contributes no path.
- [ ] State that both punctuation forms (`**Files to modify**:` and `**Files to modify:**`) are
      accepted, cross-referencing the existing "Field-punctuation tolerance" paragraph rather than
      restating its rule.
- [ ] Add a "Consumers of this field" subsection mirroring the structure of the existing
      "Consumers of this heading contract" subsection, listing: `agents/general-implementation-agent.md`
      (reads "Files to modify/create per phase" when extracting from the plan — heading-name
      stability only); `skills/skill-orchestrate/SKILL.md`'s H1 territory block (points an agent at
      the phase location, does not parse the list — heading-name stability only);
      `scripts/orchestrate-cycle-plan.sh`'s verbatim port of that same derivation (heading-name
      stability only); and `scripts/plan-file-scope-harvest.sh` (the one consumer that actually
      depends on list-item shape). State explicitly that the heading text is frozen because the
      first three embed it in a prompt directive where a mismatch fails silently with no parse
      error.
- [ ] Add a one-line cross-reference at the "Counts-are-hypotheses obligation" subsection stating
      that `**Scope Hypothesis:**` is deliberately not a harvest source for `file_scope` and
      naming `Files to modify` as the structured carrier (Decision 5).
- [ ] Confirm no task numbers appear in the added text (this file lives outside `specs/**`).

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/formats/plan-format.md` - add the required
  `**Files to modify:**` per-phase field with grammar, add a "Consumers of this field" subsection,
  add the Scope-Hypothesis-is-not-a-harvest-source cross-reference

**Verification**:
- `grep -n 'Files to modify' agent-system/extensions/core/context/formats/plan-format.md` shows the
  new field bullet, the consumers subsection, and the Scope Hypothesis cross-reference.
- The new bullet sits textually between the `Scope Hypothesis` and `Owner` bullets.
- All four consumers are named. Diff read-through confirms every changed hunk is prose.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` reports no new violation.

---

### Phase 2: Build plan-file-scope-harvest.sh with its test suite [NOT STARTED]

**Goal**: A standalone, shellcheck-clean harvester emits the deduplicated union of a plan's
per-phase `Files to modify` paths as a JSON array, tolerating every grammar wrinkle attested in the
research.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` with Class A strict
      mode (`set -euo pipefail`) per `context/standards/shell-strict-mode.md`'s default-for-new-scripts
      rule — nothing about this script matches the Class B "report everything" admission test.
- [ ] Contract, documented in the script header: one positional argument (a plan file path);
      stdout is a JSON array of strings; stdout is `[]` when the plan has no harvestable path;
      non-zero exit is reserved for genuine usage errors (missing argument, unreadable file) and
      is NEVER used for "found nothing".
- [ ] Accept both `**Files to modify**:` and `**Files to modify:**` as the block header.
- [ ] Inside a block, start a new path entry only on a line matching `^- \`` and take the first
      backticked token as the path; discard any trailing ` - {description}`; treat every other
      line as a continuation or prose that contributes nothing; end the block at the next blank
      line followed by a non-list line, the next `**Field**:` label, or the next `###` heading
      (whichever comes first).
- [ ] Union and deduplicate across every phase in the file; emit in a stable (sorted) order so
      output is reproducible.
- [ ] Never stat, resolve, or filter by filesystem existence — paths not yet created are exactly
      what a plan carries (Non-Goal above, and the schema's "prospective, not filesystem-validated"
      wording).
- [ ] Create `agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` following
      the conventions of the existing suites in that directory, covering: both punctuation
      variants; backtick-path with trailing description; an indented wrapped continuation line
      contributing nothing; a "none planned" prose sentinel contributing nothing; multi-phase
      union and dedup; a plan with zero `Files to modify` occurrences returning `[]` with exit 0;
      a missing-file argument exiting non-zero.
- [ ] Run the new suite and shellcheck both new files.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the harvester needs exactly two new files and no edits to
existing scripts. Confirm at implementation time by checking that no existing script already
extracts `Files to modify` paths (`grep -rn 'Files to modify' agent-system/extensions/core/scripts/`
should show no pre-existing extractor before this phase, only the consumers named in Phase 1); if
one exists, extend it instead of adding a second parser.

**Files to modify**:
- `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` - new harvester script
- `agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` - new test suite

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` passes with
  every case above green.
- `shellcheck` clean on both new files.
- Run the harvester over all 18 local plan files
  (`for f in specs/*/plans/*.md; do ... done`): every file yields a non-empty JSON array, output is
  valid JSON per `jq -e 'type == "array"'`, and no emitted entry contains a backtick, a leading
  `- `, or a ` - ` description fragment.

---

### Phase 3: Widen --file-scope-add to accept target_status=plan [NOT STARTED]

**Goal**: `update-task-status.sh` accepts `--file-scope-add` on `postflight ... plan ...` with its
union-merge and validation otherwise unchanged, and its test suite covers the widened restriction.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/update-task-status.sh` lines ~218-260 (the
      `--file-scope-add` validation block) and its header comment block (~lines 53-70) immediately
      before editing.
- [ ] Change the restriction guard from `target_status != research` to reject only when
      `target_status` is neither `research` nor `plan`, leaving the `operation != postflight`
      condition intact.
- [ ] Update the restriction's error message to name both permitted target statuses, so the
      failure text stays accurate.
- [ ] Update the header comment block to document the plan-postflight consumer alongside the
      existing research one, and to restate that semantics are unchanged (additive union, never a
      replacement, never subtractive).
- [ ] Verify the merge clause (~line 768) and the no-op branch (~line 697) need no change — they
      are keyed off `FILE_SCOPE_ADD_LEN`, not off `target_status`.
- [ ] Read existing test case 11f (`test-update-task-status.sh` ~line 513) before editing; it
      currently asserts rejection on `preflight 1 implement`. Keep that axis (the
      `operation != postflight` half of the guard is unchanged) and add a case asserting
      `postflight N plan ... --file-scope-add=[...]` is accepted and merges additively, plus a case
      asserting a still-rejected `postflight N implement` combination.
- [ ] Grep the test suite for the literal old error string before changing it, and update any
      assertion that matches on it.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/update-task-status.sh` - widen the `--file-scope-add`
  target_status restriction to `research|plan`, update its error message and header comment
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` - add plan-accepted and
  implement-still-rejected cases; update any assertion matching the old error text

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-update-task-status.sh` passes in full,
  including the pre-existing case 11 family.
- `shellcheck` clean on both changed files.
- A direct probe confirms `postflight <N> plan <sid> --file-scope-add='["x"]' --dry-run` exits 0
  and reports the union-merge, while `postflight <N> implement <sid> --file-scope-add='["x"]'`
  still exits non-zero with an error naming both permitted statuses.

---

### Phase 4: Wire the harvest into all four plan-postflight call sites [NOT STARTED]

**Goal**: Every path that runs `update-task-status.sh postflight <N> plan <sid>` first harvests the
plan file and forwards the result as `--file-scope-add`, treating harvester failure or an empty
result as a non-fatal no-op.

**Tasks**:
- [ ] Re-read each call site immediately before editing (siblings are active in this tree).
- [ ] `scripts/orchestrator-postflight.sh` Stage 7: add a `plan` branch alongside the existing
      `research`/`proposed_file_scope` branch (~lines 348-360), sourcing the JSON array from
      `bash .claude/scripts/plan-file-scope-harvest.sh "$artifact_path"` instead of from
      `.return-meta.json`, and reusing the same
      `[ -n "$x" ] && [ "$x" != "[]" ] && [ "$x" != "null" ]` guard shape that branch already uses.
- [ ] `scripts/reconcile-task-status.sh:558`: compute the harvest from `$plan_file` (already in
      scope, passed to `link_artifact` on the preceding line) and pass `--file-scope-add=<json>`.
- [ ] `scripts/reconcile-task-status.sh:678`: same, for the second call site.
- [ ] `skills/skill-reviser/SKILL.md:324`: same pattern, sourcing from the `$artifact_path` already
      validated in Stage 6a, so `/revise` re-harvests per Decision 2.
- [ ] At every site, wrap the harvester invocation so a non-zero exit or unparseable output degrades
      to "no `--file-scope-add` argument" with a named warning, never a failed postflight
      (Decision 3). Match the existing `|| echo "[postflight] WARNING: ... (non-blocking)"` wording
      convention already present at each site.
- [ ] Honor `--dry-run` where the surrounding call site already threads it (reconcile's
      `Would promote` branches must not write).

**Timing**: 1 hour

**Depends on**: 2, 3

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly four call sites in three files. Confirm at
implementation time with
`grep -rn 'postflight.*"\?plan"\?' agent-system/extensions/core/scripts/ agent-system/extensions/core/skills/`
plus a search for `update-task-status.sh postflight`; if a fifth site exists, wire it too and record
the correction.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` - add the `plan` harvest branch
  in Stage 7
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` - harvest and forward at both
  `postflight ... plan ...` call sites
- `agent-system/extensions/core/skills/skill-reviser/SKILL.md` - harvest and forward at the Stage 7
  postflight call, so `/revise` re-harvests

**Verification**:
- `grep -c 'file-scope-add' ` across the three changed files accounts for all four new sites plus
  the pre-existing research site in `orchestrator-postflight.sh`.
- `shellcheck` clean on both changed scripts.
- `bash agent-system/extensions/core/scripts/tests/test-update-task-status.sh` and
  `test-plan-file-scope-harvest.sh` still pass (no regression from the wiring).
- A simulated failure (harvester invoked against a nonexistent plan path) at the
  `orchestrator-postflight.sh` site prints a warning and leaves the postflight exit status 0.

---

### Phase 5: Backfill script for existing plan-bearing tasks [NOT STARTED]

**Goal**: A one-shot, idempotent, dry-run-capable backfill populates `file_scope` for existing
plan-bearing tasks in any repo's `state.json` by calling the Phase 2 harvester, never overwriting an
existing non-empty `file_scope`, and reporting the plan-less population it deliberately leaves
alone.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/backfill-file-scope.sh`, Class A strict mode.
- [ ] Interface: `[--dry-run] [--state-file PATH]`. Default target is the invoking repo's
      `specs/state.json`; `--state-file` names a cross-repo target and the repo root is derived from
      it (the parent of the state file's directory), so plan paths resolve against the right tree
      (Decision 7).
- [ ] For each task in `active_projects` whose `file_scope` is absent or empty: resolve its latest
      plan artifact (prefer an `artifacts[]` entry of `type == "plan"`; fall back to the
      lexicographically last `specs/{NNN}_*/plans/*.md` under the task's directory), then invoke
      `plan-file-scope-harvest.sh` on it. Never re-implement path extraction — call the harvester as
      a subprocess (this is the whole point of the reuse constraint).
- [ ] Skip, with an explicit per-task reason line, any task that already has a non-empty
      `file_scope`, and any task with no resolvable plan file.
- [ ] Write through `state-write.sh` (passing `--state-file` when targeting a non-default path),
      using the same additive `((. // []) + $add | unique)` merge shape `update-task-status.sh`
      uses. No hand-rolled `jq ... > tmp && mv`.
- [ ] Prefer a single batched `state-write.sh` invocation over one per task if the filter can carry
      all updates; otherwise loop, and say which was chosen in the script header.
- [ ] `--dry-run` prints the proposed per-task diff (task number, resolved plan path, paths that
      would be added) and writes nothing whatsoever.
- [ ] Print a closing summary: tasks backfilled, tasks skipped as already-covered, and the count of
      plan-less tasks deliberately left absent — the visible-gap requirement from Decision 6.
- [ ] Record Decision 6's reasoning in the script header (why not inference, why not an `[]`
      sentinel) so the disposition travels with the code.
- [ ] Add `agent-system/extensions/core/scripts/tests/test-backfill-file-scope.sh` covering, against
      a fixture state file and fixture plan: dry-run writes nothing; a real run populates a
      plan-bearing task; a second run is a byte-for-byte no-op (idempotence); a task with an
      existing non-empty `file_scope` is untouched; a plan-less task is left absent (not `[]`) and
      counted in the summary.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the reachable local population is effectively nil (this
repo measures 29/30 covered, and its single uncovered task has no plan) while
`~/Projects/BimodalLogic` measures 27/62 covered with 8 uncovered tasks that are plan-bearing.
Confirm both counts at implementation time by re-running the coverage query against each
`specs/state.json` before the backfill and again after, and record the actual before/after numbers
in the summary rather than these plan-time figures. The dispatch's "38/38" and "49/49" targets are
stale for the same reason and must not be asserted as outcomes.

**Files to modify**:
- `agent-system/extensions/core/scripts/backfill-file-scope.sh` - new backfill script
- `agent-system/extensions/core/scripts/tests/test-backfill-file-scope.sh` - new test suite

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-backfill-file-scope.sh` passes.
- `shellcheck` clean on both new files.
- `grep -n 'Files to modify' agent-system/extensions/core/scripts/backfill-file-scope.sh` finds
  nothing — proof the backfill does not carry a second parser.
- `grep -n 'state-write.sh' agent-system/extensions/core/scripts/backfill-file-scope.sh` confirms the
  sanctioned writer is the only write path, and no `> tmp && mv` sequence exists.
- `--dry-run` against this repo's live `specs/state.json` prints a diff and leaves
  `git status --short specs/state.json` unchanged.

---

### Phase 6: Deploy, full gate, and end-to-end verification [NOT STARTED]

**Goal**: The source-store changes are deployed, every acceptance criterion is demonstrated against
the deployed tree, and the three frozen-heading consumers are shown unbroken.

**Tasks**:
- [ ] Run `shellcheck` over every new and changed shell file from Phases 2-5.
- [ ] Run the full relevant test set: `test-plan-file-scope-harvest.sh`,
      `test-update-task-status.sh`, `test-backfill-file-scope.sh`.
- [ ] Deploy the source store with `bash .claude/scripts/deploy-headless.sh` and confirm the new
      scripts and the edited `plan-format.md` appear under `.claude/`.
- [ ] Acceptance check 1: `plan-format.md` (deployed copy) enumerates the field with its grammar
      and names its four consumers.
- [ ] Acceptance check 2: the harvester extracts a correct non-empty union from all 18 local plan
      files and accepts both punctuation variants (exercise the second variant with a fixture,
      since it is unattested locally).
- [ ] Acceptance check 3: a plan postflight on a task with a plan populates a non-empty
      `file_scope`. Demonstrate with `--dry-run` against this task's own state entry plus the Phase
      3 direct probe, so the check does not require mutating an unrelated task's status.
- [ ] Acceptance check 4: the three heading-name consumers are demonstrably unbroken — `grep -n
      'Files to modify' ` in `agents/general-implementation-agent.md`,
      `skills/skill-orchestrate/SKILL.md`, and `scripts/orchestrate-cycle-plan.sh` shows the string
      byte-identical to its pre-change form (confirm via `git diff` showing zero changes to that
      string in those files).
- [ ] Acceptance check 5: `backfill-file-scope.sh --dry-run` against this repo (expected: no
      backfillable task, one plan-less task reported as deliberately left absent) and against
      `--state-file ~/Projects/BimodalLogic/specs/state.json` (expected: the 8 plan-bearing
      uncovered tasks itemized). Inspect that diff.
- [ ] Run the real backfill against this repo (expected no-op given Decision 6) and, after the
      dry-run inspection above, against `~/Projects/BimodalLogic`. Re-run each to prove
      idempotence. Do NOT commit inside `~/Projects/BimodalLogic` (Decision 8); record the
      resulting uncommitted `specs/state.json` change in the summary for the user.
- [ ] Record the actual before/after coverage numbers for both repos in the summary, superseding
      this plan's plan-time figures and the dispatch's stale targets.
- [ ] Run `bash agent-system/extensions/core/scripts/check-task-references.sh` to confirm no task
      number leaked into any deliverable outside `specs/**`.
- [ ] Stage and commit only this task's own explicit file list — never a directory or glob
      pathspec, since siblings are active in this tree.

**Timing**: 1.25 hours

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- (none — verification, deploy, and reporting only; the deployed `.claude/**` tree is regenerated
  by the loader, never hand-edited)

**Verification**:
- All three test suites green; shellcheck clean across every changed shell file.
- `deploy-headless.sh` exits 0 and its inline verification passes.
- Every acceptance check above demonstrated with its command output.
- `git diff` proves the literal string `Files to modify` is unchanged in all three frozen-heading
  consumers.
- A second backfill run over each already-backfilled state file produces no change.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` passes,
      covering both punctuation variants, description stripping, wrapped continuations, the prose
      sentinel, multi-phase union/dedup, the empty-result-exit-0 case, and the usage-error case.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-update-task-status.sh` passes, including
      the pre-existing case 11 family plus the new plan-accepted and implement-rejected cases.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-backfill-file-scope.sh` passes, covering
      dry-run-writes-nothing, real-run-populates, idempotence, never-overwrite, and the plan-less
      left-absent case.
- [ ] `shellcheck` clean on every new and changed shell file, per
      `context/standards/shell-strict-mode.md`.
- [ ] Harvester run over all 18 local plan files yields valid, non-empty, clean JSON arrays.
- [ ] `check-task-references.sh` reports no new violation.
- [ ] `deploy-headless.sh` succeeds and its verification step passes.

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/plan-format.md` (edited: required field, grammar,
  consumers subsection, Scope Hypothesis cross-reference)
- `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` (new)
- `agent-system/extensions/core/scripts/backfill-file-scope.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-backfill-file-scope.sh` (new)
- `agent-system/extensions/core/scripts/update-task-status.sh` (edited: widened restriction)
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` (edited: new cases)
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` (edited: plan harvest branch)
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` (edited: two call sites)
- `agent-system/extensions/core/skills/skill-reviser/SKILL.md` (edited: Stage 7 harvest)
- Regenerated `.claude/**` deploy tree (loader output, not hand-authored)
- `specs/162_formalize_files_to_modify_and_harvest_file_scope/summaries/01_*-summary.md`
- An uncommitted `specs/state.json` change in `~/Projects/BimodalLogic`, reported for user review

## Rollback/Contingency

Each phase is independently revertible and committed on its own green sub-steps, so the ordinary
contingency is `git revert` of the offending phase commit rather than a working-tree rollback.

- **Phase 1** is prose-only: revert the `plan-format.md` hunk; no consumer depends on the new text.
- **Phases 2 and 5** add new files: deleting them restores prior behavior exactly, since nothing
  calls them until Phase 4 wires the harvester.
- **Phase 3** is a two-line guard widening: restoring the `target_status != research` condition
  restores the prior restriction with no data migration.
- **Phase 4** is the only phase that changes live behavior. Because the merge is additive and
  guarded non-fatal, the worst failure mode is a spurious path added to a task's `file_scope`;
  remove it with a targeted `state-write.sh` filter. Reverting the four wiring hunks returns plan
  postflight to its pre-change behavior.
- **Phase 5's cross-repo write** is additive and idempotent; an unwanted addition in
  `~/Projects/BimodalLogic` is discardable because Decision 8 leaves that change uncommitted
  (`git checkout` of that one file in that repo, at the user's discretion — not this task's action).
- If a working-tree rollback is genuinely required, take a snapshot first per
  `context/contracts/recovery.md`'s rollback rung (including its out-of-scope override flag for a
  deliberate whole-tree case) rather than running a destructive git command directly. Do not emit a
  default-mode `git-snapshot.sh` call as a routine per-phase checkpoint; an ordinary defensive
  checkpoint before risky work uses `--no-revert`.
