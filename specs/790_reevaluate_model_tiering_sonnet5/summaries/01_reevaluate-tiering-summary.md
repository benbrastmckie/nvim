# Implementation Summary: Task #790

**Completed**: 2026-06-30
**Duration**: ~35 minutes

## Overview

Documentation-hygiene task: re-evaluated model tiering for Sonnet 5 and confirmed **zero agent
re-tiering moves are warranted** (all 16 opus-tier agents legitimately satisfy KEEP-OPUS
criteria). The actual work was three categories of stale-text repair across the two `.claude/`
trees (`~/.config/nvim/.claude/` = nvim tree, `~/.dotfiles/.claude/` = dotfiles tree): (1) refresh
a stale SWE-bench benchmark sentence and hardcoded `4.6` version strings to durable qualitative
framing, (2) relax the orchestrator-1M-context rationale now that Sonnet 5 also ships native 1M
context, (3) fix 5 stale "opus" prose sites describing `neovim-research` (frontmatter already
`sonnet`). No `model:` frontmatter field on any agent or command file was touched.

## What Changed

### nvim tree (`~/.config/nvim/.claude/`)

- `.claude/extensions/core/docs/reference/standards/agent-frontmatter-standard.md` (SOURCE) —
  benchmark sentence → qualitative framing; orchestrator-1M rationale relaxed; example comment
  reworded.
- `.claude/docs/reference/standards/agent-frontmatter-standard.md` (DEPLOYED MIRROR) — same edits.
- `.claude/extensions/core/skills/skill-team-{research,plan,implement}/SKILL.md` (SOURCE) —
  dropped hardcoded `4.6` from `model_preference_line` (3 files).
- `.claude/skills/skill-team-{research,plan,implement}/SKILL.md` (DEPLOYED MIRROR) — same (3 files).
- `.claude/extensions/core/context/reference/team-wave-helpers.md` (SOURCE) — dropped
  `(Sonnet 4.6)` from the `default_model` comment.
- `.claude/context/reference/team-wave-helpers.md` (DEPLOYED MIRROR) — same.
- `.claude/extensions/nvim/EXTENSION.md` (SOURCE, true source for CLAUDE.md's Neovim Extension
  section) — `neovim-research` model `opus` → `sonnet`.
- `.claude/extensions/nvim/README.md` (standalone) — `opus` → `sonnet` at two sites (comment on
  `neovim-research-agent.md` and the Skill-Agent Mapping table).
- `.claude/CLAUDE.md` (GENERATED — interim hand-mirror only) — `neovim-research` model `opus` →
  `sonnet`. **Not an authoritative regen** — see User-Action Summary below.

13 files changed in the nvim tree; all remain **uncommitted** (orchestrator handles commits per
workflow convention). `git diff --stat` confirms zero changes under any `agents/` path.

### dotfiles tree (`~/.dotfiles/.claude/`, no generator, hand-edited directly)

- `.claude/docs/reference/standards/agent-frontmatter-standard.md` — same benchmark-sentence and
  orchestrator-1M-rationale edits as nvim tree.
- `.claude/skills/skill-team-{research,plan,implement}/SKILL.md` — same `4.6` drop (3 files).
- `.claude/context/reference/team-wave-helpers.md` — same `(Sonnet 4.6)` drop.
- `.claude/CLAUDE.md` — `neovim-research` model `opus` → `sonnet` (hand-edit, no generator in this
  tree).

6 files changed in the dotfiles tree. `git diff --stat` confirms zero changes under `agents/`.

**Important note on commit state**: 5 of these 6 dotfiles files were auto-committed by an
**external background process unrelated to this implementation** — commit `e6590fd` ("checkpoint:
auto-commit before update"), timestamped roughly 2 minutes after the edits landed. This agent did
not run `git commit` in the dotfiles tree at any point; the dotfiles repository appears to have an
independent periodic auto-commit mechanism (outside `.claude/` orchestration) that snapshotted the
working tree. Only `.claude/CLAUDE.md` in the dotfiles tree remains uncommitted at the time of
this summary. This is flagged for user awareness, not something this agent caused or can safely
undo (reverting the auto-commit would be a destructive git operation outside the scope of this
task).

## Decisions

- Used the plan's exact replacement wording verbatim for both the benchmark sentence and the
  orchestrator-1M rationale — no new hard percentages introduced, matching the "durable
  qualitative framing" goal.
- Left `.claude/CLAUDE.md` (nvim, GENERATED) as an interim hand-mirror rather than attempting to
  run the Neovim-picker Lua merge, per the plan's explicit instruction that this flow is not
  headless-runnable and requires the user.
- Did not touch `.opencode/` copies of `neovim-research-agent.md` — out of scope per the plan
  (plan only lists `.claude/` trees).

## Plan Deviations

- **Unplanned (Phase 4)**: Dotfiles tree edits were auto-committed by an external background
  process outside this agent's control (commit `e6590fd`, "checkpoint: auto-commit before
  update"). This agent never invoked `git commit` in the dotfiles tree. 5 of 6 edited dotfiles
  files ended up committed; the 6th (`CLAUDE.md`) remains uncommitted. See progress file
  `specs/790_reevaluate_model_tiering_sonnet5/progress/phase-4-progress.json` for the full
  deviation record.
- No other deviations — implementation followed the plan's exact replacement text for all
  in-scope edits.

## Verification

**Grep results** (all zero hits, confirming no stale strings remain in scope):

```
grep -rln "79.6\|80.8\|Opus 4.6\|Sonnet 4.6" <nvim tree>/.claude/**/*.md <dotfiles tree>/.claude/**/*.md
  -> zero hits

grep -rn '4.6 for this' <both trees>
  -> zero hits

grep -rn '(Sonnet 4.6)' <both trees>
  -> zero hits

grep -rn "neovim-research-agent.*opus\|opus.*neovim-research" <both trees>
  -> zero hits
```

(Note: an unrestricted grep for `79.6|80.8|...` over the full nvim tree, including non-`.md`
files, matches `validate-context-budgets.sh` on the substring `8048` — this is a regex false
positive from the unescaped `.` in the verification pattern matching `"80" + "4" + "8"`, not a
real stale benchmark reference. Restricting to `*.md` files, as scoped by the plan's actual edit
targets, gives a clean zero-hit result.)

**Frontmatter/command integrity**:
- `model: opus` confirmed unchanged in `.claude/commands/{research,plan,implement,orchestrate}.md`
  in both trees.
- `git diff --stat` shows **zero changes under any `agents/` directory** in either tree — no
  agent-tier moves occurred, matching the plan's Non-Goal.
- All 5 `neovim-research` prose sites (EXTENSION.md, README.md x2, nvim CLAUDE.md interim mirror,
  dotfiles CLAUDE.md) now read `sonnet`; `neovim-research-agent.md` frontmatter was already
  `model: sonnet` in all copies (no agent-file edit needed).

**Doc-lint**: `.claude/scripts/check-extension-docs.sh` ran with exit code 0; the `nvim` extension
reports `PASS` with no cross-reference breakage from the `EXTENSION.md` / `README.md` edits.

- Build: N/A (documentation-only task)
- Tests: N/A
- Files verified: Yes

## User-Action Summary (actions still required)

| Item | Who | Note |
|------|-----|------|
| Regenerate nvim `.claude/CLAUDE.md` authoritatively | **User** | Run the Neovim picker "Load Core" / extension re-merge (Lua `merge.lua inject_claudemd_section`, not headless-runnable) so the `neovim-research` line and any other merged content are regenerated from the now-corrected `.claude/extensions/nvim/EXTENSION.md`. Because the source is already correct, this resync is expected to be a **no-op** that only formalizes the interim hand-mirror already applied. |
| Review/commit nvim tree changes | **User** | 13 files in `~/.config/nvim/.claude/` are modified and uncommitted; this implementation did not commit (per convention, the orchestrator handles commits). |
| Review dotfiles tree changes | **User** | 5 of 6 dotfiles files were already auto-committed by an unrelated external process (commit `e6590fd`); `.claude/CLAUDE.md` in the dotfiles tree remains uncommitted. User should review both the auto-committed diff and the remaining uncommitted `CLAUDE.md` change. |
| No home-manager/system activation needed | — | This task made no changes requiring `home-manager switch` or `nixos-rebuild`; all edits are plain text/markdown. |

## Notes

- No `model:` frontmatter field was changed on any agent or command file in either tree — the
  re-tiering evaluation concluded zero moves were warranted, and this was preserved throughout
  implementation and verification.
- The dotfiles auto-commit (commit `e6590fd`) is worth the user's attention as a standalone
  finding: an external mechanism is committing working-tree changes in that repo independent of
  the `.claude/` orchestration workflow, which could interact unexpectedly with future tasks that
  expect edits to remain uncommitted until user review.
