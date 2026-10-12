# Implementation Summary: Task #347

- **Task**: 347 - Turn bounded-build-waiter.md Rule 2 into a blocking PreToolUse Bash hook
- **Status**: [COMPLETED]
- **Started**: 2026-10-12T02:51:32Z
- **Completed**: 2026-10-12T10:53:32Z
- **Effort**: ~4.5 hours (matched plan estimate)
- **Dependencies**: None
- **Artifacts**: plans/01_self-match-waiter-hook.md, summaries/01_self-match-waiter-hook-summary.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md, shell-strict-mode.md, shell-script-testing.md

## Overview

`bounded-build-waiter.md`'s Rule 2 ("never use `ps | grep`, `pgrep -f`, or any
process-name-matching test") had already failed to bind once in practice, documentation-only.
This implementation adds mechanical teeth: a new PreToolUse Bash hook
(`hooks/validate-bounded-waiter.sh`) that blocks the narrow three-way conjunction of a loop
construct, a `sleep` call, and a process-name-match liveness test (bare-word `pgrep` or
`ps`-piped-into-`grep`), with a fixture suite proving every must-block and must-allow shape, a
bare registration in the deploy-reaching settings surface, and manifest wiring. No new context
or pattern document was created.

## What Changed

- `agent-system/extensions/core/hooks/validate-bounded-waiter.sh` — new PreToolUse Bash hook.
  Fails open (`exit 0`) on `jq` absent, empty/absent stdin, an unparseable payload, or a missing
  `tool_input.command`. Blocks (`exit 2` + stderr) only when all three legs hold: a loop keyword
  (`until`/`while`), a `sleep` call, and a name-match test (bare-word `pgrep`, any flags or none,
  or `ps` piped into `grep`). Does not inspect the `grep` pattern's own contents, so the
  `[b]racket` evasion blocks by construction. The stderr block states the self-match mechanism,
  names Rule 2, and carries the canonical `kill -0` idiom inline. The header records, in full:
  the bare-word-vs-flag-narrowed ruling; the deliberately-not-classified shapes (bare
  `pgrep`/`ps|grep`, one-shot conditionals, `ps -p "$pid"`, log-sentinel polls, no-op filler,
  absent-waiter parking); the no-exemption-for-`kill -0` ruling; the Rule 4 scope-out; the
  shared-pattern-library rejection; and the Family B two-way inventory-asymmetry
  cross-reference.
- `agent-system/extensions/core/scripts/tests/test-validate-bounded-waiter.sh` — new fixture
  suite (Class B, `set -uo pipefail`), 23 cases driving the hook as a real subprocess: 5
  must-block shapes (including the `[b]racket` variant), 5 flag-clustering regressions pinning
  the bare-word ruling, 1 no-exemption-for-`kill -0` pin, 8 must-allow shapes (including the
  no-op-filler boundary), and 4 fail-open cases. All 23 pass; no matcher defect was found in the
  hook.
- `agent-system/extensions/core/merge-sources/settings-hooks.json` — appended
  `validate-bounded-waiter.sh` bare (no `|| echo`/`2>/dev/null` wrapper) to the existing
  exact-string `"Bash"` PreToolUse block. Block count unchanged (3); no new matcher key created.
- `agent-system/extensions/core/manifest.json` — `validate-bounded-waiter.sh` added to
  `provides.hooks` (alphabetically, between `tts-notify.sh` and `validate-handoff-location.sh`);
  `tests/test-validate-bounded-waiter.sh` added to `provides.scripts` via the sanctioned
  `sync-manifest-scripts.sh --write` derivation, not a hand-edit.

## Decisions

- **Bare-word `pgrep` match, not flag-narrowed**: Rule 2 forbids "any process-name-matching
  test"; the three-way conjunction already supplies the false-positive safety, so matching the
  bare token (any flags or none) closes every flag-clustering evasion by construction rather than
  by an enumerated, driftable flag list. Pinned by 5 dedicated fixture cases.
- **Registration surface: `merge-sources/settings-hooks.json`, not `root-files/settings.json`**.
  `root-files/settings.json` is install-once (`INSTALL_ONCE_ROOT_FILES` in the loader) and
  reaches only a fresh install; `verify-deploy.sh`'s own Gate 2 remediation string states the
  same direction verbatim. Confirmed live: the deployed `.claude/settings.json` registers the
  hook bare, exactly once, after `deploy-headless.sh`.
- **Rule 4 ("one waiter per log") scoped out of this hook, not implemented**: a PreToolUse hook
  observes waiter STARTS and never waiter EXITS, so any "this log already has a waiter" record
  goes stale the instant that waiter exits, with no event to clear it — it would falsely refuse a
  legitimate sequential wait on the same log, a false positive this task treats as worse than no
  hook. A fixed TTL does not rescue it: Rule 1 sizes the legitimate wait to the command's own
  expected run time, so no single bound is safely shorter than every legitimate wait and longer
  than every dead-waiter gap. Rule 4 is enforceable only at REAP time, against a live process
  snapshot — exactly where `scripts/claude-refresh.sh`'s `BUILD_WAITER_REAP_MIN`-gated
  `run_build_waiter_pass` already lives. This hook does not duplicate it.
- **Shared-pattern-library question: rejected**. The `validate-no-task-references.sh` /
  `scripts/lib/task-reference-patterns.sh` precedent does not generalize here: a library sourced
  by only this hook would not be shared, the only candidate second consumer
  (`build_waiter_family()` in `scripts/claude-refresh.sh`) is outside this task's `file_scope`
  and an explicit non-goal to modify, and the two consumers receive structurally different input
  (a `ps -eo args` column at reap time vs. a `tool_input.command` string at write time) — a
  harder split than `task-reference-patterns.sh`'s two plain-text consumers. The drift path is
  closed instead by a bidirectional cross-reference comment inside this hook's own header, naming
  `build_waiter_family()` and both inventory asymmetries explicitly: the reaper's Family B test
  (`(until|while) && "grep -q" && sleep`) misses `pgrep` entirely (re-derived: `grep -c pgrep
  scripts/claude-refresh.sh` returns 0) and also misses a `ps aux | grep -i` loop lacking the
  literal `-q`; conversely, this hook deliberately does not classify the reaper's
  log-sentinel-poll half of Family B (`until grep -q DONE log; do sleep N; done`, no
  `ps`/`pgrep` at all).
- **Reciprocal cross-reference comment in `scripts/claude-refresh.sh`'s Family B header:
  declined**, not added. The plan's stated prerequisite — `update-task-status.sh
  --file-scope-add` as "the sanctioned mid-run re-scope path" — was mechanically verified not to
  apply during an implement-phase dispatch: the script hard-errors unless
  `operation=postflight` and `target_status` is `research` or `plan`. No other sanctioned
  implement-time `file_scope`-widening entry point was found. Rather than hand-edit
  `specs/state.json`'s `file_scope` array to bypass this, the edit was declined. **Residual,
  one-directional drift risk**: an editor of `claude-refresh.sh` will not see a pointer toward
  this hook, though this hook's own header already names `build_waiter_family()` and both
  asymmetries in the other direction. If a future task widens `claude-refresh.sh`'s `file_scope`
  for an unrelated reason, adding the reciprocal one-line comment at that point would close the
  remaining direction cheaply.
- **Neighbor-status correction**: task 345 (the no-op-filler/absent-waiter neighbor named in the
  dispatch) is completed, and its `detect-noop-bash.sh` hook remains PostToolUse, advisory-only,
  and exits 0 unconditionally — it never became a blocking gate. The collision risk the dispatch
  flagged ("if both tasks independently build a blocking Bash gate...") does not materialize:
  this hook is the first (and, as far as this task's scope extends, only) blocking Bash gate over
  wait-loop shapes in this corpus. The sibling record-versioning hook task (the closest sibling in
  shape) was re-confirmed `not_started` at plan time, so this task establishes the house pattern
  rather than following one; its own declared registration surface was observed to be
  `root-files/settings.json`-only in its task description, which — per the identical
  install-once reasoning this task applied to its own registration — is the surface that cannot
  reach an already-deployed repo. Recorded here as an out-of-scope recommendation for that task,
  not acted on.

## Plan Deviations

- **Phase 3, "reciprocal cross-reference" decision point**: altered. Declined the reciprocal
  comment in `scripts/claude-refresh.sh` rather than add it, because the plan's prerequisite
  re-scope mechanism (`update-task-status.sh --file-scope-add`) does not apply during implement
  (see Decisions above).
- **Phase 4, "run the complete gate set ... confirm exit 0"**: altered. `verify-deploy.sh`
  reported 33/36 checks passing, not exit 0. All 3 failures were individually investigated and
  confirmed pre-existing and unrelated to this task's deliverables; recorded as a full
  `#### Reasoned Exclusions` table in the plan's Phase 4 body, and the phase closed
  `[COMPLETED WITH EXCLUSIONS]` rather than a false-clean `[COMPLETED]`. Detail:
  - Gate 3 doc-lint: `check-evidence-probes.sh` referenced only in `skills/skill-todo/SKILL.md`
    and absent from disk and from `provides.scripts` — unconnected to this task's hook, suite, or
    either wired file. Plus a `lean`-extension `index-entries.json` line-count drift, unrelated
    to `core`.
  - Gate 5 (manifest-driven verification): two `lean`-extension findings (a missing context file
    and a content-hash mismatch), zero `core`-prefixed findings.
  - Gate 8 (`run-all.sh`): the sole failing suite was `test-verify-deploy-context-budget.sh`,
    whose own fixture setup is broken (reports "baseline fixture is not clean"), a pre-existing
    defect tracked by a separate already-open task. This task's own new suite,
    `test-validate-bounded-waiter.sh`, PASSed within that same `run-all.sh` run (136 passed, 1
    failed overall).

## Verification

- Build: N/A (shell scripts, no build step).
- Tests: `test-validate-bounded-waiter.sh` — 23/23 pass. `run-all.sh --only
  test-validate-bounded-waiter.sh,test-deploy-orphans.sh` — 2/2 pass. Full
  `run-all.sh` — 136/137 pass (the one failure is the pre-existing, unrelated
  `test-verify-deploy-context-budget.sh` fixture defect; see Plan Deviations).
- Shellcheck: `lint-shellcheck.sh --verbose` exits 0 for both new files, full-repo clean (362
  files checked, 0 findings).
- Registration: deployed `.claude/settings.json` registers the hook bare, exactly once, under
  the exact-string `"Bash"` matcher; `.claude/hooks/validate-bounded-waiter.sh` is executable and
  byte-identical to the source-store copy.
- Live-fire: the deployed hook blocks the incident command (exit 2, `kill -0` in stderr) and
  allows the canonical waiter (exit 0), both observed directly against the deployed copy.
- End-to-end: a real Bash tool call
  (`timeout 5 bash -c "until ! pgrep -f 'nonexistent-sentinel-xyz'; do sleep 1; done"`) was
  refused by the live, registered hook in this session, observed firsthand.
- `verify-deploy.sh`: 33/36 (see Plan Deviations / Reasoned Exclusions for the 3 pre-existing,
  unrelated failures).
- `check-task-references.sh`: exits 0 (zero occurrences outside `specs/**`).
- Pattern-document count: unchanged — `git status --short` under
  `agent-system/extensions/core/context/patterns/` is empty, and `bounded-build-waiter.md` was
  not modified.
- Files verified: Yes (all four deliverable files confirmed present, executable where
  applicable, and `jq empty`-valid for the two JSON files).

## Impacts

- Every Bash tool call across this repository (and every deployed consumer repo, once the next
  deploy lands) is now refused if it conjoins a wait loop with a process-name-matching liveness
  test — closing the exact gap that let the motivating incident recur twice with the prohibition
  already live in the dispatched agent's own reference chain.
- `scripts/claude-refresh.sh`'s reaper is unchanged; cleanup (reclaiming an already-orphaned
  waiter) and prevention (refusing one before it starts) remain two separate, complementary
  layers, as the task required.
- No change to `bounded-build-waiter.md` or any other context/pattern document.

## Follow-ups

- The reciprocal one-line cross-reference comment in `scripts/claude-refresh.sh`'s Family B
  header (naming this hook) remains undone. Low cost, low urgency: add it the next time
  `scripts/claude-refresh.sh` is already in an active task's `file_scope` for an unrelated
  reason, closing the one remaining drift direction.
- Recorded as an out-of-scope recommendation (not actioned by this task): the sibling
  record-versioning PreToolUse hook task's declared registration surface
  (`root-files/settings.json`) is, by the identical install-once reasoning this task applied to
  its own registration, the surface that cannot reach an already-deployed repo. That task should
  re-confirm its registration surface before closing.
- `check-evidence-probes.sh` (referenced in `skills/skill-todo/SKILL.md`, absent from disk and
  from `provides.scripts`) and the `lean`-extension doc/content drift observed during Phase 4's
  gate run are pre-existing defects outside this task's scope; left for their owning tasks.
  `test-verify-deploy-context-budget.sh`'s broken fixture setup is likewise outside this task's
  scope and is tracked by a separate, already-open task.

## References

- Plan: `specs/347_self_match_waiter_pretooluse_block_hook/plans/01_self-match-waiter-hook.md`
- Research: `specs/347_self_match_waiter_pretooluse_block_hook/reports/01_self-match-waiter-hook.md`
- Progress files: `specs/347_self_match_waiter_pretooluse_block_hook/progress/phase-{1,2,3,4}-progress.json`
- Handoffs: `specs/347_self_match_waiter_pretooluse_block_hook/handoffs/phase-{1,2,3,4}-handoff-*.md`
- Hook: `agent-system/extensions/core/hooks/validate-bounded-waiter.sh`
- Fixture suite: `agent-system/extensions/core/scripts/tests/test-validate-bounded-waiter.sh`
- Reference precedent: `bounded-build-waiter.md` Rule 2 (enforced, not modified); `guard-destructive-git.sh` and `validate-no-task-references.sh` (structural model); `scripts/claude-refresh.sh`'s `build_waiter_family()` (pattern inventory, cross-referenced, not modified)
