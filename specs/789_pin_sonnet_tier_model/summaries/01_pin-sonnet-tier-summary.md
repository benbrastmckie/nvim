# Implementation Summary: Task #789

**Completed**: 2026-06-30
**Duration**: ~10 minutes

## Overview

Phase 1 of the plan was executed: the Home-Manager-managed Claude Code settings source at `/home/benjamin/.dotfiles/config/claude/settings.json` now pins the `sonnet` alias to Sonnet 5 with 1M context, mirroring the existing Opus pin. Phase 2 (activation via `home-manager switch`) is a user-execution step per plan Non-Goals/USER-EXECUTION flag and was deliberately not run.

## What Changed

- `/home/benjamin/.dotfiles/config/claude/settings.json` — In the `env` block: inserted `"ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5[1m]"` immediately after `ANTHROPIC_DEFAULT_OPUS_MODEL`, and reworded `_MODEL_NOTE` to document that both `ANTHROPIC_DEFAULT_OPUS_MODEL` and `ANTHROPIC_DEFAULT_SONNET_MODEL` are the single source of truth for the default Opus/Sonnet models. No other `env` entries, permissions, hooks, or top-level keys were touched.

  Resulting diff:
  ```diff
     "env": {
  -    "_MODEL_NOTE": "ANTHROPIC_DEFAULT_OPUS_MODEL is the single source of truth for the default Opus model. Do not set it elsewhere (e.g. packages/claude-code.nix wrapper).",
  +    "_MODEL_NOTE": "ANTHROPIC_DEFAULT_OPUS_MODEL and ANTHROPIC_DEFAULT_SONNET_MODEL are the single source of truth for the default Opus/Sonnet models. Do not set them elsewhere (e.g. packages/claude-code.nix wrapper).",
       "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-8[1m]",
  +    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5[1m]",
       "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
       "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION": "1",
       "CLAUDE_CODE_FORK_SUBAGENT": "1",
       "LITERATURE_DIR": "/home/benjamin/Projects/Literature"
     },
  ```

- `specs/789_pin_sonnet_tier_model/plans/01_pin-sonnet-tier.md` — Phase 1 marked `[COMPLETED]`, its task checklist items checked off. Phase 2 left `[NOT STARTED]` pending user activation.

## Decisions

- Followed the plan's exact recommended wording for `_MODEL_NOTE` verbatim (no paraphrasing), since the plan specified it precisely.
- Did not touch `~/.claude/settings.json` (live/deployed copy), `shell.nix`, or `.claude/` tiering/routing docs — all explicitly out of scope per the plan's Non-Goals (tiering policy doc updates are task 790's scope).
- Did not run `home-manager switch` — Phase 2 is explicitly flagged USER-EXECUTION in the plan; a live system rebuild is deferred to the user.
- Left the change staged/unstaged in the dotfiles working tree (no commit made there), per instructions.

## Plan Deviations

- None (implementation followed Phase 1 of the plan exactly).

## Verification

- `jq . /home/benjamin/.dotfiles/config/claude/settings.json` — exit 0, valid JSON.
- `jq -r '.env.ANTHROPIC_DEFAULT_SONNET_MODEL' /home/benjamin/.dotfiles/config/claude/settings.json` → `claude-sonnet-5[1m]` (matches required value).
- `jq -r '.env.ANTHROPIC_DEFAULT_OPUS_MODEL' /home/benjamin/.dotfiles/config/claude/settings.json` → `claude-opus-4-8[1m]` (unchanged).
- `jq -r '.env._MODEL_NOTE' /home/benjamin/.dotfiles/config/claude/settings.json` → now documents both Opus and Sonnet env vars.
- `git diff config/claude/settings.json` (in `/home/benjamin/.dotfiles`) — confirms the diff is exactly the two intended lines (`_MODEL_NOTE` reword + new `ANTHROPIC_DEFAULT_SONNET_MODEL` key), no other files touched.
- Build: N/A (JSON config change, no build step)
- Tests: N/A
- Files verified: Yes

## Notes

**User action required to activate**: The edit is confined to the dotfiles source and has not yet been deployed to the live `~/.claude/settings.json`. To activate the Sonnet pin, run:

```bash
home-manager switch --flake /home/benjamin/.dotfiles
```

After activation, verify with:

```bash
jq -r '.env.ANTHROPIC_DEFAULT_SONNET_MODEL' ~/.claude/settings.json
# expected: claude-sonnet-5[1m]
```

Task 790 (tiering policy doc updates) depends on this task and should be re-evaluated once the sonnet pin is confirmed live.
