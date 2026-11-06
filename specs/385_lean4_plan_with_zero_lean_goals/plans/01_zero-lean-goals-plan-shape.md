# Implementation Plan: Task #385

- **Task**: 385 - Lean4 plan with zero Lean goals
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/385_lean4_plan_with_zero_lean_goals/reports/01_zero-lean-goals-plan-shape.md
- **Artifacts**: plans/01_zero-lean-goals-plan-shape.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

A lean/lean4-typed plan with no theorem deliverable currently has no sanctioned shape, and both
available shapes (`## Lean Challenge Statements` present-but-empty, or omitted entirely) collapse
into the same `exit 71` that `lean-challenge-snapshot.sh` already uses for a genuine config error.
This plan implements the mechanism research settled on: a literal, substring-matched marker line
`<!-- lean-challenge-statements:none -->` inside a *present* but block-free section, recognized by
a new internal `extract_r1` status `3` and reported as a new, dedicated process exit code `72`,
documented in `plan-format.md`, in the script's own exit-code header, and in the design record's
Exit-Code Vocabulary table. Every other route (`0` plan-declared, `1` section-absent/R2 fallback,
`2` present-but-empty-without-marker) keeps today's exact behaviour, so the deliberate no-op and
the malformed section remain mechanically distinguishable by exit-code value rather than by
stderr-text parsing.

All edits land in the **source store** (`agent-system/extensions/core`,
`agent-system/extensions/lean`, both resolved from `.claude-extensions.json`'s `source_dir`), never
under the deployed `.claude/**` tree, and a redeploy closes the task.

### Research Integration

The research report settled nine decisions this plan carries out verbatim; the load-bearing ones:

- **Marker shape** (Decision 1): the exact literal line `<!-- lean-challenge-statements:none -->`,
  matched as a plain substring against the *section* text after fenced-block extraction confirms
  zero blocks — the same idiom `task-ref-ok`/`version-ok` already use, not a new convention.
- **`**Goals**:` must also be empty** (Decision 2): marker present + `**Goals**:` naming
  identifiers is a genuine self-inconsistency and stays a hard `71`, not the new `72`.
- **New internal `extract_r1` status `3`** (Decision 3) and **new process exit `72`**
  (Decision 4), fired only when status `3` AND `GOALS_FILE` is empty, with no manifest write, no
  module assembly, and no git commit — a side-effect-free early exit.
- **Section-absent stays wired to R2, unchanged** (Decision 5) and
  **present-but-empty-without-marker stays a hard `71`** (Decision 6) — acceptance (c) and (d).
- **`--compare`/Comparator needs no code change** (Decision 7): a zero-goal plan never writes
  `challenge/manifest.json`, so `lean-implementation-agent.md`'s existing advisory
  `challenge_missing` preflight verdict is already the correct, settled behaviour. This is a
  documentation-only obligation, landing in `challenge-snapshot.md`.
- **Placement** (Decisions 8-9): a new `### Zero Lean Goals (no theorem deliverable)` subsection
  under the existing `## Lean Challenge Statements (format, lean/lean4 plans only)` section of
  `plan-format.md`, and a new `72` row plus a short "Zero-Goal Marker" subsection in
  `challenge-snapshot.md`.

Research also surfaced a **pre-existing coverage gap**: `test-lean-challenge-snapshot.sh` has no
case at all driving `extract_r1`'s status-`2` branch (section present, zero ```` ```lean ````
blocks). Acceptance (c) is therefore net-new fixture work in Phase 4, not "keep an existing test
green" — this plan treats it as such.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no `roadmap_flag` was set; `specs/ROADMAP.md`
exists but was not consulted and is not touched by this plan.

## Goals & Non-Goals

**Goals**:

- `plan-format.md` states the sanctioned shape for a lean/lean4 plan with zero Lean goals, at the
  `## Lean Challenge Statements` section (acceptance (a)).
- `lean-challenge-snapshot.sh` recognizes the marker and reports it with a dedicated, non-`71`
  exit code `72`, documented in the script's own exit-code header and in
  `challenge-snapshot.md`'s Exit-Code Vocabulary section (acceptance (b)).
- A present-but-empty `## Lean Challenge Statements` section with no marker still fails loudly
  with `71`, proven by a net-new regression case (acceptance (c)).
- Ordinary lean4 plans' R1 extraction, R2 fallback, and identifier-set cross-validation behaviour
  are unchanged, proven by the existing suite staying green (acceptance (d)).
- The settled `--compare`/Comparator disposition for a zero-goal plan is documented.
- The deployed `.claude/` tree is regenerated from the source store so the change is live.

**Non-Goals**:

- Rewording `lean-implementation-agent.md`'s `challenge_missing` `reason_detail` text (research
  flagged this as a wording nit and explicitly scoped it out; the acceptance criteria name only
  `plan-format.md` and the snapshot script plus its design record).
- Changing `--check` mode. A zero-goal plan has no manifest, so `do_check` keeps producing its
  existing "no manifest found" `71`, which is accurate.
- Adding the already-missing `74` row to `challenge-snapshot.md`'s Exit-Code Vocabulary table
  (the script header documents `74` but the table omits it). Real, pre-existing, and out of this
  task's declared scope — left alone rather than silently bundled.
- Promoting any snapshot verdict from advisory to a hard gate.
- Writing a generic "marker-driven opt-out convention" context note (research's optional
  Context Extension Recommendation, explicitly not required here).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A too-loose marker substring check swallows the existing status-`2` malformed case (e.g. matching marker text inside a fenced block's prose) | H | M | Run the marker check at exactly the point the status-`2` decision already happens — against the section text, *after* `blocks` is confirmed empty. Phase 4's no-marker fixture is the regression that kills this mutation. |
| An author mistypes the marker and silently lands on `71` instead of `72` | L | M | Accepted by design, mirroring `task-ref-ok`/`version-ok`'s plain-substring semantics: failing loud-but-wrong-coded is strictly safer than a fuzzy match that could misclassify a malformed section as intentional. Documented as fixed literal text, not a paraphrasable template, in both doc edits. |
| Replacing the unconditional `[ ! -s "$GOALS_FILE" ]` guard with a branch weakens the R1/R2 "vacuous pass" protection that guard exists for | H | M | Keep the guard's position and its exact message/behaviour for every route other than `zero-goal`; existing case R21 pins this and must stay green unmodified. |
| Doc edits describe exit `72` before the script implements it, if phases land out of order | M | L | Phases 2 and 3 are wave-1-parallel with Phase 1 but the final phase depends on all four, so no partial state is ever the task's terminus; each phase commits independently and the task is only complete once the script, tests, and both docs agree. |
| Concurrent sibling tasks are dispatched this same cycle on the shared tree | M | M | No sibling's declared `file_scope` intersects this task's five files; still, re-read each file immediately before editing and stage only this task's own hunks per the territory contract. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1 |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Zero-Goal Recognition in lean-challenge-snapshot.sh [COMPLETED]

**Goal**: Teach the script to recognize the marker and report it with a dedicated exit code `72`,
without altering any other route's behaviour.

**Tasks**:
- [x] Re-read `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` immediately
      before editing (sibling-concurrency precaution). *(completed)*
- [x] In `extract_r1`'s embedded Python helper, at the existing `if not blocks:` branch: before
      the current `sys.stderr.write(...)` / `sys.exit(2)`, test the already-extracted `section`
      text for the literal substring `lean-challenge-statements:none`. On a hit, `sys.exit(3)`
      writing nothing to the names/module output files. On a miss, leave the existing stderr
      message and `sys.exit(2)` byte-for-byte unchanged. *(completed)*
- [x] Update `extract_r1`'s own exit-status comment block (the `#   0 / 1 / 2` list above the
      function) with the new `3` row, matching the existing wording style. *(completed)*
- [x] In the main resolution block, add an `elif [ "$r1_status" -eq 3 ]; then ROUTE="zero-goal"`
      arm between the existing `-eq 0` and `-eq 2` arms; leave the `-eq 2 -> exit 71` arm and the
      trailing `else -> extract_r2 / ROUTE="git-baseline"` arm untouched. *(completed)*
- [x] Replace the unconditional `if [ ! -s "$GOALS_FILE" ]` guard with a three-way branch that
      preserves its position (still strictly before `cross_validate_identifiers`):
      (i) `ROUTE="zero-goal"` and `GOALS_FILE` empty -> print an explicit informational
      zero-goal message naming the plan file and the fact that no Challenge, module, manifest, or
      commit was produced, then `exit 72`; (ii) `ROUTE="zero-goal"` and `GOALS_FILE` non-empty ->
      `exit 71` with a message naming the inconsistency (marker claims no goals while `**Goals**:`
      names identifiers) and the offending identifiers; (iii) any other route with an empty
      `GOALS_FILE` -> today's exact `"ERROR: no identifiers found under **Goals**: ... nothing to
      snapshot."` message and `exit 71`, verbatim. *(completed)*
- [x] Add `72` to the file-header `# Exit codes` block with the same wording the design record's
      table will carry (Phase 3), keeping the header and the record in sync per the header's own
      stated convention. *(completed)*
- [x] Confirm by reading that no `72` path can reach the status gate, the manifest write, the git
      commit, or the `--dry-run` print block. *(completed: confirmed — the zero-goal branch's
      exit 72 fires strictly before cross_validate_identifiers, before THEOREM_NAMES assembly,
      before the commit/manifest block, and before the --dry-run print block, which all sit
      later in the file)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly one touched file and four edit sites within it
(`extract_r1`'s `if not blocks:` branch, `extract_r1`'s status-comment block, the `r1_status`
resolution branch, and the `GOALS_FILE` guard) plus the header exit-code block; the implementer
confirms by grepping the file for `r1_status`, `GOALS_FILE`, `if not blocks`, and `# Exit codes`
before editing and verifying no fifth site needs to change.

**Tier Justification**: the edit is confined to one shell script with no externally visible
signature change, and the covering check is its own paired suite,
`bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh`, which resolves
the tool relative to itself and therefore exercises the source-store copy directly (note:
`suite_selection_select` returns `__FULL_SWEEP__` for a non-core source-store path, so the suite
is named directly rather than via `run-all.sh --only`).

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` - new `extract_r1` status
  `3`, new `ROUTE="zero-goal"` arm, three-way `GOALS_FILE` branch, new `72` in the header
  exit-code block and in `extract_r1`'s status-comment block

**Verification**:
- `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` passes with
  no new failures (the pre-existing case inventory R1-R21/M1-M3/C1-C4/AV1 stays green; cases R2,
  R3, R4, and R21 specifically pin that the untouched routes and the guard's non-`zero-goal`
  message are unchanged).
- `bash -n agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` is clean.
- Reading the diff confirms the status-`2` stderr message and `sys.exit(2)` are byte-for-byte
  unchanged, and that the `else -> extract_r2` fallback arm is untouched.

---

### Phase 2: plan-format.md Zero-Goal Section Shape [COMPLETED]

**Goal**: State the sanctioned shape for a lean/lean4 plan with zero Lean goals at the
`## Lean Challenge Statements` section (acceptance (a)).

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/formats/plan-format.md` immediately before
      editing. *(completed)*
- [x] Insert a new `### Zero Lean Goals (no theorem deliverable)` subsection after the existing
      bullet list under `## Lean Challenge Statements (format, lean/lean4 plans only)` (after the
      `import` lines bullet) and before `## Goal Polarity (optional, lean/lean4 plans)`, stating:
      gating stays binary on `task_type` (such a plan still carries the section); the section MUST
      contain the verbatim marker line `<!-- lean-challenge-statements:none -->` and no
      ```` ```lean ```` fenced blocks, with surrounding rationale prose permitted; `- **Goals**:`
      MUST name zero identifiers; the rationale MUST be recorded under the plan's `## Decisions`.
      *(completed)*
- [x] In the same subsection, state the three contrasts explicitly: a merely-empty section (no
      blocks, no marker) is malformed and still fails loudly with `71`; omitting the section
      entirely is NOT equivalent (it means a pre-R1-feature legacy plan and still routes to the
      R2 git-baseline fallback); and the marker is a deliberate opt-out, never a default.
      *(completed)*
- [x] Add a pointer from the subsection to
      `context/project/lean4/domain/challenge-snapshot.md`'s Exit-Code Vocabulary (for `72`) and
      its Zero-Goal Marker subsection (for the mechanics). *(completed)*
- [x] Append a minimal pointer clause to numbered-section list entry `6.` ("**Lean Challenge
      Statements** (lean/lean4 plans only) ... see below") naming the zero-Lean-goals case — a
      pointer only, no restated rules. *(completed)*
- [x] Confirm the identifier-set cross-validation bullet's hard requirement is left intact (the
      zero-goal case satisfies it vacuously with both sets empty; no carve-out text is added to
      that bullet). *(completed: confirmed by reading — the "`The identifier set declared here
      MUST equal...`" bullet is unmodified)*
- [x] Confirm no task-number reference is introduced anywhere in the added text. *(completed:
      confirmed by reading the new subsection and the entry-6 pointer clause)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Tier Justification**: the edit is markdown-only inside a guidance document with no compile or
elaboration surface, and `suite_selection_select` returns `__FULL_SWEEP__` for it (no suite maps
this path), so the honest covering check is sub-case (b)'s gate subset —
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(doc-lint and task-reference lint, with `TARGET` the source-store repository's own root) — plus
the `prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/formats/plan-format.md` - new
  `### Zero Lean Goals (no theorem deliverable)` subsection under
  `## Lean Challenge Statements (format, lean/lean4 plans only)`, plus a one-clause pointer on
  numbered-section entry `6.`

**Verification**:
- `grep -n "Zero Lean Goals" agent-system/extensions/core/context/formats/plan-format.md` finds
  the new subsection, and it sits between the section's bullet list and `## Goal Polarity`.
- `grep -c "lean-challenge-statements:none"` on the file is at least 1 and the marker text
  matches the script's substring exactly (compare against the script's literal).
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  reports gates 3 and 4 as non-SKIP and passing.
- Diff read-through confirms every changed hunk is prose/markdown and the cross-validation bullet
  is unmodified.

---

### Phase 3: challenge-snapshot.md Exit Code and Zero-Goal Marker Record [COMPLETED]

**Goal**: Document exit `72`, the marker mechanics, and the settled `--compare`/Comparator
disposition in the design record (acceptance (b)'s documentation half, plus Decision 7).

**Tasks**:
- [x] Re-read
      `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md`
      immediately before editing. *(completed)*
- [x] Add a `72` row to the existing `## Exit-Code Vocabulary` table, between the `71` and `73`
      rows, reading "Zero-goal plan — intentional, no Challenge produced (marker-recognized,
      `**Goals**:` also empty)" with "(new to this tool; no Comparator analogue)" in the Mirrors
      column, worded identically to the script header's new entry from Phase 1. *(completed)*
- [x] Add a short `### Zero-Goal Marker` subsection directly after `### Fail-loud on partial
      resolution`, documenting: the verbatim marker line and its plain-substring matching; the
      "`**Goals**:` must also be empty" cross-check, and that marker-plus-non-empty-Goals is a
      hard `71` naming the inconsistency; that a merely-empty section without the marker stays a
      hard `71`; and that an absent section still means the R2 legacy route, not this case.
      *(completed)*
- [x] In that same subsection, record the settled `--compare`/Comparator disposition: a zero-goal
      plan never acquires `challenge/manifest.json`, so `lean-implementation-agent.md`'s existing
      advisory `challenge_missing` preflight verdict is the correct and intended outcome, and
      `--compare` is in effect inapplicable to such a plan — no code change, by decision.
      *(completed)*
- [x] Cross-reference `plan-format.md`'s `### Zero Lean Goals (no theorem deliverable)`
      subsection as the authoring-side statement of the shape. *(completed)*
- [x] Confirm no task-number reference is introduced anywhere in the added text. *(completed:
      confirmed by reading the new subsection and table row)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Tier Justification**: the edit is markdown-only in a design record with no executable surface
and no suite mapping (`__FULL_SWEEP__`), so the covering check is sub-case (b)'s
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
plus the `prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md` - new `72`
  row in `## Exit-Code Vocabulary`, new `### Zero-Goal Marker` subsection after
  `### Fail-loud on partial resolution`

**Verification**:
- `grep -n '`72`' agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md`
  shows the new table row inside the Exit-Code Vocabulary table.
- `grep -n "Zero-Goal Marker"` finds the new subsection, and it precedes `## Manifest Schema`.
- The `72` wording in the record and in the script header (Phase 1) are compared side by side and
  agree.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  reports gates 3 and 4 as non-SKIP and passing.

---

### Phase 4: Regression Cases and Fixtures [COMPLETED]

**Goal**: Prove acceptance (b) and (c) mechanically, and close the pre-existing coverage gap for
the present-but-empty-section hard-failure path.

**Tasks**:
- [x] Re-read `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` and
      list `fixtures/challenge/` immediately before editing. *(completed)*
- [x] Add fixture `fixtures/challenge/plan_zero_goal_marker.md`: `- **Type**: lean`, a
      `## Goals & Non-Goals` block whose `**Goals**:` names zero identifiers, and a present
      `## Lean Challenge Statements` section containing rationale prose plus the verbatim marker
      line and no ```` ```lean ```` blocks. Model its header/metadata lines on
      `plan_r21_empty_goals.md` so `make_repo`'s `{N}` substitution works unchanged. *(completed)*
- [x] Add fixture `fixtures/challenge/plan_zero_goal_marker_with_goals.md`: the same marker
      section but with a `**Goals**:` block naming one identifier (Decision 2's inconsistency
      case). *(completed)*
- [x] Add fixture `fixtures/challenge/plan_empty_section_no_marker.md`: a non-empty `**Goals**:`
      block and a present `## Lean Challenge Statements` section with neither blocks nor marker
      (the currently-uncovered `extract_r1` status-`2` path). *(completed)*
- [x] Add case `Z1`: run the tool on the marker fixture with `--dry-run`; assert exit `72`, assert
      the informational zero-goal message is present on the output, and assert no
      `specs/*/challenge/manifest.json` was created in the throwaway repo. *(completed)*
- [x] Add case `Z2`: run on the marker-with-goals fixture; assert exit `71` and that the message
      names the inconsistency and the offending identifier. *(completed)*
- [x] Add case `Z3`: run on the empty-section-no-marker fixture; assert exit `71` and that the
      existing "present but contains no ```` ```lean ```` fenced blocks" message is emitted
      (acceptance (c)). *(completed)*
- [x] Add a case `Z4` anti-vacuity assertion in the style of the existing `AV1`: assert
      `Z1`'s and `Z3`'s exit codes are both non-zero AND distinct, so a naive
      nonzero-means-failure classifier cannot tell the deliberate no-op from the malformed
      section — the exact collapse this task exists to prevent. *(completed)*
- [x] Extend the suite's own header comment inventory to name the new `Z*` cases, matching the
      existing R/M/C/AV grouping style. *(completed)*
- [x] Run the full suite and confirm every pre-existing case still passes. *(completed: 37 passed,
      0 failed, 0 skipped — 33 pre-existing cases plus Z1-Z4; two deliberate temporary mutations
      were also applied and reverted, confirming Z1/Z4 go RED under each while R21 stays green)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts three new fixture files and four new cases (`Z1`-`Z4`) in
one suite file; the implementer confirms the fixture count by re-listing
`fixtures/challenge/` after authoring and the case count by grepping the suite for `^# Case Z`,
and adjusts the plan's claim in the summary if the real shape differs (for example if an
existing fixture can be reused for one of the three).

**Tier Justification**: the edit adds fixtures plus cases inside one test suite with no change to
any production signature, and the covering check is that same suite run directly,
`bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh`.

**Files to modify**:
- `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` - new cases
  `Z1`-`Z4` plus header-comment inventory entries
- `agent-system/extensions/lean/scripts/tests/fixtures/challenge/plan_zero_goal_marker.md` - new
  fixture: marker present, zero Goals identifiers
- `agent-system/extensions/lean/scripts/tests/fixtures/challenge/plan_zero_goal_marker_with_goals.md` -
  new fixture: marker present, Goals non-empty (inconsistency case)
- `agent-system/extensions/lean/scripts/tests/fixtures/challenge/plan_empty_section_no_marker.md` -
  new fixture: section present, no blocks, no marker

**Verification**:
- `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` exits 0 with
  the new `Z1`-`Z4` cases passing and zero regressions in the pre-existing inventory.
- A deliberate temporary mutation check (reverted immediately): removing the marker substring
  test from `extract_r1` turns `Z1` RED, and removing the `zero-goal` arm of the `GOALS_FILE`
  branch turns `Z1` RED while leaving `R21` green — confirming the new cases are not vacuous.
- `ls agent-system/extensions/lean/scripts/tests/fixtures/challenge/` shows the new fixtures and
  no fixture was renamed or deleted.

---

### Phase 5: Redeploy and Full Gate [NOT STARTED]

**Goal**: Regenerate the deployed `.claude/` tree from the source store so the change is live,
and close the task on the complete gate set.

**Tasks**:
- [ ] Re-read the four source-store files touched by Phases 1-4 and confirm the marker literal is
      identical in the script, in `plan-format.md`, and in `challenge-snapshot.md`.
- [ ] Run the deploy (`bash agent-system/extensions/core/scripts/deploy-headless.sh` from the
      repository root, or the extension picker's regenerate entry) and confirm it reports success.
- [ ] Confirm the deployed copies carry the change:
      `grep -c "lean-challenge-statements:none" .claude/context/formats/plan-format.md`,
      `.claude/scripts/lean-challenge-snapshot.sh`, and
      `.claude/context/project/lean4/domain/challenge-snapshot.md` are each at least 1.
- [ ] Run the full gate set and record the result.
- [ ] Run the deployed copy of the suite once
      (`bash .claude/scripts/tests/test-lean-challenge-snapshot.sh` if present at that path after
      deploy, else note that gate 8 covers it) to confirm the deployed script behaves identically
      to the source-store one.
- [ ] Re-verify all four acceptance criteria explicitly against observed output, naming the case
      or command that evidences each.

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that the deploy regenerates the entire `.claude/` tree
and touches no source-store file; the implementer confirms with `git status --short` after the
deploy, expecting changes confined to the deployed tree (which is gitignored) plus nothing new
under `agent-system/**`.

**Files to modify**:
- `__WHOLE_TREE__` - the deploy regenerates the entire deployed `.claude/` tree

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`) passes the complete gate set, with no
  gate reporting the zero-check-under-filter condition.
- `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` passes from
  the source store, and gate 8's deployed-tree run of the same suite passes inside the
  `verify-deploy.sh` run above.
- Acceptance (a): the `### Zero Lean Goals (no theorem deliverable)` subsection is present in
  `plan-format.md`. Acceptance (b): case `Z1` observes exit `72`, and `72` appears in both the
  script header and `challenge-snapshot.md`'s Exit-Code Vocabulary table. Acceptance (c): case
  `Z3` observes exit `71` with the malformed-section message. Acceptance (d): the pre-existing
  case inventory is green and unmodified.
- `git status --short` shows no unexpected source-store modification introduced by the deploy.

## Testing & Validation

- [ ] `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` exits 0
      with cases `Z1`-`Z4` passing and no regression in R1-R21/M1-M3/C1-C4/AV1.
- [ ] A marker fixture plan with zero Goals identifiers exits `72`, writes no manifest, makes no
      commit, and prints an explicit informational message (acceptance (b)).
- [ ] A marker fixture plan whose `**Goals**:` names identifiers exits `71` naming the
      inconsistency (Decision 2).
- [ ] A present-but-empty section with no marker exits `71` with the existing malformed-section
      message (acceptance (c)).
- [ ] `72` and `71` are distinct observed exit values for the two cases, asserted by `Z4`
      (the non-collapse requirement).
- [ ] `bash .claude/scripts/verify-deploy.sh` passes the complete gate set after redeploy.
- [ ] Gates 3 and 4 report non-SKIP and pass for the two markdown edits.
- [ ] No file under `agent-system/**` contains a task-number reference introduced by this work.

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/plan-format.md` — new
  `### Zero Lean Goals (no theorem deliverable)` subsection plus a pointer clause on
  numbered-section entry `6.`
- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` — `extract_r1` status `3`,
  `ROUTE="zero-goal"`, three-way `GOALS_FILE` branch, exit `72`, updated exit-code header
- `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md` — `72` row in
  the Exit-Code Vocabulary table, new `### Zero-Goal Marker` subsection
- `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` — cases `Z1`-`Z4`
- Three new fixtures under
  `agent-system/extensions/lean/scripts/tests/fixtures/challenge/`
- Regenerated deployed `.claude/` tree
- `specs/385_lean4_plan_with_zero_lean_goals/summaries/01_zero-lean-goals-plan-shape-summary.md`

## Rollback/Contingency

Each phase commits independently, so rollback is per-phase `git revert` of that phase's commit
followed by a redeploy. The script change is the only behavioural edit and is additive: reverting
it restores the status-`2` -> `71` collapse without affecting any other route, since the
status-`2` branch, the R2 fallback arm, and the non-`zero-goal` `GOALS_FILE` message are all
preserved byte-for-byte by construction. If Phase 1's `GOALS_FILE` branch rewrite turns existing
case `R21` RED and cannot be reconciled, stop and reconsider the mechanism rather than weakening
`R21`: the unconditional-guard protection it pins is load-bearing, and a marker design that
cannot coexist with it is the wrong design. If the deploy in Phase 5 fails, the source store is
already correct and committed; re-run the deploy rather than reverting source-store commits. Take
a defensive checkpoint with
`bash .claude/scripts/git-snapshot.sh 385 --no-revert` before Phase 1 if the working tree carries
unrelated sibling-task changes.
