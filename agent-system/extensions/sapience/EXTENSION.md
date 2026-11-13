## Sapience Extension

Permission grants, per-repo activation surface, and orientation docs for Sapience, the hosted
vault at app.spnc.ai. See `~/.dotfiles/docs/sapience.md` for the machine configuration.

**Per-repo activation**: loading this extension into a repo is the ONLY thing that turns
Sapience on there; unloading it turns it off again. `settings-fragment.json` carries 11
permission grants (7 read tools + 4 write tools) and five hooks (`SessionStart`,
`UserPromptSubmit`, `PreToolUse`, `SessionEnd`, `Stop`), merged only while loaded. A separate,
user-level `SessionStart` hook (installed by `scripts/install-sapience-mcp-session-hook.sh`)
registers or removes this project's own `~/.claude.json` MCP entry -- six hook surfaces in
total, five of which are extension-merged. See `domain/per-repo-scoping.md`.

**What this extension adds**: besides the grants and hooks above, two scripts deployed to
`.claude/scripts/`: `scripts/sapience-retrieve.sh` (core's `orchestrate-build-dispatch.sh`
Stage 3.5 `memory_context` block) and `scripts/sapience-remember.sh` (the postflight wrapup
below). See `domain/per-repo-scoping.md` for both scripts' contracts and hazards, and for the
per-project MCP-registration triad (`setup-sapience-mcp.sh`, the registration hook, the
installer, the verifier).

**Postflight wrapup**: at the `[IMPLEMENTING]` -> `[COMPLETED]` transition, write 3-8 distilled
notes via `scripts/sapience-remember.sh` (bound enforced at this call site), replacing the
untagged `sapience_wrapup` call. Do NOT call `sapience_remember` proactively mid-run -- see
`domain/review-gate-boundary.md`'s `## Write-Tool Disposition` section for the per-tool
reasoning. A non-zero exit (`set_aside`, `gated`, `written == 0`, `ok != true`) is MIRRORED
non-fatally via `issue-record.sh` (`--class "infrastructure/transport unavailable"`); the
degrade rule is unchanged.

**Superseding the vendor SessionStart nudge**: the Sapience SessionStart briefing's own standing
instruction to save a decision with `sapience_remember` as soon as it lands is superseded here
by a counter-instruction in this extension's own surfaces (the nudge text is vendor-authored and
cannot be edited directly). Nothing is lost -- the finding surfaces repo-tagged through the
bounded postflight pass above instead.

**Primary-session content-scoping residual, not closed.** One of three hooks
(`UserPromptSubmit`) sends a repo identifier on `POST /v1/cli/context`; the server ignores it
and returns no per-item attribution to filter or label by. No hook is suppressed or narrowed --
see `domain/injection-site-scoping.md` for the measurement, both owner actions, and
`scripts/verify-sapience-context-scoping.sh`'s falsifiability probe.

**No task type, no routing, no slash command**: review/sync/coverage/pending/stats are already
covered by the GNOME desktop launchers the nix module installs.

**Mechanical gap**: an `mcp__sapience__*` tool failure cannot be intercepted mechanically from
this repository (vendor-owned `~/.sapience/mcp.py`); the only remedy is best-effort agent
self-report via `issue-record.sh`, same class. See `domain/per-repo-scoping.md`'s "Hazards"
section for the full account.

### Context Pointers

Read-on-demand, not eager-loaded:

- `context/project/sapience/README.md`
- `context/project/sapience/domain/vault-model.md`
- `context/project/sapience/domain/review-gate-boundary.md`
- `context/project/sapience/domain/transcript-filter-ceiling.md`
- `context/project/sapience/domain/subagent-orientation.md`
- `context/project/sapience/domain/per-repo-scoping.md`
- `context/project/sapience/domain/injection-site-scoping.md`
