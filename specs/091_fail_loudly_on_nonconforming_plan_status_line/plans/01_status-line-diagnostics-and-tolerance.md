# Implementation Plan: Task #91

- **Task**: 91 - Fail loudly on nonconforming plan status line
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/091_fail_loudly_on_nonconforming_plan_status_line/reports/01_diagnostic-opacity-and-anchor-fix.md
- **Artifacts**: plans/01_status-line-diagnostics-and-tolerance.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`update-plan-status.sh` funnels every non-conforming plan-level `- **Status**:` line into one
byte-identical, undiagnosable failure (`Failed to update status in <file>`), and its mutating
`sed` carries a `$` anchor that makes any plan whose Status line ends in a trailing annotation
permanently un-stampable. This plan fixes the script to (a) classify the malformed shapes and
emit distinct, line-numbered, content-quoting diagnostics reusing `update-phase-status.sh`'s
existing idiom, (b) accept and preserve trailing text after the closing `]`, (c) make the
idempotent no-op path echo the plan path so stdout matches the script's own documented contract,
then documents the tolerance policy in `plan-format.md`, enriches the preflight warning in
`update-task-status.sh` without touching its deliberate fatality asymmetry, adds a dedicated
fixture-driven test suite, and redeploys to confirm the fix survives regeneration. Definition of
done: every malformed shape produces a distinct line-numbered diagnostic, the trailing-annotation
shape stamps successfully with its annotation preserved, and all of it holds after a redeploy.

### Research Integration

Report `01_diagnostic-opacity-and-anchor-fix.md` confirmed all four defects by direct code read
and supplies the exact edit sites, which this plan adopts verbatim rather than re-deriving:

- **Edit sites**: `update-plan-status.sh` lines 62 (idempotency read), 69 (mutating `sed`, the
  `$`-anchor bug), and 72-78 (the single generic diagnostic). Lines 33-59 (missing plan
  dir/file) are already diagnostic and out of scope.
- **Reusable precedent**: `update-phase-status.sh:295-329` already implements the line-numbered,
  content-quoting diagnostic idiom (`grep -n ... | head -1 | cut -d: -f1`, then
  `echo "Line ${n}: $(sed -n "${n}p" "$file")" >&2`). Phase 1 copies this idiom rather than
  inventing a second diagnostic style.
- **Stale citation corrected**: `commands/implement.md:353`, named in the task description as a
  documented defensive call site, was deleted in commit `ff08eb967`. There is no live
  stdout-consuming caller. The sole caller is `update_plan_file()` in
  `update-task-status.sh:751-780`, which branches on **exit code only**, confirming the stdout
  contract change in Phase 1 carries zero regression risk. This plan does not edit, verify
  against, or otherwise reference `commands/implement.md`.
- **Documentation target**: the trailing-text policy belongs in `plan-format.md`'s
  "Plan-level vs. phase-level markers" subsection (the plan-level Status field's home), not at
  the phase-heading "Consumers of this heading contract" paragraph — which is a different
  contract at a different grain. A one-line forward pointer is added at the latter for
  discoverability.
- **No existing test file**: `update-plan-status.sh` has no dedicated suite today (only indirect
  coverage via `test-update-task-status.sh`), which is why Phase 2 creates one.
- **Deferral**: the research recommends the plan-creation-time Status-line lint (`ALSO EVALUATE`
  item 2) be deferred as an independent enhancement with its own scope and testing burden. This
  plan follows that recommendation — see Non-Goals.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the dispatch and no ROADMAP.md was consulted.

## Decisions Adopted (stated assumptions)

Two choices the task description left open are resolved here rather than deferred. Both follow
the direction the description itself and the research report point to; neither requires
information the artifacts lack.

1. **Trailing-text policy: ACCEPT and preserve.** The task description frames defect 2 as "the
   argument for tolerating it rather than rejecting it" and calls the resume-workflow shape
   "legitimate"; the research report recommends tolerance. Phase 1 therefore rewrites only the
   bracketed token and preserves the remainder of the line verbatim.

2. **Reconciling tolerance with the "three distinct diagnostics" acceptance criterion.** That
   criterion enumerates *trailing text, no brackets, missing prefix* — a list written on the
   assumption that policy (b) resolves to *reject*. Under *accept*, the trailing-text shape is
   by construction no longer malformed and correctly produces no diagnostic at all. The
   criterion's intent (three distinct, line-numbered, non-generic messages replacing one generic
   one) is met by classifying the shapes that remain malformed under the accept policy:
   - **M1** — no `- **Status**:` prefix line found anywhere in the plan;
   - **M2** — prefix present, but no `[...]` pair anywhere on the line;
   - **M3** — prefix present and brackets present, but the `[` does not immediately follow
     `- **Status**: ` (text intrudes before the bracket, e.g. `- **Status**: see [NOTE]`).
   M3 is what keeps tolerance narrow: it is the shape that a naive "brackets anywhere on the
   line" rule would silently accept. The trailing-annotation shape is verified as a **success**
   case (stamped, annotation preserved) rather than as a diagnostic case.

## Goals & Non-Goals

**Goals**:
- Replace the single generic `Failed to update status in <file>` with distinct, line-numbered
  diagnostics that quote the offending line verbatim and state which condition failed.
- Accept and preserve trailing text after the closing `]`, so a resumed plan is stampable.
- Keep tolerance narrow: text *before* the first bracket, or no bracket pair at all, still fails.
- Make the idempotent no-op path echo the plan file path, matching the script's own header
  contract ("Updated plan file path on success, empty on failure/no-op").
- Document the accepted Status-line shape in `plan-format.md` with a concrete example.
- Give the preflight non-fatal path one operator-visible line naming the plan file and the
  postflight consequence — without changing fatality anywhere.
- Add a dedicated fixture-driven test suite covering every shape.
- Redeploy and confirm the fix survives regeneration.

**Non-Goals**:
- Changing the deliberate preflight-warn / postflight-fatal asymmetry in
  `update-task-status.sh:762-780`, or its rationale comment. Diagnosability only.
- A plan-creation-time Status-line lint in `validate-artifact.sh` (deferred per research
  recommendation 5 — an independent enhancement, not a bug fix).
- Any edit under `.claude/**`. Per `.claude/rules/source-store-deploy-boundary.md` every edit
  targets `agent-system/extensions/core/**`; `.claude/` changes only via redeploy.
- Touching `commands/implement.md` (deleted) or the phase-heading contract (a different grain).
- Refactoring the plan-file resolution logic (lines 33-59), which is already diagnostic.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Widened pattern silently accepts genuinely malformed lines (brackets mid-prose, multiple pairs) | H | M | Anchor the bracket to immediately follow `- **Status**: `; add the M3 classification and a fixture for `- **Status**: see [NOTE]` and for a two-bracket-pair line |
| Idempotency read (line 62) and verification read (line 72) drift apart if only one is updated | M | M | Factor extraction + line-number lookup into one shared shell function used by both sites, in a single phase |
| Stdout contract change breaks a consumer | M | L | Research confirmed the sole caller branches on rc only and never reads stdout; Phase 4 re-reads that call site to reconfirm before the deploy gate |
| Fix lands in source store but is wiped or diverges on regeneration | H | L | Phase 5 redeploys and re-runs the suite against the deployed copy, not just the source store |
| Preflight warning enrichment mistaken for a fatality change | M | L | Phase 4 is additive echo lines only; the `if/else` branch structure and rationale comment at lines 762-776 are left byte-identical and diffed to prove it |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel. Wave 2's three phases touch three disjoint
files (`tests/test-update-plan-status.sh`, `context/formats/plan-format.md`,
`scripts/update-task-status.sh`) and have no shared edit surface.

---

### Phase 1: Diagnose loudly and tolerate trailing text in update-plan-status.sh [COMPLETED]

**Goal**: Replace the generic failure with three classified line-numbered diagnostics, make the
mutating `sed` preserve trailing text, and make the no-op path echo the plan path.

**Tasks**:
- [x] Add a shared helper near the top of the script that locates the plan-level Status line:
      `grep -n "^- \*\*Status\*\*:" "$plan_file" | head -1 | cut -d: -f1`, mirroring
      `update-phase-status.sh:299`. Both the idempotency read and the post-`sed` verification
      read must go through it, so the two sites cannot drift.
- [x] Add a second helper that extracts the bracketed token from a given line number using the
      already-trailing-text-tolerant `s/.*\[\([^]]*\)\].*/\1/` form.
- [x] Insert classification **before** the idempotency check (so a malformed line is diagnosed,
      never silently carried into the `sed`), emitting to stderr and exiting 1:
      - **M1** (no matching line): `Plan-level Status line not found in <file>` plus a statement
        that a line of the form `- **Status**: [STATUS]` is required.
      - **M2** (line found, no `[...]` pair): a message naming the missing-brackets condition,
        followed by `Line ${n}: $(sed -n "${n}p" "$plan_file")`.
      - **M3** (bracket present but not immediately after `- **Status**: `): a message naming the
        unexpected-text-before-bracket condition, followed by the same `Line ${n}: ...` quote.
      Each of the three messages must be textually distinct from the other two and from the
      pre-existing "Plan directory not found" / "No plan file found" messages.
- [x] Change the idempotency early-exit (currently lines 63-66) from a bare `exit 0` to
      `echo "$plan_file"; exit 0`.
- [x] Replace line 69's substitution so the trailing remainder is captured and re-emitted:
      `s/^- \*\*Status\*\*: \[[^]]*\]\(.*\)$/- **Status**: [${new_status}]\1/` — dropping the
      `$`-immediately-after-`]` requirement while keeping the bracket anchored to the prefix.
- [x] Rewrite the post-`sed` verification block (lines 72-78) to use the shared helpers and, on
      mismatch, report wanted-vs-got plus the quoted line, in the shape of
      `update-phase-status.sh:325-329`.
- [x] Update the script header comment (line 6) so the stated Outputs contract matches the new
      behavior: the plan path is echoed on success **and on the already-at-target no-op**.
- [x] Smoke-test by hand against the five shapes (M1, M2, M3, trailing-annotation, well-formed)
      plus the already-at-target no-op, using scratch fixtures, before closing the phase.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts (i) exactly one file is modified —
`agent-system/extensions/core/scripts/update-plan-status.sh` — and (ii) exactly three malformed
classifications (M1/M2/M3) are needed to cover every non-conforming shape under the accept
policy. Confirm (i) by checking `git status --short` names only that path at phase close.
Confirm (ii) at implementation time by enumerating the shapes actually reachable after the
tolerance change: if hand-testing surfaces a fourth distinguishable malformed shape (for example
an empty bracket pair `- **Status**: []`), add a fourth classification rather than folding it
into an existing message, and record the widened count here.

**Files to modify**:
- `agent-system/extensions/core/scripts/update-plan-status.sh` - shared line-lookup and
  extraction helpers; three classified diagnostics before the idempotency check; no-op path
  echoes the plan path; `$`-anchor removed from the mutating substitution with the trailing
  remainder preserved; verification block rewritten; header Outputs contract corrected.

**Verification**:
- Each of M1, M2, M3 exits 1 and prints a distinct message including `Line <n>: <verbatim line>`.
- `- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)` transitions to
  `- **Status**: [COMPLETED] (resumed; Phases 1R-10R closed)` — annotation intact.
- A well-formed line still stamps correctly, rc=0, stdout is the plan path.
- The already-at-target path leaves the file byte-identical, rc=0, and now prints the plan path.
- No malformed input mutates the plan file (compare checksums before/after).
- `bash -n` passes on the edited script.

---

### Phase 2: Fixture-driven test suite for update-plan-status.sh [COMPLETED]

**Goal**: Create the missing dedicated regression suite covering every shape Phase 1 defines.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/test-update-plan-status.sh`, following
      the structural model of `test-phase-heading-patterns.sh`: `set -uo pipefail`,
      `pass()`/`fail()`/`info()` helpers, PASSED/FAILED counters, exit 0 all-pass / 1 any-fail /
      2 environment error, and the git-root-first REPO_ROOT resolution so the suite runs from
      both the source-store and deployed locations.
- [x] Resolve the script under test via the same deploy-tree-first / source-store-fallback
      candidate list that sibling suites use, so Phase 5 can run this identical file against the
      deployed copy.
- [x] Build fixtures in a `mktemp -d` scratch tree shaped as `specs/{NNN}_{slug}/plans/01_*.md`,
      since the script resolves its target from that layout; `cd` into the scratch root so the
      script's relative `specs/...` resolution works, and clean up on `trap EXIT`.
- [x] Cases: M1 missing prefix; M2 no brackets; M3 text before bracket
      (`- **Status**: see [NOTE]`); trailing annotation (success + preservation); two bracket
      pairs on one line (first rewritten, remainder preserved verbatim); well-formed transition;
      already-at-target no-op (rc=0, stdout equals plan path, file unchanged); unknown status
      token still rejected; missing plan dir and missing plan file still produce their own
      pre-existing messages.
- [x] Assert **distinctness**: collect the stderr of M1/M2/M3 and fail if any two are equal, so a
      future regression that collapses them back to one message is caught mechanically.
- [x] Assert no mutation on every failing case by checksumming the fixture before and after.
- [x] `chmod +x` the suite so `run-all.sh` does not report it as a loud `[SKIP]`.
- [x] Run the suite; then run `bash agent-system/extensions/core/scripts/tests/run-all.sh` to
      confirm discovery picks it up and no sibling suite regressed.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts ten test cases across one new file. The count is a
hypothesis: confirm at implementation time by mapping each case to a Phase 1 verification bullet
and to an acceptance criterion in the task description; if Phase 1's Scope Hypothesis widened the
classification count, add the matching case(s) and record the revised total here rather than
leaving the asserted count stale.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-update-plan-status.sh` - new fixture-driven
  suite (created, executable).

**Verification**:
- The new suite exits 0 with every case passing.
- `run-all.sh` discovers it (it appears in the per-suite narration, not as `[SKIP]`) and the
  overall run is green.
- Temporarily reverting the Phase 1 `$`-anchor change makes the trailing-annotation case fail —
  confirming the suite actually tests the fix rather than passing vacuously.

---

### Phase 3: Document the trailing-text tolerance policy in plan-format.md [COMPLETED]

**Goal**: Make the accepted plan-level Status-line shape an explicit, exampled part of the
format standard rather than an undocumented script behavior.

**Tasks**:
- [x] In `agent-system/extensions/core/context/formats/plan-format.md`, inside the
      "Plan-level vs. phase-level markers" subsection under `## Status Marker Requirements`, add
      a short "Trailing annotations on the plan-level Status line" passage stating: the line MUST
      begin `- **Status**: ` followed immediately by a single `[...]` pair drawn from the
      six-value plan-level vocabulary; arbitrary trailing text after the closing `]` is
      **accepted and preserved** across status transitions; text between the prefix and the
      opening bracket, or an absent bracket pair, is malformed and rejected loudly.
- [x] Include the concrete accepted example verbatim:
      `- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)`, and at least one rejected
      example (`- **Status**: see [NOTE]`), so the rule is not prose-only.
- [x] Name `update-plan-status.sh` as the enforcing consumer and state that a malformed line
      produces a line-numbered diagnostic naming the failing condition.
- [x] Add a one-line forward pointer in the "Consumers of this heading contract" paragraph
      (the phase-heading contract, currently near line 102) noting that the plan-level Status
      field has its own separate trailing-text rule documented in the plan-level-vs-phase-level
      subsection — keeping the two grains cross-referenced without conflating them.
- [x] Re-read the surrounding prose to confirm no existing sentence now contradicts the new
      allowance (in particular the metadata examples at the top of the file and the
      `## Example Skeleton` block, which show the bare `[NOT STARTED]` form — these stay correct
      and need no change, since trailing text is permitted, not required).

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts exactly two edit locations in one file, cited by
approximate line numbers (the plan-level-vs-phase-level subsection near lines 343-365, and the
consumers paragraph near line 102). Line numbers are a hypothesis and drift; confirm at
implementation time by locating both anchors with `grep -n "Plan-level vs. phase-level markers"`
and `grep -n "Consumers of this heading contract"` rather than by seeking the cited numbers, and
record the actual locations edited.

**Files to modify**:
- `agent-system/extensions/core/context/formats/plan-format.md` - new trailing-annotation policy
  passage with accepted and rejected examples; forward pointer from the phase-heading consumers
  paragraph.

**Verification**:
- Every changed hunk is prose inside the two named sections (diff read-through per the `prose`
  tier).
- The documented accepted shape matches Phase 1's implemented pattern exactly — the example line
  is copy-pasted into a fixture and confirmed to stamp successfully.
- No task-number references were introduced (this file lives outside `specs/**`; see
  `.claude/rules/no-task-references-in-deliverables.md`).

---

### Phase 4: Enrich the preflight warning without changing fatality [COMPLETED]

**Goal**: Give the operator a one-line, actionable warning at preflight — the leading indicator
of the fatal postflight failure — while leaving the deliberate asymmetry untouched.

**Tasks**:
- [x] Re-read `update_plan_file()` in `agent-system/extensions/core/scripts/update-task-status.sh`
      (currently lines 751-780) and confirm the caller still branches on exit code only and never
      reads `update-plan-status.sh`'s stdout — reconfirming Phase 1's stdout change is inert here.
- [x] In the non-fatal `else` branch only (currently line 778), add one or two additional stderr
      echo lines after the existing `Warning: plan file update failed (non-fatal)`, naming the
      plan file's task/project and stating that the underlying line-numbered diagnostic was
      printed above and that this same failure will hard-fail at postflight (`exit 3`) if left
      unresolved.
- [x] Leave the `if [[ "$operation" == "postflight" ]]` branch, its three explanatory echo lines,
      the `exit 3`, and the rationale comment at lines 762-768 byte-identical.

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/update-task-status.sh` - additive stderr lines in the
  preflight non-fatal branch of `update_plan_file()` only.

**Verification**:
- `git diff` on the file shows only added lines inside the `else` branch; the postflight branch
  and rationale comment are unchanged.
- `bash -n` passes.
- `bash agent-system/extensions/core/scripts/tests/test-update-task-status.sh` still passes.
- A manual preflight run against a malformed-Status fixture prints the line-numbered diagnostic
  from `update-plan-status.sh` followed by the enriched warning, and still exits 0 (non-fatal);
  the equivalent postflight run still exits 3.

---

### Phase 5: Redeploy and confirm the fix survives regeneration [NOT STARTED]

**Goal**: Prove the fix is live in the deploy artifact and that nothing in the wider suite broke.

**Tasks**:
- [ ] Confirm no edits landed under `.claude/**` during Phases 1-4
      (`git status --short` plus a check that every modified path is under
      `agent-system/extensions/core/`).
- [ ] Redeploy via `agent-system/extensions/core/scripts/deploy-headless.sh`.
- [ ] Diff the deployed `.claude/scripts/update-plan-status.sh` against the source-store copy to
      confirm the fix propagated intact.
- [ ] Re-run `test-update-plan-status.sh` from its deployed location
      (`.claude/scripts/tests/`) so the deployed copy — not only the source store — is exercised.
- [ ] Run `bash .claude/scripts/tests/run-all.sh` for the full regression net.
- [ ] Run `agent-system/extensions/core/scripts/verify-deploy.sh` and confirm it is green
      (including its Gate 8 suite-discovery gate, which must now see the new suite).
- [ ] Walk the task description's ACCEPTANCE list item by item and record the evidence for each.

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Files to modify**:
- None directly. `.claude/**` is regenerated by the deploy, not hand-edited.

**Verification**:
- `deploy-headless.sh` exits 0 and the deployed script diff is empty against the source store.
- The new suite passes from the deployed path.
- `run-all.sh` is green with zero `[FAIL]` lines and the new suite is not `[SKIP]`ped.
- `verify-deploy.sh` exits 0.
- Every acceptance criterion in the task description has a named piece of evidence.

---

## Testing & Validation

- [ ] M1 (missing `- **Status**:` prefix) exits 1 with its own message quoting nothing but
      stating the requirement; no file mutation.
- [ ] M2 (no bracket pair) exits 1 with a distinct message plus `Line <n>: <verbatim>`; no
      mutation.
- [ ] M3 (text before the bracket) exits 1 with a third distinct message plus the quoted line;
      no mutation.
- [ ] The three stderr texts are pairwise distinct (asserted mechanically, not by eye).
- [ ] `- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)` stamps to the target status
      with the annotation preserved byte-for-byte.
- [ ] A well-formed plan still stamps correctly; rc=0; stdout is the plan path.
- [ ] The already-at-target path is a no-op (file unchanged), rc=0, stdout is now the plan path.
- [ ] `test-update-task-status.sh` still passes (no regression in the sole caller).
- [ ] `run-all.sh` is green in both the source store and the deployed tree.
- [ ] `verify-deploy.sh` is green after redeploy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/update-plan-status.sh` (modified) - classified
  line-numbered diagnostics, trailing-text tolerance, corrected stdout contract.
- `agent-system/extensions/core/scripts/update-task-status.sh` (modified) - enriched preflight
  warning only; fatality asymmetry untouched.
- `agent-system/extensions/core/context/formats/plan-format.md` (modified) - documented
  trailing-annotation policy with accepted and rejected examples, plus cross-reference.
- `agent-system/extensions/core/scripts/tests/test-update-plan-status.sh` (new) - fixture-driven
  regression suite.
- `.claude/**` (regenerated by deploy, not hand-edited).
- `specs/091_fail_loudly_on_nonconforming_plan_status_line/summaries/01_*.md` (implementation
  summary, written at completion).

## Rollback/Contingency

Every change is confined to four files in `agent-system/extensions/core/**` plus a regenerated
`.claude/` tree. `git revert` of the phase commits restores the prior script exactly; a
subsequent `deploy-headless.sh` run restores the deployed copy, since `.claude/` is a disposable
artifact regenerated wholesale from the source store. If the trailing-text tolerance proves too
permissive in practice, the narrower fallback is to keep Phases 1's diagnostics and stdout fix
and revert only the substitution-pattern change, converting the trailing-text shape into a
fourth explicit malformed classification — this is the "reject" branch of the task description's
policy choice and requires no rework of Phases 2-5 beyond flipping one test case's expectation
and one paragraph in `plan-format.md`.
