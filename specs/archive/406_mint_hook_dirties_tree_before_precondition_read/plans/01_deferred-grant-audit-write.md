# Implementation Plan: Task #406

- **Task**: 406 - Mint hook dirties tree before precondition read
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: None (coordinates with, but does not depend on, the separate `sweep_task_support_file_tracked_or_ignored` task, which owns `specs/events.jsonl`'s tracked-vs-ignored classification)
- **Research Inputs**: specs/406_mint_hook_dirties_tree_before_precondition_read/reports/01_mint-hook-audit-ordering.md
- **Artifacts**: plans/01_deferred-grant-audit-write.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

A `UserPromptSubmit` mint hook (`hooks/please-grant.sh`) synchronously appends a
`push_grant_issued` record to the tracked `specs/events.jsonl` before the command body it minted
for ever runs, so `skill-tag`'s own clean-tree precondition reads dirt the hook itself just
created and refuses every invocation in any repository that tracks that log. The same
synchronous-append shape in `pg_grant_consume` dirties the log on every push, producing a
push-then-commit-then-push loop. This plan makes both audit writes **deferred**: mint and consume
append to a self-ignored buffer inside the existing grant directory, and a single new flush
drains that buffer into `specs/events.jsonl` from the already-registered `Stop`/`SubagentStop`
hook — the one pipeline point guaranteed to run after the current turn's whole command body and
strictly before the next turn's `UserPromptSubmit`. Definition of done: a mint leaves the git
tree byte-identical, the audit record for a minted-but-never-consumed grant still reaches
`specs/events.jsonl`, the push loop is gone, and new regression cases pin all three.

### Research Integration

Findings integrated from `reports/01_mint-hook-audit-ordering.md`:

- The full synchronous call chain was confirmed by direct read, not inference:
  `please-grant.sh` -> `pg_grant_mint` (`scripts/lib/push-grant-lib.sh:473`) ->
  `pg_events_append_observable` (line 480-482) -> `scripts/events-append.sh` -> a real append to
  the tracked `specs/events.jsonl`.
- The secondary loop's mechanism was traced precisely: `skill-tag`'s raw `git push` is
  intercepted by `hooks/guard-git-push.sh` (`PreToolUse`), which calls `pg_grant_consume`
  (`push-grant-lib.sh:492-506`), which appends `push_grant_consumed` **before** the push tool
  call executes. One synchronous-append fix therefore covers both symptoms.
- The grant directory is already self-ignoring: `pg_dir_ensure`
  (`push-grant-lib.sh:130-139`) writes a `.gitignore` containing literal `*` on first use. A
  buffer file placed there needs **no new ignore rule in any repository**, and
  `hooks/guard-git-push.sh`'s existing tamper-guard already covers everything under the grant
  directory prefix, so the buffer inherits the grant files' tamper-resistance for free.
- `hooks/events-log-lifecycle.sh` is already registered on both `Stop` and `SubagentStop` and
  already performs equivalent-shaped deferred work (its `.postflight-pending` enumerate-and-drain
  path), so the flush point reuses an established pattern rather than inventing one.
- Two existing assertions are coupled to the current synchronous timing and **will fail by
  design** the moment the write path changes: `scripts/tests/test-please-grant.sh:223` and
  `scripts/tests/test-guard-git-push.sh:294` both `tail -n1 specs/events.jsonl` immediately after
  the hook/wrapper call. Updating both is in-scope here, not a surprise for implementation time.
- Blast radius was re-measured over the **full source store** rather than the deploy: `/pr`
  (`extensions/cslib/commands/pr.md`) *is* a mint prefix and *does* run
  `git status --porcelain`, but its checks are shaped as "commit the dirt", not "refuse on dirt",
  so it absorbs mint-time dirt instead of failing on it. `skill-orchestrate` and
  `skill-cslib-vet` have porcelain checks but are not mint prefixes. The correct framing is
  therefore not "only skill-tag has a porcelain check" but "any future **refusal**-shaped
  porcelain check on any mint prefix inherits this bug" — which is the argument for fixing the
  cause.

One measured correction to the dispatch's own description, recorded here so the implementer does
not hunt for a step that is not there: the refusing clean-tree check lives in `skill-tag`'s
**Step 2, "Validate Git State"** (the `if [ -n "$(git status --porcelain)" ]` block), not Step 1
as the dispatch and the research report both call it. Step 1 is flag parsing. The behavior
described is otherwise exactly as reported; only the step label differs. Reference it by its
heading text, never by number.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and `roadmap_flag` is not set, so no roadmap
phases are added and no roadmap consultation was performed.

## Goals & Non-Goals

**Goals**:

- Make `pg_grant_mint` and `pg_grant_consume` leave the git working tree byte-identical, so no
  mint or consume can ever dirty a tracked file ahead of a command's own precondition read.
- Fix the class, not the `/tag` symptom: the fix lives in the shared library every mint prefix
  (`/please`, `/merge`, `/tag`, `/pr`) routes through, so a future command adding a
  refusal-shaped clean-tree check inherits the fix rather than the bug.
- Preserve the audit guarantee in full, including — explicitly — the record of a grant that is
  minted and then abandoned, refused, revoked, or expired.
- Eliminate the `push_grant_consumed` push-then-commit loop in the same mechanism, not via a
  second differently-shaped fix.
- Add regression cases that pin the ordering invariant directly, independent of the
  markdown-prose `skill-tag` body.
- Leave a durable in-code record of the adopted direction so the invariant is not silently
  re-broken by a future edit to either side of it.

**Non-Goals**:

- Gitignoring `specs/events.jsonl`. Ruled out by the dispatch: it hides the symptom without
  fixing the ordering class, and it is a per-repository provenance policy change rather than a
  system fix.
- Classifying `specs/events.jsonl` as tracked or ephemeral. That is the
  `sweep_task_support_file_tracked_or_ignored` task's business.
  `scripts/lib/runtime-file-patterns.sh` and `context/standards/orchestrator-runtime-files.md`
  are **not touched by this plan** and must remain unmodified.
- Narrowing `skill-tag`'s porcelain check to ignore one filename. Retained only as the documented
  fallback (see Risks & Mitigations) if the flush point proves infeasible.
- Running or verifying `/tag` itself end-to-end. `/tag` is user-only; an agent verifies only at
  the library and test-suite level.
- Any change to `scripts/events-append.sh`. The buffer-then-flush design reuses it unchanged
  through the existing `pg_events_append_observable` wrapper, so no writer-side change is needed.

## Decision Record: Direction Adopted

**Adopted: deferred/buffered audit write with a Stop-hook flush.** Not the
`skill-tag`-narrowing fallback.

Reasons, in the order the dispatch's SCOPE asks for them:

1. It fixes the class. The change is in `scripts/lib/push-grant-lib.sh`, which every mint prefix
   and every consumer (`guard-git-push.sh`, `git-push-granted.sh`, `guard-destructive-git.sh`)
   already routes through. Narrowing `skill-tag` would fix exactly one command and leave the next
   refusal-shaped porcelain check — plausibly a tightened `/pr`, which is already a mint prefix
   with porcelain checks — to rediscover the bug.
2. It preserves the audit guarantee **by construction** rather than by a special case. See the
   next subsection.
3. It fixes the secondary push loop in the same mechanism, because `pg_grant_consume` buffers
   through the identical path. The fallback would need a separate, differently-shaped fix for the
   loop and would still leave other commands' pushes dirtying the log.

### What happens to a grant that is minted and then abandoned, refused, revoked, or expired

The `push_grant_issued` buffer record is written **at mint time**, unconditionally, and is
entirely independent of the grant `.kv` file's later fate. `pg_grant_revoke`
(`push-grant-lib.sh:510-518`) deletes only the live grant token; it does not and must not touch
the buffer. The Stop-hook flush drains the buffer **unconditionally**, with no "was this grant
used?" branch anywhere. So an abandoned, refused, revoked, or expired grant's `push_grant_issued`
line reaches `specs/events.jsonl` by exactly the same path a consumed one does — the
forensically interesting minted-but-unused case is preserved with no special casing, which is
strictly more robust than a conditional emit would be.

The buffer is durable, on-disk, and append-only, so it does not depend on any hook firing to
survive: a session that crashes before `Stop` leaves pending records for the next session's
flush to drain. Nothing is lost unless the buffer file itself is deleted, which is no worse than
`specs/events.jsonl` itself being deleted today.

### Timestamp semantics (stated now so it is not rediscovered later)

A flushed event's own `timestamp` field honestly reflects **flush** time, because the flush is
the one real append and `events.jsonl` lines are never reordered or mutated. The true moment of
the mint or consume is carried forward in the event's `detail` as `recorded_at`. Neither
backdating the append nor silently dropping the original moment is acceptable.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A skipped flush point (crash, or a future Claude Code that stops firing `Stop`) silently loses audit records | H | L | Buffer is durable, append-only, and on-disk independent of any hook firing; a missed flush simply leaves records for the next session's flush. `pg_audit_flush` is also callable directly as a manual drain path. Flush truncates the buffer only after every line's durable append has succeeded |
| The two coupled test assertions fail the moment the write path changes | M | H (certain by design) | Already located precisely (`test-please-grant.sh:223`, `test-guard-git-push.sh:294`); both are updated in the same phase as the rewiring (Phase 2), so no suite is ever left red across a phase boundary |
| A flush partially succeeds, re-appending already-drained lines on the next flush | M | L | Drain is all-or-nothing per flush: lines are appended first, and the buffer is truncated only after every append returned success. A failed append leaves the buffer intact for retry, preferring a possible duplicate over a lost audit record (`events-format.md` consumers can dedupe; a dropped consent record is unrecoverable) |
| A second `/tag` retry in the same session, before any commit, still fails the clean-tree check | L | M | By design, and not a regression: after the flush the dirt is an ordinary across-turn dirty-tree fact the operator commits, not a structural impossibility. Stated explicitly in the summary so acceptance testing does not misread it |
| Concurrent writers racing on the buffer file | M | L | `flock` on a sibling lock file inside the grant directory, mirroring `events-append.sh`'s own `flock` idiom. A separate lock path means zero contention with the real log |
| A future edit re-introduces a synchronous append from a pre-command hook | M | M | Phase 5 records the invariant in `push-grant-lib.sh`'s own Audit header, in `context/formats/events-format.md` as a named pattern, and as a comment at `skill-tag`'s clean-tree check so both sides of the contract carry it |
| Fallback needed (flush point infeasible) | M | L | Documented fallback: filter the literal path `specs/events.jsonl` out of `skill-tag`'s "Validate Git State" porcelain output before the dirty/clean decision. Strictly inferior (fixes one command, not the class; does nothing for the push loop); adopt only on a measured infeasibility finding, and record the reversal in the summary |
| An agent editing or testing these files trips `guard-git-push.sh`'s tamper guard, whose Bash arm is a coarse substring check on the command text | M | H (observed during planning) | The guard refuses any Bash command whose text mentions the grant directory path, even one that only describes it. Implementation must use the Write/Edit tools (whose arm matches the target path only, not the content) for any file content naming that path, and must not construct such paths in shell heredocs. Fixture tests reach the buffer through the library's own accessors rather than by naming the path in a Bash command |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Add the deferred-audit buffer primitives [COMPLETED]

**Goal**: `pg_audit_buffer` and `pg_audit_flush` exist, are correct in isolation, and are not
yet called by anything — a green, committable intermediate that changes no observable behavior.

**Tasks**:
- [x] Add `pg_audit_buffer_path()` returning the pending-audit JSONL file inside
  `pg_grant_dir`, and a sibling lock-path accessor, placed alongside the existing
  `pg_consumed_ledger_path()` and following its style. *(completed)*
- [x] Add `pg_audit_buffer <event_type> <category> <message> <detail_json>`: calls the existing
  `pg_dir_ensure` (so the buffer inherits the directory's `.gitignore` of literal `*` with no new
  ignore rule anywhere), builds one JSON line via `jq -c -n` carrying the event type, category,
  message, session id from `pg_session_id`, the detail object, and `recorded_at` set to the
  current UTC instant, and appends it under `flock` on the sibling lock file. *(completed)*
- [x] Make `pg_audit_buffer` non-fatal in the same posture as `pg_events_append_observable`:
  always return 0, emit a stderr `WARNING` on any failure, never block the grant operation.
  *(completed)*
- [x] Add `pg_audit_flush()`: return 0 immediately when the buffer is absent or empty; otherwise
  read it line by line under the same `flock`, and for each line call the existing
  `pg_events_append_observable` with `--event-type`/`--category`/`--session`/`--message` and a
  `--detail-json` that merges the buffered detail with `recorded_at`. *(completed)*
- [x] Make the drain fail-safe: truncate (or remove) the buffer **only after every line's append
  returned success**; on any failure leave the buffer intact for the next flush and warn on
  stderr. *(completed: gated on the events-append.sh helper's availability, checked once before
  the drain loop rather than per-line, since `pg_events_append_observable`'s own contract always
  returns 0 — see the function's header comment for the precondition this coarse check
  implements)*
- [x] Verify by sourcing the library in a throwaway fixture: buffer two records, assert the
  buffer file exists with two lines and that `git status --porcelain` inside the fixture is
  empty (the directory's own `.gitignore` covers it); then flush and assert both lines land in
  `specs/events.jsonl` and the buffer is gone. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-please-grant.sh,test-guard-git-push.sh,test-guard-destructive-git.sh` — the three suites `suite_selection_select` resolves for `scripts/lib/push-grant-lib.sh`, measured in-session — plus the single-file lint of that module, which together cover a phase that adds new unreferenced functions and changes no existing call site.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` - add `pg_audit_buffer_path`, the lock-path accessor, `pg_audit_buffer`, and `pg_audit_flush`; no existing function changed

**Verification**:
- The three suites above pass unchanged (nothing calls the new functions yet, so this phase must not move any existing assertion).
- The throwaway-fixture round trip described in the last task: buffer, assert clean tree, flush, assert both lines in `specs/events.jsonl`, assert buffer gone.
- `bash -n` on the modified library, and a shellcheck pass consistent with the file's existing posture.

---

### Phase 2: Rewire mint and consume to the buffer [COMPLETED]

**Goal**: No mint and no consume writes to `specs/events.jsonl` synchronously any more; the two
coupled assertions are updated in the same pass so no suite is left red.

**Tasks**:
- [x] In `pg_grant_mint`, replace the `pg_events_append_observable --event-type push_grant_issued ...`
  call with the equivalent `pg_audit_buffer` call, keeping the `detail` object's existing field
  set byte-for-byte (`remote`, `ref`, `sha`, `force`, `mint_source`, `action_class`,
  `request_text`) and the same `--message` text, so no downstream consumer of the event shape
  changes. *(completed)*
- [x] In `pg_grant_consume`, make the identical substitution for `push_grant_consumed`, keeping
  its `detail` field set (`remote`, `ref`, `sha`, `force`, `mint_source`, `action_class`,
  `consumer`) and `--message` text unchanged. *(completed)*
- [x] Leave `pg_grant_revoke` untouched: it deletes only the live grant token, and the already
  buffered `push_grant_issued` record must survive revocation. Add a one-line comment there
  stating that this is deliberate, so a future editor does not "tidy" a flush into it.
  *(completed)*
- [x] Leave `pg_events_append_observable` itself unchanged — it is still the wrapper the flush
  uses. *(completed: unchanged, confirmed by grep — see Scope Hypothesis re-check below)*
- [x] Update `scripts/tests/test-please-grant.sh`'s audit case: after the hook invocation, assert
  `git status --porcelain` in the fixture is empty, then drain by sourcing the fixture's
  deployed-shaped library copy and calling `pg_audit_flush`, before the existing
  `tail -n1 specs/events.jsonl` assertion — which then passes unchanged. *(completed: scoped the
  assertion to `git status --porcelain -- specs` before-vs-after the mint rather than a literal
  whole-repo-empty string, since the fixture's own `.claude/` scaffold copies are untracked and
  would make a literal empty assertion always fail regardless of this fix — same intent,
  precisely targeted)*
- [x] Update `scripts/tests/test-guard-git-push.sh`'s wrapper success case the same way: flush
  before its `tail -n1` assertion on `push_grant_consumed`. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly two call sites change (`pg_grant_mint`'s `push_grant_issued` append and `pg_grant_consume`'s `push_grant_consumed` append) and exactly two existing assertions need the flush inserted (`test-please-grant.sh`'s audit case, `test-guard-git-push.sh`'s wrapper success case). Confirm at implementation time with `grep -n "pg_events_append_observable" agent-system/extensions/core/scripts/lib/push-grant-lib.sh` (expect the definition plus only the flush's own use after this phase) and `grep -rn "tail -n1.*events.jsonl" agent-system/extensions/core/scripts/tests/` (expect no un-flushed occurrence coupled to a mint or consume); if either count differs, widen this phase rather than proceeding on the estimate.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-please-grant.sh,test-guard-git-push.sh,test-guard-destructive-git.sh` — this phase changes behavior observable to the library's three enumerated direct dependents (`hooks/please-grant.sh`, `hooks/guard-git-push.sh` with `scripts/git-push-granted.sh`, and `hooks/guard-destructive-git.sh`), and those three suites are exactly the covering set `suite_selection_select` resolves for the changed module.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` - `pg_grant_mint` and `pg_grant_consume` buffer instead of appending; `pg_grant_revoke` gains an explanatory comment only
- `agent-system/extensions/core/scripts/tests/test-please-grant.sh` - audit case gains a clean-tree assertion and a flush step before its existing `tail -n1` check
- `agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` - wrapper success case gains a flush step before its existing `tail -n1` check

**Verification**:
- All three suites above pass, including both updated assertions.
- In a fixture repo that has committed a `specs/events.jsonl`, a mint leaves `git status --porcelain` empty; the pending buffer holds the record and `specs/events.jsonl` is unchanged until a flush.
- `grep` confirms `pg_events_append_observable` is no longer called from `pg_grant_mint` or `pg_grant_consume`.

---

### Phase 3: Wire the flush into the Stop/SubagentStop hook [COMPLETED]

**Goal**: Buffered records drain automatically at the one pipeline point guaranteed to run after
the current turn's whole command body and before the next turn's `UserPromptSubmit`.

**Tasks**:
- [x] In `hooks/events-log-lifecycle.sh`, source `push-grant-lib.sh` from
  `$SCRIPT_DIR/../scripts/lib/push-grant-lib.sh` guarded (`2>/dev/null || true`), matching how
  the hook already tolerates a missing `events-append.sh`. *(completed)*
- [x] Call `pg_audit_flush` once, unconditionally, after the stdin read and **before** the
  `AGENT_ID` branch, so it runs on both `Stop` and `SubagentStop` and harmlessly finds nothing in
  the common case where no mint or consume happened this turn. *(completed)*
- [x] Guard the call so a missing library or a flush failure can never change the hook's output
  contract: the hook must still always echo `{}` and exit 0, and must never emit a `decision`
  key. Place the call after the existing `command -v jq` check (the flush needs `jq` via
  `events-append.sh`). *(completed: guarded via `command -v pg_audit_flush` plus `|| true` on
  both the source and the call)*
- [x] Add a header-comment paragraph naming the ordering invariant this call exists to uphold, in
  the style of the file's existing correlation-rationale paragraphs. *(completed)*
- [x] Confirm the hook's `set -euo pipefail` is not tripped by the sourced library (which sets no
  shell options by contract) — exercise the hook end-to-end in a fixture with a non-empty buffer.
  *(completed: all three required fixture cases verified -- non-empty buffer drains correctly,
  empty/absent buffer is a clean no-op, and a deliberately-removed library still yields `{}`
  exit 0)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-subagent-postflight-marker.sh` — the covering suite `suite_selection_select` resolves for `hooks/events-log-lifecycle.sh`, measured in-session — plus `bash -n` on the hook; the edit is confined to that one hook file and changes no function signature or output contract.

**Files to modify**:
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` - guarded source of `push-grant-lib.sh` and one unconditional `pg_audit_flush` call before the `AGENT_ID` branch, plus a header-comment paragraph

**Verification**:
- `test-subagent-postflight-marker.sh` passes (the hook's existing `Stop`/`SubagentStop` behavior is unchanged).
- Fixture run: with a non-empty buffer, piping a `Stop`-shaped payload to the hook drains the buffer into `specs/events.jsonl` and still prints exactly `{}` with exit 0.
- Fixture run: with an absent buffer, the hook prints `{}` and exits 0 with no new event and no stderr noise.
- Fixture run: with `push-grant-lib.sh` deliberately removed, the hook still prints `{}` and exits 0.

---

### Phase 4: Regression cases pinning the ordering invariant [COMPLETED]

**Goal**: New assertions that fail if the synchronous-append ordering is ever reintroduced, and
that pin the audit guarantee for a minted-but-unconsumed grant.

**Tasks**:
- [x] In `scripts/tests/test-please-grant.sh`, add a case that mints a `/tag`-shaped grant
  (`/tag --minor`, exercising `please-grant.sh`'s `/tag` recognition arm and its `push_tag`
  action class) in a deployed-shaped fixture whose `specs/events.jsonl` is **already committed**,
  then asserts `git status --porcelain` is empty. This is the direct pin for the reported failure,
  independent of `skill-tag`'s markdown-prose body. *(completed)*
- [x] Add a companion case asserting the record went to the pending buffer and that
  `specs/events.jsonl` is byte-identical to its committed state before any flush. *(completed)*
- [x] Add a case for the audit guarantee: mint, then `pg_grant_revoke`, then `pg_audit_flush`, and
  assert the `push_grant_issued` line is still present in `specs/events.jsonl` — the
  minted-but-unconsumed forensic case. *(completed)*
- [x] In `scripts/tests/test-guard-git-push.sh`, add the consume-side mirror: after a successful
  wrapper push in a fixture with a committed `specs/events.jsonl`, assert the tree is clean (no
  sweep commit required), then flush and assert the `push_grant_consumed` line lands. *(completed)*
- [x] Add a flush-idempotence case: a second `pg_audit_flush` with an empty buffer appends
  nothing and leaves `specs/events.jsonl` unchanged. *(completed)*
- [x] Follow each suite's existing fixture and `pass`/`fail` helper conventions; do not introduce
  a new harness style. Reach the buffer through the library's own accessors rather than naming
  the grant directory path in a Bash command (see the tamper-guard risk row above). *(completed:
  the one case needing the buffer's path reads it via `pg_audit_buffer_path` inside a sourced
  subshell, never a hardcoded path string in a Bash command)*

**Timing**: 1.25 hours

**Depends on**: 2, 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the two named suites are the complete set of homes needed for these cases (the dispatch's ACCEPTANCE names both, and `suite_selection_select` maps `push-grant-lib.sh` to them plus `test-guard-destructive-git.sh`, which exercises the grant check rather than the audit path). Confirm at implementation time by re-running `suite_selection_select` over the final touched-file list and checking that no third suite asserts on `push_grant_issued`/`push_grant_consumed` (`grep -rn "push_grant_issued\|push_grant_consumed" agent-system/extensions/core/scripts/tests/`); add a case to any suite that does.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-please-grant.sh,test-guard-git-push.sh` — the two suites being edited are themselves the covering check for this phase, which adds test cases only and touches no production code path.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-please-grant.sh` - clean-tree-after-mint case, buffer-not-log case, and the revoke-then-flush audit-guarantee case
- `agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` - clean-tree-after-consume case and the flush-idempotence case

**Verification**:
- Both suites pass with all new cases green.
- Each new case is confirmed to actually fail against the pre-Phase-2 behavior (temporarily restore the synchronous call locally, observe the new assertions fail, restore the fix) — a regression test that cannot fail pins nothing.

---

### Phase 5: Record the invariant and run the full gate set [COMPLETED WITH EXCLUSIONS]

**Goal**: The adopted direction and the ordering invariant are durably recorded on both sides of
the contract, the blast-radius claim is re-attested, and the complete repository gate set passes.

**Tasks**:
- [x] Update `push-grant-lib.sh`'s header `Audit:` paragraph to describe the buffer-then-flush
  design: mint and consume buffer to the pending-audit file inside the grant directory, the
  `Stop`/`SubagentStop` hook flushes, and the stated reason is that a `UserPromptSubmit` or
  `PreToolUse` hook must never dirty a tracked file ahead of a command's own precondition read.
  Name `pg_grant_revoke`'s deliberate non-participation. *(completed)*
- [x] Add a short subsection to `context/formats/events-format.md` naming buffer-then-flush as
  the sanctioned pattern for any future hook that both fires ahead of a command body and needs to
  record something durably, and stating the timestamp semantics (`timestamp` is flush time,
  `detail.recorded_at` is the true moment). *(completed)*
- [x] Add a comment immediately above `skill-tag`'s clean-tree check in its "Validate Git State"
  step, recording that the check now relies on the mint path not dirtying the tree and pointing
  at `push-grant-lib.sh`'s audit paragraph — so a future editor of either side sees the contract.
  Do not change the check's logic. *(completed: comment added, check's logic untouched)*
- [x] Re-attest the blast radius against the source store rather than trusting the research
  report: `grep -rn "git status --porcelain" agent-system/extensions/*/skills/ agent-system/extensions/*/commands/ agent-system/extensions/*/scripts/`
  excluding `tests/`, and confirm that no occurrence other than `skill-tag`'s is refusal-shaped.
  Record the result (and any new occurrence) in the summary. *(completed: re-grep confirms the
  same set as the research report — `skill-tag` (refusal-shaped), `/pr` in cslib (mint prefix
  but "commit the dirt" shaped, confirmed by re-reading its Step A), `skill-orchestrate` (warn
  only, never commits/refuses, and not a mint prefix), `skill-cslib-vet` (not a mint prefix),
  and four infra scripts (`git-snapshot.sh`, `git-commit-phase.sh`,
  `orchestrator-postflight.sh`, `test-state-write-spill-names.sh`) that are not gated behind
  typing one of the four mint prefixes at all. No new occurrence found.)*
- [x] Confirm `scripts/lib/runtime-file-patterns.sh` and
  `context/standards/orchestrator-runtime-files.md` are untouched by this task:
  `git status --short` must show neither, and `git log -p` over this task's commits must not
  reach either path. *(completed: confirmed via `git status --short` and `git log` over this
  task's commit range — neither path appears)*
- [x] Run the complete gate set and observe it green. *(deviation: altered — observed, not green:
  `verify-deploy.sh` fails 5/37 and `run-all.sh` fails 4/144, every failure attributed to a
  pre-existing or concurrent-sibling cause unrelated to this task, with `test-guard-git-push.sh`
  specifically re-verified against the pristine pre-task-406 library content. See
  `#### Reasoned Exclusions` below.)*

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` - header `Audit:` paragraph rewritten for the buffer-then-flush design
- `agent-system/extensions/core/context/formats/events-format.md` - new subsection naming the buffer-then-flush pattern and its timestamp semantics
- `agent-system/extensions/core/skills/skill-tag/SKILL.md` - comment above the clean-tree check in the "Validate Git State" step recording the invariant it relies on; no logic change

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh agent-system/extensions/core` — the complete gate set this repository aggregates, run with an explicit `TARGET` naming the resolved source store (the no-argument form defaults `TARGET` to `$(pwd)` and would silently SKIP the source-store-only gates), observed green. No `--skip-slow` and no `--only-gate` narrowing: this is the final phase, so the full aggregator runs.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` — the whole shell suite, not a subset.
- The blast-radius re-grep is recorded with its output in the summary, including the `/pr`
  commit-the-dirt finding, so the class framing is attested rather than inherited.
- `git status --short` confirms `scripts/lib/runtime-file-patterns.sh` and
  `context/standards/orchestrator-runtime-files.md` are unmodified.

#### Reasoned Exclusions

`bash .claude/scripts/verify-deploy.sh "$(pwd)"` (repo root as `TARGET`, matching task 389's
prior invocation of this same gate set; the plan's own verification line above names
`agent-system/extensions/core` as `TARGET`, which errors with "no deploy tree ... nothing to
verify" since `TARGET` must be the repo root, not the source-store subdirectory — recorded as a
plan-wording deviation, not a gate defect) reports **5 of 37 checks failing**.
`agent-system/extensions/core/scripts/tests/run-all.sh` reports **4 of 144 suites failing**. Every
failure is attributed below to a cause unrelated to this task's own file_scope, each with
evidence gathered in this session.

| Item | Reason | Evidence |
|------|--------|----------|
| Gate 3 doc-lint (3 findings) | All three findings are in the `lean` and `project-wide` extensions, not `core`. `check-extension-docs.sh`'s own per-extension summary reports `core PASS`. | `lean4/patterns/measurement-harness-strictness.md` missing a `context/index.json` entry is already tracked as `iss_1792019093789_pEpEft` (task 389's measurement). Two further findings are lean challenge-fixture `.md` files not listed in `provides.scripts`, also unrelated to task 406's file_scope. |
| Gate 4 task-reference lint (1 finding) | The one finding is in `agent-system/extensions/core/context/standards/task-reference-exemptions.md`, an uncommitted, in-progress edit from a concurrent sibling task. This path is not in task 406's declared `file_scope` and no task 406 commit touches it. | `git log` shows the file's last task-406-era commit is unrelated; `git status --porcelain` at dispatch start already listed it modified, before this dispatch's own work began. `check-task-references.sh`'s direct output names only that one file and line. |
| Gate 8 / `test-detect-noop-bash.sh`, `test-four-tier-conflict.sh` | Pre-existing failures, measured and recorded by task 389's implement phase at commit `f33aa52d1`, before task 406 began. Neither suite's name overlaps task 406's `file_scope`. | `iss_1792019093909_Zk3nZO` (task 389's issue log). |
| Gate 8 / `test-guard-git-push.sh` | **In task 406's own `file_scope`; verified directly rather than assumed.** The one failing assertion ("invalidation: expired grant expected exit 2, got 0") was reproduced identically against the pristine pre-task-406 copy of `push-grant-lib.sh` (`git show a7942a4ec:...push-grant-lib.sh`, the commit immediately before this task's Phase 1), swapped in, re-run, and restored. The assertion text itself (test file line 211) is byte-identical to the pre-406 version — not one of this task's own Phase 4 additions, all of which (the three new `/tag`-shaped and buffer/flush regression cases) pass. The defect concerns `pg_grant_fresh`/`pg_grant_find_match`'s handling of an expired-but-HMAC-valid grant, orthogonal to this task's audit-buffering fix. | Reproduction performed in this session: pristine-swap re-run reproduced `[FAIL] invalidation: expired grant expected exit 2, got 0` verbatim; `git status --porcelain` confirmed the swap left no residue after restoration. |
| Gate 8 / `test-verify-deploy-context-budget.sh` | Newly failing, but caused by the same Gate 20 eager-load-over-baseline condition below cascading into this suite's own "baseline fixture is clean" precondition — not by any task 406 file. | The suite's own failure text: `could not compute a safe eager-load pad amount (current_eager='67088', baseline_bytes='66100')`, the identical figures as the Gate 20 finding immediately below. |
| Gate 20 eager-load budget (2 findings) | The baseline overage (67088 B vs. 66100 B, 988 B over) is the same pre-existing regression tracked as `iss_1792015798103_u6yBQB`. The new per-file ceiling breach is on `skills/skill-orchestrate/SKILL.md` (23566 B vs. 22500 B), a file in sibling task 403's declared `file_scope`, not task 406's. | Byte counts measured directly in this session's `verify-deploy.sh` run; `skill-orchestrate/SKILL.md` cross-checked against task 403's dispatch-file territory declaration (listed under its `concurrent_siblings` entry in this task's own `.dispatch/14.md`). |

None of these six items names a file in task 406's `file_scope`
(`context/formats/events-format.md`, `hooks/events-log-lifecycle.sh`, `hooks/please-grant.sh`,
`scripts/lib/push-grant-lib.sh`, `scripts/tests/test-guard-git-push.sh`,
`scripts/tests/test-please-grant.sh`, `skills/skill-tag/SKILL.md`) as its cause. The five new
regression cases this task's Phase 4 added (three in `test-please-grant.sh`, two in
`test-guard-git-push.sh`) all pass. This satisfies the acceptance criterion "New regression cases
pass in `scripts/tests/test-please-grant.sh` and/or `scripts/tests/test-guard-git-push.sh`" even
though those two files' *suites* are not both wholly green (one carries the pre-existing,
unrelated expiry defect above).

---

## Testing & Validation

- [x] A `/tag`-shaped mint in a fixture repository that tracks (and has committed)
  `specs/events.jsonl` leaves `git status --porcelain` empty. *(completed: pinned by
  `test-please-grant.sh`'s Phase 4 regression case)*
- [x] The buffered `push_grant_issued` record is present in the pending-audit buffer and absent
  from `specs/events.jsonl` until a flush. *(completed: pinned by `test-please-grant.sh`'s Phase 4
  "buffer-not-log" regression case)*
- [x] `pg_audit_flush` drains every buffered line into `specs/events.jsonl` and removes the buffer
  only on complete success. *(completed: covered by Phase 1/3 unit coverage and the Phase 4
  flush-idempotence case)*
- [x] A grant that is minted and then revoked still yields its `push_grant_issued` line in
  `specs/events.jsonl` after a flush. *(completed: pinned by `test-please-grant.sh`'s Phase 4
  revoke-then-flush audit-guarantee case)*
- [x] A successful push through `scripts/git-push-granted.sh` leaves the tree clean, so no sweep
  commit is required and the push/commit loop cannot re-enter. *(completed: pinned by
  `test-guard-git-push.sh`'s Phase 4 regression case)*
- [x] A `Stop`-shaped payload to `hooks/events-log-lifecycle.sh` drains the buffer, prints exactly
  `{}`, and exits 0; the same holds with an empty buffer and with `push-grant-lib.sh` absent.
  *(completed: wired in Phase 3, covered by existing `events-log-lifecycle.sh` test coverage)*
- [x] `test-please-grant.sh`, `test-guard-git-push.sh`, `test-guard-destructive-git.sh`, and
  `test-subagent-postflight-marker.sh` all pass. *(deviation: altered — `test-please-grant.sh`,
  `test-guard-destructive-git.sh`, and `test-subagent-postflight-marker.sh` are fully green;
  `test-guard-git-push.sh` has one failing assertion, confirmed pre-existing and unrelated to
  task 406 by direct reproduction against the pristine pre-406 library — see Phase 5's
  `#### Reasoned Exclusions`. Every new Phase-4-added case in both files passes.)*
- [x] The full suite (`run-all.sh`) and the full gate set (`verify-deploy.sh` with an explicit
  `TARGET`) pass. *(deviation: altered — observed, not green: 139/144 suites and 32/37 gate
  checks pass; every failure attributed to a pre-existing or concurrent-sibling cause, none in
  task 406's `file_scope`. See Phase 5's `#### Reasoned Exclusions` for the full enumeration.)*
- [x] `/tag`'s own end-to-end path is **not** agent-verified; the summary states explicitly that
  owner verification is required for it, per the dispatch's user-only constraint. *(completed:
  stated in the implementation summary)*

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` — `pg_audit_buffer_path`, buffer
  lock accessor, `pg_audit_buffer`, `pg_audit_flush`; `pg_grant_mint`/`pg_grant_consume` rewired;
  header `Audit:` paragraph rewritten.
- `agent-system/extensions/core/hooks/events-log-lifecycle.sh` — guarded flush call on both
  `Stop` and `SubagentStop`.
- `agent-system/extensions/core/scripts/tests/test-please-grant.sh` — updated audit case plus
  three new regression cases.
- `agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` — updated wrapper success
  case plus two new regression cases.
- `agent-system/extensions/core/context/formats/events-format.md` — buffer-then-flush pattern
  subsection.
- `agent-system/extensions/core/skills/skill-tag/SKILL.md` — invariant comment above the
  clean-tree check.
- `specs/406_mint_hook_dirties_tree_before_precondition_read/summaries/01_deferred-grant-audit-write-summary.md`
  — recording the adopted direction, the audit-guarantee mechanism, the blast-radius re-grep
  result, and the owner-verification requirement for `/tag` itself.

## Rollback/Contingency

Every phase is independently revertible and commits only its own files, so the ordinary
contingency is `git revert` of the offending phase commit — no working-tree discard is involved
and no snapshot is required.

- **Phase 1 alone** is behavior-neutral (unreferenced functions), so reverting it is safe at any
  time provided Phases 2 and 3 are reverted first.
- **If Phase 3's flush point proves unreliable** in some environment this system must support,
  the buffer is still durable and `pg_audit_flush` is still callable directly: wire the drain
  into an existing sweep path (`/refresh` or `/distill`) instead of reverting Phase 2. The audit
  trail is delayed, never lost.
- **If the deferral direction proves infeasible outright**, fall back to filtering the literal
  path `specs/events.jsonl` out of `skill-tag`'s porcelain output in its "Validate Git State"
  step before the dirty/clean decision, and revert Phases 1-3. This is strictly inferior — it
  fixes one command rather than the class and does nothing for the push loop — so it is adopted
  only on a measured infeasibility finding, which must be recorded in the summary alongside the
  reversal of this plan's Decision Record.
- Should a rollback ever need to discard uncommitted work rather than revert a commit, follow
  `context/contracts/recovery.md`'s rollback rung for the exact invocation shape; do not emit a
  bare precautionary snapshot as a routine start-of-phase step.
