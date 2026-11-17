# Records: Cross-Repo Closeout Evidence

- **Task**: 637 - Make the sapience extension fully functional across loaded repositories
- **Round**: Phase 1 pre-change baseline, measured 2026-11-17
- **Repositories probed**: `/home/benjamin/.config/nvim`, `/home/benjamin/.dotfiles`,
  `/home/benjamin/Projects/BimodalLogic`, `/home/benjamin/Projects/Sapience/sf1-engine`,
  `/home/benjamin/Projects/Sapience/sapience-app`
- **Excluded**: `/home/benjamin/Projects/abood` — on hold per the task description's explicit
  out-of-scope statement; not probed.

## Reachability

All five in-scope repositories were reachable (directory present, readable) at probe time. No
`issue-record.sh` exclusion entry was needed.

## Per-Repository Baseline

### `/home/benjamin/.config/nvim`

- `mcp__sapience__*` grant count: 7 (`sapience`, `sapience_ask`, `sapience_briefing`,
  `sapience_context`, `sapience_outstanding`, `sapience_papers`, `sapience_search`)
- `.claude/scripts/postflight-sapience-notes.sh`: exists, **not executable** (`-rw-r--r--`)
- `.claude/scripts/sapience-remember.sh`: exists, executable (`-rwxr-xr-x`)
- `postflight-sapience-notes.sh` occurrences: `orchestrate-cycle-postflight.sh` = 2,
  `reconcile-task-status.sh` = 4
- `verify-sapience-mcp.sh` deployed copy: 500 lines, includes checks (a)-(i)
- `verify-sapience-mcp.sh` verdict: (a) PASS, (h) PASS (ledger records hooks fragment merged),
  (b) PASS, (c) PASS, (d) PASS, **(e) PASS — 7 grants and 5 hooks**, (f) skip (not a worktree),
  (g) PASS, **(i) PASS — capture enabled for project 'nvim'**. Overall PASS.

### `/home/benjamin/.dotfiles`

- `mcp__sapience__*` grant count: 7 (same seven names as above)
- `.claude/scripts/postflight-sapience-notes.sh`: exists, **not executable**
- `.claude/scripts/sapience-remember.sh`: exists, executable
- `postflight-sapience-notes.sh` occurrences: `orchestrate-cycle-postflight.sh` = 2,
  `reconcile-task-status.sh` = 4
- `verify-sapience-mcp.sh` deployed copy: **348 lines — predates checks (h) and (i)** (deployed
  2026-11-17 08:36, before this repository's own 500-line copy was deployed at 09:06)
- `verify-sapience-mcp.sh` verdict: (a) PASS, (b) PASS, (c) PASS, (d) PASS, **(e) PASS — 7 grants
  and 5 hooks**, (f) skip. Checks (h) and (i) do not appear in the output at all — the deployed
  script predates them, not a skip or a fail.

### `/home/benjamin/Projects/BimodalLogic`

- `mcp__sapience__*` grant count: 7
- `.claude/scripts/postflight-sapience-notes.sh`: exists, **not executable**
- `.claude/scripts/sapience-remember.sh`: exists, executable
- `postflight-sapience-notes.sh` occurrences: `orchestrate-cycle-postflight.sh` = 2,
  `reconcile-task-status.sh` = 4
- `verify-sapience-mcp.sh` deployed copy: 348 lines (same pre-(h)/(i) vintage as `.dotfiles`)
- `verify-sapience-mcp.sh` verdict: (a) PASS, (b) PASS, (c) PASS, (d) PASS, **(e) PASS — 7 grants
  and 5 hooks**, (f) skip. Checks (h)/(i) absent from output (script predates them).

### `/home/benjamin/Projects/Sapience/sf1-engine`

- `mcp__sapience__*` grant count: 7
- `.claude/scripts/postflight-sapience-notes.sh`: exists, **not executable**
- `.claude/scripts/sapience-remember.sh`: exists, executable
- `postflight-sapience-notes.sh` occurrences: `orchestrate-cycle-postflight.sh` = 2,
  `reconcile-task-status.sh` = 4
- `verify-sapience-mcp.sh` deployed copy: 348 lines (pre-(h)/(i))
- `verify-sapience-mcp.sh` verdict: (a) PASS, (b) PASS, (c) PASS, (d) PASS, **(e) PASS — 7 grants
  and 5 hooks**, (f) skip. Checks (h)/(i) absent from output.

### `/home/benjamin/Projects/Sapience/sapience-app`

- `mcp__sapience__*` grant count: 7
- `.claude/scripts/postflight-sapience-notes.sh`: exists, **not executable**
- `.claude/scripts/sapience-remember.sh`: exists, executable
- `postflight-sapience-notes.sh` occurrences: `orchestrate-cycle-postflight.sh` = 2,
  `reconcile-task-status.sh` = 4
- `verify-sapience-mcp.sh` deployed copy: 348 lines (pre-(h)/(i))
- `verify-sapience-mcp.sh` verdict: (a) PASS, (b) PASS, (c) PASS, (d) PASS, **(e) PASS — 7 grants
  and 5 hooks**, (f) skip. Checks (h)/(i) absent from output.

### Cross-repository observations

- **Goal 4 (check (e) at seven grants) already passes in all five repositories today.** No
  repository shows the additive-merge 11-vs-7 residual the task description names; that residual
  was already closed by an earlier redeploy.
- **Permission-bit discrepancy, all five repositories identically**: `postflight-sapience-notes.sh`
  is deployed `-rw-r--r--` (not executable) in every one of the five repositories, while its
  sibling `sapience-remember.sh` is `-rwxr-xr-x`. Both call sites (`orchestrate-cycle-postflight.sh`,
  `reconcile-task-status.sh`) invoke it via `bash <path>`, so the missing executable bit does not
  block the actual postflight call — but Phase 2's planned check (j) is specified to assert "exist
  and are executable" for both scripts as one of its four pass conditions. Traced to the source
  store: `agent-system/extensions/sapience/scripts/postflight-sapience-notes.sh` is git-tracked
  mode `100644`, versus `sapience-remember.sh`'s `100755` — a genuine, git-tracked permission
  inconsistency at the source, not a per-repository drift. This is carried into Phase 2 as a
  one-line `chmod +x` fix to the source-store script (and the already-deployed copy in this
  repository, so Phase 2's own verification claim holds without waiting for Phase 4's redeploy);
  see the Phase 2 section of the implementation summary for the applied fix.
- **Four of five repositories are running a pre-(h)/(i) deployed `verify-sapience-mcp.sh`.**
  `.dotfiles`, `BimodalLogic`, `sf1-engine`, and `sapience-app` all carry the identical 348-line,
  pre-task-636 copy (checks (a)-(g) only); only this repository (`nvim`) carries the current
  500-line copy with checks (h) and (i). This is exactly the "deploy predates the mechanism"
  failure mode Phase 2's check (j) risk analysis names generically, now confirmed concretely for
  the *verifier script itself* in four of five repositories — check (i)'s capture/activation
  verdict and check (h)'s ledger-merge verdict are **unobservable**, not failing, in those four
  until Phase 4's redeploy lands the current script. This is the strongest evidence yet that
  Phase 4's five-repository redeploy is load-bearing, not a formality.

## `~/.sapience/config.json` Capture State

- `hooks` opt-out value: `false` (hooks are not opted out; matches check (g)'s informational log
  line in every repository where check (g) is observable).
- `capture.projects[]` table (full list, 12 entries; path-prefix / enabled):
  - `/home/benjamin/Projects/BimodalLogic` (BimodalLogic) — `enabled: false`
  - `/home/benjamin/.dotfiles` (.dotfiles) — `enabled: true`
  - `/home/benjamin/Projects/Logos/Vision` (Vision) — `enabled: false`
  - `/home/benjamin/Projects/Logos/Theory` (Theory) — `enabled: false`
  - `/home/benjamin/Documents/Personal/Wedding` (Wedding) — `enabled: false`
  - `/home/benjamin/Philosophy/Papers/PossibleWorlds` (PossibleWorlds) — `enabled: false`
  - `/home/benjamin/.config/nvim` (nvim) — `enabled: true`
  - `/home/benjamin/Projects/PersonalWebsite` (PersonalWebsite) — `enabled: false`
  - `/home/benjamin/Documents/Employment/Applications` (Applications) — `enabled: false`
  - `/home/benjamin/Projects/Logos/Verification` (Verification) — `enabled: false`
  - `/home/benjamin/Projects/abood` (abood) — `enabled: true`
  - `/home/benjamin/Projects/Sapience/sapience-app` (sapience-app) — `enabled: true`
  - **No entry at all** for `/home/benjamin/Projects/Sapience/sf1-engine`.
- **Active-but-not-captured set** (sapience extension `status: active` in `.claude-extensions.json`
  for all five in-scope repositories, confirmed directly, but capture disabled or absent):
  `BimodalLogic` (`enabled: false`) and `sf1-engine` (absent from the list entirely). `.dotfiles`
  and `sapience-app` both show `enabled: true` and are NOT part of this disagreement set — this
  corrects the task description's framing, which named `.dotfiles` alongside `BimodalLogic` and
  `sf1-engine` as capture-disabled; measurement shows `.dotfiles` capture is in fact enabled.
  This disagreement set and its owner (`~/.dotfiles`'s capture-map writer) were already ruled on
  by task 636; this records the measured set as-is, per that ruling, without reopening it.
- `~/.sapience/extracted.json`, `~/.sapience/pending_kos.jsonl`, `~/.sapience/extract_yield.json`
  mtimes: all three **2026-11-13 12:06:52** (local time) — unchanged since the date the task
  description names as the capture-sync stall point. All three files share the same mtime to the
  second, consistent with one `extract_local.py` run writing all three outputs together, and none
  since.

## Extraction-Trigger Mechanism (baseline fact for Phase 3)

- The nix-provided `sapience` launcher (`/home/benjamin/.nix-profile/bin/sapience`) dispatches its
  `review`, `pending`, `sync`, `coverage`, `backfill`, and related subcommands directly to
  `/home/benjamin/.sapience/extract_local.py` via `exec python3 ... extract_local.py --<verb>`.
- `services.sapience.backgroundSync` in `~/.dotfiles/modules/home/services/sapience.nix` defaults
  to `false` (confirmed: `backgroundSync = lib.mkOption { ... }` at line 710, default unset to
  `true` anywhere in the module). The module always defines a `systemd.user.timers.sapience-sync`
  unit but gates its installation on `cfg.backgroundSync` (`lib.mkIf cfg.backgroundSync` at line
  1190) — so with the default `false`, the timer is defined in the module but never installed.
- Confirmed live on this machine: `systemctl --user list-timers` shows no `sapience` timer, and
  `crontab -l` has no `sapience` entry. No scheduling mechanism for extraction exists on this
  machine today; every extraction to date has been a manual `sapience <verb>` invocation.
- This mechanism and its owner live entirely outside this source store
  (`~/.dotfiles/modules/home/services/sapience.nix`); no script in this repository or in the
  sapience extension drives, schedules, or can schedule this pipeline.

## Acceptance Bars That Cannot Be Met From This Repository

### Goal 2 — "prompt-time hook injection is repo-filtered or otherwise bounded" / "probe returns
RESIDUAL_HOLDS"

- Measured: `bash .claude/scripts/verify-sapience-context-scoping.sh --repeat 3` returned
  **`INCONCLUSIVE -- 2 RESIDUAL_HOLDS, 1 RESIDUAL_LIFTED over 3 iterations`**, not a unanimous
  `residual holds`. Per the plan's explicit instruction, this is recorded as-is and was not
  retried.
- Reason this bar cannot be unilaterally closed from this repository: `POST /v1/cli/context`'s
  ignoring of the repo identifier is a vendor-owned (app.spnc.ai server-side) behavior; no local
  change can force a unanimous verdict in either direction, and an inconclusive run is itself
  read as "re-run", per the probe's own documented exit-code 2 contract — not as a defect to fix
  here.
- Owner: Sapience vendor (app.spnc.ai), via the already-drafted vendor ask recorded in
  `domain/injection-site-scoping.md`.

### Goal 3 — "transcript capture sync is restored"

- Measured: capture extraction is manual-by-design (see mechanism section above); the three
  extraction-output files are stale since 2026-11-13 because no `sapience <verb>` has been
  invoked since, not because any mechanism is broken.
- Reason this bar cannot be met from this repository: scheduling (`backgroundSync`) and the
  capture-enabled-project list are both owned by `~/.dotfiles` (per 636's recorded ruling for the
  list, and per the module ownership above for scheduling); this repository's scripts neither
  drive nor can drive either lever.
- Owner: the user, via `~/.dotfiles`'s `services.sapience.backgroundSync` option (scheduling) and
  its capture-map writer (the `enabled` list).

## Issue/Win Log

See `specs/637_make_sapience_extension_fully_functional/issues.jsonl` for the corresponding
`issue-record.sh` entries recorded during this phase (the permission-bit discrepancy and the
pre-(h)/(i) deployed-script finding).

---

## Phase 4: Post-Change Sweep (measured 2026-11-17, after redeploy)

### Redeploy results

`bash agent-system/extensions/core/scripts/deploy-headless.sh` (no `--wipe`) was run against this
repository first, then once per out-of-tree target, for all five repositories this baseline
recorded as reachable:

- `/home/benjamin/.config/nvim` — `RESULT=landed_verify_clean`
- `/home/benjamin/.dotfiles` — `RESULT=landed_verify_clean`
- `/home/benjamin/Projects/BimodalLogic` — `RESULT=landed_verify_clean`
- `/home/benjamin/Projects/Sapience/sf1-engine` — `RESULT=landed_verify_red`. The sapience files
  themselves landed correctly (deployed `verify-sapience-mcp.sh` grew to 562 lines including
  check (j); `postflight-sapience-notes.sh` landed executable). The red verdict is
  `deploy-headless.sh`'s own internal `verify-deploy.sh` gate 4 (`check-task-references.sh`)
  failing on a task-number reference inside
  `integration/claude-system/context/config/orchestrator-context-budget.json` — a separate,
  git-committed snapshot directory in that repository (added by a prior commit of its own,
  unrelated to the live `.claude/` deploy tree and to this task's sapience-extension scope).
  Recorded via `issue-record.sh` as a pre-existing, out-of-scope finding; not fixed here, and not
  a defect of anything this task changed.
- `/home/benjamin/Projects/Sapience/sapience-app` — `RESULT=landed_verify_clean`

No exclusions: all five repositories were reachable and redeployed.

### `verify-sapience-mcp.sh` post-change verdicts

Check (j) and check (e) in every one of the five repositories:

| Repository | Check (j) | Check (e) | Check (i) |
|---|---|---|---|
| `/home/benjamin/.config/nvim` | PASS | PASS (7/5) | PASS (capture enabled, 'nvim') |
| `/home/benjamin/.dotfiles` | PASS | PASS (7/5) | PASS (capture enabled, '.dotfiles') |
| `/home/benjamin/Projects/BimodalLogic` | PASS | PASS (7/5) | informational (not enabled) |
| `/home/benjamin/Projects/Sapience/sf1-engine` | PASS | PASS (7/5) | informational (not enabled, resolved entry 'none') |
| `/home/benjamin/Projects/Sapience/sapience-app` | PASS | PASS (7/5) | PASS (capture enabled, 'sapience-app') |

Check (j) PASSes in all five — the exact outcome the Phase 1 baseline's "four of five run a
pre-(h)/(i) script" finding predicted once redeployed. Check (e) is at seven grants and five
hooks in all five, confirming goal 4 remains closed. Check (i)'s active-but-not-captured set is
confirmed unchanged from Phase 1: `{BimodalLogic, sf1-engine}` — `.dotfiles` and `sapience-app`
both show capture enabled, as Phase 1 measured.

### Tagged-write reachability probe (dry-run, end to end)

A scratch task directory with a minimal `.return-meta.json` (a two-element `sapience_notes`
array) was passed to each repository's own **deployed**
`.claude/scripts/postflight-sapience-notes.sh --task-dir <scratch> --task 637 --dry-run`. The
printed request body's `provenance` field carried the correct `[repo:<slug>]` tag in every
repository, and no non-dry-run call was issued anywhere:

- `/home/benjamin/.config/nvim` → `[repo:nvim]`
- `/home/benjamin/.dotfiles` → `[repo:.dotfiles]`
- `/home/benjamin/Projects/BimodalLogic` → `[repo:BimodalLogic]`
- `/home/benjamin/Projects/Sapience/sf1-engine` → `[repo:sf1-engine]`
- `/home/benjamin/Projects/Sapience/sapience-app` → `[repo:sapience-app]`

Every scratch directory was removed after its probe.

### Per-Goal Disposition

- **Goal 1 (tagged postflight writes fire reliably in every loaded repo)**: mechanism deployed
  and probe-confirmed per repository (five-for-five `[repo:<slug>]`-tagged dry-run bodies above),
  and now covered by a standing mechanical check — `verify-sapience-mcp.sh` check (j) — rather
  than resting on a one-off audit claim. Closed mechanically.
- **Goal 2 (prompt-time hook injection is repo-filtered or otherwise bounded; probe returns
  `RESIDUAL_HOLDS`)**: accepted vendor-owned residual. Phase 1's probe run returned
  `INCONCLUSIVE -- 2 RESIDUAL_HOLDS, 1 RESIDUAL_LIFTED over 3 iterations`, not a unanimous
  `residual holds`; per the plan's own instruction this was recorded as-is and not retried. The
  disposition of all three possible outcomes (including `inconclusive`) is now documented by name
  in `domain/injection-site-scoping.md`'s rewritten "Verifying This Residual Is Still Current"
  section, so a future reader diagnoses this from documentation rather than re-deriving it. No
  local change can move this verdict; reported as an owned residual, not claimed closed.
- **Goal 3 (transcript capture sync is restored)**: the list disagreement (`{BimodalLogic,
  sf1-engine}` active-but-not-captured) is owned by `~/.dotfiles` per task 636's recorded ruling,
  confirmed unchanged by this sweep. Extraction itself is manual-by-design, with its scheduling
  lever (`services.sapience.backgroundSync`) named and documented in `domain/per-repo-scoping.md`'s
  new "Capture Scheduling and the Manual-Only Trigger" subsection. Not restored by this task —
  restoring it (enabling scheduled extraction, or running `sapience sync` manually) is the user's
  call, raised below as a non-blocking `user_decision`, since it spends real money/CPU or uploads
  transcript-derived content and is not required by any goal this plan closes.
- **Goal 4 (`verify-sapience-mcp.sh` check (e) stops failing on the additive-merge 11-vs-7 grant
  residual)**: passing at seven grants and five hooks in all five repositories, both at the Phase
  1 baseline and after this sweep. This goal was already closed by an earlier redeploy, confirmed
  rather than newly closed by this task.

### User-Owned Levers (non-blocking)

Two levers remain, both outside this repository's write surface and both the user's call, not an
implementation step:

1. **Whether to enable scheduled extraction** (`services.sapience.backgroundSync` in
   `~/.dotfiles`, default `false`). Enabling it spends real money or CPU on every scheduled run,
   per the module's own recorded rationale.
2. **Whether to enable capture for `BimodalLogic` and `sf1-engine`** (the two active-but-not-
   captured repositories). Enabling capture means their transcripts begin being extracted and
   uploaded to the vault.

Recommendation: leave both as they stand (the conservative option) — neither is required to
close any goal this plan addresses, and both carry a real cost (money/CPU, or uploading
transcript-derived content) that only the user should accept. See `.return-meta.json`'s
`user_decision` field for the structured, non-blocking record of this choice.

