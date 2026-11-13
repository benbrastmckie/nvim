# Implementation Summary: Task #612

- **Task**: 612 - Gate every Sapience activation surface behind the sapience extension so Sapience runs only in repos that load it
- **Status**: [COMPLETED]
- **Started**: 2026-11-12T22:12:00Z
- **Completed**: 2026-11-13T07:00:00Z
- **Effort**: ~4 hours
- **Dependencies**: Task 611 (completed)
- **Artifacts**: plans/01_gate-sapience-activation-extension.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built the per-repository Sapience activation surface inside `agent-system/extensions/sapience/`:
a four-script MCP-registration triad (writer, bidirectional `SessionStart` hook, installer,
verifier) mirroring the lean extension's own per-project `lean-lsp` pattern, eleven permission
grants, and five hooks moved into `settings-fragment.json`, so loading the extension into a
repo is now the mechanism that turns on all three activation surfaces there (grants, hooks, and
the per-project MCP registration), and unloading it turns off two of the three cleanly (see
Follow-ups for the one documented exclusion). Every edit landed under
`agent-system/extensions/sapience/` plus two user-level install paths; no `.dotfiles` file was
touched, confirmed mechanically.

## What Changed

- `agent-system/extensions/sapience/settings-fragment.json` — 7 read-tool grants added (11
  total); new `hooks` object with the 5 Sapience hooks (`SessionStart`, `UserPromptSubmit`,
  `PreToolUse`, `SessionEnd`, `Stop`), command strings/timeouts/async flags byte-identical to
  `~/.dotfiles/config/claude/settings.json`
- `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` — new per-project writer:
  registers/repairs/removes `.projects["<abs path>"].mcpServers.sapience` in `~/.claude.json`,
  inheriting the pinned nix-store interpreter when present, falling back to `command -v python3`
- `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh` — new bidirectional
  `SessionStart` hook: registers/repairs when the repo's extension is active, removes when it is
  not
- `agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh` — new
  idempotent, `--remove`-capable installer seeding both files to `$HOME/.claude/{hooks,scripts}/`
  and registering the `SessionStart` entry in `$HOME/.claude/settings.json` only (deliberately
  omitting lean's second `.dotfiles` write target)
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` — new verifier: five named
  checks, three exit codes
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` — new
  23-case regression suite (writer, hook, installer, verifier) plus a mutation check
- `agent-system/extensions/sapience/manifest.json` — `provides.scripts`/`provides.hooks`
  populated; `description` updated
- `agent-system/extensions/sapience/EXTENSION.md` — "Already ambient" paragraph replaced with
  the per-repo activation contract (58/60 lines)
- `agent-system/extensions/sapience/README.md` — file inventory and gaps sections updated (four
  gaps now, including the new MCP-registration surface)
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` — new
  "The MCP-Registration Triad" section plus a durability-residual hazard bullet
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md` —
  "The Permission Grant's Repository-Scoped Tradeoff" section updated to all 11 grants and the
  now-scope-matched registration; heading anchor text kept byte-identical; a coming-staleness
  note added for `core`'s worked example
- `agent-system/extensions/sapience/index-entries.json` — summaries/keywords refreshed;
  `line_count` regenerated (6/6 exact)

## Decisions

- Interpreter resolution prefers the existing top-level `.mcpServers.sapience.command` (inheriting
  the pinned nix-store path) and falls back to `command -v python3` only when no top-level entry
  exists yet to inherit from.
- The registration hook is bidirectional (register on active, remove on inactive-with-existing-
  entry) because the settings-merge engine governs only in-tree merge targets, never
  `~/.claude.json`; this is the only mechanism that can retract a per-project entry on unload.
- The installer deliberately omits lean's second `.dotfiles` write target (acceptance criterion 2
  forbids touching `.dotfiles`), accepting a documented durability gap: the `SessionStart`
  registration in `$HOME/.claude/settings.json` is wiped by the next `home-manager switch` and
  must be re-run until a separate task takes ownership of a durable user-level entry.

## Plan Deviations

- **Verification item 3** (clean unload of all three surfaces) is `[COMPLETED WITH EXCLUSIONS]`
  for one narrowly-scoped item: 4 of the 11 permission grants (the original write-tool grants)
  survive unload because `.claude-extensions.json`'s merge-tracking record for them has been
  empty since before this task existed (confirmed via `git log`, predating this task by at least
  one commit). Hooks and the per-project MCP entry both verified fully clean; 7 of 11 grants
  (every one this task newly added) also verified fully clean. See the plan's Phase 7
  `#### Reasoned Exclusions` record for the full evidence.
- **Verification item 3's "run the complete gate set" bullet, altered**: per this dispatch's
  Batch Gate Deferral directive, discharged against a scoped narrowing invocation
  (`run-all.sh --only test-sapience-mcp-registration.sh` from the source-store entry point, and
  `verify-deploy.sh --skip-slow --only-gate 3,4,21`) instead of independently running the complete
  gate set in this dispatch. Both narrowing invocations are green. The complete gate set runs
  once, for the whole batch, at the end of the invocation.

## Verification

- Build: N/A
- Tests: `test-sapience-mcp-registration.sh` — 23/23 cases pass (source-store `run-all.sh`
  entry point; deployed-mode discovery cannot see an un-deployed suite pre-deploy)
- Files verified: Yes
- `bash -n` and `shellcheck`: clean on all four new scripts plus the hook (0 findings; the
  writer's `.projects[$path]...` jq-filter strings carry the same info-level SC2016 as lean's
  shipped model)
- `verify-deploy.sh --skip-slow --only-gate 3,4,21`: clean after every phase
- `sync-manifest-scripts.sh --check` / `generate-context-line-counts.sh --check`: clean (7/7,
  6/6)
- `check-task-references.sh`: 0 occurrences repo-wide
- `check-record-versioning.sh`: 3 pre-existing BLOCKING hits, all in unrelated `himalaya` docs;
  none introduced by this task (one "no longer exists" phrase was caught and rewritten during
  Phase 6 before closing)

### Verification Items (acceptance criterion 1)

1. **Merged settings carry all 11 grants and 5 hooks** — confirmed via `jq -e` against the real
   `.claude/settings.local.json` in this repo after a `deploy-headless.sh` resync:
   `.permissions.allow | length == 11` and the five hook keys all present.
2. **`~/.claude.json` per-project entry present, no other key disturbed** — confirmed: after
   installing and firing the `SessionStart` hook, `.projects["/home/benjamin/.config/nvim"].mcpServers.sapience`
   appeared with the inherited pinned interpreter and token; a `jq -S` before/after diff of the
   entire file showed the new entry as the ONLY addition — the top-level `.mcpServers.sapience`
   entry and every `.projects[*].mcpServers."lean-lsp"` entry, and every other key, were
   byte-identical.
3. **Unload removes all three surfaces cleanly** — PARTIAL, see Plan Deviations / Reasoned
   Exclusions above: hooks (5/5) and the per-project entry both confirmed fully clean; 7 of 11
   grants confirmed fully clean; the other 4 grants are a pre-existing, out-of-scope
   merge-tracking residual.
4. **Installer idempotent, `--remove` fully reversible** — confirmed against the REAL `$HOME`
   (not a fixture): a second install run left both installed files and `~/.claude/settings.json`
   byte-identical; `--remove` deleted both files, reverted `~/.claude/settings.json` to its exact
   pre-install byte content, and removed the per-project entry immediately;
   `~/.claude.json`'s `.mcpServers`/`.projects` sub-trees were byte-identical pre-install vs.
   post-remove.
5. **Lean + sapience `SessionStart` coexistence** — confirmed empirically: both hooks live in the
   same real `~/.claude/settings.json` (4 `SessionStart` entries total after install), both
   invoked back-to-back exit 0 with no interference, command strings and installed file paths
   are distinct (`lean-lsp-register-project.sh`/`setup-lean-mcp.sh` vs.
   `sapience-mcp-register-project.sh`/`setup-sapience-mcp.sh`).

## Impacts

- Loading the sapience extension into any repo now activates all three surfaces there
  (permission grants, hooks, per-project MCP registration); unloading deactivates the hooks and
  per-project MCP registration cleanly, and 7 of 11 grants cleanly (the 4 pre-existing grants'
  partial residual is documented, not silent).
- The companion task in `/home/benjamin/.dotfiles` (`retire_machine_wide_sapience_surface`) can
  now proceed safely: the per-repo surface this task builds is the precondition that companion
  depends on.
- `core`'s `context/patterns/mcp-server-ownership.md` worked example remains accurate for now
  (both surfaces coexist) but will need updating together with the companion's removal of the
  dotfiles-level read grants — named as a follow-up, not fixed here (out of this task's edit
  surface).

## Follow-ups

- A follow-up task (or the companion `retire_machine_wide_sapience_surface` task) should take
  ownership of a durable user-level `SessionStart` entry for the sapience MCP-registration hook,
  since this task's installer deliberately cannot write `.dotfiles`.
- A separate, differently-scoped task should address `merge.lua`'s tracking-data gap for the
  4 pre-existing sapience write-tool grants (`merged_sections.settings.permissions.children.allow.items`
  being `[]` since before this task), so a future unload can retract them too. This is a
  merge-engine defect, not specific to this extension.
- A follow-up task should update `core/context/patterns/mcp-server-ownership.md`'s sapience
  worked example once the companion task removes the dotfiles-level seven-tool read allow-list,
  together with that same change.

## References

- Plan: `specs/612_gate_sapience_activation_behind_extension/plans/01_gate-sapience-activation-extension.md`
- Report: `specs/612_gate_sapience_activation_behind_extension/reports/01_gate-sapience-extension-scope.md`
- Issue log: `specs/612_gate_sapience_activation_behind_extension/issues.jsonl`
