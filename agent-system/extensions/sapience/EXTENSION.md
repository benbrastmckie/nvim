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

If a `sapience-remember.sh` call at this site exits non-zero (its own documented failure
branches: `set_aside`, `gated`, `written == 0`, or `ok != true` -- see the script's own header),
record it non-fatally via `issue-record.sh` with `--class "infrastructure/transport
unavailable"`, `--severity minor`, and the script's own stderr text verbatim as
`--what-happened`. This is a MIRROR of the failure, never a gate: the existing degrade rule --
a failed write never blocks postflight -- is unchanged.

**No task type, no routing, no slash command**: review/sync/coverage/pending/stats are already
covered by the GNOME desktop launchers the nix module installs.

**Mechanical gap, stated plainly**: an `mcp__sapience__*` tool failure (as opposed to a failure
of the two scripts above) does not pass through either script and cannot be intercepted
mechanically from this repository -- it surfaces only as a tool-call error in the agent's own
turn, via the vendor-owned `~/.sapience/mcp.py`. The only available remedy is agent self-report
via `issue-record.sh` with the same `infrastructure/transport unavailable` class, and this is
explicitly best-effort, never a substitute for mechanical capture. See
`domain/per-repo-scoping.md`'s "Hazards" section for the full account of what is and is not
reachable.

### Context Pointers

Read-on-demand, not eager-loaded:

- `context/project/sapience/README.md`
- `context/project/sapience/domain/vault-model.md`
- `context/project/sapience/domain/review-gate-boundary.md`
- `context/project/sapience/domain/transcript-filter-ceiling.md`
- `context/project/sapience/domain/subagent-orientation.md`
- `context/project/sapience/domain/per-repo-scoping.md`
