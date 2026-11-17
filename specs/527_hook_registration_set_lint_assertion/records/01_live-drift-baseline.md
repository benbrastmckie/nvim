# Live Fleet Drift Baseline and Fixture Provenance

Measured 2026-11-17, superseding every carried field figure in the dispatch and in the plan's own
Premise Re-Validation table with a fresh measurement taken today against the real identity
bridge.

## Enumeration Method

Two passes, per the task's instruction to "start from the repos holding a `.claude-extensions.json`,
then widen to any other `.claude/settings.json` found":

1. `find ~ -maxdepth 4 -name ".claude-extensions.json"` — 23 repos.
2. `find ~ -maxdepth 5 -path "*/.claude/settings.json"` — 28 paths, minus the user-global
   `~/.claude/settings.json` (not a project deploy target), yielding 27 unique deployed trees;
   together with pass 1 this is a strict superset (every `.claude-extensions.json` repo also
   carries a deployed `.claude/settings.json`).

The resulting 27-repo enumeration (repo-root paths, `~` expanded):

`~/.config/nvim`, `~/.dotfiles`, `~/.config/zed`, `~/Mail`, `~/Projects/Sapience/sapience-pitch`,
`~/Projects/Logos/ModelChecker`, `~/Philosophy/Papers/PossibleWorlds`, `~/Projects/ModelBuilder`,
`~/Projects/protocol`, `~/Projects/Literature`, `~/Projects/BimodalLogic`, `~/Projects/SPSDemo`,
`~/Projects/cslib`, `~/Projects/PersonalWebsite`, `~/Projects/ModelChecker`,
`~/Projects/BimodalHarness`, `~/Projects/theorem_proving_in_lean4`, `~/Projects/abood`,
`~/Projects/Sapience/sf1-engine`, `~/Projects/Logos/Verification`, `~/Projects/Logos/Theory`,
`~/Projects/Logos/Vision`, `~/Projects/Logos/Hardware`,
`~/Projects/Logos/gate-worktree-e18ce9353734`, `~/Projects/Logos/Website`,
`~/Projects/Sapience/sapience-app`, `~/Documents/Personal/Wedding`,
`~/Documents/Employment/Applications`.

## Measurement Method

For each repo's `.claude/settings.json`, and for the source store's own `root-files/settings.json`
plus every `settings-hooks.json`/`settings-fragment.json` under `agent-system/extensions/*`, the
same `(.hooks // {}) | to_entries[] | .key as $event | (.value // [])[] | (.matcher // "") as
$matcher | ((.hooks // [])[] // {}) | [...]` jq walk `collect_inventory()` uses was run to build an
`(event, matcher, type, command)` row set. Every row's `(type, command)` pair across every repo and
every source surface was resolved through exactly ONE batched
`lua/neotex/plugins/ai/shared/extensions/hook_identity_cli.lua` invocation (681 input lines in,
681 output lines out, in order) -- the same bridge Check E will call, never a basename
approximation. Nil-identity rows were dropped first (the mandatory carve-out).

The declared set is the union of the root-files and fragment rows' `(event, matcher, identity)`
triples (29 identity-eligible declared rows). For each repo's deployed rows: shape (b) candidates
are `(event, identity)` groups with more than one distinct matcher string within that repo's OWN
deployed file; shape (a)/(c) candidates are deployed triples absent from the declared set, split by
whether `<repo>/.claude/<normalized-path>` exists on disk (present = (a), absent = (c)).

## Measured-Clean Repo Set (criterion 3 evidence)

**14 of 27** enumerated repos are clean today -- zero candidates of any shape:

`~/.config/nvim` (host), `~/.dotfiles`, `~/Projects/BimodalLogic`, `~/Projects/Logos/Theory`,
`~/Projects/Logos/Verification`, `~/Projects/Logos/Vision`, `~/Projects/Logos/Website`,
`~/Projects/Logos/gate-worktree-e18ce9353734`, `~/Projects/Sapience/sapience-app`,
`~/Projects/Sapience/sapience-pitch`, `~/Projects/Sapience/sf1-engine`, `~/Projects/abood`,
`~/Projects/protocol`, `~/Projects/theorem_proving_in_lean4`.

This **supersedes** the dispatch's already-refuted "fourteen clean repos" figure (the dispatch's
own fourteen were never this set; see the re-validation below) and the plan's own carried "zero
live shape-(c) instances" sub-claim for `theorem_proving_in_lean4` specifically, which this fresh
measurement **confirms holds today**: that repo's deployed `SessionStart` block now reads
`"$CLAUDE_PROJECT_DIR"`-prefixed throughout with no `claude-ready-signal.sh` registration at all,
and no missing-file registration either -- it has evidently been resynced since the task-369
baseline capture.

## Measured-Drifted Repos (13 of 27)

**Shape (a)** -- live, multiple instances:
- `~/Projects/ModelBuilder`: `Stop|* -> hooks/tts-notify.sh`, `Stop|* -> hooks/wezterm-notify.sh`,
  `UserPromptSubmit|* -> hooks/wezterm-clear-status.sh`,
  `Notification|permission_prompt|idle_prompt|elicitation_dialog -> hooks/tts-notify.sh` (source
  now declares `tts-notify.sh` only under the narrower `permission_prompt|elicitation_dialog`
  matcher for `Notification`) -- all four files are PRESENT on disk at
  `~/Projects/ModelBuilder/.claude/hooks/`.
- `~/Projects/cslib`: `PostToolUse|Write|Edit -> hooks/validate-no-task-references.sh` (source
  declares this identity only under `PreToolUse|Write|Edit`) -- file present.
- `~/Projects/Logos/Hardware`: same `PostToolUse|Write|Edit -> hooks/validate-no-task-references.sh`
  cross-event instance as cslib -- file present.

**Shape (b)** -- **zero live instances found**, confirming the plan's Premise Re-Validation
("Logos/Theory ... DOES NOT HOLD, and no substitute exists"). No repo's own deployed settings.json
carries two matcher blocks for the same `(event, identity)` pair today.

**Shape (c)** -- live, widespread (the `scripts/claude-ready-signal.sh` orphan from task 369's
baseline, still CWD-relative and un-resynced in every "unmanaged" repo and several "managed" ones
that have not had a resync since task 369 landed): `~/.config/zed`,
`~/Documents/Employment/Applications`, `~/Documents/Personal/Wedding`, `~/Mail`,
`~/Philosophy/Papers/PossibleWorlds`, `~/Projects/BimodalHarness`, `~/Projects/Literature`,
`~/Projects/Logos/Hardware` (also shape (a) above), `~/Projects/Logos/ModelChecker`,
`~/Projects/ModelChecker`, `~/Projects/PersonalWebsite`, `~/Projects/SPSDemo`, `~/Projects/cslib`
(also shape (a) above). Every instance resolves to the SAME triple:
`SessionStart|startup -> command:scripts/claude-ready-signal.sh`, absent at
`<repo>/.claude/scripts/claude-ready-signal.sh` in every case (the correct `~/`-anchored form,
`bash ~/.config/nvim/scripts/claude-ready-signal.sh`, is nil-identity and never a candidate at
all -- confirmed directly in `~/Projects/ModelBuilder/.claude/settings.json`, which carries BOTH
the correct `~/`-anchored registration (exempt) and the undeclared orphans above side by side).

## Carried-Figure Re-Validation

The dispatch's "fourteen other deployed repos are clean" claim was **already refuted** by task
369's own archived baseline record
(`specs/archive/369_orphan_sweep_for_removed_merge_target_entries/records/01_baseline-measurements.md`,
"Carried-Figure Re-Validation" section, lines 90-118), which found the `claude-ready-signal.sh`
orphan in at least sixteen further repos beyond its five named targets. This phase's fresh
measurement **confirms the refutation and supersedes the carried figure outright** with the
measured-clean set above (14 of 27, not the dispatch's unverified fourteen) -- the two sets
partially overlap (`protocol`, `Logos/Verification`, `Logos/gate-worktree-e18ce9353734` appear in
both) but are not the same set, since several repos the task-369 baseline measured clean (e.g.
the four managed repos noted there) have since drifted further or were never in its clean-set
discussion at all.

The plan's own narrower per-shape re-validation is also confirmed: `ModelBuilder` is genuinely
drifted and supplies shape (a) only (never shape (c) -- all four invoked scripts are present on
disk); the `Logos/Theory` shape-(b) duplicate-matcher defect does not survive live anywhere; and
`theorem_proving_in_lean4`'s task-369-cited shape-(c) pair
(`claude-stop-notify.sh`/`wezterm-preflight-status.sh`) does not survive either -- that repo is
now wholly clean, including of the `claude-ready-signal.sh` orphan the task-369 baseline also
named it for.

## Per-Shape Criterion-1 Exemplar Decision

| Shape | Provenance | Exemplar | Citation |
|---|---|---|---|
| (a) | **live** | `~/Projects/ModelBuilder/.claude/settings.json`, verbatim copy, specifically its `Stop|* -> hooks/wezterm-notify.sh` registration (undeclared anywhere, file present on disk) | This record's "Measured-Drifted Repos" section above, confirmed live 2026-11-17; also task-369 baseline record lines 66-73 |
| (b) | **reconstructed** | Copy `~/Projects/Logos/Theory/.claude/settings.json` verbatim (its current single `Notification|permission_prompt|elicitation_dialog -> hooks/tts-notify.sh` block, per the plan's Premise Re-Validation table), then add ONE minimal second `Notification` matcher block, `permission_prompt\|idle_prompt\|elicitation_dialog`, also registering `tts-notify.sh` -- reproducing the exact matcher pair task 369's own archived baseline record states verbatim at line 70-71: "`Notification\|permission_prompt\|idle_prompt\|elicitation_dialog` → `tts-notify.sh` (the cross-matcher case — source now declares `tts-notify.sh` only under the narrower `permission_prompt\|elicitation_dialog`)" | `specs/archive/369_orphan_sweep_for_removed_merge_target_entries/records/01_baseline-measurements.md` lines 70-71 |
| (c) | **live** | `~/Projects/SPSDemo/.claude/settings.json`, verbatim copy, plus a verbatim copy of its real `.claude/hooks/` directory listing (which has no `claude-ready-signal.sh` entry at all, under either `hooks/` or `scripts/`) -- its `SessionStart|startup -> scripts/claude-ready-signal.sh` registration is undeclared anywhere AND the file is absent on disk | This record's "Measured-Drifted Repos" section above, confirmed live 2026-11-17; `SPSDemo` is also explicitly named in task-369's archived baseline "sixteen further repos" list |

No live shape-(b) instance survives anywhere in the 27-repo fleet, so shape (b)'s exemplar is the
only one of the three built by documented, minimal, cited mutation rather than live capture; shapes
(a) and (c) are both live captures requiring no mutation at all.

## Hand-Written-Hook Carve-Out Exemplar (criterion 2, non-shape)

No mutation or live-capture provenance obligation applies here (criterion 2 names no
real-deploy-derivation requirement), but a real live instance of a nil-identity command exists
anyway: `~/Projects/ModelBuilder/.claude/settings.json`'s own `PreToolUse|Write` block, a `bash -c
'...'` snippet containing no `*.sh` invocation at all (an inline `permissionDecision` echo). It
resolves to an empty identity via the bridge and will be used, or a structurally equivalent
synthetic one, as Phase 4's dedicated carve-out regression case.
