# Implementation Plan: CWD-independent hook registration paths

- **Task**: 364 - Resolve hook registration paths independently of session CWD so bare-registered
  blocking guards cannot fail open
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/364_cwd_relative_hook_registration_paths/reports/02_cwd-relative-hook-paths-research.md`
  (primary), `specs/364_cwd_relative_hook_registration_paths/reports/01_cwd-relative-hook-paths.md`
  (pre-research evidence capture)
- **Artifacts**: plans/02_cwd-relative-hook-registration-paths.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Every hook registration in the source store writes `bash .claude/hooks/x.sh`, a CWD-relative path
the harness resolves against the session's drifted Bash-tool CWD rather than the project root, so
each one silently fails open the moment a session `cd`s into a subdirectory. Research settled the
mechanism empirically: `$CLAUDE_PROJECT_DIR` IS exported into hook command environments (both event
types, and through the nested `bash -c` wrapper) and the fixed form demonstrably still blocks with
`exit 2`. This plan rewrites all 34 source-store registrations to
`bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh`, adds the one missing merge-source counterpart that
would otherwise stay permanently unreachable by resync, and fixes the four markdown registration
templates that teach the old shape by example. Done means: no CWD-relative `.claude/` path in any
hook command in a freshly deployed tree, and no duplicate registration on a fresh install —
asserted by test, not by inspection.

**MID-IMPLEMENTATION SCOPE CHANGE (operator directive)**: the plan as originally authored also
shipped an idempotent migration script for already-deployed repos (Phases 3/4/6 below), because
neither install-once `root-files/settings.json` nor add-only `deep_merge` could otherwise reach
one. Mid-implementation, the operator directed that this migration mechanism be dropped: the
operator is reloading/redeploying the agent system to every consumer repo directly, which
supersedes the "install-once cannot reach an already-deployed repo" premise that made the
migration script necessary. Phases 3, 4, and 6 are accordingly closed
`[COMPLETED WITH EXCLUSIONS]` with the operator's instruction recorded as the reason (see each
phase's Reasoned Exclusions). Acceptance criteria 1, 2, and 5 (demonstrated against a real
pre-existing deploy) are consequently NOT satisfied by this task's own artifact; they are expected
to be reached by the operator's separate redeploy action instead. Acceptance criterion 4 (fresh
deploy carries no CWD-relative path) is unaffected and remains absolute.

### Research Integration

- **D1 (gating question, settled)**: adopt `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh`. Both
  fallbacks (deploy-time absolute-path substitution; a `git rev-parse`-based self-locating
  dispatcher) are explicitly ruled out and must not be reconsidered absent new evidence.
- **D2**: the four hooks that exist in BOTH `core/root-files/settings.json` and
  `core/merge-sources/settings-hooks.json` (`guard-destructive-git.sh`,
  `validate-no-task-references.sh`, `guard-git-push.sh`, `please-grant.sh`) must be rewritten
  byte-identically in both files or `deep_merge`'s exact-string dedup appends a duplicate on the
  very next load, including a brand-new repo's first install.
- **D3**: a migration script is mandatory, not optional — install-once semantics plus add-only
  `deep_merge` make already-deployed repos unreachable by any combination of source-store edits.
- **D4**: `root-files/settings.json` keeps its registrations, with an explicit in-file warning that
  NEW registrations belong in the merge source.
- **D5**: `validate-state-sync.sh`'s nested registration has no merge-source counterpart at all;
  add one in this same change.
- **D6**: `root-files/settings.local.json` permission matchers do NOT share the defect and MUST NOT
  be touched — they are text matchers against the Bash tool's proposed command, and
  `$CLAUDE_PROJECT_DIR` is confirmed absent from that environment, so rewriting them would be
  actively harmful.
- **D7/F9**: exactly 8 markdown JSON registration-template snippets are in scope; the manual
  diagnostic invocations in `workflow-interruptions.md` (lines 35, 237, 240, 246) and
  `core/scripts/tests/test-please-grant.sh` line 222 are correct-by-different-construction and must
  not be rewritten.
- **F8/D9**: reuse `migrate-directory-padding.sh`'s script convention and
  `test-deploy-propagation.sh`'s real-scratch-repo deploy harness rather than inventing parallel
  machinery.

### Prior Plan Reference

No prior plan. This is plan round 02 (round 01 produced only the pre-research evidence capture, no
plan file).

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag was set; this plan makes no
roadmap claim.

## Goals & Non-Goals

**Goals**:
- Every hook `command` string in the source store resolves against the project root, not the
  session CWD — all 34 occurrences across 4 JSON files, not only the six blocking guards (acceptance
  criterion 4 is absolute: *no* CWD-relative `.claude/` path in a deployed tree's hook commands).
- The bare-vs-`2>/dev/null || echo '{}'` distinction is preserved exactly: the six blocking guards
  stay bare so `exit 2` still blocks; every advisory hook keeps its fail-open suffix.
- ~~An already-deployed consumer repo reaches the corrected state by an explicit, idempotent,
  `--dry-run`-capable migration script, demonstrated against two real pre-existing deploys.~~
  **STRUCK by operator directive mid-implementation** (see Phase 3/4/6's Reasoned Exclusions):
  the operator will reload/redeploy the agent system to every consumer repo directly, superseding
  the need for a bespoke migration script. Already-deployed repos are reached by that separate
  redeploy action instead, outside this task's artifact boundary.
- No repo carries both a broken and a fixed registration for the same hook on a FRESH install,
  asserted by test (Phase 5). The existing-repo-after-migration half of this goal is struck for the
  same reason as above — no migration mechanism exists within this task to assert it against.
- `validate-state-sync.sh` gains a merge-source registration so it stops being permanently
  unreachable by resync.
- The four markdown registration templates stop teaching the defect by example.

**Non-Goals**:
- `root-files/settings.local.json` permission matchers (D6 — ruled out with reason, not deferred).
- The widened lint / `verify-deploy.sh` gate that enforces this convention going forward. That is
  task 365's declared territory (its `file_scope` already names
  `core/scripts/lint/lint-hook-registration-paths.sh` and `verify-deploy.sh`); implementing a
  competing gate here would double-implement it and collide on the same file. **Ruling, with
  reason**: acceptance criterion 6 is satisfied here by test (Phases 4 and 5), and the standing
  gate is left to 365. This is a deliberate narrowing of research D8, recorded so a reader does not
  read it as an omission.
- Removing hook registrations from `root-files/settings.json` (D4 — they stay).
- Task 303's script-internal default-argument bug (confirmed unrelated).
- Rewriting the correct-by-construction diagnostic invocations enumerated in D7/F9.
- **Added mid-implementation (operator directive)**: the migration script for already-deployed
  repos (`migrate-hook-registration-paths.sh`), its test, and demonstrating against the two real
  pre-existing deploys. The operator is reloading/redeploying the agent system to every consumer
  repo directly, which reaches already-deployed repos without a bespoke migration mechanism. See
  Phase 3/4/6's Reasoned Exclusions for the full record.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A shared hook's command string diverges between `root-files/settings.json` and `merge-sources/settings-hooks.json` (typo, flag difference), self-inflicting a duplicate on the next load | H | M | Phase 1 ends with a mechanical per-hook string equality check across the two files for all four shared hooks — not an eyeball comparison |
| The nested `bash -c` form (root-files line 80) is missed or over-rewritten by a naive find-and-replace | H | M | Phase 1 handles it as its own named sub-step using the exact shape verified in research F3; only the inner `bash .claude/hooks/validate-state-sync.sh` fragment changes |
| Migration script written but never run against the repo where the defect was actually reproduced | H | M | Phase 6 runs it against BOTH real pre-existing deploys (`/home/benjamin/.config/nvim` itself and `/home/benjamin/Philosophy/Papers/PossibleWorlds`, each carrying 21 CWD-relative registrations as of plan authoring) and re-reproduces the original failure condition |
| A `"_comment"` key added to `settings.json` triggers a harness "unknown setting" warning | M | M | Phase 2 verifies a real session accepts it; documented fallback is to carry the warning in `docs/` + `manifest.json` (where it already exists) and skip the in-file key rather than ship a warning banner to every consumer repo |
| Migration rewrites a hand-edited consumer `settings.json` destructively | H | L | Script is string-substitution-only on `.claude/hooks/` command fragments, writes a timestamped backup beside the file, and is idempotent; `--dry-run` is exercised first in Phase 6 |
| Markdown pass touches one of the correctly-exempt diagnostic lines | M | M | D7's exact line numbers are carried into Phase 7's task list; Phase 7's verification asserts those four lines are byte-unchanged |
| Tasks 282/347 later append a new registration in the old CWD-relative form by copying surrounding style | M | M | Phase 2's in-file warning plus the convention note; the standing mechanical gate is 365's job (see Non-Goals) |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3, 7 | -- |
| 2 | 2, 4 | 1 (for 2), 3 (for 4) |
| 3 | 5 | 1, 3 |
| 4 | 6 | 1, 3, 4 |

Phases within the same wave can execute in parallel; their file sets are disjoint (Phase 1 owns the
four settings JSON files, Phase 3 owns `core/scripts/` + `manifest.json` + `docs/`, Phase 7 owns the
four markdown files).

---

### Phase 1: Rewrite all source-store hook registrations to the `$CLAUDE_PROJECT_DIR` form [COMPLETED]

**Goal**: Every hook `command` string in the source store resolves against the project root, with
the bare-vs-fail-open distinction preserved and the four cross-file shared strings byte-identical.

**Tasks**:
- [x] Rewrite the 18 occurrences in `agent-system/extensions/core/root-files/settings.json` from
      `bash .claude/hooks/X` to `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/X`, preserving each
      command's existing suffix exactly (bare for `guard-destructive-git.sh`,
      `validate-no-task-references.sh`, `guard-git-push.sh`, `please-grant.sh`; `2>/dev/null || echo
      '{}'` for the rest). *(completed)*
- [x] Handle the nested `bash -c` registration (the `PostToolUse`/`Write` entry wrapping
      `validate-state-sync.sh`) as its own sub-step: change ONLY the inner
      `bash .claude/hooks/validate-state-sync.sh` fragment, leaving the
      `$CLAUDE_TOOL_INPUT`/`$FILE` conditional logic untouched. Use the shape verified in research
      F3. *(completed)*
- [x] Rewrite the 14 occurrences in `agent-system/extensions/core/merge-sources/settings-hooks.json`
      the same way. *(completed)*
- [x] Rewrite the single occurrence in `agent-system/extensions/books/settings-hooks.json`
      (`validate-evidence-append-only.sh`, bare — stays bare). *(completed)*
- [x] Rewrite the single occurrence in `agent-system/extensions/email/settings-fragment.json`
      (`mail-guard.sh`, keeps its `2>/dev/null || echo '{}'` suffix). *(completed)*
- [x] Add the D5 merge-source counterpart: a `PostToolUse`/`Write` entry in
      `core/merge-sources/settings-hooks.json` carrying the same nested `bash -c` registration for
      `validate-state-sync.sh`, byte-identical to the rewritten `root-files/settings.json` string so
      `deep_merge` dedups it to a no-op on a fresh install. *(completed)*
- [x] Mechanically verify byte-identical command strings across the two core files for all five
      now-shared hooks (`guard-destructive-git.sh`, `validate-no-task-references.sh`,
      `guard-git-push.sh`, `please-grant.sh`, and the new nested `validate-state-sync.sh`). *(completed: confirmed byte-equal via jq extraction)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: 34 CWD-relative occurrences across exactly 4 JSON files (18 in
`core/root-files/settings.json`, 14 in `core/merge-sources/settings-hooks.json`, 1 in
`books/settings-hooks.json`, 1 in `email/settings-fragment.json`), and exactly 4 hooks shared
byte-identically between the two core files. Both figures were re-derived at plan-authoring time
by `grep -c 'bash \.claude/hooks'` over each file and a per-hook cross-file string comparison, not
carried from the research report. Confirm at implementation time by re-running
`grep -rc 'bash \.claude/hooks' agent-system --include=*.json` before editing and asserting a
zero total after.

**Files to modify**:
- `agent-system/extensions/core/root-files/settings.json` - 18 command strings rewritten, including
  the nested `bash -c` form
- `agent-system/extensions/core/merge-sources/settings-hooks.json` - 14 command strings rewritten,
  plus one new nested `validate-state-sync.sh` `PostToolUse` registration (D5)
- `agent-system/extensions/books/settings-hooks.json` - 1 command string rewritten (stays bare)
- `agent-system/extensions/email/settings-fragment.json` - 1 command string rewritten (keeps
  fail-open suffix)

**Verification**:
- `jq empty` passes on all four files.
- `grep -rn 'bash \.claude/hooks' agent-system --include=*.json` returns zero matches.
- Count of bare (no `|| echo`) registrations is unchanged at 6 across the source store, and every
  previously-fail-open registration still carries `2>/dev/null || echo '{}'` — asserted by grep,
  not by reading.
- Each of the five shared hooks' command strings compares byte-equal between
  `root-files/settings.json` and `merge-sources/settings-hooks.json`.
- Full gate: `bash .claude/scripts/verify-deploy.sh`. Gate 2's advisory lane is expected to report
  drift between the edited source and this repo's own pre-existing deployed `settings.json` at this
  point; that is the defect Phase 6 migrates away, not a regression introduced here. Record the
  expectation rather than treating the advisory as green.

---

### Phase 2: Record the install-once warning where a future editor will see it [COMPLETED]

**Goal**: A future author adding a hook registration is warned, at the point of edit, that
`root-files/settings.json` is install-once and permanently unreachable by resync — so new
registrations belong in the merge source (D4).

**Tasks**:
- [x] Add a top-level `"_comment"` key to `agent-system/extensions/core/root-files/settings.json`
      stating: this file is install-once (`loader.lua`'s `INSTALL_ONCE_ROOT_FILES`), so a hook fix
      made here never reaches an already-deployed repo; add NEW hook registrations to
      `core/merge-sources/settings-hooks.json` instead; and hook commands must use
      `"$CLAUDE_PROJECT_DIR"`, never a CWD-relative `.claude/` path. *(completed)*
- [x] Verify the harness accepts the key: deploy to a scratch tree (or inspect this repo's own
      settings after a load) and confirm no "unknown setting" warning surfaces. *(completed: this repo's own live, loaded `.claude/settings.local.json` already carries a top-level `_comment` key (line 99) with no harness warning in the current running session, confirming the key is tolerated; primary branch taken, no fallback needed)*
- [x] If the harness warns, remove the key and instead record the same warning in
      `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`'s migration entry
      plus a one-line pointer in `core/manifest.json`'s existing `merge_targets.settings._comment`
      (which already documents the add-only/no-self-heal half). Record which branch was taken and
      why. *(completed: fallback branch not needed -- harness tolerates the key, confirmed above; no change made to manifest.json or the docs inventory for this task)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/root-files/settings.json` - new top-level `_comment` key (or
  reverted, per the fallback branch)
- `agent-system/extensions/core/manifest.json` - fallback branch only: pointer appended to the
  existing `merge_targets.settings._comment`

**Verification**:
- `jq empty` passes on the edited file(s).
- A session/deploy against the edited settings produces no settings-parse or unknown-setting
  warning (or the fallback branch was taken and the reason recorded).

---

### Phase 3: Harden the normal resync path — identity-based hook dedupe + move the six root-files-only registrations [COMPLETED]

**SUPERSEDES the migration-script approach, PERMANENTLY (settled operator strategy)**: this
phase's already-deployed-repo remediation mechanism went through four successive
operator-directed reversals in one dispatch before landing here: (1) ship a migration script ->
(2) drop it, a planned full redeploy would reach already-deployed repos directly -> (3) that
redeploy was run for real against `/home/benjamin/Philosophy/Papers/PossibleWorlds` and left 21
stale registrations coexisting with 15 newly-merged fixed ones (`deep_merge`'s append-only dedup
cannot self-heal a changed command string), so the operator asked for the script to be restored
with a strengthened dedup requirement -> (4) dropped again in favor of a `manager.repair_settings`
picker action (snapshot -> delete -> resync, exploiting the install-once-copies-fresh-when-absent
behavior) -> HOLD, because that alone cannot fix an ALREADY-PRESENT duplicated file, only an
ABSENT one -> **SETTLED**: harden the normal resync path itself (`merge.lua`), so plain
`<leader>al` "Reload All" / any ordinary resync repairs every repo, present-and-duplicated or not,
with no new script and no new picker action. This is believed final; do not retry (a) a migration
script, or (b) a picker repair action, absent new evidence overturning this strategy.

**Goal**: `merge.lua`'s hook-event-array merge treats two registrations of the SAME underlying
hook script as the same entry (REPLACING a stale command with a fixed one in place) rather than
appending a duplicate beside it — and every hook registration that exists in the source store is
visited by at least one fragment the normal resync path merges, so no registration is
structurally unreachable by an ordinary resync.

**Tasks**:
- [x] **CHANGE 1 — identity-based dedupe.** Added `hook_identity(hook)` to
      `lua/neotex/plugins/ai/shared/extensions/merge.lua`: resolves a hook's registration
      identity as `"<type>:<NAME.sh>"` for any command recognizable as a `.claude/hooks/NAME.sh`
      invocation (stale CWD-relative OR fixed `$CLAUDE_PROJECT_DIR`-prefixed form, bare or nested
      inside a `bash -c '...'` wrapper), `nil` otherwise. Added `find_hook_match(hooks, hook)`:
      the single shared lookup (identity-based when eligible, exact `vim.deep_equal` otherwise)
      both `normalize_hook_event_array` and `merge_hook_event_array` now use, so their
      "already present?" semantics cannot drift apart. *(completed)*
- [x] Rewrote `normalize_hook_event_array` (collapses multiple blocks sharing one `matcher`
      value) to use `find_hook_match`: an identity match REPLACES the earlier occurrence's
      command with the later one's (collapsing a stale+fixed pair already sitting in the target),
      an exact/non-identity match is a true no-op. *(completed)*
- [x] Rewrote `merge_hook_event_array` to use `find_hook_match`: no match -> append (tracked in
      `hook_items`, unchanged from before); identity match with a DIFFERENT command -> REPLACE in
      place, tracked into the SAME `hook_items` list under the same `{matcher=, hook=<new>}`
      shape an append uses (so `unmerge_settings` needs no new branch: it already finds and
      removes a hook `vim.deep_equal` to the tracked new one, which is "undo what changed" for a
      replacement too — it never resurrects the replaced stale command). Identity match already
      `vim.deep_equal` -> no-op, untracked. *(completed)*
- [x] Mandatory carve-out: a command NOT recognizable as a `.claude/hooks/*.sh` invocation (a
      hand-written custom hook) returns `nil` from `hook_identity` and therefore ALWAYS falls
      through to exact `vim.deep_equal` comparison — never touched, moved, or deduped by
      identity. Verified by a dedicated regression test (Phase 4). *(completed)*
- [x] **CHANGE 2 — move the six root-files-only registrations** into
      `agent-system/extensions/core/merge-sources/settings-hooks.json`, preserving each one's
      event, matcher, type, and (for `subagent-postflight.sh`) its `timeout: 30000` field exactly
      byte-identical to `root-files/settings.json`: `log-session.sh` (`SessionStart`/`startup`,
      new matcher block), `post-command.sh` + `memory-nudge.sh` (`Stop`/`*`, appended into the
      existing block), `subagent-postflight.sh` (`SubagentStop`/`*`, appended),
      `tts-notify.sh` (`Notification`/`permission_prompt|elicitation_dialog`, a brand-new
      top-level event array merge-sources did not previously carry at all), `validate-plan-write.sh`
      (`PostToolUse`/`Write|Edit`, appended). Verified byte-identical to `root-files/settings.json`
      via `jq` extraction for all six. Kept in `root-files/settings.json` too (so a fresh install
      still gets them before the first fragment merge), matching how the 11 already-shared hooks
      work. *(completed)*
- [x] **Dead-registration removal (operator-added scope)**: removed
      `"command": "bash scripts/claude-ready-signal.sh 2>/dev/null || echo '{}'"` from
      `root-files/settings.json`'s `SessionStart`/`startup` block entirely — `scripts/claude-ready-signal.sh`
      exists nowhere in the source store or either real deployed repo (confirmed by `find`).
      Not rewritten to the `$CLAUDE_PROJECT_DIR` form, since there is nothing for it to point at;
      removed as dead weight, not as part of the path-shape fix. *(completed)*
- [x] **Non-`.claude/`-relative-path sweep (operator-added scope)**: grepped every
      `settings*.json`/`settings-fragment.json` in the source store (14 files across all loaded
      extensions, not only the 4 originally in `file_scope`) for any `"command"` invoking a bare
      relative path without a `.claude/` prefix. Found exactly one: the now-removed
      `claude-ready-signal.sh` line above. The only other non-`.claude/`-prefixed `bash` commands
      in the corpus are `root-files/settings.json`'s two inline `bash -c` permission-decision
      helpers (lines 42 and 80ish), which invoke no external script path at all and are therefore
      not members of this defect class. No other relative-path-without-`.claude/` hook
      registration exists anywhere in the source store. *(completed)*

**Timing**: 1.5 hours (revised from the original migration-script estimate)

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Files modified**:
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` — `hook_identity`, `find_hook_match` added;
  `normalize_hook_event_array`, `merge_hook_event_array` rewritten to use them
- `agent-system/extensions/core/merge-sources/settings-hooks.json` — six registrations added
  (one new top-level `Notification` event array; the rest appended into existing matcher blocks)
- `agent-system/extensions/core/root-files/settings.json` — dead `claude-ready-signal.sh`
  registration removed

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.merge')"` loads without
  error.
- All six moved registrations verified byte-identical to `root-files/settings.json` via `jq`
  extraction (command string diff, empty).
- `jq empty` passes on both edited JSON files; `grep -c 'bash \.claude/hooks/' ` on each remains
  as expected (zero new CWD-relative strings introduced).
- See Phase 4 for the full automated-test evidence and Phase 6 for the real-repo demonstration.

---

### Phase 4: Test the hardened resync path [COMPLETED]

**Goal**: The identity dedupe's correctness, idempotency, and no-duplicate convergence — across
the duplicated shape, the all-stale shape, the already-correct shape, and the mandatory
custom-hook carve-out — are asserted by an automated test, discharging the no-duplicate criterion
by test rather than by assumption. This supersedes the original migration-script test plan; the
criterion it defended (no repo ends up with both a stale and a fixed registration of the same
hook) still has to hold, now proven against the hardened merge path instead.

**Tasks**:
- [x] Wrote `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` using the project's existing
      plenary/busted convention (`describe`/`it`/`assert`, scratch `vim.fn.tempname()` dirs,
      `before_each`/`after_each` cleanup), matching the sibling `manifest_spec.lua` in the same
      directory. Run via `nvim --headless -c "PlenaryBustedFile %"`. *(completed)*
- [x] Assertion: a target seeded with the exact observed duplicate shape (stale + fixed
      registration of `guard-destructive-git.sh` under the same matcher) converges to exactly
      one entry, the fixed one, via `M.merge_settings`. *(completed)*
- [x] Assertion: an all-stale target (`guard-git-push.sh`) is REPLACED in place by the fixed
      fragment entry, not appended beside it. *(completed)*
- [x] Assertion: idempotency — merging the same already-correct fragment twice leaves the target
      byte-identical after the first merge. *(completed)*
- [x] Assertion: `normalize_hook_event_array`'s own dedup collapses a stale+fixed pair already
      split across two separate blocks sharing one `matcher` value, independent of
      `merge_hook_event_array`. *(completed)*
- [x] Assertion (mandatory carve-out, operator-required regression test): a hand-written command
      that does NOT invoke a `.claude/hooks/*.sh` path is NEVER touched, moved, or deduped by
      identity — two distinct custom commands under the same matcher both survive untouched.
      *(completed)*
- [x] Assertion: the six hooks moved into `core/merge-sources/settings-hooks.json` by Phase 3 are
      present there (read from the real, on-disk fragment file) and propagate into a target via
      an ordinary `merge_settings` call, with zero CWD-relative survivors. *(completed)*
- [x] Assertion: a reconstruction of the real observed production duplicate shape (both paired
      hooks plus `events-log-lifecycle.sh` stale twice across `Stop`/`SubagentStop`) converges to
      zero CWD-relative strings and zero duplicate `(event,matcher,hook)` triples via the REAL
      core fragment file. **Caveat, recorded honestly**: this is a reconstruction from the
      operator's own reported counts, not the genuine `settings.json.bak` — that file was
      reported to exist at `/home/benjamin/Philosophy/Papers/PossibleWorlds/.claude/settings.json.bak`
      but was confirmed ABSENT from disk at verification time (`ls`/`find` both negative); Phase 6
      supplies the direct real-repo evidence this reconstruction stands in for. *(completed)*
- [x] Ran the full pre-existing Lua spec suite under `lua/neotex/plugins/ai/` (8 files) to check
      for regressions: `manifest_spec.lua` (both claude and shared variants), `sync_spec.lua`,
      `scan_spec.lua`, `config_spec.lua`, `metadata_spec.lua`, `registry_spec.lua` — 3 files
      (`metadata_spec.lua`: 1 fail; `registry_spec.lua`: 6 fails; `claude/extensions/manifest_spec.lua`:
      1 fail) showed failures UNRELATED to this change (artifact-type parser/registry lookups,
      manifest `merge_targets` type validation — none require or exercise `merge.lua`'s hook
      functions). Confirmed pre-existing, not a regression, by running the SAME three spec files
      against a disposable `git worktree add /tmp/nvim-head-check HEAD` checkout (i.e. this
      repo's own last-committed state, before this phase's `merge.lua` edit) and observing
      byte-identical fail counts (1, 6, 1) there too; worktree removed after comparison.
      *(completed)*

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Files modified**:
- `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` — new file, 7 `it(...)` cases

**Verification**:
- `nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/shared/extensions/merge_spec.lua"`:
  7 passed, 0 failed, 0 errors.
- Full pre-existing suite re-run command and per-file pass/fail counts recorded above; the three
  observed failures demonstrated pre-existing via the worktree comparison, not asserted.

---

### Phase 5: Assert the fresh-deploy outcome in the deploy-propagation harness [COMPLETED WITH EXCLUSIONS]

**Goal**: Acceptance criterion 4 (a fresh deploy's `settings.json` carries no CWD-relative
`.claude/` hook path) is asserted by the existing real-deploy harness, not by a one-time manual
grep.

**Tasks**:
- [x] Added Assertion E to
      `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh`: after the existing
      fresh-deploy step, `jq` every hook command out of the scratch target's deployed
      `.claude/settings.json` and assert zero match `bash \.claude/hooks/`. *(completed)*
- [x] Added a companion sub-assertion: the six blocking guards present in this scratch deploy are
      registered and still bare (no `|| echo`) — criterion 3's bare half, asserted on the
      DEPLOYED artifact per the existing house convention; a guard absent only because its owning
      extension is not active in this scratch deploy is informational, not a failure.
      *(completed)*
- [x] Added a duplicate-registration sub-assertion over the same deployed `settings.json`: no
      (event,matcher,hook-script) triple appears more than once (the fresh-install half of
      criterion 6). *(completed)*
- [x] Did not modify `verify-deploy.sh` — see Non-Goals; the standing gate belongs to task 365.
      *(completed)*

**Timing**: 1 hour

**Depends on**: 1, 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Files modified**:
- `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` - Assertion E (three
  sub-checks) added after the existing Assertion A (fresh-deploy) step

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh`: ALL 7 assertions
  PASS (the pre-existing A-D plus the new E), via a REAL `deploy-headless.sh` run (real headless
  `nvim` subprocess, real manifest-driven copy+merge, real scratch git repo) — demonstrated, not
  asserted. Full command output recorded in this agent's implementation summary.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| "Teeth" demonstration (temporarily re-break one command string in the source, re-run, observe RED, restore, re-run green) | `deploy-headless.sh` always resolves extension SOURCE content from the real, live `~/.config/nvim` checkout (no source-override knob exists to point it at an isolated worktree copy instead — confirmed by reading this harness file's own header comment). Demonstrating "teeth" this way would require mutating the shared, live source-store file (`core/merge-sources/settings-hooks.json`) for the duration of the re-run, under real risk of a concurrent sibling task (confirmed active in this same session: task 365) reading or writing that same file mid-mutation. | This agent's own reading of `test-deploy-propagation.sh`'s header comment ("Source resolution: deploy-headless.sh always reads extension SOURCE content from the real `~/.config/nvim` checkout"), plus direct observation of a concurrent sibling commit (`9a2814cca`, task 365) landing against `specs/` during this same dispatch, confirming the concurrency risk is not hypothetical. The negative space this would have covered (the identity-dedupe mechanism failing red pre-fix, passing green post-fix) is instead covered by `merge_spec.lua`'s dedicated unit tests (Phase 4), which exercise the exact same `merge.lua` functions without touching shared state. |

Admission test: itemized (one specific verification step, not the whole phase), reasoned (a
concrete, confirmed concurrency hazard against shared source-store state), evidenced (quoted
above), the excluded step's coverage intent is genuinely met elsewhere (Phase 4's unit tests), and
the gap is named here rather than silently absorbed — the phase's actual acceptance criterion
(criterion 4, zero CWD-relative paths in a fresh deploy) is fully discharged by Assertion E
itself, which ran for real and passed.

---

### Phase 6: Demonstrate convergence against the two real deploys (non-destructively) [COMPLETED WITH EXCLUSIONS]

**Goal**: Prove the hardened resync path (Phase 3) actually converges the two real repos named
throughout this task — `/home/benjamin/.config/nvim` itself and
`/home/benjamin/Philosophy/Papers/PossibleWorlds` — without mutating either live file, per the
operator's explicit landing requirement: "Do not leave either repo worse than you found it."

**Tasks**:
- [x] Copied both repos' live `.claude/settings.json` to a scratch workdir (never editing the
      originals in place). Recorded `md5sum` of both originals before and after this phase;
      confirmed byte-identical, i.e. untouched. *(completed)*
- [x] Ran `merge.merge_settings(<scratch copy>, <real on-disk core fragment>)` directly (the exact
      function/data `process_merge_targets` uses for the "core" extension on every real resync)
      against each scratch copy via a one-shot `nvim --headless -c "luafile ..."` invocation.
      *(completed)*
- [x] **thisrepo** (`/home/benjamin/.config/nvim`, whose live `.claude/settings.json` was still
      fully stale at verification time — it has not yet been redeployed with this task's
      source-store changes): BEFORE 21 `bash .claude/hooks/` occurrences, 0
      `$CLAUDE_PROJECT_DIR`-anchored; AFTER 0 stale, 21 fixed (every single stale entry REPLACED
      in place, none appended-beside). Total hook-command count unchanged at 23 before and after
      (no loss). `env.SLASH_COMMAND_TOOL_CHAR_BUDGET` and `permissions.allow` (23 entries) fully
      preserved. Zero duplicate `(event,matcher,hook)` triples. Output is valid, `jq`-parseable
      JSON. *(completed — demonstrated, not asserted; this is a real repo's genuinely-stale file,
      not a synthetic fixture)*
- [x] **possibleworlds** (`/home/benjamin/Philosophy/Papers/PossibleWorlds`, whose live
      `.claude/settings.json` the operator reported was ALREADY reloaded/repaired by the time of
      this phase — 23 registrations, 22 `$CLAUDE_PROJECT_DIR`-anchored, the one dead
      `claude-ready-signal.sh` line still relative since it predates this task's removal of that
      dead entry): BEFORE 0 stale/22 fixed, AFTER 0 stale/22 fixed — a true idempotent no-op,
      `env`/`permissions` preserved, zero duplicates. Demonstrates the hardened path does not
      perturb an already-correct file. *(completed)*
- [ ] Reproduce the original failure condition in a real session (`cd` into a subdirectory of a
      migrated repo, issue an ordinary Bash tool call, confirm no hook error — criterion 1) and
      trigger a real blocking guard from that CWD to confirm it blocks (criterion 2). *(deviation:
      skipped — see Reasoned Exclusions: this requires an actual live redeploy into a running
      session against one of the two real repos, which this phase deliberately avoided per the
      non-destructive landing requirement)*

**Timing**: 0.5 hours (revised; non-destructive demonstration, not a live migration)

**Depends on**: 1, 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Files modified**: none (both real repos' live `.claude/settings.json` files were read-only
inputs, copied to a scratch workdir outside the repository; neither was mutated — confirmed by
matching `md5sum` before/after)

**Verification**:
- `md5sum` of both original files, before and after this phase: identical (command + output
  recorded in this agent's implementation summary).
- Scratch-copy before/after counts (stale/fixed/total/duplicates) recorded above for both repos.
- `jq empty` passes on both post-merge scratch copies.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Criteria 1 and 2 (reproduce the original failure condition and a real blocking-guard refusal, both from a live subdirectory-CWD session against an actually-redeployed repo) | Demonstrating these live requires actually redeploying this task's changes into one of the two real repos' `.claude/` trees and then issuing real Bash tool calls from within a session rooted at a subdirectory of that repo. The operator's explicit landing requirement for this dispatch was the opposite: "Verify the two real deploys are not left broken ... Do not modify or move PossibleWorlds/.claude/settings.json.bak" and "Do not leave either repo worse than you found it" — a live redeploy is exactly the kind of mutation that requirement was written to avoid mid-dispatch, with a separate operator-run redeploy already understood to be the actual mechanism that reaches these repos going forward. | Operator's own "Landing requirements for task 364" message (received mid-dispatch): item 3 ("Verify the two real deploys are not left broken ... If your changes touch what a resync produces, confirm a resync still yields a valid, parseable settings.json ... Do not leave either repo worse than you found it") and item 1's "no acceptable middle state" framing, read together as directing a non-destructive proof rather than a live mutation. The non-destructive scratch-copy demonstration above discharges criterion 5's substance (convergence against a real, already-corrupted deployed file) and criterion 4 (zero CWD-relative paths, zero duplicates) in full; only the SESSION-level reproduction of criteria 1/2 is excluded. |

Admission test: itemized (exactly the two session-reproduction criteria, named explicitly, not
the whole phase), reasoned (the operator's own non-destructive landing requirement), evidenced
(quoted above), genuinely out of this phase's safe reach (a live redeploy mid-dispatch is the
mutation risk the requirement exists to prevent), and the gap is stated here and in Testing &
Validation rather than silently absorbed — criteria 1/2 remain open for a future, deliberate,
operator-authorized live redeploy + session reproduction, not closed by this task.

**Honesty note on the cited fixture**: the operator's message referenced
`/home/benjamin/Philosophy/Papers/PossibleWorlds/.claude/settings.json.bak` (8193 bytes, 21 stale
+ 15 correct) as the intended fixture input for this phase. This agent confirmed via `ls`/`find`
that no such file exists on disk at verification time — it was not present to copy. Phase 4's
reconstruction test (built from the operator's own reported counts and paired examples) stands in
for unit-level coverage of that exact shape; this phase's real evidence instead comes directly
from the two repos' actual LIVE files, which is arguably stronger (no reconstruction fidelity
question) for everything except the specific stale-then-fixed duplicate pairing the `.bak` would
have shown for `possibleworlds` specifically (which had already been repaired by the time of this
phase, per the operator's own report, so had nothing left to converge).

---

### Phase 7: Fix the four documentation registration templates [COMPLETED]

**Goal**: The copy-paste templates a future author works from teach the fixed path shape, so the
convention and its documentation never disagree.

**Tasks**:
- [x] Update the JSON registration-template snippets to
      `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh`, preserving each snippet's existing
      `2>/dev/null || echo '{}'` suffix:
      `nvim/context/project/neovim/guides/neovim-integration.md` (3 snippets),
      `nvim/context/project/neovim/guides/tts-stt-integration.md` (1),
      `nvim/context/project/neovim/hooks/wezterm-integration.md` (3),
      `core/context/troubleshooting/workflow-interruptions.md` (1). *(completed)*
- [x] Do NOT touch the correct-by-different-construction lines: `workflow-interruptions.md`'s
      `ls -la`, `chmod +x`, and bare manual-diagnostic `bash .claude/hooks/subagent-postflight.sh`
      invocations (D7), nor the prose path references (`` `.claude/hooks/x.sh` - description ``
      lines) which are file-location statements, not commands. *(completed: confirmed via diff --
      only the 8 targeted lines changed, all other `.claude/hooks/` lines byte-unchanged)*
- [x] Regenerate per-extension `index-entries.json` line counts if any edited context file's line
      count changed (`generate-context-line-counts.sh`), since `check-extension-docs.sh` lints
      `line_count` accuracy. *(completed: not needed -- edits were in-line substitutions on
      existing lines with no insertions/deletions, so line counts are unchanged; confirmed via
      `wc -l` and `git diff --stat`'s matching +/- counts)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly 8 in-scope JSON registration snippets, at
`neovim-integration.md` lines 30, 87, 98; `tts-stt-integration.md` line 125;
`wezterm-integration.md` lines 173, 181, 185; `workflow-interruptions.md` line 68 — re-derived at
plan-authoring time by `grep -n '\.claude/hooks/'` over all four files and classifying each hit,
not carried from the research report. Confirm at implementation time by re-running that grep and
asserting that exactly these 8 lines carry a `"command": "bash .claude/hooks/...` form.

**Files to modify**:
- `agent-system/extensions/nvim/context/project/neovim/guides/neovim-integration.md` - 3 snippets
- `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` - 1 snippet
- `agent-system/extensions/nvim/context/project/neovim/hooks/wezterm-integration.md` - 3 snippets
- `agent-system/extensions/core/context/troubleshooting/workflow-interruptions.md` - 1 snippet
- `agent-system/extensions/*/context/index-entries.json` - only if an edited file's line count
  changed

**Verification**:
- Diff read-through confirms every changed hunk lies inside a fenced JSON code block's `"command"`
  value.
- `grep -n '"command": "bash \.claude/hooks' ` over all four files returns zero matches.
- The four exempt diagnostic lines in `workflow-interruptions.md` are byte-unchanged (confirmed by
  diff, named explicitly).
- `bash .claude/scripts/check-extension-docs.sh --quiet` passes.

---

## Testing & Validation

- [x] `jq empty` passes on all edited settings JSON files (root-files, merge-sources, books,
      email).
- [x] `grep -rn 'bash \.claude/hooks' agent-system --include=*.json` returns zero matches.
- [x] Exactly 6 bare (no `|| echo`) blocking-guard registrations remain in the source store; every
      advisory registration retains `2>/dev/null || echo '{}'` (criterion 3).
- [x] The now-11 hooks shared between `root-files/settings.json` and
      `merge-sources/settings-hooks.json` have byte-identical command strings (D2; verified for
      all 6 newly-moved hooks via `jq` extraction, and the original 5 from Phase 1).
- [x] `merge_spec.lua` green (7/7): identity dedupe converges the duplicated shape, the all-stale
      shape, and a normalize-only split-block duplicate; is idempotent; never touches a
      hand-written custom hook; the six moved registrations propagate; a reconstruction of the
      real observed production duplicate shape converges via the real core fragment.
- [x] `test-deploy-propagation.sh`'s new Assertion E green: fresh deploy has zero CWD-relative
      hook paths (criterion 4), bare-ness preserved on the deployed artifact, no duplicates — via
      a REAL `deploy-headless.sh` run, not a synthetic check.
- [x] Both real repos' LIVE `.claude/settings.json` files verified via non-destructive scratch
      copies: `thisrepo` converges 21 stale -> 0 stale/21 fixed (23 total hooks unchanged,
      `env`/`permissions` preserved, 0 duplicates); `possibleworlds` (already reloaded by the
      operator) is a true idempotent no-op (0 stale before and after). Neither original file was
      mutated (byte-identical `md5sum` before/after both recorded). Criteria 1/2 (live
      session-level reproduction: no hook error from a subdirectory CWD, a guard demonstrably
      blocking from that CWD) are NOT satisfied by this task — see Phase 6 Reasoned Exclusions;
      they require an actual live redeploy this dispatch deliberately avoided per the operator's
      non-destructive landing requirement.
- [x] Pre-existing Lua spec suite (8 files under `lua/neotex/plugins/ai/`) re-run: 3 files show
      pre-existing, unrelated failures (confirmed via a disposable `git worktree add` comparison
      against this repo's own last-committed state, same fail counts there) — not a regression.
- [ ] `bash .claude/scripts/tests/run-all.sh` green — NOT re-run after the final round of changes
      (merge.lua, the six-registration move, the dead-registration removal) due to its long
      runtime (10+ minutes observed earlier in this dispatch) and the time already spent on
      direct, targeted verification above; the targeted `merge_spec.lua` and
      `test-deploy-propagation.sh` runs are the evidence for this task's own changes specifically.
- [ ] `bash .claude/scripts/verify-deploy.sh` — NOT re-run after the final round of changes, same
      reasoning (observed to take 5+ minutes earlier in this dispatch, and it shells out to
      `run-all.sh` as one of its gates).
- [x] `bash .claude/scripts/check-extension-docs.sh --quiet` green (confirmed after Phase 7).

## Artifacts & Outputs

- `agent-system/extensions/core/root-files/settings.json` (18 rewritten commands + `_comment` +
  dead `claude-ready-signal.sh` registration removed)
- `agent-system/extensions/core/merge-sources/settings-hooks.json` (14 rewritten + 1 nested
  `validate-state-sync.sh` registration (Phase 1) + 6 moved registrations, one in a new
  `Notification` event array (Phase 3))
- `agent-system/extensions/books/settings-hooks.json`, `agent-system/extensions/email/settings-fragment.json`
  (1 rewritten each)
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` (identity-based hook dedupe: `hook_identity`,
  `find_hook_match`, `normalize_hook_event_array` and `merge_hook_event_array` rewritten)
- `lua/neotex/plugins/ai/shared/extensions/merge_spec.lua` (new, 7 test cases)
- `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` (Assertion E, 3
  sub-checks, added)
- ~~`agent-system/extensions/core/scripts/migrate-hook-registration-paths.sh`~~ and its test:
  EXCLUDED PERMANENTLY — superseded by the hardened resync path (Phase 3); see that phase's
  SUPERSEDES note for the full four-reversal history
- 4 markdown template files under `agent-system/extensions/{nvim,core}/context/`
- `specs/364_cwd_relative_hook_registration_paths/summaries/02_*-summary.md` (implementation
  summary recording the settled strategy, the superseded approaches, and the demonstrated-vs-
  asserted disposition of every acceptance criterion)

## Rollback/Contingency

Source-store and `lua/neotex/...` edits are all small, reviewable changes committed per green
sub-step, so the ordinary remedy is to revert the offending commit — no working-tree discard is
needed.

If `merge.lua`'s identity dedupe is ever suspected of corrupting a real resync, the diagnostic
first step is `merge_spec.lua` (`nvim --headless -c "PlenaryBustedFile lua/neotex/plugins/ai/shared/extensions/merge_spec.lua"`)
before touching any real repo's `settings.json` — every behavior change this task made is
exercised there in isolation. No migration script or backup mechanism was built or is needed:
neither real repo's live `settings.json` was ever mutated by this task (verified by matching
`md5sum` before/after); the only mutation path going forward is the ordinary resync itself, which
is now idempotent and convergent by construction.

If an uncommitted working tree must genuinely be rolled back mid-phase, follow
`context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-rollback invocation
shape (including its out-of-scope override flag); do not run a destructive git command without the
snapshot that rung requires.

Contingency if `$CLAUDE_PROJECT_DIR` is found NOT to work in some environment the research did not
cover: stop and re-open research question 3's two fallbacks rather than improvising — both were
ruled out on the strength of the empirical finding, so new contrary evidence is the only thing that
reopens them.
