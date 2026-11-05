## Sapience Extension

Permission grants and orientation docs for Sapience, the hosted vault at app.spnc.ai. See
`~/.dotfiles/docs/sapience.md` for the machine configuration -- not duplicated here.

**Already ambient**: the MCP server registration and the three SessionStart/SessionEnd/Stop
hooks in `~/.dotfiles`, enforced every home-manager switch -- never rebuilt here.

**What this extension adds**: `settings-fragment.json` grants the four MCP write tools
(`sapience_remember`, `sapience_wrapup`, `sapience_handoff`, `sapience_adddoc`) at this repo's
project scope -- repository-scoped, not machine-wide; see `domain/review-gate-boundary.md`.

**Postflight wrapup**: at the `[IMPLEMENTING]` -> `[COMPLETED]` transition, call
`sapience_wrapup` with 3-8 distilled notes from the summary artifact just written. Do NOT call
`sapience_remember` proactively mid-run -- see `domain/review-gate-boundary.md` for why.

**No task type, no routing, no slash command**: review/sync/coverage/pending/stats are already
covered by the GNOME desktop launchers the nix module installs.

### Context Pointers

Read-on-demand, not eager-loaded:

- `context/project/sapience/README.md`
- `context/project/sapience/domain/vault-model.md`
- `context/project/sapience/domain/review-gate-boundary.md`
- `context/project/sapience/domain/transcript-filter-ceiling.md`
- `context/project/sapience/domain/subagent-orientation.md`
