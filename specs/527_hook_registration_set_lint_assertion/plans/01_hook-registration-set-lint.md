# Implementation Plan: Task #527

- **Task**: 527 - Extend the hook-registration lint so it asserts the deployed hook registration
  SET against the merge-source, not only the FORM of each individual command path, and wire the
  resulting gate into verify-deploy.sh
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: `orphan_sweep_for_removed_merge_target_entries` (task 369, archived
  `[COMPLETED]`) and `gate8_expected_vs_new_failure_distinction` (task 445, archived
  `[COMPLETED]`) -- both edges confirmed landed; see Overview.
- **Research Inputs**: specs/527_hook_registration_set_lint_assertion/reports/01_hook-registration-set-lint.md
- **Artifacts**: plans/01_hook-registration-set-lint.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`scripts/lint/lint-hook-registration-paths.sh` today checks only the FORM of each hook
registration's invoked-script path across the source store's own declared surfaces; it has no
concept of a deployed tree at all. This plan adds a fifth check ("Check E") to that same script
which compares a deployed `.claude/settings.json`'s `(event, matcher, hook-identity)` registration
SET against the union of what the merge-source and root-files surfaces declare, reporting three
drift shapes as distinct findings with distinct remedies: (a) a registration no source surface
declares, (b) one hook identity registered under two different matchers for one event (a
double-fire), and (c) a registration whose script file is absent from that deploy target's own
filesystem. Done means: the three shapes are separately reported and separately remedied, a
hand-written custom hook is never reported, Gate 21 fails on a drifted fixture, and the
pre-existing lint and `verify-deploy.sh` suites stay green.

### Research Integration

The research report settles five design questions this plan builds on directly, rather than
re-deriving:

- **Consume, never redefine, the identity notion.** `merge.lua` already exports
  `M.hook_valid_set_key(event, matcher, identity)` -- literally the tuple this task's GOAL names --
  and the lint already resolves every identity through the one shared module via the logic-free
  `hook_identity_cli.lua` bridge (`resolve_identities_via_bridge`). Check E reuses both by name.
  Verified live at plan time: the bridge maps `bash .claude/hooks/tts-notify.sh ...` and
  `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/tts-notify.sh ...` to the same identity
  (`command:hooks/tts-notify.sh`), returns a non-empty identity for a path outside `hooks/`
  (`command:scripts/foo.sh`), and returns empty for a `~/`-anchored path -- the mandatory
  carve-out.
- **Check E is a new fifth check, not an extension of an existing one.** All four current checks
  draw exclusively from `ROOT_FILES_GROUP + FRAGMENT_GROUP`, populated by
  `classify_settings_file()` matching only three filename shapes. A bare deployed
  `.claude/settings.json` matches none of them and is silently ignored if passed as a scan path
  today, so Check E needs its own explicit input.
- **Existence must be probed at the deploy target, not in the source store.** The existing
  `check_exists()` globs `$PROJECT_ROOT/agent-system/extensions/*/<norm>` -- the right question for
  Checks C/D (which audit declarations) and the wrong one for shape (c). Confirmed live: the
  identity's normalized path is `.claude/`-relative (`hooks/tts-notify.sh`), so shape (c)'s probe
  is `$(dirname "$DEPLOYED_SETTINGS")/<norm>`.
- **`matcher` is discarded by the shared inventory today.** `collect_inventory()`'s jq recipe
  extracts `[$event, (.type // ""), (.command // "")]` and never reads `.matcher`, so shape (b) is
  undetectable without a small additive change to that one recipe.
- **No new gate is needed.** `gate-registry.data` row 21 already carries
  `requires_source_store: true`, and `gate21_run` already runs the whole lint with `--verbose` and
  scrapes every `[VIOLATION]` line into `FINDINGS_LIST`. Re-confirmed verbatim at plan time.

### Premise Re-Validation (Carried-Figure Discipline)

The dispatch flagged two lines for re-validation, and its `MEASURED FIELD INSTANCES` block (dated
2026-11-07) carries further figures this plan depends on. All were checked against live state at
plan time; results stated explicitly, including where they only confirm the dispatch unchanged.

| Carried claim | Source | Result at plan time (2026-11-17) |
|---|---|---|
| Source store is `agent-system/extensions/core/**`, resolved from `.claude-extensions.json` | dispatch line 3 | **CONFIRMED unchanged.** `.extensions.core.source_dir` resolves to `/home/benjamin/.config/nvim/agent-system/extensions/core`; every path in this plan is spelled as it is on disk there. |
| A naive `.claude/hooks/` grep matches `root-files/settings.json`'s own `_comment` field | dispatch line 30 | **CONFIRMED unchanged.** That file's `_comment` does quote `"$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh` in prose; the file carries 22 `.claude/hooks/` text occurrences. The lint's existing key-anchored extraction and its Case 13 fixture already close this; Check E inherits the closure by using the same jq `.hooks` walk. |
| Gate 21's registry row sets `requires_source_store: true` and scrapes `[VIOLATION]` lines | research report | **CONFIRMED unchanged**, read verbatim from `gate-registry.data` row 21 and `gate21_run`. |
| ModelBuilder is still genuinely drifted | research report | **CONFIRMED, and narrowed.** Its deployed tree carries 10 CWD-relative registrations, including `wezterm-clear-status.sh` under `UserPromptSubmit|*`, which no source surface declares -- a live shape (a). But both `wezterm-clear-status.sh` and `wezterm-notify.sh` are PRESENT in its own `.claude/hooks/`, so ModelBuilder supplies shape (a) only, never shape (c). |
| lean4 carries shape (c) twice (`claude-stop-notify.sh`, `wezterm-preflight-status.sh` absent) | dispatch, `MEASURED FIELD INSTANCES` | **DOES NOT HOLD.** Both files are present in `~/Projects/theorem_proving_in_lean4/.claude/hooks/` today. A probe of six deployed repos (Logos/Verification, protocol, ModelBuilder, Logos/Theory, lean4, provability-fabric) found **zero** live shape-(c) instances. |
| Logos/Theory carries shape (b) (two Notification blocks both registering `tts-notify.sh`) | dispatch, `MEASURED FIELD INSTANCES` | **DOES NOT HOLD, and no substitute exists.** Task 369's own baseline record states this defect was hand-repaired on 2026-11-07, before its fixtures were captured; the captured `logos-theory-settings.json` holds one Notification `tts-notify.sh` registration, matcher `permission_prompt|elicitation_dialog`. No same-event duplicate-matcher pair exists in any of the five archived fixtures or in any of the six probed live deploys. |
| "Fourteen other deployed repos are clean" | dispatch, `MEASURED FIELD INSTANCES` | **ALREADY REFUTED by task 369's own record**, which found the CWD-relative `bash scripts/claude-ready-signal.sh` orphan in at least sixteen further repos. Confirmed consequential here: the bridge resolves that command to the identity-eligible `command:scripts/claude-ready-signal.sh`, so Check E would report it. Phase 1 measures today's actual clean set rather than carrying the figure. |
| This repo's own deployed tree would turn Gate 21 red once Check E lands | not claimed by any record -- checked because it is the task's main landing hazard | **It would not.** A jq inventory of `.claude/settings.json` against the union of the 12 source-declared settings surfaces leaves exactly one non-matching row, an inline `PreToolUse|Write` snippet with no `*.sh` invocation, which the nil-identity carve-out drops before any finding logic runs. No missing files, no same-event duplicate matchers. |

**Consequence for acceptance criterion 1.** The criterion asks for each shape demonstrated
"against a faithful copy of a real drifted deploy, not only a synthetic fixture". Only shape (a)
has a surviving live instance. This plan therefore satisfies the criterion with a
**real-deploy-derived** fixture family: every fixture is a verbatim copy of a real deployed
`.claude/settings.json` (and, for shape (c), a verbatim copy of that repo's real `.claude/hooks/`
file listing), carrying at most **one documented, minimal mutation** for a shape with no surviving
live instance, each mutation reproducing a measurement recorded verbatim in task 369's archived
baseline record. Phase 1 re-probes the whole fleet first, so a surviving live instance is used
wherever one is found and a mutation is introduced only where none is. Phase 6's summary states
per shape whether its exemplar was found live or reconstructed, and names the reconstruction
source. Substituting a wholly synthetic fixture while claiming real-deploy provenance is the
specific dishonesty this arrangement exists to prevent.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap phases are
included.

## Goals & Non-Goals

**Goals**:

- Check E compares a deployed `.claude/settings.json`'s `(event, matcher, hook-identity)` set
  against the union of the source-declared surfaces, and reports shapes (a), (b) and (c) as three
  distinct findings with three distinct remedy texts.
- Shape (b) is reported whenever one identity appears under two different matchers for one event,
  independent of declared-set membership and independent of whether each registration is
  individually well-formed -- form-correctness is exactly why it passes today.
- The nil-identity carve-out (a hand-written custom hook; a `~/`-anchored, absolute-non-`.claude/`,
  or no-`*.sh` command) runs FIRST, unconditionally, before any other Check E logic.
- The identity notion is consumed from its single shared definition (`hook_identity.lua` via
  `hook_identity_cli.lua`, keyed as `merge.lua`'s `M.hook_valid_set_key` does), never redefined.
- Detection is anchored on the jq `.hooks` walk and the `"command"` key, never a text grep.
- Check E is reachable ad hoc against an arbitrary deployed settings file, so the fixture suite and
  one-time cross-repo verification can run at all.
- Gate 21 fails on a drifted fixture with no edit to `verify-deploy.sh` or `gate-registry.data`.
- Checks A-D's finding set is unchanged, and the pre-existing lint and `verify-deploy.sh` suites
  stay green.

**Non-Goals**:

- `env`, `permissions`, `statusLine`, `mcpServers` and every other non-`hooks` key: out of scope,
  never reported, never touched.
- `settings.local.json`: out of scope for every check, per the lint's existing D6 ruling.
- Re-litigating the identity notion, or defining a second one anywhere.
- A new gate id, a `gate-registry.data` row, or a `gateNN_run` function.
- A standing fleet-wide CI job running Check E against every deploy consumer. Gate 21's
  `requires_source_store: true` confines the automated gate to this repo's own deployed tree;
  cross-repo runs are one-time implementation-phase verification evidence.
- Remediating any other repo's measured drift. Phase 1 records it; fixing it is not this task.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Adding `matcher` to the shared `collect_inventory()` recipe silently changes Check C's or Check D's finding set | H | L | Research confirmed by direct reading that Check C keys only on `identity\|event` and Check D reads only `identity`/`file`. Phase 2 additionally captures Checks A-D's full output before and after the change and asserts it byte-identical, so a behavior change is caught at the phase that introduces it, not later. |
| `--deployed-settings PATH` breaks argument parsing | H | H if unguarded | `lint_corpus_scan_parse_flags` is shared byte-identically across seven lints and treats every unrecognized token as a positional scan path, so the flag would land as a scan path and exit 2 on "scan path not found". Phase 2 strips the flag in a pre-pass in this lint's own body, BEFORE calling the shared parser, leaving the shared library untouched. |
| Criterion 5's drifted-fixture demonstration would require writing a drifted file into the live deployed `.claude/settings.json` | H | H if unguarded | Phase 2 adds `HOOK_REG_DEPLOYED_SETTINGS_OVERRIDE`, mirroring the script's own existing `HOOK_IDENTITY_CLI_OVERRIDE` precedent (introduced for exactly this purpose -- pointing a test at a deliberate fixture "without touching the real bridge file"). Gate 21 passes no flags, so the env var is the only way to drive it at a fixture; the live deployed tree is never mutated. |
| Check E fires on this repo's own deploy the moment it lands, turning Gate 21 red | H | L | Measured at plan time (see Premise Re-Validation): the host deploy is already clean at the `(event, matcher, identity)` grain. Phase 3's verification re-runs the check against the live default path and requires zero findings before the phase closes. |
| Ad hoc runs against other repos report many findings, reading as noise | M | H | Those findings are real -- task 369 measured the `scripts/claude-ready-signal.sh` orphan in 16+ repos, and the bridge resolves it to an identity-eligible path. Phase 1 measures today's actual clean set and records it, so criterion 3's "clean deploy produces zero findings" is evidenced against repos measured clean rather than against a carried, already-refuted figure. |
| A missing deployed-settings file (fresh clone, never deployed) makes Check E error instead of no-op | M | M | Phase 2 mirrors Checks A-D's existing degrade pattern: a missing or unreadable deployed-settings file yields zero findings, never exit 2. Phase 4 pins this with a dedicated case. |
| The nil-identity carve-out is applied after some other Check E logic, so a hand-written hook is reported | H | L | The carve-out is written as the first statement of Check E's per-row loop, before the shape-(b) grouping and before any declared-set comparison, and Phase 4's criterion-2 regression case asserts zero findings for a hand-written command. A lint that reports a user's own hook is worse than no lint. |
| Shape (b) grouping keys on `(event, matcher, identity)` by mistake, making it structurally unable to fire | H | M | Shape (b) groups on `(event, identity)` and inspects the matcher SET within each group -- keying on the matcher would collapse the very distinction being detected. Phase 4's shape-(b) case uses two registrations that are each individually well-formed, so a form-only implementation fails it. |

## Decisions

- **A fifth check inside the existing lint, not a new script.** Directly supported by the
  dispatch's own "Extend the hook-registration lint" framing, and it lets Gate 21's existing
  wiring absorb the new findings with no registry or `verify-deploy.sh` edit.
- **Gate 21 already is "the resulting gate".** Its row's `requires_source_store: true` matches
  Check E's precondition exactly (only the source-store repo holds `agent-system/extensions` and
  the identity bridge side by side), and it already scrapes every `[VIOLATION]` line.
- **Shape-(c) existence resolves against the deployed file's own directory**, never against
  `check_exists()`'s source-store glob. The glob is correct for Checks C/D and would produce a
  false negative on precisely the defect class shape (c) names.
- **Two input mechanisms, not one.** A `--deployed-settings PATH` flag serves ad hoc and
  fixture-driven invocation; `HOOK_REG_DEPLOYED_SETTINGS_OVERRIDE` serves the flagless gate-21
  invocation. The alternative -- writing a drifted fixture into the live `.claude/settings.json` --
  was rejected: it mutates a deployed tree to prove a point about drift.
- **Criterion 1 is met with real-deploy-derived fixtures carrying at most one documented minimal
  mutation each**, with provenance stated per shape. See Premise Re-Validation for why: only shape
  (a) has a surviving live instance, and claiming a live capture for the other two would be false.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is fully sequential: each phase
consumes the previous phase's output directly.

### Phase 1: Live Fleet Drift Baseline and Fixture Provenance [COMPLETED]

**Goal**: Replace every carried field figure with a measurement taken today, using the real
identity bridge rather than a basename approximation, and settle per shape whether its criterion-1
exemplar is a live capture or a documented reconstruction.

**Tasks**:

- [x] Enumerate every deployed tree on this machine carrying a `.claude/settings.json` (start from
      the repos holding a `.claude-extensions.json`, then widen to any other `.claude/settings.json`
      found), and record the enumeration method and the resulting repo list. *(completed: 27 repos
      enumerated)*
- [x] For each enumerated repo, build the `(event, matcher, command)` inventory with the same jq
      `.hooks` walk the lint uses, resolve every command's identity through ONE batched
      `hook_identity_cli.lua` call, and drop nil-identity rows first. *(completed: 681 rows resolved
      in one batched bridge call)*
- [x] Record per repo: shape (a) candidates (triple absent from the source-declared union), shape
      (b) candidates (an `(event, identity)` group with more than one distinct matcher), and shape
      (c) candidates (normalized path absent at `<repo>/.claude/<norm>`). *(completed)*
- [x] Record the set of repos measured clean today -- zero candidates of any shape. This is
      criterion 3's evidence set and supersedes the dispatch's already-refuted "fourteen clean
      repos" figure. *(completed: 14 of 27 measured clean)*
- [x] For each of the three shapes, record either the live instance chosen as its criterion-1
      exemplar, or -- where none survives -- the archived fixture to be copied verbatim, the single
      minimal mutation to be applied, and the verbatim line in
      `specs/archive/369_orphan_sweep_for_removed_merge_target_entries/records/01_baseline-measurements.md`
      that the mutation reproduces. *(completed: (a) and (c) both live, (b) reconstructed)*
- [x] Write all of the above to `specs/527_hook_registration_set_lint_assertion/records/01_live-drift-baseline.md`. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: The phase writes one measurement record under `specs/**` and no executable
surface; `suite_selection_select` returns `__FULL_SWEEP__` for that path, and per plan-format.md's
`__FULL_SWEEP__` sub-case (a) a path entirely under `specs/**` is covered by the `prose` row's
diff read-through, not by `--only-gate 3,4`.

**Scope Hypothesis**: Carried from the dispatch's `MEASURED FIELD INSTANCES` block and from task
369's `records/01_baseline-measurements.md`: that shape (a) survives live in ModelBuilder, that no
live shape (b) or (c) survives anywhere, and that the "fourteen clean repos" figure is refuted.
This phase's own fleet measurement IS the confirmation -- it supersedes all three figures rather
than assuming them, and a surviving live instance found for shape (b) or (c) must be preferred
over this plan's reconstruction path.

**Files to modify**:

- `specs/527_hook_registration_set_lint_assertion/records/01_live-drift-baseline.md` - new: the
  fleet measurement, the measured-clean repo set, and the per-shape fixture provenance decision.

**Verification**:

- The record names every enumerated repo and the enumeration method, so the measurement is
  reproducible rather than asserted.
- Every identity in the record came from the `hook_identity_cli.lua` bridge; no basename
  approximation appears in any finding column.
- Each of the three shapes has a named criterion-1 exemplar, each marked either `live` or
  `reconstructed` with its archived source line quoted.
- Diff read-through confirms every line of the new record is prose or a measurement table.

---

### Phase 2: Matcher-Aware Inventory and Deployed-Settings Input [COMPLETED]

**Goal**: Give the lint a deployed-tree input and a matcher column, with Checks A-D's finding set
provably unchanged -- all the plumbing Check E needs, and none of its finding logic.

**Tasks**:

- [x] Capture the current full `--verbose` output of the lint over the default scan root, as the
      before-baseline for the no-behavior-change assertion below. *(completed)*
- [x] Extend `collect_inventory()`'s jq recipe to also extract `.matcher` (the enclosing block's
      field, read at the `(.value // [])[]` level where it actually lives), and add a parallel
      `ALL_MATCHER` array alongside `ALL_GROUP`/`ALL_FILE`/`ALL_EVENT`/`ALL_TYPE`/`ALL_COMMAND`.
      *(completed)*
- [x] Add a `deployed` group to `collect_inventory`'s `<root|frag>` group argument and call
      `collect_inventory deployed "$DEPLOYED_SETTINGS"` alongside the existing `root`/`frag` calls,
      so the deployed rows are resolved through the SAME single batched
      `resolve_identities_via_bridge` invocation. Do not add a second identity mechanism or a
      second bridge call. *(completed)*
- [x] Add a `--deployed-settings PATH` flag, parsed in a pre-pass inside this lint's own body that
      strips the flag and its value from `"$@"` BEFORE `lint_corpus_scan_parse_flags` is called.
      Leave `scripts/lib/lint-corpus-scan-lib.sh` untouched: that parser is shared byte-identically
      by seven lints and treats any unknown token as a positional scan path. *(completed)*
- [x] Add a `HOOK_REG_DEPLOYED_SETTINGS_OVERRIDE` environment override, documented in the script
      header as mirroring the existing `HOOK_IDENTITY_CLI_OVERRIDE` convention, for the flagless
      gate-21 invocation. Precedence: flag beats env var beats the default. *(completed)*
- [x] Default `DEPLOYED_SETTINGS` to `$PROJECT_ROOT/.claude/settings.json`, never
      `settings.local.json` (D6). A missing, unreadable, or non-JSON file yields zero rows and zero
      findings -- never exit 2 -- mirroring the existing empty-`SETTINGS_FILES` degrade.
      *(completed)*
- [x] Guard the `root`/`frag` groups against the new `deployed` rows: Checks C and D must continue
      to iterate only their own groups, so a deployed row can never enter Check C's
      root-vs-fragment coverage comparison or Check D's source-store existence verdict.
      *(completed)*
- [x] Re-run the captured before-baseline command and assert the output is byte-identical.
      *(completed: diff confirms byte-identical)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-deploy-baseline-lib.sh,test-lint-corpus-scan-lib.sh,test-lint-hook-registration-paths.sh,test-lint-verdict-extraction-anchoring.sh,test-verify-deploy-context-budget.sh`
-- the exact five suites `suite_selection_select` returns for this phase's one file, run at plan
time over that path.

**Files to modify**:

- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` - `ALL_MATCHER`
  array and the `.matcher` jq extraction; a `deployed` inventory group; the
  `--deployed-settings` pre-pass; the `HOOK_REG_DEPLOYED_SETTINGS_OVERRIDE` env override; the
  default-path and missing-file degrade; group guards on Checks C/D; usage-block and
  override-convention header updates.

**Verification**:

- The before/after `--verbose` output over the default scan root is byte-identical: Checks A-D
  report exactly what they reported before.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-lint-corpus-scan-lib.sh,test-lint-hook-registration-paths.sh,test-lint-verdict-extraction-anchoring.sh,test-verify-deploy-context-budget.sh`
  exits 0, and its exit status is checked, not only its output diffed.
- `bash agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh --deployed-settings /nonexistent/settings.json`
  exits 0 with zero findings, demonstrating the degrade.
- `--deployed-settings` does not reach `lint_corpus_scan_parse_flags`: the lint does not emit
  "scan path not found: --deployed-settings", and `git diff` shows
  `scripts/lib/lint-corpus-scan-lib.sh` unmodified.
- Exactly one `resolve_identities_via_bridge` call site remains in the script.

---

### Phase 3: Check E -- Three Distinct Findings with Distinct Remedies [COMPLETED]

**Goal**: Assert the deployed registration SET against the declared union and report shapes (a),
(b) and (c) as three separately-remediable findings, with the carve-out running first.

**Tasks**:

- [x] Build the declared set as `event\x01matcher\x01identity` strings over the `root` and `frag`
      groups' identity-eligible rows, with a code comment naming
      `merge.lua`'s `M.hook_valid_set_key(event, matcher, identity)` as the definition this key
      shape mirrors, so the two cannot silently diverge again. *(completed)*
- [x] Write Check E's per-row loop over the `deployed` group with the nil-identity carve-out as its
      FIRST statement: an empty identity row is skipped unconditionally, before the shape-(b)
      grouping and before any declared-set comparison. *(completed)*
- [x] Shape (b): group the surviving deployed rows by `(event, identity)` -- never by matcher -- and
      report any group whose member matchers are not all identical, naming the event, the identity,
      and every distinct matcher string in the group. Report it independent of declared-set
      membership and independent of each registration's individual form. *(completed)*
- [x] Shape (a)/(c) split: for any surviving deployed row whose `(event, matcher, identity)` triple
      is absent from the declared set, probe `$(dirname "$DEPLOYED_SETTINGS")/<norm>` -- never
      `check_exists()`. Present on disk is shape (a); absent is shape (c). *(completed)*
- [x] Give each shape its own remedy text: (a) remove the stale registration, or correct the merge
      source's declared event/matcher to match; (b) collapse the duplicate blocks to the one matcher
      the source declares, naming the double-fire event; (c) fix the registered path or remove the
      registration -- re-declaring it cannot help, since the file is absent from this deploy target.
      *(completed)*
- [x] Emit every Check E finding with the same `[VIOLATION]` prefix Checks A-D use, so Gate 21's
      existing `verify_deploy_extract_verdict_lines '[VIOLATION]'` scrape captures them unchanged.
      *(completed)*
- [x] Confirm Check E reads only the jq `.hooks` walk: `env`, `permissions`, `statusLine` and
      `mcpServers` are never read, reported, or touched. *(completed)*
- [x] Update the script header: the EXIT-CODE CONTRACT, "THE FOUR CHECKS" (now five), the usage
      block's new flag, and a new numbered design note recording the deploy-target-relative versus
      source-store-relative existence distinction and why `check_exists()` is deliberately not
      reused here. *(completed: D7)*
- [x] Add Check E's own counters to the summary block so a Check E finding is reflected in the
      printed `Total violations` on both the clean and failing paths. *(completed)*

**Timing**: 1.75 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-deploy-baseline-lib.sh,test-lint-corpus-scan-lib.sh,test-lint-hook-registration-paths.sh,test-lint-verdict-extraction-anchoring.sh,test-verify-deploy-context-budget.sh`
-- the same measured five-suite selector output as Phase 2, this phase touching the same one file.

**Files to modify**:

- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` - Check E's declared
  set construction, carve-out-first per-row loop, shape (b) grouping, shape (a)/(c) split and
  deploy-target-relative existence probe, three remedy texts, summary counters, and header updates.

**Verification**:

- Run against the live default deployed path: zero findings, exit 0. This is the measured
  expectation from plan-time probing, and a non-zero result means either real newly-detected drift
  or a false positive -- both must be resolved before the phase closes, not deferred.
- Drive each of the three shapes with the Phase 1 exemplar via `--deployed-settings` and confirm
  three distinguishable finding texts with three distinct remedies.
- A hand-written custom hook command in a deployed fixture produces zero findings.
- A shape-(b) fixture whose two registrations are each individually well-formed still fires, which
  a form-only implementation cannot do.
- `grep` the Check E block for `check_exists` and confirm no call: the existence probe is
  deploy-target-relative.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-lint-corpus-scan-lib.sh,test-lint-hook-registration-paths.sh,test-lint-verdict-extraction-anchoring.sh,test-verify-deploy-context-budget.sh`
  exits 0, exit status checked.

---

### Phase 4: Fixture Regression Suite [COMPLETED]

**Goal**: Pin every acceptance criterion as a regression case in the existing both-polarity
fixture suite, following its established scratch-`WORKDIR` idiom.

**Tasks**:

- [x] Add a failing case per shape -- (a), (b), (c) -- each built from the Phase 1 exemplar: copy
      the real deployed `settings.json` verbatim into the scratch `WORKDIR`, apply the one
      documented mutation where the record says the shape was reconstructed, and assert exit 1 plus
      a `grep` for that shape's own distinct finding text. For shape (c), also plant the companion
      `hooks/` directory with the other scripts present and the cited one deliberately absent --
      the settings fixtures alone do not encode deploy-target filesystem state. *(completed: cases
      19 (a, ModelBuilder), 20 (b, reconstructed Logos/Theory + mutation), 21 (c, SPSDemo))*
- [x] Add a passing case for criterion 2: a hand-written custom hook command -- not recognizable as
      a source-store hook invocation -- survives with zero findings. This is the dedicated
      regression case the criterion names, carrying a comment stating that a lint reporting a user's
      own hook is worse than no lint. *(completed: case 22)*
- [x] Add a passing case for criterion 3: copies of the deployed `settings.json` from repos the
      Phase 1 record measured clean, each producing zero findings. *(completed: case 23a/23b,
      protocol and theorem_proving_in_lean4)*
- [x] Add a case for criterion 4: a deployed registration whose path lies OUTSIDE `hooks/` yields
      the same identity in Check E as the shared bridge does, asserting Check E specifically -- the
      existing Case 16 asserts this for Checks C/D only. *(completed: case 24)*
- [x] Add a passing case for the missing-deployed-settings degrade: a path that does not exist
      yields zero findings and exit 0, never exit 2. *(completed: case 25)*
- [x] Number the new cases contiguously after the existing ones and keep each case's
      `pass()`/`fail()`/`info()` shape, `common_test_resolve_subject` resolution, and scratch
      `WORKDIR` teardown identical to the suite's existing cases. Plant no committed fixture files.
      *(completed: cases numbered 19-25 after the pre-existing 1-18; `git status --short` confirms
      no new committed fixture files)*
- [x] Confirm every pre-existing case still passes unchanged. *(completed: all 18 pre-existing
      cases pass unchanged under `CORE_TEST_SUBJECT_MODE=source-store`, the mode needed to resolve
      this phase's as-yet-undeployed source-store edit -- see Deviations)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-lint-hook-registration-paths.sh,test-lint-verdict-extraction-anchoring.sh` -- the exact two
suites `suite_selection_select` returns for this phase's one file, run at plan time over that path.

**Scope Hypothesis**: The suite currently holds 18 cases (`grep -n '^# Case'` over
`test-lint-hook-registration-paths.sh` at plan time), so the new cases are expected to number 19
onward. Confirm by re-running that same enumeration before numbering, since a sibling task may
have added a case; the contiguity requirement is on the numbering as found, not on the figure 18.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` - new cases
  for shapes (a), (b) and (c), the hand-written-hook carve-out, the measured-clean-repo zero-finding
  case, Check E identity agreement outside `hooks/`, and the missing-file degrade.

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` exits 0
  with every case reported PASS, including all pre-existing cases.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-hook-registration-paths.sh,test-lint-verdict-extraction-anchoring.sh`
  exits 0, exit status checked.
- Each new failing case's assertion greps that shape's OWN finding text, so a single
  undifferentiated message cannot satisfy all three -- the criterion-1 distinctness requirement is
  enforced by the assertions, not by inspection.
- `git status --short` shows no committed fixture files added under the tests directory.

---

### Phase 5: Gate Wiring Confirmation and Boundary Note [NOT STARTED]

**Goal**: Demonstrate that Gate 21 already is the resulting gate, with no `verify-deploy.sh` or
`gate-registry.data` edit, and record the existence-boundary distinction where a future lint in
this cluster will look for it.

**Tasks**:

- [ ] Run `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 21 <repo_root>`
      (`<repo_root>` being the directory holding `.claude-extensions.json`) and confirm gate 21
      passes against live state.
- [ ] Re-run the same invocation with `HOOK_REG_DEPLOYED_SETTINGS_OVERRIDE` pointed at the Phase 1
      drifted exemplar and confirm gate 21 FAILS, that `--findings` captures the Check E
      `[VIOLATION]` lines into `FINDINGS_LIST` tagged `gate21`, and that the live
      `.claude/settings.json` was never written to.
- [ ] Confirm by `git diff` that `agent-system/extensions/core/scripts/verify-deploy.sh` and
      `agent-system/extensions/core/scripts/gate-registry.data` are both unmodified -- the
      "no new gate" decision holds in fact, not only in intent.
- [ ] Add a short subsection to
      `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md`
      covering the source-store-relative versus deploy-target-relative existence distinction: what
      `check_exists()`'s glob correctly answers, what a deploy-target probe answers, and why reusing
      the former for a deployed-tree audit is a false negative. Cite the lint and the check by
      durable name, never by task number or line number.
- [ ] Note in that subsection that the two questions are independent axes, so a script can be fully
      present and correctly declared in the source store while absent from one deploy target's own
      filesystem.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns the sentinel `__FULL_SWEEP__` for this
phase's two paths together, so no suite covers them; per plan-format.md's `__FULL_SWEEP__`
sub-case (b) the covering check for a source-store non-`specs/**` markdown edit is
`bash <repo_root>/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>`.

**Scope Hypothesis**: Carried from the research report: that Gate 21 absorbs Check E's findings
with zero changes to `verify-deploy.sh` and `gate-registry.data`. Confirmed at implementation time
by this phase's own drifted-fixture run plus the `git diff` check above; if either file turns out
to need an edit, that is a finding to record and act on, not a deviation to absorb silently.

**Files to modify**:

- `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md` - new
  subsection on the source-store-relative versus deploy-target-relative existence distinction.
- `agent-system/extensions/core/index-entries.json` - this file's own `line_count` entry for the
  narrative above (171 at plan time, matching the file on disk) moves with the edit. The check that
  detects the drift (`check-extension-docs.sh` Rule R) is not commit-blocking in this repository,
  so the regeneration itself lands in Phase 6's deploy; the declaration is owed here, in the phase
  that moves the quantity.

**Verification**:

- Gate 21 passes against live state and FAILS against the drifted exemplar, with the failing run's
  exit status checked, not only its output inspected.
- The failing run's `[VIOLATION]` lines appear in `FINDINGS_LIST` tagged `gate21`.
- `git diff` on `verify-deploy.sh` and `gate-registry.data` is empty.
- `git diff` on `.claude/settings.json` is empty: the demonstration mutated no deployed tree.
- `bash <repo_root>/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>`
  exits 0, exit status checked, with neither selected gate SKIPping.
- Diff read-through confirms the new subsection contains no task-number reference and no
  record-versioning language.

---

### Phase 6: Redeploy and Full Gate Battery [NOT STARTED]

**Goal**: Land the change in every deployed tree this loader serves and discharge the complete gate
set, including acceptance criterion 6.

**Tasks**:

- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` and require
      `RESULT=landed_verify_clean`, as the dispatch mandates. A different RESULT is a blocker to
      report, never a result to accept.
- [ ] Confirm the deploy regenerated `index-entries.json`'s `line_count` for the Phase 5 narrative
      edit, reconciling the coupled surface declared there.
- [ ] Run the complete gate set: `bash agent-system/extensions/core/scripts/verify-deploy.sh`
      (no gate filter, no `--skip-slow`), and require a clean verdict.
- [ ] Run the full shell suite: `bash agent-system/extensions/core/scripts/tests/run-all.sh`, and
      require exit 0 -- criterion 6's "pre-existing lint and verify-deploy tests still pass". A
      newly red pre-existing test is treated as caused by this task and fixed here, not reported as
      pre-existing.
- [ ] Confirm the deployed copy of the lint carries Check E and that Gate 21 runs it from the
      deployed path as well as the source-store path.
- [ ] Write the completion summary, stating per shape whether its criterion-1 exemplar was found
      live or reconstructed, and naming the reconstruction source for each reconstructed one.

**Timing**: 1.25 hours

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`, an
  implicit scope claim over the entire deployed tree that no real declared path can express.

**Verification**:

- `deploy-headless.sh` reports `RESULT=landed_verify_clean`.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh` -- the complete gate set this
  repository aggregates, unfiltered -- exits 0, exit status checked.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0 with every suite passing.
- `git diff` on `index-entries.json` shows only the regenerated `line_count` for the Phase 5
  narrative edit.
- The deployed `.claude/scripts/lint/lint-hook-registration-paths.sh` contains Check E.
- The summary states each shape's exemplar provenance explicitly.

---

## Testing & Validation

- [ ] Shapes (a), (b) and (c) each produce a distinct finding with its own remedy text, asserted by
      three separate regression cases that each grep that shape's own message (criterion 1).
- [ ] Each shape's criterion-1 exemplar derives from a verbatim copy of a real deployed
      `settings.json`, with provenance recorded per shape as `live` or `reconstructed` plus source
      (criterion 1).
- [ ] A hand-written custom hook command survives with zero findings, pinned by a dedicated
      regression case (criterion 2).
- [ ] Copies of the deployed `settings.json` from repos measured clean in Phase 1 produce zero
      findings (criterion 3).
- [ ] Check E's identity comes from `hook_identity_cli.lua`, keyed as `merge.lua`'s
      `M.hook_valid_set_key` is, with a case asserting agreement on a path outside `hooks/`
      (criterion 4).
- [ ] Gate 21 fails on the drifted exemplar with no edit to `verify-deploy.sh` or
      `gate-registry.data` (criterion 5).
- [ ] `run-all.sh` and the unfiltered `verify-deploy.sh` both pass; any newly red pre-existing test
      is fixed within this task (criterion 6).
- [ ] Checks A-D's `--verbose` output over the default scan root is byte-identical to the
      pre-change baseline.
- [ ] A missing deployed-settings file yields zero findings and exit 0.
- [ ] `env`, `permissions`, `statusLine` and `mcpServers` are never read or reported by Check E.
- [ ] `scripts/lib/lint-corpus-scan-lib.sh` is unmodified.
- [ ] `deploy-headless.sh` reports `RESULT=landed_verify_clean`.

## Artifacts & Outputs

- `specs/527_hook_registration_set_lint_assertion/records/01_live-drift-baseline.md` - the fleet
  drift measurement, the measured-clean repo set, and the per-shape fixture provenance decision.
- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` - Check E, the
  matcher-aware inventory, the deployed-settings input and override, and the header updates.
- `agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` - the new
  regression cases covering acceptance criteria 1 through 4 plus the degrade case.
- `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md` - the
  existence-boundary subsection.
- `agent-system/extensions/core/index-entries.json` - regenerated `line_count` for the file above.
- A regenerated deployed tree in every repo this loader serves.
- `specs/527_hook_registration_set_lint_assertion/summaries/01_hook-registration-set-lint-summary.md`
  - the completion summary, including per-shape exemplar provenance.

## Rollback/Contingency

Every phase is a scoped, commit-per-green-substep edit to at most two files, so the ordinary
remedy is to fix forward -- correct the source until the phase's own verification passes -- never
to discard uncommitted work to reach a passing gate.

- **Checks A-D's output changes in Phase 2.** Revert the `matcher` column addition only, keeping the
  deployed-settings plumbing, and re-derive which of Check C or Check D depended on the row shape
  before reattempting.
- **Check E fires on the live deploy in Phase 3.** Determine first whether it is real newly-detected
  drift or a false positive. Real drift is a finding to record and, if it originates in the source
  store, to fix; a false positive blocks the phase until the predicate is corrected. Do not silence
  the check to make the phase close.
- **`deploy-headless.sh` does not reach `RESULT=landed_verify_clean` in Phase 6.** Report it as a
  blocker with the actual RESULT and the failing gate; the deployed trees stay on the previous
  generation until it is resolved.
- **A genuine whole-tree rollback becomes necessary.** Use the snapshot-then-rollback recipe in
  `context/contracts/recovery.md`'s rollback rung, including its out-of-scope override flag for the
  deliberate whole-tree case. Do not emit a bare reverting snapshot call as a routine
  start-of-phase precaution; an ordinary defensive checkpoint uses `git-snapshot.sh --no-revert`.

Three sibling tasks (635, 636, 627) are scheduled for plan dispatch this same cycle on this shared
working tree, none with a declared `file_scope`. Before editing or committing any file, re-read it
immediately beforehand, stage only this task's own hunks with an explicit file list, and treat an
unexpected failure outside this plan's declared files as possibly a sibling's in-flight edit rather
than necessarily a regression of this task's own.
