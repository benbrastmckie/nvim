# Implementation Plan: Task #526

- **Task**: 526 - Announce completion and input-needed over TTS from the source store, with a cooldown
- **Status**: [IMPLEMENTING]
- **Effort**: 8.5 hours
- **Dependencies**: Territory edge to the open record `reword_dead_lifecycle_command_prose_per_class` (task 435) — serialization only, no subject overlap. NOT YET RECORDED in `specs/state.json` (`depends_on: null` as of plan authoring); see Risks & Mitigations.
- **Research Inputs**: specs/526_tts_announce_completion_and_input_needed/reports/01_tts-completion-input-needed.md
- **Artifacts**: plans/01_tts-completion-input-needed.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Three coupled source-store changes make the two announcements the operator actually wants fire
exactly once each. `hooks/tts-notify.sh` gains a pane-keyed cooldown gate plus a third mode
(`--stop`) whose utterance is distinguishable by ear; `hooks/claude-stop-notify.sh`'s existing
no-marker branch gains a call into that new mode, with both of its suppression guards left
byte-identical; and the `Notification` matcher widens to include `idle_prompt` in both surfaces
that declare it. Documentation in two files that currently asserts the opposite of the landed
behavior is reconciled in the same pass, and the whole set is redeployed and demonstrated
against the live notification cadence.

The cooldown lands FIRST and the matcher widening depends on it. This is not cosmetic ordering:
the loader's merge engine is additive-only, so a changed matcher string produces a deployed
`settings.json` carrying both the old and the new `Notification` block until the separately-owned
orphan sweep lands — one event then matches two blocks and fires `tts-notify.sh` twice. Widening
the trigger before the cooldown exists would therefore manufacture the exact burst the task is
meant to eliminate.

### Research Integration

Findings carried into this plan:

- All three defects confirmed verbatim against the live source store; both must-preserve guards
  in `claude-stop-notify.sh` present exactly as described (lines 59-67 agent_id, lines 72-83
  workflow-active glob loop).
- A third mode (`--stop`), not a reuse of `--lifecycle`, is the shape that satisfies
  distinguishability and the "lifecycle vocabulary unchanged" constraint simultaneously.
- `hooks/memory-nudge.sh` supplies a directly transferable cooldown shape (timestamp file,
  `NOW - LAST_TIME` comparison, write only on an actual fire). No existing cooldown in this
  codebase is pane-keyed, so `WEZTERM_PANE` keying has no precedent to copy verbatim.
- Zero existing automated check asserts matcher parity between the two settings surfaces, and
  zero existing test suite exercises any of `tts-notify.sh`, `claude-stop-notify.sh`, or
  `lifecycle-notify.sh`. All test coverage in this plan is new work, not an extension.
- A second, independent dead-contract gap lives in the same `lifecycle-notify.sh` header the task
  already requires reconciling: the `orchestrate-active` marker that header describes has zero
  writers anywhere in the source store. Folded into the same reconciliation pass (describe the
  check honestly; do NOT write a producer).
- The lifecycle TTS path (`skill_lifecycle_notify` / `orchestrator-postflight.sh`) is orphaned for
  this repo's core task types, which is why the Stop hook is the structurally correct insertion
  point rather than a narrower fix inside that chain.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap consultation
performed and no roadmap phases added.

## Goals & Non-Goals

**Goals**:

- A finished `/orchestrate` run announces itself, with its own word, exactly once.
- An input-needed wait (`idle_prompt`) announces itself, keeping the bare "Tab N" utterance.
- Repeat announcements are harmless by construction: any double registration, coinciding
  Stop+Notification, or idle re-fire inside the window collapses to one utterance.
- Both settings surfaces declare an identical `Notification` matcher, with a check that asserts it.
- Two documentation surfaces that currently assert the opposite of the implemented behavior are
  restated to match the landed code.
- `TTS_ENABLED=0` still fully disables every path including the new one.

**Non-Goals**:

- No TTS hook added to the user-level `~/.dotfiles/config/claude/settings.json`. Repos with no
  deployed `.claude/` tree stay silent by choice. Settled by the operator; not revisited.
- No `orchestrate-active` marker producer written. The reconciliation obligation is to describe
  the existing check honestly, not to make its condition satisfiable.
- No loader-side stale-registration deletion and no one-shot remediation of repos carrying stale
  registrations — owned by the open `orphan_sweep_for_removed_merge_target_entries` record.
- No deployed-registration-SET-versus-merge-source assertion — owned by the
  `hook_registration_set_lint_assertion` record.
- No edit anywhere under a deployed `.claude/**` tree. It is a gitignored, disposable deploy
  artifact regenerated from the source store.

## Decisions Settled At Plan Time

Research deliberately left two choices open. Both are settled here so no implementation phase
has to re-litigate them.

**Cooldown window: 75 seconds, non-sliding, env-overridable via `TTS_COOLDOWN`.**
Non-sliding means the stamp is written only when `speak()` is actually invoked, never on a
suppressed invocation. This is what makes acceptance criterion 2 demonstrable in both directions
against the real cadence: the observed idle re-fire band tops out at 70 seconds, so every
re-fire lands inside a 75-second window and is suppressed, while the re-fire after that one
(≥120 seconds since the last actual utterance) lands outside it and speaks. A sliding window
would make "one outside it does" unreachable while idle; a window under 70 seconds would leave
part of the observed band unsuppressed.

**Stamp location: `${XDG_RUNTIME_DIR:-/tmp}/claude-tts-cooldown-${UID:-0}-${WEZTERM_PANE:-nopane}`.**
The dispatch offers two options — somewhere a repo without `specs/` can still write, or fail open
silently like the current log write. The runtime-dir form takes the stronger first option, which
matters because the matcher widening reaches every deploy target, not only repos with a `specs/`
tree. This also keeps a principled split: the log is a repo-local evidence surface and stays at
`specs/tmp/claude-tts-notify.log`; the stamp is ephemeral per-pane runtime state and does not
belong in a repository. `UID` is in the key so a shared `/tmp` fallback cannot collide across
users. Every read and write is `2>/dev/null || true`, so a write failure degrades to "cooldown
never engages" — announcing, never silence.

**Three expected `validate-artifact.sh` warnings, not defects to chase.** Phases 1, 2, and 3 each
edit an existing file AND create that file's new test suite in the same phase, so each phase's
`Files to modify` contains a path that does not yet exist on disk. One unmappable path escalates
`suite_selection_select`'s whole multi-path call to `__FULL_SWEEP__` by its documented fail-safe
direction, which makes the validator report each of those three Tier Justifications as a
"fabricated claim". The suite names in all three are measured, not guessed — each justification
states the measured single-path result and names the not-yet-created suite as the reason for the
escalation. Default-mode validation exits 0 (three warnings, zero errors), which is the state the
lifecycle's own `--fix` call site evaluates. Keeping each test beside the code it covers was chosen
over splitting tests into their own phase purely to silence the warning, because the split would
leave each code phase unable to run its own new suite.

**The cooldown gate covers all three modes uniformly**, placed once after the `TTS_ENABLED` and
`piper` guards and before any mode branch. Rationale: the dispatch's load-bearing requirement
names "any future double registration", which includes paths not live today, and a single gate is
the only shape that collapses a lifecycle-`completed` utterance coinciding with a Stop-branch
"done". The trade-off (two genuinely distinct lifecycle transitions less than 75 seconds apart
collapse to one) is accepted: real phase transitions are minutes apart, the window is
env-tunable, and every suppressed invocation is still logged, so no evidence is lost — only audio.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Additive-only merge leaves the deployed `settings.json` carrying both the old and the widened `Notification` block, double-firing `tts-notify.sh` | M | H | Phase 2 depends on Phase 1, so the cooldown always exists first and collapses the double to one utterance. Phase 5 inspects the deployed file and RECORDS the duplicate-block outcome; fixing it is the orphan-sweep record's territory, not this task's. |
| `root-files/settings.json` is install-once and never overwritten on resync, so redeploying this repo does not prove the fix reaches an already-deployed repo | M | H | In-scope boundary already: the widened matcher is proven at the source-store surface and via the new parity check, not by asserting a deployed repo's content. Stated explicitly so Phase 5 is not mistaken for proof that the fix landed everywhere. |
| Time-based (not content-based) suppression can swallow a genuinely distinct second announcement inside the window | L | M | Accepted and intended per the dispatch's own framing. Window held near the measured band rather than much larger; `TTS_COOLDOWN` is env-overridable; suppression is logged. |
| New `--stop` mode's branch placed before the `TTS_ENABLED`/`piper` guards, leaking a fire when TTS is disabled | H | L | Sequence the new branch after the existing early-exit guards, mirroring the existing modes' position, and cover the ordering with the explicit `TTS_ENABLED=0` regression test in Phase 1. |
| Acceptance criteria 1-3 name live, by-ear outcomes a single dispatch cannot fully produce (a complete `/orchestrate` run, an organically idle session) | M | M | Phase 6 discharges each at the deployed-hook level with the real marker-state preconditions and by replaying the measured inter-arrival cadence against the deployed script, and records explicitly which part remains an operator by-ear confirmation on the next real run rather than claiming it was heard. |
| The `depends_on` territory edge to task 435 is absent from `specs/state.json` | M | M | Flagged for the orchestration layer: `update-task-status.sh --depends-on-add`. Not actionable from inside a plan dispatch, and not a blocker for authoring. |
| Three sibling tasks are dispatched this same cycle on this shared tree | M | M | No file overlap with any sibling's `file_scope` (verified at authoring time). Per-file re-read immediately before each edit, explicit-file-list staging only, no reverting `git-snapshot.sh`. Phase 5's `__WHOLE_TREE__` claim will serialize against any sibling making the same claim — expected, not a fault. |
| A new test suite is invisible to `check-extension-docs.sh` Rule Q until its manifest entry exists, and invisible to `sync-manifest-scripts.sh` until `git add`-ed | L | H | Phase 5 stages the new suites BEFORE running `sync-manifest-scripts.sh --write`, in that order. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Cooldown gate and distinguishable `--stop` mode in `tts-notify.sh` [COMPLETED]

**Goal**: `tts-notify.sh` gains a pane-keyed cooldown that collapses any repeat utterance inside
the window, and a third mode whose utterance is distinguishable by ear from the input-needed one.
This is the load-bearing change every later phase depends on.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/hooks/tts-notify.sh` immediately before editing (a
      sibling task may have touched the tree). If the file is absent or its mode-parsing block no
      longer matches what this plan describes, STOP and report rather than editing by inference.
- [x] Add `TTS_COOLDOWN="${TTS_COOLDOWN:-75}"` and
      `COOLDOWN_FILE="${XDG_RUNTIME_DIR:-/tmp}/claude-tts-cooldown-${UID:-0}-${WEZTERM_PANE:-nopane}"`
      to the configuration block, with a comment stating why the stamp is pane-keyed and why it
      lives in the runtime dir rather than beside the log.
- [x] Extend argument parsing with a `--stop` mode flag, leaving the existing
      `--lifecycle STATUS` parse untouched.
- [x] Add a `cooldown_blocked()` helper reading the stamp and comparing `NOW - LAST_TIME` against
      `TTS_COOLDOWN`, and a `cooldown_stamp()` helper writing `date +%s`. Both wrap every file
      operation in `2>/dev/null || true` so a failure degrades to "cooldown never engages".
      `cooldown_stamp()` is called only on a path that actually reaches `speak()`.
- [x] Insert the cooldown check ONCE, after the existing `TTS_ENABLED` and `piper` early-exit
      guards and before the first mode branch. On suppression, log a line naming the mode and the
      elapsed seconds, then `exit_success` — the log stays a complete record of every invocation,
      suppressed or not.
- [x] Add the `--stop` branch after the `--lifecycle` branch and before the no-args interactive
      branch, composing `get_tab_prefix` with the fixed suffix `done` (utterance: "Tab N done").
      Leave the interactive branch's bare "Tab N" and the lifecycle branch's "Tab N STATUS"
      vocabulary byte-identical.
- [x] Update the file's own header comment block to document the third mode, the cooldown, the two
      new environment variables, and the stamp location.
- [x] Create `agent-system/extensions/core/scripts/tests/test-tts-notify.sh` following the house
      convention in `context/standards/shell-script-testing.md`: `set -uo pipefail`, `source
      lib/common.sh`, a loud-skip `REQUIRED_SCRIPTS` existence check, `PASSED`/`FAILED` counters,
      `mktemp -d` workdir with an `EXIT` trap, and content-based assertions. Cases: (a) `--stop`
      emits an utterance containing `done` and the interactive mode does not; (b) `--lifecycle
      researched` still emits exactly `Tab N researched` with no `done`; (c) two invocations
      inside `TTS_COOLDOWN` produce one logged fire and one logged suppression; (d) two
      invocations separated by more than `TTS_COOLDOWN` produce two fires; (e) `TTS_ENABLED=0`
      produces zero fires in all three modes; (f) two distinct `WEZTERM_PANE` values do not
      suppress each other.
- [x] Drive the cooldown cases by setting `TTS_COOLDOWN` small and by pre-seeding the stamp file
      with a chosen `date +%s` offset, rather than by sleeping — the window's semantics are what
      is under test, not wall-clock duration.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: `hooks/tts-notify.sh` is the only file in the source store carrying a
`speak()`/`piper` invocation path, so the cooldown placed inside it gates every TTS utterance
with no second site to patch. Confirm at implementation time with
`grep -rln "piper\|speak()" agent-system/extensions/core/hooks/ agent-system/extensions/core/scripts/`
and widen this phase only if a second utterance site appears.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-lint-hook-registration-paths.sh,test-tts-notify.sh` covers the one edited hook plus this
phase's own new suite — `suite_selection_select` returns exactly
`test-lint-hook-registration-paths.sh` for `hooks/tts-notify.sh` as measured at authoring time and
escalates the pair to `__FULL_SWEEP__` only because `test-tts-notify.sh` does not yet exist on
disk, so the implementer re-derives and re-confirms this list once that suite is created.

**Files to modify**:

- `agent-system/extensions/core/hooks/tts-notify.sh` - exists (confirmed at authoring time; 122 lines, no cooldown state). Add cooldown config, `cooldown_blocked`/`cooldown_stamp` helpers, the gate, the `--stop` branch, and header documentation. If absent at implementation time, STOP and report rather than recreating it.
- `agent-system/extensions/core/scripts/tests/test-tts-notify.sh` - create; new suite, no existing file to amend.

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-tts-notify.sh,test-lint-hook-registration-paths.sh` passes.
- `bash .claude/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/hooks/tts-notify.sh agent-system/extensions/core/scripts/tests/test-tts-notify.sh` exits 0 (the sanctioned entry point, not the bare binary; exit 70 means `shellcheck` is unresolvable and is a failure, never a skip).
- Diff read-through confirms the `--lifecycle` vocabulary and the interactive bare-"Tab N"
  utterance are byte-identical to their pre-edit form.

---

### Phase 2: Widen the `Notification` matcher in both declaring surfaces [NOT STARTED]

**Goal**: `idle_prompt` — the actionable "has been waiting for input" notification type — gains a
trigger, in both surfaces that declare the matcher, with a check that asserts the two agree.

**Tasks**:

- [ ] Re-read both settings files immediately before editing.
- [ ] Change the `Notification` matcher in
      `agent-system/extensions/core/merge-sources/settings-hooks.json` from
      `permission_prompt|elicitation_dialog` to `permission_prompt|idle_prompt|elicitation_dialog`.
- [ ] Make the identical change in `agent-system/extensions/core/root-files/settings.json`.
      These two edits are one atomic unit: landing one without the other leaves a fresh deploy and
      a resynced deploy disagreeing.
- [ ] Validate both files parse: `jq empty` on each.
- [ ] Create `agent-system/extensions/core/scripts/tests/test-notification-matcher-parity.sh`
      following the same house convention as Phase 1's suite. Cases: (a) the `.hooks.Notification`
      matcher list extracted from each file via `jq` is byte-equal across the two files; (b) that
      shared matcher contains `idle_prompt`; (c) a deliberately divergent fixture pair is detected
      as a failure, so the check is proven to be able to fail.
- [ ] Record in the test's header that this closes acceptance criterion 4 and that no prior check
      compared these two files against each other.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: exactly two source-store surfaces declare this matcher —
`merge-sources/settings-hooks.json:64` and `root-files/settings.json:188` — with every other
occurrence of the literal out of scope (the regenerated `.claude-extensions.json` deploy manifest,
`.opencode/settings.json` belonging to a different system, and archived task-369 fixtures).
Confirm at implementation time with
`grep -rln "permission_prompt" --include=*.json agent-system/` and treat any third live
`agent-system/**` surface as a scope expansion to report, not to silently absorb.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-deploy-propagation.sh,test-lint-hook-registration-paths.sh,test-gate-cache-equivalence.sh,test-gate-cache-lib.sh,test-gate-registry-resolution.sh,test-guard-git-push.sh,test-sapience-mcp-registration.sh,test-verify-deploy-gate-selection.sh,test-notification-matcher-parity.sh`
covers both edited files — which span two files and so exceed `local` — plus this phase's own new
parity suite; that eight-suite list is the exact union `suite_selection_select` returns for the two
settings paths as measured at authoring time, and the pair escalates to `__FULL_SWEEP__` only
because `test-notification-matcher-parity.sh` does not yet exist on disk, so the implementer
re-derives and re-confirms the list once that suite is created.

**Files to modify**:

- `agent-system/extensions/core/merge-sources/settings-hooks.json` - exists (confirmed at authoring time; matcher at line 64). Widen the `Notification` matcher only; no other key changes. If absent, STOP and report.
- `agent-system/extensions/core/root-files/settings.json` - exists (confirmed at authoring time; matcher at line 188). Identical widening. If absent, STOP and report.
- `agent-system/extensions/core/scripts/tests/test-notification-matcher-parity.sh` - create; new suite.

**Verification**:

- The new parity suite passes, and its deliberately-divergent fixture case demonstrates the check
  can fail.
- `jq -r '.hooks.Notification[].matcher'` on each of the two files prints
  `permission_prompt|idle_prompt|elicitation_dialog` and nothing else.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only` with the suite list named in
  the Tier Justification passes.

---

### Phase 3: Fire the Stop-branch announcement from `claude-stop-notify.sh` [NOT STARTED]

**Goal**: the no-workflow-marker branch announces a finished run, with both existing suppression
guards left byte-identical and each covered by its own regression check.

**Tasks**:

- [ ] Re-read `agent-system/extensions/core/hooks/claude-stop-notify.sh` immediately before
      editing.
- [ ] In the no-marker branch, AFTER the existing `wezterm-notify.sh` invocation and before
      `exit_success`, add a guarded call: resolve `$SCRIPT_DIR/tts-notify.sh`, test `-f`, and
      invoke `bash "$tts_script" --stop 2>/dev/null || true` — the same shape the sibling
      `wezterm-notify.sh` call already uses, so `set -euo pipefail` cannot turn a missing or
      failing hook into a Stop-hook failure.
- [ ] Replace the now-false inline comment "Fire needs_input wezterm color only (no TTS for
      non-lifecycle stops)" with one stating what the branch now does.
- [ ] Leave the agent_id subagent guard and the global `workflow-active-*` glob suppression loop
      untouched, including the header paragraphs documenting why the suppression is deliberately
      global across sessions. Extend the header's architecture summary to mention the new TTS call
      in the no-marker branch; do not weaken or rescope the suppression rationale.
- [ ] Create `agent-system/extensions/core/scripts/tests/test-claude-stop-notify.sh` following the
      house convention. Cases: (a) stdin JSON carrying `agent_id` exits via the subagent guard
      with zero TTS invocation; (b) a present `workflow-active-<anything>` marker exits via the
      suppression loop with zero TTS invocation, including a marker belonging to a DIFFERENT
      session id (the global-scope property); (c) no marker and no `agent_id` reaches exactly one
      `tts-notify.sh --stop` invocation; (d) the hook still emits valid `{}` JSON on stdout and
      exits 0 on every one of those paths.
- [ ] Observe `tts-notify.sh` invocation by shimming it inside the test's `mktemp -d` fixture
      (a deployed-tree-shaped `hooks/` directory holding the real `claude-stop-notify.sh` beside a
      recording stub), not by relying on audio or on the real script. The hook resolves its
      siblings through `SCRIPT_DIR`, so a fixture directory is the correct and only reliable
      observation point.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the two guards this phase must preserve are exactly the `agent_id` block at
lines 59-67 and the `workflow-active-*` glob loop at lines 72-83, and the file contains no
existing `tts-notify.sh` call to adapt. Confirm by re-reading the file and running
`grep -n "tts-notify\|agent_id\|WORKFLOW_ACTIVE_GLOB"` on it immediately before editing; any
divergence from this shape is a report, not an improvisation.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-lint-hook-registration-paths.sh,test-claude-stop-notify.sh` covers the one edited hook plus
this phase's own new suite — `suite_selection_select` returns exactly
`test-lint-hook-registration-paths.sh` for `hooks/claude-stop-notify.sh` as measured at authoring
time and escalates the pair to `__FULL_SWEEP__` only because `test-claude-stop-notify.sh` does not
yet exist on disk, so the implementer re-derives and re-confirms this list once that suite is
created.

**Files to modify**:

- `agent-system/extensions/core/hooks/claude-stop-notify.sh` - exists (confirmed at authoring time; 92 lines, no TTS call). Add the guarded `--stop` call in the no-marker branch, correct the inline comment, extend the header. If absent, STOP and report.
- `agent-system/extensions/core/scripts/tests/test-claude-stop-notify.sh` - create; new suite.

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-claude-stop-notify.sh,test-lint-hook-registration-paths.sh` passes.
- `git diff` on `claude-stop-notify.sh` shows zero changed lines inside the agent_id block and the
  glob loop.
- `bash .claude/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/hooks/claude-stop-notify.sh agent-system/extensions/core/scripts/tests/test-claude-stop-notify.sh` exits 0 (the sanctioned entry point, not the bare binary).

---

### Phase 4: Reconcile both documentation surfaces to the landed behavior [NOT STARTED]

**Goal**: no claim in either documentation surface survives that the landed code contradicts,
including the second, independently-dead `orchestrate-active` contract in the same header.

**Tasks**:

- [ ] Re-read both files immediately before editing.
- [ ] In `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md`,
      replace the assertion "The Stop hook does NOT trigger TTS. This eliminates random 'Tab N'
      announcements during mid-workflow orchestrator pauses." with a statement of the implemented
      behavior: the Stop hook DOES announce, in its no-marker branch only, with its own utterance;
      mid-workflow pauses stay silent because of the workflow-active-marker suppression and the
      subagent guard, not because the hook declines to announce.
- [ ] Add `idle_prompt` to that file's "Notification Event Types" table with its real trigger
      (Claude has been waiting for user input) and its utterance ("Tab N"), and add a row for the
      Stop-branch completion announcement ("Tab N done").
- [ ] Update that file's embedded hook-configuration JSON snippet so its matcher matches the
      landed `permission_prompt|idle_prompt|elicitation_dialog`.
- [ ] Replace that file's "No cooldown or signal file mechanism" claim under "The --lifecycle Flag
      in tts-notify.sh" with the real cooldown contract: pane-keyed stamp, default window,
      `TTS_COOLDOWN` override, applies to all three modes, fails open.
- [ ] Document the three modes and their three distinct utterances in one place in that file, and
      add `TTS_COOLDOWN` to its environment-variable table.
- [ ] In `agent-system/extensions/core/scripts/lifecycle-notify.sh`, restate the header's
      four-bullet decision table so every bullet matches the code. The two bullets promising
      Stop-hook TTS are now TRUE and stay, pointing at the no-marker branch as the mechanism. The
      two `orchestrate-active` bullets are restated honestly: the file-existence check exists in
      code, and nothing in the source store writes that file, so that auto-suppression path does
      not currently engage.
- [ ] Confirm the reconciliation leaves no remaining claim in either file that the landed code
      contradicts, by re-reading both files end to end against the Phase 1-3 diffs rather than
      spot-checking the lines this phase edited.

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: the false claims to correct are the four enumerated locations in
`tts-stt-integration.md` (the Stop-hook assertion near line 98, the Notification Event Types table
near line 162, the embedded matcher snippet near line 121, the "No cooldown or signal file
mechanism" line near line 175) plus the four-bullet decision table in `lifecycle-notify.sh`'s
header (lines 22-29). This phase deliberately EXCLUDES any behavior change to
`lifecycle-notify.sh` and any new `orchestrate-active` producer; every task above is a comment or
prose edit, consistent with that exclusion. Confirm the enumeration by re-reading both files end
to end; correct any additional contradicted claim found, and record the widened count.

**Tier Justification**: a diff read-through confirming every changed hunk lies inside a
comment or prose region, run together with
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
— `suite_selection_select` returns `__FULL_SWEEP__` for the markdown file, so no suite covers it
and the source-store doc-lint plus task-reference-lint gate subset is the honest covering check.

**Files to modify**:

- `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` - exists (confirmed at authoring time; 433 lines). Restate the Stop-hook claim, the event-types table, the embedded matcher snippet, the no-cooldown claim; document the three modes and `TTS_COOLDOWN`. If absent, STOP and report.
- `agent-system/extensions/core/scripts/lifecycle-notify.sh` - exists (confirmed at authoring time; 72 lines). Header comment block only — no executable line changes. If absent, STOP and report.
- `agent-system/extensions/nvim/index-entries.json` - exists (confirmed at authoring time; carries `line_count: 433` for `project/neovim/guides/tts-stt-integration.md`). Coupled generated surface: this phase's prose edits move that derived line count. `check-extension-docs.sh` Rule R is NOT commit-blocking in this repository (no `pre-commit` hook is installed), so the regeneration itself is scheduled in Phase 5, where `deploy-headless.sh` repairs it as a side effect; the declaration is owed here regardless.

**Verification**:

- Diff read-through confirms every changed hunk in both files lies inside a comment or prose
  region, with zero executable lines of `lifecycle-notify.sh` touched.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  reports no new finding and does not SKIP both selected gates.
- Grep confirms no surviving occurrence of "does NOT trigger TTS", "No cooldown or signal file
  mechanism", or a bare `permission_prompt|elicitation_dialog` matcher in
  `tts-stt-integration.md`.
- Both files contain no task-number reference and no record-versioning language.

---

### Phase 5: Register the new suites, reconcile the derived line count, and redeploy [NOT STARTED]

**Goal**: the three new test suites are declared in their extension manifest, the derived
line_count is reconciled, and the source store is landed into this repo's deployed tree.

**Tasks**:

- [ ] Stage the three new test suites with an explicit file list (`git add -- <three paths>`),
      never a directory or glob pathspec. `sync-manifest-scripts.sh` diffs against `git ls-files`,
      so an untracked new suite is invisible to it; staging must precede the sync.
- [ ] Run `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` to see the
      gap, then `--write` to insert the three `provides.scripts` entries into
      `agent-system/extensions/core/manifest.json`.
- [ ] Re-run `--check` and confirm it reports clean in both directions.
- [ ] Redeploy with the bounded-wait idiom required for this repo's stale deployed tree:
      `timeout 540 bash .claude/scripts/deploy-headless.sh`, invoked with the Bash tool's
      `timeout` parameter raised to 600000. Confirm `RESULT=landed_verify_clean`. If the deploy
      reports any other RESULT, treat it as a blocker to report, not a step to retry blindly.
- [ ] Confirm the redeploy repaired `agent-system/extensions/nvim/index-entries.json`'s
      `line_count` for `tts-stt-integration.md` to the post-Phase-4 value. If it did not, run
      `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` and
      confirm.
- [ ] Inspect the deployed `.claude/settings.json`'s `Notification` blocks and RECORD what landed:
      whether the additive-only merge left both the old and the widened matcher block present.
      Record the observation in this task's issue log. Do NOT hand-patch the deployed file — that
      would mask the divergence, and the remediation is the orphan-sweep record's territory.
- [ ] Confirm the deployed `.claude/hooks/tts-notify.sh` and `.claude/hooks/claude-stop-notify.sh`
      carry this task's changes, as evidence the source-store edits actually propagated.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly three new test suites need `provides.scripts` entries
(`tests/test-tts-notify.sh`, `tests/test-notification-matcher-parity.sh`,
`tests/test-claude-stop-notify.sh`), and the deploy reaches `RESULT=landed_verify_clean`. Confirm
the first with `sync-manifest-scripts.sh --check` before and after the `--write`, and the second
from the deploy script's own final RESULT line; a different suite count means an earlier phase
created more or fewer suites than planned and the count is simply updated.

**Tier Justification**: whole-tree regeneration of the deployed `.claude/` tree rewrites every
hook registration, every deployed script, and the merged settings surface at once — a cross-cutting
surface no suite subset or gate subset covers, since the thing under test is the propagation itself
rather than any one file.

**Files to modify**:

- `agent-system/extensions/core/manifest.json` - exists (confirmed at authoring time; `provides.scripts` holds 412 entries). Add three entries via `sync-manifest-scripts.sh --write`, not by hand. If absent, STOP and report.
- `agent-system/extensions/nvim/index-entries.json` - exists. Derived `line_count` reconciliation for `tts-stt-integration.md`, by regeneration rather than hand-edit.
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`, which is an implicit scope claim over the entire deployed tree that no real declared path can express.

**Verification**:

- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` reports clean in
  both directions.
- `deploy-headless.sh` prints `RESULT=landed_verify_clean`.
- `agent-system/extensions/nvim/index-entries.json`'s `line_count` for
  `project/neovim/guides/tts-stt-integration.md` equals `wc -l` of that file.
- The deployed `.claude/hooks/tts-notify.sh` contains the cooldown helpers and the `--stop` branch,
  and the deployed `.claude/hooks/claude-stop-notify.sh` contains the `--stop` call.
- The deployed `.claude/settings.json`'s `Notification` block state is recorded in the issue log,
  whatever it turned out to be.

---

### Phase 6: Demonstrate every acceptance criterion against the deployed tree [NOT STARTED]

**Goal**: each of the six acceptance criteria is discharged against the deployed hooks, with the
one part that only a real operator session can supply named as such rather than claimed.

**Tasks**:

- [ ] Criterion 1 (exactly one announcement, distinguishable by ear): drive the deployed
      `.claude/hooks/claude-stop-notify.sh` with no `workflow-active-*` marker present and stdin
      JSON carrying no `agent_id`, and assert the log records exactly one `--stop` fire whose
      utterance contains `done`. Then drive the Notification path and assert its utterance is the
      bare tab prefix with no `done`. Record that the final by-ear confirmation happens on the
      operator's next real `/orchestrate` run; do not report having heard it.
- [ ] Criterion 2 (idle re-fire inside the window silent, outside it audible — against the real
      cadence, not only a synthetic repeat): replay the measured inter-announcement intervals from
      the cited `claude-tts-notify.log` corpus against the deployed script by pre-seeding the
      pane-keyed stamp at each real interval offset, and assert that every interval in the
      observed 10-70 second band is suppressed while the following re-fire (beyond the window
      since the last actual utterance) fires. Record the per-interval outcome table as the
      evidence, not a single pass/fail.
- [ ] Criterion 3 (mid-orchestrate pause still silent, both guards intact): re-run the Phase 3
      regression suite against the DEPLOYED hook, confirming the marker-suppression path and the
      `agent_id` path each reach zero TTS invocations.
- [ ] Criterion 4 (matcher parity asserted by a check): re-run the Phase 2 parity suite and
      confirm it is discovered by `run-all.sh` without `--only`, so it participates in Gate 8 from
      now on rather than only when named.
- [ ] Criterion 5 (no documentation claim contradicted by landed code): re-read both reconciled
      files against the landed deployed scripts and record the confirmation.
- [ ] Criterion 6 (`TTS_ENABLED=0` disables everything): invoke the deployed `tts-notify.sh` with
      `TTS_ENABLED=0` in all three modes, and the deployed `claude-stop-notify.sh` with
      `TTS_ENABLED=0` exported, asserting zero fires and that the cooldown stamp is left
      unperturbed on every one of those paths.
- [ ] Run the complete gate set and record its verdict.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: six acceptance criteria are discharged here, of which criterion 1's by-ear
half is the only one no dispatch can produce on its own. Confirm by walking the dispatch's own
numbered acceptance list item by item and recording an evidence line for each; a criterion that
cannot be discharged is reported as such, never silently dropped or declared met by argument.

**Files to modify**:

- No source files. This phase produces evidence, not edits.

**Verification**:

- `bash .claude/scripts/verify-deploy.sh` — the complete gate set, every gate, no
  `--skip-slow`, no `--only-gate`, no `--skip-unchanged` — passes.
- `bash .claude/scripts/tests/run-all.sh` passes with all three new suites discovered.
- Each of the six acceptance criteria has a recorded evidence line, with criterion 1's by-ear half
  explicitly marked as pending the operator's next real run.

---

## Testing & Validation

- [ ] `test-tts-notify.sh` covers the three utterance vocabularies, the cooldown in both
      directions, pane independence, and `TTS_ENABLED=0`.
- [ ] `test-claude-stop-notify.sh` covers the `agent_id` guard, the global marker suppression
      (including a foreign session's marker), and the single `--stop` invocation on the no-marker
      path.
- [ ] `test-notification-matcher-parity.sh` asserts byte-equality of the two surfaces' matchers,
      asserts `idle_prompt` is present, and proves it can fail on a divergent fixture.
- [ ] All three suites are discovered by `run-all.sh` with no `--only` filter, so Gate 8 carries
      them.
- [ ] `verify-deploy.sh` passes complete, unnarrowed.
- [ ] No file landing under `agent-system/**` carries a task-number reference or
      record-versioning language.

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/hooks/tts-notify.sh`,
  `agent-system/extensions/core/hooks/claude-stop-notify.sh`,
  `agent-system/extensions/core/merge-sources/settings-hooks.json`,
  `agent-system/extensions/core/root-files/settings.json`,
  `agent-system/extensions/core/scripts/lifecycle-notify.sh`,
  `agent-system/extensions/core/manifest.json`,
  `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md`,
  `agent-system/extensions/nvim/index-entries.json`.
- Created: `agent-system/extensions/core/scripts/tests/test-tts-notify.sh`,
  `agent-system/extensions/core/scripts/tests/test-claude-stop-notify.sh`,
  `agent-system/extensions/core/scripts/tests/test-notification-matcher-parity.sh`.
- Regenerated: this repository's deployed `.claude/` tree, via `deploy-headless.sh`.
- Recorded: the deployed `Notification` block state after the additive merge, and a per-interval
  cooldown outcome table against the real cadence.

## Rollback/Contingency

Every phase commits its own green sub-steps, so reverting is per-commit rather than wholesale. If
a later phase fails, the safe partial states are: Phase 1 alone (a cooldown and an unused third
mode, zero behavior change for any existing caller — fully inert), and Phases 1+3 without Phase 2
(completion announces, input-needed still has no trigger — a strict improvement over the current
silence). Phase 2 alone is the one state to avoid, which is exactly why it depends on Phase 1.

If a redeploy in Phase 5 fails or reports a RESULT other than `landed_verify_clean`, the source
store is already correct and committed; the deployed tree is a disposable artifact that a later
redeploy regenerates, so no source-store rollback is warranted — report the deploy failure instead.

Before any intentional rollback that would otherwise be blocked, run
`bash .claude/scripts/git-snapshot.sh 526` first. Do NOT use the reverting default form as a
routine checkpoint; use `bash .claude/scripts/git-snapshot.sh 526 --no-revert` for an ordinary
defensive checkpoint before the Phase 5 redeploy.
