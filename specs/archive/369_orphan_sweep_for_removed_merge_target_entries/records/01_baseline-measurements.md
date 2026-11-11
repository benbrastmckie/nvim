# Baseline Measurements: Orphan Hook Registrations

Captured at implementation time via a direct filesystem scan and the `jq` recipe below (no new
permanent script added; this recipe is the acceptance-criterion-4 measurement contract).

## Enumeration Method

`find ~/Projects ~/Philosophy ~/.config/nvim ~/.dotfiles ~/Documents ~/Training -maxdepth 5 -type d -name .claude -not -path '*/.local/*' -not -path '/tmp/*'` found 27 deployed repos. The
extension repo registry (`~/.local/share/nvim/neotex-ai/extension-repo-registry.json`) was
rejected as the enumeration source: at measurement time it held mostly ephemeral `/tmp` test
fixture entries alongside the small number of real repositories, so a filesystem scan of the
real project trees is the only reliable source for the affected-and-control repo sets.

**Managed** (carries `.claude-extensions.json`, so an ordinary `[Reload All]`/resync acts on it
directly): `~/.config/nvim`, `~/.dotfiles`, `~/Projects/BimodalLogic`, `~/Projects/BimodalHarness`,
`~/Projects/ModelChecker`, `~/Projects/PersonalWebsite`, `~/Projects/cslib`,
`~/Projects/SPSDemo`, `~/Philosophy/Papers/PossibleWorlds`, `~/Documents/Employment/Applications`,
`~/Projects/Logos/Theory`, `~/Projects/Logos/Verification`, `~/Projects/Logos/Hardware`,
`~/Projects/Logos/ModelChecker`, `~/Projects/Logos/gate-worktree-e18ce9353734`,
`~/Projects/Logos/Vision`, `~/Documents/Personal/Wedding`.

**Unmanaged** (deployed `.claude/` with no `.claude-extensions.json` — a sweep fired only by a
Phase-5 fail-safe decision, since the loaded-extension-list-derived valid set is empty for these):
`~/Training` (no `.claude/settings.json` present), `~/Projects/protocol`,
`~/Projects/ModelBuilder`, `~/Projects/Literature`, `~/Projects/VSCodium` (no settings.json),
`~/Projects/theorem_proving_in_lean4`, `~/Philosophy/Teaching/LogicNotes` (no settings.json),
`~/Philosophy/Papers/ProgrammaticSemantics` (no settings.json), `~/Projects/Logos/Website`,
`~/Training/z3/nice_connectives` (no settings.json), `~/Projects/Repos/provability-fabric` (no
settings.json), `~/Philosophy/Teaching/MIT/Logic/ForAllX` (no settings.json).

## Measurement Recipe

```bash
# registration count
jq '[(.hooks // {}) | to_entries[] | .value[] | (.hooks // [])[]] | length' .claude/settings.json
# total duplicate-registration count (same event|type|command tuple appearing >1x anywhere)
jq -r '(.hooks // {}) | [to_entries[] | .key as $e | .value[] | .matcher as $m | (.hooks//[])[] |
  "\($e)|\(.type)|\(.command)"] | group_by(.) | map(select(length > 1)) | length' .claude/settings.json
# env/permissions fingerprint
jq -S '{env, permissions}' .claude/settings.json | sha256sum
```

## Named-Target Before-State

| Repo | Managed | Registration count | Duplicate count | env/permissions fingerprint |
|------|---------|--------------------:|-----------------:|------------------------------|
| `~/.config/nvim` (host) | yes | 28 | 0 | `bda8ce82960141f4a93a3c24648589c0d0dc2e2a1619c6eee595d82875460629` |
| `~/Projects/ModelBuilder` | no | 12 | 0 | `77a2960a51661f3d5831d2b5e52dff6e4f599f102793c56b08c69b2ae9eda386` |
| `~/Projects/Logos/Website` | no | 12 | 0 | `8eec0ea2943900920676e794f7015421737e16d1773e922e8d2c23874bcaac3a` |
| `~/Projects/Logos/Theory` | yes | 30 | 0 | `77a2960a51661f3d5831d2b5e52dff6e4f599f102793c56b08c69b2ae9eda386` |
| `~/Projects/theorem_proving_in_lean4` | no | 13 | 0 | `8eec0ea2943900920676e794f7015421737e16d1773e922e8d2c23874bcaac3a` |

These five counts (28, 12, 12, 30, 13) match the plan's Scope Hypothesis exactly, confirming the
research report's field table was not stale. The duplicate count is 0 for all five today: the
Logos/Theory `Notification`/`Stop` duplicate-matcher-block defect the dispatch described as a
second live instance was indeed hand-repaired on 2026-11-07 as the dispatch states — but the
repair was NOT complete, per the orphan commands found below.

Fixtures (verbatim copies): `records/fixtures/{host,modelbuilder,logos-theory,logos-website,lean4}-settings.json`.

## Orphan Commands Observed (named targets)

- **host** (`~/.config/nvim`): `SessionStart|startup` → `bash scripts/claude-ready-signal.sh 2>/dev/null || echo '{}'`.
  CWD-relative, not `~/`-anchored, no `.claude/` in it at all. Undeclared by any fragment or
  root-files — the live instance cited in the task description.
- **ModelBuilder**: `Stop|*` → `bash .claude/hooks/wezterm-notify.sh ...` (undeclared — the
  source never registers `wezterm-notify.sh` directly; it is invoked indirectly, from inside
  `claude-stop-notify.sh`); `UserPromptSubmit|*` → `bash .claude/hooks/wezterm-clear-status.sh ...`
  (fully dead — no such script exists anywhere in the source store; superseded by
  `wezterm-clear-task-number.sh`); `Notification|permission_prompt|idle_prompt|elicitation_dialog`
  → `tts-notify.sh` (the cross-matcher case — source now declares `tts-notify.sh` only under the
  narrower `permission_prompt|elicitation_dialog`). `SessionStart|startup` carries the
  `~/`-anchored `claude-ready-signal.sh` form, which MUST survive (carve-out).
- **Logos/Website**: identical three-orphan shape to ModelBuilder (`wezterm-notify.sh` under
  `Stop|*`, `wezterm-clear-status.sh` under `UserPromptSubmit|*`, the widened Notification
  matcher for `tts-notify.sh`), plus the same surviving `~/`-anchored `claude-ready-signal.sh`.
- **Logos/Theory**: `PostToolUse|Write|Edit` → `bash .claude/hooks/validate-no-task-references.sh ...`
  (the cross-EVENT case — source declares this hook only under `PreToolUse|Write|Edit`);
  `UserPromptSubmit|*` → `bash .claude/hooks/wezterm-clear-status.sh ...` (same dead script as
  ModelBuilder/Website). The Notification/Stop duplicate-block defect is gone (hand-repaired), and
  the `~/`-anchored `claude-ready-signal.sh` form correctly survives.
- **theorem_proving_in_lean4**: `SessionStart|startup` → `bash scripts/claude-ready-signal.sh ...`,
  the same CWD-relative, non-`~/`-anchored orphan as the host. Also carries live (non-orphaned,
  source-declared) registrations of `claude-stop-notify.sh` and `wezterm-preflight-status.sh`
  whose underlying script files the dispatch describes as absent on disk in that repo — that is a
  missing-file deployment defect, not an orphan-registration defect (the registration IS
  source-declared), and is explicitly out of this task's scope: the sweep's job is "does the
  source still declare this identity", never "does the script file exist".

## Carried-Figure Re-Validation: the "fourteen clean repos" claim does not hold

The task description's claim that "fourteen other deployed repos are already clean and serve as
the no-change control set" was checked directly against live state rather than carried forward
unverified, per this dispatch's Premise Re-Validation obligation. **It does not hold.** A scan of
every other reachable managed-or-unmanaged repo for the three known orphan signatures
(`claude-ready-signal.sh`, `wezterm-notify.sh`/`wezterm-clear-status.sh`, and the widened
`idle_prompt` Notification matcher) found the CWD-relative, non-`~/`-anchored
`bash scripts/claude-ready-signal.sh` orphan present in at least sixteen repos beyond the five
named targets: `~/.dotfiles`, `~/Projects/BimodalLogic`, `~/Projects/Literature`,
`~/Projects/BimodalHarness`, `~/Projects/ModelChecker`, `~/Projects/PersonalWebsite`,
`~/Projects/cslib`, `~/Projects/SPSDemo`, `~/Philosophy/Papers/PossibleWorlds`,
`~/Documents/Employment/Applications`, `~/Projects/Logos/Hardware`,
`~/Projects/Logos/ModelChecker`, `~/Projects/Logos/Vision`, `~/Documents/Personal/Wedding` (14
of these), plus the already-named `theorem_proving_in_lean4` and host. This script was apparently
registered CWD-relative (rather than `~/`-anchored) broadly across every repo that loaded the
`nvim` extension's merge-sources fragment at some point before the registration was narrowed to
the `~/`-anchored form (or removed from the merge source entirely) — the orphan is therefore a
systemic, not localized, consequence of exactly the mechanism this task closes, not a five-repo
anomaly. This is recorded here as the honest premise re-validation result (see
`.claude/scripts/issue-record.sh` entry filed against this dispatch) rather than silently carried
forward; it does not change this task's mechanism (repo-agnostic identity and sweep), only the
size of the affected-deploy set Phase 6 must account for. `~/Projects/Logos/Verification`,
`~/Projects/Logos/gate-worktree-e18ce9353734`, `~/Projects/protocol`, and
`~/Projects/Repos/provability-fabric` were checked and found clean of all three signatures and
remain genuine no-change control-set members, alongside every repo with no deployed
`.claude/settings.json` at all (`~/Training`, `~/Projects/VSCodium`,
`~/Philosophy/Teaching/LogicNotes`, `~/Philosophy/Papers/ProgrammaticSemantics`,
`~/Training/z3/nice_connectives`).

## Scope Note for Phase 6

Phase 6 measures the five named targets before/after in full (registration count, duplicate
count, fingerprint) since those are this task's explicit remediation targets and carry the fixture
corpus. The wider 14-plus-repo CWD-relative-orphan population above is corrected by the same
mechanism whenever each of those repos' own owner next runs `[Reload All]`/a resync in this
Neovim configuration — this task does not reach into every one of those repos to force that resync
as part of its own acceptance criteria, which name the five targets specifically. Where Phase 6
below applies the sweep to one of the wider-population repos directly (as a secondary, non-blocking
spot check) it is called out explicitly as such.
