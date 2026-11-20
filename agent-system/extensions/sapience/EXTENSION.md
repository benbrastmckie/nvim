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

**What this extension adds**: besides the grants and hooks above, four scripts deployed to
`.claude/scripts/`: `scripts/sapience-retrieve.sh` (core's `orchestrate-build-dispatch.sh`
Stage 3.5 `memory_context` block), `scripts/sapience-remember.sh` plus
`scripts/postflight-sapience-notes.sh` (both invoked by the postflight wrapup below), and
`scripts/sapience-tag-pending.sh` (a pre-review ledger tagger: injects the same `[repo:<slug>]`
provenance tag into `~/.sapience/pending_kos.jsonl`'s still-pending transcript-capture records,
in the window between `sapience sync` and `sapience review`). See `domain/per-repo-scoping.md`
for all four scripts' contracts/hazards and the per-project MCP-registration triad
(`setup-sapience-mcp.sh`, the registration hook, installer, verifier).

**Postflight wrapup**: mechanically anchored, not instruction-dependent. The completing
implementation agent emits 3-8 notes as the top-level `sapience_notes` array in
`.return-meta.json`; `scripts/postflight-sapience-notes.sh` performs one
`scripts/sapience-remember.sh` call per note at the `[IMPLEMENTING]` -> `[COMPLETED]` transition
on both completion paths, replacing the untagged `sapience_wrapup` call (full contract:
`domain/per-repo-scoping.md`, Tagged-Write Call Site). Do NOT call `sapience_remember`
proactively mid-run -- see `domain/review-gate-boundary.md`'s Write-Tool Disposition section.

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

**`/sapience`**: assembles a draft vault update from local and vault state, always ending in
ONE approval picker before any write; review/sync/coverage/pending/stats stay the GNOME launchers.

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
