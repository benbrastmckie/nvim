## Sapience Extension

Permission grants and orientation docs for Sapience, the hosted vault at app.spnc.ai. See
`~/.dotfiles/docs/sapience.md` for the machine configuration -- not duplicated here.

**Already ambient**: the MCP server registration and the three SessionStart/SessionEnd/Stop
hooks in `~/.dotfiles`, enforced every home-manager switch -- never rebuilt here.

**What this extension adds**: `settings-fragment.json` grants the four MCP write tools
(`sapience_remember`, `sapience_wrapup`, `sapience_handoff`, `sapience_adddoc`) at this repo's
project scope -- repository-scoped, not machine-wide; see `domain/review-gate-boundary.md`. It
also provides two scripts, `scripts/sapience-retrieve.sh` and `scripts/sapience-remember.sh`,
deployed to `.claude/scripts/`: the first is called from core's `orchestrate-build-dispatch.sh`
Stage 3.5 `memory_context` block; the second is called from the postflight wrapup below. See
`domain/per-repo-scoping.md` for both scripts' contracts and hazards.

**Postflight wrapup**: at the `[IMPLEMENTING]` -> `[COMPLETED]` transition, write 3-8 distilled
notes via `scripts/sapience-remember.sh` (bound enforced at this call site), replacing the
untagged `sapience_wrapup` call. Do NOT call `sapience_remember` proactively mid-run -- see
`domain/review-gate-boundary.md` for why.

**No task type, no routing, no slash command**: review/sync/coverage/pending/stats are already
covered by the GNOME desktop launchers the nix module installs.

### Context Pointers

Read-on-demand, not eager-loaded:

- `context/project/sapience/README.md`
- `context/project/sapience/domain/vault-model.md`
- `context/project/sapience/domain/review-gate-boundary.md`
- `context/project/sapience/domain/transcript-filter-ceiling.md`
- `context/project/sapience/domain/subagent-orientation.md`
- `context/project/sapience/domain/per-repo-scoping.md`
