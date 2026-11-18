# Research Report: Task #527

- **Task**: 527 - Extend the hook-registration lint to assert the deployed registration SET
  against the merge-source, and wire the gate into verify-deploy.sh
- **Started**: 2026-11-17T00:00:00Z
- **Completed**: 2026-11-17T00:00:00Z
- **Effort**: ~2 hours
- **Dependencies**: orphan_sweep_for_removed_merge_target_entries (archived, completed) and
  gate8_expected_vs_new_failure_distinction (archived, completed) -- both confirmed landed; see
  Findings.
- **Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh`,
  `agent-system/extensions/core/scripts/verify-deploy.sh`, `agent-system/extensions/core/scripts/gate-registry.data`,
  `lua/neotex/plugins/ai/shared/extensions/{hook_identity,merge,init}.lua`), archived task
  summaries (369, 445), live filesystem check of `~/Projects/Logos/Theory/.claude-extensions.json`.
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both dependency edges are satisfied: task 369 (`orphan_sweep_for_removed_merge_target_entries`)
  and task 445 (`gate8_expected_vs_new_failure_distinction`) are archived/completed. Task 369 left
  behind exactly the single shared identity notion this lint must consume:
  `lua/neotex/plugins/ai/shared/extensions/hook_identity.lua` (`M.identity`), its CLI bridge
  (`hook_identity_cli.lua`), and -- critically -- `merge.lua`'s already-exported
  `M.hook_valid_set_key(event, matcher, identity)`, which is the *exact* `(event, matcher,
  hook-identity)` tuple this task's GOAL asks the lint to assert. The new check should reuse this
  key shape by name, not invent a second one.
- The existing lint (`lint-hook-registration-paths.sh`) never reads a *deployed* `.claude/settings.json`
  today -- all four existing checks (A-D) operate purely on the source store's own declared
  surfaces (`merge-sources/*.json`, `root-files/settings.json`). The new SET check is therefore a
  genuinely new fifth check ("Check E"), not an extension of an existing one, and needs its own
  input (a deployed settings.json path) and its own matcher-aware inventory (the existing
  Check C/D inventory recipe silently discards `.matcher`, which is required for shape (b)).
- **Gate wiring requires no new gate.** Gate 21 in `verify-deploy.sh` already runs the full lint
  script with `--verbose` and already scrapes every `[VIOLATION]` line into `FINDINGS_LIST`; its
  registry row (`gate-registry.data` id 21, `requires_source_store: true`) is architecturally
  identical to what Check E needs ($TARGET must be the source-store repo, since only there do
  `agent-system/extensions/` and `lua/neotex/.../hook_identity_cli.lua` exist side by side). Adding
  Check E's violations to the same script automatically strengthens Gate 21; no registry edit, no
  new `gateNN_run` function, no renumbering is needed.
- **A field-instance premise check found two of the four dispatch-cited repos already fixed, and
  surfaced a genuinely distinct fourth defect class.** Logos/Theory and Logos/Website's shape
  (a)+(b) pair (measured 2026-11-07) were live-resynced and corrected by task 369 on 2026-11-11.
  ModelBuilder remains genuinely drifted (no live resync was done there). theorem_proving_in_lean4's
  cited shape (c) is a *different* defect than the one task 369 measured for that repo: the two
  named scripts (`claude-stop-notify.sh`, `wezterm-preflight-status.sh`) ARE correctly declared
  and DO exist in the source store -- the missing-file condition is specific to that repo's own
  deployed filesystem, not a declaration or source-store gap. This has a direct design
  consequence (see Findings: "Existence must be checked against the deploy target, not the source
  store").
- Recommended approach: add Check E to the existing lint script, default its deployed-settings
  input to `$PROJECT_ROOT/.claude/settings.json` (never `settings.local.json`, matching the
  existing D6 exclusion), thread `matcher` through the shared inventory collector, and derive all
  three shapes from one pass: shape (a)/(c) split on whether the normalized path exists *at the
  deploy target* (`$(dirname DEPLOYED_FILE)/<norm>`), and shape (b) from grouping deployed entries
  by `(event, identity)` and flagging any group with >1 distinct matcher value, independent of
  declared-set membership.

## Context & Scope

This repository (`~/.config/nvim`) is the single source-store repository for a Claude Code
extension-loader system implemented in Lua (loaded inside Neovim) that merges per-extension
settings fragments into many other repositories' own `.claude/` trees on this one machine. Task
369 closed the loader-side half of a drift problem: a hook registration removed from the merge
source would survive indefinitely in an already-deployed `.claude/settings.json` until swept.
That sweep runs only inside Neovim, at merge/reload time. This task's job is the complementary,
independent *verification* half: a standalone lint check (no Neovim dependency beyond the
existing identity bridge) that can assert, after the fact, that a deployed registration set
matches what the source currently declares -- catching drift the sweep missed, drift from a stale
deploy that hasn't been resynced, or a genuinely new defect class (duplicate-matcher double-fire)
the sweep was never designed to report as a *finding* (the sweep silently removes it; this lint
must *report* it as three distinct, separately-remediable findings).

The scope is bounded by the dispatch's MANDATORY CONSTRAINTS: consume the one shared identity
definition rather than re-deriving it; never report a hand-written custom hook; anchor detection
on the JSON `"command"` key, never a text grep; report shape (b) unconditionally; and touch
`hooks` only, never `env`/`permissions`/`statusLine`/etc.

## Findings

### Dependency status (both edges satisfied)

- **Task 369** (`specs/archive/369_orphan_sweep_for_removed_merge_target_entries/`): archived,
  `[COMPLETED]`. Delivered the single normative identity module
  (`lua/neotex/plugins/ai/shared/extensions/hook_identity.lua`, `M.identity(command, hook_type)`
  returning `"<type>:<normalized_path>"` or `nil`), its logic-free CLI bridge
  (`hook_identity_cli.lua`, invoked via `nvim --headless -l ... <stdin >stdout`, batched
  tab-separated `type\tcommand` lines), a shared conformance corpus
  (`hook_identity_fixtures.json`), and `merge.lua`'s `M.hook_identity` / `M.hook_valid_set_key` /
  `M.remove_orphaned_hook_registrations`. The lint's own former `normalize_identity()` was
  deleted; Checks C and D in `lint-hook-registration-paths.sh` already resolve identity through
  this one bridge (`resolve_identities_via_bridge`, lines 535-560 of the current lint script). A
  test already asserts lint/sweep identity agreement outside `hooks/`
  (`test-lint-hook-registration-paths.sh`), satisfying this task's acceptance criterion 4's
  precondition.
- **Task 445** (`specs/archive/445_gate8_expected_vs_new_failure_distinction/`): archived,
  `[COMPLETED]`. Touched only Gate 8 (`run-all.sh` wrapper) in `verify-deploy.sh`; no overlap with
  Gate 21's territory. The "territory edge" the dispatch names is satisfied by the fact both
  records are now closed, not by any remaining coordination this task must do.

### The lint has no deployed-tree concept today

`lint-hook-registration-paths.sh`'s four checks (A: path-shape in settings surfaces, B: path-shape
in markdown templates, C: fragment coverage, D: script existence) all draw their input exclusively
from `SETTINGS_FILES` = `ROOT_FILES_GROUP + FRAGMENT_GROUP`, populated by `classify_settings_file()`
matching only three filename shapes: `*/root-files/settings.json`, `*/settings-hooks.json`,
`*/settings-fragment.json` (lines 353-363). A bare deployed `.claude/settings.json` (not under a
`root-files/` directory, not named `settings-hooks.json`/`settings-fragment.json`) matches none of
these cases and is silently ignored if passed as a scan path today. The new SET check (hereafter
"Check E") needs a distinct, explicit notion of "the deployed file to audit", not a reuse of
`SCAN_PATHS`.

### `merge.lua` already defines the exact tuple shape this task needs

`M.hook_valid_set_key(event, matcher, identity)` (merge.lua:926) builds
`event .. "\1" .. matcher .. "\1" .. identity` and is the key both the Lua-side orphan sweep and
(per task 369's own doc comments) any future bash-side consumer should use for "is this the same
registration". `union_hook_registrations_into_valid_set` (init.lua:75-93) shows the canonical way
to fold a settings-shaped table into a valid_set using exactly this key. Check E's declared-set
and deployed-set should both be built as sets of this same triple (recomputed in bash/jq terms,
since Check E has no Neovim runtime access beyond the existing one-shot identity bridge).

### The existing Check C/D inventory recipe discards `matcher` -- a direct blocker for shape (b)

`collect_inventory()` (lint script lines 572-589) extracts `[$event, (.type // ""), (.command //
"")]` via jq, iterating `(.value // [])[]` (the array of `{matcher, hooks:[...]}` blocks) without
ever reading `.matcher`. Shape (b) (the same identity registered under two different matcher
strings for one event) is undetectable without matcher. This is a required, small change to the
shared jq recipe -- not a redesign -- and the same recipe can be reused for a deployed-file pass
(same `ALL_GROUP`/`ALL_FILE`/`ALL_EVENT`/`ALL_TYPE`/`ALL_COMMAND` arrays pattern, with a new
`ALL_MATCHER` array and a `collect_inventory deployed "$DEPLOYED_FILE"` call alongside the existing
`collect_inventory root ...` / `collect_inventory frag ...` calls, all resolved through ONE batched
bridge call as today -- never a second, parallel identity-resolution mechanism).

### Existence must be checked against the deploy target, not the source store (new finding)

The existing `check_exists()` (lint script lines 333-340) resolves existence by globbing
`$PROJECT_ROOT/agent-system/extensions/*/<norm>` -- i.e. "does this script exist anywhere in the
source store". That is the right question for Checks C/D (which audit the source's own
declarations), but it is the *wrong* question for shape (c) as this dispatch defines it: "a
registration whose hook script file does not exist **on disk at all**, failing open". Verified
directly: `claude-stop-notify.sh` and `wezterm-preflight-status.sh` -- the two scripts this
dispatch cites as lean4's shape (c) instances -- both exist today in the source store
(`agent-system/extensions/core/hooks/`), confirmed via `find`. The field defect task 369's own
baseline record (`records/01_baseline-measurements.md`) attributes to lean4 is explicitly described
there as "a missing-file deployment defect, not an orphan-registration defect... out of this
task's scope" (the registration *is* source-declared; the file is simply absent from that one
repo's own deployed `.claude/hooks/`). A Check E existence test that reuses `check_exists()`
unmodified would therefore report **zero** findings for this exact field instance -- a false
negative on the defect class this task's own dispatch names as a motivating example. Check E's
shape-(c) existence test must instead resolve the normalized path relative to the **deployed**
file's own directory (`$(dirname "$DEPLOYED_SETTINGS")/<norm>`, e.g.
`$TARGET/.claude/hooks/claude-stop-notify.sh`), independent of `check_exists()`'s source-store
glob. This is a one-line difference in *where* the existence probe looks, but it is the
difference between the check actually catching the cited field defect and silently missing it.

### `requires_source_store: true` already matches what Check E needs -- Gate 21 is the correct wiring point, unmodified

`gate-registry.data` row 21: `21	Hook registration path lint (lint-hook-registration-paths.sh)
gate21_run	-	true	30	moderate	false	@extensions`. Field 5 (`requires_source_store`) is
already `true`, and `gate21_run` (verify-deploy.sh:2107-2133) already guards on
`[ -d "$TARGET/agent-system/extensions" ]`, runs the full lint script with `--verbose`, and scrapes
every line matching `[VIOLATION]` via `verify_deploy_extract_verdict_lines` into
`FINDINGS_LIST` tagged `gate21`. Check E's new violation lines, if emitted with the same
`[VIOLATION]` prefix convention the lint already uses for Checks A-D, are captured by this
existing scrape mechanism with **zero** changes to `verify-deploy.sh` or `gate-registry.data`.
This satisfies acceptance criterion 5 ("the gate is wired into verify-deploy.sh") by construction,
since Gate 21 already *is* "the resulting gate" once the lint script itself gains the new check.
A deliberately-drifted fixture dropped at `$PROJECT_ROOT/.claude/settings.json` (or the default
path Check E resolves to) will make Gate 21 fail exactly as it already does for Checks A-D today.

### `$TARGET`'s own deployed settings.json is the only deployed tree Gate 21 can reach

Because `requires_source_store: true` forces $TARGET to be the source-store repo itself for Gate
21 to run at all (every other target skips with `[SKIP] ... is a deploy consumer`), the deployed
side Check E compares against, in the *automated gate* context, is necessarily this repo's own
`.claude/settings.json` -- not Logos/Theory's, ModelBuilder's, etc. Those other repos' deployed
trees remain reachable only via the lint's existing explicit-scan-path mechanism (an ad hoc CLI
invocation pointing Check E's deployed-file input at an arbitrary path), which is exactly the
mechanism acceptance criteria 1 and 3 call for ("a faithful copy of a real drifted deploy", "verified
against several of the fourteen clean repos") -- both read naturally as one-time verification
evidence gathered during implementation, not a new standing fleet-wide CI job. This is consistent
with task 369's own precedent: its baseline/after measurements were gathered by direct `jq`
inspection of each repo's settings.json from this same vantage point, never by running a per-repo
copy of any script.

### Premise re-validation: two of the four cited field instances are already remediated; the fourth is a different defect than previously measured

The dispatch's MEASURED FIELD INSTANCES section is dated 2026-11-07. Task 369 completed on
2026-11-11 and its own summary states plainly: "host, Logos/Theory, Logos/Website, and
theorem_proving_in_lean4 were all resynced live via `deploy-headless.sh`, each showing the
predicted orphan(s) removed, 0 per-event duplicates". That means:
- **Logos/Theory** and **Logos/Website**'s shape (a)+(b) pair (as measured 2026-11-07) is fixed.
- **ModelBuilder** remains genuinely drifted -- task 369's own Follow-ups section states its live
  tree was never resynced (98 uncommitted, unrelated changes blocked it; only a scratch-directory
  replay was done). This is the one dispatch-cited repo still safely usable as a live, real
  drifted-deploy fixture source today, and its settings.json content is already captured verbatim
  at `specs/archive/369_orphan_sweep_for_removed_merge_target_entries/records/fixtures/modelbuilder-settings.json`.
- **theorem_proving_in_lean4**'s *fixed* defect (the CWD-relative `claude-ready-signal.sh`
  orphan, shape (a)) is no longer present after the 2026-11-11 resync. The shape (c) pair this
  dispatch names for lean4 (`claude-stop-notify.sh`, `wezterm-preflight-status.sh`) is a
  pre-existing, *separate*, still-open deployment gap task 369 explicitly declared out of its own
  scope -- it remains live today and is this task's best available real-world shape-(c) exemplar,
  though verifying it requires checking that repo's actual deployed `.claude/hooks/` contents
  directly (not derivable from the settings.json fixture alone, since the fixture only captures
  the registration text, not the deploy target's filesystem state).

This does not change the task's goal or design -- all five already-captured task-369 fixtures
(`host`, `modelbuilder`, `logos-theory`, `logos-website`, `lean4` -- all at
`specs/archive/369_orphan_sweep_for_removed_merge_target_entries/records/fixtures/*.json`) remain
directly reusable as "faithful copies of a real drifted deploy" settings.json content for
acceptance criterion 1 and for the clean-repo check in criterion 3 (host/logos-theory/logos-website
are now clean after remediation and serve as negative/clean-repo fixtures; modelbuilder remains a
genuine positive fixture). Reusing these as-is (verbatim, from the already-archived task) rather
than re-capturing live state avoids re-measuring repos this task has no need to touch.

### Existing test-fixture idiom to follow

`test-lint-hook-registration-paths.sh` (674 lines) plants synthetic fixtures inside a `mktemp -d`
`WORKDIR`, resolves the subject lint via `common_test_resolve_subject` (deploy-tree-first /
source-store-fallback), and invokes the lint with an explicit file path argument per case (e.g.
`bash "$LINT_SCRIPT" "$CASE1_DIR/settings.json"`), asserting on exit code and on a `grep` for a
`[VIOLATION].*<name>` line in captured output. New Check E cases should follow the same shape: a
scratch `WORKDIR` holding both a synthetic/real-copied merge-source tree AND a synthetic/real-copied
deployed-settings file (plus, for shape (c), a companion `hooks/` directory with some files present
and the cited one deliberately absent -- the settings.json fixtures alone do not encode deploy-target
filesystem state).

## Recommendations

1. Add a fifth check ("Check E: deployed-set assertion") to
   `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh`, not a new,
   separate lint script -- this matches the dispatch's own framing ("Extend the hook-registration
   lint...") and lets Gate 21's existing wiring absorb the new findings with zero changes to
   `verify-deploy.sh` or `gate-registry.data`.
2. Give Check E an explicit deployed-settings input, defaulting to `$PROJECT_ROOT/.claude/settings.json`
   (never `settings.local.json`, consistent with the existing D6 exclusion and with the
   "env/permissions/statusLine out of scope" constraint), overridable via a new CLI flag (e.g.
   `--deployed-settings PATH`) for ad hoc verification against other repos' copied/real settings
   files and for the fixture-driven test suite.
3. Extend `collect_inventory()`'s jq recipe to also capture `.matcher`, and add a `deployed` group
   (`collect_inventory deployed "$DEPLOYED_FILE"`) resolved through the SAME batched
   `resolve_identities_via_bridge` call already used for `root`/`frag` -- never a second identity
   mechanism. Build the declared set as `{event\x01matcher\x01identity}` strings mirroring
   `merge.lua`'s `M.hook_valid_set_key`, explicitly naming that correspondence in the code comment
   so the two definitions cannot silently diverge again (the exact failure task 369's dependency
   edge exists to prevent).
4. Derive findings from the deployed inventory in one pass, skipping any row whose identity is
   `nil` (the mandatory, unconditional carve-out) before any other logic runs:
   - **Shape (b)** (checked first, independent of declared-set membership): group surviving
     deployed rows by `(event, identity)`; any group whose member matchers are not all identical
     is a shape-(b) finding, naming both matcher strings and the double-fire event.
   - **Shape (a) vs (c)** (checked for any deployed row whose `(event, matcher, identity)` triple
     is absent from the declared set): if the normalized path exists at
     `$(dirname "$DEPLOYED_FILE")/<norm>`, it is shape (a) (undeclared but the script is present --
     remedy: either remove the stale registration or correct the merge source's declared
     matcher/event to match); if it does not exist there, it is shape (c) (remedy: fix the
     registered path or remove the registration -- re-declaring it would not help, since the file
     itself is gone from this deploy target).
5. Wire no new gate. Confirm via a deliberately-drifted fixture dropped at Check E's default
   deployed path that the existing Gate 21 invocation already fails on it (acceptance criterion
   5), and confirm the pre-existing Checks A-D plus the full `verify-deploy.sh` gate battery stay
   green (acceptance criterion 6).
6. For acceptance criterion 1's "faithful copy of a real drifted deploy", reuse
   `specs/archive/369_orphan_sweep_for_removed_merge_target_entries/records/fixtures/modelbuilder-settings.json`
   (still genuinely drifted, shape a+b) directly; for a genuine shape-(c) exemplar, either
   synthesize a companion fixture missing a declared script's file (fastest, fully self-contained)
   or, if judged worth the cost, capture theorem_proving_in_lean4's real deployed `.claude/hooks/`
   contents (confirmed still missing `claude-stop-notify.sh`/`wezterm-preflight-status.sh` as of
   this dispatch's own citation, though not re-verified live during this research pass since doing
   so would require filesystem access to that repo).
7. For acceptance criterion 3, spot-check Check E (via the `--deployed-settings` override) against
   a few repos recorded as currently clean per task 369's measurements (e.g. `~/Projects/Logos/Verification`,
   `~/Projects/protocol`, `~/Projects/Repos/provability-fabric`) as implementation-time ad hoc
   verification evidence, not as new permanent automated test cases.

## Decisions

- Treat this as a fifth check inside the existing lint script, not a new standalone script --
  directly supported by the dispatch's own "Extend the hook-registration lint" framing and by
  Gate 21's registry row already matching the new check's `requires_source_store` precondition
  exactly.
- Treat Gate 21 as already "the resulting gate" the dispatch asks to be wired in -- no new gate
  id, no `gate-registry.data` edit is needed, since Gate 21 already runs the whole script and
  already scrapes every `[VIOLATION]` line.
- Resolve shape-(c) existence against the deployed file's own directory, never against the
  source store's global `agent-system/extensions/*/` glob -- the source-store-relative
  `check_exists()` function is correct for Checks C/D (which audit declarations) but would produce
  a false negative on this task's own cited field exemplar if reused unmodified for Check E.

## Risks & Mitigations

- **Risk**: resolving `$PROJECT_ROOT/.claude/settings.json` by default could make Check E a no-op
  in a checkout where that file has never been deployed (e.g. a fresh clone before the first
  `[Reload All]`). **Mitigation**: mirror Checks A-D's existing degrade pattern -- treat a missing
  deployed-settings file as "nothing to check" (0 findings, not an error), exactly like an empty
  `SETTINGS_FILES` array degrades today.
- **Risk**: a sweep that already ran (via a recent `[Reload All]`) would make Check E's own
  default-path check vacuous against this repo's own deploy, since the Lua sweep already removes
  exactly the orphans Check E would otherwise find. **Mitigation**: this is expected and
  acceptable -- Check E's value is as an independent, Neovim-runtime-free verification layer
  (defense in depth against a missed sweep, a stale deploy, or shape (b), which the sweep collapses
  silently rather than reporting as a finding) and as the mechanism that makes ad hoc, explicit-path
  verification against other repos possible at all, not as a check expected to fire routinely
  against this repo's own freshly-resynced deploy.
- **Risk**: adding a `matcher` field to `collect_inventory()`'s shared recipe could silently
  change Check C's or Check D's own existing behavior if either implicitly depended on the row
  shape. **Mitigation**: confirmed by direct reading that neither Check C (keys only on
  `identity|event`) nor Check D (reads only `identity`/`file`) references `matcher`; adding a
  column to the TSV extraction and the parallel bash arrays is additive and should leave their
  existing logic untouched, verified by running the existing suite unmodified after the change.

## Context Extension Recommendations

- **Topic**: deployed-vs-declared SET verification pattern for the hook-registration lint cluster.
- **Gap**: no existing context file documents the distinction (now load-bearing for this task)
  between "does the source store declare/contain X" (the existing `check_exists()` question) and
  "does the file exist at THIS deploy target" (the new question Check E must ask) -- a distinction
  that is easy to get backwards when reusing an existing helper function by name.
- **Recommendation**: once implemented, add a short note to
  `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md`
  (which already documents the add/change-but-not-delete invariant from task 369) covering this
  source-store-relative-vs-deploy-target-relative existence distinction, so a future lint in this
  cluster does not repeat the same false-negative risk this report identifies.

## Appendix

- Searches/reads performed: `jq`/`ls`/`find` over `specs/state.json`, `specs/TODO.md`, and
  `specs/archive/{369,445}_*/summaries/*.md`; direct `jq` read of
  `~/Projects/Logos/Theory/.claude-extensions.json` and `~/Projects/ModelBuilder/.claude-extensions.json`
  (confirming the managed/unmanaged distinction); full read of
  `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` (687 lines); targeted
  reads of `lua/neotex/plugins/ai/shared/extensions/{hook_identity.lua,merge.lua,init.lua}`;
  targeted reads of `agent-system/extensions/core/scripts/verify-deploy.sh` (gates 21-29) and
  `agent-system/extensions/core/scripts/gate-registry.data`; `find` confirming
  `claude-stop-notify.sh`/`wezterm-preflight-status.sh` exist under
  `agent-system/extensions/core/hooks/`; header read of
  `agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` and
  `agent-system/extensions/core/scripts/lib/lint-corpus-scan-lib.sh`.
- Key file paths for the implementation phase: lint script above; its test counterpart
  (`agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh`); the five
  reusable fixtures under
  `specs/archive/369_orphan_sweep_for_removed_merge_target_entries/records/fixtures/`.
