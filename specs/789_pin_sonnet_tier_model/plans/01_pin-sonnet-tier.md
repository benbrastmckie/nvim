# Implementation Plan: Task #789

- **Task**: 789 - Pin sonnet tier to Sonnet 5 (1M context) via ANTHROPIC_DEFAULT_SONNET_MODEL
- **Status**: [COMPLETED]
- **Effort**: 0.4 hours
- **Dependencies**: None
- **Research Inputs**: specs/789_pin_sonnet_tier_model/reports/01_pin-sonnet-tier.md
- **Artifacts**: plans/01_pin-sonnet-tier.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a single environment-variable pin (`ANTHROPIC_DEFAULT_SONNET_MODEL`) to the Home-Manager-managed Claude Code settings source, mirroring the existing Opus pin, so the `sonnet` alias deterministically resolves to Sonnet 5 with 1M context. The edit is confined to the dotfiles source file `/home/benjamin/.dotfiles/config/claude/settings.json` (a copy-on-rebuild source, not a symlink); a `home-manager switch` deploys it to `~/.claude/settings.json`. Because the system rebuild is a user-facing action, activation is flagged as requiring user execution.

### Research Integration

The research report confirmed (against `code.claude.com/docs/en/model-config`) that `ANTHROPIC_DEFAULT_SONNET_MODEL` is the correct, documented env var, that `claude-sonnet-5[1m]` is the correct value (idempotent on direct API, load-bearing on gateways, and consistent with downstream task 790's stated expectation), and that the deploy mechanism is a `rm -f` + `cp` in `home.activation.claudeSettings` (modules/home/core/shell.nix). The report supplied the exact diff and resulting `env` block, both reproduced verbatim below.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (roadmap flag not set). Note: task 790 depends on this task and will re-evaluate tiering policy once the sonnet pin lands.

## Goals & Non-Goals

**Goals**:
- Add `"ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5[1m]"` to the `env` block of the dotfiles settings source.
- Update `_MODEL_NOTE` to document both the Opus and Sonnet single-source-of-truth env vars.
- Keep the settings.json valid JSON (verified with `jq`).
- Confirm the pin reaches the live `~/.claude/settings.json` after activation.

**Non-Goals**:
- Editing `.claude/docs/reference/standards/agent-frontmatter-standard.md` or any routing/tiering policy doc (that is task 790's scope, which depends on this task).
- Editing the live `~/.claude/settings.json` directly (it is overwritten on rebuild).
- Changing any Opus/Haiku pin or other `env` entries.
- Touching `packages/claude-code.nix` or any other file that might set model env vars.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Edit made to live `~/.claude/settings.json` instead of the dotfiles source, then lost on next rebuild | M | L | Edit ONLY `/home/benjamin/.dotfiles/config/claude/settings.json`; verify the source path before editing |
| JSON syntax error (trailing comma / quoting) | M | L | Match the exact style of the existing `ANTHROPIC_DEFAULT_OPUS_MODEL` line; run `jq . settings.json` after the edit |
| Scope creep into task 790's tiering-policy territory | M | L | Non-Goals explicitly forbid any `.claude/` doc/routing edits |
| Activation cannot run non-interactively (system rebuild) | L | M | Phase 2 marks `home-manager switch` as user-run; implementer stops and reports rather than forcing a rebuild |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Edit settings.json source [COMPLETED]

**Goal**: Add the Sonnet pin and update `_MODEL_NOTE` in the dotfiles source, keeping valid JSON.

**Tasks**:
- [x] Confirm the target file is `/home/benjamin/.dotfiles/config/claude/settings.json` (dotfiles repo, NOT the nvim tree, NOT the live `~/.claude/settings.json`). *(completed)*
- [x] Read the current `env` block to confirm it matches the research snapshot. *(completed)*
- [x] Apply the exact edit (two changes: `_MODEL_NOTE` text, one new key inserted after `ANTHROPIC_DEFAULT_OPUS_MODEL`): *(completed)*

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

  Resulting `env` block (must match exactly):

  ```json
  "env": {
    "_MODEL_NOTE": "ANTHROPIC_DEFAULT_OPUS_MODEL and ANTHROPIC_DEFAULT_SONNET_MODEL are the single source of truth for the default Opus/Sonnet models. Do not set them elsewhere (e.g. packages/claude-code.nix wrapper).",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-8[1m]",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5[1m]",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION": "1",
    "CLAUDE_CODE_FORK_SUBAGENT": "1",
    "LITERATURE_DIR": "/home/benjamin/Projects/Literature"
  },
  ```
- [x] Validate JSON: `jq . /home/benjamin/.dotfiles/config/claude/settings.json` (must exit 0 and pretty-print the file). *(completed)*
- [x] Confirm the new key is present in the source: `jq -r '.env.ANTHROPIC_DEFAULT_SONNET_MODEL' /home/benjamin/.dotfiles/config/claude/settings.json` must print `claude-sonnet-5[1m]`. *(completed)*

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `/home/benjamin/.dotfiles/config/claude/settings.json` - add one `env` key (`ANTHROPIC_DEFAULT_SONNET_MODEL`) and reword `_MODEL_NOTE` to cover both tiers.

**Verification** (success criteria):
- `jq . /home/benjamin/.dotfiles/config/claude/settings.json` exits 0 (valid JSON).
- `jq -r '.env.ANTHROPIC_DEFAULT_SONNET_MODEL' /home/benjamin/.dotfiles/config/claude/settings.json` prints exactly `claude-sonnet-5[1m]`.
- `jq -r '.env.ANTHROPIC_DEFAULT_OPUS_MODEL' ...` is unchanged (`claude-opus-4-8[1m]`).
- `_MODEL_NOTE` now mentions both `ANTHROPIC_DEFAULT_OPUS_MODEL` and `ANTHROPIC_DEFAULT_SONNET_MODEL`.
- No files outside `/home/benjamin/.dotfiles/config/claude/settings.json` were modified.

---

### Phase 2: Activate and verify deployment [NOT STARTED]

**Goal**: Deploy the edited source to the live `~/.claude/settings.json` and confirm the pin took effect.

**Depends on**: 1

**Tasks**:
- [ ] Recommended activation command (run from the dotfiles flake directory, typically `/home/benjamin/.dotfiles`):

  ```bash
  home-manager switch --flake /home/benjamin/.dotfiles
  ```

  (If the user's normal workflow uses a bare `home-manager switch` or a host-specific flake target, use that instead.)
- [ ] **USER-EXECUTION FLAG**: This is a system rebuild and is a user-facing action. The implementer MUST NOT force a rebuild that cannot complete non-interactively. If `home-manager switch` cannot run cleanly and non-interactively in the current environment, STOP and hand this step to the user, clearly stating the recommended command above. Report the task as awaiting user activation rather than failing.
- [ ] After activation (whether run by implementer non-interactively or by the user), verify the live file:

  ```bash
  jq -r '.env.ANTHROPIC_DEFAULT_SONNET_MODEL' ~/.claude/settings.json
  ```

  Expected output: `claude-sonnet-5[1m]`.
- [ ] Optional sanity check that the live `_MODEL_NOTE` was updated too:

  ```bash
  jq -r '.env._MODEL_NOTE' ~/.claude/settings.json
  ```

  Expected to mention both Opus and Sonnet env vars.

**Timing**: 0.15 hours (excluding any wait for user-run rebuild)

**Files to modify**:
- None directly. Deployment is performed by `home.activation.claudeSettings` in `/home/benjamin/.dotfiles/modules/home/core/shell.nix` (copies source -> `~/.claude/settings.json`). This plan does NOT edit shell.nix.

**Verification** (success criteria):
- `jq -r '.env.ANTHROPIC_DEFAULT_SONNET_MODEL' ~/.claude/settings.json` prints `claude-sonnet-5[1m]` after `home-manager switch`.
- If activation is deferred to the user, the task is reported as "edit complete, awaiting user `home-manager switch`" with the exact command provided — this is an acceptable terminal state for the implementer, not a failure.

---

## Testing & Validation

- [ ] Source JSON is valid (`jq .` exits 0).
- [ ] Source contains `ANTHROPIC_DEFAULT_SONNET_MODEL == "claude-sonnet-5[1m]"`.
- [ ] `_MODEL_NOTE` documents both Opus and Sonnet env vars.
- [ ] Opus pin and all other `env` entries are unchanged.
- [ ] (Post-activation) Live `~/.claude/settings.json` reflects the new key.
- [ ] No `.claude/` doc, routing, or tiering file was touched (task 790 scope).

## Artifacts & Outputs

- Modified: `/home/benjamin/.dotfiles/config/claude/settings.json` (one new `env` key + reworded `_MODEL_NOTE`).
- Deployed (post-activation): `~/.claude/settings.json` with the sonnet pin.
- Execution summary: `specs/789_pin_sonnet_tier_model/summaries/01_pin-sonnet-tier-summary.md` (created at /implement time).

## Rollback/Contingency

- **Revert the edit**: In `/home/benjamin/.dotfiles/config/claude/settings.json`, remove the `ANTHROPIC_DEFAULT_SONNET_MODEL` line and restore the original `_MODEL_NOTE` text (Opus-only). Because the dotfiles repo is git-tracked, `git checkout -- config/claude/settings.json` from the dotfiles root restores the prior state.
- **Undo deployment**: Re-run `home-manager switch` after reverting the source to overwrite `~/.claude/settings.json` back to the Opus-only env block.
- **Blast radius is minimal**: the change is a pure additive env pin with no behavioral code path; worst case the `[1m]` suffix is a redundant no-op on the direct API.
