# Implementation Plan: Task #186

- **Task**: 186 - Fix the wrong deploy-headless.sh invocation path documented in regeneration-is-manual-only.md
- **Status**: [IMPLEMENTING]
- **Effort**: 3.25 hours
- **Dependencies**: None
- **Research Inputs**: None (planned directly from the task description plus a first-hand source-store survey performed during planning -- see Overview)
- **Artifacts**: plans/01_fix-deploy-headless-invocation-path.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`deploy-headless.sh` exists at exactly two real paths in this repository: the deployed copy at
`.claude/scripts/deploy-headless.sh` and its source at
`agent-system/extensions/core/scripts/deploy-headless.sh`. A bare `scripts/deploy-headless.sh`
resolves from neither a consuming repo root nor this repo root, so `bash
scripts/deploy-headless.sh` fails with exit 127 and produces nothing on **stdout** -- which is
why the observed failure read as a silent no-op. That wrong invocation form is documented in the
one file the deploy gate's own remedy text sends blocked operators to, and it is repeated in
operator-facing runtime remedy strings printed by five core scripts.

The fix is a small, precisely-scoped text correction plus a regression guard. Its entire
difficulty is discrimination, not volume: the string `scripts/deploy-headless.sh` appears 28
times in the source store, and **most of those occurrences are correct**. This plan resolves that
by a single discriminator established during planning and encoded in the site inventory below.

### The Discriminator (binding for every phase)

| Class | Shape | Verdict |
|-------|-------|---------|
| **Invocation** | Prefixed with `bash `, or standing alone inside a runnable code fence, or appearing in operator-facing remedy text that tells a reader to *run* it | **WRONG.** Must resolve from the working directory its surrounding text assumes |
| **Reference** | Naming the file as an identifier inside a list, table, or prose *about* the script, uniformly alongside sibling `scripts/*.sh` entries | **CORRECT IN CONTEXT.** These are extension-root-relative identifiers (from `agent-system/extensions/core/`, `scripts/deploy-headless.sh` is a real path). Do not touch |
| **Source-store-relative invocation** | `bash agent-system/extensions/core/scripts/deploy-headless.sh` | **CORRECT.** This is the CI/bootstrap case where no `.claude/` tree exists yet (`.github/workflows/check-extension-docs.yml:69`). Do not "normalize" it |
| **Shell-internal** | `$SCRIPT_DIR/deploy-headless.sh`, `$REPO_ROOT/.claude/scripts/...`, `$WORKDIR/.claude/...` | **CORRECT.** Resolved at runtime. Do not touch |

The single mechanical test that isolates exactly the defect class, with zero false positives
against the reference class, is the literal string **`bash scripts/deploy-headless.sh`**.

```bash
grep -rn 'bash scripts/deploy-headless\.sh' agent-system/
```

This returns **12 hits across 6 files** today and MUST return **0** when the task is done.

The canonical correct form is already established by existing, working code and is not being
invented here -- `command-gate-out.sh:176`, `check-deploy-freshness.sh:95`,
`check-consumer-freshness.sh:185`, `validate-state.sh:248`, `check-extension-docs.sh:1446`, and
`deploy-headless.sh`'s own header comment (line 72) all use:

```
bash .claude/scripts/deploy-headless.sh
```

`check-extension-docs.sh` is internally inconsistent today -- correct at line 1446, wrong at four
other lines -- which is independent corroboration of the fix direction.

### Site Inventory (surveyed during planning; re-confirm in Phase 1)

**Defect sites -- 12 invocation occurrences, all under `agent-system/extensions/core/`:**

| File | Lines | Sub-class |
|------|-------|-----------|
| `context/patterns/regeneration-is-manual-only.md` | 32, 35 | Runnable code fence (the canonical doc; highest cost) |
| `scripts/check-extension-docs.sh` | 316, 331, 446, 453 | Runtime `advisory()` remedy string |
| `scripts/task-lock.sh` | 214, 221 | 214 comment / 221 runtime `echo` remedy |
| `scripts/orchestrate-batch-admit.sh` | 349, 353 | 349 comment / 353 runtime `echo` remedy |
| `scripts/deploy-root-guard.sh` | 27 | Runtime `echo` remedy |
| `scripts/system-defect-record.sh` | 52 | Comment |

Seven of the twelve are strings printed to an operator at runtime; those carry the same
"maximally expensive, read while already blocked" property as the doc itself.

**Reference-class sites deliberately NOT changed** (verified correct in context during planning):
`context/standards/shell-strict-mode.md:91` (a uniform `scripts/*.sh` migration list),
`context/patterns/ci-deploy-tree-bootstrap.md:20`,
`context/patterns/batch-orchestration-guardrails.md:195, 411, 599`,
`scripts/verify-deploy.sh:18, 52`, and the eight backticked references inside
`regeneration-is-manual-only.md` itself (lines 19, 23, 48, 60, 67, 95, 150, 488). Phase 2
addresses the last group by making the two-root convention explicit **once** in the doc, rather
than rewriting eight identifier references.

Also deliberately out of scope: `.github/workflows/check-extension-docs.yml:5`, a comment naming
the aggregator in the same uniform reference style as the `scripts/verify-deploy.sh` mention
beside it -- reference class, not an invocation. Line 69 of that same file is a correct
source-store-relative invocation and must be left alone.

### Research Integration

No research report exists for this task, and none was requested. The task description already
carried the defect, the reproduction, the evidence, and the acceptance bar; the one genuinely
open question it raised -- "determine which of these are genuinely wrong versus
correct-in-their-own-context rather than mass-rewriting on the string alone" -- was answerable
with targeted `grep`/`Read` inside the planning dispatch itself, and is answered above by the
Discriminator table and the Site Inventory. The exit-127 behavior was confirmed empirically
during planning (`bash scripts/deploy-headless.sh --help` -> exit 127).

One nuance the description's "NO output" observation should be recorded against: `bash` *does*
write `No such file or directory` to **stderr**. The silence is stdout-only. The warning added in
Phase 2 must say this accurately rather than repeating "no output at all".

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found at `specs/ROADMAP.md`.

## Goals & Non-Goals

**Goals**:
- Every *invocation* of `deploy-headless.sh` documented under `agent-system/extensions/**` names
  a path that resolves from the working directory its surrounding text assumes.
- The two code fences in `regeneration-is-manual-only.md` are runnable verbatim from a consuming
  repo root.
- The doc warns that the wrong path fails with exit 127 and is stdout-silent.
- A regression guard prevents the `bash scripts/deploy-headless.sh` form from reappearing.
- Deploy lands and the full gate run shows no *new* failures.

**Non-Goals**:
- Editing anything under `.claude/` (see `rules/source-store-deploy-boundary.md`; that tree is
  regenerated from the source store by Phase 5's deploy and any hand-edit there is wiped).
- Mass-rewriting the bare `scripts/deploy-headless.sh` reference form. Most occurrences of it are
  correct.
- Renaming, relocating, or changing the behavior of `deploy-headless.sh` itself.
- Fixing pre-existing, unrelated gate failures surfaced by the Phase 1 baseline. They are
  recorded for comparison only.
- Rewriting `.github/workflows/check-extension-docs.yml`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A blanket `sed` on `scripts/deploy-headless.sh` corrupts the ~16 correct reference-class sites | H | M | Anchor every substitution on the literal `bash scripts/deploy-headless.sh`, never on the bare path. Phase 1 records the exact per-class counts; Phase 4's guard uses the same anchor |
| `check-extension-docs.sh:446/453` contains BOTH a correct `scripts/$s` identifier and a wrong invocation on one line | H | M | Called out explicitly in Phase 3's task list. The `bash `-anchored substitution is safe here by construction; a `scripts/`-anchored one is not |
| `deploy-headless.sh` already exits 3 on this repo because of pre-existing gate failures, so Phase 5 cannot read "exit 0 = success" | H | H | Phase 1 captures the baseline failure set *before any edit*. Exit 3 means the deploy **landed**; Phase 5's bar is "no NEW failures vs. baseline", not "exit 0" |
| A new lint check hard-fails `check-extension-docs.sh` for consuming repos that have no `agent-system/` tree | M | M | Guard the check on the source store existing; skip cleanly when absent. Verify by running the gate from a tree without `agent-system/` |
| The `--wipe` fence is destructive and must not be run verbatim during verification | H | L | Phase 5 verifies both fences with `--dry-run` appended; only the non-destructive default fence is ever run for real |
| Editing `deploy-root-guard.sh` / `task-lock.sh` (runtime-critical shared infrastructure) introduces a shell syntax error | H | L | String-literal-only edits, `bash -n` on every touched script, plus the full gate run in Phase 5 |
| Fix lands in the source store but never becomes live, reproducing the original blocked state | M | M | Phase 5's deploy is a mandatory phase, not a postflight afterthought |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 2 and 3 touch disjoint file sets
(one markdown doc vs. five shell scripts) and carry no shared state.

---

### Phase 1: Baseline Capture and Classification Confirmation [COMPLETED]

**Goal**: Freeze a pre-edit reference point so later phases can prove they changed exactly the
intended sites and introduced no new gate failures. No source files are modified in this phase.

**Tasks**:
- [x] Record the defect-class census: `grep -rn 'bash scripts/deploy-headless\.sh' agent-system/`
      -- confirm 12 hits across the 6 files named in the Site Inventory. If the count or the file
      set differs, reconcile against the inventory and note the delta before proceeding.
      *(completed: 12 hits across exactly the 6 inventoried files, no divergence)*
- [x] Record the full-form census:
      `grep -rhoE '[A-Za-z0-9_./-]*deploy-headless\.sh' agent-system/ | sort | uniq -c | sort -rn`
      -- expected today: 149 bare `deploy-headless.sh`, 28 `scripts/...`, 9 `.claude/scripts/...`,
      plus the shell-internal and source-store-relative forms.
      *(completed: exact match -- 149/28/9 plus 3 WORKDIR/, 3 SCRIPT_DIR/../, 3 REPO_ROOT/, 2
      SCRIPT_DIR/, 2 agent-system/extensions/core/scripts/)*
- [x] Confirm the two real paths on disk: `find . -name deploy-headless.sh -not -path './.git/*'`.
      *(completed: `.claude/scripts/deploy-headless.sh` and
      `agent-system/extensions/core/scripts/deploy-headless.sh`, matching the Overview)*
- [x] Confirm the failure mode first-hand and capture stdout and stderr separately:
      `bash scripts/deploy-headless.sh --help; echo "exit=$?"` -- expect exit 127 with the
      diagnostic on stderr and nothing on stdout.
      *(completed: exit=127, stdout empty, stderr "bash: scripts/deploy-headless.sh: No such file
      or directory")*
- [x] Capture the pre-edit gate baseline to a scratch file:
      `bash .claude/scripts/verify-deploy.sh > /tmp/186-gate-baseline.txt 2>&1; echo "exit=$?" >> /tmp/186-gate-baseline.txt`.
      Record the exit code and the list of failing checks verbatim.
      *(completed: 34/34 checks PASS, exit=0; sole findable signal is the pre-existing
      non-failing WARN on commands/orchestrate.md's 15965 B vs 8000 B ceiling. A first attempt at
      this capture overlapped with the git-snapshot.sh tree revert below and produced a spurious
      1/34 FAIL; discarded and re-run on the stable, restored tree)*
- [x] Snapshot the working tree before any edits: `bash .claude/scripts/git-snapshot.sh 186`.
      *(completed: git-snapshot.sh's default mode reverted and stashed the tree as
      `git-snapshot-1788908157` (stash@{0}). This also stashed pre-existing, task-unrelated
      uncommitted changes that were present before this dispatch began; those were popped back
      cleanly immediately after with no conflicts and are present in the tree again -- see the
      phase-1 progress file's `notes` field)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: The Site Inventory asserts 12 defect sites across 6 files and ~16
reference-class sites left untouched. These counts were measured during planning against the
current tree and are a hypothesis, not a fact -- concurrent edits may have shifted them. The
first two tasks in this phase exist specifically to confirm them. Proceed with the *measured*
set, not the tabulated one, if they diverge, and record the divergence in the summary.

**Files to modify**:
- None. This phase is measurement only. `/tmp/186-gate-baseline.txt` is scratch output, not a
  repository artifact.

**Verification**:
- The 12-hit defect census matches the Site Inventory, or the divergence is explicitly recorded.
- `git status --short` shows no modifications to `agent-system/**` from this phase.
- `/tmp/186-gate-baseline.txt` exists and names the pre-existing failing checks (if any) and the
  baseline exit code.

---

### Phase 2: Correct the Canonical Doc [COMPLETED]

**Goal**: Make `regeneration-is-manual-only.md`'s two code fences runnable verbatim from a
consuming repo root, warn about the exit-127 failure mode, and remove the ambiguity that let the
reference-class occurrences in this file be misread as invocations.

**Tasks**:
- [x] In `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`, change
      the two fence lines (32 and 35) from `bash scripts/deploy-headless.sh ...` to
      `bash .claude/scripts/deploy-headless.sh ...`, preserving the `[TARGET_REPO]` placeholder
      and the `--wipe` flag exactly. *(completed)*
- [x] Immediately after the fence block, add a short paragraph stating the two-root convention
      explicitly: the script is *invoked* from a consuming repo root as
      `.claude/scripts/deploy-headless.sh`; it is *referred to* elsewhere in this document and in
      the source store by its extension-relative identifier `scripts/deploy-headless.sh`; and a
      bare `scripts/deploy-headless.sh` is never a runnable path from a repo root. *(completed:
      "Two-root convention." paragraph)*
- [x] In that same paragraph, record the failure mode accurately: an invocation using the wrong
      path fails with **exit 127**, writing its diagnostic to stderr and **nothing to stdout** --
      so any caller that captures stdout only, or reads exit status loosely, sees what looks like
      a silent no-op rather than a failure. *(completed)*
- [x] Note the one legitimate alternative invocation for completeness: from this repo's root
      before any `.claude/` tree exists (CI bootstrap), the source-store path
      `bash agent-system/extensions/core/scripts/deploy-headless.sh` is the correct form -- as
      used by `.github/workflows/check-extension-docs.yml`. *(completed)*
- [x] Leave the eight backticked reference-class occurrences (lines 19, 23, 48, 60, 67, 95, 150,
      488) unchanged; the new convention paragraph is what disambiguates them. *(completed:
      confirmed unchanged via diff read-through)*
- [x] Follow this document's own established correction-as-addition pattern (see its
      `**CORRECTION.**` block and its `## Automated Exception` subsection): add the convention as
      a labeled, additive paragraph rather than silently rewriting surrounding prose. *(completed:
      "Two-root convention." labeled paragraph, additive)*
- [x] Do NOT edit `.claude/context/patterns/regeneration-is-manual-only.md`. Phase 5's deploy
      regenerates it. *(completed: not touched)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - fence lines 32
  and 35 corrected; one additive convention-and-failure-mode paragraph inserted after the fence
  block.

**Verification**:
- `grep -n 'bash scripts/deploy-headless\.sh' agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
  returns nothing.
- `grep -c 'scripts/deploy-headless\.sh' ` on that file still shows the eight reference
  occurrences intact (plus the new paragraph's mentions).
- Diff read-through confirms every changed hunk is prose or fence content; no other section of
  the 528-line file is touched.
- The `**CORRECTION.**` block and the `## Automated Exception` subsection are byte-for-byte
  unchanged.

---

### Phase 3: Correct the Operator-Facing Remedy Strings in Core Scripts [COMPLETED]

**Goal**: Correct all ten invocation occurrences across the five core scripts -- seven of them
strings printed to a blocked operator at runtime -- without disturbing the correct identifier
paths that sit on the same lines.

**Tasks**:
- [x] `scripts/check-extension-docs.sh` lines 316, 331, 446, 453: change
      `bash scripts/deploy-headless.sh` to `bash .claude/scripts/deploy-headless.sh` inside the
      four `advisory()` strings. **On lines 446 and 453 do not touch the `scripts/$s` /
      `hooks/$h` identifier earlier in the same string** -- that is a manifest-relative path and
      is correct. This file already uses the correct form at line 1446; the edits make it
      self-consistent. *(completed)*
- [x] `scripts/task-lock.sh` line 221 (runtime `echo` remedy) and line 214 (comment): same
      substitution. *(completed)*
- [x] `scripts/orchestrate-batch-admit.sh` line 353 (runtime `echo` remedy) and line 349
      (comment): same substitution. *(completed)*
- [x] `scripts/deploy-root-guard.sh` line 27 (runtime `echo` remedy): same substitution, keeping
      the surrounding single quotes in the message intact. *(completed)*
- [x] `scripts/system-defect-record.sh` line 52 (comment): same substitution. *(completed)*
- [x] Leave `scripts/verify-deploy.sh` lines 18 and 52 alone -- reference class, confirmed during
      planning. *(completed: confirmed zero diff)*
- [x] Re-read `scripts/check-extension-docs.sh` line 421 and make an explicit judged call: it
      reads "headlessly via scripts/deploy-headless.sh" inside a GUARDRAIL comment. If read as
      guidance to run the script, correct it to `.claude/scripts/deploy-headless.sh`; if read as
      an identifier reference, leave it. Record the call and its reasoning either way -- do not
      leave it unaddressed. *(completed: judged Reference class -- no "bash " prefix, not a
      runnable fence, names the headless mechanism in parallel with "interactively via
      <leader>al" in the same sentence rather than instructing a reader to run it verbatim; left
      unchanged)*
- [x] Run `bash -n` on each of the five modified scripts. *(completed: all five pass)*
- [x] Do NOT edit the corresponding files under `.claude/scripts/`. *(completed: not touched)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly ten invocation sites across five files, with
line numbers from the planning survey. Line numbers are the most fragile part of that assertion.
Confirm each site by matching the surrounding string content, not by line number alone, and
re-run the Phase 1 defect census after editing to confirm the count reached zero for these files.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - 4 advisory strings (+1 judged
  call at line 421)
- `agent-system/extensions/core/scripts/task-lock.sh` - 1 echo string, 1 comment
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - 1 echo string, 1 comment
- `agent-system/extensions/core/scripts/deploy-root-guard.sh` - 1 echo string
- `agent-system/extensions/core/scripts/system-defect-record.sh` - 1 comment

**Verification**:
- `bash -n` passes on all five scripts.
- `grep -rn 'bash scripts/deploy-headless\.sh' agent-system/extensions/core/scripts/` returns
  nothing.
- `grep -n 'scripts/\$s' agent-system/extensions/core/scripts/check-extension-docs.sh` still
  matches at line 446 (the identifier was not collaterally rewritten).
- `bash .claude/scripts/check-extension-docs.sh` (the currently deployed copy, i.e. the pre-fix
  one) still runs; no new failure appears versus the Phase 1 baseline.

---

### Phase 4: Add the Regression Guard [NOT STARTED]

**Goal**: Make the defect class mechanically unable to reappear, so a future edit reintroducing
`bash scripts/deploy-headless.sh` is caught by the gate rather than by an operator who is already
blocked.

**Tasks**:
- [ ] Add a check to `agent-system/extensions/core/scripts/check-extension-docs.sh` that scans
      the source store for the literal invocation form `bash scripts/deploy-headless.sh` and
      reports every hit with file and line number.
- [ ] Anchor the pattern on the `bash `-prefixed form ONLY. A bare-path pattern would fire on the
      ~16 correct reference-class sites and is wrong. State this constraint in a comment above
      the check so a future maintainer does not "improve" it into a false-positive generator.
- [ ] Guard the check on the source store being present (`agent-system/extensions/` exists); skip
      cleanly and silently when it is absent, so consuming repos with only a `.claude/` tree are
      unaffected.
- [ ] Decide and document the severity lane. Prefer `fail()` over `advisory()`: unlike the
      deploy-drift advisories this file already carries, this check is a deterministic string
      match on files under version control, needs no regeneration to satisfy, and cannot
      spuriously fire in a sibling session. Record the reasoning in the comment.
- [ ] Confirm the check is wired into the script's normal execution path (called from the same
      place the sibling checks are), not merely defined.
- [ ] Verify the guard fires: temporarily reintroduce the wrong form in a scratch copy or via a
      transient edit, confirm a non-zero exit and a useful message, then revert.
- [ ] Verify the guard is clean on the fixed tree: zero findings.
- [ ] Verify no false positives: confirm the guard is silent on
      `context/standards/shell-strict-mode.md`, `context/patterns/ci-deploy-tree-bootstrap.md`,
      `context/patterns/batch-orchestration-guardrails.md`, and `scripts/verify-deploy.sh`.
- [ ] `bash -n` the modified script.

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - one new check function plus
  its call site and rationale comment.

**Verification**:
- The guard reports zero findings against the fixed source store.
- The guard reports a finding (and a non-zero exit) against a deliberately reintroduced
  occurrence, then returns to clean after revert.
- The four named reference-class files produce no findings.
- `bash -n` passes.

---

### Phase 5: Deploy, Verify Acceptance, and Run the Full Gate [NOT STARTED]

**Goal**: Make the corrected source store live in `.claude/`, prove the doc's fences are runnable
exactly as written, and confirm the full gate run introduced no new failures.

**Tasks**:
- [ ] Deploy the source store: `bash .claude/scripts/deploy-headless.sh`. Capture stdout, the
      `[deploy-headless] RESULT=` marker line, and the exit code.
- [ ] Interpret the exit code against the script's documented contract, not against "0 means
      good": `0` = landed, verification clean; `3` = **landed**, but the inline
      `verify-deploy.sh --skip-slow` run reported findings; `1`/`2` = did NOT land. Only `1` or
      `2` is a Phase 5 failure. An exit `3` whose findings match the Phase 1 baseline is an
      expected pass for this task.
- [ ] Confirm the fix reached the deploy tree:
      `grep -n 'bash \.claude/scripts/deploy-headless\.sh' .claude/context/patterns/regeneration-is-manual-only.md`
      matches the two fence lines, and
      `grep -rn 'bash scripts/deploy-headless\.sh' .claude/` returns nothing.
- [ ] Acceptance check on fence 1 (non-destructive form, safe to run):
      `bash .claude/scripts/deploy-headless.sh --dry-run` -- must not exit 127.
- [ ] Acceptance check on fence 2 (**append `--dry-run`; never run `--wipe` for real here**):
      `bash .claude/scripts/deploy-headless.sh --wipe --dry-run` -- must not exit 127.
- [ ] Spot-check a runtime remedy string end-to-end: trigger or inspect one of the corrected
      `echo`/`advisory` messages and confirm the printed path is copy-pasteable and resolves.
- [ ] Run the full gate suite: `bash .claude/scripts/verify-deploy.sh` (no `--skip-slow`) and
      diff its failing-check set against `/tmp/186-gate-baseline.txt`.
- [ ] Confirm the delta is empty or strictly improving. Any NEW failure blocks the phase and must
      be traced to a Phase 2/3/4 edit and fixed.
- [ ] Final census: `grep -rn 'bash scripts/deploy-headless\.sh' agent-system/` returns nothing.

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- None in the source store. This phase regenerates `.claude/` (expected and sanctioned) and
  produces verification evidence only.

**Verification**:
- Deploy exit code is `0` or `3`, never `1` or `2`; the `RESULT=` marker confirms the tree was
  modified.
- Both fences run to a non-127 exit exactly as written (with `--dry-run` appended for safety).
- `verify-deploy.sh` shows no failing check absent from the Phase 1 baseline.
- Zero remaining `bash scripts/deploy-headless.sh` occurrences anywhere in `agent-system/` or
  `.claude/`.

---

## Testing & Validation

- [ ] `grep -rn 'bash scripts/deploy-headless\.sh' agent-system/` returns zero hits (was 12).
- [ ] `grep -rn 'bash scripts/deploy-headless\.sh' .claude/` returns zero hits post-deploy.
- [ ] The ~16 reference-class occurrences survive untouched, confirmed by re-running the
      full-form census from Phase 1 and comparing the `scripts/deploy-headless.sh` count against
      its expected post-fix value.
- [ ] `bash -n` passes on all five modified shell scripts.
- [ ] Both `regeneration-is-manual-only.md` code fences execute (with `--dry-run`) without exit
      127.
- [ ] `.github/workflows/check-extension-docs.yml:69`'s source-store-relative invocation is
      unchanged.
- [ ] The new regression guard: zero findings clean, non-zero on a reintroduced occurrence, no
      false positives on the four named reference-class files.
- [ ] `verify-deploy.sh` full run introduces no new failing checks versus the Phase 1 baseline.
- [ ] `git diff --stat` touches only files under `agent-system/extensions/core/` -- no `.claude/`
      file appears as a hand-edit.

## Artifacts & Outputs

- Corrected `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (two
  fences + one additive convention/failure-mode paragraph).
- Five corrected core scripts: `check-extension-docs.sh`, `task-lock.sh`,
  `orchestrate-batch-admit.sh`, `deploy-root-guard.sh`, `system-defect-record.sh`.
- A new regression guard inside `check-extension-docs.sh`.
- A regenerated `.claude/` tree carrying all of the above (deploy artifact, gitignored).
- `specs/186_fix_deploy_headless_path_in_regeneration_doc/summaries/01_*-summary.md` recording
  the final census numbers, the line-421 judged call, and the baseline-vs-final gate delta.

## Rollback/Contingency

- Every edit is a string-literal text change in version-controlled source-store files; `git
  checkout` of the six touched files restores the prior state exactly. The Phase 1 snapshot
  (`git-snapshot.sh 186`) is the coarse fallback.
- If the Phase 4 regression guard proves noisy or destabilizes the gate for consuming repos,
  Phase 4 alone can be reverted without touching Phases 2, 3, or 5 -- the guard is additive and
  the path corrections stand on their own. Demote it to the existing `advisory()` lane rather
  than dropping it entirely, if a middle ground is needed.
- If Phase 5's deploy exits `1` or `2` (did not land), the source store is still correct and
  committed; re-run the deploy after resolving the environmental cause (nvim availability, git
  repo detection, deploy lock). No source-store rollback is warranted for a deploy-side failure.
- If the full gate run surfaces a NEW failure traceable to a specific edit, revert that single
  file rather than the whole task -- the phases are file-disjoint by design.
