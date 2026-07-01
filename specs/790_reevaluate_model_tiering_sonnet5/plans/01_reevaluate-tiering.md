# Implementation Plan: Task #790

- **Task**: 790 - Re-evaluate model tiering for Sonnet 5
- **Status**: [COMPLETED]
- **Effort**: 1.75 hours
- **Dependencies**: task 789 (set `ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-5[1m]`) — already complete
- **Research Inputs**: specs/790_reevaluate_model_tiering_sonnet5/reports/01_reevaluate-tiering.md
- **Artifacts**: plans/01_reevaluate-tiering.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This is a **documentation-hygiene** task, not an architectural change. Research confirmed that
re-tiering was authorized but **zero agent-tier moves are warranted**: all 16 opus-tier agents
across both `.claude/` trees legitimately satisfy the KEEP-OPUS criteria (planner / meta-builder /
reviser, or formal-reasoning: lean / logic / math / physics / formal / legal / cslib-research).
No `model:` frontmatter field on any agent or command is changed by this plan.

The actual work is three categories of stale-text repair across two asymmetric trees
(`/home/benjamin/.config/nvim/.claude/` = "nvim tree", `/home/benjamin/.dotfiles/.claude/` =
"dotfiles tree"): (1) refresh a stale SWE-bench benchmark sentence and hardcoded `4.6` version
strings into durable qualitative framing; (2) relax the orchestrator-1M rationale now that
Sonnet 5 also ships native 1M context; (3) fix stale "opus" prose describing `neovim-research`
(whose frontmatter is already `sonnet`). A final phase verifies via grep that no stale strings
remain in scope.

### Research Integration

The plan follows the report's 4-phase RECOMMENDED IMPLEMENTATION section directly. Exact file
paths, line numbers, and current strings were re-verified against the working tree during
planning (all confirmed). The report's tree-asymmetry finding drives the central mechanical
distinction encoded in every phase below: **source-edit-then-resync** (nvim tree, which has a
Lua generator) vs **direct hand-edit** (dotfiles tree, which has no generator).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (no `roadmap_path` provided).

## Goals & Non-Goals

**Goals**:
- Replace the stale SWE-bench percentage sentence ("Sonnet 4.6 79.6% vs Opus 4.6 80.8%") with a
  durable **qualitative** framing (no new hard percentages that will go stale).
- Drop hardcoded `4.6` version strings from the `skill-team-*` dispatch prompts and the
  `team-wave-helpers.md` comment.
- Relax the orchestrator-1M rationale: Sonnet 5 also has native 1M context, so the 1M requirement
  no longer *forces* opus; opus remains the default for `/research` `/plan` `/implement` on
  deep-reasoning grounds, not context size.
- Fix the 4 stale "opus" prose sites describing `neovim-research` (frontmatter already `sonnet`).
- Keep the nvim tree and dotfiles tree consistent, respecting each tree's generation model.

**Non-Goals** (explicit — record and do NOT implement):
- **Re-tiering evaluated; zero moves warranted.** No agent's `model:` field is changed. All 16
  opus-tier agents belong on opus.
- **No change to any command's `model: opus` default.** `/research`, `/plan`, `/implement` keep
  `model: opus` (documentation rationale only is relaxed; changing the default is higher-risk and
  out of scope).
- **No change to `/orchestrate`'s `model: opus`** — separate autonomous-decision-quality rationale.
- **No audit of the other 12 non-orchestrator commands** carrying `model: opus` (`/tag`, `/todo`,
  `/refresh`, `/merge`, etc.) — flagged for a **separate future task**.
- No new web research; no re-derivation of the settled model-positioning conclusions.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing a generated file (nvim `.claude/CLAUDE.md`) without editing its source causes silent drift on next "Load Core" sync | M | M | Always edit the SOURCE (`EXTENSION.md` / `merge-sources`) first; hand-mirror the generated copy only as an interim so a future real sync is a no-op, not a regression |
| dotfiles tree has no generator; its copies silently diverge from nvim sources over time | L | M | Out of scope to fix structurally; hand-edit dotfiles copies directly this pass and note the latent gap for a future cross-tree checker |
| Relaxed 1M rationale propagates an unverified native-1M claim | L | L | Use the report's hedged replacement wording ("verify empirically via `/context` if behavior seems inconsistent"); do not assert mechanism as settled fact |
| Same file (`agent-frontmatter-standard.md`) edited by two phases races if parallelized | L | L | Sequence Phase 2 after Phase 1 (both touch that file); see Dependency Analysis |
| Line numbers drift after an edit shifts subsequent lines | L | M | Match on exact string content (Edit tool), not line number; re-grep in Phase 4 |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phases 1 and 3 touch disjoint file sets and
are independent. Phase 2 is sequenced after Phase 1 because both edit
`agent-frontmatter-standard.md` (avoids same-file edit races). Phase 4 (verification) depends on
all edit phases.

**Edit-mechanism legend** (applies to every phase):
- **SOURCE (agent edits directly)** — nvim tree source-of-truth files: `extensions/core/docs/...`,
  `extensions/core/skills/...`, `extensions/core/context/...`, `extensions/nvim/EXTENSION.md`.
- **DEPLOYED MIRROR (agent hand-mirrors directly)** — nvim tree deployed copies produced by the
  picker "Load Core" sync of plain files (`.claude/docs/...`, `.claude/skills/...`,
  `.claude/context/...`). The agent edits these to match the source immediately; a later real
  sync is a byte-for-byte no-op.
- **GENERATED — REQUIRES USER RESYNC** — nvim `.claude/CLAUDE.md` is assembled by the Neovim
  picker's Lua merge (`merge.lua inject_claudemd_section`) from `EXTENSION.md` + `merge-sources`.
  This Lua flow is **not runnable headlessly by an agent**. The agent edits the SOURCE and may
  hand-mirror `.claude/CLAUDE.md` as an interim stopgap, but the authoritative regeneration
  **requires the user to run the Neovim picker "Load Core" / extension re-merge**.
- **HAND-EDIT (dotfiles, no generator)** — dotfiles tree has no local generator; edit files
  directly.

---

### Phase 1: Stale benchmark + hardcoded version strings [COMPLETED]

**Goal**: Replace the SWE-bench percentage sentence with durable qualitative framing and remove
hardcoded `4.6` version strings from team-skill dispatch prompts and helper comments, across both
trees.

**Replacement text — benchmark sentence** (`agent-frontmatter-standard.md`, currently:
`Sonnet 4.6 achieves 79.6% on SWE-bench (vs Opus 4.6 at 80.8%), making it suitable for most pattern-execution work. Opus is reserved for tasks requiring deep analytical reasoning, multi-step planning, or formal verification.`):

> `Sonnet 5 delivers near-Opus quality on most pattern-execution work, including coding and agentic tasks; Opus remains the choice for deep analytical reasoning, multi-step planning, and formal verification.`

**Replacement text — team-skill dispatch line** (drop the hardcoded version entirely — the
`${teammate_model^}` variable already carries the tier name):
- `model_preference_line="Model preference: Use Claude ${teammate_model^} 4.6 for this analysis."`
  → `model_preference_line="Model preference: Use Claude ${teammate_model^} for this analysis."`
- `model_preference_line="Model preference: Use Claude ${teammate_model^} 4.6 for this task."`
  → `model_preference_line="Model preference: Use Claude ${teammate_model^} for this task."`

**Replacement text — team-wave-helpers comment**:
- `# - "sonnet": Balanced model (Sonnet 4.6), used for most tasks`
  → `# - "sonnet": Balanced model, used for most tasks`

**Tasks**:
- [x] SOURCE: edit `.claude/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`
      (line ~53) — benchmark sentence → qualitative framing. *(completed)*
- [x] DEPLOYED MIRROR: apply identical benchmark-sentence edit to
      `.claude/docs/reference/standards/agent-frontmatter-standard.md` (nvim deployed, line ~53). *(completed)*
- [x] HAND-EDIT (dotfiles): apply identical benchmark-sentence edit to
      `/home/benjamin/.dotfiles/.claude/docs/reference/standards/agent-frontmatter-standard.md`
      (line ~53). *(completed)*
- [x] SOURCE: drop `4.6` in `.claude/extensions/core/skills/skill-team-research/SKILL.md` (line ~217),
      `.../skill-team-plan/SKILL.md` (line ~48), `.../skill-team-implement/SKILL.md` (line ~49). *(completed)*
- [x] DEPLOYED MIRROR: drop `4.6` in `.claude/skills/skill-team-research/SKILL.md` (~217),
      `.claude/skills/skill-team-plan/SKILL.md` (~48), `.claude/skills/skill-team-implement/SKILL.md` (~49). *(completed)*
- [x] HAND-EDIT (dotfiles): drop `4.6` in `/home/benjamin/.dotfiles/.claude/skills/skill-team-research/SKILL.md`,
      `.../skill-team-plan/SKILL.md`, `.../skill-team-implement/SKILL.md` (same lines). *(completed)*
- [x] SOURCE: drop `(Sonnet 4.6)` in `.claude/extensions/core/context/reference/team-wave-helpers.md` (line ~388). *(completed)*
- [x] DEPLOYED MIRROR: drop `(Sonnet 4.6)` in `.claude/context/reference/team-wave-helpers.md` (line ~388). *(completed)*
- [x] HAND-EDIT (dotfiles): drop `(Sonnet 4.6)` in `/home/benjamin/.dotfiles/.claude/context/reference/team-wave-helpers.md` if present. *(completed)*

**Timing**: 40 minutes

**Depends on**: none

**Files to modify**:
- nvim SOURCE: `extensions/core/docs/reference/standards/agent-frontmatter-standard.md`,
  `extensions/core/skills/skill-team-{research,plan,implement}/SKILL.md`,
  `extensions/core/context/reference/team-wave-helpers.md`
- nvim DEPLOYED MIRROR: `.claude/docs/reference/standards/agent-frontmatter-standard.md`,
  `.claude/skills/skill-team-{research,plan,implement}/SKILL.md`,
  `.claude/context/reference/team-wave-helpers.md`
- dotfiles HAND-EDIT: the same four relative paths under `/home/benjamin/.dotfiles/.claude/`

**Verification**:
- `grep -rn "79.6\|80.8\|Opus 4.6\|Sonnet 4.6" ` over both trees returns zero hits.
- `grep -rn '4.6 for this' ` over both trees returns zero hits.
- Benchmark sentence reads as qualitative framing in all three `agent-frontmatter-standard.md` copies.

---

### Phase 2: Orchestrator-1M rationale relaxation (docs-only) [COMPLETED]

**Goal**: Reword the orchestrator-1M rationale so that context size no longer forces opus, while
keeping opus as the deep-reasoning default. Documentation only — no command frontmatter changes.

**Replacement text — rationale bullet** (`agent-frontmatter-standard.md` line ~72). Current:

> `- **Orchestrator commands** (`/research`, `/plan`, `/implement`): these commands run long multi-task sessions that accumulate context from many sequential sub-agent summaries. They must use `model: opus` to receive the 1M context auto-upgrade (via `ANTHROPIC_DEFAULT_OPUS_MODEL` env var). Using `model: sonnet` drops them to 200K and causes context-limit failures on multi-task workflows.`

Replace with the report's §3 wording:

> `- **Orchestrator commands** (`/research`, `/plan`, `/implement`): these commands run long multi-task sessions that accumulate context from many sequential sub-agent summaries. Both `model: opus` and `model: sonnet` now receive the native 1M-token context window (Anthropic's current catalog ships 1M context at standard pricing for both Opus 4.8 and Sonnet 5, no premium or beta header required — verify empirically via `/context` if behavior seems inconsistent). Context size alone no longer requires `model: opus` here; `model: opus` may still be preferred for these commands when the *reasoning depth* of orchestration decisions (not context capacity) justifies it. Domain worker agents dispatched by these commands remain `model: sonnet` per their own frontmatter.`

**Replacement text — example comment** (`agent-frontmatter-standard.md` line ~111). Current:

> `/implement 42 --hard       # Deep reasoning with default model (Opus for orchestrator command)`

Replace with:

> `/implement 42 --hard       # Deep reasoning at high effort (model per command frontmatter; --opus to force Opus)`

**Tasks**:
- [x] SOURCE: edit `.claude/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`
      lines ~72 (rationale) and ~111 (example comment). *(completed)*
- [x] DEPLOYED MIRROR: apply identical edits to
      `.claude/docs/reference/standards/agent-frontmatter-standard.md`. *(completed)*
- [x] HAND-EDIT (dotfiles): apply identical edits to
      `/home/benjamin/.dotfiles/.claude/docs/reference/standards/agent-frontmatter-standard.md`. *(completed)*
- [x] CONFIRM NO-OP: do NOT edit `.claude/commands/{research,plan,implement}.md` frontmatter
      (`model: opus` stays) in either tree. *(completed: verified unchanged via grep)*
- [x] CONFIRM NO-OP: do NOT touch `.claude/commands/orchestrate.md` or any other command file. *(completed: verified via git diff --stat)*

**Timing**: 25 minutes

**Depends on**: 1 (same file — `agent-frontmatter-standard.md` — edited in Phase 1; sequence to
avoid same-file edit races)

**Files to modify**:
- nvim SOURCE: `extensions/core/docs/reference/standards/agent-frontmatter-standard.md`
- nvim DEPLOYED MIRROR: `.claude/docs/reference/standards/agent-frontmatter-standard.md`
- dotfiles HAND-EDIT: `/home/benjamin/.dotfiles/.claude/docs/reference/standards/agent-frontmatter-standard.md`

**Verification**:
- Rationale bullet in all three copies contains "native 1M-token context window" and no longer
  contains "They must use `model: opus`".
- `grep -rn "model: opus" .claude/commands/{research,plan,implement}.md` (both trees) still shows
  `model: opus` — confirming the deferred default was NOT changed.

---

### Phase 3: neovim-research documentation fix [COMPLETED]

**Goal**: Fix the 4 stale "opus" prose sites describing `neovim-research`. No agent frontmatter
changes (already `model: sonnet` in all three copies).

**Edits** (`opus` → `sonnet`):
- EXTENSION.md:15 (nvim, **true source** for CLAUDE.md's Neovim Extension section):
  `| skill-neovim-research | neovim-research-agent | opus | Neovim/plugin research |`
  → `| skill-neovim-research | neovim-research-agent | sonnet | Neovim/plugin research |`
- README.md:36 (nvim, standalone doc):
  `│   ├── neovim-research-agent.md     # Research agent (opus model)`
  → `│   ├── neovim-research-agent.md     # Research agent (sonnet model)`
- README.md:55 (nvim, standalone doc):
  `| skill-neovim-research | neovim-research-agent | opus | Neovim/plugin/Lua research |`
  → `| skill-neovim-research | neovim-research-agent | sonnet | Neovim/plugin/Lua research |`
- nvim `.claude/CLAUDE.md:663` (GENERATED): mirror to `sonnet` (interim), but authoritative regen
  requires user resync (see below).
- dotfiles `.claude/CLAUDE.md:649` (HAND-EDIT, no generator): `opus` → `sonnet` directly.

**Tasks**:
- [x] SOURCE: edit `.claude/extensions/nvim/EXTENSION.md` (line ~15) — `opus` → `sonnet`. *(completed)*
- [x] HAND-EDIT (nvim standalone): edit `.claude/extensions/nvim/README.md` lines ~36 and ~55. *(completed)*
- [x] GENERATED — INTERIM MIRROR: hand-edit nvim `.claude/CLAUDE.md` (line ~663) to `sonnet` as a
      stopgap so the deployed file is immediately correct. **FLAG**: the canonical regeneration of
      this line from `EXTENSION.md` requires the user to run the Neovim picker "Load Core" /
      extension re-merge (Lua `merge.lua`, not headless-runnable). Because the source
      (`EXTENSION.md`) is now correct, that resync will be consistent (no-op), not a regression.
      *(completed — user resync still required for authoritative regen, see summary)*
- [x] HAND-EDIT (dotfiles): edit `/home/benjamin/.dotfiles/.claude/CLAUDE.md` (line ~649) — `opus`
      → `sonnet` directly (no generator in that tree). *(completed)*
- [x] CONFIRM NO-OP: `neovim-research-agent.md` frontmatter is already `model: sonnet` in all
      three copies — no agent-file edit. *(completed: verified)*

**Timing**: 20 minutes

**Depends on**: none (disjoint file set from Phases 1 and 2)

**Files to modify**:
- nvim SOURCE: `extensions/nvim/EXTENSION.md`
- nvim standalone: `extensions/nvim/README.md`
- nvim GENERATED (interim mirror + flag resync): `.claude/CLAUDE.md`
- dotfiles HAND-EDIT: `/home/benjamin/.dotfiles/.claude/CLAUDE.md`

**Verification**:
- `grep -rn "neovim-research-agent.*opus\|opus.*neovim-research" ` over both trees returns zero hits.
- `grep -n "Research agent (opus model)" .claude/extensions/nvim/README.md` returns zero hits.

---

### Phase 4: Verification [COMPLETED]

**Goal**: Confirm all stale strings are gone in scope and no unintended frontmatter changes
occurred; surface the user-resync requirement explicitly.

**Tasks**:
- [x] Re-grep both trees for `"79.6\|80.8\|Opus 4.6\|Sonnet 4.6"` — expect zero hits. *(completed: zero hits)*
- [x] Re-grep both trees for `'4.6 for this'` and `'(Sonnet 4.6)'` — expect zero hits. *(completed: zero hits)*
- [x] Re-grep both trees for `"neovim-research-agent.*opus\|opus.*neovim-research"` — expect zero hits. *(completed: zero hits)*
- [x] Re-read `agent-frontmatter-standard.md` line ~72 in both trees; confirm relaxed rationale
      reads correctly and retains the empirical-verification caveat. *(completed)*
- [x] Confirm `model: opus` is still present in `.claude/commands/{research,plan,implement,orchestrate}.md`
      (both trees) — no command default changed. *(completed: verified)*
- [x] Confirm no `model:` field changed on any agent file (`git diff --stat` should show only docs,
      skills, EXTENSION.md, README.md, CLAUDE.md, team-wave-helpers.md — no `agents/*.md`). *(completed: verified, zero `agents/` diffs in either tree)*
- [x] Run `.claude/scripts/check-extension-docs.sh` (nvim tree) if present; confirm no
      cross-reference breakage from the EXTENSION.md / README.md edits. *(completed: exit 0, nvim extension PASS)*
- [x] **Emit user-action note**: list the one action requiring the user — run the Neovim picker
      "Load Core" / extension re-merge to formally regenerate nvim `.claude/CLAUDE.md` from the
      corrected `EXTENSION.md` and to re-sync the deployed `.claude/docs/`, `.claude/skills/`,
      `.claude/context/` copies. Because all sources and interim mirrors are already correct, this
      resync is expected to be a no-op that only formalizes the change. *(completed — see summary)*

**Timing**: 15 minutes

**Depends on**: 1, 2, 3

**Files to modify**: none (verification only)

**Verification**:
- All grep checks above return zero hits.
- `git diff --name-only` contains no path under `agents/`.

## Testing & Validation

- [ ] `grep -rn "79.6\|80.8\|Opus 4.6\|Sonnet 4.6" <nvim tree> <dotfiles tree>` → 0 hits.
- [ ] `grep -rn "4.6 for this" <both trees>` → 0 hits.
- [ ] `grep -rn "neovim-research-agent.*opus\|opus.*neovim-research" <both trees>` → 0 hits.
- [ ] `neovim-research` reads `sonnet` in all 4 prose sites (EXTENSION.md, README.md x2, dotfiles CLAUDE.md)
      and interim-mirrored in nvim CLAUDE.md.
- [ ] Orchestrator rationale relaxed in all 3 `agent-frontmatter-standard.md` copies.
- [ ] No `agents/*.md` `model:` field changed; command `model: opus` defaults preserved.

## Artifacts & Outputs

- Edited docs/skills/context/EXTENSION/README/CLAUDE files across both trees (no new files created).
- A user-action note (from Phase 4) documenting the required Neovim-picker resync.
- No agent or command frontmatter changes.

## Rollback/Contingency

All edits are text-only and confined to documentation/skill-prompt strings. To revert, use
`git checkout -- <path>` for the affected files in each tree (both are git repositories). No state,
schema, or executable behavior changes are introduced, so rollback carries no data-migration risk.
If the user declines the Neovim-picker resync, the interim hand-mirror of nvim `.claude/CLAUDE.md`
keeps the deployed tree correct until the next natural "Load Core" sync.

## User-Action Summary (edits requiring user resync/activation)

| Item | Who applies | Note |
|------|-------------|------|
| All nvim SOURCE files (`extensions/core/...`, `extensions/nvim/EXTENSION.md`) | Agent | Direct edit |
| All nvim DEPLOYED MIRRORS (`.claude/docs/`, `.claude/skills/`, `.claude/context/`) | Agent | Direct hand-mirror; a later "Load Core" sync is a no-op |
| nvim `extensions/nvim/README.md` | Agent | Standalone, direct edit |
| nvim `.claude/CLAUDE.md` (neovim-research line) | Agent interim + **USER** | Agent hand-mirrors; **user must run Neovim picker "Load Core" / re-merge** for authoritative regen from EXTENSION.md |
| All dotfiles files | Agent | Direct hand-edit (no generator in that tree) |
