# Research Report: Task #386

**Task**: 386 - Silent exit in --no-revert git-snapshot.sh
**Started**: 2026-10-14T00:00:00Z
**Completed**: 2026-10-14T00:00:00Z
**Effort**: small (single-script, well-bounded fix)
**Dependencies**: None (adjacency-only coordination note with a separate not-started task; see Decisions)
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/git-snapshot.sh` (source-store copy; edit target)
- `agent-system/extensions/core/scripts/tests/test-git-snapshot.sh` (existing regression suite)
- `agent-system/extensions/core/context/standards/shell-strict-mode.md`
- `agent-system/extensions/core/context/patterns/checkpoint-before-overflow.md`
- Live reproduction in a scratch `mktemp -d` git repo (held `.git/index.lock`, large stash-list fixture)
- Repo-wide grep sweep for the same unguarded-substitution shape
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's claimed mechanism is confirmed by direct reproduction: `git-snapshot.sh`'s
  `--no-revert` branch runs three unguarded command substitutions under `set -euo pipefail`
  (`STASH_SHA=$(git stash create ... 2>/dev/null)` at line 464, `STASH_REF=$(git stash list |
  head -1 | cut -d: -f1)` at line 471, and `UNTRACKED_LIST=$(git ls-files --others
  --exclude-standard 2>/dev/null)` at line 479). A failing `git stash create` under a held
  `.git/index.lock` reproduces the exact observed signature byte-for-byte: the mode line prints,
  then nothing, then `exit 1`.
- A **second, independently-triggerable failure mode** in the identical pipeline shape was found
  and reproduced: `STASH_REF=$(git stash list | head -1 | cut -d: -f1)` is SIGPIPE-prone once
  `git stash list` has enough entries that `head -1` closes the pipe early (reproduced reliably
  at ~2000 entries; the real repo currently has 9, so this is latent, not yet live, but grows
  over time as this script is the sole stash-entry producer in its own convention). This exact
  line is duplicated verbatim in **default mode** (line 501) — meaning default mode can also
  die silently, and worse: it dies *after* `git stash push -u` has already reverted the tree,
  so the caller is left with a reverted tree, no patch, no marker, and no explanation.
- A fourth unguarded instance exists in `--branch` mode: `ORIGINAL_BRANCH=$(git rev-parse
  --abbrev-ref HEAD 2>/dev/null)` (line 442). Lower real-world risk (`rev-parse` does not need
  the index lock) but the same shape.
- A repo-wide sweep found no other git-command instances of this specific shape outside
  `git-snapshot.sh` itself; a related-but-distinct hazard (`grep -n ... | head -1 | cut`, which
  can fail via `grep`'s own no-match exit status under `pipefail`) exists in a few sibling files,
  some already guarded with `|| true`, two not (`lib/plan-status-line.sh:40`,
  `lib/suite-selection-lib.sh:267,269`) — flagged for a future, separate sweep; out of this
  task's scope (dispatch scope is `git-snapshot.sh` only).
- `context/standards/shell-strict-mode.md`'s own Class A migration audit explicitly asserts, for
  the population including `scripts/git-snapshot.sh`, "None found unguarded ... every
  conditional read is already inside `if`/`||`/`&&`, or reads via `2>/dev/null || true` /
  `2>/dev/null || echo <default>`." This claim is contradicted by the four unguarded sites above
  and should be corrected once the fix lands (see Decisions).
- Recommended fix shape: wrap each of the four substitutions in an explicit success check that
  captures the command's own stderr (replacing the `2>/dev/null` that currently discards it) and
  emits a named reason + the standard `exit 1` the rest of the script already uses — except the
  stash-create/stash-list pair in `--no-revert` mode, which should **degrade to a loud warning
  and keep going** rather than abort, because the `.patch` file (computed and already in hand
  before this point) is a complete substitute for the stash's tracked-change coverage.

## Context & Scope

Scope is `extensions/core/scripts/git-snapshot.sh` only (source store; this repo's deployed
`.claude/scripts/git-snapshot.sh` is a disposable regenerated copy per
`rules/source-store-deploy-boundary.md` and must not be hand-edited). The task explicitly
pre-empts one wrong hypothesis (the out-of-scope refusal guard) and supplies the correct one
(unguarded command substitutions under `set -e`); this research's job was to verify that
mechanism by direct reproduction, sweep for sibling instances of the same shape (in this script's
other modes, and in other scripts), and resolve the one open design question the dispatch poses:
whether a stash-create failure in `--no-revert` mode should be fatal or should degrade to a
patch-only snapshot.

## Findings

### Codebase Patterns

**The script's own existing convention for failure already does the right thing everywhere
else.** Every other explicit `exit 1` in `git-snapshot.sh` is preceded by an `if ! cmd; then echo
"git-snapshot.sh: <specific reason>" >&2; ...; exit 1; fi` pattern (e.g. the `git diff HEAD`
capture at lines 418-422, the `git checkout -b`/`git add -A && git commit`/`git checkout` calls
in `--branch` mode at lines 445-457, the `git stash push -u` call in default mode at line
496-500, and the untracked-file `mkdir -p`/`cp -p` loop at lines 482-489). The fix for this task
is to bring the four exception sites below into that same, already-established convention — not
to invent a new error-handling idiom.

**The four unguarded sites** (grep-confirmed exhaustive within this script; see Appendix for the
query):

| Line | Mode | Code | Risk confirmed |
|------|------|------|----------------|
| 442 | `--branch` | `ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)` | shape-only; `rev-parse` does not need `.git/index.lock` |
| 464 | `--no-revert` | `STASH_SHA=$(git stash create "..." 2>/dev/null)` | **reproduced**: fails under held `.git/index.lock` |
| 471 | `--no-revert` | `STASH_REF=$(git stash list \| head -1 \| cut -d: -f1)` | **reproduced**: SIGPIPE-prone once stash-list output exceeds the pipe buffer (reliably reproduced at ~2000 entries) |
| 479 | `--no-revert` | `UNTRACKED_LIST=$(git ls-files --others --exclude-standard 2>/dev/null)` | shape-only; `ls-files` does not need `.git/index.lock` |
| 501 | default | `STASH_REF=$(git stash list \| head -1 \| cut -d: -f1)` | **same SIGPIPE risk as line 471**, but strictly worse: this runs *after* `git stash push -u` has already reverted the tree (line 496), so a silent abort here leaves the caller with a reverted tree, no patch written yet (the `mv "$PATCH_TMP" "$PATCH_PATH"` at line 507 hasn't run), and no stderr explanation at all. |

**Reproduction 1 — exact reported signature** (held `.git/index.lock`, mirroring a concurrent git
process in the same repo):

```
$ touch .git/index.lock
$ ./minimal-repro.sh   # set -euo pipefail; mode-line echo; STASH_SHA=$(git stash create ... 2>/dev/null)
git-snapshot.sh: --no-revert mode -- the working tree will NOT be modified.
$ echo $?
1
```
No further output. `git stash create`'s own stderr (`error: Unable to create '.../.git/index.lock':
File exists. Another git process seems to be running in this repository...`) is real and
informative but is discarded by the `2>/dev/null` before `set -e` ever gets a chance to report
it. This is byte-for-byte the originally reported symptom.

**Reproduction 2 — SIGPIPE on the `head -1 | cut` pipeline** (confirms a second, independent
failure mode sharing the identical unguarded-substitution shape):
```
$ for i in $(seq 1 2000); do echo "x$i" >> f.txt; git stash push -q -m "entry-$i" -- f.txt; done
$ bash -c 'set -o pipefail; git stash list | head -1 | cut -d: -f1; echo "exit=$?"'
stash@{0}
exit=1
```
Isolated further: `git stash list` alone (unpiped) exits 0; piped into `head -1`, `PIPESTATUS`
shows `1 0` — `git stash list` itself receives the nonzero/EPIPE-driven status once `head`
closes the read end early. The real repository currently has 9 stash entries (`git stash list |
wc -l`), below the threshold observed in the fixture, so this is a **latent**, not yet live, risk
in production — but one that grows monotonically, since `git-snapshot.sh` is the sole producer
of its own `git-snapshot-{task}-{ts}`-named stash entries and nothing in the codebase currently
prunes them.

**Verified NOT a cause** (per the dispatch, independently re-confirmed): an untracked-only dirty
tree produces an empty `git stash create` stdout and exit 0; `[ -n "$STASH_SHA" ]` at line 465
already handles that correctly.

### External Resources

Not applicable — this is a pure shell/git semantics question (`set -e` + command substitution +
`pipefail`), not a library/API question. No web research was needed or performed; all findings
are from direct reproduction against this repository's own git version and from reading the
script and its sibling test suite.

### Existing Test Coverage

`agent-system/extensions/core/scripts/tests/test-git-snapshot.sh` (200 lines) is entirely focused
on the out-of-scope refusal guard (default mode refuses/preserves an out-of-scope tracked file;
negative control; `--no-revert` is never guarded). It establishes a reusable fixture helper
(`make_scoped_repo`), a `run_snapshot` wrapper that captures combined stdout+stderr and exit
code, and the `pass`/`fail`/`info` + `PASSED`/`FAILED` counter convention this file's own header
cites from `shell-script-testing.md`. **It has zero coverage of the silent-exit failure mode**
this task addresses — acceptance criterion (a)'s fixture (a held `.git/index.lock`) needs to be
added as a new case in this same suite, following the established `make_scoped_repo` +
`run_snapshot` pattern.

### Documentation Discrepancy

`agent-system/extensions/core/context/standards/shell-strict-mode.md`'s "Class A candidates —
ordinary scripts (individually audited)" section states, for the population it lists
(`scripts/git-snapshot.sh` among them, under "Phase 7 remainder (core)"): *"`-e`-hostile
constructs checked for each: bare non-`if`-guarded command chains, functions whose nonzero return
is a meaningful signal, and `grep`/`jq` calls whose empty/no-match result is a normal outcome.
None found unguarded in the scripts below — every conditional read is already inside
`if`/`||`/`&&`, or reads via `2>/dev/null || true` / `2>/dev/null || echo <default>`."* This is
contradicted by the four sites in the table above, each of which is a bare, non-`if`-guarded
command substitution with a plain `2>/dev/null` and no `|| true`/`|| echo` fallback — exactly the
construct the audit's own admission test says it checked for. This is a documentation-accuracy
issue in a standards file, not a behavioral bug in its own right, but it is worth a follow-up
correction once this task's fix lands (the corrected doc should record that `git-snapshot.sh` was
re-audited and the four sites fixed, rather than silently leaving the old "none found" claim in
place for a reader to rely on).

### Sibling-Script Sweep

Grep sweep across `agent-system/extensions/core/scripts/**/*.sh` for
`^\s*[A-Za-z_]+=\$\(.*git .*\)` (command substitutions assigning from a command that invokes
`git`, with or without a pipe) found matches **only** in `git-snapshot.sh` (the four sites above)
and one already-safe instance in `migrate-directory-padding.sh:71`
(`PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)` — has an explicit `|| pwd`
fallback, so `set -e` never sees a nonzero status). No other script in this extension shares the
exact "bare git-command substitution, no fallback" shape.

A **related but distinct** hazard exists more broadly: `grep -n PATTERN FILE | head -1 | cut
-d: -f1` pipelines, where `grep`'s own exit status is 1 whenever PATTERN has no match (a normal,
expected outcome in several of these call sites, not an error). Under `pipefail`, that 1
propagates through `head`/`cut` to the assignment exactly as `git stash list`'s SIGPIPE does
above. Most instances found are already guarded with a trailing `|| true`
(`update-phase-status.sh:217`, `update-plan-status.sh:78`, `deploy-headless.sh:414`), but two are
not: `lib/plan-status-line.sh:40` and `lib/suite-selection-lib.sh:267,269`. Both are **sourced
library functions**, not top-level scripts with their own `set -e`/`pipefail`, so whether a
no-match `grep` there actually aborts depends on the *calling* script's shell-option state at the
call site — this needs its own targeted audit, not a guess, and is explicitly **out of this
task's scope** (dispatch scope is `git-snapshot.sh` only). Flagging it here as a candidate for a
future, separate task.

## Decisions

- **Fatal vs. degrade for `--no-revert` mode's stash-create/stash-list pair (lines 464-472)**:
  **degrade to a loud, named warning on stderr and continue**, rather than abort. Rationale: by
  the time this code runs, `PATCH_TMP` (the full `git diff HEAD` output) has already been
  computed successfully (lines 417-422) and is held in a temp file awaiting the move to
  `PATCH_PATH`. The header comment's own "belt-and-suspenders" framing (`.patch` is "the primary
  durable record"; the no-revert stash is a secondary recovery handle for *tracked* changes only
  — it never covers untracked files, which are backed up separately) means the patch is already
  a complete substitute for whatever the stash step would have added for tracked changes. Keeping
  the script fatal here would mean a transient, often very short-lived lock contention (another
  session's git process) throws away a snapshot opportunity that was otherwise fully achievable.
  The fix should: set `STASH_SHA=""`/`STASH_REF="NONE"` on failure (the existing downstream `[ -n
  "$STASH_SHA" ]` / `[ "$STASH_REF" = "NONE" ]` logic already handles both empty states
  correctly), print a named reason including the underlying git stderr, and proceed to the
  untracked-backup step and the patch/marker write exactly as today's empty-stash-create case
  already does.
- **Fatal for the untracked-file listing failure (line 479)**: stays fatal (as today), but with a
  named reason now reported. Rationale: unlike the stash, there is no independent capture of
  untracked content elsewhere in the script — if `git ls-files --others` itself cannot be trusted
  to enumerate what exists, proceeding silently risks skipping real untracked data with no
  record anywhere. This matches the existing `mkdir -p`/`cp -p` loop's own fatal-with-reason
  convention two lines further down (lines 485-489), so the fix is purely additive (name the
  reason), not a behavior change.
- **Fatal for `--branch` mode's `ORIGINAL_BRANCH` (line 442)**: stays fatal, with a named reason
  added. Rationale: every other command in `--branch` mode (`checkout -b`, `add -A && commit`,
  `checkout` back) is already fatal-with-reason on failure; without a known original branch the
  script cannot safely return to it after the WIP commit, so this is consistent with the mode's
  existing all-fatal posture, not a new design choice.
- **Fix structurally removes the SIGPIPE risk rather than papering over it**: replace `git stash
  list | head -1 | cut -d: -f1` (both occurrences, lines 471 and 501) with a capture-then-parse
  form that never pipes `git stash list`'s potentially-large output into a short-reading
  consumer — e.g. capture the full `git stash list` output into a variable with an explicit
  success check, then take the first line and the text before its first colon via pure bash
  parameter expansion (`${var%%$'\n'*}`, `${first_line%%:*}`), which cannot SIGPIPE a subprocess
  because there is no pipe. This removes the latent risk in default mode (line 501) and the
  reproduced risk in `--no-revert` mode (line 471) in the same stroke, and is a smaller,
  lower-risk change than trying to special-case SIGPIPE's exit status.
- **Success-path stdout stays byte-compatible** (acceptance criterion (c)): all of the fix's new
  reason-reporting and warning text belongs on **stderr**, matching every existing message in
  this script (the pre-op mode-line warnings at lines 430-439 and the post-op notices at lines
  529-540 are already stderr-only for exactly this reason, per the inline comment at lines
  428-429). The stdout lines consumed by `checkpoint-before-overflow.md` and the agent handoff
  steps (`snapshot complete` / `patch:` / `stash:` / `branch:` / `marker:`) are untouched by this
  fix.
- **Out-of-scope guard is untouched** (acceptance criterion (d)): confirmed by direct code
  reading that the guard block (lines 327-406) is gated on `[ "$MODE" != "no-revert" ]` and
  has no interaction with any of the four sites being fixed, all of which live after the guard
  block in program order.
- **Adjacency with the `guard-destructive-git.sh`/stash-pop task**: confirmed no file-territory
  overlap (that task edits the guard hook and `git-workflow.md`, not this script) and no
  behavioral coupling — this fix changes nothing about which stash entries exist or how they are
  named, only whether/how failures while creating them are reported.
- **The `shell-strict-mode.md` "none found unguarded" claim is incorrect for `git-snapshot.sh`**
  (machine-checked: all four sites were read directly from the live script, and the `git stash
  create` and `head -1 | cut` failures were independently reproduced). Recorded as a
  `claim_invalidations` entry in `.return-meta.json` rather than left only in this report's
  prose.

## Recommendations

1. Wrap each of the four sites (lines 442, 464, 471+472 as a pair, 479, 501) in an explicit
   success check following the script's own existing `if ! VAR=$(cmd 2>&1); then echo
   "git-snapshot.sh: <reason>" >&2; echo "  <underlying-command> exited $?: $VAR" >&2; ...; exit
   1; fi` idiom — replacing the current `2>/dev/null` with `2>&1` captured into the same variable
   so the underlying git error text is preserved and reportable rather than discarded.
2. For lines 464/471 specifically (the `--no-revert` stash pair), implement the degrade-not-abort
   decision above: on failure, print a named `WARNING` (not an error) to stderr including the
   underlying git stderr text, reset `STASH_SHA=""` / leave `STASH_REF="NONE"`, and fall through
   to the untracked-backup and patch/marker-write steps exactly as the existing empty-stash
   case already does. Do not `exit 1` on this path.
3. Replace the `git stash list | head -1 | cut -d: -f1` pipeline at both line 471 and line 501
   with a non-piped capture + pure-bash first-line/first-field parse, removing the SIGPIPE class
   of failure structurally rather than special-casing its exit status.
4. Add a new case to `tests/test-git-snapshot.sh` reusing its existing `make_scoped_repo`/
   `run_snapshot` pattern: hold `.git/index.lock` in a fixture repo, run `--no-revert`, and assert
   (a) a non-zero, documented exit status, (b) the output contains a named reason (not merely the
   mode line followed by nothing), and (c) — as a companion negative control — that an ordinary
   (unlocked) `--no-revert` run on the same fixture still succeeds byte-compatibly on stdout.
   Consider also exercising the large-stash-list SIGPIPE path directly (push ~2000+ scratch
   stash entries in the fixture before running `--no-revert`) as a second case, since that one is
   reproducible independent of lock timing and would otherwise remain untested.
5. Leave the `shell-strict-mode.md` correction and the broader `grep | head | cut` sibling sweep
   (`lib/plan-status-line.sh`, `lib/suite-selection-lib.sh`) as follow-up items, not in this
   task's scope.

## Risks & Mitigations

- **Risk**: degrading the stash-create failure to a warning could mask a *different*, more
  serious git repository problem (not mere lock contention) that happens to manifest the same
  way. **Mitigation**: the warning must include the underlying git stderr verbatim (captured via
  `2>&1` instead of discarded), so a caller or log reviewer can distinguish "transient lock
  contention" from "something is actually wrong with this repository" even though the script
  itself proceeds either way.
- **Risk**: the non-piped parse replacement for `STASH_REF` could subtly change behavior if
  `git stash list`'s first line ever legitimately contains no colon (parsing bug risk).
  **Mitigation**: `stash@{N}: <message>` is a stable, documented `git stash list` format; the
  existing `cut -d: -f1` already assumes exactly this shape, so the bash-parameter-expansion
  replacement should preserve the identical assumption, just without piping.
- **Risk**: a new fixture test that holds `.git/index.lock` could itself leak a stale lock file if
  the test crashes before cleanup. **Mitigation**: follow the existing suite's `trap cleanup EXIT`
  convention (already present in `test-git-snapshot.sh`) and release/remove the lock file
  explicitly before any `rm -rf` of the fixture directory, not relying on the directory removal
  alone.

## Context Extension Recommendations

- **Topic**: shell command-substitution failure semantics under `set -euo pipefail`.
- **Gap**: `shell-strict-mode.md` documents the *migration admission tests* (Class A/B/C) but has
  no worked example of the specific "bare `VAR=$(cmd1 | cmd2)` under `pipefail` can abort
  silently on cmd1's SIGPIPE, not just on an obvious failure" gotcha that this task's root cause
  turned out to hinge on for the second (latent) failure mode.
- **Recommendation**: after this fix lands, consider adding a short worked example to
  `shell-strict-mode.md` or a sibling pattern doc capturing the "pipe a potentially-large git
  output into `head`/`cut` under `pipefail`" gotcha and the pure-bash-parsing alternative, so
  future Class A migrations catch this shape before merge rather than after an incident report.

## Appendix

- Reproduction commands (scratch `mktemp -d` repos, not this repository): held `.git/index.lock`
  + `git stash create`; 2000-entry `git stash push` loop + `git stash list | head -1 | cut -d: -f1`
  under `pipefail`; `PIPESTATUS` isolation of the piped failure.
- Sweep query: `grep -rnE '^\s*[A-Z_]+=\$\(.*git .*\)' . --include="*.sh"` (and a lowercase/`local`
  variant) across `agent-system/extensions/core/scripts/`, excluding `deprecated/`.
- Related query: `grep -rnE 'git stash list.*\|.*head|head.*\|.*cut' . --include="*.sh"`.
- Files read in full: `git-snapshot.sh`, `tests/test-git-snapshot.sh`,
  `context/standards/shell-strict-mode.md` (relevant sections), `context/patterns/
  checkpoint-before-overflow.md` (relevant sections).
