# Implementation Plan: Task #356

- **Task**: 356 - Propagate bounded-wait contract and add lint coverage
- **Status**: [NOT STARTED]
- **Effort**: 5.5 hours
- **Dependencies**: None (no dependency edges; related tasks recorded by durable anchor only)
- **Research Inputs**: specs/356_propagate_bounded_wait_contract_and_lint_coverage/reports/01_propagate-bounded-wait-contract.md
- **Artifacts**: plans/01_propagate-bounded-wait-contract.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The bounded-wait contract for a dispatched implementation agent exists and is correct; it is
simply absent from 14 of 17 implementation-agent definitions. This plan propagates it as a short,
literal, lint-verified MUST/MUST-NOT bullet pair sourced from **one** canonical fragment appended
to the existing `context/patterns/bounded-build-waiter.md`, adds the same bullet to the agent
template as a forward-looking complement, and extends
`core/scripts/lint/lint-agent-contracts.sh` with a new **Check H** that fails when an in-scope
implementation agent lacks it. No new document is created and the contract text itself is reused
verbatim, never reworded.

### Research Integration

The research pass re-confirmed the 3-covered / 14-missing split exactly as recorded (identical
output from the stated reproduce command) and settled every open item:

- **Item 1(a) is unavailable as literally stated.** No context pointer is included by all 17
  implementation agents. The nearest candidates (`contracts/phase-closure.md`,
  `contracts/pre-edit-gate.md`, present in 15 of 17) are missing from exactly
  `cslib/agents/pr-review-implementation-agent.md` and `email/agents/email-implementation-agent.md`
  — both of which are in the 14-file target list — so even the closest-to-universal pointer would
  still require a fresh addition in the two hardest cases. The only genuinely universal reference,
  `formats/return-metadata-file.md`, is a metadata-schema document topically unrelated to
  process-wait discipline.
- **A bare pointer will not reach the agent.**
  `context/contracts/no-task-references-bullet.md`'s own header records the empirical finding for
  this codebase: `@`-references inside an agent body do not auto-resolve when Claude Code spawns a
  subagent. The behavioral MUST/MUST-NOT core must therefore be literal text in each agent body.
- **The literal-copy-plus-lint-verified-fragment shape is this codebase's established house
  style for exactly this problem**, with two live precedents in the very script being extended:
  Check C (`no-task-references-bullet.md`) and Check G (`plan-status-ownership.md`).
- **Hard variants do not inherit.** `books-implementation-hard-agent.md`'s "Extends
  `books-implementation-agent`" is prose, not a file inclusion; both hard variants measure as
  missing independently, which is itself the proof.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- Re-confirm the measured coverage split by a stated command before any edit, reporting any
  divergence rather than absorbing it.
- Establish exactly **one** hand-edited home for the propagated bullet, inside an existing file.
- Place the bullet in all 14 missing implementation-agent definitions, verifiable by one command.
- Make `lint-agent-contracts.sh` FAIL on an in-scope implementation agent lacking the bullet, with
  the failure demonstrated by fixtures (including a near-miss paraphrase) and a deliberate
  temporary removal.
- Answer items 3 (hard variants) and 4 (research agents) in writing, in the deliverables.

**Non-Goals**:
- Rewriting, rewording, or re-deriving the contract. `core/agents/general-implementation-agent.md`'s
  "Local Long-Running Command Discipline" block is its correct current home and is **not edited by
  this plan** (it is also claimed by two other open tasks' `file_scope`).
- Adding a new pattern or contract document. `bounded-build-waiter.md` (the idiom) and
  `external-process-wait.md` (the defect class) already exist and are adequate.
- Propagating to research agents (ruled out of scope in Phase 2, with the reason recorded).
- Touching any consumer repo, or making verification suites faster or sharded.
- Deploying to `.claude/**`. All edits land in the source store `agent-system/extensions/**`;
  regeneration of the deploy tree is a separate, user-initiated operation.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A literal-text lint check is brittle to minor rewording (one typo fix breaks 14 copies at once) | M | M | Same risk Checks C and G already carry and operate with; the fragment is the single stated edit point and a wording change is expected to be followed by a mechanical re-propagation pass. Phase 2 records this in the fragment's own header. |
| Appending to `bounded-build-waiter.md` is misread as "adding a new pattern document" | L | L | The addition is a propagation-fragment section inside the existing pattern document that already names itself the idiom's owner. Net document count is unchanged; Phase 6 asserts it. |
| Lean and general implementation agents, if swept into the lint's in-scope set, would produce false failures (their coverage is correct but differently worded; lean's is a legitimately domain-adapted sanctioned-background path) | M | M | The new check uses a curated in-scope array (Check C/G precedent), not a filename glob, with the three exclusions recorded inline with per-file reasons read from the files, never inferred from absence. |
| A future 18th implementation agent misses the bullet because the curated array is hand-maintained | M | M | Accepted, explicit trade-off already made twice (Checks C, G) for the same reason. Mitigated by the template complement (Phase 2) and by an inline lint comment carrying the re-audit reproduce command verbatim. |
| New test fixtures generate incidental FAILs from Checks A/B/C/E/F/G, obscuring Check H assertions | L | M | New fixtures are built otherwise-compliant (carrying `BULLET_LINE`, `OWNERSHIP_BULLET_LINE`, and `ARTIFACTS_TEMPLATE_BLOCK`), and all assertions are scoped by check letter plus filename. |
| A sibling task concurrently edits a file in this task's scope | M | L | Sibling scopes (orchestrate SKILL.md, orchestrate-cycle-postflight.sh, git-workflow.md, git-staging-scope.md, report-format.md, plan-format.md) do not intersect this task's scope at all. Per-file re-read immediately before each edit, and per-file scoped staging, per Phase 0 discipline below. |
| Two target files are also claimed by an open task's `file_scope` | L | M | `books/agents/books-implementation-agent.md` is declared by open `offer_owner_review_when_approval_needed`. Edits here are additive (two bullets appended to an existing MUST/MUST-NOT list), never a rewrite of surrounding text, so a later merge is trivial. Recorded, no dependency edge. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 2, 3 |
| 5 | 5 | 4 |
| 6 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel. This plan is fully sequential by
construction: the fragment must exist before propagation, propagation must land before the lint
can go green, and the tests exercise the implemented check.

**Territory discipline, applying to every phase**: re-read each file immediately before editing
it; stage and commit only this task's own hunks with an explicit file list (never `git add -A`,
never a directory or glob pathspec); never run `git-snapshot.sh` in its reverting default form.

---

### Phase 1: Re-Confirm the Coverage Baseline [NOT STARTED]

**Goal**: Establish, by the stated command and before any edit, that the measured 3-covered /
14-missing split still holds — and report any divergence explicitly rather than absorbing it.

**Tasks**:
- [ ] Run, from the repository root:
      `cd agent-system/extensions && for f in $(find . -name '*implementation*agent.md' | sort); do echo "$(grep -c run_in_background "$f") $(grep -c bounded-build-waiter "$f") $f"; done`
- [ ] Compare the output against the 17-line baseline recorded in the research report's "Codebase
      Patterns" section. Confirm exactly three files are nonzero
      (`core/agents/general-implementation-agent.md`, `lean/agents/lean-implementation-agent.md`,
      `lean/agents/lean-implementation-hard-agent.md`) and the other 14 are `0 0`.
- [ ] If the file count is not 17, or any file's covered/missing state differs from the baseline,
      STOP and report the divergence in the handoff `summary` and (if it changes scope) as a
      blocker — do not silently widen or narrow the target list.
- [ ] Confirm all 14 target files have a `## Critical Requirements` section and a `**MUST NOT**`
      list (the insertion site Phase 3 depends on):
      `for f in <14 paths>; do printf '%s crit=%s mustnot=%s\n' "$f" "$(grep -c '^## Critical Requirements' "$f")" "$(grep -c '^\*\*MUST NOT\*\*' "$f")"; done`

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: 17 files match `*implementation*agent.md` in the source store; exactly 14
lack the contract. Confirm by the command above before any edit; the figures are a hypothesis
inherited from the task description and research, not a fact, until this phase re-runs them.

**Files to modify**:
- None (read-only measurement phase).

**Verification**:
- The command's output is captured verbatim in the implementation summary.
- Either "no divergence from the recorded 14-of-17" is stated, or the divergence is enumerated.

---

### Phase 2: Author the Single Canonical Home, the Rulings, and the Template Complement [NOT STARTED]

**Goal**: Create exactly one hand-edited source for the propagated bullet pair, inside an existing
file, and record the item 1/3/4 rulings in writing — including the rejected candidate homes.

**Tasks**:
- [ ] Re-read `core/agents/general-implementation-agent.md` lines ~158-200 and extract the
      MUST/MUST-NOT wording **verbatim**. Do not re-derive or reword it.
- [ ] Append a new section to the **existing** `core/context/patterns/bounded-build-waiter.md`
      (an edit, not a new file), placed after "The Canonical Idiom" and before "Conforming
      Examples", structured on `no-task-references-bullet.md`'s shape:
      - `## Canonical Agent-Contract Bullet (Generated-Copy Source)` with a "Generated-Copy
        Source, Not an `@`-Import" explainer stating that `@`-references inside an agent body do
        not auto-resolve when a subagent is spawned, that each agent body therefore carries a
        literal copy, and that `lint-agent-contracts.sh` Check H keeps the copies in sync against
        this file rather than against a string baked into the lint. Cite the precedent by
        filename (`no-task-references-bullet.md`, `plan-status-ownership.md`) — **never** by task
        number or `specs/` path.
      - A fenced "Copy this exact text" block containing the two bullets below, each on a single
        line so a `grep -F` anchor can extract it:

        MUST bullet (one physical line, backticks included):

        ```
        Whenever a local verification/gate/build/test process is backgrounded at all, use bounded-build-waiter.md's canonical idiom VERBATIM: a captured `pid=$!`, a `kill -0 "$pid"` liveness loop, and an outer `timeout N`, all inside one Bash call that does not return control until the wait resolves -- and prefer the plain foreground form `timeout N cmd` whenever the command plausibly fits within the Bash tool's own ceiling
        ```

        MUST NOT bullet (one physical line, backticks included):

        ```
        Use `Bash(run_in_background: true)` or arm a `Monitor` to watch a local verification, gate, build, or test process from within this dispatched subagent, and never end the turn on an unresolved local background wait -- the harness's own asynchronous detach-then-await-notification path hands the dispatch back unfinished with nothing guaranteed to resume it
        ```

      - A `### Classification Rule` naming which agents must carry it (every dispatchable
        implementation agent that can run a local build, gate, test, or verification command),
        with the three recorded exclusions and the per-file reason each is already correct.
      - A `### Item 3 Ruling: Hard Variants Do Not Inherit` note: hard-mode agent files are
        independent prose with no file-inclusion or generation link to their non-hard sibling;
        each must carry its own literal copy and be listed independently in the lint's in-scope
        set. Evidence: both hard variants measure as missing even though their non-hard siblings
        are in the same state, and `books-implementation-hard-agent.md`'s "Extends ..." line is a
        documentation claim, not a reference.
      - A `### Item 4 Ruling: Research Agents Are Out of Scope Here, Not Dismissed` note: research
        agents are plausibly exposed to the identical defect class (`general-research-agent.md`
        carries the external/remote-wait discipline but neither half of the local-background one,
        and several research agents hold Bash access explicitly for verification/build commands);
        the Lean research agents' `run_in_background` occurrences are the separate, sanctioned
        Lean build-guard path, not partial coverage of this contract. Ruled out of this change's
        scope because the measured evidence and acceptance surface are implementation-scoped;
        recommended as a follow-up reusing this identical fragment-and-check mechanism.
      - A one-line brittleness note: this file is the single edit point, and a wording change here
        is expected to be followed by a mechanical re-propagation pass across every copy.
- [ ] Edit the `### Implementation Agent` subsection of
      `core/context/templates/agent-template.md` (the canonical structure `meta-builder-agent`
      generates from) to add one bullet directing a newly authored implementation agent to carry
      the bounded-wait MUST/MUST-NOT pair from
      `.claude/context/patterns/bounded-build-waiter.md`'s canonical-bullet section.
- [ ] Record, in the same fragment section, that the template complement is **forward-looking
      only**: it fixes no existing file and is not a substitute for the propagation in Phase 3 or
      the lint in Phase 4.
- [ ] Verify no `specs/` path and no "task N"-shaped string entered either file:
      `bash .claude/scripts/check-task-references.sh` (or the repo-wide lint equivalent) over the
      two touched paths.

**Timing**: 1.0 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` - append the
  canonical-bullet section, the classification rule, and the item 3 / item 4 rulings
- `agent-system/extensions/core/context/templates/agent-template.md` - add the forward-looking
  bullet to the `### Implementation Agent` variant subsection

**Verification**:
- `grep -c "canonical idiom VERBATIM" agent-system/extensions/core/context/patterns/bounded-build-waiter.md`
  returns at least 1, and the MUST-NOT anchor
  `arm a \`Monitor\` to watch a local verification` likewise.
- Both new bullets are each on a single physical line (a multi-line bullet would break the lint's
  `grep -F` extraction). Confirm with
  `grep -n 'canonical idiom VERBATIM' ... | wc -l` and by reading the fenced block.
- The item 1 rejected-home record, the item 3 ruling, and the item 4 ruling are each present as
  named subsections.
- Net new files: zero.

---

### Phase 3: Propagate the Bullet Pair to All 14 Agent Definitions [NOT STARTED]

**Goal**: Place the literal bullet pair in every implementation-agent definition measured as
missing it, without touching any surrounding text.

**Tasks**:
- [ ] For each of the 14 files below, in order: re-read the file's `## Critical Requirements`
      section immediately before editing, then append the MUST bullet as the next sequential item
      of the `**MUST**` list (or, where only a `**MUST NOT**` list exists, add a `**MUST**:`
      heading in the same section shape) and the MUST NOT bullet as the next sequential item of
      the `**MUST NOT**` list. Do not renumber or reword any surrounding bullet.
- [ ] Copy the bullet text from the Phase 2 fragment **character for character**. The only
      permitted adaptation is the list's own numbering prefix.
- [ ] Commit each file (or each small group of files within one extension) as its own scoped
      green sub-step, with an explicit file list — never a directory or glob pathspec.
- [ ] After all 14, re-run the Phase 1 reproduce command and confirm all 17 files now report
      nonzero counts in both columns.

The 14 files, verbatim from the measured list:
- `books/agents/books-implementation-agent.md`
- `books/agents/books-implementation-hard-agent.md`
- `cslib/agents/cslib-implementation-agent.md`
- `cslib/agents/cslib-implementation-hard-agent.md`
- `cslib/agents/pr-review-implementation-agent.md`
- `email/agents/email-implementation-agent.md`
- `latex/agents/latex-implementation-agent.md`
- `nix/agents/nix-implementation-agent.md`
- `nvim/agents/neovim-implementation-agent.md`
- `python/agents/python-implementation-agent.md`
- `rust/agents/rust-implementation-agent.md`
- `typst/agents/typst-implementation-agent.md`
- `web/agents/web-implementation-agent.md`
- `z3/agents/z3-implementation-agent.md`

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: exactly 14 files need the edit, and each already has a
`## Critical Requirements` section with a `**MUST NOT**` list (measured in Phase 1). Re-confirm
per file at edit time; if a file's structure differs, add the bullets under the existing
`## Critical Requirements` heading rather than inventing a new section shape, and record the
deviation.

**Files to modify**:
- The 14 paths listed above, each under `agent-system/extensions/` - two bullets appended to the
  existing MUST / MUST NOT lists; no other change

**Verification**:
- One command confirms acceptance:
  `cd agent-system/extensions && for f in $(find . -name '*implementation*agent.md' | sort); do echo "$(grep -c run_in_background "$f") $(grep -c bounded-build-waiter "$f") $f"; done`
  — all 17 lines nonzero in both columns.
- Exact-text confirmation across the 14:
  `cd agent-system/extensions && for f in <14 paths>; do grep -qF 'canonical idiom VERBATIM' "$f" && grep -qF 'arm a `Monitor` to watch a local verification' "$f" && echo "OK $f" || echo "MISSING $f"; done`
  — 14 `OK`, zero `MISSING`.
- `git diff --staged` per commit shows only appended bullet lines, no surrounding-text churn.

---

### Phase 4: Add Check H to lint-agent-contracts.sh [NOT STARTED]

**Goal**: Make the coverage mechanically asserted, so the gap cannot reopen silently.

**Tasks**:
- [ ] Re-read `core/scripts/lint/lint-agent-contracts.sh` (Checks C and G are the structural
      templates to follow; do not invent a new check shape).
- [ ] Add a root-resolution constant alongside the existing fragment constants:
      `BOUNDED_WAIT_FRAGMENT="$REPO_ROOT/agent-system/extensions/core/context/patterns/bounded-build-waiter.md"`.
- [ ] Add `BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS=( ... )` containing exactly the 14 paths from
      Phase 3, both hard variants included per the item 3 ruling.
- [ ] Add an inline comment block above the array recording:
      (a) that the set is curated, not a filename glob, because three of the 17 are legitimate
      already-correct exclusions a literal-text check cannot recognize uniformly;
      (b) the three exclusions with their per-file reasons —
      `core/agents/general-implementation-agent.md` (the contract's authoritative home, full prose
      block, deliberately not edited), `lean/agents/lean-implementation-agent.md` and
      `lean/agents/lean-implementation-hard-agent.md` (carry a domain-adapted sanctioned
      background-build path routed through the Lean build guard, a different legitimate mechanism
      rather than an unfixed gap);
      (c) the re-audit reproduce command, verbatim, so a future auditor can re-derive the set;
      (d) that a future agent addition must be added here by applying the fragment's
      classification rule — the check does not infer scope on its own.
- [ ] Implement `check_h_bounded_wait_contract_bullet()` on Check C/G's exact shape:
      fail loudly and by name if the fragment file is absent (`Check H: canonical fragment not
      found at ...`); extract both anchors with
      `grep -F 'canonical idiom VERBATIM' "$BOUNDED_WAIT_FRAGMENT" | head -n1` and
      `grep -F 'arm a `Monitor` to watch a local verification' "$BOUNDED_WAIT_FRAGMENT" | head -n1`;
      fail if either extraction is empty; then per in-scope path, `log_fail` on a missing file,
      and `grep -qF` each anchor, emitting one named `log_pass` on success and one named
      `log_fail` on either anchor missing.
- [ ] Register `check_h_bounded_wait_contract_bullet` in `main()` after
      `check_g_plan_status_ownership_bullet`.
- [ ] Keep the script shellcheck-clean per `context/standards/shell-strict-mode.md`.

**Timing**: 1.0 hours

**Depends on**: 2, 3

**Verification Tier**: local

**Scope Hypothesis**: the next free check letter is H (A, B, C, E, F, G are implemented; D remains
a documented deferral). Confirm by reading `main()` and the deferred-follow-up block before
naming the new check, and do not reuse D.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - new fragment constant,
  curated in-scope array with recorded exclusions, `check_h_...` function, `main()` registration

**Verification**:
- `shellcheck agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` is clean.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` exits 0 on
  the post-propagation tree and prints 14 named Check H PASS lines.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --help` still exits 0;
  an unknown flag still exits 2.

---

### Phase 5: Extend the Lint Test Suite with Check H Fixtures [NOT STARTED]

**Goal**: Prove, by fixture, that the lint FAILS when the bullet is absent and when it is merely
paraphrased, and PASSES when it is verbatim — satisfying the acceptance bullet without relying on
a one-off manual experiment.

**Tasks**:
- [ ] Re-read `core/scripts/tests/test-lint-agent-contracts.sh` (Check G's three-fixture shape is
      the template).
- [ ] Add `BOUNDED_WAIT_FRAGMENT_SRC="$SCRIPT_DIR/../../context/patterns/bounded-build-waiter.md"`
      with the existing `if [ ! -f ... ]` pre-flight guard, create
      `$WORKDIR/agent-system/extensions/core/context/patterns/`, and copy the fragment in — the
      main scratch tree must carry it or Check H degrades to the fragment-missing branch and the
      per-fixture assertions become meaningless.
- [ ] Define `BOUNDED_WAIT_MUST_LINE` and `BOUNDED_WAIT_MUSTNOT_LINE` shell constants holding the
      two canonical bullet texts, mirroring the existing `BULLET_LINE` / `OWNERSHIP_BULLET_LINE`
      convention.
- [ ] Conforming positive fixture: add both bullets to the existing
      `cslib/agents/cslib-implementation-agent.md` fixture (already in Check H's in-scope set, and
      already asserted to produce no FAIL) — assert an explicit named Check H PASS line for it,
      and that it still produces no FAIL at all.
- [ ] Missing-bullet negative fixture: add a new `nvim/agents/neovim-implementation-agent.md`
      fixture, otherwise compliant (carrying `BULLET_LINE`, `OWNERSHIP_BULLET_LINE`, and
      `ARTIFACTS_TEMPLATE_BLOCK`) but with neither bounded-wait bullet — assert a named Check H
      FAIL for it.
- [ ] Near-miss paraphrase fixture: add a new `z3/agents/z3-implementation-agent.md` fixture,
      otherwise compliant, carrying a plausible-looking paraphrase ("never background a build and
      wait for a notification") instead of the verbatim text — assert it still FAILs Check H,
      proving the match is verbatim rather than loose.
- [ ] Exclusion-list assertion: assert the existing `lean/agents/lean-implementation-agent.md`
      fixture produces **no** Check H FAIL, proving the recorded exclusions are honored.
- [ ] Fragment-missing assertion: in the existing bare `FRAGDIR` tree, assert
      `Check H: canonical fragment not found` appears — Check H must fail loudly by name, never
      silently pass, when `bounded-build-waiter.md` is absent.
- [ ] Keep the test script shellcheck-clean and keep its exit contract (0 all-pass / 1 any-fail).

**Timing**: 1.0 hours

**Depends on**: 4

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` - fragment copy into
  the scratch tree, two bullet constants, one amended and two new fixtures, five new assertions

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` exits 0 and its
  summary line shows the pre-existing assertion count plus the new Check H assertions, with zero
  failures.
- `shellcheck agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` is clean.
- Every pre-existing assertion still passes (no regression in the Check A/B/C/E/F/G cases).

---

### Phase 6: Final Gate — Deliberate-Removal Demonstration and Acceptance Sweep [NOT STARTED]

**Goal**: Demonstrate end-to-end that the lint fails on a real missing-contract tree and passes on
the propagated one, and confirm every acceptance bullet.

**Tasks**:
- [ ] Deliberate temporary removal, on a real file rather than a fixture: remove the two bullets
      from one in-scope agent (e.g. `z3/agents/z3-implementation-agent.md`) in the working tree,
      run the lint, capture the named Check H FAIL, then restore the bullets with a targeted edit
      (never a destructive git command — the tree is dirty and shared with sibling tasks) and
      re-run the lint to confirm it returns to exit 0. Record both outputs in the summary.
- [ ] Run the full acceptance sweep:
      - `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` → exit 0
      - `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` → exit 0
      - `shellcheck` clean on both touched shell scripts
      - the Phase 1 reproduce command → 17 nonzero lines
      - the 14-file exact-text check → 14 `OK`
      - `bash .claude/scripts/check-task-references.sh` → no new findings under
        `agent-system/**`
- [ ] Confirm net document count did not increase: `git status --short` shows no new `.md` file
      under `agent-system/**` (only modifications).
- [ ] Confirm the item 1 rejected-home record, the item 3 ruling, and the item 4 ruling are each
      present in `bounded-build-waiter.md`, and that the template complement is recorded as
      forward-looking only.
- [ ] Record, as recommendations only (no edits, no dependency edges): (a) a follow-up applying
      this same fragment-and-check mechanism to research agents, per the item 4 ruling; (b) the
      observation that `books/agents/*` are absent from Check C's and Check G's curated in-scope
      arrays although they carry the no-task-references bullet — a pre-existing curated-list drift
      outside this change's scope; (c) that the deploy tree must be regenerated from the source
      store before the propagated contract takes effect at runtime.
- [ ] Final scoped commit of any remaining hunks, with an explicit file list.

**Timing**: 0.75 hours

**Depends on**: 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- None beyond restoring the deliberate-removal file to its Phase 3 state.

**Verification**:
- Both halves of the demonstration are captured: a named Check H FAIL on the removed-bullet tree
  and exit 0 on the restored tree.
- Every command in the acceptance sweep passes, with output recorded in the summary.
- `git status --short` shows zero new files under `agent-system/**`.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` exits 0, with
      all pre-existing assertions still passing plus the five new Check H assertions.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` exits 0
      and emits 14 named Check H PASS lines.
- [ ] The lint FAILS, by name, on a deliberate temporary removal from a real in-scope agent file,
      and returns to exit 0 once restored.
- [ ] The lint FAILS, by name, on a near-miss paraphrase fixture (verbatim matching proven).
- [ ] The lint FAILS, by name, when `bounded-build-waiter.md` is absent (never a silent pass).
- [ ] The lint produces no Check H FAIL for the three recorded exclusions.
- [ ] `shellcheck` clean on `lint-agent-contracts.sh` and `test-lint-agent-contracts.sh`.
- [ ] Coverage command reports all 17 implementation agents nonzero in both columns.
- [ ] No "task N"-shaped reference and no `specs/` path citation in any file landing under
      `agent-system/**`.
- [ ] Net `.md` document count under `agent-system/**` unchanged.

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` — amended with the
  single canonical agent-contract bullet section, the classification rule, and the item 3 / item 4
  rulings
- `agent-system/extensions/core/context/templates/agent-template.md` — forward-looking bullet in
  the `### Implementation Agent` variant subsection
- 14 implementation-agent definitions carrying the literal MUST/MUST-NOT bullet pair
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — Check H
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` — Check H fixtures and
  assertions
- `specs/356_propagate_bounded_wait_contract_and_lint_coverage/summaries/01_*-summary.md` —
  implementation summary carrying the re-confirmed coverage output, the deliberate-removal
  demonstration, and the recorded recommendations

## Rollback/Contingency

Every change is additive and text-local: two bullets appended per agent file, one appended section
in an existing pattern document, one bullet in a template, one new function plus one array plus one
`main()` line in the lint, and new fixtures in the test script. Each phase commits separately with
an explicit file list, so reverting any single phase is a targeted `git revert` of its commits.

Because the working tree is shared with concurrently dispatched sibling tasks, rollback MUST NOT
use `git reset --hard`, `git checkout -- <path>`, `git clean`, or `git-snapshot.sh` in its
reverting default form. Revert by targeted commit revert, or by a targeted edit that removes the
added text.

If Phase 1 finds the coverage split has diverged from the recorded baseline, stop and report
rather than proceeding: the 14-file target list is an acceptance-gating input, and silently
re-deriving it would defeat the purpose of the re-confirmation gate.
