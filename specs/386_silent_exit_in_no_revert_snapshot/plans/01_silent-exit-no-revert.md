# Implementation Plan: Task #386

- **Task**: 386 - Silent exit in --no-revert git-snapshot.sh
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None (adjacency-only coordination note with the guard-destructive-git.sh / foreign-stash-pop task; no file-territory overlap)
- **Research Inputs**: specs/386_silent_exit_in_no_revert_snapshot/reports/01_silent-exit-no-revert.md
- **Artifacts**: plans/01_silent-exit-no-revert.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`git-snapshot.sh` runs under `set -euo pipefail` and performs four unguarded command
substitutions whose failure aborts the script with no reason on stderr — the underlying git
error having already been discarded by a `2>/dev/null` redirect. Three live in the `--no-revert`
branch (reproducing the originally reported "mode line, then nothing, then exit 1" signature) and
one duplicate pipeline shape lives in default mode, where a silent abort is strictly worse because
it fires *after* `git stash push -u` has already reverted the working tree. This plan brings all
four sites into the script's own already-established `if ! VAR=$(cmd 2>&1); then <named reason>;
exit 1; fi` convention, implements the research's degrade-not-abort ruling for the `--no-revert`
stash pair, structurally removes the SIGPIPE class of failure from the `git stash list | head -1 |
cut` pipelines, and proves all of it with new fixture cases in the existing regression suite.
Definition of done: no command substitution anywhere in the script can abort it without a named
reason on stderr; the success path's stdout report is byte-identical; the out-of-scope guard is
untouched; the deployed tree is regenerated and the full gate set is green.

### Research Integration

The research reproduced the claimed mechanism byte-for-byte (held `.git/index.lock` +
`git stash create`) and found two things the dispatch did not name: a second, independently
triggerable SIGPIPE failure in `STASH_REF=$(git stash list | head -1 | cut -d: -f1)` (reproduced
at ~2000 stash entries; the real repo has 9, so it is latent but monotonically growing since this
script is the sole producer of its own stash entries), and the fact that this exact line is
duplicated verbatim in **default mode**, after the tree has already been reverted. It also ruled
the design question the dispatch posed: a `--no-revert` stash-create failure **degrades to a loud
named warning and continues**, because the `.patch` file (the documented primary durable record)
is already computed and in hand before this point and is a complete substitute for the stash's
tracked-change coverage. Failures with no independent backstop (untracked-file enumeration,
`--branch` mode's original-branch read) stay fatal, gaining only a named reason. All four fixed
sites are confirmed by code reading to sit *after* the out-of-scope guard block in program order,
with no interaction with it.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, so no ROADMAP.md consultation was performed and
this plan asserts no roadmap alignment.

## Goals & Non-Goals

**Goals**:
- Every failure path reachable in `--no-revert` mode emits a named reason on stderr before
  exiting or degrading (acceptance (a), (b)).
- The underlying git stderr text is preserved and reported, not discarded by `2>/dev/null`, so a
  reader can tell transient lock contention from genuine repository damage.
- A `--no-revert` stash-create/stash-list failure degrades to a patch-only snapshot with a loud
  warning rather than throwing away an otherwise fully achievable snapshot.
- The `git stash list | head -1 | cut -d: -f1` SIGPIPE class of failure is removed structurally
  at **both** occurrences (`--no-revert` and default mode), not special-cased by exit status.
- The success path's stdout report stays byte-compatible for its documented consumers
  (acceptance (c)); the out-of-scope refusal guard remains skipped for `--no-revert`
  (acceptance (d)).
- The new behaviour is covered by fixture cases in the existing regression suite, and the
  per-mode failure posture (fatal vs. degrade, and the exit status each yields) is documented in
  the script's own header.

**Non-Goals**:
- Changing the out-of-scope refusal guard in any way. The dispatch establishes the original
  report's conjectured cause is wrong; nothing about that guard needs touching.
- Correcting `context/standards/shell-strict-mode.md`'s "none found unguarded" audit claim,
  which the four fixed sites contradict. Research recommends this as a follow-up, and the
  dispatch scope is `git-snapshot.sh` only.
- The broader `grep -n ... | head -1 | cut` sibling sweep (`lib/plan-status-line.sh:40`,
  `lib/suite-selection-lib.sh:267,269`). Both are sourced libraries whose abort behaviour depends
  on the caller's shell-option state, needing its own targeted audit — explicitly out of scope.
- Pruning accumulated `git-snapshot-*` stash entries, or changing how they are named.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Degrading stash-create failure to a warning masks genuine repository damage, not mere lock contention | M | M | The warning MUST include the underlying git stderr verbatim (captured via `2>&1` instead of discarded), so a caller or log reviewer can distinguish the two even though the script proceeds either way |
| The non-piped `STASH_REF` parse changes behaviour if `git stash list`'s first line ever lacks a colon | M | L | `stash@{N}: <message>` is the stable documented format; the existing `cut -d: -f1` already assumes exactly it. The replacement preserves the identical assumption, just without a pipe. Phase 3 asserts the parsed value against the piped form's output on a known fixture |
| Switching `2>/dev/null` to `2>&1` leaks git stderr into a variable whose value is later printed on stdout, breaking byte-compatibility (acceptance (c)) | H | L | Every new reason/warning line goes to **stderr** only, matching every existing message in this script. Phase 5 diffs the success-path stdout against a pre-change capture to prove byte-identity |
| A fixture that holds `.git/index.lock` leaks a stale lock if the test crashes before cleanup | L | M | Follow the suite's existing `trap cleanup EXIT` convention and release/remove the lock file explicitly before any `rm -rf` of the fixture dir, never relying on directory removal alone |
| A concurrent sibling task edits this file mid-phase (five siblings dispatched this cycle, three with no declared `file_scope`) | M | L | Re-read `git-snapshot.sh` and the test suite immediately before each edit; stage only this task's own hunks with an explicit file list; never run `git-snapshot.sh` in its reverting default mode |
| The SIGPIPE fixture (~2000 `git stash push` calls) is slow enough to make the suite painful | L | M | Build the stash entries with the cheapest form available and cap at the smallest count that reproduces reliably; if wall-clock exceeds roughly a minute, gate that one case behind an opt-in env var and say so in the suite header rather than silently dropping it |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

Phases within the same wave can execute in parallel. This plan is fully sequential: phases 2-4
all edit the same file (`git-snapshot.sh`) in overlapping regions, and phase 1 establishes the
RED the later phases turn green.

### Phase 1: Add Failing Fixture Cases (RED First) [COMPLETED]

**Goal**: Extend the existing regression suite with cases that reproduce the silent-exit
signature and the SIGPIPE signature, demonstrating RED against the unfixed script before any fix
lands.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-git-snapshot.sh` in full
      immediately before editing (concurrency: five sibling tasks are live this cycle). *(completed)*
- [x] Add a case: in a `make_scoped_repo "yes"` fixture, create `.git/index.lock`, run
      `--no-revert` via the existing `run_snapshot` wrapper, and assert the captured output
      contains a **named reason** mentioning the stash step — not merely the mode line followed
      by nothing. Assert exit status 0 and that the patch and marker files were still written
      (this is the degrade-not-abort contract; see the Decisions note below on why this is exit 0
      and not non-zero). *(completed)*
- [x] Release/remove `.git/index.lock` explicitly in that case before the fixture `rm -rf`,
      per the suite's existing `trap cleanup EXIT` convention. *(completed)*
- [x] Add a companion negative control: the same fixture **without** the held lock still
      succeeds, writes a real `stash@{N}` into the marker, and prints the unchanged stdout
      report. *(completed)*
- [x] Add a case exercising the SIGPIPE path directly: push enough scratch stash entries into a
      fixture repo that `git stash list | head -1` closes the pipe early (research reproduced at
      ~2000), then run `--no-revert` and assert a named reason or a successful parse — never
      silence. If this case's wall-clock cost is excessive, gate it behind an opt-in env var and
      document that in the suite header. *(completed: 2000-entry fixture built via `git stash
      create` + `git update-ref --create-reflog`, ~12s wall-clock, well under the 1-minute
      threshold so no env-var gate was needed)*
- [x] Run the suite and record the observed RED: which cases fail and with what output. A
      demonstrated RED is this phase's deliverable (the suite's own header documents this
      convention for its existing cases). *(completed: held-index.lock case and SIGPIPE case both
      FAIL with exit=1 and output='git-snapshot.sh: --no-revert mode -- the working tree will NOT
      be modified.' -- the exact reported silent-exit signature. 5 passed, 2 failed.)*
- [x] Use no task-number references anywhere in the added code or comments; cite the report by
      filename only, as the suite's existing header already does. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly one file is touched
(`tests/test-git-snapshot.sh`) and that ~2000 stash entries are the threshold at which the
SIGPIPE case reproduces. Confirm at implementation time by running the new case and checking it
actually fails (or passes) for the stated reason, and by lowering the count until it stops
reproducing rather than accepting 2000 on faith.

**Tier Justification**: The edit is confined to one test file with no externally visible
signature, and `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-snapshot.sh`
is the suite that `suite_selection_select` resolves for this path and is therefore the exact
covering check.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-snapshot.sh` - add the held-`index.lock`
  silent-exit case, its unlocked negative control, and the large-stash-list SIGPIPE case, reusing
  the existing `make_scoped_repo` / `run_snapshot` / `pass` / `fail` helpers

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-snapshot.sh` runs
  and the pre-existing cases still pass.
- The new cases FAIL against the unfixed script, and their failure text shows the silence being
  tested for (mode line, then nothing) rather than an unrelated fixture error.
- `bash -n` parses the suite cleanly; `shellcheck` reports no new findings on it.

---

### Phase 2: Guard the Three `--no-revert` Substitutions [COMPLETED]

**Goal**: Make every command substitution in the `--no-revert` branch report a named reason,
with the stash pair degrading to a warning and the untracked-file enumeration staying fatal.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/git-snapshot.sh` immediately before editing. *(completed)*
- [x] Replace `STASH_SHA=$(git stash create "..." 2>/dev/null)` with an explicit
      `if ! STASH_SHA=$(git stash create "..." 2>&1); then ...` form that prints a named
      `WARNING` on **stderr** including the captured git stderr text, then sets `STASH_SHA=""`
      and falls through. Do **not** `exit 1` on this path. *(completed)*
- [x] Preserve the existing empty-output semantics: `git stash create` printing nothing on a
      tracked-clean tree is a success, already handled by `[ -n "$STASH_SHA" ]`. The new guard
      must not turn that case into a warning. *(completed: the `if !` only fires on a nonzero
      exit status, not on empty-but-successful output)*
- [x] Give the `STASH_REF` read inside the `[ -n "$STASH_SHA" ]` block the same
      degrade-with-warning treatment (its structural rewrite lands in Phase 3; this phase only
      ensures it cannot abort silently in the interim). *(completed)*
- [x] Replace `UNTRACKED_LIST=$(git ls-files --others --exclude-standard 2>/dev/null)` with an
      explicit success check that stays **fatal** — printing a named reason plus the captured git
      stderr, `rm -f "$PATCH_TMP"`, and `exit 1`, matching the `mkdir -p`/`cp -p` loop's existing
      fatal-with-reason convention two lines below it. *(completed)*
- [x] Confirm by reading that the out-of-scope guard block is untouched and still gated on
      `[ "$MODE" != "no-revert" ]` (acceptance (d)). *(completed: confirmed unchanged at its
      original line, still gated identically)*
- [x] Keep every new message on stderr; change no stdout line (acceptance (c)). *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly three substitution sites exist in the
`--no-revert` branch. Confirm at implementation time by re-running the research's sweep query
(`grep -nE '^\s*[A-Za-z_]+=\$\(.*git .*\)'` over the script) and checking the matches inside the
`elif [ "$MODE" = "no-revert" ]` block against that count rather than trusting the report's line
numbers, which drift as edits land.

**Tier Justification**: The edit is confined to one script with no change to any externally
visible interface (same flags, same stdout contract), and `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-snapshot.sh`
is the suite `suite_selection_select` resolves for this path and the one that exercises the edited
branch end to end.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-snapshot.sh` - guard the `git stash create`,
  interim `STASH_REF`, and `git ls-files --others` substitutions in the `--no-revert` branch;
  `2>&1`-capture instead of `2>/dev/null`-discard; warning-and-continue for the stash pair,
  fatal-with-reason for the untracked enumeration

**Verification**:
- `bash -n` parses the script; `shellcheck` reports no new findings.
- Phase 1's held-`index.lock` case now PASSES: a named warning appears on stderr, exit is 0, and
  patch plus marker are written.
- Phase 1's unlocked negative control still PASSES with a real `stash@{N}` recorded.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-snapshot.sh` shows
  no regression in the pre-existing out-of-scope-guard cases.
- A manual `--no-revert` run on a dirty scratch repo produces stdout byte-identical to a
  pre-change capture of the same run.

---

### Phase 3: Remove the SIGPIPE Pipeline at Both Sites; Guard `--branch` [COMPLETED]

**Goal**: Replace both `git stash list | head -1 | cut -d: -f1` pipelines with a non-piped
capture plus pure-bash parse, structurally eliminating the SIGPIPE failure class, and give
`--branch` mode's `ORIGINAL_BRANCH` read a named reason.

**Tasks**:
- [x] Re-read `git-snapshot.sh` immediately before editing (Phase 2 just changed it). *(completed)*
- [x] Replace the `--no-revert` branch's `STASH_REF=$(git stash list | head -1 | cut -d: -f1)`
      with an explicit-success capture of the full `git stash list` output into a variable
      (`2>&1`, checked), then take the first line and the text before its first colon via pure
      parameter expansion (`${var%%$'\n'*}`, `${first%%:*}`) — no pipe, so no subprocess can be
      SIGPIPE'd. On failure, warn with a named reason and leave `STASH_REF="NONE"`. *(completed:
      factored into a shared `resolve_latest_stash_ref()` function, reused at both sites)*
- [x] Apply the identical replacement to the duplicate in **default mode**, where this line runs
      after `git stash push -u` has already reverted the tree. A failure there MUST still reach
      the patch/marker write with `STASH_REF="NONE"` and a named reason rather than aborting
      silently and leaving the caller with a reverted tree, no patch, and no explanation.
      *(completed)*
- [x] Wrap `ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)` in `--branch` mode in
      an explicit success check that stays **fatal** with a named reason plus captured git
      stderr, consistent with that mode's existing all-fatal posture (without a known original
      branch the script cannot safely return to it). *(completed)*
- [x] Re-run the sweep query over the whole script and confirm zero remaining bare git-command
      substitutions in any mode (acceptance (b), extended beyond `--no-revert`). *(completed: only
      remaining hit is `HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")`, which
      already has its own `||` fallback and cannot abort; no fix needed there)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the `git stash list | head -1 | cut` pipeline appears at
exactly two sites and that `ORIGINAL_BRANCH` is the only remaining unguarded substitution.
Confirm at implementation time with `grep -nE 'git stash list' agent-system/extensions/core/scripts/git-snapshot.sh`
plus a re-run of the sweep query, counting matches rather than trusting this number.

**Tier Justification**: Still one script, no interface change — and the structural parse
replacement is directly exercised by the new SIGPIPE case plus the existing default-mode cases in
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-snapshot.sh`, the
suite `suite_selection_select` resolves for this path.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-snapshot.sh` - replace both `git stash list | head -1
  | cut -d: -f1` pipelines with non-piped capture plus bash parsing; guard `--branch` mode's
  `ORIGINAL_BRANCH` read with a named fatal reason

**Verification**:
- `bash -n` and `shellcheck` clean.
- Phase 1's SIGPIPE case PASSES: the large-stash-list fixture yields a correctly parsed
  `stash@{N}` (or a named reason), never silence.
- The parsed `STASH_REF` value on a known fixture equals what the old piped form produced on the
  same fixture — verified explicitly, not assumed.
- Default-mode cases in the existing suite still pass, including the negative control that
  asserts a reverted tree plus a written marker.
- The sweep query returns no unguarded bare git-command substitution anywhere in the script.

---

### Phase 4: Document the Per-Mode Failure Posture in the Script Header [COMPLETED]

**Goal**: Make the exit status and failure posture of each mode readable from the script's own
header, satisfying acceptance (a)'s "documented exit status" clause.

**Tasks**:
- [x] Re-read the script header immediately before editing. *(completed)*
- [x] Extend the header's existing closing paragraph ("On any failure, this script exits non-zero
      with a clear message...") into an explicit per-case statement: which failures are fatal
      (exit 1, named reason on stderr) and which degrade (exit 0, named `WARNING` on stderr,
      patch and marker still written, `STASH_REF=NONE`). *(completed)*
- [x] State plainly that a `--no-revert` stash-create or stash-list failure is **not** fatal
      because the `.patch` file is the primary durable record and is already written, and that
      the underlying git stderr is reported verbatim so a reader can distinguish transient lock
      contention from repository damage. *(completed)*
- [x] Confirm the stdout report contract paragraph still accurately describes the (unchanged)
      stdout lines, and that no new stdout line was introduced by Phases 2-3. *(completed:
      re-verified by the byte-identical stdout diff already captured in Phase 3)*
- [x] Add no task-number reference anywhere in the header. *(completed, confirmed by grep)*

**Timing**: 0.25 hours

**Depends on**: 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Tier Justification**: Every changed hunk lies inside a `#` comment block in a shell script with
zero executable surface, and the diff read-through the `prose` tier prescribes is paired with
`bash -n` plus `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(doc-lint and task-reference lint on the source store, with the target named explicitly because
the no-argument form would default to the consumer root and silently SKIP both gates).

**Files to modify**:
- `agent-system/extensions/core/scripts/git-snapshot.sh` - header comment only: per-mode failure
  posture and exit statuses

**Verification**:
- Diff read-through confirms every changed line is inside the leading comment block; no
  executable line is touched.
- `bash -n` still parses; the full suite still passes.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is green (neither gate reports SKIP-only).
- `grep -nE '[Tt]ask [0-9]' agent-system/extensions/core/scripts/git-snapshot.sh` finds no new
  task-number reference.

---

### Phase 5: Redeploy and Full Gate Set [COMPLETED WITH EXCLUSIONS]

**Goal**: Regenerate the deployed `.claude/` tree from the source store and prove the whole
change set green against the complete gate set, with every acceptance criterion walked
explicitly.

**Tasks**:
- [x] Re-read every file this task modified and confirm the working tree contains only this
      task's own hunks in them (five sibling tasks are live this cycle; a foreign modification or
      a foreign commit in these files is a STOP-and-report condition, after checking `git log` to
      confirm the work is not this task's own). *(completed: `git diff --stat` on both modified
      files against HEAD was empty before Phase 5 began -- both already committed with no foreign
      content; `git log --oneline -5` on both files showed only this task's own four prior phase
      commits)*
- [x] Redeploy: `timeout 540 bash .claude/scripts/deploy-headless.sh` (Bash tool `timeout`
      parameter raised to 600000, per the bounded-wait idiom). The dispatch's deploy-freshness
      context already reports `core` and `lean` stale, so this redeploy is required regardless.
      *(completed, twice: once to land Phases 1-4's edits, and once more after a shellcheck
      fixture fix discovered during this phase -- see deviations)*
- [x] Confirm the deployed `.claude/scripts/git-snapshot.sh` now matches the source-store copy
      (`diff` them) — never hand-patch the deployed file. *(completed: `diff` reports both
      `git-snapshot.sh` and `tests/test-git-snapshot.sh` byte-identical, deployed vs. source-store)*
- [x] Run the full gate set: `bash .claude/scripts/verify-deploy.sh` from the repo root (which is
      the source-store host here, so the source-store gates apply rather than SKIP). *(completed
      with recorded exclusions -- see Reasoned Exclusions below; every gate not listed there
      PASSED, including the shellcheck lint gate across all 375 scanned files after a fix found
      during this phase)*
- [x] Run the full shell suite: `bash agent-system/extensions/core/scripts/tests/run-all.sh`.
      *(completed via narrow substitution -- see Reasoned Exclusions below)*
- [x] Walk each acceptance criterion and record the evidence for it: (a) held-`index.lock`
      fixture shows a named reason and the documented exit status, not silence; (b) no command
      substitution in the `--no-revert` branch can abort without a reason line; (c) success-path
      stdout is byte-compatible with a pre-change capture; (d) the out-of-scope guard is still
      skipped for `--no-revert`. *(completed -- see Acceptance Criteria Evidence below)*
- [x] Note in the completion summary the two deliberately deferred follow-ups: the
      `shell-strict-mode.md` "none found unguarded" audit correction, and the sibling
      `grep | head | cut` sweep in `lib/plan-status-line.sh` and `lib/suite-selection-lib.sh`.
      *(completed, see summary)*

#### Deviations

- A `shellcheck` finding (SC2164: `cd` without `|| exit`) was discovered in this task's own new
  Phase 1 fixture code (the SIGPIPE-fixture subshell) during this phase's full gate run, not
  caught earlier because Phase 1's own verification ran `shellcheck` on the file in isolation
  before this specific line existed in its final form, and Phase 2-4's `shellcheck` checks were
  re-run against `git-snapshot.sh` only, not the test file. Fixed in this phase (`cd
  "$sigpipe_repo" || exit 1`), reverified standalone (`shellcheck -S warning`, exit 0) and via a
  second full 375-file sweep (0 findings), and redeployed. The regression suite was re-run after
  the fix: still 7 passed, 0 failed.
- A stray, gitignored runtime file (`.claude/tmp/stash-pre-<this-session-id>`) was flagged by the
  orphan-detection gate during this phase, created by sibling task 382's `guard-destructive-git.sh`
  hook intercepting this task's own `git stash`-containing Bash calls during SIGPIPE-fixture
  testing (see `issues.jsonl` for the full root-cause note). Deleted as routine gitignored-runtime
  cleanup, outside this task's or task 382's declared `file_scope` and not a tracked deliverable;
  the gate passed clean after deletion.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `verify-deploy.sh` gate: full shell test suite runner (`tests/run-all.sh`, no filter) | `test-zotero-generate-export.sh` (literature extension) hangs indefinitely and blocks any unfiltered `run-all.sh`/gate-8 run; a separate task already tracks this hang. Not caused by, or fixable within, this task's file_scope (`git-snapshot.sh`, its test file). | Dispatch's own stated known-pre-existing-obstruction list names this exact hang. Narrow substitution run instead: `run-all.sh --only test-git-snapshot.sh` -> 1 passed, 0 failed; `run-all.sh --only test-guard-destructive-git.sh` (sibling task 382's suite, which drives `git-snapshot.sh` as a real subprocess per the dispatch's coupling note) -> 1 passed, 0 failed. |
| `verify-deploy.sh` gate: doc-lint (`check-extension-docs.sh`) | The gate's aggregate FAIL comes entirely from the `lean` extension (a doc-lint fixture registration gap, `Rule S` finding on `measurement-harness-strictness.md`, plus two `provides.scripts` mismatches under `scripts/tests/fixtures/challenge/`) and from `lean`'s own stale-deploy drift lines for sibling in-flight tasks. The `[core]` extension's own section reports `OK` (only an advisory `README.md older than manifest.json` WARN, pre-existing and non-blocking). Neither `git-snapshot.sh` nor its test file appears in any FAIL line. | Direct `bash .claude/scripts/check-extension-docs.sh` run (non-`--quiet`) after the final redeploy: `[core]` section prints `WARN: README.md older than manifest.json (possible drift)` then `OK`; every `FAIL:` line in the output is under the `[lean]` / `project-wide` sections. Dispatch names this lean doc-lint gap as a known, already-excluded-by-siblings obstruction. |
| `verify-deploy.sh` gate: orchestrator context budget lock (`measure-eager-context.sh`) | The eager-load total (67088 B) exceeds the recorded baseline (66100 B) by 988 B. Neither modified file (`git-snapshot.sh`, `tests/test-git-snapshot.sh`) is an eager-loaded context file (`commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`) or referenced by one; this task touched no file this gate measures. Per-file ceilings for both named files report `PASS` (`within ceiling`). | Gate output: `[PASS] commands/orchestrate.md (20971 B) within ceiling (21000 B)`; `[PASS] skills/skill-orchestrate/SKILL.md (22335 B) within ceiling (22500 B)`; only the aggregate-total line FAILs, from cumulative growth attributable to this batch's other sibling tasks (the dispatch names this exact gate as already excluded by siblings this cycle). |

#### Acceptance Criteria Evidence

- **(a)** Held-`.git/index.lock` fixture case in `test-git-snapshot.sh` PASSES: exit 0, stderr
  carries `WARNING -- git stash create failed in --no-revert mode; degrading to a patch-only
  snapshot...` plus the captured `git said: ...` line, and both the `.patch` file and
  `.git-snapshot-marker` (with `STASH_REF=NONE`) are written. The exit status for this case is
  documented in the script's own header (Phase 4): DEGRADE, exit 0.
- **(b)** Sweep query (`grep -nE '^\s*[A-Za-z_]+=\$\(.*git .*\)'`) over the final script finds
  exactly one hit, `HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")`, which already
  has its own `||` fallback and cannot abort the script. All four originally-unguarded sites
  (three in `--no-revert`, one duplicated in default mode) are guarded; both SIGPIPE-prone
  `git stash list | head -1 | cut -d: -f1` pipelines are structurally replaced by
  `resolve_latest_stash_ref()` (no pipe, no subprocess to SIGPIPE). The full regression suite's
  SIGPIPE case (2000 pre-existing stash entries) PASSES.
- **(c)** A byte-for-byte diff of the success-path stdout (modulo the timestamp embedded in the
  patch filename) between the pre-Phase-2 script and the final script, run against an identical
  fixture, is empty (captured in Phase 3, re-confirmed unaffected by Phases 4-5's comment-only
  and redeploy-only changes).
- **(d)** Read-confirmed: the out-of-scope refusal guard block's gating condition
  (`if [ "$MODE" != "no-revert" ] && [ "$ALLOW_OUT_OF_SCOPE" -ne 1 ]`) is byte-identical to its
  pre-change form. `test-git-snapshot.sh`'s pre-existing `--no-revert: never guarded` case PASSES
  in the final 7/7-green suite run.

**Timing**: 0.5 hours

**Depends on**: 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that exactly two files were modified across the whole
task (`git-snapshot.sh` and `test-git-snapshot.sh`) plus the regenerated deploy artifacts.
Confirm with `git status --short` before committing, and treat any third source-store file as
either scope creep to justify or a sibling's edit to leave alone.

**Files to modify**:
- `.claude/` (regenerated by `deploy-headless.sh`; never hand-authored) - redeploy only, no
  hand-edits

**Verification**:
- `timeout 540 bash .claude/scripts/deploy-headless.sh` completes successfully and the deployed
  `git-snapshot.sh` is byte-identical to the source-store copy.
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set it aggregates, no `--skip-slow`,
  no `--only-gate` filter) is green.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` is green, including every case
  added in Phase 1.
- All four acceptance criteria are walked with recorded evidence, not asserted.

---

## Decisions

- **The held-`index.lock` fixture asserts exit 0, not a non-zero status.** The research report is
  internally inconsistent here: its Decisions section rules that a `--no-revert` stash-create
  failure degrades to a warning and continues, while its Recommendation 4 then specifies the
  fixture should assert "a non-zero, documented exit status". The two cannot both hold. This plan
  follows the Decisions ruling — the degrade is the substantive design choice, reasoned from the
  `.patch` file already being in hand — and reads acceptance (a)'s "documented exit status" as
  satisfied by Phase 4 documenting that status in the script header, not as a requirement that it
  be non-zero. Recorded in `issues.jsonl`.
- **Default mode's duplicate pipeline is in scope** even though the dispatch's stated goal names
  `--no-revert` mode. The dispatch scope is the file, and the dispatch itself asks research to
  "sweep for the same unguarded-substitution shape in the script's other modes"; the default-mode
  instance is both the same shape and strictly more damaging (it aborts after the tree is already
  reverted).
- **RED-first ordering (Phase 1 before any fix)** rather than fix-then-test, matching the existing
  suite's own documented convention that a demonstrated RED is a deliverable.

## Testing & Validation

- [ ] Held-`index.lock` `--no-revert` fixture: named reason on stderr, exit 0, patch and marker
      written, `STASH_REF=NONE` in the marker.
- [ ] Unlocked `--no-revert` negative control on the same fixture: exit 0, real `stash@{N}` in the
      marker, stdout report unchanged.
- [ ] Large-stash-list fixture: `STASH_REF` parses correctly with no SIGPIPE abort and no silence.
- [ ] Default-mode cases (existing out-of-scope refusal, negative control) unregressed.
- [ ] `--no-revert` on an out-of-scope dirty tree still exits 0 and leaves the tree exactly as
      found (acceptance (d), already covered by the suite's existing case).
- [ ] Success-path stdout diffed byte-for-byte against a pre-change capture (acceptance (c)).
- [ ] Sweep query finds no unguarded bare git-command substitution anywhere in the script.
- [ ] `bash -n` and `shellcheck` clean on both modified files.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` fully green.
- [ ] `bash .claude/scripts/verify-deploy.sh` fully green after redeploy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/git-snapshot.sh` - four substitution sites guarded, both
  SIGPIPE-prone pipelines structurally replaced, header documenting the per-mode failure posture
- `agent-system/extensions/core/scripts/tests/test-git-snapshot.sh` - new silent-exit,
  negative-control, and SIGPIPE fixture cases
- Regenerated `.claude/` deploy artifacts (produced by `deploy-headless.sh`, never hand-authored)
- `specs/386_silent_exit_in_no_revert_snapshot/summaries/01_silent-exit-no-revert-summary.md` -
  completion summary, including the two deferred follow-up items

## Rollback/Contingency

All work is confined to two source-store files plus a regenerable deploy tree, so the ordinary
contingency is to fix forward: correct the source and redeploy. If a phase's edit must actually be
undone, revert that phase's commit (`git revert <sha>`) and redeploy — this leaves the working
tree intact and needs no snapshot.

If a genuine working-tree rollback is ever required (an edit must be discarded before it was
committed), take a snapshot first per `context/contracts/recovery.md`'s rollback rung, which
specifies the exact invocation shape including its out-of-scope override flag; do not emit a bare
`git-snapshot.sh` call as a routine precaution. For an ordinary defensive checkpoint before a
risky edit in this task, use the non-reverting `--no-revert` form instead — noting the irony that
this task is fixing that very mode, so until Phase 2 lands a silent exit from it is possible and a
checkpoint that prints only its mode line and nothing else must be treated as having failed.
