# Research Report: Task #789

**Task**: 789 - Pin sonnet tier to Sonnet 5 (1M context) via ANTHROPIC_DEFAULT_SONNET_MODEL
**Started**: 2026-06-30T00:00:00Z
**Completed**: 2026-06-30T00:00:00Z
**Effort**: Small (single-file settings.json edit)
**Dependencies**: None
**Sources/Inputs**:
- `claude-api` skill (bundled reference, cached 2026-06-24) — model catalog, model IDs
- `claude-code-guide` agent dispatch → WebFetch of `https://code.claude.com/docs/en/model-config` (authoritative Claude Code settings reference)
- Direct file reads: `/home/benjamin/.dotfiles/config/claude/settings.json`, `/home/benjamin/.dotfiles/modules/home/core/shell.nix`
- Codebase grep: `.claude/docs/reference/standards/agent-frontmatter-standard.md`, `specs/TODO.md` (task 790), `.memory/`
**Artifacts**:
- This report: `specs/789_pin_sonnet_tier_model/reports/01_pin-sonnet-tier.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `ANTHROPIC_DEFAULT_SONNET_MODEL` is a real, documented Claude Code environment variable — the sibling of `ANTHROPIC_DEFAULT_OPUS_MODEL` and `ANTHROPIC_DEFAULT_HAIKU_MODEL` — confirmed against the official Claude Code model-config docs (`code.claude.com/docs/en/model-config`).
- The correct model ID for Sonnet 5 is `claude-sonnet-5` (verified via the `claude-api` skill's cached model catalog, cache date 2026-06-24).
- The `[1m]` suffix **is valid and documented for both Opus and Sonnet** aliases (`ANTHROPIC_DEFAULT_OPUS_MODEL` / `ANTHROPIC_DEFAULT_SONNET_MODEL`). On the direct Anthropic API, Sonnet 5 already runs with 1M context natively (no 200K variant exists), so the suffix is a no-op/idempotent safety net there; on LLM gateways it is load-bearing, since Claude Code cannot otherwise verify 1M support. **Recommendation: use `claude-sonnet-5[1m]` anyway** — it costs nothing on direct API and future-proofs against gateway use, matching the existing `claude-opus-4-8[1m]` pattern exactly.
- The exact edit site is the `env` block in `/home/benjamin/.dotfiles/config/claude/settings.json` — add one key, update `_MODEL_NOTE`.
- Deploy path: Home Manager's `home.activation.claudeSettings` (in `shell.nix`) **copies** (not symlinks) `config/claude/settings.json` to `~/.claude/settings.json`. A rebuild (`home-manager switch`) is required for the change to take effect.
- Task 790 already exists and explicitly expects `claude-sonnet-5[1m]` as the pinned value from this task — the recommendation here is consistent with that downstream dependency.

## Context & Scope

The user's Claude Code agent system pins the Opus tier via `ANTHROPIC_DEFAULT_OPUS_MODEL: claude-opus-4-8[1m]` in the Home-Manager-managed `settings.json`. There is no equivalent pin for the `sonnet` tier, so the ~70 sonnet-tier agents in this repo (see `.claude/docs/reference/standards/agent-frontmatter-standard.md`) resolve the `sonnet` alias to whatever Claude Code's built-in default is, rather than deterministically to Sonnet 5. This research determines the exact, correct settings.json edit to close that gap.

## Findings

### 1. Env var name — `ANTHROPIC_DEFAULT_SONNET_MODEL` confirmed

Per the official Claude Code settings reference (`code.claude.com/docs/en/model-config`):

> `ANTHROPIC_DEFAULT_SONNET_MODEL` — The model to use for `sonnet`, or for `opusplan` when Plan Mode is not active.

This sits alongside `ANTHROPIC_DEFAULT_OPUS_MODEL` and `ANTHROPIC_DEFAULT_HAIKU_MODEL` as one of three standard, documented tier-pinning env vars. No other name variant exists for this purpose. This is not an API/SDK concept (it does not appear in the Anthropic Messages API or the `claude-api` skill) — it is a Claude Code CLI harness setting, confirmed via the CLI's own docs.

### 2. Model ID + `[1m]` suffix

- **Model ID**: `claude-sonnet-5` — confirmed authoritative via the `claude-api` skill's current model catalog (1M context, 128K max output, $3/$15 per MTok with an introductory $2/$10 rate through 2026-08-31). This matches the exact string already referenced in task 790's description (`claude-sonnet-5[1m]`).
- **`[1m]` suffix validity**: Documented and supported for Sonnet, not just Opus. From the Claude Code docs:

  > To enable extended context for a pinned model, append `[1m]` to the model ID in `ANTHROPIC_DEFAULT_OPUS_MODEL` or `ANTHROPIC_DEFAULT_SONNET_MODEL`:
  > ```
  > export ANTHROPIC_DEFAULT_OPUS_MODEL='claude-opus-4-8[1m]'
  > ```
  > The `[1m]` suffix applies the 1M context window to all usage of the `opus` and `sonnet` aliases.

- **Important nuance — the suffix is idempotent on direct API, load-bearing on gateways**: on the direct Anthropic API, Sonnet 5 *always* runs with the 1M context window — there is no 200K variant and no suffix needed to select it. The `claude-api` skill's model table corroborates this (Sonnet 5 is listed simply as "1M" context, same as Opus 4.8, with no beta-header or suffix requirement in the API surface). However, when `ANTHROPIC_BASE_URL` points at an LLM gateway instead of the direct API, Claude Code cannot verify 1M support automatically, and the docs state the `[1m]` suffix (mapping to the model picker's "Sonnet 5 (1M context)" option) is the correct way to force it.
- **Recommendation**: use `claude-sonnet-5[1m]` regardless of current deployment topology. It is a no-op on the direct API (which this fleet currently uses, based on `settings.json` containing no `ANTHROPIC_BASE_URL` override) and correctly future-proofs against any gateway use, while also mirroring the existing `claude-opus-4-8[1m]` convention exactly — making the two lines visually and semantically parallel in the config.

### 3. Exact edit site

Current `env` block in `/home/benjamin/.dotfiles/config/claude/settings.json` (verbatim):

```json
{
  "_NOTE": "Managed by Home Manager via ~/.dotfiles/config/claude/settings.json. Edit the source, then run 'home-manager switch'. Runtime changes persist until next rebuild.",
  "env": {
    "_MODEL_NOTE": "ANTHROPIC_DEFAULT_OPUS_MODEL is the single source of truth for the default Opus model. Do not set it elsewhere (e.g. packages/claude-code.nix wrapper).",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-8[1m]",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION": "1",
    "CLAUDE_CODE_FORK_SUBAGENT": "1",
    "LITERATURE_DIR": "/home/benjamin/Projects/Literature"
  },
  ...
}
```

The insertion point is immediately after `ANTHROPIC_DEFAULT_OPUS_MODEL`, before `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`, matching the existing quoting/comma style (double-quoted keys and values, trailing comma on all but the last entry in the block).

Confirmed: no other file in `.claude/`, `.dotfiles/`, or `packages/claude-code.nix` sets `ANTHROPIC_DEFAULT_SONNET_MODEL` or `ANTHROPIC_DEFAULT_OPUS_MODEL` — grepping `/home/benjamin/.config/nvim/.claude/` and `/home/benjamin/.config/.claude/` for `ANTHROPIC_DEFAULT` returns only doc references (agent-frontmatter-standard.md), not settings-file assignments. No collision risk.

### 4. `_MODEL_NOTE` update

Current note only documents the Opus pin. Recommended replacement text covering both tiers:

```
"ANTHROPIC_DEFAULT_OPUS_MODEL and ANTHROPIC_DEFAULT_SONNET_MODEL are the single source of truth for the default Opus/Sonnet models. Do not set them elsewhere (e.g. packages/claude-code.nix wrapper)."
```

### 5. Deploy path

Confirmed via `/home/benjamin/.dotfiles/modules/home/core/shell.nix` (lines 36-38, 58-66):

```nix
# NOTE: .claude/{settings,keybindings}.json managed via activation script (not symlink)
# so that Claude Code can write runtime changes. Source: config/claude/
# See home.activation.claudeSettings below.
...
home.activation.claudeSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
  mkdir -p ${config.home.homeDirectory}/.claude
  rm -f ${config.home.homeDirectory}/.claude/settings.json
  cp ${../../../config/claude/settings.json} ${config.home.homeDirectory}/.claude/settings.json
  chmod u+w ${config.home.homeDirectory}/.claude/settings.json
  ...
'';
```

This is a **copy**, not a symlink — matching the top-level `_NOTE` field in settings.json itself ("Managed by Home Manager via ~/.dotfiles/config/claude/settings.json. Edit the source, then run 'home-manager switch'. Runtime changes persist until next rebuild.").

**Activation command**: `home-manager switch` (from the dotfiles flake). This must be run after editing the source file for the change to reach `~/.claude/settings.json`. Until then, the live file retains the old (Opus-only) env block, and any runtime edits made directly to `~/.claude/settings.json` by Claude Code itself will be silently overwritten (`rm -f` + `cp`) on the next rebuild — so the edit must go in the dotfiles source, never the live file.

### 6. Blast radius / risks

- **No existing sonnet default conflict**: grep confirms no other harness-level config sets a sonnet-tier default, so this is a pure addition, not an override of existing behavior.
- **`[1m]` on Sonnet is documented as safe**: per the official docs quoted in Finding 2, the suffix is explicitly supported for `ANTHROPIC_DEFAULT_SONNET_MODEL`, not an Opus-only mechanic. No error risk.
- **Idempotent on direct API**: since Sonnet 5 already defaults to 1M context on the direct Anthropic API, adding `[1m]` cannot regress current behavior — worst case it is a redundant suffix.
- **Documentation debt (owned by task 790, not this task)**: `/home/benjamin/.config/nvim/.claude/docs/reference/standards/agent-frontmatter-standard.md` (line 72, duplicated in `extensions/core/docs/...`) currently states that orchestrator commands (`/research`, `/plan`, `/implement`) "must use `model: opus` to receive the 1M context auto-upgrade (via `ANTHROPIC_DEFAULT_OPUS_MODEL` env var)" and that "Using `model: sonnet` drops them to 200K." Once this task lands, that constraint may no longer hold for orchestrators (they could get 1M via `model: sonnet` too) — task 790's description already explicitly acknowledges this and scopes the re-tiering-policy re-evaluation to itself ("DEPENDS ON 789... determine whether orchestrators / other opus-tier roles can move to sonnet"). **This task must not edit agent-frontmatter-standard.md or any routing/tiering policy** — that is task 790's scope.
- **Two synced `.claude/` trees**: the doc reference above is duplicated at `.claude/docs/...` and `.claude/extensions/core/docs/...` — again, out of scope for this task (policy-doc sync is task 790's job), but worth flagging so planning doesn't miss it when scoping 790.
- **No test/CI risk**: this is a pure config-value addition with no behavioral code path in the `.claude/` skill/agent system itself; the effect is entirely in how Claude Code's CLI resolves the `sonnet` alias at invocation time.

## Decisions

- Use env var name `ANTHROPIC_DEFAULT_SONNET_MODEL` (confirmed, not guessed).
- Use value `claude-sonnet-5[1m]` (matches task 790's stated expectation, mirrors the Opus pattern, is safe/idempotent on direct API).
- Edit only `/home/benjamin/.dotfiles/config/claude/settings.json`; do not touch `agent-frontmatter-standard.md` or any tiering-policy doc (task 790's scope).
- Update `_MODEL_NOTE` to reference both env vars in one sentence, keeping it short and consistent with the existing style.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Edit made to live `~/.claude/settings.json` instead of the dotfiles source, then lost on next rebuild | Edit only `/home/benjamin/.dotfiles/config/claude/settings.json`; verify via `home-manager switch` afterward |
| Planner scope creep into task 790's tiering-policy territory | Explicitly note in the plan that only the settings.json `env` block changes; no `.claude/` doc/routing edits |
| JSON syntax error (trailing comma, quoting mismatch) | Match exact style of the existing `ANTHROPIC_DEFAULT_OPUS_MODEL` line; validate with `jq . settings.json` before/after |

## Context Extension Recommendations

- **Topic**: Claude Code CLI environment-variable pinning conventions (`ANTHROPIC_DEFAULT_*_MODEL`, `[1m]` suffix semantics)
- **Gap**: No `.claude/context/` or `.memory/` file documents this mechanism; it currently exists only as a comment (`_MODEL_NOTE`) in `settings.json` itself and one prose reference in `agent-frontmatter-standard.md`.
- **Recommendation**: Task 790 (or a follow-up) could add a short note to `.claude/context/` or `.memory/` capturing: (a) the three `ANTHROPIC_DEFAULT_*_MODEL` env vars, (b) the `[1m]` suffix behavior and its idempotent-on-direct-API / load-bearing-on-gateway nuance, (c) the copy-not-symlink deploy mechanism via `home.activation.claudeSettings`. This is exactly the kind of fact that's easy to re-litigate from scratch next time a model tier needs pinning.

## RECOMMENDED IMPLEMENTATION

Apply this exact diff to `/home/benjamin/.dotfiles/config/claude/settings.json`:

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

Resulting block:

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

**Steps for the implementation phase**:

1. Edit `/home/benjamin/.dotfiles/config/claude/settings.json` exactly as above (two changes: `_MODEL_NOTE` text, one new key).
2. Validate JSON syntax: `jq . /home/benjamin/.dotfiles/config/claude/settings.json`.
3. Activate the change: `home-manager switch` (run from wherever the dotfiles flake is normally applied — this is a user-facing rebuild step; confirm with the user before running, or leave it to them per standard dotfiles workflow).
4. Verify deployment: `jq '.env.ANTHROPIC_DEFAULT_SONNET_MODEL' ~/.claude/settings.json` should print `"claude-sonnet-5[1m]"` after the switch.
5. Do **not** touch `.claude/docs/reference/standards/agent-frontmatter-standard.md` or any routing/tiering content — that is task 790's scope, which explicitly depends on this task completing first.

## Appendix

- Search queries used: `code.claude.com/docs/en/model-config` (via `claude-code-guide` agent WebFetch), grep for `ANTHROPIC_DEFAULT` across `.claude/` and `.memory/` trees, grep for task 789/790 in `specs/state.json` and `specs/TODO.md`.
- References: `claude-api` skill bundled model catalog (`shared/models.md` equivalent, cache date 2026-06-24); Claude Code settings reference at `code.claude.com/docs/en/model-config` (lines ~432, ~436, ~470, ~497-503 per subagent report).
