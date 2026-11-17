# Implementation Plan: Task #635

- **Task**: 635 - Enforce the sapience postflight wrapup write at task completion
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: specs/635_enforce_sapience_postflight_wrapup_write/reports/01_sapience-postflight-wrapup-enforcement.md
- **Artifacts**: plans/01_sapience-wrapup-write-enforcement.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The repo-tagged Sapience wrapup write is prose-only today, so it fires or does not fire
depending on whether a completing agent happens to read and follow `EXTENSION.md`. This plan
anchors the *write* mechanically while leaving the *note content* agent-authored: the completing
implementation agent emits a bounded top-level `sapience_notes` array in `.return-meta.json`, and
a new standalone script invoked from every implement-completion call site performs one
`sapience-remember.sh` call per note, non-fatally, with the 8-note ceiling and the zero-notes gap
enforced at that single site.

The design is wired at **three invocation points across two scripts**, not one: the live
`/orchestrate` path (`orchestrate-cycle-postflight.sh`'s terminal `implemented` arm) and the
deferred path (`reconcile-task-status.sh`'s `implementing)` *and* `partial)` promotion arms),
because the latter bypasses `skill_postflight_update` and every propagation helper entirely.

### Research Integration

The research report's call-site trace is the load-bearing input and was re-verified live:

- `skill_propagate_memory_candidates` (`skill-base.sh:1223`) is fully implemented and has
  **zero live callers** anywhere — confirmed. A function's existence in `skill-base.sh` is
  therefore no evidence of wiring, which is why this plan ends with an explicit grep self-check
  on its own call sites.
- `reconcile-task-status.sh`'s promotion arms call `update-task-status.sh postflight` directly
  (lines 684 and 734), bypassing `skill_postflight_update` (`skill-base.sh:1010`) and
  `skill_orchestrate_propagate_completion` — confirmed; that script greps clean for
  `propagate|completion_summary|memory_candidates`.
- `orchestrate-cycle-postflight.sh`'s terminal propagation calls sit at lines 1439 and 1442 —
  confirmed.
- `sapience-remember.sh` already carries every flag the call site needs
  (`--subject/--value/--predicate/--ko-type/--confidence/--source-loc/--dry-run`), sets
  `explicit: true` unconditionally, and exits non-zero on all three silent-loss response shapes.
  No change to it is planned.
- `issue-record.sh`'s `--class` is a deliberately **open** enum (16 seed classes, lenient
  stderr warning outside them), which is the mechanism for the zero-notes gap.

**Divergence from the research recommendation, with rationale.** Research recommended a new
`skill_propagate_sapience_notes` function inside `skill-base.sh`. This plan uses a **standalone
script** instead, because `reconcile-task-status.sh` does not source `skill-base.sh` at all (it
sources only `lib/common.sh` and `deploy-root-guard.sh`) and sourcing a multi-thousand-line
lifecycle library into a reconcile script to reach one function is disproportionate and
side-effect-prone. A sibling-script subprocess call is already that script's established pattern
for reaching core behavior (`"$SCRIPT_DIR/update-task-status.sh"`), and a standalone script is
also directly testable without a `skill-base.sh` sourcing fixture.

**Second divergence: the script lives in the sapience extension, not core.** Research placed it
in core. Placing it under `agent-system/extensions/sapience/scripts/` mirrors
`sapience-retrieve.sh` exactly, keeps all vault-specific logic inside the extension whose
load/unload is the documented on/off switch for this behavior, and reduces core's change surface
to two small presence-guarded call blocks. Core already hard-references a sapience script with
graceful degradation on absence (`orchestrate-build-dispatch.sh:363`), so the precedent for the
guard is established.

**Correction to a carried figure**: the report cites
`skill_orchestrate_propagate_completion` at `skill-base.sh:1083`; its live definition is at
`skill-base.sh:1746`. All other file:line figures in the report verified exact.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch context; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- A mechanically-anchored write: every implement completion that reaches `[COMPLETED]` attempts
  the repo-tagged write without depending on an agent reading prose.
- Coverage of the deferred-completion path (deploy-gate exit-6 refusal later settled by
  `reconcile-task-status.sh`), not only the live `/orchestrate` path.
- The 3-8 note bound enforced at exactly one site, mechanically at the ceiling.
- Zero notes for a completed task recorded as a visible, non-blocking `issues.jsonl` row.
- An emission instruction that reaches every domain implementation agent, not only
  `general-implementation-agent`.
- Domain docs (`EXTENSION.md`, `per-repo-scoping.md`) stating the resulting design.
- A test suite with the network call stubbed.

**Non-Goals**:
- Changing `sapience-remember.sh` itself — it already implements every needed behavior.
- Fixing `skill_propagate_memory_candidates`'s zero-live-caller gap (pre-existing, unrelated).
- Back-filling `completion_summary`/`roadmap_items` on the deferred reconcile path
  (pre-existing gap the research surfaced; out of scope).
- Wiring the `postflight:pr_ready` -> `completed` transition. Decision recorded here rather than
  deferred as an open question: a `type: pr` task's implementation agent returns its
  `.return-meta.json` at the `implementing -> pr_ready` dispatch, which is where its notes are
  emitted; the later user-invoked `/merge` transition carries no agent return to read. Both
  measured completions (the two tasks in session `sess_1794696615_44948d`) are non-PR, so no
  evidence motivates a third call site. If a `pr_ready` completion is later measured to drop its
  notes, the remedy is one additional guarded call block of the same shape.
- Mechanically enforcing the 3-note *floor*. There is no content to fabricate; the floor stays
  agent-side guidance and the zero case is the only lower-end condition the site can detect.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Only one of the three invocation points gets wired, leaving the deferred path as unreachable as the prose is today | H | M | Phase 3 closes on an explicit grep self-check asserting exactly three invocation points across exactly two scripts; the new suite has a dedicated case per arm |
| Every vault write is permanent (no delete API) and unreviewed; a malformed-array bug could write far more than 8 notes | H | L | The ceiling is a hard `jq length` check performed *before any* `sapience-remember.sh` call is issued, never a running counter; the suite's N>8 case exists to catch regression here |
| Non-general implementation agents (lean/nix/neovim/email) never emit notes, turning the zero-notes gap row into per-completion noise instead of signal | M | H without Phase 4 | Phase 4 injects the emission instruction into every implement dispatch via `orchestrate-build-dispatch.sh`, gated on the extension's presence, reaching every domain agent with no per-agent-file edit |
| `sapience_notes` confused with `memory_candidates` by a future editor, given identical shape conventions | M | M | The `return-metadata-file.md` field spec states explicitly that the two target different stores (local `state.json` vs. the hosted vault) and are not interchangeable |
| A repo without the sapience extension loaded records a spurious gap row on every completion | M | M | The new script's first action is a presence check on its own sibling `sapience-remember.sh`; absent, it exits 0 silently with no issue row — unloaded is not a gap |
| Editing `EXTENSION.md` (a `claudemd` merge source) without regenerating leaves the deployed `.claude/CLAUDE.md` stale, which the completion-deploy gate refuses with exit 6 | M | M | Phase 5 declares the derived `.claude/CLAUDE.md` path; Phase 6 regenerates the whole deployed tree and declares `__WHOLE_TREE__` |
| A new 17th `issue-record.sh` seed class drifts between its two copies (`issue-log.md` table and the script's `ISSUE_SEED_CLASSES` array plus its comment copy) | L | M | Phase 1 treats the three locations as one edit and greps every `16-class`/`16 seed` occurrence under `agent-system/**` before closing |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3 | 2 |
| 4 | 5 | 3 |
| 5 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Contract Surfaces — `sapience_notes` Field Spec and Gap Class [COMPLETED]

**Goal**: Land the two contract surfaces every later phase references — the
`.return-meta.json` field specification and the `issue-record.sh` class the zero-notes gap uses —
so Phases 2 and 4 build against a fixed vocabulary.

**Tasks**:
- [x] Add a `### sapience_notes (optional)` section to
      `agent-system/extensions/core/context/formats/return-metadata-file.md`, sibling to the
      existing `### memory_candidates (optional)` section (currently at line 405) and placed
      immediately after it. Specify: array of 3-8 objects at the **top level**, never nested
      under `completion_data`; producer = the completing implementation agent; consumer = the
      sapience extension's postflight write script. Per-object fields mapping 1:1 onto
      `sapience-remember.sh`'s flags: `subject` (string, required), `value` (string, required),
      `predicate` (string, optional, script default `"finding is"`), `ko_type` (string,
      optional, script default `"insight"`), `confidence` (number, optional, script default
      `0.8`), `source_loc` (string, optional). *(completed)*
- [x] In that same section, state explicitly that `sapience_notes` and `memory_candidates` are
      **not interchangeable**: identical in shape convention, different in destination
      (`memory_candidates` -> local `specs/state.json`; `sapience_notes` -> the hosted vault via
      a tagged `POST /ingest-kos`), and that every `sapience_notes` write is permanent and
      unreviewed, which is why the array is bounded. *(completed)*
- [x] Add one seed-class row to `agent-system/extensions/core/context/formats/issue-log.md`'s
      class table: `knowledge-capture gap` — "a durable knowledge-capture step a completion path
      was supposed to feed produced nothing (an empty agent-authored note set at a task boundary,
      for instance). Records an absent capture, not a backing-service failure. *(completed)*"
- [x] Add the identical string to `agent-system/extensions/core/scripts/issue-record.sh`'s
      `ISSUE_SEED_CLASSES` array (currently 16 entries, starting line 276) **and** to its
      comment-only convenience copy directly above it (lines 268-274). *(completed)*
- [x] Grep every occurrence of `16-class`, `16 seed`, and `16 classes` under
      `agent-system/**` and update each to 17 — at minimum `issue-log.md` (the class-table intro,
      the Extensibility Rule paragraph, and the `class` field row in the schema table) and
      `issue-record.sh` (its header comment at line 17, the inline seed-enum comment at line 268,
      and the lenient-warning message string at line 301). Record the actual count found. *(completed: found 10 occurrences across 4 files, not 2 as hypothesized — issue-log.md (4: class-field row, heading, Extensibility Rule paragraph, Unknown-Class Tally paragraph), issue-record.sh (3), plus two files the plan did not name: orchestrate-conclusion-aggregate.sh's own third unsynced SEED_CLASSES_JSON copy (1) and error-recovery-strategies.md (1); all updated to 17 except issue-log.md's `system_defect`/system-defect-record.sh LEAVE row, which names an unrelated closed enum and is correctly left unchanged)*
- [x] State in the `issue-log.md` edit that this class was seeded on introduction of a
      mechanical writer that emits it, not promoted after recurrence — the promotion path that
      document describes remains for classes first recorded ad hoc. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-central-log-lib.sh,test-dispatch-metrics.sh,test-git-commit-phase.sh,test-git-commit-scoped.sh,test-issue-record.sh,test-lint-agent-contracts.sh,test-orchestrate-batch-admit.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-conclusion-aggregate.sh,test-orchestrate-conclusion-roadmap.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-redeploy-remedy-lib.sh,test-run-task-observers.sh,test-sapience-capture.sh,test-validate-return-meta.sh` is `suite_selection_select`'s verbatim output for this phase's three paths and covers both the edited script and every consumer of the two edited format docs.

**Scope Hypothesis**: the `16`-count strings are expected in exactly two files (`issue-log.md`
and `issue-record.sh`). Confirm by running the grep in the task above across all of
`agent-system/**` before editing, and report the real file/occurrence count in the phase's
verification notes rather than assuming two.

**Files to modify**:
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - adds the new field
  specification section, placed after the memory-candidates section
- `agent-system/extensions/core/context/formats/issue-log.md` - 17th seed class row, plus every
  count reference updated
- `agent-system/extensions/core/scripts/issue-record.sh` - seed-class array entry, its comment
  copy, the header count, and the warning-message count

**Verification**:
- `bash agent-system/extensions/core/scripts/issue-record.sh --task-dir <this task dir>
  --kind issue --class "knowledge-capture gap" --severity minor --what-happened "seed class
  smoke check"` emits **no** `outside the ... seed enum` warning on stderr and exits 0.
- A deliberately bogus `--class` value still warns and still exits 0 (leniency preserved).
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` clean for
  `issue-record.sh`.
- The `--only` suite list in Tier Justification above runs green.
- Grep confirms zero remaining `16-class`/`16 seed`/`16 classes` strings under
  `agent-system/**`.

---

### Phase 2: The Write Script and Its Stubbed Test Suite [IN PROGRESS]

**Goal**: Build the single site where the bound, the zero-notes gap, and the per-note degrade
all live, with a suite that asserts call count and argument shape against a recording stub.

**Tasks**:
- [x] Create `agent-system/extensions/sapience/scripts/postflight-sapience-notes.sh` with
      interface `--task-dir PATH --task N [--session-id S] [--phase P] [--dispatch-seq N]
      [--dry-run]`. Follow `sapience-remember.sh`'s own conventions: `set -euo pipefail`, a
      `SCRIPT_DIR` resolution followed immediately by `. "${SCRIPT_DIR}/deploy-root-guard.sh"
      || exit 1`, a `usage()` heredoc, and a header comment block stating the contract. *(completed)*
- [x] Presence guard first: if `${SCRIPT_DIR}/sapience-remember.sh` is absent, exit 0 silently
      with no issue row. An unloaded extension is not a knowledge-capture gap. *(completed)*
- [x] Read `sapience_notes` from `<task-dir>/.return-meta.json` with
      `jq -c '.sapience_notes // []'`, failing closed to `[]` on a missing, unreadable, or
      malformed file. The script performs this read itself so that neither call site depends on
      a value threaded through propagation machinery the reconcile path does not exercise. *(completed)*
- [x] Compute the array length **once** via `jq 'length'` before issuing any write. On
      `length > 8`: slice to the first 8 with `jq -c '.[0:8]'`, emit a named warning on stderr,
      and record one `issue-record.sh` entry (`--class "tooling bug or gap" --severity minor`)
      naming the emitted and the honored count. This must be a pre-write length check, never a
      counter incremented inside the loop. *(completed)*
- [x] On `length == 0`: skip the loop entirely and record exactly one `issue-record.sh` entry
      (`--class "knowledge-capture gap" --severity minor --resolution open`) whose
      `--what-happened` names the task number and states that no notes were emitted at
      completion. Exit 0. *(completed)*
- [x] For each honored note, invoke `sapience-remember.sh` once with `--subject` and `--value`
      from the entry, plus `--predicate`/`--ko-type`/`--confidence`/`--source-loc` only when the
      corresponding key is present and non-null (so the script's own defaults apply otherwise).
      Pass `--dry-run` through when `--dry-run` was given to this script. Read each field with
      `jq -r` into a shell variable and pass it as a single argument — never build the argv by
      string interpolation, so a note containing quotes or newlines cannot break the call. *(completed)*
- [x] Per-note degrade: a non-zero exit is mirrored by one `issue-record.sh` entry
      (`--class "infrastructure/transport unavailable" --severity minor --resolution
      worked_around`) carrying that call's stderr, and the loop **continues** to the remaining
      notes. Never abort on first failure, never retry. *(completed)*
- [x] Exit 0 on every degrade path; reserve non-zero for a usage error (missing `--task-dir` or
      `--task`) so a caller's `|| note` guard distinguishes misuse from a degraded write. Every
      `issue-record.sh` call is itself `|| true`-guarded: a recording failure never fails this
      script. *(completed)*
- [ ] Register both new files in `agent-system/extensions/sapience/manifest.json`'s
      `provides.scripts` array: `postflight-sapience-notes.sh` and
      `tests/test-postflight-sapience-notes.sh`, keeping the array's existing alphabetical
      order.
- [ ] Create `agent-system/extensions/sapience/scripts/tests/test-postflight-sapience-notes.sh`
      following `test-sapience-capture.sh`'s conventions exactly: `common_test_pass/_fail/_info`
      from `lib/common.sh`, `PASSED`/`FAILED` integer counters, a `mktemp -d` workdir with
      `trap ... EXIT` cleanup, and that suite's two-candidate `lib/common.sh` bootstrap (sapience
      has no `scripts/lib/` of its own, so the source-store fallback to core's copy is required).
      Resolve the repo root via `common_test_repo_root`, never a fixed-depth `cd ../../..` walk —
      `lint-test-root-resolution.sh` (gate 29) flags the latter from a `scripts/tests/` file.
- [ ] Stub `sapience-remember.sh` itself, not `curl`: a recording executable in a scratch
      directory that appends its full argv to a recorder file and exits with a dispatchable
      status. PATH-shadowing is insufficient here because the script under test calls its
      sibling by `${SCRIPT_DIR}/`-qualified path, so the fixture must place the stub as a
      sibling of a copy of the script under test inside the workdir (together with a stub
      `deploy-root-guard.sh` satisfying its `|| exit 1`). Record the chosen mechanism in the
      suite's header comment.
- [ ] Cases: (1) `N == 0` — zero stub calls, exactly one `knowledge-capture gap` row in the
      fixture's `issues.jsonl`, exit 0; (2) `N == 1` and (3) `N == 8` — exactly N stub calls with
      `--subject`/`--value` matching the fixture's own minted values (never a hardcoded literal),
      no gap row; (4) `N == 12` — exactly 8 stub calls and exactly one `tooling bug or gap` row;
      (5) one stub call failing mid-run within an otherwise-normal N — exactly one
      `infrastructure/transport unavailable` row **and** the remaining notes still attempted
      (assert the full call count, which is what distinguishes continue-on-failure from
      abort-on-first-failure); (6) absent sibling `sapience-remember.sh` — exit 0, zero stub
      calls, **zero** issue rows; (7) a note whose `value` contains a double quote and a newline
      arrives at the stub as one intact argument; (8) `--dry-run` propagates `--dry-run` into
      every stub invocation; (9) a missing or malformed `.return-meta.json` is treated as `N == 0`
      (one gap row, exit 0), not as a crash.
- [ ] Add one TAB-separated row to
      `agent-system/extensions/core/scripts/tests/suite-classification.data`:
      `test-postflight-sapience-notes.sh	unit	-`. Required even though the suite lives under a
      different extension — that file's own SCOPE NOTE states every suite in the merged deployed
      `tests/` set needs a row, and `lint-unit-integration-boundary.sh` fails loudly on an
      unclassified suite.
- [ ] Leave `suite-cost-hints.txt` untouched: that file is mechanically generated by
      `measure-gate-costs.sh --regen-hints` and is explicitly advisory — an unhinted suite keeps
      discovery order and nothing is skipped.

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns the sentinel `__FULL_SWEEP__` for this phase's path set because its two new files are unmapped, so no suite covers them and none is claimed here; the honest covering check is the gate subset `bash .claude/scripts/verify-deploy.sh --only-gate 4,22 /home/benjamin/.config/nvim` (task-reference lint and shellcheck over the two new shell files) run together with the `local` row's own single-module lint pass, whose concrete commands this phase's Verification section enumerates.

**Scope Hypothesis**: the suite is expected to need no new shared fixture library and no
`run-all.sh` change — it is discovered by basename from the tests directory. Confirm by running
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-postflight-sapience-notes.sh`
against the **deployed** tree after Phase 6's redeploy; if discovery requires anything beyond the
classification row, report it rather than silently adding a runner change to this phase.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/postflight-sapience-notes.sh` - new: the single
  bound-enforcing, gap-recording, per-note-degrading write site
- `agent-system/extensions/sapience/scripts/tests/test-postflight-sapience-notes.sh` - new:
  9-case suite with the write primitive stubbed
- `agent-system/extensions/sapience/manifest.json` - registers both new scripts in the
  provides-scripts array
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - classification row
  for the new suite

**Verification**:
- The new suite exits 0 with all 9 cases PASS and `FAILED == 0`.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` clean for both new files.
- `bash agent-system/extensions/core/scripts/lint/lint-unit-integration-boundary.sh` reports no
  unclassified suite.
- `bash agent-system/extensions/core/scripts/lint/lint-test-root-resolution.sh` clean for the new
  suite.
- A live, un-stubbed `--dry-run` smoke run against this task's own directory prints the
  `[repo:<slug>]`-tagged, token-redacted request body for each note and makes no network call —
  the "dry-run before real write" obligation `per-repo-scoping.md`'s call-site contract already
  states.
- The `--only` suite list in Tier Justification above runs green.

---

### Phase 3: Wire the Three Completion Invocation Points [NOT STARTED]

**Goal**: Make the write fire on both the live and the deferred completion paths, each site
guarded on the extension's presence and each non-fatal.

**Tasks**:
- [ ] In `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`, add the call
      inside the `implemented)` case's `is_live` branch, immediately after the existing
      `skill_orchestrate_propagate_completion` calls (lines 1439 and 1442) — placed once, after
      the `if [ "$skeleton_active" = "true" ]` / `else` fork closes, so both the skeleton and
      non-skeleton paths reach it without duplicating the block.
- [ ] Gate that call on `postflight_rc` being 0. On `postflight_rc == 6` the completion-deploy
      gate refused the transition and the task is **not** completed; writing notes there would
      produce a permanent vault write for a task still in flight, and the reconcile arms wired
      below cover that task when the next cycle's Inter-Cycle Redeploy Checkpoint settles it.
      State this reasoning in a comment at the call site.
- [ ] Guard on presence and make the call non-fatal:
      `[ -f "${SKILL_REPO_ROOT}/.claude/scripts/postflight-sapience-notes.sh" ] && bash
      "${SKILL_REPO_ROOT}/.claude/scripts/postflight-sapience-notes.sh" --task-dir "$TASK_DIR"
      --task "$task_number" --session-id "$session_id" --phase implement
      ${handoff_dispatch_seq:+--dispatch-seq "$handoff_dispatch_seq"} || echo "Note:
      postflight sapience note write failed (non-fatal)" >&2`. Use `SKILL_REPO_ROOT`-qualified
      paths, matching this script's existing collaborator-call convention.
- [ ] Add the matching `[dry-run]` notice to the existing `else` branch (the one already printing
      "would transition task ... to completed and propagate completion_summary/roadmap_items"),
      so a dry-run cycle states that the note write would also have been attempted.
- [ ] In `agent-system/extensions/core/scripts/reconcile-task-status.sh`, add the same guarded,
      non-fatal call in **both** promotion arms: the `implementing)` arm immediately after its
      `promoted implementing -> completed` log line (line 695) and the `partial)` arm immediately
      after its `promoted partial -> completed` log line (line 742). Place each inside the live
      (non-`DRY_RUN`) branch only, after the `reconcile_rc` success checks, so a refused or failed
      promotion never triggers a write.
- [ ] Resolve the paths in that script from the variables already in scope: `$PROJECT_ROOT` for
      the deployed script path, `$TASK_DIR` (line 139) for `--task-dir`, `$task_number`, and
      `$session_id` (line 103). Pass `--phase implement` and no `--dispatch-seq` (the reconcile
      path has none). Add the corresponding "would also attempt" line to each arm's `DRY_RUN`
      branch.
- [ ] Add reconcile-arm cases to `agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh`
      — the existing suite that already owns reconcile promotion-arm fixtures — asserting that
      both the `implementing)` and `partial)` arms invoke the write script on a successful
      promotion, do **not** invoke it when the arm refuses with `reconcile_rc == 4`, and do not
      invoke it under `--dry-run`. Keep these cases in this suite rather than in the new sapience
      suite: the subject under test here is the reconcile arm, not the write primitive.
- [ ] Close the phase on an explicit grep self-check: `grep -rn
      "postflight-sapience-notes.sh" agent-system/extensions/core/scripts/` must report
      **exactly three** invocation lines across **exactly two** files (one in
      `orchestrate-cycle-postflight.sh`, two in `reconcile-task-status.sh`), plus whatever
      non-invocation comment lines the edits added. Report the actual counts. A function or
      script existing in this codebase is not evidence it is called — this check is the evidence.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-corroborate-phase-counts.sh,test-deploy-baseline-lib.sh,test-force-phases.sh,test-gate-out-derived-staleness.sh,test-git-commit-scoped.sh,test-handoff-dispatch-identity.sh,test-handoff-reader-parity.sh,test-lint-deliberate-break-residue.sh,test-lint-json-channel-discipline.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-recover-message-findings.sh,test-reconcile-demote-stranded.sh,test-reconcile-handoff-status.sh,test-redeploy-checkpoint-promotion.sh,test-run-task-observers.sh,test-skill-base-lifecycle.sh,test-stall-reprompt-wiring.sh` is `suite_selection_select`'s verbatim output for this phase's two paths and covers both edited scripts' own regression suites including all three reconcile/postflight promotion suites.

**Scope Hypothesis**: three invocation points across two files is the asserted scope. The
implementer confirms it with the grep self-check in the final task above, and reports the real
count; a fourth live `implement -> completed` transition found during the edit (for example a
third reconcile arm) is a scope-hypothesis miss to report, not to absorb silently.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - one guarded,
  return-code-gated, non-fatal call in the terminal implemented branch, plus the matching
  dry-run notice
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` - the same guarded call in
  both promotion arms, plus their dry-run notices
- `agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh` - adds the
  reconcile-arm invocation, refusal, and dry-run cases

**Verification**:
- The grep self-check reports exactly three invocation lines across exactly two files.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` clean for both edited
  scripts.
- `bash agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh` exits 0
  with the new reconcile-arm cases passing, and
  `bash agent-system/extensions/sapience/scripts/tests/test-postflight-sapience-notes.sh` still
  exits 0 with `FAILED == 0`.
- `agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh` (gate 9) is **not
  applicable** to this phase: it lints `SKILL.md` files only, and this phase edits no skill.
  State that explicitly rather than reporting a vacuous pass.
- The `--only` suite list in Tier Justification above runs green.

---

### Phase 4: Emission Instruction Surfaces [NOT STARTED]

**Goal**: Make every completing implementation agent — in every domain, not only
general/meta/markdown — actually author the notes the mechanical site writes.

**Tasks**:
- [ ] Add `### Stage 6c: Emit Sapience Notes` to
      `agent-system/extensions/core/agents/general-implementation-agent.md`, immediately after
      Stage 6b (which currently ends at line 857) and before Stage 7. Mirror Stage 6b's
      structure: a cardinality line (3-8 notes), a "What to capture" list, a "What NOT to
      capture" list, and a per-object construction list.
- [ ] Scope the capture guidance to *durable, cross-session* findings — a decision and its
      rationale, a measured fact about an external system, a correction to a previously-held
      belief, a non-obvious constraint discovered in the work — and distinguish it explicitly
      from Stage 6b's in-repo reusable-pattern framing, naming the different destinations.
      State that fewer than 3 notes is recorded as a visible gap and that more than 8 are
      truncated at the write site, so the bound is worth respecting.
- [ ] Update that agent's Stage 7 write-up line (line 860) to name `sapience_notes` alongside
      `memory_candidates` and `modified_files` as a top-level field, and add
      `"sapience_notes": []` to the worked `.return-meta.json` example (near line 883) so the
      shape is visible rather than only described.
- [ ] In `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`, add a short
      `sapience_notes` instruction block to the dispatch body, emitted only when `$phase` is
      `implement` **and** `${SKILL_REPO_ROOT}/.claude/scripts/sapience-remember.sh` exists.
      Model its placement and presence-gating on the existing Stage 3.5 `memory_context` block
      (lines 349-381); this is the one edit that reaches the lean, nix, neovim, and email
      implementation agents, none of which has a memory-candidates stage, without editing five
      agent files.
- [ ] Keep that block short (a few lines: the field name, the 3-8 bound, the one-sentence
      capture framing, and a pointer to `return-metadata-file.md`'s field spec) and keep it out
      of the `--clean` suppression path — `--clean` suppresses memory *retrieval*, not the
      agent's own obligation to report what it learned.
- [ ] Add a case to `test-orchestrate-build-dispatch.sh` asserting the block is present for
      `phase=implement` with the script present, and absent for `phase=research`/`phase=plan`
      and when the script is absent.
- [ ] Name no task numbers in any of these files (all lie outside `specs/**`), and state the
      design on its own merits — no "replacing", "previously", "no longer", or supersession
      framing, per `no-task-references-in-deliverables.md` and
      `no-record-versioning-in-deliverables.md`.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-force-phases.sh,test-lint-agent-contracts-heartbeat.sh,test-lint-agent-contracts.sh,test-orchestrate-build-aux-dispatch.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-record-decision.sh,test-orchestrate-recover-message-findings.sh,test-orchestrate-unwind-dispatch.sh,test-routing-resolution.sh` is `suite_selection_select`'s verbatim output for this phase's two paths and covers the agent-contracts lint plus every dispatch-builder suite the injected block could break.

**Scope Hypothesis**: the injected block is asserted to add no measurable eager-context cost to
non-implement dispatches, since it is phase-gated. Confirm with
`bash agent-system/extensions/core/scripts/measure-eager-context.sh --check` (gate 20's own
budget lock) and report the delta rather than assuming zero.

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` - new Stage 6c, Stage 7
  field mention, worked-example field
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - phase- and
  presence-gated `sapience_notes` instruction block
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - presence,
  phase-gating, and absence cases for the new block

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` clean.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` clean for the dispatch
  builder.
- `bash agent-system/extensions/core/scripts/measure-eager-context.sh --check` within budget.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` and
  `bash agent-system/extensions/core/scripts/check-record-versioning.sh` clean for the edited
  files.
- The `--only` suite list in Tier Justification above runs green.

---

### Phase 5: Sapience Domain Docs State the Wired Design [NOT STARTED]

**Goal**: Make `EXTENSION.md` and `per-repo-scoping.md` describe the mechanism that now exists,
so a reader is not told the write depends on following an instruction.

**Tasks**:
- [ ] Rewrite `agent-system/extensions/sapience/EXTENSION.md`'s **Postflight wrapup** paragraph
      (lines 22-28) to state the mechanical design: the completing implementation agent emits
      3-8 notes in `.return-meta.json`'s top-level `sapience_notes` array;
      `scripts/postflight-sapience-notes.sh` performs one `sapience-remember.sh` call per note at
      the `[IMPLEMENTING]` -> `[COMPLETED]` transition, on both the live and the deferred
      completion paths; the 8-note ceiling and the zero-notes gap are enforced at that one site.
      Keep the existing degrade rule sentence and the existing `sapience_remember`
      counter-instruction (both still correct). Keep the sentence naming the untagged
      `sapience_wrapup` replacement — that is the sanctioned D3 design decision, not draft
      lineage.
- [ ] Add `scripts/postflight-sapience-notes.sh` to EXTENSION.md's **What this extension adds**
      paragraph (lines 15-20), which currently names two deployed scripts; it becomes three.
      Update that paragraph's own count wording accordingly.
- [ ] Rewrite `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`'s
      `## The Tagged-Write Call Site` section (line 78) to name
      `scripts/postflight-sapience-notes.sh` and its three invocation points across
      `orchestrate-cycle-postflight.sh` and `reconcile-task-status.sh`'s two promotion arms,
      instead of "`EXTENSION.md`'s postflight wrapup instruction". Keep all three bullets of the
      call-site contract (Bound, Dry-run before real write, Degrade rule) and extend the Bound
      bullet to state which half of 3-8 is mechanical (the ceiling, as a pre-write length check)
      and which is agent-side guidance (the floor, with the zero case recorded as a visible gap).
- [ ] Add one sentence to that file's `## No Lifecycle Hook` section (line 99) noting that the
      write site sidesteps the `hooks.postflight` gating entirely by living in a script the core
      completion paths invoke directly, rather than depending on extension-hook dispatch. Leave
      the section's `skill_get_extension_dir()` reasoning substantively unchanged — it is still
      correct, and its final sentence ("it is why the call site lives in the instruction-level
      postflight wrapup text instead") is the one clause that needs updating to point at the new
      site.
- [ ] Update `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`'s
      Hazards section only if its permanent/unreviewed-write census is now inaccurate — the new
      site does not add a write path, it mechanizes the existing one, so the census count should
      be unchanged. Confirm by reading it; report either way.
- [ ] Verify compliance with `rules/sapience-write-path.md`: the new prose must name
      `scripts/sapience-remember.sh` (via `postflight-sapience-notes.sh`) as the only prescribed
      write path and must not name any MCP write tool as a path a write should take. The inherited
      3-8 bound is the same bound, not a second independently-sized one — state that explicitly.
      That rule also states its governed surface is "14 files under the source store path"; this
      phase adds files under that path, so check whether that count needs updating and report it.
- [ ] No task numbers, no record-versioning language in either file.

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this phase's two markdown paths (no suite maps them), so the honest covering check is sub-case (b)'s `bash .claude/scripts/verify-deploy.sh --only-gate 3,4 /home/benjamin/.config/nvim` — the repository root, which holds both a deployed `.claude/` tree and the source store — run together with the `prose` row's own diff read-through.

**Files to modify**:
- `agent-system/extensions/sapience/EXTENSION.md` - postflight wrapup paragraph rewritten, and
  the third deployed script named
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` - the
  tagged-write call-site section rewritten, and one sentence added to the no-lifecycle-hook
  section
- `__WHOLE_TREE__` - coupled generated surface: `EXTENSION.md` is the `claudemd` merge source
  (`merge_targets.claudemd`, `section_id: extension_sapience`), so this phase moves the input
  that the deployed `CLAUDE.md` section and the deployed context mirror both derive. The
  sentinel is the sanctioned way to declare that claim — a deployed-tree path is never a
  legitimate `file_scope` member. The regeneration itself runs in Phase 6, which is correct here
  because the check that detects this drift (gate 5's content-hash equality, and the
  completion-deploy gate) is not commit-blocking within this phase

**Verification**:
- Diff read-through confirming every changed hunk lies in prose, with no cross-reference left
  pointing at a call site that no longer exists.
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4 /home/benjamin/.config/nvim` reports
  no findings for either edited file.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` and
  `bash agent-system/extensions/core/scripts/check-record-versioning.sh` clean for both files.
- Grep confirms no MCP write tool (`sapience_remember`, `sapience_wrapup`, `sapience_handoff`,
  `sapience_adddoc`) is named as a prescribed write path in either edited section.

---

### Phase 6: Redeploy and Full Gate Sweep [NOT STARTED]

**Goal**: Regenerate the deployed tree so the new script, suite, agent stage, merged CLAUDE.md
section, and context mirror are live, and prove the whole change green against the complete gate
set.

**Tasks**:
- [ ] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the deployed `.claude/` tree
      from the source store. This is the only sanctioned writer of every `.claude/**` path this
      task's edits derive, including `.claude/CLAUDE.md`'s merged sapience section, the deployed
      `postflight-sapience-notes.sh`, and the merged `tests/` directory the new suite must appear
      in for `run-all.sh` to discover it.
- [ ] Confirm post-deploy presence: `.claude/scripts/postflight-sapience-notes.sh`,
      `.claude/scripts/tests/test-postflight-sapience-notes.sh`, the `sapience_notes` section in
      `.claude/context/formats/return-metadata-file.md`, and the rewritten
      `.claude/CLAUDE.md` sapience postflight paragraph.
- [ ] Run `bash .claude/scripts/tests/run-all.sh` against the deployed tree and confirm the new
      suite is discovered by basename, is classified, and passes there — a source-store-only pass
      is not evidence for the merged set.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` (the complete 29-gate battery) and confirm
      green, with particular attention to gate 5 (manifest-driven category parity plus
      content-hash equality, which the two new sapience `provides.scripts` entries must satisfy),
      gate 8 (the full shell-suite battery, now including the new suite), gate 3, gate 4,
      gate 22, and gate 29.
- [ ] End-to-end attestation with the network call stubbed: construct a throwaway fixture task
      directory carrying a `.return-meta.json` with 4 `sapience_notes`, invoke
      `bash .claude/scripts/postflight-sapience-notes.sh --task-dir <fixture> --task 0 --dry-run`,
      and confirm four `[repo:<slug>]`-tagged, token-redacted request bodies are printed, zero
      network calls are made, and no issue rows are recorded. Then re-run with an empty array and
      confirm exactly one `knowledge-capture gap` row.
- [ ] Report any gate that could not be run and why, rather than reporting an unqualified pass.

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`; the
  reserved sentinel serializes this task against any concurrent task that would also regenerate
  the deployed tree
- No source-store file is edited in this phase; it regenerates and verifies only

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 with no FINDING lines across all 29 gates.
- `bash .claude/scripts/tests/run-all.sh` exits 0 against the deployed tree, with
  `test-postflight-sapience-notes.sh` among the discovered-and-passed suites.
- The dry-run end-to-end attestation above produces the stated output on both the 4-note and the
  0-note fixture.

---

## Testing & Validation

- [ ] `test-postflight-sapience-notes.sh` passes all cases against both the source store and the
      deployed tree, with `sapience-remember.sh` stubbed (no network call on any case).
- [ ] The N=0, N=8, N=12, and mid-run-failure cases each assert exact stub call counts and exact
      `issues.jsonl` row counts — the bound and the degrade behavior are asserted, not assumed.
- [ ] The extension-absent case records zero issue rows, so an unloaded extension produces no
      false gap signal.
- [ ] `test-orchestrate-build-dispatch.sh` asserts the emission block's phase- and
      presence-gating.
- [ ] Reconcile-arm cases assert the write fires on a successful promotion and not on a refused
      one (`reconcile_rc == 4`).
- [ ] The grep self-check in Phase 3 confirms exactly three invocation points across exactly two
      scripts.
- [ ] `bash .claude/scripts/verify-deploy.sh` green post-deploy.
- [ ] A live `--dry-run` attestation prints the `[repo:<slug>]`-tagged, token-redacted body for
      each note.

## Artifacts & Outputs

- `agent-system/extensions/sapience/scripts/postflight-sapience-notes.sh` (new)
- `agent-system/extensions/sapience/scripts/tests/test-postflight-sapience-notes.sh` (new)
- Edited: `agent-system/extensions/sapience/manifest.json`,
  `agent-system/extensions/sapience/EXTENSION.md`,
  `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
- Edited: `agent-system/extensions/core/context/formats/return-metadata-file.md`,
  `agent-system/extensions/core/context/formats/issue-log.md`,
  `agent-system/extensions/core/scripts/issue-record.sh`,
  `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
  `agent-system/extensions/core/scripts/reconcile-task-status.sh`,
  `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`,
  `agent-system/extensions/core/agents/general-implementation-agent.md`,
  `agent-system/extensions/core/scripts/tests/suite-classification.data`,
  `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh`
- Regenerated: the deployed `.claude/**` tree, including `.claude/CLAUDE.md`'s merged sapience
  section
- `specs/635_enforce_sapience_postflight_wrapup_write/summaries/01_*-summary.md`

## Rollback/Contingency

Every phase is committed separately, so a revert is per-phase. No vault write is permanent until
Phase 6's attestation is run without `--dry-run`, and the attestation steps in Phases 2 and 6 are
both `--dry-run` — so a defect found before the next real task completion costs nothing
irreversible. If a defect is found *after* real notes land, note that there is no delete API on
this vault (deletion is web-app-only), so the containment move is to revert the Phase 3 wiring
commit first, which stops further writes immediately, and only then diagnose.

If the mechanism proves too noisy in practice (a gap row on every completion because domain
agents do not author notes despite Phase 4), the cheapest intervention is narrowing the
zero-notes row's severity or scoping the gap record to task types whose agents carry the Stage 6c
instruction — a one-line change inside the single write site, not a redesign.
