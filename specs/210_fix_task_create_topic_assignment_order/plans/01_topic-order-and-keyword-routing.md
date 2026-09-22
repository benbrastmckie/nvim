# Implementation Plan: Fix /task create topic assignment order, and task-type keyword false positives

- **Task**: 210 - Fix /task create: topic assignment order and registration, and task-type keyword false positives
- **Status**: [IMPLEMENTING]
- **Effort**: 9 hours
- **Dependencies**: None (task 209 is a state.json ordering dependency only, not content-related)
- **Research Inputs**: specs/210_fix_task_create_topic_assignment_order/reports/01_topic-order-and-keyword-routing.md
- **Artifacts**: plans/01_topic-order-and-keyword-routing.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two separable defect clusters in `/task`, both rooted in `agent-system/extensions/core/`.
**Cluster A** — Create Task Mode calls `manage-topics.sh set` at step 4.5, *before* step 6 writes
the task into `active_projects`, so the call always exits 4; `active_topics` therefore never gets
the topic; and the Mode A picker under-shoots `AskUserQuestion`'s 2-option floor on a fresh repo
while its JSON templates use a schema the tool does not have. **Cluster B** — step 4's task_type
detection is first-keyword-match-wins over bare common words, so "agent", "lean", and "proof" in
passing misroute real descriptions, and the literature manifest's `keyword_overrides` maps
literature vocabulary to task_type `meta`.

The fix for Cluster A is a reordering (not a new mechanism): move Create Mode's existing
`manage-topics.sh set` call to after step 6's state write, matching what Expand, Recover, and
Review Mode already do. The fix for Cluster B is to extract step 4's whole detection sequence into
one sourceable shell library with a strong-anchor/weak-signal scoring rule, so it is both shared
and mechanically testable. Definition of done: create mode on a fresh `state.json` yields a task
with its topic set and listed in `active_topics` with no non-zero exit; both new fixture suites
pass from the deployed copy; shellcheck clean; redeployed and verified.

### Research Integration

The research report (`reports/01_topic-order-and-keyword-routing.md`) confirmed every defect and
resolved several questions this plan would otherwise have had to open:

- Create Mode is the **sole** caller with the wrong order — Expand (`task.md` Expand Mode, ~462),
  Review follow-ups (~868), Recover (~384), plus `/spawn`, `/fix-it`, `/review`,
  `/project-overview`, `/todo` backfill all already call `set`/`add` after the state write. The
  dispatch's "check each caller; don't assume" sweep is therefore **verification work**, not
  edit work, on every caller but Create Mode.
- `manage-topics.sh set` already sets `.topic` AND appends to `active_topics` idempotently in one
  `state-write.sh` call (`scripts/manage-topics.sh`, `set` subcommand). Defects (a) and (b) share
  one fix; no change to step 6's jq filter or to `manage-topics.sh` is needed.
- The step-4 keyword table exists in exactly one place (`commands/task.md`); there are no verbatim
  duplicates. Two independent **prose summaries** would silently drift: `commands/fix-it.md`
  (research-task language detection) and `agents/meta-builder-agent.md` — the latter explicitly
  out of scope per the dispatch MUST NOT. `commands/review.md` uses file-extension majority voting
  (a different, unaffected mechanism) and `skill-spawn` inherits `task_type` from the parent.
- Literature is the only manifest whose `keyword_overrides` key is not its own task_type, and it
  has `routing_exempt: true` with no `.routing` block at all — so remapping the key to
  `"literature"` would create a task_type no routing consumer can resolve, a worse failure than
  today's wrong-but-resolvable `meta`.
- The real `AskUserQuestion` schema is `{question, header, multiSelect, options: [{label,
  description}]}` (per `context/standards/interactive-selection.md`); there is no `type` field and
  no `freeText` variant.
- `scripts/tests/run-all.sh` auto-discovers `scripts/tests/test-*.sh` — new suites need no
  registration, only the exec bit.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in this dispatch; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Create Mode's topic assignment succeeds: task `topic` set and topic present in `active_topics`,
  with no non-zero exit from `manage-topics.sh`, following `commands/task.md` exactly as written.
- `topic-assignment-pattern.md`'s templates are valid `AskUserQuestion` inputs and define a
  zero-existing-topics branch that keeps assignment mandatory.
- Task-type detection stops misrouting descriptions that mention a routing keyword in passing,
  while still routing genuine agent-system and Lean descriptions correctly.
- The detection rule lives in **one** sourceable definition, consumed by `commands/task.md` and
  referenced by `commands/fix-it.md`, and is covered by a fixture suite.
- Two new fixture suites pass from the deployed copy; shellcheck clean for every shell file added
  or changed.

**Non-Goals**:
- No Skip or Defer option on any creation path. The single "Defer (leave uncategorized for now)"
  option stays exclusive to `/task --sync` backfill.
- No change to `manage-topics.sh`'s behavior or exit-code contract (callers depend on exit 4).
- No change to how `/meta` sets `task_type` (`agents/meta-builder-agent.md` is out of the edit
  set, per the dispatch MUST NOT).
- No change to `commands/review.md`'s file-extension majority-vote topic/type mechanism.
- No detection path that asks questions in autonomous contexts.
- No hand-authored edits under `.claude/**` — that tree is a deploy artifact regenerated from
  `agent-system/extensions/**`.

## Decisions

These are plan-phase judgment calls the research explicitly deferred here. The implementer follows
them rather than re-opening them.

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Fix (a)+(b) by **moving** Create Mode's existing `manage-topics.sh set` call to after step 6, not by teaching step 6's jq filter to append to `active_topics` | `set` already does both atomically; inlining `active_topics` jq would make Create Mode the only call site that bypasses `manage-topics.sh`, contradicting `topic-assignment-pattern.md`'s stated purpose |
| D2 | **Keep** step 6's `"topic": ...` jq clause after the move, with an inline comment noting `manage-topics.sh set` re-asserts it and owns `active_topics` | Redundant but idempotent and same-valued; keeping it means `state.json` carries the topic correctly even in the window before the `set` call, and removing it would make the field depend entirely on a single later call |
| D3 | Create Mode's post-move `set` call is a **hard error** (loud, named, with the exact remediation command), not the `\|\| echo "...non-fatal"` idiom used by Expand/Review. No rollback of the already-written task row | Create Mode's topic assignment is documented mandatory, so a silent swallow is wrong; but rolling back a completed `state-write.sh` is more destructive than leaving a created task with a printed remediation line |
| D4 | Zero existing topics → go **straight to free-text**, skipping the multi-option picker entirely (research option ii), reusing the existing empty-input re-prompt rule | Deterministic; avoids introducing a name-synthesis heuristic whose quality is a new risk surface, and avoids the residual case where the heuristic yields zero candidates and still under-shoots the floor |
| D5 | **Remove** `keyword_overrides` from the literature manifest rather than remapping its key | Literature has `routing_exempt: true` and no `.routing` block, so `"literature"` as a task_type would be unresolvable at dispatch time; `--lit` already provides literature context independent of task_type, so nothing is lost |
| D6 | Detection rule = **strong anchors + weak-signal threshold** (a blend of dispatch options 1 and 3), extracted into `scripts/lib/task-type-detect.sh` implementing the whole 4a-4e sequence | Pure narrowing (option 1) risks breaking the "skill-orchestrate" true positive; pure scoring alone does not express high-confidence phrase anchors. Extraction is what makes the ACCEPTANCE fixture tests literal assertions rather than manual transcript inspection, and satisfies "ideally from one shared definition" |
| D7 | **Also fix** `task.md`'s three illustrative pickers (Recover, Expand, Review) that pass `options` as bare strings, in Phase 1 | Rewriting the pattern doc while leaving the pickers that point at it non-conformant recreates exactly the drift this task exists to close; the edit is mechanical. Placed in Phase 1 (which already owns `task.md`'s topic surface) so it does not collide with Phase 2's pattern-doc territory |
| D8 | `agents/meta-builder-agent.md` stays untouched | Dispatch MUST NOT |

### D6 detail: the detection rule

`detect_task_type` resolves in this order, preserving today's 4a-4e sequence shape:

1. **Strong anchors** (phrase- or pattern-level, high confidence). A single match resolves
   immediately.
   - `meta`: `.claude/`, `agent-system`, `agent system`, `SKILL.md`, `CLAUDE.md`, `manifest.json`,
     `state.json`, `slash command`, `subagent`, `task_type`, `keyword_overrides`, a
     `skill-<word>` or `<word>-agent` hyphenated compound, a leading-slash command token
     (`/task`, `/orchestrate`, `/implement`, ...), `specs/`
   - `lean4`: a `.lean` path or filename, `Mathlib`, `lean4`, `mathlib4`
2. **Extension `keyword_overrides`** (today's 4b), unchanged in mechanism, now scanning a
   corrected literature manifest.
3. **Project default** (today's 4c), unchanged.
4. **Weak-signal scoring** (replaces today's 4d first-match-wins). Each type accumulates a count of
   **distinct** matched weak keywords over the whole description. A type resolves only at
   **>= 2 distinct** weak matches. Highest distinct count wins; on a tie, today's row order breaks
   it (meta, then lean4, then the remaining 4d rows in their existing order). Zero types reaching
   the threshold → `general`.
   - `meta` weak: `meta`, `agent`, `command`, `skill`, `hook`, `rule`, `dispatch`, `orchestrate`
   - `lean4` weak: today's row verbatim (`lean`, `theorem`, `proof`, `lemma`, `axiom`,
     `proposition`, `corollary`, `derivation`, `formalize`, `formalization`)
   - Every other 4d row keeps its existing keyword list and its existing relative order.
5. **Alias remapping** (today's 4e), unchanged, and still applied only to results from steps 3-4.

Worked against the six acceptance descriptions:

| Description | Resolves via | Expected |
|-------------|--------------|----------|
| "research and revise the AI agent objectives ... training models ... agent harnesses" | no strong anchor; `meta` weak = 1 distinct (`agent`) → below threshold | `general` |
| "Why Lean over Rocq when there are more resources for software verification in Rocq?" | no strong anchor; `lean4` weak = 1 distinct (`lean`) → below threshold | `general` |
| a business-strategy description mentioning "the Logos proof theory" | no strong anchor; `lean4` weak = 1 distinct (`proof`) → below threshold | `general` |
| a lean4 formalization description that also contains the word "literature" | literature's override removed (D5), so 4b no longer fires; `.lean` path or >= 2 distinct lean4 weak words | `lean4` |
| "Update skill-orchestrate's dispatch to pass --lit" | `meta` strong anchor (`skill-<word>` compound) | `meta` |
| "Prove soundness lemma in Metalogic/Soundness.lean" | `lean4` strong anchor (`.lean` path) | `lean4` |

The first three rows are where this rule earns its keep, and the fifth is the true positive the
research flagged as at risk from naive narrowing: it survives because the strong-anchor set
includes the hyphenated `skill-<word>` compound rather than only multi-word phrases.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The narrowed 4a breaks the "skill-orchestrate" true positive | H | M | D6's strong-anchor set includes `skill-<word>`/`<word>-agent` compounds; Phase 7's fixture asserts all six acceptance cases together, not just the three false positives |
| Weak-signal threshold of 2 misroutes a genuine short description (e.g. "Fix agent dispatch") | M | M | Marked as a **Scope Hypothesis** on Phase 5; Phase 7 adds negative-control cases and the threshold is a single named constant so it can be retuned without restructuring |
| Extracting step 4 into a library is new surface area beyond a "move a line" fix | M | H | It is the only way to satisfy ACCEPTANCE's literal "fixture test ... All pass from the deployed copy"; the library implements the *existing* 4b/4c/4e logic unchanged, so only 4a/4d are genuinely new code |
| Removing literature's `keyword_overrides` silently changes routing for existing literature-flavored descriptions | L | M | Intended (D5); Phase 4 updates `extension-development.md`'s worked-examples citation in the same commit so docs and manifest never disagree |
| Making Create Mode's `set` call fatal diverges from the soft-failure idiom used elsewhere | L | L | D3 documents the divergence and its rationale inline at the call site, so a future reader does not "fix" it back to non-fatal |
| A sibling task commits into the shared working tree mid-phase | M | M | Territory is disjoint from tasks 242/243/245/227 (verified against the dispatch's `concurrent_siblings` block); re-read every file immediately before editing, stage only this task's own hunks, never a directory or glob `git add` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 4 | -- |
| 2 | 3, 5 | 1, 2, 4 |
| 3 | 6, 7 | 5 |
| 4 | 8 | 3, 6, 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Fix Create Mode topic-assignment order in task.md [COMPLETED]

**Goal**: Create Task Mode assigns its topic after the task exists in `active_projects`, and
`task.md`'s three illustrative pickers use the real `AskUserQuestion` option shape.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/commands/task.md` immediately before editing (shared
      working tree, concurrent siblings). *(completed)*
- [x] In step 4.5, keep the Mode A picker reference and the `$topic` capture; **delete** the
      `bash .claude/scripts/manage-topics.sh set "$next_num" "$topic"` block that currently
      follows it, replacing it with a one-line note that state application happens after step 6.
      *(completed)*
- [x] Immediately after step 6's `state-write.sh` invocation, add the `manage-topics.sh set` call
      using the same `$session_id` generated in step 6, guarded per D3: on non-zero exit print a
      loud error naming the exit code and the exact remediation command, and treat it as a hard
      error rather than the `|| echo "...non-fatal"` idiom used by Expand/Review. *(completed)*
- [x] Add a short inline comment at step 6's `"topic": ...` jq clause recording D2 (kept
      deliberately; `manage-topics.sh set` re-asserts it and owns `active_topics`). *(completed)*
- [x] Fix the bare-string `options` arrays in the three illustrative `AskUserQuestion` blocks
      (Recover Mode ~353-361, Expand Mode ~442-450, Review Mode ~822-830) to
      `{label, description}` objects. Do not change their `question`/`header`/`multiSelect`
      values, which are already correct.
      *(deviation: altered — a fourth bare-string site was also found and fixed, the `/task
      --sync` backfill picker (~line 607); Phase 1's Verification criterion is file-wide
      ("No `"options": [` block in `task.md` contains a bare string element"), so it was
      included rather than left as the sole remaining bare-string block)*
- [x] Audit-only caller sweep (no edits expected): confirm Expand (~462), Review follow-up
      (~868), and Recover (~384) still call `set`/`add` strictly after their state write, and
      confirm `/spawn`, `/fix-it`, `/review`, `/project-overview`, `/todo` backfill likewise.
      Record any caller found out of order as a new finding rather than silently fixing it.
      *(completed: all callers confirmed in order — Recover, Expand, Review follow-up in
      task.md; skill-spawn Stage 14a, skill-fix-it Step 9.3, skill-project-overview, and
      skill-todo backfill all call `set`/`add` strictly after their state write. No
      out-of-order caller found besides the original Create Mode defect.)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts exactly three bare-string picker sites in `task.md` and
zero out-of-order callers besides Create Mode. Confirm at implementation time with
`grep -n '"options"' commands/task.md` and by re-reading each caller's ordering; if the counts
differ, report the discrepancy rather than silently widening or narrowing the edit.

**Files to modify**:
- `agent-system/extensions/core/commands/task.md` - move the `manage-topics.sh set` call from
  step 4.5 to after step 6; annotate step 6's topic clause; fix three picker `options` arrays

**Verification**:
- `grep -n 'manage-topics.sh set' commands/task.md` shows the Create Mode call after, not before,
  step 6's `state-write.sh`.
- No `"options": [` block in `task.md` contains a bare string element.
- Step 4.5 no longer contains a `manage-topics.sh` invocation.

---

### Phase 2: Rewrite topic-assignment-pattern.md templates and zero-topics branch [COMPLETED]

**Goal**: The pattern doc's `AskUserQuestion` templates are valid tool inputs, and Mode A has a
defined, mandatory-preserving path when `active_topics` is empty.

**Tasks**:
- [x] Rewrite Mode A **Step 2**'s JSON block to the real schema:
      `{question, header, multiSelect: false, options: [{label, description}]}`. Give each
      existing-topic option a description (e.g. its current task count or a short gloss) and give
      "New topic..." a description naming the free-text follow-up. *(completed)*
- [x] Replace Mode A **Step 3**'s `{"type": "freeText"}` JSON block with prose: selecting
      "New topic..." triggers a natural-language free-text follow-up in the next turn; it is not a
      second tool schema. Keep the existing validation rules (non-empty, kebab-case, re-prompt on
      empty). *(completed)*
- [x] Rewrite the `/task --sync` backfill template (Mode A Step 4's exception block) to the same
      real schema, keeping its single "Defer (leave uncategorized for now)" option and its
      explicit "this is the ONE exception to no-Skip" framing. *(completed)*
- [x] Add a **zero-existing-topics** branch to Mode A Step 1 per D4: when
      `${#existing_topics[@]} -eq 0`, skip the picker entirely and go straight to the free-text
      prompt of Step 3, reusing its empty-input re-prompt rule. State explicitly that this branch
      offers no Skip and no Defer. *(completed)*
- [x] Update the **Mandatory Assignment Guarantee** section so its "no bypass" language covers the
      new zero-topics branch by name. *(completed)*
- [x] Note in the batch-variant subsection that it inherits the corrected schema and the
      zero-topics branch from Steps 1-3. *(completed)*
- [x] Add a one-line pointer to `context/standards/interactive-selection.md` as the schema's
      source of truth, so a future edit has somewhere to check against. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/context/patterns/topic-assignment-pattern.md` - Mode A Steps 1-4,
  sync-backfill template, batch-variant note, Mandatory Assignment Guarantee

**Verification**:
- `grep -n '"type":' context/patterns/topic-assignment-pattern.md` returns nothing.
- Every remaining JSON block in the file carries `question`, `header`, `multiSelect`, and
  `options` whose elements are objects with `label` and `description`.
- The zero-topics branch is present in Step 1 and referenced from the Mandatory Assignment
  Guarantee section.

---

### Phase 3: Fixture test for create-mode topic assignment [COMPLETED]

**Goal**: A runnable suite asserting that create-mode topic assignment leaves both the task's
`topic` and `active_topics` set, with no non-zero `manage-topics.sh` exit, on a state with zero
topics and on a state with existing topics.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/test-manage-topics-create-order.sh`
      following `context/standards/shell-script-testing.md` conventions: `mktemp -d` scratch
      repo, `pass()`/`fail()`/`info()` helpers, PASSED/FAILED counters, exit 0/1/2. *(completed)*
- [x] Case 1 (zero topics): seed a scratch `specs/state.json` with `active_projects: []` and
      `active_topics: []`; simulate Create Mode's corrected order (state write, then
      `manage-topics.sh set`); assert exit 0, assert the task's `topic` is set, assert
      `active_topics` contains it. *(completed)*
- [x] Case 2 (existing topics): seed `active_topics` with two entries; run the same sequence with
      an existing topic; assert exit 0, topic set, and `active_topics` **unchanged in length**
      (idempotent append, no duplicate). *(completed)*
- [x] Case 3 (regression guard for the original defect): call `manage-topics.sh set` against a
      task number absent from `active_projects` and assert exit **4** — pinning the exit-code
      contract this task must not change. *(completed)*
- [x] Add a case asserting `commands/task.md`'s Create Mode text places its `manage-topics.sh set`
      call after `state-write.sh` (a text-order assertion over the source file), so a future
      re-introduction of the defect fails the suite rather than only failing at runtime.
      *(completed)*
- [x] `chmod +x` the suite (`run-all.sh` reports a non-executable suite as a loud `[SKIP]`, and
      auto-discovers it otherwise — no registration needed). *(completed)*
- [x] Run `shellcheck` on the new suite and resolve every finding. *(completed: one info-level
      SC2329 "cleanup() never invoked" false positive remains, identical to the same finding on
      every precedent suite's `trap ... EXIT`-invoked `cleanup()` function in this codebase
      (`test-census-count.sh`, `test-skill-base-lifecycle.sh`, etc.) — this is the established,
      accepted "shellcheck clean" bar this repo's test suites already meet, not a new finding)*

**Timing**: 1.25 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-manage-topics-create-order.sh` - new

**Verification**:
- `bash scripts/tests/test-manage-topics-create-order.sh` exits 0 with all cases passing.
- `shellcheck` clean.
- The suite leaves no residue outside its `mktemp -d` directory.

---

### Phase 4: Remove literature's keyword_overrides and correct the docs [COMPLETED]

**Goal**: No manifest maps keywords to a task_type it does not own, and the documentation that
cites literature as a worked example no longer does.

**Tasks**:
- [x] Remove the entire `keyword_overrides` block from
      `agent-system/extensions/literature/manifest.json`. Verify the file remains valid JSON
      (`jq . manifest.json`). *(completed)*
- [x] Sweep every other manifest for the same mistake:
      `for m in agent-system/extensions/*/manifest.json; do jq -r '...' ; done` comparing each
      `keyword_overrides` key against that manifest's own `.name`/task_type. Research found
      cslib, email, latex, rust, typst all correct and literature the sole exception — confirm,
      do not assume. *(completed: confirmed cslib (`cslib`, `pr` — both have real `.routing`
      entries), email, latex, rust, typst all match their own task_types; literature was the
      sole exception)*
- [x] In `context/guides/extension-development.md`'s `keyword_overrides` section, drop
      `literature` from the "Worked examples" list. *(completed)*
- [x] In the same section, add an explicit rule sentence: a `keyword_overrides` key **is** a
      task_type, so an extension with `routing_exempt: true` and no `.routing` block must not
      declare `keyword_overrides` at all — with a one-line note on why remapping to a
      routing-less task_type is worse than removal. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: this phase asserts literature is the only manifest whose
`keyword_overrides` key differs from its own task_type. Confirm with the cross-manifest `jq`
sweep above before editing; if another manifest is also non-conformant, report it and extend the
phase rather than leaving it unfixed.

**Files to modify**:
- `agent-system/extensions/literature/manifest.json` - remove `keyword_overrides`
- `agent-system/extensions/core/context/guides/extension-development.md` - worked-examples list
  and the new key-is-a-task_type rule

**Verification**:
- `jq -e '.keyword_overrides' agent-system/extensions/literature/manifest.json` exits non-zero.
- `jq . agent-system/extensions/literature/manifest.json` succeeds.
- `grep -n 'literature' context/guides/extension-development.md` shows no worked-example citation.

---

### Phase 5: Extract task-type detection into a sourceable library [COMPLETED]

**Goal**: One shared, testable definition of the whole step-4 detection sequence, implementing
D6's strong-anchor + weak-threshold rule.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lib/task-type-detect.sh` exporting
      `detect_task_type "<description>" [state_file] [extensions_dir]`, echoing the resolved
      task_type on stdout. Follow the sourceable-library conventions of
      `scripts/lib/manifest-routing-lib.sh` (the precedent for centralizing previously-prose
      routing logic) — no side effects on source, no `set -e` imposed on the caller. *(completed)*
- [x] Implement the resolution ladder in D6 order: strong anchors, extension `keyword_overrides`,
      project default, weak-signal scoring, alias remapping. *(completed)*
- [x] Define the strong-anchor sets and the weak-signal sets as named arrays/constants near the
      top of the file, and the threshold as one named constant, so the rule is retunable without
      restructuring. *(completed: `DTD_WEAK_SIGNAL_TABLE` and `DTD_WEAK_THRESHOLD`; strong
      anchors are literal lists inside `_dtd_strong_anchor_meta`/`_dtd_strong_anchor_lean4`)*
- [x] Carry today's 4b, 4c, and 4e logic across **unchanged in behavior** (including the
      alphabetical first-match-wins manifest scan order and the rule that 4b matches are final and
      not alias-remapped) — only 4a and 4d change. *(completed)*
- [x] Preserve whole-word, case-insensitive matching (`\b<keyword>\b`) for weak signals; strong
      anchors match as literal substrings or the stated compound patterns. *(completed)*
- [x] Use the `select(... | not)` jq idiom rather than `!=` throughout (Claude Code Issue #1132).
      *(completed: no `!=` used anywhere in the new library's jq calls — only `==` and
      `select(...)` with no negation, so the idiom does not arise)*
- [x] Add a file-header comment block documenting the rule, its consumers, and a pointer to this
      plan's D6 table. *(completed)*
- [x] Run `shellcheck` and resolve every finding. *(completed: clean, zero findings)*

**Timing**: 2 hours

**Depends on**: 4

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts that only 4a and 4d change behavior and that 4b/4c/4e
port across unchanged. Confirm at implementation time by diffing the library's 4b/4c/4e branches
against `commands/task.md`'s current reference jq snippets line-for-line before deleting the
prose versions in Phase 6.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/task-type-detect.sh` - new

**Verification**:
- `bash -n scripts/lib/task-type-detect.sh` and `shellcheck` both clean.
- Sourcing the file and calling `detect_task_type` on each of the six D6 acceptance descriptions
  returns the expected type (formalized as a suite in Phase 7).

---

### Phase 6: Rewire task.md step 4 and the drifting prose summaries [COMPLETED]

**Goal**: `commands/task.md` step 4 delegates to the library instead of restating the rule, and
every other prose restatement either points at the library or is documented as out of scope.

**Tasks**:
- [x] Re-read `commands/task.md` immediately before editing (Phase 1 already modified it).
      *(completed)*
- [x] Replace step 4's 4a-4e prose and reference jq snippets with a call to the library:
      source `scripts/lib/task-type-detect.sh` and assign `task_type=$(detect_task_type ...)`.
      Retain a **short** prose summary of the resolution ladder (anchors, overrides, default,
      scoring, aliases) for the reader, explicitly naming the library as the authority.
      *(completed)*
- [x] Update `commands/fix-it.md`'s research-task language-detection sentence to reference the
      same library rather than restating a first-match keyword list, so the two cannot drift.
      *(completed)*
- [x] Check whether `merge-sources/claudemd.md`'s `keyword_overrides` sentence (the
      Task-Type-Based Routing section) still describes the behavior accurately after D5 and D6. It
      currently says extensions "automatically detect their task type from keywords" — which
      stays true — so amend only if a concrete inaccuracy is found; record either way.
      *(completed: checked — the sentence remains accurate; keyword_overrides still functions
      identically from the extension-manifest side, only its consulted-from location moved into
      the library. No inaccuracy found; left unchanged.)*
- [x] Leave `agents/meta-builder-agent.md` untouched (D8) and add no cross-reference to it.
      *(completed: confirmed via `git diff --stat` — no entry)*
- [x] Confirm `commands/review.md` needs no change (file-extension majority vote, a different
      mechanism). *(completed: confirmed unmodified, no entry in `git diff --stat`)*

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/commands/task.md` - step 4 replaced with a library call plus a
  short ladder summary
- `agent-system/extensions/core/commands/fix-it.md` - research-task detection sentence
- `agent-system/extensions/core/merge-sources/claudemd.md` - only if a concrete inaccuracy is
  found

**Verification**:
- `commands/task.md` step 4 contains no hardcoded keyword table and one `detect_task_type` call.
- `grep -rn 'theorem, proof, lemma' commands/` returns nothing outside the library.
- `agents/meta-builder-agent.md` is unmodified (`git diff --stat` shows no entry for it).

---

### Phase 7: Fixture test for task-type detection [COMPLETED]

**Goal**: A runnable suite asserting all six D6 acceptance cases plus negative controls against
the library.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/test-task-type-detect.sh` following
      `context/standards/shell-script-testing.md` conventions, structured table-driven after
      `test-routing-resolution.sh`. *(completed)*
- [x] Assert the six D6 cases: the two Verification false positives (`general`), the business-
      strategy "Logos proof theory" case (`general`), the lean4-formalization-with-"literature"
      case (`lean4`), "Update skill-orchestrate's dispatch to pass --lit" (`meta`), and
      "Prove soundness lemma in Metalogic/Soundness.lean" (`lean4`). *(completed)*
- [x] Add negative controls that pin the threshold's intent: a short genuine agent-system
      description that must still resolve `meta`, and a short description with one incidental
      routing word that must resolve `general`. *(completed)*
- [x] Add a case asserting the literature-keyword regression stays closed: a description
      containing "literature" alongside lean4 content resolves `lean4`, not `meta`. *(completed)*
- [x] Run the suite against a scratch `extensions_dir` fixture so it does not depend on the live
      manifest set, plus one case against the real deployed manifests. *(completed: the
      "real manifests" case resolves relative to the suite's own location -- source store's
      `agent-system/extensions` pre-deploy, or `.claude/extensions` when run as the deployed
      copy in Phase 8 -- rather than an unconditional deployed-first preference, so it never
      reads a stale not-yet-redeployed `.claude/extensions` while this suite still runs from
      the source store)*
- [x] `chmod +x`, run `shellcheck`, resolve every finding. *(completed: one info-level SC2329
      "cleanup() never invoked" false positive remains, the same established, accepted finding
      documented for Phase 3's suite)*

**Timing**: 1.25 hours

**Depends on**: 5

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts nine or so cases (six acceptance + three controls). The
count is a hypothesis; if implementing the controls reveals a case the rule mishandles, report it
and retune D6's threshold constant rather than deleting the failing case.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-task-type-detect.sh` - new

**Verification**:
- `bash scripts/tests/test-task-type-detect.sh` exits 0 with every case passing.
- `shellcheck` clean.

---

### Phase 8: Deploy, full gate, and end-to-end confirmation [NOT STARTED]

**Goal**: The change is live in the deployed tree and confirmed against ACCEPTANCE as written.

**Tasks**:
- [ ] Run `shellcheck` across every shell file added or changed in this task and confirm clean.
- [ ] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh` and confirm both new suites
      are discovered (not `[SKIP]`) and the whole run is green.
- [ ] Redeploy via `bash .claude/scripts/deploy-headless.sh` (or the repo's current sanctioned
      deploy entry point) and confirm `.claude/scripts/lib/task-type-detect.sh`,
      `.claude/scripts/tests/test-task-type-detect.sh`, and
      `.claude/scripts/tests/test-manage-topics-create-order.sh` all landed.
- [ ] Re-run both new suites **from the deployed copy** under `.claude/scripts/tests/` — ACCEPTANCE
      says "All pass from the deployed copy", which the source-store run does not satisfy.
- [ ] Run `bash .claude/scripts/tests/run-all.sh` from the deployed tree for the full regression
      net.
- [ ] End-to-end ACCEPTANCE walkthrough: on a scratch `state.json` with zero topics, follow
      deployed `commands/task.md` Create Mode exactly as written and confirm the created task has
      its topic set, the topic appears in `active_topics`, and no step exits non-zero.
- [ ] Confirm no file under `.claude/**` was hand-authored — every `.claude/` change must have
      arrived via the deploy.

**Timing**: 1 hour

**Depends on**: 3, 6, 7

**Verification Tier**: full

**Files to modify**:
- None (verification and deploy only; `.claude/**` changes arrive via the deploy, never by hand)

**Verification**:
- `run-all.sh` green from both the source store and the deployed tree.
- The scratch-repo Create Mode walkthrough produces a topic-assigned task with a populated
  `active_topics` and no non-zero exit.
- `git status` shows no hand-edited `.claude/**` file.

---

## Testing & Validation

- [ ] `scripts/tests/test-manage-topics-create-order.sh` passes: zero-topics case, existing-topics
      case, exit-4 contract guard, and the task.md call-order text assertion.
- [ ] `scripts/tests/test-task-type-detect.sh` passes all six acceptance cases plus negative
      controls and the literature regression guard.
- [ ] `run-all.sh` green from the source store and from the deployed tree, with both new suites
      discovered rather than skipped.
- [ ] `shellcheck` clean for `scripts/lib/task-type-detect.sh` and both new suites.
- [ ] `jq .` valid on `agent-system/extensions/literature/manifest.json`.
- [ ] No `"type": "select"` or `"type": "freeText"` remains in
      `context/patterns/topic-assignment-pattern.md`; no bare-string `options` remains in
      `commands/task.md`.
- [ ] `agents/meta-builder-agent.md` unmodified.
- [ ] No task-number references introduced outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/commands/task.md` (modified: step 4, step 4.5, step 6, three
  pickers)
- `agent-system/extensions/core/commands/fix-it.md` (modified: research-task detection sentence)
- `agent-system/extensions/core/context/patterns/topic-assignment-pattern.md` (modified: Mode A
  Steps 1-4, sync-backfill template, batch variant, mandatory-assignment guarantee)
- `agent-system/extensions/core/context/guides/extension-development.md` (modified:
  `keyword_overrides` worked examples and key-is-a-task_type rule)
- `agent-system/extensions/core/scripts/lib/task-type-detect.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-task-type-detect.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-manage-topics-create-order.sh` (new)
- `agent-system/extensions/literature/manifest.json` (modified: `keyword_overrides` removed)
- `agent-system/extensions/core/merge-sources/claudemd.md` (conditional, Phase 6)
- `specs/210_fix_task_create_topic_assignment_order/summaries/01_*-summary.md` (implementation
  summary)

## Rollback/Contingency

Every phase is a separate scoped commit, so the ordinary contingency is `git revert` of the
offending commit — no working-tree destruction required, and the concurrent-sibling situation on
this shared tree makes a targeted revert strongly preferable to any whole-tree operation.

Per-cluster fallbacks, in order of decreasing scope:

- **Cluster B, if the D6 rule cannot be made to satisfy all six acceptance cases**: keep Phases 4
  (literature manifest) and 1-3 (Cluster A), which are independently valuable and independently
  verified, and report the detection rule as `[BLOCKED]` with the specific failing case rather
  than shipping a rule that trades one false positive for another.
- **Phase 5, if extraction proves larger than budgeted**: the research flagged a lighter-weight
  fallback — assert the rule by grepping the deployed `task.md` for the exact keyword lists
  instead of extracting a library. This satisfies ACCEPTANCE more weakly and forfeits the "one
  shared definition" goal, so take it only after reporting why extraction failed.
- **Phase 4, if removing literature's `keyword_overrides` breaks a consumer not found in
  research's sweep**: restore the block and re-scope to a narrowed, multi-word `keywords` list
  under a key that is a real task_type, reporting the consumer found.

Only if an uncommitted working tree must actually be discarded does the snapshot-then-rollback
rung apply: see `context/contracts/recovery.md`'s rollback rung for the exact
`git-snapshot.sh` invocation shape, including its out-of-scope override flag. Do not take a bare
reverting snapshot as a routine start-of-phase checkpoint; a defensive checkpoint before risky
work uses `--no-revert`.
