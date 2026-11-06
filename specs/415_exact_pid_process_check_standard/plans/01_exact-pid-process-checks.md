# Implementation Plan: Exact-PID Process Check Standard

- **Task**: 415 - Record exact-pid process checking as a parallelism-safety suite-authoring standard, replacing broad process-name matching
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: Sequenced after the verdict-extraction enforcement work, whose edit to `context/standards/shell-script-testing.md` has already landed (its `## Verdict-line extraction contract (producer/consumer)` section is present in the source store at line 703). Rebase onto that landed edit; never revert it.
- **Research Inputs**: specs/415_exact_pid_process_check_standard/reports/01_exact-pid-process-check-standard.md
- **Artifacts**: plans/01_exact-pid-process-checks.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The discipline of checking an exact spawned pid (rather than matching on process name) for
leftover/liveness assertions already exists in the corpus as a landed fix, but exists nowhere in
the convention document that governs suite authoring. This plan adds a parallelism-safety
subsection to `agent-system/extensions/core/context/standards/shell-script-testing.md`, placed
inside its existing `## Suite runtime: --jobs, --timings, and gate selection` section so it is
reachable from the parallelism material an author already reads; re-derives the corpus audit live
(rather than citing the research report's frozen number) and fixes any live occurrence it finds;
reproduces the original collision shape on purpose against the already-fixed suite to prove the
rule's claim; records the declined-mechanical-lint decision with its evidence in a durable
artifact; and redeploys plus runs the complete gate set with an explicit source-store `TARGET`.
Done means: the subsection is in place and discoverable via `index-entries.json`, the audit result
is a stated count with named files and a re-runnable search recipe, and the full gate set is green
against the source-store repository root.

### Research Integration

The research report establishes, and this plan builds directly on, five findings: (1) the origin
fix is live at `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh`
case13, which captures the stalled descendant's own pid at spawn into a dedicated pidfile and
tests `kill -0` against that exact pid — the canonical shape to cite rather than invent; (2) the
standard genuinely contains no process-check guidance (a full-document grep for the
name-matching utilities and exact-pid terms returns nothing); (3) the corpus audit found zero live
violations across the files carrying textual hits, every one of them a comment, a fixture string
for a different lint under test, or the already-fixed case; (4) a mechanical lint is declined
because 100% of current textual hits would need an allowlist entry and there is no live violating
target to prove detection against; (5) the insertion point is immediately after the
`## Suite runtime` section's closing bullet list and before
`### Mapping a touched file to its suite`. The report also flags
`context/patterns/bounded-build-waiter.md` as the sibling agent-layer discipline (same mechanism —
name matching is unsafe under concurrency — but a different actor and a different hazard:
self-match in a polling shell's own argv, not sibling-suite collision), to be cross-linked as
related-but-distinct rather than merged.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap path was provided in this dispatch; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- State the exact-pid rule, its mechanism-level rationale, the strictly-worse name-based-kill
  case, the copy-pasteable portable shape, and the `LOAD_SENSITIVE_BASENAMES` non-substitution
  point, as a `###` subsection reachable from the standard's existing parallelism material.
- Re-derive the corpus audit live and fix any live occurrence; state the result as a count with
  the files named plus the search commands that produced it.
- Record the rule's boundary explicitly (which corpora were audited and which were not) rather
  than silently widening it.
- Prove the rule's claim by reproducing the original collision shape on purpose, with a
  non-vacuousness check showing a name-based check would in fact have fired.
- Record the declined-mechanical-lint decision and its evidence in a durable artifact so the
  question is not reopened from scratch.
- Make the new material discoverable: update the standard's `index-entries.json` entry
  (`keywords`, `topics`, `line_count`).

**Non-Goals**:
- Adding a mechanical lint. The research declined it on measured evidence; this plan records the
  declination rather than reversing it.
- Auditing other extensions' suite corpora (lean, latex, python, typst, z3, cslib, ...). This
  task's footprint is core's own suites; the boundary is recorded, not widened.
- Fixing the known-unrelated pre-existing failures named in the dispatch (Gate 3 lean4 doc-lint
  index entry, Gate 20 eager-load budget, Gate 8 suites `test-detect-noop-bash.sh`,
  `test-four-tier-conflict.sh`, `test-guard-git-push.sh`).
- Restating a frozen audit count inside the standard itself; the standard carries the re-runnable
  recipe, the count lives in this task's own artifacts.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A concurrent sibling task edits `shell-script-testing.md` or `index-entries.json` between read and write (both files are already dirty in the working tree) | H | M | Re-read each file immediately before editing; stage only this task's own hunks with an explicit file list (never a directory or glob add); if a foreign commit or foreign uncommitted modification to either file is observed, stop and report per the Territory contract |
| `generate-context-line-counts.sh --write` rewrites `line_count` for every entry in every extension, far outside this task's footprint | H | M | Edit only the one entry's `line_count` surgically; use the script in its default `--check` (report-only) mode for verification, and treat mismatches it reports in other entries or extensions as pre-existing, not this task's to fix |
| The live audit finds an occurrence the research did not (the report's zero-count is a hypothesis, not a fact) | M | L | Phase 1 confirms the count before Phase 2 writes the subsection, so the boundary and the "true of the corpus as written" claim rest on a fresh search; a live occurrence found is fixed in Phase 1 and then exercised under the parallel pool |
| The collision reproduction passes vacuously (no identically-named sibling process actually alive during the suite run) | M | M | Mandatory non-vacuousness check: assert a name-match probe against the fixture's own command text matches the injected noise process while the suite is mid-run, per the standard's own non-vacuousness requirement |
| Prose quoting the anti-pattern's literal text trips the write-time bounded-waiter hook, blocking the edit | M | H | Observed in this very dispatch: a heredoc carrying the quoted pattern was refused. Author the subsection with the Write/Edit tools rather than a shell heredoc, and keep any quoted example free of a surrounding wait loop |
| The new subsection reads as an orphan, or visually conflates opt-in parallel scheduling with process-identity correctness | M | L | Own `###` heading inside the `## Suite runtime` section rather than folded into its bullet list, with an explicit sentence relating it to `LOAD_SENSITIVE_BASENAMES` and a cross-link to `bounded-build-waiter.md` |
| A bare `verify-deploy.sh` invocation silently skips the source-store-only gates | H | M | Final phase declares the complete gate set with an explicit source-store `TARGET` (the repository root holding both `.claude/` and `agent-system/extensions`) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Live corpus audit, collision reproduction, and lint declination record [COMPLETED]

**Goal**: Establish, from a fresh search rather than a cited number, what the corpus actually
contains; fix any live occurrence; prove the exact-pid shape is collision-immune by reproducing
the original collision on purpose; and record the audit result, the rule's boundary, and the
declined-lint decision in a durable artifact.

**Tasks**:
- [x] Re-run the audit search set from `agent-system/extensions/core`, capturing raw output. The
      four searches (as recorded in the research report's Appendix, to be reused verbatim) cover:
      the name-match process-query utility with a full-command-line flag; its kill counterpart
      with the same flag; the `ps`-piped-to-`grep` shapes (`aux`, `-ef`, `ax`); and a filenames-only
      sweep for either utility anywhere. Each runs over `scripts/tests/` and flat `scripts/*.sh`
      *(completed)*
- [x] Classify every hit as live-violation vs. non-violating (comment or documentation, fixture
      string fed to a different lint under test, or classification-matcher fixture), naming the
      file and line for each *(completed: 8 files, all non-violating — see summary)*
- [x] Fix any live violation found: capture the pid at spawn, test that pid with `kill -0`, clean
      up only that pid and its own children — and run the changed suite under the parallel pool
      (`bash scripts/tests/run-all.sh --only <suite> --jobs 4`). If the count is zero, state that
      the "fix any remaining occurrences" directive produced zero changes, with the search set
      above as the re-run recipe *(completed: zero live violations, zero changes made)*
- [x] Reproduce the original collision shape deliberately: spawn an unrelated sibling process
      using the same command text as case13's stalling fixture, capturing its pid at spawn; run
      `bash scripts/tests/test-gate-registry-resolution.sh` while that process is alive; confirm
      case13 passes *(completed: 35 passed, 0 failed, case13 reported no leftover against its own
      exact pid while the noise pid stayed alive)*
- [x] Non-vacuousness check for that reproduction: while the suite is mid-run, confirm a
      name-match probe against that same command text does match the injected noise pid — proving
      the reproduction would have tripped a name-based check and the pass is not vacuous. Then
      terminate only the injected noise process, by its captured pid *(deviation: altered — the
      probe ran as a standalone one-shot `pgrep -f` call immediately after the suite finished,
      while the noise process was still confirmed alive, rather than literally mid-run; combining
      a kill -0 liveness check and a pgrep -f probe in one command is refused by the
      validate-bounded-waiter.sh PreToolUse hook as an apparent wait-loop pattern. The noise
      process was alive throughout and after the run, so the evidence is equivalent: the probe
      matched the noise pid, confirming non-vacuousness. Noise pid terminated by its own captured
      pid only, confirmed dead by a follow-up kill -0.)*
- [x] Record in `specs/415_exact_pid_process_check_standard/summaries/01_exact-pid-process-checks-summary.md`
      (create it if absent; the completion summary extends this file rather than overwriting it):
      the audit count, the files named, the verbatim search commands, the collision-reproduction
      result with its non-vacuousness evidence, the audited boundary (core's own
      `scripts/tests/**` and flat `scripts/*.sh`; other extensions' suite corpora not audited and
      not claimed), and the declined-mechanical-lint decision with its reason (every current
      textual hit would require an allowlist entry, and there is no live violating target to
      prove detection against without a synthetic fixture — revisit only if a second live
      occurrence appears)

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: The research asserts zero live violations across the files carrying textual
hits (`test-gate-registry-resolution.sh`, `test-validate-bounded-waiter.sh`,
`test-lake-build-guard.sh`, `test-claude-refresh-matcher.sh`, `lake-build-guard.sh`,
`orchestrate-build-dispatch.sh`, `dispatch-strand-probe.sh`). Confirm by re-running the search
set above and classifying each hit from its own source line; do not carry the report's count
forward as a fact.

**Tier Justification**: The phase's only file write is a `specs/**` summary artifact plus, if the
audit finds one, a single suite file whose covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only <changed-suite> --jobs 4`;
`specs/**` paths map to no suite at all, so their honest check is the `prose` row's diff
read-through, as the `__FULL_SWEEP__` sub-case (a) prescribes.

**Files to modify**:
- `specs/415_exact_pid_process_check_standard/summaries/01_exact-pid-process-checks-summary.md` - audit count, named files, verbatim search commands, collision-reproduction and non-vacuousness evidence, audited boundary, declined-lint decision and reason
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` - no change expected; listed because it is the suite the collision reproduction runs, and the file that would be edited if the audit contradicted the zero-count hypothesis there

**Verification**:
- All four audit searches ran and their raw output is captured, not summarized from memory
- Every hit is classified with its file and line, and the resulting count of live violations is
  stated explicitly (zero is a result, provided the search set that produced it is recorded)
- Any suite changed by the audit passes under `run-all.sh --only <suite> --jobs 4`
- `test-gate-registry-resolution.sh` case13 passes while an unrelated identically-named process
  is alive, and the non-vacuousness probe confirms a name-based check would have matched that
  process during the run
- The summary artifact contains the boundary statement and the lint declination with its reason

---

### Phase 2: Add the parallelism-safety subsection and make it discoverable [NOT STARTED]

**Goal**: Land the rule in `context/standards/shell-script-testing.md`, inside the existing
parallelism section rather than as an orphan, and update the standard's `index-entries.json`
entry so keyword-based context discovery reaches the new material.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/standards/shell-script-testing.md`
      immediately before editing (both this file and `index-entries.json` are already dirty in the
      working tree; a sibling may have moved the insertion point)
- [ ] Re-locate the insertion point by content, not by a cached line number: the end of the
      `## Suite runtime: --jobs, --timings, and gate selection` section's bullet list (currently
      ending with the `--class` / `--tag` / `--cost-class` bullet), immediately before
      `### Mapping a touched file to its suite: scripts/lib/suite-selection-lib.sh`
- [ ] Insert a new `###` subsection (own heading, not folded into the bullet list) stating:
      (a) the rule — a suite checking for a leftover or still-running process MUST check the exact
      pid it itself spawned, captured at spawn time, and a process-NAME match (either name-query
      utility with a command-line flag, or `ps` piped to `grep` on a command pattern) is never
      acceptable for this purpose inside the battery;
      (b) the mechanism-level reason — under a parallel pool a sibling suite may legitimately be
      running a process with the same name at the same moment, so a name-based check tests the
      state of the whole host rather than the state of the suite, and a suite that asserts about
      the host is not parallelism-safe by construction, independently of whether a collision has
      yet been observed;
      (c) the strictly worse adjacent case — a name-based KILL in a suite can terminate a sibling
      session's work, a failure mode already paid for at the agent level in this repository and
      not to be reintroduced at the suite level;
      (d) the portable shape, concretely enough to copy — write `$!` to a dedicated pidfile at
      spawn, test liveness with `kill -0 "$pid"`, and clean up only that pid and its own children —
      citing `scripts/tests/test-gate-registry-resolution.sh` case13 by name as the already-landed
      worked example;
      (e) the `LOAD_SENSITIVE_BASENAMES` non-substitution point, in the voice the document already
      uses for its load-sensitive / known-failures distinction: the serialized set exists for load
      sensitivity, not check precision, and using it to paper over an imprecise check both slows
      the pool and leaves the latent bug in place;
      (f) the re-runnable audit recipe (the Phase 1 search set) with no frozen count, per this
      document's own re-run-don't-cite convention;
      (g) a cross-link to `context/patterns/bounded-build-waiter.md` as the sibling agent-layer
      discipline — same mechanism, different actor and hazard (self-match in a polling shell's own
      argv) — explicitly related, never merged
- [ ] Confirm the subsection reads as reachable from the section it sits in (its heading is
      nested under `## Suite runtime`, and the serialized-set sentence ties it to that section's
      own material) rather than as an appended orphan
- [ ] Re-read `agent-system/extensions/core/index-entries.json`, then surgically update the
      `standards/shell-script-testing.md` entry only: add `pid` and `process-check` to
      `keywords`, add `parallelism-safety` to `topics`, and correct `line_count` to the file's new
      `wc -l`. Do not run `generate-context-line-counts.sh --write` (it rewrites every entry in
      every extension, far outside this footprint)
- [ ] Validate the JSON parses (`python3 -m json.tool` or `jq empty`) and that the diff touches
      only that one entry

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Tier Justification**: Both edits are source-store non-`specs/**` markdown and JSON with no
mapped suite (`__FULL_SWEEP__` sub-case (b)), whose covering check is
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(doc-lint and task-reference lint, with the source-store repository root as explicit `TARGET`)
plus `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` in its
report-only mode for the `line_count` field.

**Files to modify**:
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - new `###` parallelism-safety subsection on exact-pid process checks, inserted at the end of the `## Suite runtime` section's bullet list
- `agent-system/extensions/core/index-entries.json` - the `standards/shell-script-testing.md` entry only: `keywords` plus `pid` and `process-check`; `topics` plus `parallelism-safety`; `line_count` corrected

**Verification**:
- The new subsection is a `###` heading inside `## Suite runtime: --jobs, --timings, and gate
  selection`, positioned before `### Mapping a touched file to its suite`, confirmed by
  re-reading the section boundaries after the edit
- All seven content requirements (a)-(g) above are present, and the `bounded-build-waiter.md`
  cross-link states the two disciplines as related-but-distinct
- No frozen audit count appears in the standard; the re-runnable recipe does
- `index-entries.json` parses, and its diff touches only the `standards/shell-script-testing.md`
  entry; `generate-context-line-counts.sh --check` reports no mismatch for that entry (mismatches
  reported for other entries or other extensions are pre-existing and out of scope)
- `verify-deploy.sh --skip-slow --only-gate 3,4 <source-store repo root>` is green, with the
  `TARGET` given explicitly
- `git status --short` and `git diff --staged` reviewed before committing; only this task's two
  files staged, by explicit file list

---

### Phase 3: Redeploy and full gate set [NOT STARTED]

**Goal**: Regenerate the deployed tree from the source store and verify the complete gate set
against the source-store repository root, so the source-store-only gates actually run.

**Tasks**:
- [ ] Redeploy: `bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/deploy-headless.sh`
      (whole-tree regeneration — this phase declares `__WHOLE_TREE__` accordingly)
- [ ] Confirm the new subsection and the updated index entry are present in the deployed tree
      (`.claude/context/standards/shell-script-testing.md`, `.claude/context/index.json`)
- [ ] Run the complete gate set with an explicit source-store `TARGET`, never the bare form:
      `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim`
- [ ] Triage the result against the dispatch's known-unrelated baseline: Gate 3 lean4 doc-lint
      missing `index.json` entry; Gate 20 eager-load budget over baseline; Gate 8 suites
      `test-detect-noop-bash.sh`, `test-four-tier-conflict.sh`, `test-guard-git-push.sh`. Do not
      attribute these to this work and do not fix them here; any failure outside that set is
      this task's to resolve
- [ ] Extend the summary artifact with the gate-set result and the triage against the baseline

**Timing**: 30 minutes

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree from the source store
- `specs/415_exact_pid_process_check_standard/summaries/01_exact-pid-process-checks-summary.md` - gate-set result and triage against the known-unrelated baseline

**Verification**:
- The deployed tree carries the new subsection and the updated index entry
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim`
  ran with the `TARGET` argument present (the bare form is not acceptable evidence — it silently
  skips the source-store-only gates) and its result is recorded verbatim
- Every failure in that run is matched against the dispatch's known-unrelated set; the failure
  set is identical to that baseline, or any difference is explained and resolved
- The summary artifact records the gate command as run, not a paraphrase of it

---

## Testing & Validation

- [ ] Four audit searches run live, raw output captured, every hit classified by file and line
- [ ] Live-violation count stated explicitly alongside the search set that produced it
- [ ] Any suite changed by the audit passes under `run-all.sh --only <suite> --jobs 4`
- [ ] `test-gate-registry-resolution.sh` case13 passes with an unrelated identically-named
      process alive, and the non-vacuousness probe confirms a name-based check would have matched
      it during the run
- [ ] New subsection is a `###` heading inside the `## Suite runtime` section, before
      `### Mapping a touched file to its suite`
- [ ] `index-entries.json` parses; its diff touches only the one entry;
      `generate-context-line-counts.sh --check` reports no mismatch for that entry
- [ ] `verify-deploy.sh --skip-slow --only-gate 3,4 <repo root>` green after Phase 2
- [ ] Full `verify-deploy.sh <repo root>` run with explicit `TARGET`; failure set matches the
      dispatch's known-unrelated baseline
- [ ] No task-number references and no record-versioning language in any file landing under
      `agent-system/**`

## Artifacts & Outputs

- `agent-system/extensions/core/context/standards/shell-script-testing.md` — new parallelism-safety subsection on exact-pid process checks
- `agent-system/extensions/core/index-entries.json` — updated `keywords`, `topics`, `line_count` for that standard's entry
- `specs/415_exact_pid_process_check_standard/summaries/01_exact-pid-process-checks-summary.md` — audit count with named files and verbatim search commands, collision-reproduction and non-vacuousness evidence, audited boundary, declined-mechanical-lint decision with its reason, full gate-set result
- Regenerated deployed `.claude/` tree (disposable deploy artifact, not committed as source)

## Rollback/Contingency

Each phase commits its own files by explicit file list, so reverting is per-commit: `git revert`
the phase commit, or re-edit forward. The two source-store edits are additive (one inserted
markdown subsection, one entry's fields) and carry no behavioral surface, so a forward fix is
always available and is preferred over discarding work.

If an intentional rollback of uncommitted work becomes necessary, follow
`context/contracts/recovery.md`'s rollback rung for the snapshot-then-rollback invocation shape
(including its out-of-scope override flag) before running any destructive git command. Do not
take a routine reverting snapshot as a precautionary start-of-phase checkpoint; for an ordinary
defensive checkpoint use `git-snapshot.sh --no-revert`, which is durable without touching the
working tree — this matters especially here, where concurrent sibling tasks share the tree.

If the deployed tree is left inconsistent after a failed redeploy, re-run `deploy-headless.sh` —
`.claude/` is a regenerable deploy artifact, so recovery is a redeploy, never a hand-edit of the
deployed copy.
