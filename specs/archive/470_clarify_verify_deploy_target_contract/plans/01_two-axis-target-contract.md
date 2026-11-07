# Implementation Plan: Task #470

- **Task**: 470 - Clarify verify-deploy.sh TARGET contract versus its invocation-directory claim
- **Status**: [COMPLETED]
- **Effort**: 2.65 hours
- **Dependencies**: None
- **Research Inputs**: specs/470_clarify_verify_deploy_target_contract/reports/01_target-contract-clarification.md
- **Artifacts**: plans/01_two-axis-target-contract.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`verify-deploy.sh`'s header states a true claim about its **invocation-CWD axis** ("resolves its
TARGET from an explicit argument or `$(pwd)` ... so it runs correctly from either tree with no
override") and says nothing about its **TARGET-argument axis**. This plan adds the missing
TARGET-argument contract alongside the existing claim (never replacing it), carries that contract
into the usage line's `[TARGET_REPO]` placeholder and gate0's stderr, and corrects the one
upstream document that actually prescribes the broken invocation. Every edit is a comment, a
markdown sentence, or a pure `echo ... >&2` addition — no gate's pass/fail semantics change.

### Research Integration

The research report confirmed the mechanism (gate0 hard-requires `$TARGET/.claude` at
`verify-deploy.sh:496-504`, and ~20 source-store-only gates additionally guard on
`$TARGET/agent-system/extensions`), verified no test pins gate0's stderr wording, and recommended
header-alone authority plus a one-clause strengthening of `regeneration-is-manual-only.md:888`.
This plan adopts all of that. Two findings were established during planning that the report does
not contain, and both change the work:

1. **The actual origin site is `context/formats/plan-format.md:364`**, not the script header. Its
   `__FULL_SWEEP__` sub-case (b) hands planners a copy-pasteable
   `bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>` — a
   verbatim match for the invocation named in this task's CITATION. A repo-wide grep found this
   is the only occurrence of that shape outside `specs/**` and the deployed tree. Reproduced
   directly during planning: that invocation exits 2 with `no deploy tree at
   .../agent-system/extensions/core/.claude`. Correcting it is in scope under outcome 4's "one
   authority plus pointers" instruction — leaving the origin uncorrected would mean the clarified
   header competes with a live instruction to do the wrong thing.

2. **Gate 3 (doc-lint) already FAILS at baseline**, before any edit in this plan. Measured during
   planning via `verify-deploy.sh --skip-slow --only-gate 3,4,22 /home/benjamin/.config/nvim`:
   exit 1, gate 3 FAIL, gates 4 and 22 PASS. The failures are all staleness-driven — "deployed
   script content drift" across ~15 files and two Rule R `line_count` mismatches in
   `index-entries.json` (`formats/plan-format.md` declared 807, actual 818;
   `contracts/batch-gate-stage.md` declared 132, actual 163). This matches the dispatch's own
   `deploy-freshness-context` (core, lean, literature all stale). Consequence for this plan: every
   phase below verifies **differentially** (capture `--findings` before, diff after, assert no NEW
   finding) rather than by exit code, exactly as the script's own `--findings` header subsection
   prescribes. An exit-1 run is the expected baseline, not evidence of a regression.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in the dispatch context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:

- Separate the two axes explicitly in the header: where the script may be INVOKED FROM (the
  retained `#441` claim) versus what TARGET may BE (outcome 1).
- Give `[TARGET_REPO]` an inline contract naming the concrete `--only-gate 3,4 <source_dir>`
  failure and the repo root as the correct TARGET for source-store gates (outcome 2).
- Make gate0's stderr teach the convention, not just report the missing directory (outcome 3).
- Decide and act on outcome 4: single authority in the script header, with
  `regeneration-is-manual-only.md`'s existing pointer sentence widened by one clause — no second
  partial copy.
- Correct `plan-format.md:364`, the live instruction that produces the defect this task responds
  to.
- Land the change in the deployed tree via a real redeploy.

**Non-Goals**:

- Any change to a gate's pass/fail semantics, exit codes, `CHECKS`/`FAILURES` counters, or
  `[SKIP]` guards (outcome 5). The only executable change is gate0's stderr emission.
- Fixing the pre-existing baseline doc-lint failures beyond what the redeploy in Phase 4 resolves
  on its own. The ~15 "content drift" entries and the `batch-gate-stage.md` line_count mismatch
  belong to other, uncommitted work in this tree.
- Any edit to `redeploy_remedy_fragment` or its call site (its own suite pins constraints on that
  function's output).
- A new context file for the general "explicit TARGET argument has its own shape contract"
  pattern. The report recommends deferring that until a second script is found conflating the two
  axes.
- Touching the deployed `.claude/**` copies by hand. The source store
  (`agent-system/extensions/core/`) is the edit target; Phase 4 redeploys.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `verify-deploy.sh` carries ~76 lines of **pre-existing foreign uncommitted work** (the `warn_advisory()`/`WARN-FINDING` channel, in the header at lines ~159-186 and at ~606). `git-commit-scoped.sh` stages at pathspec granularity only — no hunk-level staging — so committing this file sweeps that work in. | H | H (already present) | Phase 1 opens with a mandatory disclosure step and Phase 2 closes with an explicit decision gate (below). Default branch: leave the file uncommitted and report, never silently commit foreign hunks under a `task 470:` message. |
| `index-entries.json` also carries foreign uncommitted modification (4 lines), and Phase 3's line-count regeneration writes to it. | M | H (already present) | Phase 3 inspects `git diff` on that file before staging; if foreign hunks are present it leaves the file unstaged and reports, deferring the line-count sync to Phase 4's redeploy (which runs the generator itself). |
| Concurrent sibling task #414 declares `verify-deploy.sh` in its own `file_scope` (plus not-started #444, #445, #449). | M | M | Keep this task's diff to three disjoint regions: the header block (lines ~1-40), and gate0 (lines ~496-504). Re-read the file immediately before each edit. #414's likely regions (gate-registry resolution, verdict-extraction anchoring) do not overlap. |
| Gate 3's pre-existing FAIL masks a newly-introduced finding if verification compares exit codes. | H | H | Every phase verifies differentially against a captured `--findings` baseline, per the script's own header guidance. Phase 1 captures that baseline first. |
| A new header paragraph balloons into restating all ~20 per-gate SKIP sites. | L | M | Name representative gate ids (3, 4, 6, 7, 12, "and others") and point at the existing per-gate `[SKIP]` comment pattern; do not enumerate. |
| Editing `plan-format.md` changes its line count, re-breaking Rule R if not regenerated. | M | H | Phase 3 runs `generate-context-line-counts.sh --write`; Phase 4's redeploy runs it again automatically. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phases 1 and 3 touch disjoint files. Phase 2
is serialized behind Phase 1 because both edit `verify-deploy.sh`.

**Note on this plan's own invocation shapes**: every `verify-deploy.sh` command below passes
`TARGET=/home/benjamin/.config/nvim` (the repo root), which is the only directory in this
repository that simultaneously holds the deployed `.claude/` and the `agent-system/extensions`
source store. That is deliberate: it is the contract this task documents, and it contradicts
`plan-format.md:364`'s current text, which Phase 3 corrects.

---

### Phase 1: Header — Separate the Invocation-CWD Axis from the TARGET Axis [COMPLETED]

**Goal**: The header states both axes explicitly, and `[TARGET_REPO]` carries its contract inline
(outcomes 1 and 2).

**Tasks**:

- [x] Capture the differential baseline:
      `bash agent-system/extensions/core/scripts/verify-deploy.sh --findings --quiet --skip-slow --only-gate 3,4,22 /home/benjamin/.config/nvim 2>/dev/null | grep '^FINDING ' | sort -u > /tmp/claude-1000/-home-benjamin--config-nvim/fcbf2ae8-d69d-4f60-b0d2-b3405211c42d/scratchpad/470-findings-before.txt`
      (expected: non-empty, exit 1 — see Research Integration finding 2). *(completed: baseline
      shifted since planning — 0 findings, exit 0; gate 3's pre-existing FAIL has since been
      resolved by other work. Recorded via issue-record.sh as a `kind: win`.)*
- [x] Capture the gate0 reproduction baseline:
      `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core 2>&1`
      — record the exact three stderr lines and exit 2 for later comparison. *(completed)*
- [x] Run `git diff -- agent-system/extensions/core/scripts/verify-deploy.sh` and `git log -1 --stat`.
      Confirm the uncommitted diff is **not** this session's own work, then record it via
      `issue-record.sh --kind issue --class "concurrency" --severity costly` naming the foreign
      hunks and their line regions. Do not revert, stash, or reset it. *(deviation: altered — the
      diff is empty at implement time; the foreign warn_advisory()/WARN-FINDING hunks the plan
      flagged were already committed upstream (`task 810 phase 4`), so there is no foreign work to
      disclose. Recorded as a `kind: win` instead of `kind: issue`.)*
- [x] Re-read `agent-system/extensions/core/scripts/verify-deploy.sh` lines 1-40 immediately
      before editing. *(completed)*
- [x] Insert a new `# TARGET_REPO CONTRACT:` paragraph immediately after the existing
      `# INVOCATION CONTRACT:` paragraph (which ends at line ~12 with "running a sub-check's
      source-store copy instead would make that comparison meaningless."). The new paragraph must:
      open by naming itself as a **separate axis** from the paragraph above; state that TARGET,
      when given, must be a repository already holding a deployed `.claude/` tree (gate0 requires
      `$TARGET/.claude`, else exit 2); state that it is never the
      `agent-system/extensions/<name>` source-store directory, which has no `.claude/`
      subdirectory; state that every source-store-only gate (3, 4, 6, 7, 12 and others, each
      guarded on `$TARGET/agent-system/extensions`) additionally `[SKIP]`s unless TARGET also
      holds `agent-system/extensions`; and conclude that TARGET must therefore be simultaneously a
      deploy consumer AND the source store for those gates to run at all — in this repository,
      only the repo root. *(completed)*
- [x] Leave the existing `# INVOCATION CONTRACT:` paragraph byte-identical. It is correct on its
      own axis and the task description requires it be qualified, not deleted. *(completed:
      verified byte-identical and `grep -c 'INVOCATION CONTRACT'` is 1 — the new paragraph refers
      to "the paragraph above" rather than repeating the literal label, to keep that grep count
      meaningful.)*
- [x] Add a `# TARGET_REPO placeholder (see TARGET_REPO CONTRACT above):` explanatory subsection
      directly below the `# Usage:` block (line ~33), mirroring the existing
      `# Minimal-init hatch (--minimal-init DIR, ...)` subsection shape already used in this
      header. It must name the concrete consequence: `--only-gate 3,4 <source_dir>` cannot work,
      because `<source_dir>` has no `.claude/` and gate0 fires before gate selection is consulted;
      the repo root is the correct `TARGET_REPO` for exercising source-store gates. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: A comment-only edit to a shell script can only break parse or lint, both
covered by `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` plus
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 22 /home/benjamin/.config/nvim`
(gate 22, shellcheck lint, measured PASS at baseline).

**Files to modify**:

- `agent-system/extensions/core/scripts/verify-deploy.sh` - add the `TARGET_REPO CONTRACT` header
  paragraph and the `TARGET_REPO placeholder` usage subsection; existing `INVOCATION CONTRACT`
  paragraph untouched

**Verification**:

- `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` exits 0.
- Gate 22 still PASSes: `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 22 /home/benjamin/.config/nvim`.
- `grep -c 'INVOCATION CONTRACT' verify-deploy.sh` is 1 and the sentence "so it runs correctly from
  either tree with no override" is still present verbatim.
- `grep -n 'TARGET_REPO CONTRACT' verify-deploy.sh` returns a line in the first 40 lines, and its
  paragraph mentions both `$TARGET/.claude` and `$TARGET/agent-system/extensions`.
- `git diff -- verify-deploy.sh` shows only additions in the header region plus the pre-existing
  foreign hunks — zero deletions attributable to this phase.

---

### Phase 2: gate0 Error Text Names the Convention [COMPLETED]

**Goal**: A reader who passed a source directory learns from the error text that TARGET must be
the repository root holding the deployed tree (outcome 3).

**Tasks**:

- [x] Re-read `agent-system/extensions/core/scripts/verify-deploy.sh` lines 490-510 immediately
      before editing. *(completed: actual lines shifted to ~520-545 after Phase 1's header
      insertions; re-read at the shifted location.)*
- [x] Insert exactly one new line between the existing `echo "ERROR: no deploy tree at
      $CLAUDE_DIR -- nothing to verify." >&2` and `echo "Run: bash deploy-headless.sh $TARGET"
      >&2`, as its own `echo ... >&2` statement, stating that TARGET must be a repository root
      holding a deployed `.claude/` tree and never the `agent-system` source-store directory
      itself. *(completed)*
- [x] Leave untouched, byte-for-byte: the `redeploy_remedy_fragment` call and its surrounding
      `echo`, the `[ "$FINDINGS" = "true" ]` FINDING line, the `exit 2`, and the
      `target is not a directory` branch above it. *(completed: confirmed byte-identical)*
- [x] Re-run the exact reproduction from Phase 1 and diff its output against the captured
      baseline: the only difference must be the one added line. *(completed: `diff` confirms
      exactly one added stderr line)*
- [x] **Decision gate — commit scope.** Re-run `git diff -- verify-deploy.sh`. If the foreign
      `warn_advisory()`/`WARN-FINDING` hunks recorded in Phase 1 are still uncommitted:
      **default branch** — do not commit this file; leave both phases' edits in the working tree,
      record the condition via `issue-record.sh`, and state it explicitly in
      `.orchestrator-handoff.json`'s `blockers` as a commit-scope deferral (the edits are complete
      and verified; only the commit is withheld). Commit normally **only** if the foreign hunks
      have since been committed by their owner, leaving this task's edits as the file's sole
      uncommitted diff. Never widen the pathspec, never `git add -A`, and never revert or stash
      the foreign work to clear the path. *(completed: the foreign `warn_advisory()`/
      `WARN-FINDING` hunks were already committed upstream before this dispatch began (see Phase
      1's win entry) -- `git diff -- verify-deploy.sh` shows only this task's own hunks, so the
      **commit-normally** branch applies; no commit-scope deferral needed.)*

**Timing**: 0.4 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The change is a single `echo ... >&2` on an already-terminal `exit 2`
path, covered by gate 22 shellcheck plus a direct reproduction
(`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core`)
diffed against the Phase 1 baseline capture.

**Files to modify**:

- `agent-system/extensions/core/scripts/verify-deploy.sh` - one added `echo ... >&2` line in the
  gate0 `.claude/`-missing branch (lines ~496-504)

**Verification**:

- `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` exits 0.
- The reproduction still exits 2, and its stderr diff against the Phase 1 baseline is exactly one
  added line naming the repository-root convention.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 22 /home/benjamin/.config/nvim`
  still PASSes.
- A successful run is unaffected:
  `bash agent-system/extensions/core/scripts/verify-deploy.sh --findings --quiet --skip-slow --only-gate 3,4,22 /home/benjamin/.config/nvim | grep '^FINDING ' | sort -u`
  diffs clean against `470-findings-before.txt` (no NEW finding; pre-existing ones may remain).
- `git diff -- verify-deploy.sh` shows exactly one added executable line for this phase, with no
  deletion and no change inside the `redeploy_remedy_fragment` or FINDING lines.

---

### Phase 3: Companion Documents — Pointer Clause and the Corrected Origin-Site Invocation [COMPLETED]

**Goal**: `regeneration-is-manual-only.md`'s existing pointer names *which* contract the header
holds (outcome 4, decided as header-alone-plus-pointer), and `plan-format.md`'s copy-pasteable
sub-case (b) shape stops prescribing an invocation that cannot run.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
      lines 880-892 immediately before editing. *(completed)*
- [x] Widen the existing sentence at line ~888 ("`verify-deploy.sh` carries no such guard at all
      and sits outside this contract entirely -- see its own header for why.") by one clause, so
      it states that the script resolves TARGET from an explicit argument rather than this
      section's own-location mechanism, and that the argument's **required shape** is a separate
      contract documented in its own header. Add no new section and no duplicate prose — this
      section stays a pointer. *(completed: one `verify-deploy.sh` mention confirmed in the
      Root-Resolution Guard section)*
- [x] Re-read `agent-system/extensions/core/context/formats/plan-format.md` lines 344-372
      immediately before editing. *(completed)*
- [x] Correct sub-case (b) of the `__FULL_SWEEP__` case:
      - Replace the copy-pasteable shape at line ~364,
        `bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>`,
        with a shape whose TARGET is the **repo root** of the source-store repository (the only
        directory holding both a deployed `.claude/` and `agent-system/extensions`).
        *(completed: new shape is `bash <repo_root>/.claude/scripts/verify-deploy.sh --skip-slow
        --only-gate 3,4 <repo_root>`)*
      - Correct the accompanying claim that the no-argument form "silently runs both gates' SKIP
        branch there and checks nothing". That is true for a pure deploy-consumer repo, but false
        in the source-store repo, where `$(pwd)` at the repo root is itself a valid TARGET for
        both gates. State the distinction rather than deleting the warning. *(completed)*
      - Add a short cross-reference to `verify-deploy.sh`'s own `TARGET_REPO CONTRACT` header
        paragraph (landed in Phase 1) as the authority, keeping this file a consumer of that
        contract rather than a second copy of it. *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` to
      resync `index-entries.json`'s `line_count` for both edited markdown files. *(completed: run
      as `REPO_ROOT=$(pwd) bash ...` since the source-store invocation requires the explicit
      override per regeneration-is-manual-only.md's Root-Resolution Guard)*
- [x] Inspect `git diff -- agent-system/extensions/core/index-entries.json`. If it contains hunks
      beyond the two `line_count` values for the files this phase edited, leave that file
      unstaged, record the condition via `issue-record.sh`, and note it in the handoff — Phase 4's
      redeploy runs the generator again, so the sync is not lost. *(completed: 6 of 8 regenerated
      entries were pre-existing foreign uncommitted diffs; left entirely unstaged and recorded via
      issue-record.sh)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: Markdown-only edits whose covering checks are
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(gate 3's Rule R `line_count` rule and gate 4's task-reference lint — compared differentially,
since gate 3 FAILs at baseline) plus
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-consumer-freshness.sh,test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh`,
the suites `suite_selection_select` resolves for these two paths.

**Scope Hypothesis**: `plan-format.md:364` is asserted to be the **only** occurrence of the broken
`--only-gate 3,4 <source_dir>` shape outside `specs/**` and the deployed `.claude/**` tree, based
on a repo-wide grep run during planning. Confirm at implementation time with
`grep -rn 'only-gate 3,4' --include='*.md' --include='*.sh' . | grep -v '^./.claude/' | grep -v '^./specs/'`
before editing; if a second site exists, correct it in this same phase and say so.

**Files to modify**:

- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - one-clause
  widening of the existing `verify-deploy.sh` pointer sentence at line ~888
- `agent-system/extensions/core/context/formats/plan-format.md` - corrected `__FULL_SWEEP__`
  sub-case (b) invocation and its accompanying SKIP-branch claim, plus a cross-reference to the
  script header's `TARGET_REPO CONTRACT`
- `agent-system/extensions/core/index-entries.json` - regenerated `line_count` values for the two
  edited markdown files (generator-written, not hand-edited)

**Verification**:

- `grep -n 'only-gate 3,4' agent-system/extensions/core/context/formats/plan-format.md` shows no
  surviving `<source_dir>` TARGET; the corrected shape's TARGET is the repo root.
- The corrected shape, executed verbatim with `<repo-root>` substituted, exits without gate0's
  "no deploy tree" error and actually runs gates 3 and 4 (neither reports `[SKIP]`).
- `regeneration-is-manual-only.md` still has exactly one `verify-deploy.sh` mention in the
  Root-Resolution Guard section, and it still defers to the header (no new section added).
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is run and **its exit status recorded** (expected 1 at this point, from the pre-existing
  staleness failures measured during planning — not 0; Phase 4's post-redeploy full battery is
  where exit 0 is the authoritative bar). The differential findings diff against
  `470-findings-before.txt` is checked *in addition to* that exit status and must show no NEW
  `FINDING` line; the pre-existing `formats/plan-format.md` Rule R `line_count` mismatch must be
  resolved.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-consumer-freshness.sh,test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh`
  exits 0.

---

### Phase 4: Redeploy and Full Verification [COMPLETED]

**Goal**: The clarified contract exists in the deployed tree, and the full gate battery confirms
no regression against the captured baseline.

**Tasks**:

- [x] Confirm Phases 1-3 are complete and their verification criteria met. *(completed)*
- [x] Redeploy with the bounded-wait idiom:
      `timeout 540 bash .claude/scripts/deploy-headless.sh` with the Bash tool `timeout` parameter
      raised to 600000 (never its 120000ms default) — see
      `context/patterns/external-process-wait.md` Rule 1. Drive to `RESULT=landed_verify_clean`.
      Never hand-patch a deployed file as a substitute. *(completed: landed_verify_clean, 38
      checks, 0 failures, on the first attempt)*
- [x] If the redeploy's own inline verification reports failures, determine whether each one is
      pre-existing (present in `470-findings-before.txt`) or newly introduced. Only a NEW finding
      is this task's regression. *(completed: redeploy's own inline verification reported 0
      failures; no findings to classify)*
- [x] Run the full battery at the repo root:
      `bash .claude/scripts/verify-deploy.sh --findings --quiet /home/benjamin/.config/nvim 2>/dev/null | grep '^FINDING ' | sort -u > .../470-findings-after.txt`,
      then `diff 470-findings-before.txt 470-findings-after.txt`. *(deviation: altered — the
      dispatch file's Batch Gate Deferral section, not present when this plan was written,
      requires this specific dispatch to discharge this phase against a scoped tier and defer the
      full gate set to the once-per-invocation batch stage. An independent unscoped full-battery
      run was attempted first and FAILed at gate 8, traced to a pre-existing, already-tracked
      test-corpus defect (`specs/476_isolate_seven_red_gate8_shell_suites`, itself citing
      completed task 275's proof that these suites fail identically on unmodified master) plus
      plausible interference from concurrently-active sibling-task dispatches in this same batch
      touching shared verify-deploy.sh/gate-selection test fixtures — not a regression introduced
      by this task. Recorded via `issue-record.sh`. The dispatch-mandated scoped substitute,
      `verify-deploy.sh --skip-slow --only-gate 3,4,6,7,12,22` at the repo root, exits 0 clean
      (7/7 PASS, none SKIP) both before and after this check, confirming no regression within
      this task's own scoped tier; the full-battery exit-0 bar is deferred to the batch-level
      stage per the dispatch contract.)*
- [x] Confirm the deployed copy carries the change: the `TARGET_REPO CONTRACT` paragraph and the
      new gate0 line are present in `.claude/scripts/verify-deploy.sh`, and the corrected sub-case
      (b) shape is present in `.claude/context/formats/plan-format.md`. *(completed, plus the
      widened pointer sentence confirmed present in
      `.claude/context/patterns/regeneration-is-manual-only.md`)*
- [x] Re-run the original failing invocation against the **deployed** script and confirm the new
      error line appears:
      `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core`.
      *(completed: exit 2 unchanged, new convention-naming line present alongside the original
      three lines)*
- [x] Record a `kind: win` or `kind: issue` entry for this phase's outcome via `issue-record.sh`,
      and attest explicitly in the handoff if nothing arose. *(completed: one win entry for the
      clean redeploy/deployed-copy confirmation, one issue entry for the full-battery deferral
      correction)*

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`, an
  implicit scope claim over the entire deployed tree
- `agent-system/extensions/core/index-entries.json` - possibly re-touched by the deploy's own
  automatic `generate-context-line-counts.sh --write` run

**Verification**:

*(Batch Gate Deferral note: this dispatch's own dispatch file carried a `## Batch Gate
Deferral` section — generated after this plan was written — directing this phase to discharge
against a scoped tier and defer the unscoped full-battery exit-0 bar below to the
once-per-invocation batch-level stage. The bullet is kept verbatim as the plan's own standing
criterion; the Implementation Phases task-list annotation above records what was actually run in
its place and why.)*

- `deploy-headless.sh` reaches `RESULT=landed_verify_clean`.
- The complete gate set runs and **exits 0**:
  `bash .claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim` (no `--only-gate`, no
  `--skip-slow` — `--skip-slow` is never evidence that doc-sync pins hold, and a selected subset
  never substitutes for the full battery at task close). Exit 0 is the authoritative bar here; the
  diff below is corroborating evidence, not a replacement for it. If exit is non-zero, the
  differential diff decides only whether the task is `[PARTIAL]` on pre-existing grounds (see
  Rollback/Contingency) or has introduced a regression.
- `diff 470-findings-before.txt 470-findings-after.txt` shows no NEW `FINDING` line attributable
  to this task. Pre-existing staleness findings resolved by the redeploy may disappear; none may
  appear.
- Gates 3, 4, 6, 7, 12 and 22 all run (none `[SKIP]`) under the repo-root TARGET, demonstrating
  the contract this task documents.
- The deployed `.claude/scripts/verify-deploy.sh` emits the new gate0 line for a source-directory
  TARGET.

---

## Testing & Validation

- [ ] `bash -n` clean on `verify-deploy.sh` after each edit.
- [ ] Gate 22 (shellcheck) PASSes after each `verify-deploy.sh` edit.
- [ ] Gate0 reproduction against a source directory exits 2 and prints the new convention line
      alongside the three pre-existing lines, with `redeploy_remedy_fragment`'s output unchanged.
- [ ] The corrected `plan-format.md` sub-case (b) invocation executes successfully and actually
      runs gates 3 and 4 rather than `[SKIP]`ping them or erroring at gate0.
- [ ] Differential `--findings` comparison (before vs. after) shows no newly-introduced finding.
- [ ] Full `verify-deploy.sh` battery at the repo root after redeploy.
- [ ] `run-all.sh --only` for the four suites mapped to the two edited markdown files.
- [ ] `grep` confirms the `#441` invocation-CWD sentence survives verbatim — this task qualifies
      it, never deletes it.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/verify-deploy.sh` — `TARGET_REPO CONTRACT` header
  paragraph, `TARGET_REPO placeholder` usage subsection, one added gate0 stderr line.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — one-clause
  widening of the existing pointer sentence.
- `agent-system/extensions/core/context/formats/plan-format.md` — corrected `__FULL_SWEEP__`
  sub-case (b) invocation and SKIP-branch claim, plus a cross-reference to the script header.
- `agent-system/extensions/core/index-entries.json` — regenerated line counts.
- Regenerated `.claude/` deploy tree.
- `specs/470_clarify_verify_deploy_target_contract/summaries/01_*-summary.md` at completion.
- Issue-log entries for the foreign-uncommitted-work conditions and the commit-scope decision
  gate's outcome.

## Rollback/Contingency

Every edit in Phases 1-3 is additive and confined to named line regions, so a revert is a targeted
`git checkout`/manual removal of the added lines — not a structural rollback. Because
`verify-deploy.sh` and `index-entries.json` carry **pre-existing foreign uncommitted work**, a
rollback must never use `git checkout -- <path>`, `git restore <path>`, `git reset --hard`, or
`git-snapshot.sh` in its default reverting mode: all of those would discard that foreign work.
Remove the added lines by hand instead, verifying with `git diff` that only this task's hunks
disappear.

If Phase 4's redeploy cannot reach `landed_verify_clean` for reasons traceable to the baseline
staleness rather than to this task's edits, leave the source-store edits in place, report the
deploy failure in the handoff with the differential findings diff as evidence, and mark the task
`[PARTIAL]`. Do not hand-patch `.claude/**` to force a clean verification.
