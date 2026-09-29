# Implementation Plan: Task #136

- **Task**: 136 - Implementation-agent contract corrections: plan-level Status ownership, no
  fan-out, marker/commit sync, validator catch
- **Status**: [NOT STARTED]
- **Effort**: 10 hours
- **Dependencies**: 139 (completed), 91 (completed, archived), 13 (completed, archived)
- **Research Inputs**: specs/136_enforce_plan_status_field_ownership/reports/01_plan-status-field-ownership.md
- **Artifacts**: plans/01_plan-status-field-ownership.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Three defect threads share one root cause: agent contract text is allowed to drift from what
`validate-artifact.sh` enforces, and nothing mechanically closes the gap. This plan fixes both
ends of each thread — the contract text that produces the drift AND the validator/lint layer that
should catch it — using the two enforcement mechanisms this codebase already operates: a canonical
fragment in `context/contracts/` whose literal copies are kept in sync by a
`lint-agent-contracts.sh` check (the Check C precedent), and a shared `scripts/lib/` pattern
library sourced by the validator (the `phase-heading-patterns.sh` precedent). Definition of done:
every implementation agent that is told to edit phase-heading markers also carries the plan-level
Status ownership boundary and is grep-verified to carry it by a lint check; `validate-artifact.sh`
rejects the three malformed Status shapes and accepts the conforming one; the report-heading
drift is reproduced in a fixture and shown fixed; the fan-out and marker/commit-sync contract gaps
are closed by one normative statement all 13 agents already load; and all of it survives a
redeploy.

### Research Integration

The research report supersedes this task's own dispatch text on two load-bearing points, and this
plan implements the research, not the dispatch's literal wording:

1. **Task 91 shipped "accept trailing text", not "reject" it.** The three malformed shapes are
   **M1** (line does not match `^- \*\*Status\*\*:` at all), **M2** (prefix present, no `[...]`
   pair anywhere on the line), **M3** (bracket pair present but text intrudes *between* the prefix
   and the opening `[`). Arbitrary text *after* the closing `]` is well-formed and preserved
   verbatim across a stamp. The dispatch lists "trailing text after the closing bracket" as
   malformed; implementing that literally would re-diverge from 91 the moment it landed. Verified
   live against `update-plan-status.sh:103-118` and `plan-format.md`'s trailing-annotation policy.
2. **Task 13 is closed (decision D-A: `--fix` remains in-place-mutating on the gate-out path).**
   The dispatch's "do not silently add a new in-place mutation while that decision is open" caveat
   is discharged; the bar is now consistency with D-A, which this plan meets by deciding
   **report-only** with stated reasoning (Phase 4).
3. **The "at minimum" 4-file list undercounts and misnames one file.**
   `general-implementation-hard-agent.md` does not exist (general/meta/markdown have no hard-mode
   agent variant). The real in-scope set is **13 files**, zero of which carry any ownership
   language today.
4. **The report-skeleton is not validator-non-conforming.** `grep -qE "^##+ ${section}"` matches
   `###` as readily as `##`, so `general-research-agent.md`'s nested `### Recommendations` already
   satisfies the check. The defect is drift in produced prose, not a broken skeleton or a broken
   regex — so remedy (iii) (relaxing the validator) is both unnecessary and dangerous and is
   rejected.

Four findings this plan adds on top of the research, established during planning:

5. **`lint-agent-contracts.sh` already exists** with a Check A/B/C/E/F structure, a shared
   `enumerate_dispatchable_agents` detector, a documented insertion point for further checks, and
   a fixture-driven suite (`test-lint-agent-contracts.sh`). It runs inside `verify-deploy.sh` as
   gate 6. The ownership bullet gets Check G here rather than a new script.
6. **`context/contracts/phase-closure.md` is `@`-referenced as "always load"/"MANDATORY" from all
   13 in-scope agents** (confirmed by grep across `agent-system/extensions/*/agents/`). It is
   therefore the single normative statement the dispatch asked for ("prefer that over copying the
   same paragraph into four files") for the fan-out and marker/commit-sync additions — its
   existing charter, "how a single implementation dispatch sequences its own work across the
   phases of a plan", already covers both.
7. **All 193 plan files under `specs/` and `specs/archive/` currently conform** to the Status-line
   grammar (swept by the M1/M2/M3 predicate during planning; zero non-conforming). The new
   grammar check can therefore land at **error** level immediately, with no advisory-first stage
   and no legacy-plan breakage — unlike the Verification Tier check, whose promotion criterion is
   still unmet.
8. **Artifact validation is non-blocking at every call site** (`skill-base.sh:618` and `:772`,
   `orchestrator-postflight.sh:286` all downgrade a non-zero exit to a counted WARNING). A new
   error-level check surfaces loudly in the aggregated counters and the `events.jsonl` row without
   ever blocking a status transition — which is exactly the desired behavior and removes the main
   risk of erroring rather than warning.
9. **The research's sweep glob was `*implementation*agent.md`**, which misses the
   `*-implement-agent.md` naming form (`epi-implement-agent.md`, `founder-implement-agent.md`).
   Both were checked during planning and carry zero phase-marker-editing instructions, so the
   13-file set stands — but Phase 1 re-runs the sweep with a *predicate over all* `*/agents/*.md`
   rather than a name glob, so the enumeration is established by rule and not by glob luck.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; ROADMAP.md was not consulted.

## Goals & Non-Goals

**Goals**:
- A canonical, lint-enforced ownership boundary: the plan METADATA `- **Status**:` field is owned
  by `update-plan-status.sh` (driven from `update-task-status.sh` postflight) and MUST NOT be
  hand-edited; an implementation agent's plan-file write authority is limited to
  `### Phase N: ... [MARKER]` headings and checklist items.
- `validate-artifact.sh` rejects M1/M2/M3 on a plan artifact and accepts the conforming shape
  including trailing annotations, with the classification logic in a shared library rather than a
  third independent copy of the regex.
- A stated, reasoned `--fix` participation decision, consistent with task 13's shipped D-A.
- The report-heading drift closed on the agent side (skeleton + non-paraphrasable heading list),
  with the historically observed failure reproduced in a fixture and shown to pass after the fix.
- The fan-out question answered, the terminal-status requirement stated, and marker/commit
  divergence forbidden **in both directions**, in one normative statement all 13 agents load.
- Everything survives `deploy-headless.sh` regeneration (source store is the edit target).

**Non-Goals**:
- Editing `update-plan-status.sh`, `update-task-status.sh`, or `context/formats/plan-format.md`.
  The dispatch's SCOPE BOUNDARY excludes all three. Task 91 is completed and archived, so the
  *collision* rationale is discharged, but the boundary is honored anyway: Phase 5 replaces the
  refactor with a **read-only conformance test** that fails if the new library and
  `update-plan-status.sh` ever disagree, which buys the drift protection without the edit. The
  one-line-per-branch refactor of `update-plan-status.sh` onto the shared library is recorded as a
  follow-up, not done here.
- Relaxing any validator check to make an artifact green (dispatch option (iii), explicitly
  rejected — a substring relax would let `## Context Extension Recommendations` satisfy
  `Recommendations`, converting a true failure into a false pass).
- Re-litigating the status-vocabulary half of the absorbed former-task-14 work.
  `orchestrate-recover-outcome.sh`'s `STATUS_IN_PROGRESS` verdict and
  `skill-orchestrate/SKILL.md`'s off-schema handling of `in_progress` are already correct and are
  not touched.
- Promoting the per-phase Verification Tier advisory to an error (its own promotion criterion is
  unmet; out of scope).
- Backfilling pre-existing non-conforming artifacts authored before their agent gained a
  conforming skeleton.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The new grammar check errors on a legacy plan and floods gate-out warnings | M | L | Planning swept all 193 plans: zero non-conforming. Phase 4 re-runs the sweep as a gate before switching the check to error level; if any plan is non-conforming at implementation time, land the check at warn level and record the promotion criterion instead of erroring |
| The shared library and `update-plan-status.sh` drift apart (the exact bug class this task exists to prevent) | H | M | Phase 5 adds a read-only conformance test asserting per-fixture agreement between the library's verdict and `update-plan-status.sh`'s live accept/reject behavior — it fails loudly on any future divergence without this task editing that script |
| 13 near-identical hand edits drift in wording | M | M | One exact fenced paragraph in the canonical fragment, copied verbatim; Check G (Phase 3) reads the expected text from the fragment at runtime and greps every in-scope file for it, so drift is a lint failure, not a silent inconsistency |
| The curated Check G in-scope list goes stale as agents are added | M | M | The fragment carries the classification rule ("carries the bullet iff its contract instructs editing `### Phase N ... [MARKER]` headings") and Phase 1 records the exact predicate sweep command that derives the list, mirroring Check C's documented convention |
| Auto-fixing the Status grammar guesses wrong on M3 | H | L | Decided report-only (Phase 4). No auto-repair path exists to guess with |
| Sibling task edits the same file this cycle | M | L | No declared sibling `file_scope` in this dispatch's territory block names any file this plan touches. `run-all.sh` (task 265) is NOT edited — it auto-globs `test-*.sh`, so the new suite registers itself; `suite-cost-hints.txt` is advisory and skipped. Per territory contract: re-read every file immediately before editing, stage only this task's own hunks, never a directory or glob `git add` |
| Widening `phase-closure.md` makes the 13 agents' one-line `@`-reference descriptions ("depth-first phase closure") inaccurate | L | H | Phase 2 updates that description line in the same per-file pass as the ownership bullet, so each of the 13 files is touched exactly once |
| A redeploy is required for the fix to be live, and a stale `.claude/` tree masks it | M | M | Phase 8 runs `deploy-headless.sh` plus `verify-deploy.sh` and re-runs Check G and the new suite from the **deployed** tree, not only the source store |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4, 6, 7 | -- |
| 2 | 2, 5 | 1, 7 (for 2); 4 (for 5) |
| 3 | 3 | 1, 2 |
| 4 | 8 | 1, 2, 3, 4, 5, 6, 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Canonical ownership fragment and predicate-derived in-scope enumeration [NOT STARTED]

**Goal**: Establish the single authoritative text of the plan-level Status ownership boundary, and
derive the in-scope agent set by a stated rule rather than by a name glob.

**Tasks**:
- [ ] Re-run the in-scope sweep as a **predicate over every** `agent-system/extensions/*/agents/*.md`
      (never a filename glob): a file is in scope iff it is a dispatchable agent (first line `---`,
      frontmatter carries `name:`) AND its body instructs editing a `### Phase {P}: ... [MARKER]`
      heading or calls `update-phase-status.sh`. Record the exact command and its output.
- [ ] Confirm the candidates the research's `*implementation*agent.md` glob could not see
      (`epidemiology/agents/epi-implement-agent.md`, `founder/agents/founder-implement-agent.md`)
      are correctly out of scope, and that `cslib/agents/pr-review-implementation-agent.md` and
      `email/agents/email-implementation-agent.md` remain out of scope (no phase-heading write
      authority to bound).
- [ ] Create `agent-system/extensions/core/context/contracts/plan-status-ownership.md`, mirroring
      `context/contracts/no-task-references-bullet.md`'s shape section-for-section: purpose; the
      "generated-copy source, not an `@`-import" note; **the exact bullet text in a fenced block**;
      the classification rule; the placement rule; and a pointer to `plan-format.md`'s existing
      "Plan-level vs. phase-level markers" subsection as the authority for the two-vocabulary /
      two-owner distinction (pointer only — that file is not edited).
- [ ] Bullet text requirements: names `update-plan-status.sh` and `update-task-status.sh`
      postflight as the owner; states the metadata `- **Status**:` field MUST NOT be hand-edited;
      states positively what the agent's plan-file write authority *is* (`### Phase N: ...
      [MARKER]` headings and `- [ ]` checklist items); contains **no digits** so it cannot trip
      `check-task-references.sh`'s own gate (the same constraint `no-task-references-bullet.md`
      documents for its own placeholder forms).
- [ ] Record the derived in-scope list inside the fragment, as Check C's list is recorded, with a
      note that a future agent addition must be classified by the rule rather than inferred.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: The in-scope set is **13 files** (`core/agents/general-implementation-agent.md`;
`lean/agents/lean-implementation-{,hard-}agent.md`;
`cslib/agents/cslib-implementation-{,hard-}agent.md`; and the `python`, `rust`, `latex`, `typst`,
`z3`, `nvim`, `nix`, `web` implementation agents). All 13 were confirmed to exist during planning.
Confirm at implementation time by the predicate sweep above, not by reusing this list: if the
sweep yields a different set, the sweep wins and the fragment records the difference.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/plan-status-ownership.md` - new canonical
  fragment: bullet text, classification rule, placement rule, in-scope enumeration

**Verification**:
- The fragment exists and its fenced bullet block yields exactly one line under
  `grep -F` extraction (the mechanism Check G will use in Phase 3).
- `grep -cE '[0-9]' <the fenced bullet line>` returns 0.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` (or its deployed
  equivalent) reports no new finding for the fragment.
- The recorded sweep output and the fragment's in-scope list agree file-for-file.

---

### Phase 2: Roll the ownership bullet into every in-scope agent contract [NOT STARTED]

**Goal**: Every in-scope implementation agent carries the verbatim ownership bullet, and its
`phase-closure.md` reference line reflects that contract's widened scope.

**Tasks**:
- [ ] For each in-scope agent from Phase 1's enumeration: re-read the file immediately before
      editing (territory contract, concurrent siblings this cycle), then insert the fragment's
      bullet **verbatim** as the next sequential numbered item in the existing
      `## Critical Requirements` -> `**MUST NOT**:` list. Do not renumber or reword any
      surrounding bullet. Where an agent has no MUST NOT list, add one under
      `## Critical Requirements` rather than inventing a new section shape.
- [ ] In each agent that carries the existing sentence "Phase status lives ONLY in the heading. Do
      NOT add or edit a separate `**Status**:` line per phase." (present in
      `general-implementation-agent.md` at both the Mark-Phase-In-Progress and Mark-Phase-Complete
      steps), append one sentence distinguishing the *plan-level metadata* `- **Status**:` field
      from the per-phase case that sentence already covers, pointing at the new fragment. This puts
      the boundary adjacent to the instruction that produced the generalization, not only in the
      MUST NOT list at the end of the file.
- [ ] Update each agent's `@.claude/context/contracts/phase-closure.md` reference description from
      "depth-first phase closure: close one phase before opening the next" to also name the
      no-fan-out and marker/commit-synchrony content Phase 7 adds, so the one-line description
      stays accurate.
- [ ] Commit per file (each file is its own independently green sub-step).

**Timing**: 1.5 hours

**Depends on**: 1, 7

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: 13 files, each receiving one MUST NOT bullet, one adjacent clarifying
sentence (where the anchor sentence exists), and one reference-description update. The anchor
sentence is confirmed present in `general-implementation-agent.md`; its presence in the other 12
is a hypothesis — where absent, place the clarifying sentence next to that agent's own
`update-phase-status.sh` / phase-heading Edit instruction instead, and record which files differed.

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` - MUST NOT bullet,
  adjacent clarifying sentence at both mark-phase steps, reference-description update
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` - same three edits
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - same three edits
- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` - same three edits
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` - same three edits
- `agent-system/extensions/python/agents/python-implementation-agent.md` - same three edits
- `agent-system/extensions/rust/agents/rust-implementation-agent.md` - same three edits
- `agent-system/extensions/latex/agents/latex-implementation-agent.md` - same three edits
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` - same three edits
- `agent-system/extensions/z3/agents/z3-implementation-agent.md` - same three edits
- `agent-system/extensions/nvim/agents/neovim-implementation-agent.md` - same three edits
- `agent-system/extensions/nix/agents/nix-implementation-agent.md` - same three edits
- `agent-system/extensions/web/agents/web-implementation-agent.md` - same three edits

**Verification**:
- `grep -lF "<the fragment's bullet opening clause>"` across the in-scope set returns every file
  in Phase 1's enumeration and nothing is missing — this is the dispatch's "verified by grep, not
  by assumption" acceptance criterion, satisfied before Phase 3 mechanizes it.
- `grep -c "phase-closure.md"` is unchanged per file (description updated, reference not
  duplicated or dropped).
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` still exits 0 (Checks
  A/B/C/E/F unaffected by the insertion).
- No task-number references introduced: repo-wide `check-task-references.sh` clean.

---

### Phase 3: Lint Check G enforcing the ownership bullet [NOT STARTED]

**Goal**: The ownership bullet's presence is a mechanical gate, not a one-time rollout, and it runs
inside `verify-deploy.sh`.

**Tasks**:
- [ ] Add `check_g_plan_status_ownership_bullet()` to
      `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`, following Check C's
      mechanism exactly: read the expected bullet text from
      `context/contracts/plan-status-ownership.md` **at runtime** (never hardcode it), iterate a
      curated `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS` array, `log_fail` on a missing file or a missing
      bullet, `log_pass` per conforming file. A missing fragment is a Check-level fail with the
      same message shape Check C uses.
- [ ] Reuse `rel_path` and the `$AGENTS_ROOT` convention; do not re-derive the
      dispatchable-agent detector.
- [ ] Wire `check_g_plan_status_ownership_bullet` into `main()`, and extend both the file-header
      check list and the `--help` output with Check G's one-line description.
- [ ] Add fixture cases to `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh`
      following its existing scratch-repo idiom (`mktemp -d`, `REPO_ROOT=<scratch>`, assert on exit
      code and specific `[FAIL]`/`[PASS]` lines, never instrument the lint script):
      (a) an in-scope fixture agent missing the bullet -> Check G FAILs, exit 1;
      (b) the same fixture carrying the verbatim bullet -> no Check G FAIL;
      (c) a fixture whose bullet text is a near-miss paraphrase -> still FAILs (proves the check
          compares against the fragment, not a loose pattern);
      (d) fragment file absent from the scratch tree -> Check G reports the fragment-missing fail
          rather than silently passing.
- [ ] Copy the canonical fragment into the scratch fixture tree the way the suite already stages
      `FRAGMENT_SRC` / `ARTIFACTS_FRAGMENT_SRC`, so the fixture exercises the real read path.

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Scope Hypothesis**: The curated in-scope array duplicates Phase 1's enumeration (13 entries).
Confirm at implementation time that Check G's array and the fragment's recorded list are
identical, and add a comment in the lint naming the fragment as the source of truth for the rule
(as Check C does) so a future addition is classified rather than guessed.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - new Check G function,
  in-scope array, `main()` wiring, header-comment and `--help` updates
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` - four Check G fixture
  cases and fragment staging

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` exits 0 with the
  four new cases reported PASS.
- `cd <repo> && REPO_ROOT=$PWD bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose`
  exits 0 against the real tree and prints a Check G pass line for every in-scope agent.
- Temporarily removing the bullet from one real agent makes the lint exit 1 naming that file;
  restore it afterward (verify by re-running the lint to 0).
- `bash agent-system/extensions/core/scripts/verify-deploy.sh` gate 6 (agent contracts lint) still
  passes.

---

### Phase 4: Shared plan-status-line grammar library and validator wiring [NOT STARTED]

**Goal**: `validate-artifact.sh` rejects M1/M2/M3 on a plan artifact and accepts the conforming
shape including trailing annotations, with the classification in a shared library rather than a
third independent copy of the regex.

**Tasks**:
- [ ] Re-run the conformance sweep over every `specs/*/plans/*.md` and
      `specs/archive/*/plans/*.md` with the M1/M2/M3 predicate. Planning measured **193 plans, 0
      non-conforming**. If the count is still 0, land the new check at **error** level. If any
      plan is non-conforming, land it at **warn** level instead and record the promotion criterion
      in the script (the same advisory-first idiom the Verification Tier check documents) — do not
      silently error and flood gate-out.
- [ ] Create `agent-system/extensions/core/scripts/lib/plan-status-line.sh` exporting a
      classifier, e.g. `plan_status_classify FILE` printing one of `OK`, `M1`, `M2`, `M3` plus the
      offending line number and content on the malformed arms. Mirror
      `update-plan-status.sh:77-118`'s logic exactly: `^- \*\*Status\*\*:` prefix detection,
      then `^-\ \*\*Status\*\*:\ \[[^]]*\]` for well-formed (trailing text after `]` tolerated by
      design), then a bare `\[[^]]*\]` presence test to separate M3 from M2.
- [ ] Give the library a header comment that (a) names `update-plan-status.sh` as the sibling
      implementation whose behavior it must agree with, (b) states the accept-trailing-text policy
      and points to `plan-format.md`'s "Plan-level vs. phase-level markers" subsection, and (c)
      records that refactoring `update-plan-status.sh` onto this library is deferred follow-up
      (out of this task's scope boundary), with the Phase 5 conformance test named as the guard in
      the meantime.
- [ ] Source the library in `validate-artifact.sh`'s `plan` branch using the **same lazy,
      `${BASH_SOURCE[0]}`-relative, exit-5-on-missing idiom** already used for
      `phase-heading-patterns.sh` (correct in both the source store and the deployed tree; never
      fall through to an inline pattern). Extend the script's exit-code header comment to name the
      second library.
- [ ] Emit a shape-specific `log_error` per malformed arm, quoting the line number and content:
      M1 "plan-level Status line not found (expected: `- **Status**: [STATUS]`)"; M2 "plan-level
      Status line has no [STATUS] bracket pair"; M3 "plan-level Status line has unexpected text
      between the prefix and the bracket". Keep the wording aligned with
      `update-plan-status.sh`'s own three diagnostics so an operator sees the same language from
      both layers.
- [ ] **Do not add a `--fix` repair arm.** Add a comment block at the check stating the decision
      and its reasoning (see Verification below for the reasoning that must be recorded).

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: 193 plan files, 0 currently non-conforming (measured during planning by the
M1/M2/M3 predicate over both `specs/*/plans/*.md` and `specs/archive/*/plans/*.md`). Confirm by
re-running that sweep as the phase's first task; the error-vs-warn level of the new check is
conditional on its result.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/plan-status-line.sh` - new shared classifier library
- `agent-system/extensions/core/scripts/validate-artifact.sh` - source the library in the plan
  branch, add the grammar check with three shape-specific errors, extend the exit-code header
  comment, record the no-`--fix` decision inline

**Verification**:
- Five hand-run fixtures behave correctly: conforming; conforming + trailing annotation
  (`- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)`) -> both PASS; M1, M2
  (`- **Status**: COMPLETED`), M3 (`- **Status**: see [NOTE]`) -> each FAILs with its own message.
- The M2 fixture that validated `[PASS]` before this phase now FAILs — the dispatch's DEFECT 2,
  closed.
- `--fix` on the M2 fixture leaves the Status line **byte-identical** (no repair attempted) and
  still reports the error.
- Deleting the library makes the plan branch exit 5 with the environment-error message, not
  degrade silently.
- The `--fix` decision is recorded with this reasoning: consistent with task 13's shipped D-A
  (which permits in-place gate-out repair), but declined here on three independent grounds —
  (1) the existing `--fix` only ever *inserts a placeholder for an absent field* and has never
  rewritten an author-supplied value, so a grammar repair is a new mutation class, not an
  extension of the existing one; (2) M3 offers no derivable intent and M1 no anchor, so two of
  three shapes are unrepairable anyway; (3) most importantly, auto-repair would erase the only
  signal that an agent hand-wrote the line, defeating this task's own producer-side purpose.
  Because validation is non-blocking at every call site, an error here surfaces loudly in the
  aggregated counters and the `events.jsonl` row without blocking any status transition.

---

### Phase 5: Validator test suite and cross-script conformance guard [NOT STARTED]

**Goal**: Both the Status-grammar behavior and the report-heading behavior are fixture-locked, and
the new library is mechanically prevented from drifting away from `update-plan-status.sh`.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` following
      `context/standards/shell-script-testing.md`'s core convention (`pass`/`fail`/`info`
      helpers, PASSED/FAILED counters, `mktemp -d` workdir with `trap EXIT` cleanup, exit 0 on
      all-pass / 1 on any-fail). Never instrument `validate-artifact.sh`.
- [ ] Status-grammar cases: conforming PASS; conforming-with-trailing-annotation PASS; M1 FAIL;
      M2 FAIL; M3 FAIL; each malformed case asserted on its own distinct message.
- [ ] `--fix` non-participation case: run `--fix` on the M2 fixture and assert the Status line is
      byte-identical afterward and the error is still reported.
- [ ] Report-heading cases (the absorbed former-task-166 thread): a report fixture carrying
      `## Context Extension Recommendations` and `## Recommended Next Steps (for the plan phase)`
      but no `## Recommendations` FAILs with `Missing required section: ## Recommendations`; the
      same fixture with a top-level `## Recommendations` added and nothing else changed PASSes;
      and — the dispatch's explicit requirement — a fixture carrying
      `## Context Extension Recommendations` **alone** still FAILs, proving the check was not
      relaxed into a false pass.
- [ ] Depth-tolerance case: a report whose only conforming heading is `### Recommendations`
      (nested under `## Findings`) PASSes, locking in the `^##+` any-depth semantics so a future
      change cannot quietly narrow it.
- [ ] Cross-script conformance guard: for each of the five Status-grammar fixtures, build a
      throwaway `specs/{NNN}_{slug}/plans/01_*.md` layout inside the scratch dir, invoke the real
      `update-plan-status.sh` against it, and assert its accept/reject outcome agrees with
      `plan-status-line.sh`'s verdict for the same fixture. This is read-only with respect to
      `update-plan-status.sh` — it is never edited — and it fails loudly if the two
      classifications ever diverge.
- [ ] No `run-all.sh` edit: it auto-globs `scripts/tests/test-*.sh`, so the suite self-registers.
      `suite-cost-hints.txt` is advisory and deliberately left alone.

**Timing**: 1.75 hours

**Depends on**: 4

**Verification Tier**: local

**Scope Hypothesis**: ~11 fixture cases (5 grammar + 1 `--fix` + 4 heading + 5 conformance
assertions, some sharing fixtures). The exact count is a hypothesis; confirm the suite's own
reported PASSED total matches the enumerated case list at implementation time rather than assuming
this number.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` - new suite: Status
  grammar, `--fix` non-participation, report-heading conformance, depth tolerance, and the
  `update-plan-status.sh` cross-script conformance guard

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` exits 0 with every
  enumerated case reported PASS.
- The suite is discovered and run by
  `bash agent-system/extensions/core/scripts/tests/run-all.sh` without any edit to that file.
- Reverting Phase 4's grammar check makes the suite fail on the grammar cases (it genuinely tests
  the new behavior rather than passing vacuously).
- Perturbing `plan-status-line.sh`'s M3 branch makes the conformance guard fail; restore and
  re-run to 0.

---

### Phase 6: Report-heading conformance remedy in general-research-agent.md [NOT STARTED]

**Goal**: Close the produced-report heading drift on the agent side, with the core skeleton
inventory machine-checked rather than eyeballed.

**Tasks**:
- [ ] Promote `### Recommendations` in `general-research-agent.md`'s Stage 6 report skeleton to a
      top-level `## Recommendations`, placed between `## Findings` and `## Decisions` — dispatch
      remedy (ii), which structurally removes contributing factor (a) (burial as a third-level
      subsection alongside two non-required siblings). Leave `### Codebase Patterns` and
      `### External Resources` nested under `## Findings` unchanged.
- [ ] Add dispatch remedy (i) alongside it: a short, explicit statement in Stage 6 listing the
      **five required heading strings verbatim** (`## Executive Summary`, `## Context & Scope`,
      `## Findings`, `## Decisions`, `## Recommendations`) and marking them **non-paraphrasable**.
      Name the two observed near-misses explicitly — "Recommended Next Steps" and "Context
      Extension Recommendations" do **not** satisfy `## Recommendations` — because the near-miss
      trap (contributing factor (b)) is what the observed artifact actually fell into.
- [ ] Keep `## Context Extension Recommendations` in the skeleton (it is a distinct, useful
      section) but note in the same statement that it is additional to, never a substitute for,
      `## Recommendations`.
- [ ] Machine-check every core agent's embedded skeleton against the validator's own regex
      (`grep -qE "^##+ ${section}"` for each member of `REPORT_SECTIONS`, `SUMMARY_SECTIONS`,
      `PLAN_SECTIONS`) with a throwaway script that extracts each skeleton to a temp file and runs
      the real regex — not by eye. Record the result for every core agent, including the
      no-skeleton and no-applicable-type cases.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: Only `general-research-agent.md` needs a skeleton change.
`general-implementation-agent.md` (six `SUMMARY_SECTIONS`, all top-level) and `planner-agent.md`
(seven `PLAN_SECTIONS`, all top-level) were reported conforming; `reviser-agent.md` carries no
embedded skeleton; `code-reviewer-agent.md`, `meta-builder-agent.md`, and `spawn-agent.md` author
no validated artifact type. Confirm all seven by the machine check above before concluding no
further gaps exist — the enumeration, not just the one fix, is an acceptance criterion.

**Files to modify**:
- `agent-system/extensions/core/agents/general-research-agent.md` - promote
  `### Recommendations` to top-level `## Recommendations` in the Stage 6 skeleton; add the
  verbatim/non-paraphrasable five-heading statement naming both observed near-misses

**Verification**:
- The machine check reports every `REPORT_SECTIONS` member satisfied by the revised skeleton, and
  reports per-agent results for all seven core agents.
- Phase 5's heading fixtures still behave as specified (near-miss-only FAILs, conforming PASSes).
- Extracting the revised Stage 6 skeleton to a file and running
  `validate-artifact.sh <file> report` reports no missing-section error.
- The word "Recommendations" appears in the skeleton as both `## Recommendations` and
  `## Context Extension Recommendations`, and the statement text makes the distinction explicit.

---

### Phase 7: Fan-out prohibition and bidirectional marker/commit synchrony [NOT STARTED]

**Goal**: Answer the two open questions absorbed from former task 14, in one normative statement
that all 13 in-scope agents already load, plus MUST NOT bullets in the normative core agent.

**Tasks**:
- [ ] Add a `## No fan-out to phase sub-agents` section to
      `agent-system/extensions/core/context/contracts/phase-closure.md`, resolving question 1 as a
      **prohibition**: a dispatched implementation agent MUST NOT delegate plan-phase execution to
      sub-agents. Reasoning to record: the dispatched agent alone owns its `.return-meta.json` and
      `.orchestrator-handoff.json`, a child cannot write the parent's terminal status, and a
      parent returning while children still run is precisely the observed failure (twice in one
      lean4 batch, both leaving `status: "in_progress"`). Carve out read-only search/exploration
      fan-out, which cannot leave work uncommitted.
- [ ] State the terminal-status corollary in the same section: the dispatched agent writes its own
      terminal `.return-meta.json` **before returning**, covering all work performed under it;
      `in_progress` is early-metadata-only and never a legal terminal dispatch outcome. Point at
      `context/formats/return-metadata-file.md` for the vocabulary rather than restating it. Note
      that this retires the per-dispatch prompt text used as the incident workaround — the wording
      is known to work; the point is that it now lives in the contract.
- [ ] Add a `## Marker/commit synchrony is bidirectional` section resolving question 2, with both
      directions stated as requirements:
      - **Promotion-on-commit** (under-claim direction): a phase's marker promotion is committed
        together with that phase's final work, never deferred to a later commit or to the end of
        the dispatch. Note that `general-implementation-agent.md`'s existing scoped-commit staging
        set already includes `{plan_path}`, so this is a sequencing requirement, not a new staging
        one.
      - **No-promotion-without-evidence** (over-claim direction): a marker is promoted only after
        that phase's own declared verification has been **run in this dispatch and observed
        green**. An inherited `[COMPLETED]` or `[IN PROGRESS]` marker on a resumed dispatch is
        re-verified by actually running the phase's verification, never trusted on sight. Record
        why both directions are needed: the over-claim case (five of seven phases `[COMPLETED]`
        against an unmodified declared `file_scope`) was caught only because the orchestrator
        cross-checked markers against the working tree, and a fix that merely tightened
        promotion-on-commit would not have caught it.
- [ ] Add two MUST NOT bullets to `general-implementation-agent.md` (the normative contract; the
      12 extension agents are conformers reached by the `@`-reference they already carry): no
      fan-out of plan-phase execution to sub-agents; no marker promotion without this dispatch's
      own green verification. Point both at `phase-closure.md` rather than restating the reasoning.
- [ ] Re-read `phase-closure.md`'s existing "Loaded via explicit reference in BOTH modes" section
      and, if its claim about extension coverage is stale relative to the grep evidence, correct
      it to match what is actually referenced.
- [ ] Do **not** touch `orchestrate-recover-outcome.sh` or `skill-orchestrate/SKILL.md`'s
      `in_progress` handling — already correct, explicitly out of scope.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: All 13 in-scope agents carry an
`@.claude/context/contracts/phase-closure.md` reference marked "always load" or "MANDATORY"
(confirmed by grep during planning; `epi-implement-agent.md` and `founder-implement-agent.md` also
reference it and will inherit the text harmlessly). Re-confirm before relying on the
single-statement mechanism: if any in-scope agent lacks the reference, add it in Phase 2's
per-file pass rather than duplicating the contract text into that file.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/phase-closure.md` - new `## No fan-out to phase
  sub-agents` section (with the terminal-status corollary) and new `## Marker/commit synchrony is
  bidirectional` section; correct the load-path claim if stale
- `agent-system/extensions/core/agents/general-implementation-agent.md` - two MUST NOT bullets
  pointing at the new sections

**Verification**:
- `grep -c "phase-closure.md"` across `agent-system/extensions/*/agents/*.md` confirms every
  in-scope agent still reaches the contract.
- Both new sections are reachable from the contract's own heading outline and state their
  requirement in imperative MUST/MUST NOT form, not as advice.
- The bidirectional requirement names both observed directions (markers under-claiming against
  landed commits; markers over-claiming against an unmodified `file_scope`).
- `check-task-references.sh` clean: the incident narratives are described by symptom, never by
  task number, since both files live outside `specs/**`.

---

### Phase 8: Redeploy, full gate set, and decision record [NOT STARTED]

**Goal**: Confirm every change survives `.claude/` regeneration and the whole gate set is green,
then record the three required decisions.

**Tasks**:
- [ ] Run the full test suite from the source store:
      `bash agent-system/extensions/core/scripts/tests/run-all.sh`.
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` to regenerate `.claude/`.
- [ ] Run `bash agent-system/extensions/core/scripts/verify-deploy.sh` and confirm gate 6 (agent
      contracts lint) passes with Check G included.
- [ ] Re-verify from the **deployed** tree, not only the source store: Check G passes via
      `.claude/scripts/lint/lint-agent-contracts.sh`; the new fixtures pass via
      `.claude/scripts/validate-artifact.sh`; `.claude/scripts/lib/plan-status-line.sh` exists and
      is sourced without the exit-5 environment error. This is the dispatch's "confirm the fix
      survives regeneration" criterion.
- [ ] Validate this plan file itself with the newly hardened validator:
      `bash .claude/scripts/validate-artifact.sh <this plan> plan` -> PASS, and confirm its own
      `- **Status**:` line is classified `OK`.
- [ ] Write the summary recording, explicitly: (1) the `--fix` non-participation decision with its
      three-ground reasoning and its consistency with task 13's shipped D-A (noted as **closed**,
      not open); (2) the fan-out resolution (prohibited, with the read-only carve-out) and the
      terminal-status corollary; (3) the bidirectional marker/commit-synchrony resolution. Include
      the grep evidence for the ownership-boundary rollout and the machine-check table for the
      core skeleton enumeration.
- [ ] Record the deferred follow-up: refactor `update-plan-status.sh`'s three classification
      branches onto `scripts/lib/plan-status-line.sh`, deliberately excluded here by the
      dispatch's scope boundary and currently guarded by Phase 5's conformance test.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5, 6, 7

**Verification Tier**: full

**Files to modify**:
- `specs/136_enforce_plan_status_field_ownership/summaries/01_plan-status-field-ownership-summary.md` -
  new execution summary carrying the three decision records, the grep evidence, the skeleton
  machine-check table, and the deferred follow-up

**Verification**:
- `run-all.sh` exits 0 with both new suites reported.
- `verify-deploy.sh` exits 0, gate 6 included.
- Deployed-tree re-verification of Check G, the validator fixtures, and library resolution all
  green.
- The summary contains all three decision records with reasoning, and the grep/machine-check
  evidence tables rather than assertions.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` exits 0,
      including the four new Check G cases.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` exits 0,
      including all Status-grammar, `--fix`-non-participation, report-heading, depth-tolerance,
      and cross-script conformance cases.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0 and discovers the new
      suite with no `run-all.sh` edit.
- [ ] `REPO_ROOT=$PWD bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose`
      exits 0 with a Check G pass line per in-scope agent; removing the bullet from any one agent
      makes it exit 1 naming that file.
- [ ] `bash agent-system/extensions/core/scripts/verify-deploy.sh` exits 0 (gate 6 included).
- [ ] The M2 fixture (`- **Status**: COMPLETED`) that validated `[PASS]` before this work now
      FAILs, and `--fix` leaves its Status line byte-identical.
- [ ] The conforming-plus-trailing-annotation fixture PASSes, matching task 91's shipped
      accept-and-preserve policy.
- [ ] The report fixture with near-miss Recommendations headings FAILs; with a conforming
      `## Recommendations` added it PASSes; with `## Context Extension Recommendations` alone it
      still FAILs.
- [ ] Repo-wide `check-task-references.sh` reports no new finding (every file touched outside
      `specs/**` describes incidents by symptom, never by task number).
- [ ] All 193 existing plan files still validate without a new Status-grammar error.

## Artifacts & Outputs

- `agent-system/extensions/core/context/contracts/plan-status-ownership.md` (new canonical fragment)
- `agent-system/extensions/core/scripts/lib/plan-status-line.sh` (new shared classifier library)
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` (new test suite)
- Modified: `scripts/validate-artifact.sh`, `scripts/lint/lint-agent-contracts.sh`,
  `scripts/tests/test-lint-agent-contracts.sh`,
  `context/contracts/phase-closure.md`, `agents/general-research-agent.md`,
  `agents/general-implementation-agent.md`, and the 12 other in-scope implementation agents
- Regenerated `.claude/` deploy tree (disposable artifact, not committed)
- `specs/136_enforce_plan_status_field_ownership/summaries/01_plan-status-field-ownership-summary.md`

## Rollback/Contingency

Every phase is additive and independently revertible; nothing removes or weakens an existing
check. Per-phase rollback is `git revert` of that phase's own scoped commits (per-substep commit
mode keeps them small and file-scoped), followed by a redeploy.

Phase-specific contingencies:
- If the Phase 4 sweep finds any non-conforming plan, land the grammar check at **warn** level
  with a recorded promotion criterion instead of **error**. The check still closes DEFECT 2's
  silent-pass; only its severity changes.
- If a Phase 2 target agent turns out to lack a `## Critical Requirements` MUST NOT list, add one
  under that heading rather than inventing a new section shape, and record the difference.
- If any in-scope agent turns out not to `@`-reference `phase-closure.md`, add the reference in
  Phase 2's per-file pass rather than copying Phase 7's contract text into that file.

Should a whole-tree revert of uncommitted work become necessary, snapshot first per
`context/contracts/recovery.md`'s rollback rung (which documents the required invocation shape,
including its out-of-scope override flag for the deliberate whole-tree case) — never a bare
default-mode `git-snapshot.sh` call as a routine checkpoint. A defensive checkpoint before risky
work uses `--no-revert`, which is durable without reverting the working tree.
