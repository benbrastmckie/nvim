# Research Report: Task #365

- **Task**: 365 - Lint forbidding CWD-relative paths and fragment-absent registrations in hook
  commands, wired as a verify-deploy gate
- **Started**: 2026-10-07T22:09:54Z
- **Completed**: 2026-10-07T22:30:00Z
- **Effort**: ~1 session (research only)
- **Dependencies**: Task 364 (completed) — upstream path-shape fix. Confirmed landed; see
  Findings.
- **Sources/Inputs**: Codebase (agent-system/extensions/, this repo's own deployed `.claude/`),
  task 364's reports/plan/summary artifacts, `specs/state.json`
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- Task 364 (upstream dependency) is **completed**. It settled the path shape as
  `"$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh` (never a bare-relative or deploy-time-substituted
  form), ruled `settings.local.json` permission matchers **out of scope** (D6: they match literal
  command text, not a resolved CWD, so they don't share the defect), moved six registrations from
  install-once `root-files/settings.json` into `merge-sources/settings-hooks.json`, and hardened
  `merge.lua`'s hook dedupe to identity-based comparison. The corpus under
  `agent-system/extensions/` is currently clean of the CWD-relative `.claude/` shape (verified by
  grep across every settings surface and the four named markdown files).
- Task 364's own fix already removed the specific "line 118" `claude-ready-signal.sh` dead
  registration from the source store's `root-files/settings.json`. The dispatch's acceptance
  criteria 11/12 fixture cases are therefore synthetic reconstructions of that shape, not a live
  corpus finding — confirmed by grep (zero remaining instances in `agent-system/`).
- A **live, current instance of the exact defect persists right now** in this very repo's own
  deployed `.claude/settings.json` (line 21): `"command": "bash scripts/claude-ready-signal.sh
  2>/dev/null || echo '{}'"`. This is outside task 365's scope (source store only, never
  `.claude/**`) and is unreachable by resync (the entry is root-files-only and root-files is
  install-once) — see Risks.
- `merge.lua`'s `hook_identity()` function (the upstream task's dedupe) recognizes only
  `.claude/hooks/NAME.sh`-shaped commands. The dispatch's fragment-coverage check explicitly
  requires a **broader** identity (any invoked script path, e.g. `scripts/foo.sh` too). This is a
  real, documented divergence between the lint's identity notion and `merge.lua`'s, worth noting
  for the plan — the dispatch's own later revision deliberately widens the lint past what
  `merge.lua` currently recognizes.
- A naive `grep '\.claude/hooks/'` scan across a whole settings JSON file **false-positives** on
  `root-files/settings.json`'s own `_comment` field, which deliberately quotes the correct hook
  path form in prose. The lint must anchor matching to the `"command"` key's value, not scan
  arbitrary JSON text.
- 11 existing `lint-*.sh` scripts in `agent-system/extensions/core/scripts/lint/` establish a firm
  house convention (fail-closed on missing `lib/common.sh`, `set -euo pipefail`, `--verbose`/
  `--quiet`, exit 0/1/2, `[VIOLATION]`/`[FAIL]` tagged output, project-root self-resolution that
  works from both the source-store and deployed-tree copy). `lint-state-writer-boundary.sh` is
  the closest structural template for this new lint.

## Context & Scope

This is a research-only dispatch for a task whose implementation is explicitly blocked on (and
now unblocked by) task 364. The goal is to confirm: (a) task 364's actual settled path shape and
scope rulings, so the lint encodes the real decision rather than a guess; (b) the current state of
the corpus (is it actually clean, does the dead-registration case still exist anywhere reachable);
(c) the house conventions this task's four fixed artifact paths (lint script, fixture test, gate
wiring, manifest registration) must follow; and (d) any latent tension between the dispatch's
acceptance criteria and what adjacent code (`merge.lua`) already does.

Scope is deliberately bounded by the dispatch's fixed `file_scope`:
`agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh`,
`agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh`,
`agent-system/extensions/core/scripts/verify-deploy.sh`, and
`agent-system/extensions/core/manifest.json`. No other files are to be created or widened.

## Findings

### Codebase Patterns

**Upstream task 364's settled decisions** (from
`specs/364_cwd_relative_hook_registration_paths/reports/02_cwd-relative-hook-paths-research.md`,
`plans/02_cwd-relative-hook-registration-paths.md`, and
`summaries/02_cwd-relative-hook-registration-paths-summary.md`):
- Path shape: `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh` (including the nested `bash -c`
  wrapper form). This resolves the dispatch's stated DEPENDENCY concern — there is only one
  accepted shape to encode, not three candidates.
- D6 / F6-F7: `root-files/settings.local.json` permission matchers do **not** share the CWD
  defect (a permission matcher matches literal command text the tool call presents; it is not
  itself resolved against a CWD) and are explicitly ruled **out of scope**. This directly answers
  the dispatch's "follows the upstream task's finding" instruction for the lint's own scope: do
  **not** lint `settings.local.json`.
- Six registrations (`log-session.sh`, `post-command.sh`, `memory-nudge.sh`,
  `subagent-postflight.sh`, `tts-notify.sh`, `validate-plan-write.sh`) were moved from
  install-once `root-files/settings.json`-only into `merge-sources/settings-hooks.json` (a new
  top-level `Notification` array was added to the fragment for `tts-notify.sh`). Before this move
  these six were exactly the "fragment-absent-while-root-files-present" violation shape this
  task's fragment-coverage check (criteria 8-10) targets. Current count of hook-script names
  present in **both** `root-files/settings.json` and `merge-sources/settings-hooks.json`: 16 (not
  the dispatch's cited "eleven" — the discrepancy is simply that task 364 added more shared
  entries; both counts are consistent with "already an established, large pattern").
  Fragment-only names present today: `detect-noop-bash.sh`, `validate-handoff-location.sh`,
  `validate-meta-write.sh` (all correct per the dispatch's rule 140). No root-files-only hook
  names remain in the corpus (confirmed by `comm -23` against the two files, modulo one false
  positive explained below) — i.e. criterion 10 ("lint passes once task 364's moves land") is
  satisfiable right now.
- `claude-ready-signal.sh` was **removed outright** from `root-files/settings.json` by task 364
  (not rewritten to a `$CLAUDE_PROJECT_DIR` form), because the summary states the script "exists
  nowhere in the source store or either real deployed repo" at verification time. Confirmed:
  `agent-system/extensions/core/root-files/settings.json` has no such line today.

**Current corpus state (verified directly, not inferred)**:
- `grep -rn 'bash \.claude/hooks' agent-system --include=*.json` → zero matches.
- Every `"command"` value across `core/root-files/settings.json`, `core/merge-sources/settings-
  hooks.json`, `books/settings-hooks.json`, `email/settings-fragment.json`, and the other six
  extensions' `settings-fragment.json` files is either `"$CLAUDE_PROJECT_DIR"`-anchored or (one
  case, `core/root-files/settings.json` line 43) an inline `bash -c` block with no invoked script
  path at all. `lean/settings-fragment.json`, `nix/settings-fragment.json`,
  `epidemiology/settings-fragment.json`, `filetypes/settings-fragment.json`,
  `founder/settings-fragment.json`, `present/settings-fragment.json`, `web/settings-fragment.json`
  contain no `"command"` hook entries at all (some, e.g. `memory/settings-fragment.json`, define
  an MCP server's `"command": "npx"`, a different JSON shape entirely and not hook-related — the
  lint's hook-command matching must not confuse MCP server `command` fields with hook `command`
  fields; they sit under different top-level keys, `mcpServers` vs `hooks`).
- The four markdown files named in the dispatch are checked: `neovim-integration.md`,
  `tts-stt-integration.md`, `wezterm-integration.md`, `workflow-interruptions.md` all show
  `"$CLAUDE_PROJECT_DIR"`-anchored commands for every `.claude/hooks/` registration template.
- **One markdown line is deliberately NOT `$CLAUDE_PROJECT_DIR`-anchored and is still correct**:
  `nvim/context/project/neovim/guides/neovim-integration.md` line 34: `"command": "bash
  ~/.config/nvim/scripts/claude-ready-signal.sh 2>/dev/null || echo '{}'"`. This documents a real,
  currently-existing script at `~/.config/nvim/scripts/claude-ready-signal.sh` (confirmed present
  on disk, executable) that is intentionally outside `.claude/` — it is nvim-integration-specific,
  not a `.claude/hooks/` script. A tilde-prefixed path is not literally "absolute" (no leading
  `/`) but is also not CWD-relative (it resolves via `$HOME`, independent of the session's drifted
  shell cwd) — see Risks for why this is a genuine open design question for the plan.

**A live, present-day instance of the exact defect, outside this task's scope**: this repo's own
deployed `.claude/settings.json` (a generated artifact, not source store) line 21 still reads
`"command": "bash scripts/claude-ready-signal.sh 2>/dev/null || echo '{}'"` — the literal
"LIVE EVIDENCE" shape quoted in the dispatch, found live rather than hypothetically. Every other
`"command"` entry in this same deployed file is already `$CLAUDE_PROJECT_DIR`-anchored (the
fragment-sourced hooks were corrected by a resync after task 364 landed), but this one entry is
**root-files-only** and root-files is install-once — never overwritten by resync — so it is stuck
defective in this already-deployed repo regardless of any future source-store fix. This is squarely
the self-healing-gap problem task 364's SCOPE ADDITION section describes, now observed directly
rather than argued abstractly. It is out of scope for task 365 (which touches only the source
store) but is a concrete, present-day argument for why the fragment-coverage check (criteria 8-10)
matters: this specific entry no longer exists in the *source store's* root-files template (task
364 deleted it there), so a freshly-generated root-files copy would not have it — but an
*already-deployed* repo's install-once copy is immune to that source-store fix forever. No action
is required by task 365 itself; flagged as a Context Extension Recommendation below.

**False-positive hazard for a naive text scan**: `root-files/settings.json`'s own top-level
`_comment` field (added by task 364) reads in part: `"... Hook commands must use
\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/x.sh, never a CWD-relative .claude/ path ..."`. A lint that
greps the whole file for `.claude/hooks/` text (rather than anchoring on the `"command"` JSON key)
would pick up this literal `x.sh` as a spurious "registration," as directly demonstrated during
this research (a `comm -23` diff falsely listed `x.sh` as root-files-only until the comment line
was excluded). **The lint must match only lines containing a `"command"` key**, not bare
`.claude/hooks/`-shaped text anywhere in the file. This is the same false-positive risk class
`lint-state-writer-boundary.sh`'s own header explicitly designs around via its allowlist and
structural classifier, and the same general lesson applies here.

**House lint conventions** (surveyed across all 11 scripts in
`agent-system/extensions/core/scripts/lint/`, closest structural match
`lint-state-writer-boundary.sh`, 348 lines):
- Shebang `#!/usr/bin/env bash`, `set -euo pipefail` (or `-uo pipefail` in a couple of scripts
  that need `grep` non-matches not to trip `-e`).
- Fail-closed sourcing: `source "${SCRIPT_DIR}/../lib/common.sh"` guarded by an explicit
  `[[ ! -f ... ]] && { echo ERROR; exit 2; }` immediately above — this is the exact mechanism that
  satisfies acceptance criterion 5 (missing/broken lib → nonzero exit, never a silent pass). The
  header of `lint-state-writer-boundary.sh` states the exit-code contract explicitly:
  `0 = clean, 1 = violations found, 2 = script error`. This task's own script header should state
  the fail-closed/fail-open polarity contrast the dispatch explicitly asks for (deploy gate fails
  closed; write-time hook fails open) in exactly those terms, mirroring how
  `lint-state-writer-boundary.sh` documents its own exit-code contract inline.
- Self-locating project-root resolution that works identically whether invoked from the
  deployed `.claude/scripts/lint/` copy or the source-store
  `agent-system/extensions/core/scripts/lint/` copy — `lint-state-writer-boundary.sh`'s
  `resolve_project_root()` (walks upward looking for `agent-system/extensions`, falling back to
  `common_repo_root`) and `lint-json-channel-discipline.sh`'s simpler `git rev-parse
  --show-toplevel` + `REPO_ROOT` env-override pattern are both live examples to choose between.
- `--verbose` to also print exempted/passing matches with a reason; `--quiet` to suppress the
  progress banner (violations still print either way). Optional positional `path...` args to
  override the default scan root.
- Output convention: `[VIOLATION] file:line: <matched text>` (red), `[EXEMPT] file:line: <reason>
  | <text>` (yellow, verbose-only), ending with a `====` banner summary block and a `Fix:` hint
  line naming the correct form and the source-store-vs-`.claude/` edit-target reminder.
- `manifest.json`'s `"scripts"` → `installed_files` array lists `lint/lint-*.sh` and
  `tests/test-lint-*.sh` **alphabetically**; both arrays must gain one new entry each
  (`lint/lint-hook-registration-paths.sh`,
  `tests/test-lint-hook-registration-paths.sh`) at the alphabetically-correct position.
- `verify-deploy.sh` wires each lint as its own numbered gate (`say "N. <Name> lint
  (lint-foo.sh --verbose)"`), with a uniform `[SKIP]` branch when `$TARGET` is a deploy consumer
  rather than the source store (every lint-gate example found is source-store-only), a `fail "...
  not found in source store"` branch when the script is missing, and a captured-output + `while
  read` loop translating `[VIOLATION]`/`[FAIL]`-tagged lines into `FINDINGS_LIST` entries. Two
  lints registered in `manifest.json` today (`lint-directory-pathspec-boundary.sh`,
  `lint-json-channel-discipline.sh`) are **not yet** wired as their own numbered `verify-deploy.sh`
  gate — `lint-json-channel-discipline.sh`'s own header explains this is deliberate and tracked as
  a separate follow-up (matches the dispatch's cross-reference to the sibling open task
  "wire directory pathspec lint as a verify-deploy gate"). This task's new lint must NOT be left in
  that same un-wired state — criterion 3 requires an actual numbered gate, not mere registration.
- Fixture tests build passing/violating trees under `mktemp -d` and tear down afterward (confirmed
  pattern across `test-lint-state-writer-boundary.sh` and siblings) — matches the dispatch's "no
  on-disk fixtures directory" instruction exactly.

**Fragment-coverage identity tension with `merge.lua`**: `lua/neotex/plugins/ai/shared/extensions/
merge.lua`'s `hook_identity(hook)` (added by task 364) matches only
`hook.command:match("%.claude/hooks/([%w_%-]+%.sh)")` — i.e., it is `hooks/`-anchored and has no
notion of a `scripts/foo.sh`-shaped invocation at all; such a hook falls through to
`vim.deep_equal` exact-match dedupe instead. The dispatch's final revision ("DO NOT ANCHOR... to
`hooks/`") explicitly requires the **lint's** fragment-coverage identity to be broader than this —
keyed on "the invoked script path as written, normalized for the anchor prefix" regardless of
directory name. This means, after this task, the lint and `merge.lua` will use two different
identity notions for the same concept, which is a direct (if narrower-in-practice) reversal of the
earlier revision's own stated goal ("so the two cannot disagree about what 'the same registration'
means"). This is real and should be surfaced to the plan rather than silently resolved either way:
either (a) accept the divergence as this task's explicit, reasoned scope (the lint is a stricter,
independently-maintained check; `merge.lua`'s narrower identity is a separate concern for a future
task), or (b) treat broadening `merge.lua`'s `hook_identity` to match as an explicit out-of-scope
follow-up worth recording. Given task 365's `file_scope` does not include `merge.lua`, option (a)
is the only one actually available within this task's boundaries — but the plan should say so
explicitly rather than let a reader assume the two now agree.

### External Resources

Not applicable — this is a purely internal, source-store lint-authoring task with no external
dependency, library, or documentation surface.

## Recommendations

1. Use `lint-state-writer-boundary.sh` as the primary structural template (fail-closed sourcing,
   `--verbose`/`--quiet`, exit-code contract, `[VIOLATION]` output, `Fix:` footer) and
   `lint-json-channel-discipline.sh` for its simpler `REPO_ROOT` resolution idiom as a secondary
   reference.
2. Implement the path-shape + markdown-template checks (criteria 1, 6, 7, 11) via line-oriented
   `grep -nE` anchored on a `"command"[[:space:]]*:` key match (never a bare `.claude/` or
   `hooks/` text search), to avoid the demonstrated `_comment`-field false positive. Within each
   matched line, extract the invoked script path (handling the nested `bash -c '...'` wrapper
   shape by finding the innermost invoked `*.sh` path, not the outer `bash -c` itself) and accept
   it only if it is `/`-absolute or `"$CLAUDE_PROJECT_DIR"`-prefixed. Apply the identical pattern
   to source-store markdown files' fenced ` ```json ` blocks (these are JSON *fragments*, not
   parseable whole documents — confirmed directly — so grep/regex, not `jq`, is the only viable
   technique there too).
3. Implement the explicit-`cd` direct-invocation exemption (criterion 7) by requiring the matched
   line (or a small fixed lookback window) to NOT be inside a `( cd "..." && ... bash <relative
   path> )` construct — `test-please-grant.sh` line 222 is the concrete positive control for this
   exemption and must be included in the fixture suite as a passing case, per the dispatch.
4. Implement the fragment-coverage check (criteria 8-10) via real `jq` parsing of each settings
   JSON file's `.hooks.<Event>[].hooks[]` entries (valid, complete JSON here, unlike the markdown
   fragments), building two sets — root-files-only script identities vs. the union of every
   fragment surface's identities — and flagging any identity in the first set but not the second.
   Key the identity on the invoked script path string normalized for its anchor prefix (per the
   dispatch's final revision), not on `hooks/NAME.sh` alone, and do not attempt to reuse or import
   `merge.lua`'s narrower `hook_identity`; document the resulting divergence in the script's header
   per Finding above.
5. Implement the existence check (criterion 12) by resolving an invoked `.claude/hooks/NAME.sh` (or
   `"$CLAUDE_PROJECT_DIR"`-anchored hooks path) against every `agent-system/extensions/*/hooks/
   NAME.sh` in the source store (hooks are spread across each extension's own `hooks/` directory,
   not just `core/hooks/`) and failing only when the name is found in none of them. Skip any
   invoked path that is not itself under a recognized source-store-relative hooks location (e.g.
   the `~/.config/nvim/scripts/claude-ready-signal.sh` form) — these are explicitly
   "user-supplied or externally-provided" per the dispatch and must not be failed for absence.
6. Treat `settings.local.json` as explicitly out of scope for every check in this lint, citing task
   364's D6 ruling directly in the script's header/comments so a future reader does not reopen the
   question.
7. Have the plan phase make an explicit, written call on the `~/`-prefixed-path open question
   (Risk below) rather than leaving it implicit in the regex.

## Decisions

- The lint's accept condition for a hook-invoking script path is: `/`-absolute, OR
  `"$CLAUDE_PROJECT_DIR"`-prefixed. (Confirmed by task 364's settled shape and the dispatch's
  final revision; no third candidate shape remains live.)
- `settings.local.json` permission matchers are excluded from every check in this lint (task 364's
  D6 ruling, directly answering the dispatch's conditional scope question).
- The fragment-coverage check's identity is keyed on the invoked script path as written
  (normalized for anchor prefix), independent of directory name — deliberately broader than, and
  intentionally divergent from, `merge.lua`'s current `hooks/`-only `hook_identity()`. This
  divergence is accepted as this task's scope boundary (file_scope excludes `merge.lua`), not
  resolved by reconciling the two.
- MCP server `"command"` fields (e.g. `memory/settings-fragment.json`'s `"command": "npx"` under
  `mcpServers`) are a structurally distinct JSON shape from hook registrations and must not be
  matched by this lint at all — confirmed by inspection, not merely assumed.

## Risks & Mitigations

- **Risk**: A naive `.claude/`- or `hooks/`-text grep false-positives on `root-files/
  settings.json`'s own explanatory `_comment` field (demonstrated directly in this research).
  **Mitigation**: anchor every match on the `"command"` JSON key, never on bare path text.
- **Risk**: The `~/`-prefixed path in `neovim-integration.md` line 34 is neither literally absolute
  nor `$CLAUDE_PROJECT_DIR`-anchored, yet is correct (cwd-independent, resolves via `$HOME`) and
  must not be flagged as a violation, while the dispatch's rule as literally stated ("absolute or
  `$CLAUDE_PROJECT_DIR`-anchored; everything else is a violation") would flag it. **Mitigation**:
  the plan must explicitly decide whether a leading `~/` is an accepted third shape (recommended,
  given it is demonstrably cwd-independent and already in deliberate, correct use) or whether this
  one line should instead be rewritten away from `~/` during this task — flagging this now so the
  implementation phase does not silently guess either way.
- **Risk**: This repo's own deployed `.claude/settings.json` (line 21) still carries the exact
  dead-registration defect live, today, and is permanently unreachable by resync (install-once).
  **Mitigation**: none required by task 365 itself (out of `file_scope`, and `.claude/**` is never
  the correct edit target per `rules/source-store-deploy-boundary.md`) — recorded purely as a
  Context Extension Recommendation for a possible future one-time repair task.
- **Risk**: Reusing `merge.lua`'s `hook_identity()` logic (porting its Lua pattern into the lint's
  bash/jq identity notion) could silently narrow the fragment-coverage check back to `hooks/`-only,
  regressing criterion 8's stated breadth. **Mitigation**: implement the identity independently in
  the lint (do not import or mirror `hook_identity`'s `hooks/`-anchored pattern), and include a
  `scripts/foo.sh`-shaped fixture case (mirroring the `claude-ready-signal.sh` line-118 shape) in
  the fragment-coverage fixture set, not only a `hooks/foo.sh`-shaped one.

## Context Extension Recommendations

- **Topic**: Already-deployed install-once `root-files` entries that predate a source-store fix.
- **Gap**: No existing context file documents that an install-once `root-files/settings.json`
  defect fix in the source store never reaches an already-deployed repo whose own `.claude/
  settings.json` predates the fix (this repo's own live `scripts/claude-ready-signal.sh` line 21
  entry is a concrete, current instance).
- **Recommendation**: Not urgent enough to block this task; worth a follow-up task (separate from
  365) to either (a) write a one-time repair note/script for already-deployed repos carrying this
  specific stale entry, or (b) document the general install-once-staleness risk pattern in
  `context/project/neovim/domain/extension-deploy-modes.md` or a sibling deploy-mode doc, for
  whoever eventually audits other already-deployed consumer repos.

## Appendix

- Search queries / commands used: `jq` queries against `specs/state.json` (task 365, task 364,
  tasks 282/347 status); `grep -rn` across `agent-system/extensions/**/settings*.json` and the
  four named markdown files for `"command"` and `.claude/hooks`; `comm -12/-23/-13` set
  comparisons between `root-files/settings.json` and `merge-sources/settings-hooks.json` hook
  names; direct reads of task 364's `reports/01_cwd-relative-hook-paths.md`,
  `reports/02_cwd-relative-hook-paths-research.md`, `plans/02_cwd-relative-hook-registration-
  paths.md`, and `summaries/02_cwd-relative-hook-registration-paths-summary.md`; direct reads of
  `lua/neotex/plugins/ai/shared/extensions/merge.lua` (`hook_identity`, `find_hook_match`);
  direct reads of `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` and
  `lint-json-channel-discipline.sh`; direct reads of `agent-system/extensions/core/scripts/
  verify-deploy.sh` (gate structure) and `manifest.json` (`installed_files` lint/test entries);
  direct read of this repo's own deployed `.claude/settings.json`.
- References: `specs/364_cwd_relative_hook_registration_paths/` (plan, reports, summary);
  `agent-system/extensions/core/scripts/lint/*.sh` (11 existing lints); `agent-system/extensions/
  core/scripts/tests/test-please-grant.sh` line 222 (explicit-cd positive control);
  `agent-system/extensions/core/manifest.json`; `agent-system/extensions/core/scripts/
  verify-deploy.sh`.
