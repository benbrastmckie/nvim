# Implementation Plan: Task #201

- **Task**: 201 - Close runtime-file ignore enumeration gap
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: None declared. Non-blocking file-footprint overlap with task 51 (`not_started`); this task lands first, no reconciliation needed now.
- **Research Inputs**: specs/201_close_runtime_file_ignore_enumeration_gap/reports/01_close_ignore_enumeration_gap.md
- **Artifacts**: plans/01_close-ignore-enumeration-gap.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, orchestrator-runtime-files.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Four members of the documented "ephemeral orchestrator runtime state" class
(`specs/.deploy-lock/`, `specs/.scope-lock/`, `specs/.commit-lock/`, `specs/.errors.lock`) are
missing from the enumerations that are supposed to cover the whole class. Rather than patching
four names into three hand-maintained lists — the exact maintenance shape that produced the
defect — this plan introduces a single canonical class definition in
`scripts/lib/runtime-file-patterns.sh` and derives every mechanical consumer from it, following
the `scripts/lib/task-reference-patterns.sh` precedent already established in this repo for a
lint/hook pattern pair. The markdown "Consumer Repo Setup" block cannot `source` a bash lib, so
it is instead pinned to the lib by a machine assertion inside a new regression test, which also
delivers the dispatch's ACCEPTANCE demonstration (tracked `specs/.deploy-lock/owner` -> FAIL with
the `git rm -r --cached` remediation line -> untracked -> PASS).

### Research Integration

Key findings carried into this plan:

- The (c) sweep found three further gaps beyond the dispatch's named `.deploy-lock/`:
  `.scope-lock/` and `.commit-lock/` (both `task-lock.sh` mutex directories, named in that
  script's own comments as siblings of the already-covered `.lock/`), and `.errors.lock`
  (`errors-append.sh`, structurally identical to the already-covered `.events.lock`).
- The three sites are incomplete in *mutually inconsistent* ways: this repo's `/.gitignore`
  already carries `**/.commit-lock/` and `**/.errors.lock` (added out of band) while the
  standards block and both script lists carry neither. No single site currently states the true
  membership of the class.
- `specs/.deploy-lock/owner` is **already untracked** (commit `cf51ce8bb`), so the ACCEPTANCE
  untracking step has nothing left to do. Note: that commit used a plain `git rm` rather than
  the documented `git rm --cached`; harmless only because no deploy was live. Verify-and-record,
  do not re-run.
- `tests/test-deploy-orphans.sh` and `tests/test-deploy-propagation.sh` embed a verbatim copy of
  the gitignore block and run a real headless deploy whose gate 14 *is*
  `check-runtime-file-tracking.sh`. Widening the script's probes without updating both fixtures
  turns two green tests red.
- `check-runtime-file-tracking.sh` carries a pre-existing `SC2034` (unused `YELLOW`), which the
  "shellcheck clean" acceptance bar will trip on regardless of this task's edits.

**Verified directly during planning, beyond the report** — two facts that sharpen the scope-(d)
argument and the acceptance mechanics:

1. **The drift is already inside the one script.** `EPHEMERAL_PROBES` contains
   `${PROBE_DIR}/.dispatch/1.md`; `b_patterns` has no `/\.dispatch/` regex. Check A probes a
   class member Check B cannot detect. This is not a hypothetical future divergence — the two
   lists disagree today.
2. **The two test fixtures have already drifted *ahead* of the standards block.** Both embed
   12 patterns including `**/.dispatch/`; the standards Consumer Repo Setup block has 11 and
   omits it. The fixtures' own comments claim they "mirror" that block. They do not.
3. **The `-r --cached` remediation branch is hardcoded to `.lock/`.** The Check B remediation is
   `if [[ "$hit" == *"/.lock/"* ]]`, so a tracked `specs/.deploy-lock/owner` would print
   `git rm --cached "specs/.deploy-lock/owner"` — *not* the `git rm -r --cached` form the
   dispatch's ACCEPTANCE line explicitly requires. Generalizing this branch to any
   directory-class member is a hard requirement, not a nicety.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in the dispatch context; ROADMAP.md not consulted.

## Goals & Non-Goals

**Goals**:
- One canonical, machine-readable definition of the ephemeral runtime-file class, consumed by
  every mechanical site, so a future class member cannot be added to one list and forgotten in
  the others.
- All four newly-found class members (`.deploy-lock/`, `.scope-lock/`, `.commit-lock/`,
  `.errors.lock`) plus the already-inconsistent `.dispatch/` present in every enumeration.
- `check-runtime-file-tracking.sh` prints the correct `git rm -r --cached` remediation for every
  directory-class member, not just `.lock/`.
- The ACCEPTANCE behaviour demonstrated by an executable regression test, not asserted in prose.
- Scope (d) decided and recorded in the standards file itself.

**Non-Goals**:
- Rewriting history to remove `specs/.deploy-lock/owner` from commit `96fb00a40` (explicitly
  forbidden by the dispatch; concurrent-writer history rewrites are separate filed work).
- Deleting any live mutex directory or `owner` file from disk.
- Adding `.orchestrator-handoff.json` or `.return-meta.json` to any ignore list (explicitly
  forbidden; they are durable freshness-gated provenance and Check C exists to enforce that).
- Delivering a repo-root `.gitignore` from the source store (documented as impossible — the
  `root_files` deploy target is the consumer's `.claude/`, so a `specs/`-rooted pattern would
  resolve to `.claude/specs/...`). The consumer-side edit stays a documented manual step.
- Folding in `.postflight-pending`, the `.stale-*`/`.exhausted-*` diagnostic trio,
  `.git-snapshot-marker`, or `untracked-backup-*/`. These are already correctly gitignored here
  and documented in other standards files; including them exceeds ACCEPTANCE without live proof.
- Reclassifying `specs/.eager-context-snapshot-*.json` as ephemeral — it is opt-in diagnostic
  evidence, structurally in the "deliberately excluded / preserve evidence" class. It gets a
  one-line documented exclusion, not an ignore pattern.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Widening Check A probes reds gate 14 in this repo (Check A fails until `/.gitignore` gains `**/.deploy-lock/` and `**/.scope-lock/`), which reds any `deploy-headless.sh` run | H | H | Phase 2 lands the consumer `.gitignore` in Wave 1, **before** Phase 3 touches the script. Sequencing is the mitigation. |
| Widening probes without updating both deploy test fixtures turns two previously-green end-to-end tests red (deploy exit 3, `landed_verify_red`) | H | H | Phase 5 rewires both fixtures to emit their block *from the lib*, so they cannot drift again; Phase 7 re-runs both against a real headless deploy. |
| Introducing a lib without registering it in `manifest.json` means it never deploys, so the deployed `check-runtime-file-tracking.sh` fails to source it and gate 14 breaks in the deployed tree only | H | M | Phase 1 registers `lib/runtime-file-patterns.sh` in `manifest.json`'s `scripts` array as part of the same phase; Phase 7 verifies against the *deployed* copy, not just the source store. |
| Pre-existing `SC2034` fails the "shellcheck clean" bar for a reason predating this task, looking like this task's regression | M | H | Phase 3 resolves `YELLOW` explicitly (wire it into a real use or remove it) rather than deferring. |
| Editing `orchestrator-runtime-files.md` without updating `index-entries.json`'s `line_count: 356` trips the line-count drift gate | M | H | Phase 7 re-syncs `line_count` and runs the drift check. |
| Task 51 later relocates these files and rewrites the same enumerations, reintroducing drift | M | L | The single-source lib is precisely the structural mitigation; whichever task lands second re-derives from the lib rather than from its own view of the lists. |
| Untracking action performed against a live mutex destroys serialization | H | L | Nothing to untrack (already done). Phase 2 only *verifies* via `git ls-files` and `ps`; it performs no `git rm` unless a genuinely tracked member is found, and then only `--cached`, with a no-deploy-in-flight check first. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 1 |
| 3 | 5, 6 | 3, 4 |
| 4 | 7 | 5, 6 |

Phases within the same wave can execute in parallel. Wave 1's ordering relative to Wave 2 is
load-bearing, not merely conventional: Phase 2 must land before Phase 3 or every `deploy-headless.sh`
run in this repo goes red at gate 14.

---

### Phase 1: Canonical runtime-file class lib [COMPLETED]

**Goal**: One place that defines the ephemeral runtime-file class, from which every mechanical
consumer derives.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` with a header
      comment modelled on `lib/task-reference-patterns.sh`: state that this is the ONLY
      definition of the class, name its consumers, and name the markdown block it is pinned to.
      *(completed)*
- [x] Define one canonical record per class member carrying: gitignore pattern, Check A
      representative probe path, Check B tracked-file regex, and a directory-class flag (used by
      the `git rm -r --cached` remediation branch). Parallel indexed arrays are acceptable and
      simplest under `set -uo pipefail`; associative arrays are fine if kept bash-4-safe.
      *(completed: 6 parallel arrays, dir basename lookup helper)*
- [x] Seed it with the existing 11 covered members **plus** `.dispatch/` (currently in Check A
      and both fixtures but in neither the Check B list nor the standards block) **plus** the
      four gaps: `.deploy-lock/`, `.scope-lock/`, `.commit-lock/`, `.errors.lock`.
      *(completed: 16 members total)*
- [x] Provide `runtime_ignore_block()` emitting the exact fenced gitignore body (comment header
      + patterns) that the standards block and both test fixtures must carry verbatim.
      *(completed)*
- [x] Register `lib/runtime-file-patterns.sh` in `agent-system/extensions/core/manifest.json`'s
      `scripts` array, in the existing alphabetical `lib/*` position. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: 16 class members total (11 existing + `.dispatch/` + 4 gaps). Confirm by
diffing the lib's member list against `EPHEMERAL_PROBES`, `b_patterns`, the standards block, and
the sweep table in the research report — all four, not just one. If a member appears in any of
those and not in the lib, the hypothesis is wrong and the lib is short.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` - new file, canonical class
  definition plus `runtime_ignore_block()`
- `agent-system/extensions/core/manifest.json` - add the lib to the `scripts` array

**Verification**:
- `shellcheck` clean on the new lib per `context/standards/shell-strict-mode.md`
- Sourcing smoke test: source the lib in a subshell, print the member count and
  `runtime_ignore_block()` output, confirm no unbound-variable error under `set -u`
- `jq . agent-system/extensions/core/manifest.json` parses; the new entry is present

---

### Phase 2: Consumer `.gitignore` and untracking verification [COMPLETED]

**Goal**: This repo's own root `/.gitignore` covers the full class *before* the lint widens, and
the already-performed untracking is verified rather than re-attempted.

**Tasks**:
- [x] Add `**/.deploy-lock/` and `**/.scope-lock/` to the repo root `/.gitignore` in the existing
      ephemeral-runtime-state block (`**/.commit-lock/`, `**/.errors.lock`, `**/.dispatch/` are
      already present — verify rather than duplicate). *(completed)*
- [x] Verify no class member is currently tracked: `git ls-files | grep -E '\.deploy-lock/|\.scope-lock/|\.commit-lock/|\.errors\.lock'`.
      *(completed: zero hits)*
- [x] Confirm `specs/.deploy-lock/owner` is absent from both index and disk (already untracked in
      commit `cf51ce8bb`). Record in the phase notes that the untrack used a plain `git rm`
      rather than the documented `git rm --cached`, harmless here only because no deploy was
      live. **Do not re-run any untrack against a path that no longer exists.**
      *(completed: confirmed absent from index (`git ls-files`) and from disk — no
      `specs/.deploy-lock/` directory exists currently, no live deploy in flight; no untrack
      action taken)*
- [x] If — contrary to expectation — a tracked member *is* found: check `ps aux` for a live
      `deploy-headless.sh` first, and only then run `git rm -r --cached <dir>` (never plain
      `git rm`, never touching the on-disk file). *(completed: not applicable, no tracked member
      found)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `/home/benjamin/.config/nvim/.gitignore` - two new patterns in the ephemeral runtime block

**Verification**:
- `git check-ignore -v specs/.deploy-lock/owner` and `git check-ignore -v specs/.scope-lock/owner`
  each name the new `.gitignore` line
- `git check-ignore -q specs/000_probe/.orchestrator-handoff.json` returns non-zero (durable
  provenance still NOT ignored — Check C must stay green)
- `git ls-files` shows zero class members tracked

---

### Phase 3: Rewire `check-runtime-file-tracking.sh` onto the lib [COMPLETED]

**Goal**: Both of the script's lists derive from the lib, the remediation line is correct for
every directory-class member, and the file is shellcheck clean.

**Tasks**:
- [x] Source `lib/runtime-file-patterns.sh` (resolve the path so it works from both the source
      store and the flattened deployed `.claude/scripts/` tree — the deploy merges `lib/` under
      `.claude/scripts/lib/`, so a `$(dirname "$0")/lib/...` form covers both). *(completed:
      `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` + `${SCRIPT_DIR}/lib/...`)*
- [x] Replace the literal `EPHEMERAL_PROBES` array with values derived from the lib. *(completed)*
- [x] Replace the literal `b_patterns` array with values derived from the lib. This closes the
      already-live Check A/Check B divergence on `.dispatch/`. *(completed)*
- [x] Generalize the Check B remediation branch: replace the hardcoded
      `if [[ "$hit" == *"/.lock/"* ]]` with a lookup against the lib's directory-class flag, so
      **every** directory member (`.lock/`, `.dispatch/`, `.deploy-lock/`, `.scope-lock/`,
      `.commit-lock/`, `.sessions/`) prints `git rm -r --cached "<dir>"` and files print
      `git rm --cached "<file>"`. This is what the ACCEPTANCE line requires for
      `specs/.deploy-lock/owner`. *(completed: `runtime_file_dir_basename_for_hit()`; verified
      live in a scratch repo — FAIL with `git rm -r --cached "specs/.deploy-lock"` on a
      force-tracked `specs/.deploy-lock/owner`, then PASS after that exact untrack)*
- [x] Resolve the pre-existing `SC2034` on `YELLOW`: either wire it into a real output line or
      remove the declaration. Do not suppress with a directive without stating why. *(completed:
      removed — `YELLOW` had no live use anywhere in the file)*
- [x] Add a cross-reference comment naming the lib as the sole source and pointing at the
      standards block and the two fixtures. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: exactly two arrays plus one remediation conditional change. Confirm by
grepping the file for every remaining literal class name after the edit — a leftover hardcoded
member means a third enumeration site inside the script was missed.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` - source the lib, derive
  both arrays, generalize the remediation branch, fix SC2034, add cross-reference comment

**Verification**:
- `shellcheck agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` exits 0 with
  no findings (including the previously-pre-existing SC2034)
- Running the script against this repo (with Phase 2 landed) reports `PASS — all three checks
  passed`, and Check A's output now lists all 16 probes
- `grep -nE '\.lock/|\.deploy-lock|\.scope-lock|\.commit-lock|\.errors\.lock|\.dispatch' ` on the
  script shows no residual hardcoded member list outside comments

---

### Phase 4: Standards file — class rows, block, and the scope-(d) decision record [NOT STARTED]

**Goal**: The canonical standards file documents all class members, matches the lib's block
byte-for-byte, and records the single-source decision.

**Tasks**:
- [ ] Add Class Table rows for `specs/.deploy-lock/` (writer `deploy-headless.sh`),
      `specs/.scope-lock/` and `specs/.commit-lock/` (writer `task-lock.sh`
      `cmd_scope_acquire`/`cmd_commit_acquire`; `git-commit-scoped.sh` for the latter's use
      site), and `specs/.errors.lock` (writer `errors-append.sh`), each with writer / reader /
      cleanup site / disposition, mirroring the existing `.lock/` and `.events.lock` rows.
- [ ] Replace the Consumer Repo Setup fenced block with the exact output of the lib's
      `runtime_ignore_block()` — this adds the four gaps and `.dispatch/`, resolving the
      block's standing contradiction with the file's own Class Table.
- [ ] Add a sentence to the "Not classified here (reviewed and deliberately excluded)" paragraph
      covering `specs/.eager-context-snapshot-{ISO8601}.json`: opt-in human-invoked diagnostic
      snapshot, no automated writer, purpose is later human diffing — same
      preserve-the-evidence class as `.stray-handoff-*`, deliberately not ephemeral.
- [ ] Add a short "Single source of truth" subsection recording the scope-(d) decision: the two
      script-internal lists and both test fixtures derive mechanically from
      `scripts/lib/runtime-file-patterns.sh`; the markdown block cannot `source` a bash lib and
      is instead pinned to it by an assertion in `tests/test-runtime-file-tracking.sh`. State
      the reasoning (this file had already drifted from its own Class Table and from both
      fixtures) so a future editor does not re-hand-maintain the block.
- [ ] Add the cross-reference comment inside the fenced block itself pointing at the lib, so a
      reader who finds only the block knows where the truth lives.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: 4 new Class Table rows and 5 new block patterns (4 gaps + `.dispatch/`).
Confirm the block by diffing it against `runtime_ignore_block()` output — an off-by-one here is
exactly the defect class this task exists to close, so diff it, do not eyeball it.

**Files to modify**:
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - Class Table
  rows, regenerated Consumer Repo Setup block, exclusion note, single-source decision record

**Verification**:
- `diff <(bash -c 'source .../runtime-file-patterns.sh; runtime_ignore_block')` against the
  extracted fenced block is empty
- Every class member in the lib has a Class Table row (grep each name)
- No task-number citations introduced (this file is outside `specs/**` — see
  `rules/no-task-references-in-deliverables.md`); `check-task-references.sh` stays green

---

### Phase 5: Rewire the two deploy test fixtures [NOT STARTED]

**Goal**: The fixtures' embedded `.gitignore` is generated from the lib, so they can never again
drift ahead of or behind the standards block.

**Tasks**:
- [ ] In `tests/test-deploy-orphans.sh`, replace the hand-maintained `GITIGNORE_EOF` heredoc with
      a call that sources the lib and writes `runtime_ignore_block()` to `$TARGET/.gitignore`.
- [ ] Do the same in `tests/test-deploy-propagation.sh`.
- [ ] Update each fixture's surrounding comment: it currently claims to "mirror" the standards
      block by hand, which was already false (both carried `**/.dispatch/` while the block did
      not). Restate it as derived-from-the-lib.
- [ ] Keep the scratch-repo bootstrap semantics otherwise unchanged — these harnesses test
      deploy propagation and orphan handling, not ignore coverage; the `.gitignore` seeding only
      exists so gate 14 does not fail for unrelated reasons.

**Timing**: 0.5 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Scope Hypothesis**: exactly two fixtures embed the block. Confirm with
`grep -rl 'orchestrator-loop-guard' agent-system/extensions/*/scripts/` before editing — a third
embedder would be a further, unfixed enumeration site.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` - generate `.gitignore`
  from the lib
- `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` - same

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` passes (runs a real
  headless deploy; gate 14 green inside the scratch repo)
- `bash agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` passes
- `shellcheck` clean on both

---

### Phase 6: Regression test — the ACCEPTANCE demonstration [NOT STARTED]

**Goal**: The dispatch's acceptance behaviour is executable and permanent, and the markdown block
is machine-pinned to the lib.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` following
      `context/standards/shell-script-testing.md` conventions (PASSED/FAILED counters,
      `set -uo pipefail`, scratch repo under the scratchpad or a `mktemp -d`, trap cleanup).
- [ ] Case 1 (the ACCEPTANCE line): build a scratch repo seeded with the lib's gitignore block,
      then force-add a tracked `specs/.deploy-lock/owner` (`git add -f`), run
      `check-runtime-file-tracking.sh`, assert exit 1, assert the output contains
      `git rm -r --cached` and the `specs/.deploy-lock` path — the `-r` form specifically, since
      the un-generalized branch would emit the plain form and silently pass a weaker assertion.
- [ ] Case 2: `git rm -r --cached specs/.deploy-lock` in the scratch repo, assert the file is
      still on disk, re-run the script, assert exit 0 / `PASS`.
- [ ] Case 3 (doc-sync pin for scope (d)): extract the fenced `gitignore` block from
      `context/standards/orchestrator-runtime-files.md` and assert it equals
      `runtime_ignore_block()` output exactly. This is the mechanism that makes the markdown site
      "provably agree" with the script lists.
- [ ] Case 4 (Check C guard): assert a scratch repo that ignores `.orchestrator-handoff.json`
      fails Check C — protecting the MUST NOT from a future over-broad pattern added to the lib.
- [ ] Case 5: assert every lib member has a Check A probe and a Check B regex (the two derived
      lists are 1:1 by construction, not by discipline).
- [ ] Register the new test in `manifest.json`'s `scripts` array. `run-all.sh` auto-discovers
      `test-*.sh`, so no runner registration is needed — verify discovery rather than assume it.
- [ ] `chmod +x` the new test (`run-all.sh` reports a non-executable suite as a loud `[SKIP]`,
      which would silently remove this test from the regression net).

**Timing**: 1 hour

**Depends on**: 3, 4

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` - new regression test
- `agent-system/extensions/core/manifest.json` - register the new test script

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` passes all cases
- Deliberate-break check (demonstrated, not asserted): temporarily revert the remediation branch
  to the `.lock/`-only form and confirm Case 1 FAILS; restore. Likewise temporarily remove one
  pattern from the standards block and confirm Case 3 FAILS; restore.
- `shellcheck` clean; the file is executable; `run-all.sh` lists it among discovered suites

---

### Phase 7: Redeploy, full verification, and index sync [NOT STARTED]

**Goal**: The deployed `.claude/` tree matches the source store, every gate is green end-to-end,
and metadata drift checks pass.

**Tasks**:
- [ ] Update `agent-system/extensions/core/index-entries.json`'s `line_count` for
      `standards/orchestrator-runtime-files.md` (currently `356`) to the post-edit count.
- [ ] Check `ps aux` for an in-flight `deploy-headless.sh` before deploying; wait rather than
      race the mutex this task is about.
- [ ] Run the deploy so `.claude/` picks up the new lib, the rewired check script, and the new
      test. Confirm `.claude/scripts/lib/runtime-file-patterns.sh` exists and that the deployed
      `check-runtime-file-tracking.sh` sources it successfully from the flattened tree.
- [ ] Run `bash .claude/scripts/check-runtime-file-tracking.sh` (the *deployed* copy) against this
      repo: expect `PASS`.
- [ ] Run the full shell test suite (`scripts/tests/run-all.sh`) and confirm no suite regressed.
- [ ] Run `shellcheck` across every file this task touched.
- [ ] Run `check-task-references.sh` to confirm no task-number citations leaked into any
      deliverable outside `specs/**`.

**Timing**: 0.75 hours

**Depends on**: 5, 6

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - `line_count` for the standards file
- `.claude/**` - regenerated by the deploy only; never hand-authored (see
  `rules/source-store-deploy-boundary.md`)

**Verification**:
- Deploy exits 0 with all gates green, gate 14 included
- Deployed and source-store copies of both changed scripts and the standards file are identical
  (`diff`)
- `run-all.sh` reports zero failing suites and a non-zero discovered-suite count
- `shellcheck` clean across all touched scripts
- Line-count drift check green

---

## Testing & Validation

- [ ] `shellcheck` clean on `check-runtime-file-tracking.sh`, the new lib, the new test, and both
      rewired fixtures — including the previously pre-existing `SC2034`
- [ ] `check-runtime-file-tracking.sh` PASSes against this repo from both the source store and
      the deployed `.claude/` copy
- [ ] `test-runtime-file-tracking.sh` demonstrates FAIL-with-`git rm -r --cached` on a tracked
      `specs/.deploy-lock/owner` and PASS after untracking, with the on-disk file intact
- [ ] Both deploy harnesses (`test-deploy-orphans.sh`, `test-deploy-propagation.sh`) still pass
      against a real headless deploy
- [ ] The standards file's fenced block is byte-identical to `runtime_ignore_block()`
- [ ] Check C still fails a repo that ignores `.orchestrator-handoff.json` (the MUST NOT holds)
- [ ] `git ls-files` shows no ephemeral class member tracked in this repo
- [ ] `check-task-references.sh` green

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` (new)
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` (rewired)
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (rows, block,
  exclusion note, single-source decision record)
- `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh`,
  `test-deploy-propagation.sh` (fixtures derived from the lib)
- `agent-system/extensions/core/manifest.json` (two new script registrations)
- `agent-system/extensions/core/index-entries.json` (`line_count` resync)
- `/home/benjamin/.config/nvim/.gitignore` (`**/.deploy-lock/`, `**/.scope-lock/`)
- Regenerated `.claude/` deploy tree

## Rollback/Contingency

Every phase is additive or a mechanical substitution; no history rewriting and no destructive git
is involved. Rollback is per-phase `git revert` of that phase's commit.

Two ordering hazards to watch during rollback as well as during implementation:

- Reverting Phase 2 (the consumer `.gitignore`) while Phase 3 stands leaves gate 14's Check A
  failing in this repo, which reds every deploy. Revert Phase 3 first, or not at all.
- Reverting Phase 3 while Phase 5 stands is safe (the fixtures source the lib, which still
  exists), but reverting Phase 1 requires reverting Phases 3, 5, and 6 first — they all source
  the lib and will fail to run without it.

If the single-source lib proves disproportionate mid-implementation (for instance, if the
deployed flattened-tree source path cannot be resolved cleanly from both trees), the documented
fallback from the dispatch's scope (d) is available without redoing the work: keep the literal
lists in `check-runtime-file-tracking.sh` and the fixtures, add the four-plus-one missing members
to each by hand, and add an explicit cross-reference comment at each of the five sites naming the
other four. Record that fallback and its reason in the standards file's single-source subsection
instead of the mechanism described in Phase 4 — scope (d) requires a recorded decision, not a
specific outcome.
