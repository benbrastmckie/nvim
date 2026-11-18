# Research Report: Task #526

**Task**: 526 - Announce completion and input-needed over TTS from the source store, with a cooldown
**Started**: 2026-11-17
**Completed**: 2026-11-17
**Effort**: medium
**Dependencies**: Territory edge to the open record `reword_dead_lifecycle_command_prose_per_class` (task 435) — serialization only, no subject overlap (see Decisions)
**Sources/Inputs**: Codebase (agent-system/extensions/core/**, agent-system/extensions/nvim/**), specs/state.json
**Artifacts**: - specs/526_tts_announce_completion_and_input_needed/reports/01_tts-completion-input-needed.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All three stated defects are confirmed verbatim against the live source store: `claude-stop-notify.sh`'s no-marker branch fires only `wezterm-notify.sh` (line 87-90); `lifecycle-notify.sh`'s header (lines 25-29) promises Stop-hook TTS on orchestrate completion that the code does not deliver; both `merge-sources/settings-hooks.json` (line 64) and `root-files/settings.json` (line 187) declare `"permission_prompt|elicitation_dialog"` with no `idle_prompt`; and `tts-notify.sh` has no cooldown/dedup mechanism of any kind.
- The fix shape is straightforward: add a `tts-notify.sh` call (new mode, distinct from `--lifecycle STATUS`) to `claude-stop-notify.sh`'s existing no-marker branch; widen both settings surfaces' matcher identically; add a pane-keyed cooldown stamp inside `tts-notify.sh` gating `speak()`.
- A significant, non-obvious finding for the documentation-reconciliation pass: the `.claude/tmp/orchestrate-active` marker that `lifecycle-notify.sh`'s header and body (line 56) describe as the mid-orchestrate TTS suppressor is never written by anything in the source store — a repo-wide search found zero writers. This is a second, independent gap in the same file the dispatch already requires reconciling, and should be folded into that same pass (see Findings and Recommendations).
- A related but genuinely live mechanism — the `workflow-active-<CC_SESSION_ID>` marker written by `update-task-status.sh` preflight and read by `claude-stop-notify.sh`'s own glob loop — is the actual, working suppression `claude-stop-notify.sh` already relies on. It is a separate file from `orchestrate-active` and must not be confused with it when rewording the header.
- No existing automated check asserts that the two settings surfaces' `Notification` matchers agree (acceptance criterion 4); none of `lint-hook-registration-paths.sh`, `verify-deploy.sh`'s hook-registration gate, or any `scripts/tests/*` file does this today. A new check is needed.
- No existing regression test exercises `claude-stop-notify.sh`, `tts-notify.sh`, or `lifecycle-notify.sh` at all; `scripts/tests/` has zero files named for any of the three. Acceptance criteria 2, 3, and 6 all require new test coverage from scratch, not an extension of an existing suite.

## Context & Scope

This is a research pass for a `meta` task whose edit target is the source store
(`agent-system/extensions/core/**` and `agent-system/extensions/nvim/**`), per the dispatch's
explicit instruction. The dispatch states the diagnosis (three defects) as established fact and
asks research to confirm current file state and design the fix, not re-diagnose. This report
follows that instruction: Findings confirm file state and surface facts the dispatch did not
already state; Recommendations propose a fix design; nothing here re-litigates Defects 1-3
themselves.

The six `file_scope` paths from `specs/state.json` were each read in full:
- `agent-system/extensions/core/hooks/tts-notify.sh`
- `agent-system/extensions/core/hooks/claude-stop-notify.sh`
- `agent-system/extensions/core/merge-sources/settings-hooks.json`
- `agent-system/extensions/core/root-files/settings.json`
- `agent-system/extensions/core/scripts/lifecycle-notify.sh`
- `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md`

Plus supporting files read to establish call-graph context: `hooks/wezterm-notify.sh`,
`hooks/wezterm-utils.sh`, `hooks/wezterm-preflight-status.sh`, `hooks/memory-nudge.sh`,
`scripts/update-task-status.sh` (workflow-active marker write site), `scripts/skill-base.sh`
(`skill_lifecycle_notify`), `scripts/orchestrator-postflight.sh`, `scripts/orchestrate-cycle-plan.sh`
(preflight call site), `scripts/verify-deploy.sh` (gate2, hook-registration check),
`scripts/lint/lint-hook-registration-paths.sh`, `scripts/tests/test-git-commit-phase.sh` (test-house-style reference).

## Findings

### Codebase Patterns

**Defect 1 confirmed verbatim.** `hooks/claude-stop-notify.sh` lines 85-91:
```bash
# --- No active workflow: interactive / non-lifecycle stop ---
# Fire needs_input wezterm color only (no TTS for non-lifecycle stops)
wezterm_script="$SCRIPT_DIR/wezterm-notify.sh"
if [[ -f "$wezterm_script" ]]; then
    bash "$wezterm_script" 2>/dev/null || true
fi
exit_success
```
No call to `tts-notify.sh` anywhere in the file. The two guards the dispatch names as
must-preserve are both present and exactly as described: the `agent_id` subagent guard
(lines 62-67) and the global `workflow-active-*` glob suppression loop (lines 72-83), the latter
keyed on existence of *any* session's marker (header lines 12-19 explicitly document this as
deliberate, not a scoping bug).

**Defect 1's live suppression mechanism, confirmed and distinguished from a second, unrelated,
dead marker.** The glob `claude-stop-notify.sh` checks (`workflow-active-*`) is written by
`update-task-status.sh` at its `preflight` operation (line 1197:
`echo "$task_number $(common_timestamp_iso)" > "$SCRIPT_DIR/../tmp/workflow-active-${marker_session_key}"`),
keyed by `${CLAUDE_CODE_SESSION_ID:-$session_id}` — Claude Code's own native session UUID. It is
cleared only by `wezterm-preflight-status.sh`'s Tier 2 branch (a later non-lifecycle
`UserPromptSubmit`) or its ESC-cancel path, both scoped to the current session's own marker only
(header lines 12-27 of that file). `update-task-status.sh` itself never clears it at
`postflight`. This is a real, live, exercised mechanism — `scripts/orchestrate-cycle-plan.sh`
line 2829-2830 calls `skill_preflight_update` (which wraps this write) once per phase per cycle.

**A second, textually similar but entirely separate marker — `.claude/tmp/orchestrate-active` —
is dead.** `scripts/lifecycle-notify.sh` lines 22-29 (header) and line 56 (body:
`if [[ -f "$SCRIPT_DIR/../tmp/orchestrate-active" ]]; then QUIET="--quiet"; fi`) describe and
implement an auto-suppression keyed to this literal filename. A repository-wide search
(`grep -rln "orchestrate-active" .` from `agent-system/`, cross-checked by also grepping
`scripts/`, `hooks/`, `commands/`, `skills/`, `agents/` individually, and separately searching
for `touch`/`>`-redirect patterns near "orchestrate" in `orchestrate-cycle-plan.sh`,
`orchestrate-stage5-postflight.sh`, and `orchestrate-build-dispatch.sh`) found **zero** writers
of this file anywhere in the source store or the deployed tree
[COVERAGE-UNVERIFIED: `grep -rln "orchestrate-active" agent-system/` plus targeted `touch`/
redirect greps in the three orchestrate-cycle scripts named above / a second, differently-shaped
pattern (e.g. a semantic AST-level write-site scan) was not run — this is a literal-string and
`touch`/redirect search only]. Every call site of `lifecycle-notify.sh` itself
(`skill_lifecycle_notify` in `skill-base.sh`; the inline Stage 8b block in
`skill-reviser/SKILL.md`; the orphaned Stage 8b in `orchestrator-postflight.sh`) passes only the
status argument, never `--quiet`, so `--quiet` can only ever be set via this always-false file
check. **This is a separate, independent gap from Defect 1-3**, living in the exact file
(`lifecycle-notify.sh`) the dispatch already names for header reconciliation (criterion 5), and
is squarely in scope for that same pass: the header's "mid-orchestrate research completes:
orchestrate-active exists -> TTS suppressed" bullet is untrue today regardless of this task's own
three fixes, because nothing ever makes that condition true. Writing an `orchestrate-active`
marker producer is explicit non-goal territory this task's dispatch does not ask for (the
dispatch's FIX list is scoped to Defects 1-3 only) — the reconciliation obligation is to
describe the code honestly (the check exists; nothing in the source store currently satisfies
its condition), not to implement a new marker writer.

**`scripts/orchestrator-postflight.sh` and `skill_lifecycle_notify` are confirmed orphaned for
the operator's actual usage pattern.** `orchestrator-postflight.sh`'s own header (lines 59-66)
states: "No current caller invokes this script directly (skill-orchestrate handles
research/plan/implement postflight inline via skill-base.sh instead) -- confirmed orphaned by a
repo-wide grep." Independently, `skill_lifecycle_notify` (defined in `skill-base.sh` lines
1403-1418) has zero call sites anywhere under `scripts/*.sh`
[COVERAGE-UNVERIFIED: `grep -rln "skill_lifecycle_notify" agent-system/extensions/core/` /
only a literal-identifier grep was run, not a second differently-shaped pattern such as a
sourced-function-call AST scan] — its only live callers are extension lifecycle `SKILL.md` files
(e.g. `skill-reviser/SKILL.md` Stage 8b, `skill-nix-research/SKILL.md`'s own Stage 8a per
`context/patterns/skill-postflight-flow.md`). Per `.claude/CLAUDE.md`'s routing table, the core
task types this task itself is one of (`general`, `meta`, `markdown`) route **directly to
agents** via `skill-orchestrate`'s dispatch, bypassing any dedicated lifecycle skill layer
entirely — so neither `orchestrator-postflight.sh` nor `skill_lifecycle_notify` is ever reached
for a `meta`-type task's research/plan/implement phases. This corroborates, rather than
contradicts, the dispatch's framing ("Today neither fires"): for the operator's own task type,
there is no live "researched"/"planned"/"completed" TTS path at all today, which is exactly why
wiring the fix into the Stop hook (the one mechanism every session reaches, core task types
included) is the structurally correct fix rather than a narrower fix inside the already-orphaned
lifecycle-notify chain.

**An open static-analysis question, flagged but not resolved (outside this task's "confirm file
state" mandate and the dispatch's "do not re-diagnose" instruction).** Because
`update-task-status.sh` preflight writes (and never clears) the `workflow-active-<uuid>` marker
once per phase per cycle, and nothing found in `orchestrate-cycle-postflight.sh`,
`orchestrate-conclusion-aggregate.sh`, or any other orchestrate-engine script clears it either
[COVERAGE-UNVERIFIED: `grep -n "workflow-active" scripts/orchestrate-cycle-postflight.sh
scripts/orchestrate-conclusion-*.sh` / only this literal-string grep was run], static reading
alone could not establish that the marker is actually absent by the moment the root orchestrate
session's own (non-subagent) Stop event fires at a run's true end. If it is not absent, Defect
1's own premise (that the no-marker branch, not the marker-suppression branch, is what executes
at that moment) would not hold in practice, independent of this task's fix. This is surfaced as
a planning/verification risk, not a contradiction of the established diagnosis — acceptance
criteria 1 and 3 are explicitly demonstrated-not-just-reasoned-about requirements, so the actual
answer will come from running `/orchestrate` to completion and listening, which this report
cannot substitute for.

**Defect 2 confirmed verbatim** in both files:
- `merge-sources/settings-hooks.json` line 64: `"matcher": "permission_prompt|elicitation_dialog"`
- `root-files/settings.json` line 187: `"matcher": "permission_prompt|elicitation_dialog"`

No third declaration of this matcher exists anywhere else under `agent-system/**`
[COVERAGE-UNVERIFIED: `grep -rln "permission_prompt|elicitation_dialog" --include=*.json .` from
repo root / a second, differently-shaped pattern such as a JSON-path-aware jq sweep for any
`Notification` block's `.matcher` field was not run]. The same literal string also appears, as
expected and out of scope, in: `.claude-extensions.json` (the deploy *manifest*, which is
regenerated by `deploy-headless.sh` from `merge-sources/settings-hooks.json` and therefore needs
no separate hand-edit — redeploying after this task's fix will update it automatically);
`.opencode/settings.json` (a different system's own settings file, entirely outside this task's
declared `agent-system/**` edit boundary); and three fixture files under
`specs/archive/369_orphan_sweep_for_removed_merge_target_entries/records/fixtures/` (test
fixtures for a *different*, already-filed defect record — task 369, explicitly named in the
dispatch's own "NON-GOALS, OWNED ELSEWHERE" section — not live settings surfaces).

**Defect 3 confirmed: `tts-notify.sh` has no cooldown, dedup, lock, or stamp mechanism of any
kind.** The file's only state is the append-only `LOG_FILE="specs/tmp/claude-tts-notify.log"`,
written via `echo "[...] $1" >> "$LOG_FILE" 2>/dev/null || true` with no preceding `mkdir -p` —
i.e. it already fails open silently today when `specs/tmp/` does not exist (the log line is
simply dropped, never blocking the `speak()` call). `speak()` itself (lines 77-89) backgrounds a
`timeout 10s bash -c '... | piper ... | paplay ...' &` with no coordination across invocations.
The measured evidence cited in the dispatch (Logos/Theory's 1329 bare "Tab N" lines vs 21
lifecycle lines; of the last 199 inter-announcement intervals, 65 in the 10-70s band and 11 under
2s) is a figure this report did not itself measure — it is carried from the dispatch/task
description `[CARRIED-UNVERIFIED: specs/526_tts_announce_completion_and_input_needed/.dispatch/2.md]`.

**No existing cooldown/dedup *pattern* in this codebase is pane-keyed, but one Stop-hook sibling
offers a directly transferable shape.** `hooks/memory-nudge.sh` (also a `Stop`-registered hook,
line 46 of `settings-hooks.json`) implements a session-global (not pane-keyed) cooldown: a
`COOLDOWN_FILE="specs/tmp/memory-nudge-last"` holding a Unix timestamp, checked via
`ELAPSED=$((NOW - LAST_TIME)); if (( ELAPSED < NUDGE_COOLDOWN )); then exit_success; fi`, written
only on an actual fire, with a `mkdir -p "$(dirname "$COOLDOWN_FILE")"` immediately before the
write (unlike `tts-notify.sh`'s log write, which has no `mkdir -p` at all and relies purely on
`2>/dev/null || true`). `WEZTERM_PANE` (a numeric pane id) is already read in three other hook
files (`wezterm-task-number.sh`, `wezterm-clear-task-number.sh`, `wezterm-preflight-status.sh`'s
sibling `wezterm-utils.sh`) purely for TTY/tab-identity lookup; none of them use it as a
cooldown/dedup key today — the dispatch's "keyed by WEZTERM_PANE" requirement has no precedent
to reuse verbatim, only the `memory-nudge.sh` timestamp-comparison shape to adapt.

**No existing check asserts Notification-matcher parity between the two settings surfaces
(acceptance criterion 4).** `scripts/verify-deploy.sh` gate 2 (lines 858-888) inspects only the
*deployed* `.claude/settings.json`'s hook *registrations* (presence of specific event->script
pairs), never the two *source* files against each other, and never inspects `Notification` at
all. `scripts/lint/lint-hook-registration-paths.sh` checks four unrelated defect classes (path
shape, anchor validity, reachability-through-root-files-only, script existence) — matcher
*content* parity is not one of them. `scripts/tests/test-lint-hook-registration-paths.sh` is the
only test file matching either settings surface by name, and it tests that lint script, not
matcher equality. A new check (lint extension or a standalone `scripts/tests/` file) is needed.

**No existing regression test touches any of the three hook/bridge scripts this task changes.**
`find scripts/tests -iname "*tts*" -o -iname "*stop-notify*" -o -iname "*wezterm*" -o -iname
"*lifecycle-notify*"` returned nothing. The house test convention these would follow (observed
in `test-git-commit-phase.sh`) is: `set -uo pipefail`, `source lib/common.sh`, a loud-skip
`REQUIRED_SCRIPTS` existence check before running anything, `PASSED`/`FAILED` counters with
`pass()`/`fail()`/`info()` helpers, a `mktemp -d` workdir with an `EXIT` trap, and assertions
that read actual file/output content rather than trusting exit code alone — documented in
`context/standards/shell-script-testing.md`.

**`deploy-root-guard.sh`-style constraints do not apply directly to these specific files.**
`claude-stop-notify.sh`, `tts-notify.sh`, `wezterm-notify.sh`, and `lifecycle-notify.sh` do not
source `deploy-root-guard.sh`
[COVERAGE-UNVERIFIED: `grep -ln "deploy-root-guard" hooks/*.sh scripts/*.sh | grep -i
"tts\|stop-notify\|wezterm\|lifecycle-notify"` / only this literal-string grep was run]. They are,
however, still CWD/SCRIPT_DIR-relative in a way that assumes the deployed tree shape (e.g.
`claude-stop-notify.sh`'s `$SCRIPT_DIR/../tmp` resolves to `.claude/tmp` only when `hooks/` sits
directly under `.claude/`), so live verification of the new Stop-branch call and the cooldown
stamp still requires either a scratch deployed-tree-shaped fixture or testing after an actual
`deploy-headless.sh` run, not a direct source-store invocation.

### External Resources

Not applicable — this is a self-contained shell/JSON/Markdown fix within the existing hook
architecture; no new external library or API is introduced.

## Recommendations

- **New `tts-notify.sh` mode for the Stop-branch utterance, distinct from `--lifecycle STATUS`.**
  The dispatch requires the Stop-branch utterance to be distinguishable by ear from the
  input-needed utterance (e.g. "Tab N done") while leaving the existing `--lifecycle STATUS`
  vocabulary (researching/researched/planning/planned/implementing/completed/blocked) unchanged.
  Reusing `--lifecycle` with a new, non-vocabulary word would violate that "unchanged" constraint
  directly, so a third mode (e.g. a new flag such as `--stop`) that composes `get_tab_prefix`
  with its own fixed suffix is the shape that satisfies both the distinguishability and the
  vocabulary-preservation requirements simultaneously.
- **Cooldown stamp: pane-keyed, timestamp-comparison, fail-open exactly like the existing log
  write.** Model directly on `memory-nudge.sh`'s shape (`COOLDOWN_FILE`, `NOW - LAST_TIME`
  comparison) but key the filename by `${WEZTERM_PANE:-nopane}` (e.g.
  `specs/tmp/claude-tts-cooldown-${WEZTERM_PANE:-nopane}`) rather than a single global file, per
  the dispatch's explicit "concurrent panes never suppress each other" requirement. Use the same
  `specs/tmp/` location and the same bare `2>/dev/null || true` fail-open discipline
  `tts-notify.sh`'s own log write already uses — this is the dispatch's explicitly sanctioned
  second option ("or fail open silently exactly as the current log write does"), and it keeps
  the new mechanism consistent with the one piece of state this file already has, rather than
  introducing a second, differently-rooted state convention.
- **Cooldown scope: pane-level last-fired timestamp, not per-message dedup.** The dispatch's own
  framing — "an idle re-fire, a Stop and a Notification coinciding, or any future double
  registration all degrade to a single utterance" — describes suppression keyed to *time since
  last fire for this pane*, independent of which message would have been spoken, not a
  content-equality check. Check/update the stamp once, late in the script (after the
  `TTS_ENABLED`/`piper`-availability guards, immediately before whichever `speak()` call is about
  to run), so a disabled or piper-unavailable invocation never perturbs the stamp.
- **Window size: inform from, but do not treat as settled by, the measured cadence
  (10-70s band).** A window on the order of 60-90 seconds would cover the full observed idle
  re-fire cadence while still being well above the 2-second overlapping-block case; the exact
  value is an implementation/plan decision, not settled by this report
  [CORPUS-UNVERIFIED: the Logos/Theory `specs/tmp/claude-tts-notify.log` corpus the dispatch
  cites / a specific window value was not re-run against that log by this research pass].
- **New parity check for acceptance criterion 4.** Add a small, independent check (either a new
  `scripts/tests/test-notification-matcher-parity.sh` following the house test convention above,
  or a new gate inside `verify-deploy.sh` alongside its existing gate 2) that extracts
  `.hooks.Notification[].matcher` from both `merge-sources/settings-hooks.json` and
  `root-files/settings.json` via `jq` and asserts byte-equality. This is new coverage, not an
  extension of an existing assertion — none of the files checked today compare these two source
  files against each other.
- **New regression tests for criteria 2, 3, 6** are needed from scratch, following
  `context/standards/shell-script-testing.md`'s house convention (loud-skip required-script
  check, `mktemp -d` + `EXIT` trap, content-based assertions): (a) a synthetic cooldown test
  invoking the Stop-branch mode twice within and once outside the window; (b) a regression test
  that asserts `claude-stop-notify.sh` still exits via the marker-suppression branch when a
  `workflow-active-*` marker is present, and still exits via the `agent_id` guard when stdin JSON
  carries one, in both cases without reaching the new TTS call; (c) a test asserting
  `TTS_ENABLED=0` short-circuits the new Stop-branch call path identically to the existing two
  modes (this requires no new gating logic beyond what `tts-notify.sh` lines 91-94 already do,
  since that check runs before any mode-specific branch — but it is currently *untested*, so a
  regression test is still new work, not a reuse of coverage that already exists).
- **Fold the `orchestrate-active` dead-marker finding into the same `lifecycle-notify.sh` header
  reconciliation the dispatch already requires**, rather than opening separate work: reword the
  header's bullet list to describe the check as it currently behaves (the file-existence check
  exists in code; nothing in the source store writes that file today, so this auto-suppression
  path does not currently engage) without implying a producer exists. This keeps the
  reconciliation pass honest about both gaps in one file in one pass, matching the dispatch's own
  instruction to "drop any claim that is still untrue."
- **Dependency edge to task 435 is not yet recorded in state.json.** `specs/state.json`'s entry
  for project 526 currently has `depends_on: null`, despite the dispatch's explicit statement
  that this task depends on the open record for task 435 as a territory edge. Per
  `context/patterns/batch-orchestration-guardrails.md`, adding this edge is normally done via
  `update-task-status.sh --depends-on-add`, an orchestration-level action outside this research
  dispatch's own Stage 6/7 contract — flagged here for the planning/orchestration layer to act
  on, not actioned by this report.

## Decisions

- Treated the three defects, their stated fixes, and the explicit non-goals (task 369's orphan
  sweep; the hook-registration-set lint) as settled per the dispatch's "DIAGNOSIS IS COMPLETE: DO
  NOT RE-DERIVE IT" instruction. This report's own findings supplement that diagnosis (the
  orphaned-marker and orphaned-postflight-path discoveries) without contradicting or re-opening
  it.
- Did not attempt to verify empirically whether the `workflow-active-<uuid>` marker is actually
  absent at the true end of a live `/orchestrate` run (the open static-analysis question above),
  since acceptance criteria 1 and 3 already require this to be demonstrated against a real run
  rather than reasoned about statically, and this research dispatch's tools and scope do not
  include launching a full `/orchestrate` session end-to-end.
- Did not propose a specific numeric cooldown window value as settled; left it as a
  planning-time decision informed by, but not fixed by, the measured cadence band the dispatch
  cites.

## Risks & Mitigations

- **Risk**: the per-pane cooldown stamp, scoped by time-since-last-fire rather than by message
  content, could suppress a second, *genuinely distinct* announcement that happens to land inside
  the window (e.g. a Stop-branch "done" immediately followed by a new Notification "Tab N" for a
  different, unrelated prompt in the same pane). **Mitigation**: keep the window close to the
  dispatch's own measured idle cadence (10-70s) rather than much larger, and note in the plan that
  this is an accepted, explicitly-intended tradeoff per the dispatch's own framing ("all degrade
  to a single utterance"), not an oversight to design around.
- **Risk**: a stamp file written to `specs/tmp/` will silently never engage in any repo lacking a
  `specs/` directory (per the acceptance criterion's own "or fail open silently" escape hatch),
  meaning the cooldown is only actually load-bearing in repos that have `specs/` — i.e. most of
  this loader's deploy targets, but not guaranteed universally. **Mitigation**: this is the
  dispatch's own sanctioned degrade-gracefully behavior, not a defect to fix; no further action
  needed, but worth stating explicitly in the plan so it isn't later mistaken for a bug.
- **Risk**: adding a new `tts-notify.sh` flag/mode increases the script's public surface at the
  same time the cooldown gating is being added; a bug in flag-parsing order could let the
  cooldown check run before the `TTS_ENABLED`/piper guards for the *new* mode even though it
  correctly runs after them for the existing two. **Mitigation**: explicitly sequence the new
  mode's branch after the existing early-exit guards (mirroring the existing `--lifecycle` and
  interactive branches' own position in the file), and cover this ordering with the
  `TTS_ENABLED=0` regression test recommended above.
- **Risk**: redeploying (`deploy-headless.sh`) after editing `root-files/settings.json` has no
  effect on an *already-deployed* repo, since that file is install-once (per its own
  `_comment` field: "copied only when no project copy exists yet, never overwritten on resync").
  A repo that was deployed before this fix landed will keep the old matcher in its deployed
  `root-files`-derived `settings.json` content indefinitely unless manually reconciled —
  explicitly the territory the dispatch assigns to task 369's orphan sweep, not this task.
  **Mitigation**: none needed from this task; confirmed in scope boundary already, restated here
  only so the plan does not mistake "redeploy this repo" as sufficient to prove the fix landed
  correctly everywhere.

## Context Extension Recommendations

- **Topic**: the `orchestrate-active` vs. `workflow-active-<uuid>` marker distinction.
- **Gap**: no existing context file documents that these are two separate mechanisms (one dead,
  one live) with similar names; a future reader of `lifecycle-notify.sh`'s header alone would
  reasonably conflate them, exactly as this research pass initially risked doing.
- **Recommendation**: once this task's documentation-reconciliation pass lands, consider whether
  a short note belongs in `context/patterns/` (or wherever TTS/lifecycle hook architecture is
  otherwise documented) distinguishing the two marker families by name and by which script reads
  vs. writes each — out of scope for this task to create, but worth a future pointer so the
  distinction survives past this one file's header.

## Appendix

Search queries / commands used (representative, not exhaustive):
- `cat -n` on all six `file_scope` files in full.
- `grep -rln "orchestrate-active" agent-system/` (and per-subdirectory variants against
  `scripts/`, `hooks/`, `commands/`, `skills/`, `agents/`) — zero writers found.
- `grep -n "skill_lifecycle_notify" scripts/*.sh` and `grep -rln "skill_lifecycle_notify" .` —
  zero call sites under `scripts/*.sh`; only extension `SKILL.md`/lint/test/pattern-doc files.
- `grep -rln "wezterm-notify.sh\|tts-notify.sh" scripts/` — only `lifecycle-notify.sh` (plus
  library/test references) calls either script.
- `grep -n "workflow-active" scripts/update-task-status.sh scripts/skill-base.sh hooks/*.sh` —
  located the live marker's single writer (`update-task-status.sh` line 1197) and single clearer
  (`wezterm-preflight-status.sh` Tier 2 / ESC-cancel).
- `grep -rln "permission_prompt|elicitation_dialog" --include=*.json .` — located both live
  settings surfaces plus the deploy manifest, the OpenCode settings file (out of scope), and
  task-369 fixture files (out of scope, different defect record).
- `find scripts/tests -iname "*tts*" -o -iname "*stop-notify*" -o -iname "*wezterm*" -o -iname
  "*lifecycle-notify*"` — zero existing tests.
- `python3 -c "..."` against `specs/state.json` to read project 526's own `file_scope`,
  `depends_on`, and `artifacts` fields directly.

References:
- `specs/526_tts_announce_completion_and_input_needed/.dispatch/2.md` (dispatch contract; source
  of the carried measured-evidence figures).
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (house test
  convention referenced in Recommendations).
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (dependency
  edge mechanics referenced in Recommendations).
