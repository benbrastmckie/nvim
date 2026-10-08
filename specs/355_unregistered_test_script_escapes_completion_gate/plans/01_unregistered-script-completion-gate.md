# Implementation Plan: Task #355

- **Task**: 355 - Unregistered test script escapes the completion gate
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: Territory-serialized after the honest-session-liveness task
  (`honest_session_liveness_for_concurrent_same_repo_batches`) over
  `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`. This is a territory
  serialization, not a work dependency -- nothing in this plan consumes that task's result.
- **Research Inputs**: `specs/355_unregistered_test_script_escapes_completion_gate/reports/01_unregistered-script-completion-gate.md`
- **Artifacts**: plans/01_unregistered-script-completion-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-strict-mode.md, source-store-deploy-boundary.md,
  no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

A new `scripts/tests/test-*.sh` in the source store requires a hand-written entry in its
extension's `manifest.json` `provides.scripts` array; `run-all.sh` discovers suites by glob, so
nothing surfaces the requirement at authoring time, and a missing entry can reach `[COMPLETED]`
undetected when the owning task's completion routes through the baseline-tolerant redeploy
paths. This plan lands both fixes the research recommends: **(a)** a `--check`/`--write` repair
script that derives each extension's `provides.scripts` from its tracked `scripts/` tree, and
**(b)** a narrow self-attribution screen that stops a task from completing through the
"findings predate this redeploy" branch when a current finding positively names one of that
task's **own** modified files. Done means: a fixture proves an unregistered test script blocks
the chosen gate, both baseline call sites carry the screen with parity preserved, the redeploy
is clean, and the work is shellcheck-clean.

**SOURCE STORE IS THE EDIT TARGET.** Every edit lands under
`agent-system/extensions/core/**`; never a deployed `.claude/**` path (see
`rules/source-store-deploy-boundary.md`). No task-number references in any file landing under
`agent-system/**` (`rules/no-task-references-in-deliverables.md`).

### Research Integration

The research report's three load-bearing results drive this plan's shape:

1. **The suspected mechanism is CONFIRMED, with a correction.** The reconcile path does verify
   less than a mid-implementation redeploy -- but not because `check-extension-docs.sh` is
   skipped, and not because the pre/post comparison is count-based. Gate 3 runs in both paths,
   and `deploy_baseline_new_findings` has been a `comm -13` set difference over **FINDING-line
   identities** since 2026-10-03, three days before the incident. The `pre=11 post=2 new=0`
   line quoted in the dispatch is that already-identity-based branch's own diagnostic output.
   **Consequence for this plan: the "counts should become identities" candidate change is
   dropped entirely -- there is nothing to convert.**
2. **The real mechanism** is that `check-extension-docs.sh`'s `EXT_DIR` always resolves to the
   source store, so Rule Q's verdict is a pure function of committed source-store state and is
   insensitive to the redeploy. A task's unregistered script is committed during implementation,
   *before* the checkpoint takes its own `pre_findings` -- so the violation is always
   "temporally pre-existing" relative to the checkpoint's measurement window, and the
   pre-existing branch applies **zero** attribution checking, by explicit design. "Predates my
   own redeploy" and "I caused it" are indistinguishable there. Phase 3 closes exactly that.
3. **`provides.scripts` is not curated.** Re-derived at plan-authoring time (not carried from
   the report): a `comm` diff of `git ls-files <ext>/scripts` against
   `jq '.provides.scripts[]?'` over all 9 extensions with a `scripts/` tree returns empty in
   **both** directions -- 225/225 for core, 54/54 literature, 36/36 lean, 7/7 books, 4/4
   memory, 4/4 typst, 2/2 nix, 1/1 email, 1/1 nvim. Zero curation exceptions, zero
   declared-but-absent entries. This removes the one standing objection to automating the array.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and `roadmap_flag` is not set; ROADMAP.md was
not consulted and MUST NOT be modified by this task.

## Goals & Non-Goals

**Goals**:
- A single-command, source-store-only repair for a missing/stale `provides.scripts` entry,
  mirroring `generate-context-line-counts.sh`'s established `--check`/`--write` shape.
- A missing `provides.scripts` registration can no longer reach `[COMPLETED]` undetected: the
  self-attribution screen blocks it at **both** baseline-tolerant completion call sites.
- Behavioral fixtures pinning both mechanisms, including the exact scenario from the incident
  (an unregistered `scripts/tests/test-*.sh` reaching completion via the reconcile path).
- The asymmetry between `provides.scripts` (explicit list) and `index-entries.json`
  (wholesale-directory convention) is stated in the extension-authoring guidance, together with
  the research's finding that `provides.agents`/`commands`/`context` have **no** disk-driven
  pre-deploy check at all.
- Redeployed; shellcheck clean per `context/standards/shell-strict-mode.md`.

**Non-Goals**:
- Converting the baseline comparison from counts to identities. **Refuted by research** -- it
  has been identity-based since before the incident. No change is made to
  `deploy_baseline_new_findings`.
- Designing new Rule-Q-equivalents for `provides.agents` / `provides.commands` /
  `provides.context`. The research confirms the gap is real and arguably worse (no detection
  point at all), but closing it means designing three new Rules, which is outside this task's
  acceptance. It is **documented** here (Phase 5) and recommended as a follow-up task in the
  implementation summary, not implemented.
- Removing curation capability from `provides.scripts` outright, or making the manifest loader
  ignore the array. The repair script is additive: the array stays the deploy's source of
  truth, it just stops being hand-typed.
- Changing `--skip-verify` / the `landed_verify_skipped` exit 4 contract. Research
  Recommendation 5: it is not part of this defect.
- Widening the attribution screen to the whole batch's `cycle_modified_files`. Only
  **self**-attribution may newly block; a finding attributable to a *different* task in the
  same batch must still be waved through exactly as today.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The self-attribution screen bricks completions: a task that merely *touches* a file already named in a long-standing unrelated red finding is newly blocked | H | M | Require a **positive** basename match against that task's own `modified_files` only; emit a loud notice naming both the finding and the matching file; ship an operator-only `SELF_ATTRIBUTION_GATE_MODE=hard\|advisory\|off` (default `hard`), mirroring the existing `STRICT_CORE_DEPLOY` / `ORPHAN_GATE_MODE` / `INDEX_TRUTH_GATE_MODE` precedent, so an operator is never stuck |
| Re-introducing the batch-deferral-on-unrelated-finding problem the pre-existing branch deliberately avoids | H | L | The screen never defers the **batch**: in `orchestrate-cycle-plan.sh` it only withholds the one offending task from `post_deploy_reconcile_json`, leaving it at `implementing` for the next cycle. Unaffected tasks reconcile exactly as today |
| Changing Rule Q's `fail()` text would change its FINDING-line identity, making an existing Rule Q finding look "new" in every pre/post comparison | M | M | **Do not touch the `fail()` string.** Emit the repair pointer as a separate line whose prefix matches neither `"  FAIL: "` nor `"["*"]"` (the two cases `verify-deploy.sh`'s gate-3 extractor keys on), so the FINDING vocabulary is byte-identical |
| A blanket `jq` round-trip of `manifest.json` reformats unrelated content | M | H | `books/manifest.json` and `rust/manifest.json` are **not** `jq --indent 2` canonical (verified at plan-authoring time; the other 19 are). `--write` performs a surgical, line-oriented rewrite of the `provides.scripts` array block only -- the identical rationale `generate-context-line-counts.sh` records for its own awk-based approach |
| Fixtures fragile against the ongoing `deploy-baseline-lib.sh` / `redeploy-checkpoint-lib.sh` refactors | M | M | Assert on **behavior** -- the FINDING text, the withheld task number, the resulting task status -- never on internal function names or line counts (research Risk 3's own mitigation) |
| Refactoring `deploy_baseline_unattributable_findings`'s internals regresses the live batch gate | H | L | Keep the exported function as a thin wrapper over one shared partition helper so the two polarities cannot drift; the existing `test-deploy-baseline-lib.sh` cases must pass unchanged, with no edits to them, as the regression proof |
| A sibling task is dispatched this same cycle on this same tree | M | M | Sibling #303 (`research`) declares `validate-state.sh` + `test-validate-state.sh` only -- **no overlap** with this plan's file set. Still observe the dispatch's concurrency note: re-read each file immediately before editing, stage only this task's own hunks (never a directory or glob `git add`), never run `git-snapshot.sh` in its reverting default mode |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4, 5 | 1, 2, 3 |
| 4 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Automate `provides.scripts` derivation [COMPLETED]

**Goal**: Remove the authoring burden entirely -- fix (a). A new `scripts/tests/test-*.sh` is
registered by one command instead of a hand-typed line, and a Rule Q failure now names that
command.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/sync-manifest-scripts.sh`, modelled
      structurally on `generate-context-line-counts.sh` (read its header first; reuse its
      `REPO_ROOT`/`deploy-root-guard.sh` bypass pattern verbatim):
  - [x] `--check` (default): for every `agent-system/extensions/*/` with a `scripts/` directory,
        diff `git ls-files <ext>/scripts` (prefix-stripped, `deprecated/*` excluded -- the same
        exemption Rule Q already applies) against `jq -r '.provides.scripts[]?'`; report both
        directions (on-disk-not-declared, declared-not-on-disk); exit nonzero if any gap exists.
  - [x] `--write`: insert each missing entry into that manifest's `provides.scripts` array,
        preserving alphabetical order. **Surgical, line-oriented rewrite of that array block
        only** -- no whole-document `jq` round-trip (see Risks: two manifests are not
        `jq --indent 2` canonical).
  - [x] Declared-but-absent entries are **reported, never auto-removed**: deleting a declaration
        is a deploy-affecting judgement call, and preserving an explicit opt-out path is this
        plan's answer to research Risk 1.
  - [x] Class A strict mode (`set -euo pipefail`) per `context/standards/shell-strict-mode.md`'s
        "Default for new scripts".
  - [x] Header comment states, in the WHY-THE-SOURCE-STORE form
        `generate-context-line-counts.sh` already uses, that `.claude/extensions/*/manifest.json`
        is a disposable deploy artifact and only the source-store manifest is read/written.
- [x] In `check-extension-docs.sh`'s `check_undeclared_scripts` (Rule Q): leave the `fail()`
      string **byte-identical**, and add one repair-pointer line after it naming
      `sync-manifest-scripts.sh --write`. Its prefix must match neither `"  FAIL: "` nor
      `"["*"]"`, the two cases `verify-deploy.sh`'s gate-3 FINDING extractor keys on.
- [x] Extend Rule Q's function header comment to record the `index-entries.json` asymmetry and
      point at the new repair script.
- [x] Register `sync-manifest-scripts.sh` in `agent-system/extensions/core/manifest.json`'s
      `provides.scripts` -- by running the new script's own `--write` mode, which both performs
      the registration and demonstrates the fix.
- [x] Add a one-line entry for the new script to
      `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`, in the same
      shape as the existing `generate-context-line-counts.sh` row.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts (i) that `provides.scripts` is uncurated in both
directions and (ii) that the two non-canonical manifests are `books` and `rust`. Both were
re-derived at plan-authoring time, not carried from the report: the `comm -23`/`comm -13` pair
over all 9 extensions with a `scripts/` tree returned empty both ways (core 225/225, literature
54/54, lean 36/36, books 7/7, memory 4/4, typst 4/4, nix 2/2, email 1/1, nvim 1/1), and
`diff <(jq --indent 2 . "$m") "$m"` flagged exactly `books` and `rust`. Confirm at
implementation time by re-running both commands before writing `--write`'s rewrite logic; if any
extension now shows a declared-but-absent entry, treat it as a possible genuine curation case
and report it rather than deleting it.

**Files to modify**:
- `agent-system/extensions/core/scripts/sync-manifest-scripts.sh` - new; `--check`/`--write`
  repair for `provides.scripts`
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - Rule Q repair-pointer line
  (fail() text unchanged) and header note on the asymmetry
- `agent-system/extensions/core/manifest.json` - register the new script in `provides.scripts`
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - inventory row

**Verification**:
- `bash -n` and `shellcheck` clean on the new script and on `check-extension-docs.sh`.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check`
  exits 0 after `--write` has registered the new script, and exits nonzero on a scratch
  fixture where an entry is deliberately removed.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` passes,
  and its Rule Q `FAIL:` line text is byte-identical to the pre-change text (diff the two runs
  against a scratch fixture with a deliberately unregistered script) -- this is the enumerated
  direct dependent for this tier, because `verify-deploy.sh` gate 3 parses those lines into
  FINDING identities.
- `git diff` on `manifest.json` shows **only** the one added `provides.scripts` line.

---

### Phase 2: Self-attribution partition in `deploy-baseline-lib.sh` [COMPLETED]

**Goal**: Give the baseline library the one primitive fix (b) needs -- the findings that
positively name one of a *given* task's own modified files -- without letting it drift from the
existing opposite-polarity filter.

**Tasks**:
- [x] Extract the identifier-scanning loop currently inside
      `deploy_baseline_unattributable_findings` into one internal helper
      (`_deploy_baseline_partition_findings <findings> <modified_files_json> <mode>`, mode one of
      `attributable` / `unattributable`), carrying the punctuation-stripping, the basename
      equality test, and the `DEPLOY_BASELINE_GOVERNED_GLOBS`/`GOVERNING_SOURCES` second signal
      unchanged.
- [x] Re-express `deploy_baseline_unattributable_findings` as a thin wrapper
      (`mode=unattributable`). Its observable contract -- prints lines where `has_ident=1` **and**
      nothing matched; never prints an identifier-free line -- MUST be preserved byte-for-byte in
      behavior. Do not edit any existing case in `test-deploy-baseline-lib.sh`; those cases
      passing unchanged is the regression proof.
- [x] Add the new exported `deploy_baseline_self_attributable_findings <findings>
      <modified_files_json>` (`mode=attributable`): prints lines where `has_ident=1` **and** at
      least one identifier matched. Never exits nonzero; `sort -u`-stable like its siblings.
- [x] Document the **deliberate asymmetry in fail-safe direction** in the library header, with
      its reason: `unattributable` fail-safes toward *blocking* (an identifier-free finding is
      never cleared); `self_attributable` fail-safes toward *proceeding* (an identifier-free
      finding is never reported). The polarities differ because the second function is a
      *narrowing* filter newly added to an already-proceeding branch -- a false negative
      reproduces today's behavior exactly, whereas a false positive would brick every completion
      whenever any identifier-free red finding exists, which is precisely the batch-wide brick
      the pre-existing branch was designed to avoid. State that this asymmetry is intentional so
      a future reader does not "fix" it into symmetry.
- [x] Keep the file Class C (sourced; sets no shell options) per
      `context/standards/shell-strict-mode.md`.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase assumes exactly three live consumers of
`deploy-baseline-lib.sh` (`command-gate-out.sh`, `orchestrate-cycle-plan.sh`,
`scripts/tests/test-deploy-baseline-lib.sh`) -- the enumerated dependent set this tier builds
against. Confirm at implementation time with
`grep -rn "deploy-baseline-lib\|deploy_baseline_" agent-system/extensions/` before editing; if a
fourth consumer exists, add it to the dependent build set for this phase's verification. *(deviation: altered — a 4th consumer, test-verify-deploy-context-budget.sh, was found via grep; it calls only deploy_baseline_new_findings, unaffected by this phase's refactor, and was included in verification regardless)*

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh` - shared partition helper,
  the new `deploy_baseline_self_attributable_findings` export, and the fail-safe-asymmetry
  header note

**Verification**:
- `shellcheck` clean on the library.
- `bash agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh` exits 0 with
  **no edits to the existing cases** -- the refactor's regression proof.
- Ad hoc sanity: the new function returns the Rule Q FINDING line
  (`FINDING gate3 [core] FAIL: script file on disk NOT in provides.scripts: scripts/tests/test-X.sh`)
  when `modified_files` contains
  `agent-system/extensions/core/scripts/tests/test-X.sh`, and returns nothing when it does not.
- Build the two enumerated dependents' own suites (`test-orchestrate-cycle-plan.sh`,
  `test-gate-out-repair-reporting.sh`) to confirm no sourcing-time breakage.

---

### Phase 3: Wire the screen into both baseline completion call sites [COMPLETED]

**Goal**: Close the escape -- fix (b). A finding this task itself caused can no longer hide
behind "it predates my own redeploy," at **either** of the two call sites that reach completion
through the baseline-tolerant branch. Both are done in one phase so the parity the library's own
header demands ("so the two cannot drift apart again") is preserved in a single commit.

**Tasks**:
- [x] `command-gate-out.sh`, `rc==6` branch (c) -- the single-task `/implement` completion path:
  - [x] Before re-attempting the postflight transition, run
        `deploy_baseline_self_attributable_findings "$gate_out_post_findings"` against this
        task's own `.modified_files` from `$meta_file` (already read a few lines above for
        `gate_out_matched_paths`).
  - [x] On a non-empty result under `SELF_ATTRIBUTION_GATE_MODE=hard` (default): do **not**
        re-attempt the transition; leave the status as `$current_status`; print each
        self-attributable finding and the matching own-file that attributed it; keep the existing
        "never re-attempt more than once per gate-out invocation" posture intact.
  - [x] `advisory` prints the same block and proceeds; `off` skips the screen entirely. Both are
        operator-only overrides and are named as such in the comment.
- [x] `orchestrate-cycle-plan.sh`, checkpoint branch (c) -- the inter-cycle reconcile path:
  - [x] Keep the branch's batch-level verdict unchanged: it still proceeds, still records its
        `verify_deploy_baseline_notices` entry. **Do not** add a batch-wide defer.
  - [x] Per deploy-pending task, screen `$post_findings` against that task's own
        `.modified_files` read from its `.return-meta.json`. The existing
        `deploy_pending_tasks_json` derivation loop already resolves `_dp_meta` per task --
        capture the per-task `modified_files` there rather than re-deriving the directory lookup.
  - [x] Withhold a self-attributed task from `post_deploy_reconcile_json` so
        `run_post_deploy_reconcile_pass` never promotes it; it stays at `implementing` for the
        next cycle, which is the correct outcome (its registration is genuinely missing).
  - [x] Record a notice carrying the withheld task number, the attributing finding, and the
        matching own-file, so the operator can act without re-running the gate. Extend the
        existing `verify_deploy_baseline_notices` entry rather than inventing a parallel channel.
  - [x] Honour the same `SELF_ATTRIBUTION_GATE_MODE` vocabulary, with identical semantics. *(deviation: altered — SELF_ATTRIBUTION_GATE_MODE declared once in deploy-baseline-lib.sh, consumed by both call sites, rather than duplicated per-file)*
- [x] Add a short comment at **both** sites stating they are a parity pair over the same library
      function, each naming the other, matching the convention the library header already
      established.

**Timing**: 1.75 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase assumes branch (c) at each site is reachable at exactly one
place (`command-gate-out.sh`'s `else` arm after `deploy_baseline_new_findings` returns empty;
`orchestrate-cycle-plan.sh`'s `if [ -z "$new_findings" ]` arm), and that
`orchestrate-cycle-plan.sh`'s own `deploy_pending_tasks_json` loop already has `_dp_meta` in
hand. Confirm by re-reading both regions immediately before editing -- a sibling may have moved
them, and the predecessor liveness task amended this same script's Move 3 postflight
precondition. Re-grep `post_deploy_reconcile_json` and `deploy_baseline_new_findings` to confirm
the branch count has not changed.

**Files to modify**:
- `agent-system/extensions/core/scripts/command-gate-out.sh` - self-attribution screen in the
  `rc==6` branch (c), before the single postflight re-attempt
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - per-task self-attribution
  screen in checkpoint branch (c); withhold the offending task from
  `post_deploy_reconcile_json`; notice fields
- `agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` - only if the withheld-task
  notice needs a field the reconcile pass emits; prefer leaving this file untouched

**Verification**:
- `shellcheck` clean on every edited script.
- Full gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`) -- this tier's declared requirement,
  the complete set of gates, not a hand-picked subset. Run it after the Phase 6 redeploy if the
  deploy is stale at this point, and record the pre-change finding set first so this phase's own
  effect on it is attributable.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` green (or no new failures vs.
  `known-failures.txt`).
- Manual read-back: branch (c)'s batch-level verdict and its existing notice entry are
  unchanged for a batch with no self-attributed finding.

---

### Phase 4: Fixtures pinning both mechanisms [COMPLETED]

**Goal**: Make the regression impossible to re-introduce silently. Adding an unregistered test
script must fail the chosen gate -- asserted behaviorally, on FINDING text and resulting task
status, never on internal function names.

**Tasks**:
- [x] New `agent-system/extensions/core/scripts/tests/test-manifest-scripts-sync.sh` (Class B,
      `set -uo pipefail`, PASSED/FAILED counter idiom like its siblings):
  - [x] `--check` exits nonzero and names the file when a scratch fixture extension has a
        tracked `scripts/tests/test-*.sh` absent from `provides.scripts`.
  - [x] `--check` exits 0 on a fixture where every tracked script is declared.
  - [x] `--write` adds exactly the missing entry, in alphabetical position, and changes nothing
        else in the manifest (assert on a full-file diff).
  - [x] `--write` on a non-`jq`-canonical manifest fixture leaves unrelated formatting intact.
  - [x] `deprecated/*` is exempt in both modes, matching Rule Q.
  - [x] A declared-but-absent entry is reported, never removed.
  - [x] Rule Q itself: `check-extension-docs.sh` against the unregistered-script fixture emits
        the exact `FAIL: script file on disk NOT in provides.scripts: scripts/tests/...` text
        (Rule Q has no direct fixture coverage today -- research Recommendation 3).
- [x] Extend `test-deploy-baseline-lib.sh` with cases for
      `deploy_baseline_self_attributable_findings`: the Rule Q line with a matching own-file
      (reported); with a non-matching own-file (not reported); an identifier-free line (never
      reported, under either `modified_files` shape); empty/malformed `modified_files_json`
      (degrades without aborting the caller under `set -e -o pipefail`); and a polarity-pair case
      asserting that a line is reported by exactly one of the two functions.
- [x] Extend `test-orchestrate-cycle-plan.sh` with a checkpoint fixture in the established
      Group-28/29 style: a deploy-pending task whose `.return-meta.json` `modified_files`
      contains an unregistered `scripts/tests/test-*.sh`, with a stubbed `verify-deploy.sh`
      returning that Rule Q FINDING in **both** pre and post snapshots (so branch (c) is the
      branch under test). Assert: the batch is **not** deferred; the offending task is absent
      from `post_deploy_reconcile_json`; the notice names it; and a second, non-self-attributed
      deploy-pending task in the same batch IS still reconciled.
- [x] Extend `test-gate-out-repair-reporting.sh` (or add a focused sibling suite if that file's
      scope does not admit it) with the `rc==6` branch-(c) equivalent: the postflight re-attempt
      is withheld and the status is left unchanged when a post-redeploy finding names the task's
      own modified file. *(deviation: altered — added a focused sibling suite, test-gate-out-self-attribution.sh, per this item's own sanctioned fallback; test-gate-out-repair-reporting.sh's build_fixture_repo copies the real update-task-status.sh dependency chain and is not a tractable host for a stubbed rc==6)*
- [x] Register every new suite file in `agent-system/extensions/core/manifest.json`'s
      `provides.scripts` -- via `sync-manifest-scripts.sh --write`, the mechanism this task
      exists to create. `run-all.sh` discovers suites by glob and needs no registration.

**Timing**: 1.75 hours

**Depends on**: 1, 2, 3

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase assumes `test-gate-out-repair-reporting.sh` is the right host
for the `rc==6` case and that `test-orchestrate-cycle-plan.sh`'s checkpoint fixtures follow the
Group-28/29 stub-`verify-deploy.sh` shape. Confirm by reading both suites' existing checkpoint
groups before writing; if the gate-out suite's declared scope does not admit the case, add a
focused sibling suite instead of widening that file's remit, and say so in the summary.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-manifest-scripts-sync.sh` - new; `--check`/`--write`
  behavior plus Rule Q's own first fixture coverage
- `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh` - new cases for the
  self-attribution function and the polarity pair
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - checkpoint
  branch-(c) withheld-task fixture
- `agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh` - `rc==6`
  branch-(c) withheld-re-attempt fixture
- `agent-system/extensions/core/manifest.json` - register the new suite(s)

**Verification**:
- `shellcheck` clean on every new and edited suite.
- Each edited/new suite run individually and exiting 0.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` -- the enumerated direct
  dependent for this tier -- green, or no new failures vs. `known-failures.txt`.
- **Negative proof**: temporarily revert the Phase 3 screen, confirm the new checkpoint and
  gate-out fixtures FAIL, then restore. A fixture that passes with the fix absent pins nothing.

---

### Phase 5: Document the asymmetry and the remaining gap [NOT STARTED]

**Goal**: Fix (c), as a companion to (a) and (b) rather than instead of them -- plus the
authoritative record of the two research results that change how a future reader should read the
checkpoint's design.

**Tasks**:
- [ ] `docs/guides/creating-extensions.md`: in the manifest-field table region (and the
      `index-entries.json` section that sets the contrasting expectation), state that **every**
      file under an extension's `scripts/` tree -- including `scripts/tests/test-*.sh` -- needs
      an explicit `provides.scripts` line, that this differs from `index-entries.json`'s
      wholesale-directory convention, that `run-all.sh` discovers suites by glob so a missing
      entry produces no authoring-time signal, and that `sync-manifest-scripts.sh --write` is
      the one-command repair.
- [ ] Same file: record the research's finding that `provides.agents`, `provides.commands`, and
      `provides.context` have **no** disk-driven pre-deploy check at all -- the orphan checks
      (Rules J/K/L) are structurally blind to a file that never deployed because it was never
      declared -- so a new agent, command, or context file silently never deploys, with no
      `fail()` anywhere in the lifecycle. Note that closing this is a separate, recommended
      follow-up (it needs new Rules, not a fix to an existing one).
- [ ] `context/patterns/batch-orchestration-guardrails.md`, "The Inter-Cycle Redeploy
      Checkpoint" section: document the self-attribution screen as a **narrowing** filter on the
      temporally-pre-existing branch; state plainly why that branch needed one (a source-store-
      resident, disk-driven check such as Rule Q reaches its verdict from committed state, so
      the source store does not change between `pre_findings` and `post_findings`, making
      "predates this redeploy" and "this task caused it" indistinguishable); and record the
      correction that the pre/post comparison is and always was identity-based (`comm -13` over
      FINDING lines), so the `pre=N post=M new=0` diagnostic is evidence of correct
      classification, not of a count-based algorithm.
- [ ] Same file: name the `SELF_ATTRIBUTION_GATE_MODE` vocabulary and its operator-only status.
- [ ] Regenerate index line counts:
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`
      -- editing `context/patterns/batch-orchestration-guardrails.md` changes its `wc -l`, and
      `index-entries.json`'s `line_count` for it (1795 at plan-authoring time) is checked by
      Rule R. Skipping this step turns this phase into a new gate failure.
- [ ] No task-number references in any file touched here (`rules/no-task-references-in-deliverables.md`):
      cite the FINDING text, the rule letter, the file name -- never "task 343" or "task 300".

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: `index-entries.json` records `line_count: 1795` for
`patterns/batch-orchestration-guardrails.md`, matching `wc -l` exactly at plan-authoring time
(both re-derived here, not carried). Confirm after editing by running
`generate-context-line-counts.sh --check`, which must be clean before this phase closes.

**Files to modify**:
- `agent-system/extensions/core/docs/guides/creating-extensions.md` - the `provides.scripts`
  registration requirement, the `index-entries.json` contrast, and the
  agents/commands/context gap
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - the
  self-attribution screen, why the pre-existing branch needed it, the identity-vs-count
  correction, and the gate-mode vocabulary
- `agent-system/extensions/core/index-entries.json` - regenerated `line_count` values

**Verification**:
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check`
  exits 0.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` -- the
  single module whose lint governs these files -- reports no new failures (Rules R, T, U, V).
- `bash .claude/scripts/check-task-references.sh` (or the equivalent repo-wide lint) clean for
  every file touched in this phase.

---

### Phase 6: Redeploy, full gate set, shellcheck [NOT STARTED]

**Goal**: Land the source-store changes in the deploy tree and prove the whole acceptance bar
green -- the step whose omission is the root of the incident this task fixes.

**Tasks**:
- [ ] Re-read every file this task touched immediately beforehand (concurrency note: a sibling
      task is dispatched this same cycle on this same tree).
- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check`
      exits 0 -- every script and suite this task added is registered.
- [ ] `shellcheck` over every `.sh` file this task added or modified; clean per
      `context/standards/shell-strict-mode.md`.
- [ ] Redeploy: `bash agent-system/extensions/core/scripts/deploy-headless.sh`.
- [ ] `bash .claude/scripts/verify-deploy.sh` -- the complete gate set. Compare its findings
      against the pre-change snapshot captured in Phase 3 and account for every difference.
- [ ] `bash .claude/scripts/tests/run-all.sh` green, or no new failures vs.
      `known-failures.txt`.
- [ ] End-to-end acceptance walkthrough, recorded in the summary: add a throwaway
      `scripts/tests/test-zz-scratch.sh` to the source store without a `provides.scripts` entry,
      commit it, confirm Rule Q fires AND that the self-attribution screen withholds a
      completion whose `modified_files` name it, then remove the scratch file and re-verify
      clean. This is the acceptance criterion "a fixture pins whichever mechanism is chosen,"
      demonstrated live rather than only in a stubbed suite.
- [ ] Record in the implementation summary: the confirmed mechanism and the refuted
      count-vs-identity framing; that the other `provides.*` arrays share a worse version of the
      escape; and the recommended follow-up task for `provides.agents`/`commands`/`context`.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- none planned (verification and deploy only; any file changed here is a gate-driven repair,
  reported as a deviation)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0, or every remaining finding is demonstrably
  pre-existing and unrelated, named individually in the summary.
- `bash .claude/scripts/tests/run-all.sh` green or no-new-failures.
- `sync-manifest-scripts.sh --check` exits 0.
- The scratch-script walkthrough above both fires and clears.

---

## Testing & Validation

- [ ] `sync-manifest-scripts.sh --check` exits 0 across all extensions; exits nonzero, naming
      the file, on an unregistered-script fixture.
- [ ] `sync-manifest-scripts.sh --write` adds exactly the missing entry and nothing else
      (full-file diff), including on a non-`jq`-canonical manifest.
- [ ] `test-deploy-baseline-lib.sh`: every pre-existing case passes **unedited** after the
      refactor; new cases cover the self-attribution function and the polarity pair.
- [ ] `test-manifest-scripts-sync.sh`: `--check`/`--write` behavior, `deprecated/*` exemption,
      declared-but-absent reporting, and Rule Q's exact FAIL text.
- [ ] `test-orchestrate-cycle-plan.sh`: branch (c) withholds the self-attributed task from
      `post_deploy_reconcile_json`, does **not** defer the batch, and still reconciles a
      non-self-attributed sibling in the same batch.
- [ ] `test-gate-out-repair-reporting.sh` (or sibling): `rc==6` branch (c) withholds the
      postflight re-attempt and leaves the status unchanged.
- [ ] Negative proof: with the Phase 3 screen reverted, the two new gate fixtures FAIL.
- [ ] Rule Q's `FAIL:` line text is byte-identical before and after this task (FINDING-identity
      stability).
- [ ] `generate-context-line-counts.sh --check` clean.
- [ ] `shellcheck` clean on every added/modified `.sh`.
- [ ] `verify-deploy.sh` and `run-all.sh` green (or no new findings/failures) after redeploy.
- [ ] No task-number references in any file under `agent-system/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/sync-manifest-scripts.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-manifest-scripts-sync.sh` (new)
- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh` (shared partition helper +
  `deploy_baseline_self_attributable_findings`)
- `agent-system/extensions/core/scripts/command-gate-out.sh` (self-attribution screen, `rc==6`
  branch (c))
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (per-task self-attribution
  screen, checkpoint branch (c))
- `agent-system/extensions/core/scripts/check-extension-docs.sh` (Rule Q repair pointer, header
  note)
- `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh`,
  `test-orchestrate-cycle-plan.sh`, `test-gate-out-repair-reporting.sh` (extended)
- `agent-system/extensions/core/manifest.json` (new scripts registered)
- `agent-system/extensions/core/docs/guides/creating-extensions.md`,
  `docs/reference/utility-scripts-inventory.md`,
  `context/patterns/batch-orchestration-guardrails.md`, `index-entries.json` (docs + line counts)
- A redeployed `.claude/` tree
- `specs/355_unregistered_test_script_escapes_completion_gate/summaries/01_*-summary.md`

## Rollback/Contingency

Each phase commits independently (`per-substep`), so the natural rollback is a scoped revert of
that phase's own commits followed by a redeploy -- preferred over any working-tree discard,
because a sibling task is dispatched on this same tree and a reverting operation would take its
in-flight edits too.

If a defensive checkpoint is wanted before Phase 3's two-call-site edit, take a **durable,
non-reverting** one: `bash .claude/scripts/git-snapshot.sh 355 --no-revert`. Do **not** emit a
bare reverting `git-snapshot.sh 355` as a routine precaution -- that default form belongs only
to a genuine rollback, whose invocation shape (including its out-of-scope override flag) is
specified in `context/contracts/recovery.md`'s rollback rung.

Per-fix contingencies:
- **Phase 1** is independently revertible: dropping `sync-manifest-scripts.sh` and the Rule Q
  pointer line restores today's hand-maintained array with no behavior change anywhere else.
- **Phase 3** has a live escape hatch that needs no revert: `SELF_ATTRIBUTION_GATE_MODE=off`
  restores the exact pre-change branch-(c) behavior at both call sites, and `advisory` keeps the
  diagnostics while un-blocking completions. If the screen proves too aggressive in practice,
  flip the default to `advisory` in a follow-up commit rather than ripping the mechanism out --
  the same one-line gate-mode-default migration precedent `STRICT_CORE_DEPLOY` and
  `ORPHAN_GATE_MODE` already set in this codebase.
- If the redeploy in Phase 6 is refused by the completion-deploy gate, that is the very path
  this task hardens: leave the task at `implementing`, record the refusal reason, and let the
  next cycle's checkpoint deploy and reconcile -- which, after this task lands, will itself
  refuse to promote on a self-attributed finding.
