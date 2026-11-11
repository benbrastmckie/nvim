# After Measurements: Orphan Hook Registration Sweep

Measured with the same recipe as `records/01_baseline-measurements.md`, after exercising the
sweep via an ordinary resync (`bash agent-system/extensions/core/scripts/deploy-headless.sh
--skip-verify TARGET_REPO`) against four of the five named targets (Logos/Theory, Logos/Website,
theorem_proving_in_lean4, and — during Phase 7's own verification pass, which required a fresh
redeploy anyway — the host), and via a scratch-directory replay of the real field fixture for
the fifth (ModelBuilder — see "Deferred to a scratch replay" below for why).

## Host — Live Redeploy Result

`timeout 540 bash .claude/scripts/deploy-headless.sh --skip-verify` (resynced 9 extensions) was
run against this repo's own live `.claude/settings.json` directly, superseding the scratch-only
demonstration this section originally planned (see "Dry-Run Replay" below, which still stands as
the pre-redeploy prediction): registration count 28 → 27, 0 per-event duplicates, the
`env`/`permissions` fingerprint byte-identical
(`bda8ce82960141f4a93a3c24648589c0d0dc2e2a1619c6eee595d82875460629`), and
`grep -c claude-ready-signal .claude/settings.json` is 0 — the orphan this task's description
cited by line number is gone from the live file.

## Dry-Run Replay (scratch directory, real field fixtures, before touching any live repo)

Every named target was first replayed against its verbatim Phase 1 fixture in a scratch
directory (`manager.load("core", {project_dir=scratch, force=false})` once to seed state, then
again with `force=true` to exercise the resync+sweep), confirming the mechanism's behavior
before any live file was touched:

| Target | Before count | After count | Dup after | Fingerprint match | Orphan(s) removed | Carve-out survivor present |
|--------|-------------:|------------:|----------:|:------------------:|--------------------|------------------------------|
| host | 28 | 27 | 0 | yes (`bda8ce82...`) | `scripts/claude-ready-signal.sh` (CWD-relative) | n/a (no `~/`-anchored form in this fixture) |
| ModelBuilder | 12 | 28 | 0 | yes (`77a2960a...`) | `wezterm-notify.sh` (Stop), `wezterm-clear-status.sh` (UserPromptSubmit), `tts-notify.sh` (widened Notification matcher) | yes — `~/.config/nvim/scripts/claude-ready-signal.sh` |
| Logos/Website | 12 | 28 | 0 | yes (`8eec0ea2...`) | same three as ModelBuilder | yes |
| Logos/Theory | 30 | 28 | 0 | yes (`77a2960a...`) | `wezterm-clear-status.sh`, `validate-no-task-references.sh` (cross-event PostToolUse duplicate) | yes |
| theorem_proving_in_lean4 | 13 | 27 | 0 | yes (`8eec0ea2...`) | `scripts/claude-ready-signal.sh` (CWD-relative) | n/a (no `~/`-anchored form in this fixture) |

The large count INCREASES for ModelBuilder/Logos-Website/lean4 (12→28, 12→28, 13→27) are **not**
a sweep defect: these three repos had not been resynced in months, so an ordinary resync's own
pre-existing, unrelated additive-merge behavior (`merge_settings`) also catches them up on every
hook `core`'s fragment has gained since their last sync (`guard-git-push.sh`,
`detect-noop-bash.sh`, `record-stash-provenance.sh`, `validate-handoff-location.sh`,
`validate-meta-write.sh`, `validate-bounded-waiter.sh`, `validate-no-python-state-write.sh`, and
more) — a pre-existing property of "an ordinary load/resync" this task did not introduce. The
sweep's own, narrower contribution within that larger catch-up is exactly the orphan removal
column above, confirmed by the fingerprint and carve-out-survival columns staying intact
regardless of the catch-up's size.

## Live Deploys Actually Resynced

Three of the five named targets were resynced for real, via the sanctioned CLI entry point, with
before/after measured directly against the live file:

| Repo | Before count | After count | Dup before/after | env/permissions fingerprint | Idempotent re-run |
|------|-------------:|------------:|:-----------------:|-------------------------------|:--------------------:|
| `~/Projects/Logos/Theory` | 30 | 28 | 0 / 0 | `77a2960a51661f3d5831d2b5e52dff6e4f599f102793c56b08c69b2ae9eda386` (unchanged) | yes — 2nd run: 28→28 |
| `~/Projects/theorem_proving_in_lean4` | 13 | 27 | 0 / 0 | `8eec0ea2943900920676e794f7015421737e16d1773e922e8d2c23874bcaac3a` (unchanged) | yes — 2nd run: 27→27 |
| `~/Projects/Logos/Website` | 12 | 28 | 0 / 0 | `8eec0ea2943900920676e794f7015421737e16d1773e922e8d2c23874bcaac3a` (unchanged) | yes — 2nd run: 28→28 |

**Logos/Theory** (acceptance criterion 1 + the second live instance in the task description): the
cross-event `validate-no-task-references.sh` duplicate under `PostToolUse|Write|Edit` is gone
(only the correct `PreToolUse|Write|Edit` registration remains), and the dead
`wezterm-clear-status.sh` registration under `UserPromptSubmit|*` is gone. The `~/`-anchored
`claude-ready-signal.sh` survived, byte-identical. The Notification/Stop duplicate-matcher-block
defect the task description cited as hand-repaired on 2026-11-07 is confirmed still absent (0
duplicates before and after) — this sweep found two FURTHER orphans the hand repair had missed.

**theorem_proving_in_lean4**: the CWD-relative, non-`~/`-anchored `scripts/claude-ready-signal.sh`
orphan is gone (`grep -c claude-ready-signal` is 0 after). `env`/`permissions` byte-identical.

**Logos/Website**: both `wezterm-notify.sh` (Stop) and `wezterm-clear-status.sh`
(UserPromptSubmit) are gone; the widened-Notification-matcher `tts-notify.sh` registration is
gone (the matcher the source still declares, `permission_prompt|elicitation_dialog`, retains its
own correct entry). The `~/`-anchored `claude-ready-signal.sh` survived, byte-identical.

## Deferred to a Scratch Replay (not applied to the live repo)

**ModelBuilder**: `git status --porcelain` on this repo showed 98 uncommitted, in-progress
changes under its OWN `.claude/` tree (unusually, `.claude/` is git-tracked there, unlike every
other repo in this census) — entirely unrelated deletions/modifications (e.g.
`.claude/agents/document-converter-agent.md`) suggesting a concurrent, mid-flight restructure by
the repo's owner that this dispatch has no visibility into. Applying a resync on top of an
unknown in-progress change set risked compounding with work this task cannot evaluate.
Acceptance criterion 1/4 are satisfied for this target via the scratch-directory replay of its
real Phase 1 fixture above (12→28, fingerprint-identical, both orphans removed, carve-out
survivor intact) — a faithful field-file demonstration, per the Verify-against-a-real-stale-
deploy requirement, just not committed to that repo's own working tree. The owner can apply the
same `deploy-headless.sh` resync once their own in-progress `.claude/` changes are resolved.

**host (`~/.config/nvim`)**: superseded by the live redeploy result recorded above — the host's
own live `.claude/settings.json` was in fact redeployed for real during this task (triggered by
Phase 7's own verification pass needing a fresh redeploy to clear an unrelated doc-lint drift
finding), so there is no remaining scratch-only gap for this target. Phase 8 confirms this same
live state against the complete gate set rather than redeploying a second time.

## No-Change Control Set (spot check)

A sample of the Phase 1 no-change control set was re-measured after the live resyncs above, to
confirm nothing else moved:

| Repo | Registration count | Fingerprint | Matches Phase 1 baseline |
|------|--------------------:|---------------|:---------------------------:|
| `~/Projects/Logos/Verification` | 25 | `bda8ce82...` | yes |
| `~/Projects/Logos/gate-worktree-e18ce9353734` | 25 | `bda8ce82...` | yes |
| `~/Projects/protocol` | 4 | `77a2960a...` | yes |

## Acceptance Criteria Cross-Check

1. **Demonstrated against a real field file**: yes — Logos/Theory, theorem_proving_in_lean4, and
   Logos/Website were resynced live; host and ModelBuilder were replayed against their verbatim
   field fixtures.
2. **Hand-written survival**: no hand-written custom hook was present in any of the five real
   field files measured here; the dedicated `merge_spec.lua` regression (Phase 4) covers this
   case directly against a synthetic `/opt/mytools/...` command, and every one of the five real
   deploys' surviving `~/`-anchored `claude-ready-signal.sh` registrations demonstrates the
   SAME carve-out firing on real field data.
3. (Identity definition — Phase 2/3, not a Phase 6 concern.)
4. **Before/after measurements**: registration count, zero per-event duplicates, and
   `env`/`permissions` byte-identical are reported above for all five named targets (four live —
   host, Logos/Theory, Logos/Website, theorem_proving_in_lean4 — one scratch-replayed —
   ModelBuilder).
5. (Pre-existing specs — Phase 8.)
6. (Documentation — Phase 7.)
