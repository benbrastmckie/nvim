## Sapience Extension

Permission grants, per-repo activation surface, and orientation docs for Sapience, the hosted
vault at app.spnc.ai. See `~/.dotfiles/docs/sapience.md` for the machine configuration.

**Per-repo activation**: loading this extension into a repo is the ONLY thing that turns
Sapience on there; unloading it turns it off again. `settings-fragment.json` carries 7
permission grants (the read-shaped tools) and five hooks (`SessionStart`, `UserPromptSubmit`,
`PreToolUse`, `SessionEnd`, `Stop`), merged only while loaded. A separate, user-level
`SessionStart` hook registers or removes this project's own `~/.claude.json` MCP entry: a
companion-owned `~/.dotfiles/config/claude/settings.json` entry is the durable writer, with
this extension's own installer converging on the identical command as a second writer -- six
hook surfaces total, five extension-merged. See `domain/per-repo-scoping.md`.

**What this extension adds**: besides the grants and hooks above, three scripts deployed to
`.claude/scripts/`: `scripts/sapience-retrieve.sh` (core's `orchestrate-build-dispatch.sh`
Stage 3.5 `memory_context` block), `scripts/sapience-remember.sh` (the single prescribed write
path, invoked below), and `scripts/postflight-sapience-notes.sh` (the mechanical write site,
invoked below). See `domain/per-repo-scoping.md` for all three scripts' contracts and hazards,
and for the per-project MCP-registration triad (`setup-sapience-mcp.sh`, the registration hook,
the installer, the verifier).

**Postflight wrapup**: the write is mechanically anchored, not instruction-dependent. The
completing implementation agent emits 3-8 notes as the top-level `sapience_notes` array in its
own `.return-meta.json`. At the `[IMPLEMENTING]` -> `[COMPLETED]` transition,
`scripts/postflight-sapience-notes.sh` reads that array and performs one
`scripts/sapience-remember.sh` call per note, non-fatally, replacing the untagged
`sapience_wrapup` call. This fires on both the live `/orchestrate` completion path and the
deferred completion path (a deploy-gate refusal later settled by `reconcile-task-status.sh`),
since both invoke the write script directly rather than through a shared propagation helper
either one might otherwise bypass. The 8-note ceiling is a pre-write length check performed
once by the write script, never a running counter; zero notes for a completed task is recorded
as a visible, non-blocking `knowledge-capture gap` issue row rather than silently skipped. Do
NOT call `sapience_remember` proactively mid-run -- see `domain/review-gate-boundary.md`'s
`## Write-Tool Disposition` section for the per-tool reasoning. A non-zero
`sapience-remember.sh` exit (`set_aside`, `gated`, `written == 0`, `ok != true`) is MIRRORED
non-fatally via `issue-record.sh` (`--class "infrastructure/transport unavailable"`) by the
write script, one row per failed note; the degrade rule is unchanged.

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
