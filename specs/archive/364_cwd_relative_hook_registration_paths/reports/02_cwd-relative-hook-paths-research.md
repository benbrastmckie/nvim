# Research Report: CWD-relative hook registration paths — mechanism, migration, and scope ruling

- **Task**: 364 - Resolve hook registration paths independently of session CWD so bare-registered
  blocking guards cannot fail open
- **Started**: 2026-10-07T19:50:00Z
- **Completed**: 2026-10-07T20:11:00Z
- **Effort**: ~1.5 hours (empirical experimentation + codebase tracing)
- **Dependencies**: None
- **Sources/Inputs**:
  - Direct empirical experiment against this repo's own deployed `.claude/settings.json` (see
    Findings F1-F3) — temporary hook registrations added, triggered, observed, then reverted and
    diff-verified byte-identical to the pristine original
  - `agent-system/extensions/core/root-files/settings.json`,
    `agent-system/extensions/core/merge-sources/settings-hooks.json`,
    `agent-system/extensions/books/settings-hooks.json`,
    `agent-system/extensions/email/settings-fragment.json`,
    `agent-system/extensions/core/root-files/settings.local.json`
  - `agent-system/extensions/core/manifest.json` (merge_targets.settings `_comment`)
  - `agent-system/extensions/core/scripts/verify-deploy.sh` (gate 2: hook-registration
    verification, existing duplicate-detection)
  - `lua/neotex/plugins/ai/shared/extensions/{loader,merge,init,verify}.lua`
  - `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` (scratch-repo
    real-deploy test harness precedent)
  - `agent-system/extensions/core/scripts/migrate-directory-padding.sh` (house migration-script
    convention)
  - `specs/state.json` (tasks 282, 303, 318, 347, 365)
  - Pre-research evidence capture: `specs/364_cwd_relative_hook_registration_paths/reports/01_cwd-relative-hook-paths.md`
  - `claude-code-guide` subagent consultation (documentation corroboration of the empirical
    finding)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Gating question answered empirically, with reproducible experiment, not by documentation
  alone**: `$CLAUDE_PROJECT_DIR` IS exported into every hook command's environment, and it
  resolves to the true project/repo root (`/home/benjamin/.config/nvim` in this repo)
  independently of the session's drifted Bash-tool CWD. Confirmed for PreToolUse:Bash hooks AND
  PostToolUse:Write hooks (two different event types), including inside a nested `bash -c '...'`
  wrapper (the second syntactic shape F4 of the pre-research report flagged).
- **The fix is adopt `$CLAUDE_PROJECT_DIR`**, exactly as the pre-research report's
  recommendation 2 anticipated: `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh`. Verified
  end-to-end against a REAL blocking guard (`guard-destructive-git.sh`): with the fixed command
  string, `git add -A` was correctly intercepted and blocked (`exit 2`, nothing staged) — not
  merely "didn't error," but demonstrated still blocking.
- **Neither fallback (deploy-time absolute-path substitution, or a self-locating dispatcher) is
  needed.** Both are now moot; this report rules them out explicitly so a future reader does not
  re-open the question.
- **The install-once propagation gap is real and the dispatch's second-order hazard is
  independently corroborated by pre-existing code comments**: `core/manifest.json`'s own
  `merge_targets.settings._comment` already documents, in almost identical words, that
  "`deep_merge` does not self-heal drifted command paths ... it will be appended alongside the
  corrected one rather than replacing it." `verify-deploy.sh` gate 2 already contains a
  (warn-only) duplicate-registration detector for exactly this failure class. This is a known,
  named, pre-existing limitation of the merge mechanism — not a new discovery — which settles
  research question 2/3 decisively in favor of an explicit migration script over any reliance on
  `deep_merge`.
- **`root-files/settings.json` should keep carrying hook registrations, but with an explicit,
  durable warning against adding *new* ones there** — the house already has this doctrine
  encoded in `verify-deploy.sh`'s gate-2 remediation text and in `core/manifest.json`'s own
  comment; it has just never been written where a future editor of `root-files/settings.json`
  itself would see it.
- **The `settings.local.json` permission matchers (F6) do NOT share the defect** and must not be
  touched: permission matching is pure string/pattern matching against the Bash tool's proposed
  command text, not a path resolved and executed by a shell. Rewriting them to reference
  `$CLAUDE_PROJECT_DIR` would be actively harmful: that variable is confirmed absent from the
  Bash tool's own command environment (re-confirmed empirically here), so a matcher rewritten
  that way would never match what the agent actually runs.

## Context & Scope

In scope: settling the gating `CLAUDE_PROJECT_DIR` mechanism question by direct experiment;
confirming the fix shape handles both syntactic registration forms; ruling on the migration path
for already-deployed repos; ruling on whether `root-files/settings.json` should carry hook
registrations at all; resolving the F6 permission-matcher scope question one way or the other
(not left open).

Out of scope (per dispatch and pre-research report): script-internal path resolution (already
correct, uses `BASH_SOURCE`); task 303 (unrelated script-internal bug); writing the actual fix,
migration script, or lint (plan/implement phases); `test-please-grant.sh`'s subshell-wrapped
invocation (already correct, must not be touched).

## Findings

### F1. Empirical confirmation: `$CLAUDE_PROJECT_DIR` is exported to hook commands

Method: a throwaway hook (`dump-hook-env.sh`, written to the session scratchpad, never under
`.claude/` or any tracked path) was temporarily registered in this repo's own deployed
`.claude/settings.json` on a `PreToolUse:Bash` matcher, triggered via an ordinary Bash tool call,
and its env dump inspected. `.claude/` is entirely gitignored in this repo (confirmed via
`.gitignore`), so this was a safe, reversible, zero-git-footprint experiment. After each
experiment the original `settings.json` was restored and `diff`-verified byte-identical to a
pristine backup taken before any edit — confirmed three times across three separate rounds of
experimentation.

Result:
```
PWD=/home/benjamin/.config/nvim
CLAUDE_PROJECT_DIR=/home/benjamin/.config/nvim
```
`$CLAUDE_PROJECT_DIR` is present and correct. Separately, `env | grep -i claude_project` run
directly as an ordinary Bash tool call (no hook involved) returns nothing — confirming the
pre-research report's F-finding that the Bash tool's *own* command environment lacks the
variable. **The variable is specific to the hook-launching mechanism, not the Bash tool's shell
— a session cannot "just check" by echoing it in an ordinary command.** This is why the pre-
research report correctly flagged this as requiring a dedicated experiment rather than
inspection of ordinary tool output.

### F2. Confirmed working end-to-end against a real blocking guard, including the block itself

The `Bash` matcher's `guard-destructive-git.sh` registration was temporarily rewritten (in this
repo's own `.claude/settings.json`, same reversible method as F1) to:
```
bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/guard-destructive-git.sh
```
Two live triggers:
1. `git status --porcelain` — ran cleanly, no `PreToolUse:Bash hook error`, no "No such file"
   warning (the exact symptom the defect produces when the path fails to resolve).
2. `git add -A` — produced:
   ```
   PreToolUse:Bash hook error: [bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/guard-destructive-git.sh]:
   BLOCKED: git add -A (or --all) stages the entire working tree; ...
   ```
   `git status --porcelain` immediately after confirmed **nothing was staged** — the guard's
   `exit 2` genuinely blocked the tool call, not merely logged a warning. This directly
   satisfies acceptance criterion 2 ("the six bare-registered blocking guards still block ...
   demonstrated, not asserted") for one of the six guards, using the exact fixed command shape.

Quoting survives JSON escaping with no special handling beyond what the existing codebase
already does elsewhere for `$CLAUDE_TOOL_INPUT` (see F3) — `\"$CLAUDE_PROJECT_DIR\"` inside the
JSON string literal is the entire requirement.

### F3. The nested `bash -c '...'` shape (F4 of the pre-research report) also works unmodified

`root-files/settings.json` line 80's nested form passes `$CLAUDE_PROJECT_DIR` through an
additional layer: `bash -c '<script using $CLAUDE_TOOL_INPUT>'`. Because environment variables
are inherited by child processes (the inner `bash -c` subshell inherits from the hook-launching
process, exactly as it already relies on inheriting `$CLAUDE_TOOL_INPUT`), no additional escaping
beyond the existing `\"...\"` pattern already used for `$CLAUDE_TOOL_INPUT` on that same line is
needed for `$CLAUDE_PROJECT_DIR`. Verified directly: a nested `bash -c` hook was registered on
`PostToolUse:Write`, triggered via the Write tool (not Bash — confirming hook firing is tool-type
independent as expected), and the invoked inner script's env dump showed
`project_dir=/home/benjamin/.config/nvim` correctly resolved inside the double-nested context.
**This also establishes, as a side finding, that `$CLAUDE_PROJECT_DIR` is available to
`PostToolUse:Write` hooks, not just `PreToolUse:Bash`** — i.e. it is not scoped to one event
type.

The fixed form for line 80 is therefore:
```
bash -c 'FILE=$(echo "$CLAUDE_TOOL_INPUT" | jq -r ".file_path // empty" 2>/dev/null); if [[ "$FILE" == *"specs/state.json"* ]]; then bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/validate-state-sync.sh 2>/dev/null || echo "{}"; else echo "{}"; fi'
```
— i.e. only the inner `bash .claude/hooks/validate-state-sync.sh` fragment changes; the
pre-existing `$CLAUDE_TOOL_INPUT`/`$FILE` conditional logic is untouched and does not need to be
understood or modified to apply this fix correctly.

### F4. Both fallback mechanisms (pre-research report recommendation 3) are now moot

Because F1-F3 settle the gating question affirmatively and demonstrate the fix working
end-to-end, neither fallback is needed:
- (a) deploy-time absolute-path substitution by the `<leader>al` loader (confirmed to exist —
  `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` backs this keymap) — not needed, and
  would have baked a machine-specific path into a generated artifact for no benefit now that (b)
  a harness-native mechanism exists.
- (b) a `git rev-parse --show-toplevel`-based self-locating dispatcher — not needed, and would
  have added a process-per-invocation cost and a new non-git-repo failure mode that
  `$CLAUDE_PROJECT_DIR` does not have.

This report rules both out explicitly so neither is reconsidered without new evidence that
`$CLAUDE_PROJECT_DIR` has stopped working.

### F5. The install-once propagation gap is independently corroborated by pre-existing code comments

`core/manifest.json`'s `merge_targets.settings._comment` (written before this task existed)
already states: *"`deep_merge` also does not self-heal drifted command paths: renaming a hook
script here requires manually removing the stale registration from already-synced repos'
`settings.json`, or it will be appended alongside the corrected one rather than replacing it
(follow-up risk, not fixed by this mechanism)."* Changing a hook's **command string** (our fix)
is mechanically identical to "renaming a hook script" from `deep_merge`'s point of view — both
change the exact string `deep_merge`'s `vim.deep_equal`-based dedup matches on
(`lua/neotex/plugins/ai/shared/extensions/merge.lua`'s `normalize`/dedup logic, confirmed by
reading lines ~175-270). The dispatch's "second-order hazard" is therefore not a hypothetical;
it is a named, pre-existing, acknowledged limitation that this task's own fix will trigger unless
an explicit migration script is used instead of relying on a resync.

`verify-deploy.sh` gate 2 already implements a **duplicate-registration detector** (warn-only, by
design — "the merge is add-only and cannot remove a pre-existing entry, so a duplicate is a
manual-cleanup item rather than something a regeneration could ever fix"). This is directly
reusable: the plan should either extend this existing gate's assertion to cover the specific
six-guard command strings as a hard failure post-migration, or add a dedicated test, rather than
inventing new duplicate-detection machinery.

### F6. `root-files/settings.json` vs. `merge-sources/settings-hooks.json` — exact overlap mapped

Traced the deploy order in `lua/neotex/plugins/ai/shared/extensions/init.lua`: `copy_category`
for `root_files` runs (line 537) **before** `process_merge_targets` (line 591) on every load,
including the very first one. `core` is always loaded first in dependency order
(`merge.lua` line 786, "core always first"), and `core/manifest.json` declares
`merge_targets.settings` pointing at `settings-hooks.json` unconditionally. So on a **fresh
install**, `root-files/settings.json` is copied first, then `merge-sources/settings-hooks.json`
is merged on top — and because the four overlapping hooks (`guard-destructive-git.sh`,
`validate-no-task-references.sh`, `guard-git-push.sh`, `please-grant.sh`) currently have
byte-identical command strings in both files, that merge is a no-op by design (exact-string
dedup match).

Consequence for the fix: **these four hooks' command strings must be changed identically,
byte-for-byte, in both files**, or the very next load/resync (including the first one, for a
brand-new repo) will append a second, differently-worded entry under the same matcher — the
duplicate-registration failure mode, self-inflicted, on day one.

Mapped exactly which hooks live where:

| Hook | root-files/settings.json | merge-sources/settings-hooks.json |
|---|---|---|
| guard-destructive-git.sh | yes (identical string) | yes (identical string) |
| validate-no-task-references.sh | yes (identical string) | yes (identical string) |
| guard-git-push.sh | yes (identical string) | yes (identical string) |
| please-grant.sh | yes (identical string) | yes (identical string) |
| validate-state-sync.sh (nested) | **yes, ONLY here** | absent |
| validate-handoff-location.sh | absent | **yes, ONLY here** |
| validate-evidence-append-only.sh | n/a (books extension) | yes, in `books/settings-hooks.json` |
| mail-guard.sh | n/a (email extension) | yes, in `email/settings-fragment.json` |

`validate-state-sync.sh`'s nested registration is the one case with **no merge-source
counterpart at all** — today, and after a naive fix that only touches `root-files/settings.json`,
it would remain permanently unreachable by resync for every already-deployed repo, forever,
even after a correct migration-script run fixes the *existing* copy (a *future* change to this
hook would hit the exact same unreachability problem all over again).

### F7. `settings.local.json` permission matchers do NOT share the defect (F6 of pre-research report, now resolved)

Permission matchers (`"Bash(bash .claude/scripts/check-extension-docs.sh)"` etc.) are evaluated
by string/glob pattern matching against the **literal command text** the agent is about to run —
they are a pre-execution ACL check, not a path that is itself resolved and executed by a shell at
match-time. Changing the session's CWD does not change whether the matcher's own text-matching
function operates correctly; it always will, regardless of CWD, because it never touches the
filesystem.

Confirmed empirically (re-run in this session, matching the pre-research report's F6 finding):
`env | grep -i claude_project` as an ordinary Bash tool command returns nothing —
`$CLAUDE_PROJECT_DIR` is absent from the Bash tool's own command execution environment (it is
only injected into the hook-launching mechanism's environment, per F1-F3). This means rewriting
a permission matcher to `"Bash(bash \"$CLAUDE_PROJECT_DIR\"/.claude/scripts/...)"` would be
actively counterproductive: Claude (the agent) would have to literally type that exact string as
its Bash command for the pattern to match, and if the Bash tool then actually executed it, the
variable would expand to empty (unset), producing a broken path (`/.claude/scripts/...` from
filesystem root) — worse than today's behavior, not better.

**Ruling: the `settings.local.json` permission matchers are out of scope. They do not share the
defect and must not be modified by this task.** (This resolves the dispatch's explicitly-left-open
SCOPE DECISION — the answer is "no, do not include them," with the reasoning above, not an
assumption either way.)

### F8. House precedent exists for both halves of the required fix

- Migration-script convention: `agent-system/extensions/core/scripts/migrate-directory-padding.sh`
  establishes the pattern (`--dry-run` flag, `--project-root` override, colorized pass/fail
  output) a new `migrate-hook-registration-paths.sh`-style script should follow.
- Real-deploy verification convention:
  `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh` already runs the real
  `deploy-headless.sh` against a scratch git repo and asserts on the deployed tree's actual
  content — exactly the mechanism acceptance criterion 4 requires ("deploying into a consumer
  repo and grepping the resulting `.claude/settings.json`"). The plan should extend this harness
  (or add a sibling assertion to it) rather than inventing a new deploy-verification mechanism.

### F9. Documentation templates and the one correctly-exempt troubleshooting line

Grepped all four named markdown files; all four contain exactly the CWD-relative JSON
registration-template snippets the dispatch named, confirmed by line number:
`neovim-integration.md` (30, 87, 98), `tts-stt-integration.md` (125),
`wezterm-integration.md` (173, 181, 185), `workflow-interruptions.md` (68). All eight are genuine
copy-paste JSON `"command"` registration examples and should be updated to the fixed shape.

One additional line in `workflow-interruptions.md` (240) was inspected and found to be a
**different kind of snippet that must NOT be changed**: `bash .claude/hooks/subagent-postflight.sh`
appears there as a manual diagnostic command ("Check hook output") a human or agent runs
interactively from the repo root while debugging — not a JSON registration. Rewriting it to use
`$CLAUDE_PROJECT_DIR` would make it **worse**: that variable is confirmed (F1, F7) to be absent
from an ordinary interactive/Bash-tool shell, so a human pasting the "fixed" line would get an
empty-variable path, not a working one. This is analogous to the already-noted
`test-please-grant.sh` exemption — a correct-by-different-construction case the plan must
preserve, not "fix" by a mechanical find-and-replace.

## Decisions

- **D1 (gating question — settled empirically)**: `$CLAUDE_PROJECT_DIR` is exported to hook
  commands across at least two event types (PreToolUse:Bash, PostToolUse:Write), resolves to the
  true project root independent of session CWD drift, and works through both the bare and the
  nested `bash -c` syntactic shapes with no extra escaping beyond standard JSON string escaping.
  Adopt `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh` (and the nested-form equivalent) as the
  fix. No fallback is needed.
- **D2**: The four hooks present in both `root-files/settings.json` and
  `merge-sources/settings-hooks.json` (guard-destructive-git.sh, validate-no-task-references.sh,
  guard-git-push.sh, please-grant.sh) MUST have their command strings changed identically,
  byte-for-byte, in both files, to preserve `deep_merge`'s exact-string dedup and avoid a
  self-inflicted duplicate on the very next load (including a brand-new repo's first install).
- **D3**: Already-deployed repos (settings.json pre-dating the fix) cannot be reached by
  `deep_merge`/resync for ANY of the affected command strings, by design (install-once for
  root-files-sourced entries; add-only-no-self-heal for merge-source-sourced entries, per F5's
  `core/manifest.json` comment). The fix therefore REQUIRES a dedicated migration script that
  rewrites matching command strings in-place in an existing `.claude/settings.json`, following
  the `migrate-directory-padding.sh` convention (`--dry-run`, idempotent on re-run, colorized
  pass/fail). This is not optional and not satisfiable by any combination of source-store edits
  alone.
- **D4**: `root-files/settings.json` SHOULD continue to carry hook registrations (do not strip
  them) — for defensive redundancy on a repo's very first write, before any extension merge has
  run — but the plan must add an explicit, visible comment in `root-files/settings.json` itself
  (not only in `verify-deploy.sh`'s remediation text or `manifest.json`'s comment, where a future
  editor of `root-files/settings.json` would not see it) stating that NEW hook registrations must
  be added to `merge-sources/settings-hooks.json`, never here, because root-files is install-once
  and permanently unreachable by resync. This reaffirms existing house doctrine rather than
  inventing new policy.
- **D5**: `validate-state-sync.sh`'s nested hook has no merge-source counterpart today and is
  therefore permanently unreachable-by-resync for any FUTURE change, independent of this fix. The
  plan should add a correctly-pathed, equivalent registration to
  `merge-sources/settings-hooks.json`'s `PostToolUse` block as part of this same change, closing
  that standing gap rather than leaving one more hook in the install-once trap D4 just finished
  warning against.
- **D6**: The `settings.local.json` permission matchers (F6/F7) do not share the defect and MUST
  NOT be modified by this task. Ruled, with reason, not assumed.
- **D7**: `workflow-interruptions.md` line 240 (manual diagnostic invocation) must NOT be rewritten
  to the `$CLAUDE_PROJECT_DIR` form; only the genuine JSON registration-template snippets (F9) are
  in scope for the documentation fix.
- **D8**: The duplicate-registration assertion (acceptance criterion 6) should extend/reuse
  `verify-deploy.sh` gate 2's existing (warn-only) duplicate detector rather than build new
  machinery — upgraded to a hard-fail assertion for the six specific blocking-guard command
  strings, run post-migration against a real migrated settings.json.
- **D9**: The fresh-deploy verification (acceptance criterion 4) should extend
  `test-deploy-propagation.sh`'s existing real-scratch-repo-deploy harness rather than invent a
  new deploy-verification mechanism.

## Recommendations

1. Plan phase: write the command-string fix across all affected surfaces (`root-files/settings.json`
   including the nested line-80 form, `merge-sources/settings-hooks.json`,
   `books/settings-hooks.json`, `email/settings-fragment.json`), applying D2's byte-identical
   constraint wherever a hook exists in two files.
2. Plan phase: add the new merge-source registration for `validate-state-sync.sh` per D5, using
   the exact nested-form shape verified in F3.
3. Plan phase: declare a new migration script path (e.g.
   `agent-system/extensions/core/scripts/migrate-hook-registration-paths.sh`) in `file_scope` via
   the plan-file-scope-harvest mechanism, following the `migrate-directory-padding.sh` convention
   (`--dry-run`, `--project-root`, idempotent, colorized pass/fail).
4. Plan phase: add the root-files/settings.json warning comment per D4.
5. Plan phase: update the four markdown templates (F9) but explicitly exclude
   `workflow-interruptions.md` line 240 (D7).
6. Verification phase: demonstrate acceptance criteria 1-2 the same way F1-F2 did here (temporary
   registration, trigger, observe, revert) — but against a FRESH deploy's output, not a hand-edited
   live file, and demonstrate criterion 5-6 against a migrated PRE-EXISTING deployed settings.json
   (e.g. a scratch copy seeded with the OLD broken strings, then migrated).
7. Extend `test-deploy-propagation.sh` (D9) and `verify-deploy.sh` gate 2 (D8) rather than adding
   parallel verification mechanisms.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| A string edit to one of root-files/merge-sources diverges from its counterpart (typo, trailing flag difference) | D2's byte-identical constraint; a plan/implement-phase diff check between the two files for the four shared hooks before committing |
| Migration script is written but never run against the actually-affected consumer repo (`/home/benjamin/Philosophy/Papers/PossibleWorlds`) named in the dispatch's live reproduction | Acceptance criterion 5 explicitly demands demonstration "against a real pre-existing deploy," not only a scratch fixture — the plan must include running it there (or an equivalent real pre-existing deployed repo) and re-confirming the original failure is gone |
| A future hook addition lands in root-files/settings.json out of habit, reintroducing the install-once-unreachable trap D4 is meant to prevent | D4's in-file comment, plus `verify-deploy.sh` gate 2's existing remediation text already pointing the other way |
| Markdown template fix accidentally touches the one correctly-exempt diagnostic line | D7, with the exact line number and reasoning recorded here so an implementer does not need to re-derive it |

## Context Extension Recommendations

- **Topic**: `$CLAUDE_PROJECT_DIR` hook-environment behavior.
- **Gap**: nothing in `.claude/context/` currently documents that `$CLAUDE_PROJECT_DIR` is
  available to hook commands (across at least PreToolUse and PostToolUse event types) but absent
  from the Bash tool's own command environment — a distinction this task needed a dedicated
  experiment to establish and that will recur for any future hook-registration work.
- **Recommendation**: after this task's implementation lands, consider a short addition to
  `.claude/context/patterns/` (or wherever hook-registration conventions are documented) recording
  this distinction, so a future hook author does not need to re-run the experiment performed in
  F1-F3 of this report.

## Appendix

### A1. Commands/method used for the empirical experiments (F1-F3, all reversible, all diff-verified restored)

```bash
# F1/F2 setup (abbreviated) — see full session transcript for exact invocations
cp .claude/settings.json /scratch/settings.json.bak
# ... python3 json edit to add/rewrite a hook entry pointing at a scratch dump script ...
# ... trigger via an ordinary Bash tool call or Write tool call ...
cat /scratch/hook-env-dump.txt   # confirms CLAUDE_PROJECT_DIR
cp /scratch/settings.json.bak .claude/settings.json
diff /scratch/settings.json.bak .claude/settings.json && echo "restored OK"
```

### A2. Task graph context (unchanged from pre-research report, re-verified against current state.json)

- 365 `lint_cwd_relative_hook_path_registrations` (not_started, depends on 364) — the companion
  lint/verify-deploy-gate task; its `file_scope` already names
  `core/scripts/lint/lint-hook-registration-paths.sh` + test + `verify-deploy.sh` + `manifest.json`.
  Whatever path shape this task's plan settles on (`$CLAUDE_PROJECT_DIR`, per D1) is what 365's
  lint must enforce.
- 282, 347 (both not_started, both depend on 364) — add new hook registrations to
  `merge-sources/settings-hooks.json`; both must use the `$CLAUDE_PROJECT_DIR` form once this
  task lands, per the dispatch's sequencing note.
- 303 (not_started) — confirmed unrelated, script-internal bug.
