# Seed Report: Sapience Extension Audit Findings

- **Task**: 637 - Make sapience extension fully functional
- **Date**: 2026-11-15
- **Type**: seed report (primary-session audit; not a research-agent report)
- **Purpose**: record what a live audit measured, so research starts from evidence rather than
  re-deriving it. Every claim below is labeled measured, inferred, or not checked.

## Goal

In every repository that loads the sapience extension, and in no other:

1. tagged knowledge objects are stored (`[repo:<slug>]` in `provenance`), and
2. injected knowledge objects are filtered to the current repository.

## Audit Method

All commands were run from `/home/benjamin/.config/nvim` on 2026-11-15.

- Enumerated every `.claude-extensions.json` under `~` to depth 5 (22 repositories) and read
  `.extensions | has("sapience")`.
- Read `.projects[<path>].mcpServers` in `~/.claude.json` per repository.
- Read sapience hook keys and `mcp__sapience__*` grants in each `.claude/settings.local.json`.
- Ran `.claude/scripts/verify-sapience-mcp.sh` in each of the six loaded repositories and in
  one unloaded repository (`Projects/Logos/Theory`).
- Ran `.claude/scripts/verify-sapience-context-scoping.sh` three times.
- Queried `GET /v1/search?q=<kw>&source=[repo:<slug>]&limit=50` directly for each slug, with
  `q=task` and `q=the`.
- Read `~/.sapience/config.json` (token excluded), file mtimes under `~/.sapience/`, and
  `specs/state.json` completion counts per repository.

## Findings

### F1. Activation surface is correct in five of six loaded repositories (measured)

| Repository | Extension | MCP entry | Hook keys | Grants |
|---|---|---|---|---|
| `~/.config/nvim` | active | yes | 5 | 11 |
| `~/.dotfiles` | active | yes | 5 | 11 |
| `~/Projects/BimodalLogic` | active | yes | 5 | 11 |
| `~/Projects/Sapience/sf1-engine` | active | yes | 5 | 11 |
| `~/Projects/Sapience/sapience-app` | active | yes | 5 | 11 |
| `~/Projects/abood` | active | **no** | **0** | **4** |

`abood` is half-deployed: its `settings.local.json` is dated Nov 12 and it has 2 sapience
scripts where the others have 6. **Repairing `abood` is out of scope for this task (on hold by
owner decision).** Research should still ask whether the cause (a load that predates the hook
and registration surfaces, with no later reload) can recur in other repositories, because that
is an extension defect rather than an `abood` defect.

### F2. Unloaded repositories carry no sapience surface (measured)

The 16 repositories without the extension have no sapience MCP entry, no sapience hooks and no
sapience grants. `~/.claude.json` has no top-level `mcpServers.sapience`. The live
`~/.claude/settings.json` contains exactly one sapience hook, the `SessionStart`
register/unregister entry, and no `mcp__sapience__*` grants. Its `hooks` object differs from
`~/.dotfiles/config/claude/settings.json` only by an empty `"Stop": []` key.

Minor: the `_SAPIENCE_NOTE` text in the live file describes the retired machine-wide model
while the dotfiles source describes the per-repository model. Not checked: whether a
`home-manager switch` is pending.

### F3. Repo-filtered retrieval works at dispatch time (measured)

`GET /v1/search` with `source=[repo:<slug>]` returned only notes whose `provenance` begins with
that tag, and returned zero hits for unloaded slugs (`Theory`, `ModelChecker`) and for a
nonexistent slug. This is the path `sapience-retrieve.sh` uses.

Caveat found while testing: `sapience-retrieve.sh` resolves the slug from `$PROJECT_ROOT`, which
follows the script's own location, not the caller's working directory. Running nvim's copy from
another repository returns nvim's notes. Each repository has its own deployed copy, so this is
correct in normal dispatch, but it invalidates any cross-repository test that reuses one copy.

### F4. Tagged writes are not reliably firing (measured counts; cause inferred)

| Slug | Tagged notes (q=the, limit 50) | Dates | Tasks completed since Nov 10 |
|---|---|---|---|
| `nvim` | 12 | Nov 5 (1), Nov 10 (7), Nov 13 (4) | 5 |
| `sapience-app` | 33 | Nov 12 (26), Nov 13 (7) | 5 |
| `.dotfiles` | 0 | - | 2 |
| `BimodalLogic` | 0 | - | 1 |
| `sf1-engine` | 0 | - | 3 |
| `abood` | 0 | - | not read |

- No repository has a tagged note dated after Nov 13.
- No repository's `specs/issues.jsonl` or `specs/events.jsonl` mentions `sapience-remember`, so
  no write failure was mirrored.
- Inferred, not verified: the postflight write is being skipped rather than failing. The
  postflight wrapup is an instruction to the agent, not a mechanical step.

Limits on this evidence:

- Counts are capped by `limit=50` and by keyword match on `q=the`; they are lower bounds.
- The "completed since Nov 10" counts were not compared against each repository's extension
  load time. The recorded `loaded_at` values (Nov 12 to Nov 15) reflect the most recent reload,
  not the first load, so they cannot settle this. Some completions may predate activation.
- Not checked: whether any of the completed tasks ran through `/orchestrate` postflight at all.

### F5. Prompt-time injection is not repo-filtered (measured)

`verify-sapience-context-scoping.sh` returned `RESIDUAL_LIFTED` once, then `RESIDUAL_HOLDS`
twice. The script documents a single `RESIDUAL_LIFTED` as inconclusive (server repeat
suppression), so the reading is that `POST /v1/cli/context` still ignores the repository
identifier. Direct observation agrees: a `UserPromptSubmit` injection in the nvim repository
included a note about sapience-app preconditions.

This endpoint is vendor-owned. `context/project/sapience/domain/injection-site-scoping.md`
records the measurement and two owner actions.

### F6. Transcript capture has stalled and its project list disagrees with the loaded set (measured)

- The SessionStart briefing reported "nothing new from your sessions since 2026-11-13, the
  local sync may have stopped".
- `~/.sapience/extracted.json` and `pending_kos.jsonl` were last written Nov 13 12:06;
  `update.log` shows auto-update still running on Nov 14.
- `config.json` has `capture.mode = "opt-in"` and `hooks: false`. Capture is enabled for
  `.dotfiles`, `nvim`, `abood`, `sapience-app`; disabled for `BimodalLogic`; `sf1-engine` has no
  entry. `folders` lists the same four enabled repositories.
- 1208 knowledge objects await review (`auto_approve: false`).
- No systemd user timer or unit matching `sapience` was found. Not checked: cron, or whatever
  schedule the vendor installer sets up.

Transcript capture is a separate channel from `sapience-remember.sh`: it is untagged and
review-gated. Research should decide whether it belongs in this task's definition of "fully
functional" or should be turned off for repositories that rely on tagged writes.

### F7. Verifier check (e) fails in every healthy repository (measured)

`verify-sapience-mcp.sh` exits 1 in all five healthy repositories on check (e) alone: 11 grants
found, 7 expected. The script's own note attributes this to the additive-only merge engine
keeping write-tool grants merged before the grant set was narrowed. The effect is that the
verifier cannot signal a healthy repository, which hides real failures such as `abood`'s.

## Overlap With Open Tasks

The backlog audit flagged these; the owner chose to create this task anyway.

| Task | Name | Overlaps |
|---|---|---|
| 635 | enforce_sapience_postflight_wrapup_write | F4 |
| 636 | sapience_activation_surface_scoping_gaps | F1, F2, F5 |
| 628 | retract_sapience_write_tool_grants | F7 |
| 627 | reap_orphan_sapience_mcp_registrations | adjacent to F1 |

Closed tasks with relevant artifacts: 606 (`summaries/02_injection-site-scoping-residual-summary.md`),
611 (`summaries/01_repo-tag-sapience-write-paths-summary.md`), 612
(`plans/01_gate-sapience-activation-extension.md`).

Research should decide first whether this task absorbs 635, 636 and 628, depends on them, or
is expanded into them, before any planning.

## Research Questions

1. Why did no tagged write fire after Nov 13? Trace one completed task per repository through
   postflight and find where the `sapience-remember.sh` call was or was not reached.
2. What is the earliest point each repository could have written a tagged note (first load of a
   deploy that included `sapience-remember.sh`)? Recompute F4's expected counts against that.
3. Can the postflight write be made mechanical (a script step with a logged outcome) rather
   than an agent instruction, and how would a skipped write become visible?
4. For F5, which option is acceptable while the vendor endpoint ignores the repository
   identifier: suppress or narrow the `UserPromptSubmit`/`PreToolUse` hooks, replace their
   content with a call to the tagged search path, or accept and label the residual?
5. Why did capture stop on Nov 13, what schedules it, and should the capture project list be
   derived from the set of loaded repositories?
6. How should stale merged grants be removed given an additive-only merge engine, so that check
   (e) passes in a healthy repository?
7. What allows a repository to stay marked active with a stale deploy (F1), and should the
   verifier or the SessionStart hook detect it?

## Source Store Note

Fixes belong in the source store resolved from `.claude-extensions.json`
(`agent-system/extensions/sapience/` in this repository), not in the deployed `.claude/` tree.
The vendor client under `~/.sapience/` is not editable from here.
