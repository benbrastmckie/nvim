# Research Report: Task #790

**Task**: 790 - Re-evaluate model tiering for Sonnet 5
**Started**: 2026-06-30T00:00:00Z
**Completed**: 2026-06-30T00:00:00Z
**Effort**: Medium (documentation + frontmatter edits across two synced trees, no architectural change)
**Dependencies**: task 789 (set `ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-5[1m]`)
**Sources/Inputs**:
- Codebase inventory of `/home/benjamin/.config/nvim/.claude/` and `/home/benjamin/.dotfiles/.claude/` (grep + Read, no web research per instructions — model-positioning conclusions were supplied pre-settled)
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The two `.claude/` trees are **not structurally symmetric**: the nvim tree fully vendors extension source directories (`extensions/*/agents/`, `extensions/*/docs/`, `extensions/core/merge-sources/claudemd.md`) that are synced into the top-level `.claude/` tree by an in-editor Neovim picker operation (`sync.lua`, "Load Core" / `Ctrl-l`). The dotfiles tree carries only `manifest.json` stubs per extension (no `agents/`, `docs/`, or `merge-sources/` subdirectories) and only 5 extensions (`core`, `memory`, `nix`, `nvim`, `python`) vs. the nvim tree's 18. Edits to generated files (CLAUDE.md, docs) must target the correct **source** file, not the deployed copy, in the nvim tree; in the dotfiles tree there is no local generator, so files must be hand-edited directly.
- **Zero agent-frontmatter re-tiering is warranted.** Every agent currently carrying `model: opus` in both trees (19 distinct agent names, some counted twice for hard variants) falls cleanly inside the KEEP-OPUS criteria (planner/meta-builder/reviser, or formal-reasoning: lean/logic/math/physics/formal/legal/cslib-research). There is no PROPOSE-SONNET candidate among opus-tier *agents*.
- The **neovim-research discrepancy is documentation-only**: `neovim-research-agent.md` frontmatter is *already* `model: sonnet` in all three copies (nvim tree top-level, nvim tree `extensions/nvim/`, dotfiles tree) — this was presumably fixed previously. Only prose tables in `CLAUDE.md`, `EXTENSION.md`, and `README.md` still say "opus". 4 exact fix sites identified below.
- The stale-benchmark sentence ("Sonnet 4.6 achieves 79.6%... vs Opus 4.6 at 80.8%") exists at 3 sites (2 nvim-tree copies + 1 dotfiles copy) in `agent-frontmatter-standard.md`. A related, previously-unflagged stale-version site was found: hardcoded `"... 4.6 for this ..."` strings in `skill-team-research`, `skill-team-plan`, `skill-team-implement` SKILL.md files (6 file copies across both trees) that get literally interpolated into teammate prompts at `--team` dispatch time.
- The orchestrator-1M mandate (`agent-frontmatter-standard.md` line 72, both trees + nvim `extensions/core/` mirror) explicitly names only `/research`, `/plan`, `/implement` — **not** `/orchestrate`, which carries `model: opus` for a separate, undocumented-but-implied reason (autonomous state-machine decision quality, not context accumulation). Recommend relaxing the 3 named commands' rationale but treating `/orchestrate`'s opus assignment as a **separate KEEP-OPUS decision**, not swept into this change.
- A broader, out-of-explicit-scope discovery: **all 16 slash-command files** in `.claude/commands/` (not just the 4 orchestrator-shaped ones) currently carry `model: opus` frontmatter, including simple direct-execution commands (`/tag`, `/todo`, `/refresh`, `/merge`). This predates and is unrelated to the 1M-context rationale under review here; flagged as a candidate for a **separate** follow-up task rather than folded into this one.

## Context & Scope

This report continues task 790 after a prior research pass established the model-positioning conclusions (embedded verbatim below) but did not write findings to disk. This pass performed the concrete codebase inventory only — no new web research was conducted, per instructions.

### Settled Model-Positioning Conclusions (carried over, not re-researched)

- `ANTHROPIC_DEFAULT_SONNET_MODEL` is the sonnet-tier's single source of truth (task 789 set it to `claude-sonnet-5[1m]`); `ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-8[1m]`. Tier-name→env-var mapping is high-confidence inference from first-party repo config + naming convention (**not confirmed by public Anthropic API docs** — caveat retained).
- Per Anthropic's current model catalog: **both** Opus 4.8 and Sonnet 5 natively ship a 1M-token context window at standard pricing, no long-context premium, no beta header required. The `[1m]` suffix is a **Claude-Code-CLI convention** (possibly vestigial given native 1M), **not** an Anthropic API model-id convention — flagged as CLI-internal; recommend empirical verification (e.g. `/context`) rather than asserting mechanism as fact.
- Because Sonnet 5 gets the same native 1M window as Opus, the policy's "orchestrators MUST be opus SOLELY for 1M context" rationale is now technically weak: recommend relaxing it to "orchestrators may run on sonnet without losing 1M context" — with a caveat that deep-reasoning quality (not context size) may still justify opus for planner/meta/reviser.
- Sonnet 5 positioning: "near-Opus quality on coding and agentic work... reaching what was previously Opus-tier quality on many tasks." Opus 4.8: most capable, best for long-horizon autonomous/deep-reasoning work. Recommend replacing stale hard percentages with durable qualitative framing, not new soon-stale numbers.

## Findings

### 1. Stale-benchmark sites (exact locations)

**Primary sentence** — "Sonnet 4.6 achieves 79.6% on SWE-bench (vs Opus 4.6 at 80.8%), making it suitable for most pattern-execution work. Opus is reserved for tasks requiring deep analytical reasoning, multi-step planning, or formal verification."

| # | File | Line | Tree |
|---|------|------|------|
| 1 | `.claude/docs/reference/standards/agent-frontmatter-standard.md` | 53 | nvim (deployed copy) |
| 2 | `.claude/extensions/core/docs/reference/standards/agent-frontmatter-standard.md` | 53 | nvim (source copy — identical byte-for-byte, confirmed via `diff`) |
| 3 | `.claude/docs/reference/standards/agent-frontmatter-standard.md` | 53 | dotfiles (no local source mirror exists — hand-edit target) |

**Secondary hardcoded-version sites** (found via broader `4\.6\b` grep, not explicitly requested but directly relevant — dynamically interpolated into teammate prompts, so also user-facing stale text):

| # | File | Line | Text | Tree |
|---|------|------|------|------|
| 4 | `.claude/skills/skill-team-research/SKILL.md` | 217 | `model_preference_line="Model preference: Use Claude ${teammate_model^} 4.6 for this analysis."` | nvim (deployed) |
| 5 | `.claude/extensions/core/skills/skill-team-research/SKILL.md` | 217 | same | nvim (source) |
| 6 | `.claude/skills/skill-team-research/SKILL.md` | 217 | same | dotfiles |
| 7 | `.claude/skills/skill-team-plan/SKILL.md` | 48 | `model_preference_line="Model preference: Use Claude ${teammate_model^} 4.6 for this task."` | nvim (deployed) |
| 8 | `.claude/extensions/core/skills/skill-team-plan/SKILL.md` | 48 | same | nvim (source) |
| 9 | `.claude/skills/skill-team-plan/SKILL.md` | 48 | same | dotfiles |
| 10 | `.claude/skills/skill-team-implement/SKILL.md` | 49 | `model_preference_line="Model preference: Use Claude ${teammate_model^} 4.6 for this task."` | nvim (deployed) |
| 11 | `.claude/extensions/core/skills/skill-team-implement/SKILL.md` | 49 | same | nvim (source) |
| 12 | `.claude/skills/skill-team-implement/SKILL.md` | 49 | same | dotfiles |

Also found (informational, not action-required — cosmetic comment, no benchmark claim): `.claude/context/reference/team-wave-helpers.md:388` and its nvim `extensions/core/` mirror: `# - "sonnet": Balanced model (Sonnet 4.6), used for most tasks`. Low priority; recommend fixing alongside items 4-12 since it's the same stale-version pattern in the same subsystem.

No other "Opus 4.6"/"Sonnet 4.6"/"79.6"/"80.8" hits exist in either tree (verified with `grep -rn` over both full `.claude/` trees; `4.6` false positives in `todo.md` step numbers and `validate-context-budgets.sh` byte-budget numbers were checked and excluded as unrelated).

### 2. Opus-tier agent inventory + re-tiering table

**Method**: `grep -rl "^model: opus"` over every file in both trees, then filtered to agent files (`.claude/agents/*.md`, `.claude/extensions/*/agents/*.md`).

| Agent | File path(s) | Current tier | Proposed tier | Rationale |
|-------|-------------|---------------|----------------|-----------|
| planner-agent | nvim: `.claude/agents/planner-agent.md`, `.claude/extensions/core/agents/planner-agent.md`; dotfiles: `.claude/agents/planner-agent.md` | opus | **KEEP-OPUS** | Explicit KEEP-OPUS category (planner) |
| planner-hard-agent | nvim: `.claude/agents/planner-hard-agent.md`, `.claude/extensions/core/agents/planner-hard-agent.md`; (not present in dotfiles — dotfiles has no `--hard` agent variants) | opus | **KEEP-OPUS** | planner (hard variant) |
| meta-builder-agent | nvim: `.claude/agents/meta-builder-agent.md`, `.claude/extensions/core/agents/meta-builder-agent.md`; dotfiles: `.claude/agents/meta-builder-agent.md` | opus | **KEEP-OPUS** | Explicit KEEP-OPUS category |
| reviser-agent | nvim: `.claude/agents/reviser-agent.md`, `.claude/extensions/core/agents/reviser-agent.md`; dotfiles: `.claude/agents/reviser-agent.md` | opus | **KEEP-OPUS** | Explicit KEEP-OPUS category |
| cslib-research-agent | nvim: `.claude/agents/cslib-research-agent.md`, `.claude/extensions/cslib/agents/cslib-research-agent.md`; not in dotfiles (no cslib extension there) | opus | **KEEP-OPUS** | formal-reasoning (cslib-research, explicit criterion) |
| cslib-research-hard-agent | nvim: `.claude/agents/cslib-research-hard-agent.md`, `.claude/extensions/cslib/agents/cslib-research-hard-agent.md`; not in dotfiles | opus | **KEEP-OPUS** | formal-reasoning (cslib-research, hard variant) |
| lean-research-agent | nvim: `.claude/extensions/lean/agents/lean-research-agent.md`; not in dotfiles | opus | **KEEP-OPUS** | formal-reasoning (lean) |
| lean-research-hard-agent | nvim: `.claude/extensions/lean/agents/lean-research-hard-agent.md`; not in dotfiles | opus | **KEEP-OPUS** | formal-reasoning (lean, hard variant) |
| lean-implementation-agent | nvim: `.claude/extensions/lean/agents/lean-implementation-agent.md`; not in dotfiles | opus | **KEEP-OPUS** | formal-reasoning (lean) |
| lean-implementation-hard-agent | nvim: `.claude/extensions/lean/agents/lean-implementation-hard-agent.md`; not in dotfiles | opus | **KEEP-OPUS** | formal-reasoning (lean, hard variant) |
| formal-research-agent | nvim: `.claude/extensions/formal/agents/formal-research-agent.md`; not in dotfiles | opus | **KEEP-OPUS** | formal-reasoning (explicit criterion) |
| math-research-agent | nvim: `.claude/extensions/formal/agents/math-research-agent.md`; not in dotfiles | opus | **KEEP-OPUS** | formal-reasoning (math) |
| logic-research-agent | nvim: `.claude/extensions/formal/agents/logic-research-agent.md`; not in dotfiles | opus | **KEEP-OPUS** | formal-reasoning (logic) |
| physics-research-agent | nvim: `.claude/extensions/formal/agents/physics-research-agent.md`; not in dotfiles | opus | **KEEP-OPUS** | formal-reasoning (physics) |
| legal-analysis-agent | nvim: `.claude/extensions/founder/agents/legal-analysis-agent.md`; not in dotfiles | opus | **KEEP-OPUS** | formal-reasoning (legal, explicit criterion) |
| legal-council-agent | nvim: `.claude/extensions/founder/agents/legal-council-agent.md`; not in dotfiles | opus | **KEEP-OPUS** | formal-reasoning (legal) |

**Conclusion: zero PROPOSE-SONNET agents.** All 16 distinct opus-tier agent names in the union of both trees fall inside the explicit KEEP-OPUS criteria (planner/meta-builder/reviser or formal-reasoning: lean/logic/math/physics/formal/legal/cslib-research). No agent frontmatter changes are recommended by this research pass.

Sanity-checked domain research/implementation agents that are **already** `model: sonnet` in both trees (no action needed): `general-research-agent`, `general-implementation-agent`, `code-reviewer-agent`, `spawn-agent`, `synthesis-agent`, `neovim-research-agent`, `neovim-implementation-agent`, `nix-research-agent`, `nix-implementation-agent`, `python-research-agent`, `python-implementation-agent` (dotfiles), and the `general-research-hard-agent` / `general-implementation-hard-agent` (sonnet) / `cslib-vet-agent` families. None of these needed re-tiering; the "pattern-execution domain research agent" PROPOSE-SONNET move the task anticipated has already happened at the frontmatter level for every domain agent that qualifies — the only gap is the stale prose describing `neovim-research-agent` (see next section).

### 3. Orchestrator 1M constraint — exact text + recommended replacement

**Exact current text**, `agent-frontmatter-standard.md` line 72 (identical in all 3 copies: nvim `.claude/docs/...:72`, nvim `.claude/extensions/core/docs/...:72`, dotfiles `.claude/docs/...:72`):

> `- **Orchestrator commands** (`/research`, `/plan`, `/implement`): these commands run long multi-task sessions that accumulate context from many sequential sub-agent summaries. They must use `model: opus` to receive the 1M context auto-upgrade (via `ANTHROPIC_DEFAULT_OPUS_MODEL` env var). Using `model: sonnet` drops them to 200K and causes context-limit failures on multi-task workflows.`

**Recommended replacement text** (same location, all 3 copies):

> `- **Orchestrator commands** (`/research`, `/plan`, `/implement`): these commands run long multi-task sessions that accumulate context from many sequential sub-agent summaries. Both `model: opus` and `model: sonnet` now receive the native 1M-token context window (Anthropic's current catalog ships 1M context at standard pricing for both Opus 4.8 and Sonnet 5, no premium or beta header required — verify empirically via `/context` if behavior seems inconsistent). Context size alone no longer requires `model: opus` here; `model: opus` may still be preferred for these commands when the *reasoning depth* of orchestration decisions (not context capacity) justifies it. Domain worker agents dispatched by these commands remain `model: sonnet` per their own frontmatter.`

**Related example line**, `agent-frontmatter-standard.md` line 111 (all 3 copies) — should be updated for consistency once the rationale changes:

> `/implement 42 --hard       # Deep reasoning with default model (Opus for orchestrator command)`

Recommend rewording to avoid implying opus is required by context size, e.g.: `/implement 42 --hard       # Deep reasoning at high effort (model per command frontmatter; --opus to force Opus)`.

**Scope boundary — do not conflate with `/orchestrate`**: The line-72 rationale names only `/research`, `/plan`, `/implement`. `/orchestrate` (and `skill-orchestrate`/`skill-orchestrate-hard`, both documented as `opus` in the Skill-to-Agent Mapping table) is a distinct, autonomous, no-confirmation-gate state machine; its opus assignment is not justified by the 1M-context rationale under revision and should be evaluated separately (recommend leaving `/orchestrate`'s `model: opus` untouched by this task, pending its own review).

**Command frontmatter files carrying `model: opus`** that implement this rationale — `research.md`, `plan.md`, `implement.md` (line 5 in every copy):

| Command | nvim (deployed) | nvim (source) | dotfiles |
|---------|------------------|-----------------|----------|
| research | `.claude/commands/research.md:5` | `.claude/extensions/core/commands/research.md:5` | `.claude/commands/research.md:5` |
| plan | `.claude/commands/plan.md:5` | `.claude/extensions/core/commands/plan.md:5` | `.claude/commands/plan.md:5` |
| implement | `.claude/commands/implement.md:5` | `.claude/extensions/core/commands/implement.md:5` | `.claude/commands/implement.md:5` |
| orchestrate | `.claude/commands/orchestrate.md:5` | `.claude/extensions/core/commands/orchestrate.md:5` | `.claude/commands/orchestrate.md:5` | *(excluded from this task's scope per boundary above — keep as-is)* |

**Decision needed from planner**: if the recommendation above ("opus may still be preferred... but is no longer required") is adopted, the *default* in these 3 command files could either (a) stay `model: opus` as a conservative default while the doc text clarifies it's now a preference not a hard requirement, or (b) change to `model: sonnet` as the new default, letting users opt into `--opus` for deep-reasoning-sensitive runs. Given the "be conservative" instruction governing this task, **recommend (a)**: change the *documentation rationale only*, leave the 3 command frontmatter files at `model: opus` for now, and treat "change the default" as a separate, higher-risk follow-up decision requiring explicit user sign-off (it changes default cost/behavior for every invocation, not just documentation accuracy).

**Out-of-scope discovery** (flag only, do not act): all 16 files in `.claude/commands/` — including `/tag`, `/todo`, `/refresh`, `/merge`, `/errors`, `/fix-it`, `/meta`, `/project-overview`, `/review`, `/revise`, `/spawn`, `/task` — currently carry `model: opus` frontmatter, most with no documented 1M-context rationale at all (many are single-shot direct-execution commands with no sub-agent fan-out). This predates and is orthogonal to the settled conclusions being implemented here. Recommend a **separate** future task to audit whether these 12 additional commands' opus assignment is intentional.

### 4. neovim-research discrepancy — every location + required edits

**Frontmatter is already correct** (`model: sonnet`) at all 3 copies — no agent-file edit needed:
- nvim: `.claude/agents/neovim-research-agent.md:4`
- nvim: `.claude/extensions/nvim/agents/neovim-research-agent.md:4`
- dotfiles: `.claude/agents/neovim-research-agent.md:4`

**Stale "opus" prose that must be fixed** (4 sites, all reading `| skill-neovim-research | neovim-research-agent | opus | Neovim/plugin research |` or equivalent):

| # | File | Line | Text | Tree | Edit source? |
|---|------|------|------|------|----------------|
| 1 | `.claude/CLAUDE.md` | 663 | `\| skill-neovim-research \| neovim-research-agent \| opus \| Neovim/plugin research \|` | nvim (generated — DO NOT hand-edit as final fix; see §5) | Source is `.claude/extensions/nvim/EXTENSION.md` (merged via section injection, `section_id: extension_nvim`) |
| 2 | `.claude/extensions/nvim/EXTENSION.md` | 15 | same table row | nvim | **This is the true source** for CLAUDE.md's `## Neovim Extension` section |
| 3 | `.claude/extensions/nvim/README.md` | 36 | `│   ├── neovim-research-agent.md     # Research agent (opus model)` (comment in directory-tree diagram) | nvim | Hand-edit directly — not merged into CLAUDE.md, this is the extension's own README |
| 4 | `.claude/extensions/nvim/README.md` | 55 | `\| skill-neovim-research \| neovim-research-agent \| opus \| Neovim/plugin/Lua research \|` | nvim | Hand-edit directly |
| 5 | `.claude/CLAUDE.md` | 649 | `\| skill-neovim-research \| neovim-research-agent \| opus \| Neovim/plugin research \|` | dotfiles | **No local generator exists in dotfiles tree** (see §5) — must hand-edit this file directly; there is no `EXTENSION.md`/`merge-sources` equivalent present in `dotfiles/.claude/extensions/nvim/` (that directory contains only `manifest.json`) |

**Required edit list for "sonnet everywhere"**:
1. Edit `.claude/extensions/nvim/EXTENSION.md:15` (nvim tree) — change `opus` → `sonnet`. This is the canonical source for the CLAUDE.md section.
2. Re-run the CLAUDE.md section-merge for `extension_nvim` (via `merge.lua`'s `inject_claudemd_section`, invoked by the extension picker/install flow) to regenerate `.claude/CLAUDE.md:663` from the corrected `EXTENSION.md`. If the merge tooling isn't invoked as part of this task's implementation, hand-edit `.claude/CLAUDE.md:663` directly as a stopgap and note it will be overwritten-consistently (not incorrectly) on next regen since the source will already say sonnet.
3. Edit `.claude/extensions/nvim/README.md:36` and `:55` (nvim tree) directly — no generator for this file.
4. Edit `.claude/CLAUDE.md:649` (dotfiles tree) directly — no generator exists locally in that tree.

No `manifest.json` or other merge-source in either tree encodes a `model` field for `neovim-research-agent` (checked `.claude/extensions/nvim/manifest.json` in both trees — no `model` key present), so no manifest edit is needed.

### 5. CLAUDE.md auto-generation caveat — correct edit source per tree

**nvim tree** (`/home/benjamin/.config/nvim/.claude/`):
- `.claude/CLAUDE.md` header states: *"This file is generated automatically from loaded extensions. Do not edit directly."*
- The generator/merge logic lives in **Lua**, not a shell script: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/extensions/merge.lua` (thin wrapper) delegating to `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/merge.lua` (`inject_claudemd_section` / `remove_claudemd_section`, keyed by `section_id`, e.g. `extension_nvim`).
- Each extension declares its `merge_targets.claudemd.source` in its `manifest.json` (e.g. `.claude/extensions/nvim/manifest.json` → `"source": "EXTENSION.md", "target": ".claude/CLAUDE.md", "section_id": "extension_nvim"`). **`EXTENSION.md` is the true edit source** for extension-specific CLAUDE.md sections (e.g. the "Neovim Extension" section).
- The **core** section of CLAUDE.md (Command Reference, Skill-to-Agent Mapping, Model Enforcement paragraph, etc.) is sourced from `.claude/extensions/core/merge-sources/claudemd.md` — confirmed by grep match at line 226 for the exact "Model Enforcement" paragraph text that also appears in `.claude/CLAUDE.md:235`. **This is the edit source for the Model Enforcement paragraph, not `.claude/CLAUDE.md` itself.**
- Separately, `.claude/extensions/core/docs/reference/standards/agent-frontmatter-standard.md` and `.claude/docs/reference/standards/agent-frontmatter-standard.md` are byte-identical (confirmed via `diff`, exit 0) — the `extensions/core/docs/` copy is the source; the top-level `.claude/docs/` copy is synced into place by the Neovim picker's "Load Core" / `Ctrl-l` sync operation, implemented in `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (search for `core_source_base = ".claude/extensions/core"`, confirming for `.claude` base_dir "core artifact categories... are now physically located in `extensions/core/`" and get synced to the base_dir root).
- **Net guidance for nvim tree**: edit `extensions/core/...` (docs) and `extensions/core/merge-sources/claudemd.md` (core CLAUDE.md sections) and `extensions/nvim/EXTENSION.md` (nvim-extension CLAUDE.md section) as the sources of truth, then either invoke the sync/merge tooling (picker `Ctrl-l` / install-extension flow) or hand-edit the generated top-level copies to match as an interim measure — since the sources will already be correct, a subsequent real sync will not clobber the fix, only formalize it.

**dotfiles tree** (`/home/benjamin/.dotfiles/.claude/`):
- `.claude/CLAUDE.md` carries the **same** "generated automatically... do not edit directly" header, but **no local generator exists**: `find /home/benjamin/.dotfiles/.claude/extensions -type f` returns only 5 `manifest.json` files (`core`, `memory`, `nix`, `nvim`, `python`) — no `agents/`, `docs/`, `context/`, `EXTENSION.md`, or `merge-sources/` subdirectories anywhere in the tree.
- `.claude/extensions.json` in the dotfiles tree records `"source_dir": "/home/benjamin/.config/nvim/.claude/extensions/nvim"` for its installed extensions — i.e., the dotfiles tree's `.claude/` content (including its already-generated `CLAUDE.md`, `docs/`, `agents/`) was populated by `install-extension.sh` pulling from the nvim tree at install time, then left as a flat, non-regenerating deployment.
- **Net guidance for dotfiles tree**: there is no in-tree source to edit and no in-tree tooling to regenerate CLAUDE.md/docs. Hand-edit `.claude/CLAUDE.md` and `.claude/docs/...` directly in the dotfiles tree. The "do not edit directly" header is aspirational/inherited from the nvim-tree template and does not reflect an actual local generation capability in this tree; note this as a latent documentation-accuracy issue in the dotfiles tree itself (out of scope for this task, but worth a one-line mention to the planner).

### 6. Full sync-scope file list (both trees)

**Hand-edit directly (no generator involved)**:

| File | Trees | Change |
|------|-------|--------|
| `.claude/extensions/nvim/README.md` | nvim only | Lines 36, 55: `opus` → `sonnet` for neovim-research-agent |
| `.claude/skills/skill-team-research/SKILL.md` | nvim (deployed), dotfiles | Line 217: hardcoded `4.6` → non-version-specific or current wording |
| `.claude/skills/skill-team-plan/SKILL.md` | nvim (deployed), dotfiles | Line 48: same |
| `.claude/skills/skill-team-implement/SKILL.md` | nvim (deployed), dotfiles | Line 49: same |
| `.claude/context/reference/team-wave-helpers.md` | nvim (deployed), dotfiles | Line 388: comment `(Sonnet 4.6)` → drop version number |
| `.claude/CLAUDE.md` | dotfiles only | Line 649 (neovim-research opus→sonnet); no local generator, must hand-edit |
| `.claude/docs/reference/standards/agent-frontmatter-standard.md` | dotfiles only | Lines 53, 72, 111 fixes; no local generator, must hand-edit |

**Edit the source, then sync/regenerate (nvim tree only — has a working generator)**:

| Source file (edit this) | Line(s) | Regenerates / mirrors to |
|---------------------------|---------|----------------------------|
| `.claude/extensions/core/docs/reference/standards/agent-frontmatter-standard.md` | 53, 72, 111 | `.claude/docs/reference/standards/agent-frontmatter-standard.md` (sync.lua "Load Core") |
| `.claude/extensions/core/merge-sources/claudemd.md` | 226 (Model Enforcement paragraph) | `.claude/CLAUDE.md:235` (section merge via `merge.lua`) |
| `.claude/extensions/nvim/EXTENSION.md` | 15 | `.claude/CLAUDE.md` "Neovim Extension" section (`section_id: extension_nvim`, currently `.claude/CLAUDE.md:663`) |
| `.claude/extensions/core/skills/skill-team-research/SKILL.md` | 217 | `.claude/skills/skill-team-research/SKILL.md` |
| `.claude/extensions/core/skills/skill-team-plan/SKILL.md` | 48 | `.claude/skills/skill-team-plan/SKILL.md` |
| `.claude/extensions/core/skills/skill-team-implement/SKILL.md` | 49 | `.claude/skills/skill-team-implement/SKILL.md` |
| `.claude/extensions/core/context/reference/team-wave-helpers.md` | 388 | `.claude/context/reference/team-wave-helpers.md` |

**Note on `.claude/commands/*.md` (research/plan/implement)**: per §3 recommendation, no frontmatter change is proposed in this pass — only the doc rationale (`agent-frontmatter-standard.md` lines 72, 111) changes. If the planner later decides to also change the command default, the same source/deployed-copy split applies: `.claude/extensions/core/commands/{research,plan,implement}.md` are sources in the nvim tree; `.claude/commands/{research,plan,implement}.md` in dotfiles have no generator and would need hand-editing.

## Decisions

- No agent frontmatter re-tiering is proposed; all opus-tier agents in both trees satisfy the explicit KEEP-OPUS criteria.
- The orchestrator-1M mandate text is recommended for relaxation (rationale rewrite only); the 3 orchestrator commands' `model: opus` default frontmatter is recommended to remain unchanged for now (conservative — treat "change the default" as a separate decision).
- `/orchestrate` is explicitly excluded from this task's rationale change — its opus assignment has a different (autonomous decision-quality) justification not addressed by the settled conclusions.
- neovim-research-agent frontmatter needs no change (already sonnet); only 4 prose sites need fixing (2 in nvim EXTENSION.md/README.md that are true generator sources or standalone docs, 1 in nvim CLAUDE.md that should ideally be fixed via EXTENSION.md + resync, 1 in dotfiles CLAUDE.md that must be hand-edited).
- The 12 non-orchestrator slash commands currently carrying `model: opus` are flagged but explicitly out of scope for this task.

## Risks & Mitigations

- **Risk**: Hand-editing generated files (`.claude/CLAUDE.md` in the nvim tree) without also editing the source (`EXTENSION.md` / `merge-sources/claudemd.md`) creates a silent drift that gets clobbered or re-diverges on the next "Load Core" sync.
  **Mitigation**: Always edit the source file first; treat the generated-copy edit as either (a) triggered automatically by re-running the sync tooling, or (b) a manual mirror edit that is now *consistent* with the (already-fixed) source, so a future real sync is a no-op rather than a regression.
- **Risk**: The dotfiles tree has no generator, so its copies can silently diverge from the nvim tree's sources over time with no build-time detection.
  **Mitigation**: Out of scope to fix here, but the planner should note this as a structural gap; `.claude/scripts/check-extension-docs.sh` (nvim tree) may be a starting point for a future cross-tree consistency checker, but it does not currently span repositories.
- **Risk**: Changing the orchestrator-1M rationale text without empirical verification of the native-1M claim could propagate an unverified assumption.
  **Mitigation**: The recommended replacement text explicitly hedges ("verify empirically via `/context` if behavior seems inconsistent") rather than asserting the mechanism as settled fact, per the settled conclusions' own caveat.

## Context Extension Recommendations

- **Topic**: Cross-tree consistency checking for `.claude/` (nvim tree vs. dotfiles tree)
- **Gap**: No documented or tooled mechanism exists to detect drift between the nvim tree's extension-source-of-truth files and the dotfiles tree's flat deployed copies (which have no generator at all). This task's inventory had to be done by hand via parallel `grep` across both trees.
- **Recommendation**: Consider a future meta task to either (a) document the dotfiles tree's deployment model explicitly (e.g., a note in dotfiles `.claude/CLAUDE.md` clarifying it is a one-time install snapshot, not auto-regenerating, contradicting its own "do not edit directly" header), or (b) extend `check-extension-docs.sh` (or a new script) to diff both trees' generated artifacts against their respective sources/snapshots.

## Appendix

### Search queries used

```
grep -rn "79.6\|80.8\|Opus 4.6\|Sonnet 4.6\|opus-4-6\|sonnet-4-6" <tree>
grep -rn "4\.6\b" <tree>   # broadened stale-version sweep
grep -rln "^model: opus" <tree>/agents/*.md <tree>/extensions/*/agents/*.md
grep -rl "^model: opus" <tree>   # full-tree sweep (found command frontmatter too)
grep -rn "neovim-research" <tree>
grep -n "^model:" <various agent/command files>
grep -rln "generated automatically from loaded extensions" <tree>
grep -rln "EXTENSION.md\|claudemd\|section_id" <scripts, lua>
diff <nvim tree docs copy> <nvim tree extensions/core docs copy>
```

### Key files read/inspected

- `/home/benjamin/.config/nvim/.claude/docs/reference/standards/agent-frontmatter-standard.md` (lines 1-120)
- `/home/benjamin/.config/nvim/.claude/extensions/core/merge-sources/claudemd.md`
- `/home/benjamin/.config/nvim/.claude/extensions/nvim/manifest.json`, `EXTENSION.md`, `README.md`
- `/home/benjamin/.dotfiles/.claude/extensions/nvim/manifest.json`, `.claude/extensions.json`
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/extensions/merge.lua`
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/merge.lua`
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
- `.claude/commands/{research,plan,implement,orchestrate}.md` frontmatter in both trees

## RECOMMENDED IMPLEMENTATION

Phased for direct planner consumption:

**Phase 1 — Stale benchmark text (low risk, both trees)**
1. Edit `.claude/extensions/core/docs/reference/standards/agent-frontmatter-standard.md:53` (nvim source) — replace SWE-bench percentage sentence with durable qualitative framing (e.g., "Sonnet 5 delivers near-Opus quality on most pattern-execution work, including coding and agentic tasks; Opus remains the choice for deep analytical reasoning, multi-step planning, and formal verification.").
2. Sync/mirror the same fix to `.claude/docs/reference/standards/agent-frontmatter-standard.md:53` (nvim deployed copy).
3. Apply the identical fix directly to `.claude/docs/reference/standards/agent-frontmatter-standard.md:53` (dotfiles — hand-edit, no source).
4. Fix hardcoded `4.6` in `skill-team-research/SKILL.md:217`, `skill-team-plan/SKILL.md:48`, `skill-team-implement/SKILL.md:49` and mirror `team-wave-helpers.md:388` comment — in nvim `extensions/core/skills/...` (source) + `.claude/skills/...` (deployed) + dotfiles `.claude/skills/...` (hand-edit). Suggest replacing `"... ${teammate_model^} 4.6 for this ..."` with `"... ${teammate_model^} for this ..."` (drop hardcoded version entirely, since `teammate_model` already carries the tier name and hardcoding invites future staleness).

**Phase 2 — Orchestrator-1M rationale relaxation (both trees, docs-only)**
1. Edit `.claude/extensions/core/docs/reference/standards/agent-frontmatter-standard.md:72` (nvim source) with the recommended replacement text from §3.
2. Edit line 111 example comment for consistency.
3. Sync/mirror to `.claude/docs/reference/standards/agent-frontmatter-standard.md` (nvim deployed).
4. Hand-edit `.claude/docs/reference/standards/agent-frontmatter-standard.md:72,111` (dotfiles).
5. Do **not** change `.claude/commands/{research,plan,implement}.md` frontmatter (`model: opus` stays) — decision explicitly deferred per §3.
6. Do **not** touch `.claude/commands/orchestrate.md` or the 12 other command files — out of scope.

**Phase 3 — neovim-research documentation fix (both trees)**
1. Edit `.claude/extensions/nvim/EXTENSION.md:15` (nvim tree, true source) — `opus` → `sonnet`.
2. Regenerate/mirror `.claude/CLAUDE.md:663` (nvim tree) to match (via section-merge tooling or matching hand-edit).
3. Edit `.claude/extensions/nvim/README.md:36,55` (nvim tree) directly — `opus` → `sonnet`.
4. Edit `.claude/CLAUDE.md:649` (dotfiles tree) directly — `opus` → `sonnet`.
5. No agent frontmatter changes needed (already `model: sonnet` everywhere).

**Phase 4 — Verification**
1. Re-grep both trees for `"79.6\|80.8\|Opus 4.6\|Sonnet 4.6"` — expect zero hits.
2. Re-grep both trees for `neovim-research-agent.*opus\|opus.*neovim-research` — expect zero hits.
3. Re-read `agent-frontmatter-standard.md` line 72 in both trees to confirm the relaxed rationale reads correctly and the caveat about `[1m]` being CLI-internal is preserved somewhere in the doc (add if missing).
4. Run `.claude/scripts/check-extension-docs.sh` (nvim tree) if available, to confirm no cross-reference breakage from the EXTENSION.md/README.md edits.

**Explicitly not implemented by this plan** (flag for user/separate task):
- No agent frontmatter re-tiering (none qualified).
- No change to `/orchestrate`'s `model: opus`.
- No change to the 12 non-orchestrator commands currently carrying `model: opus`.
- No change to whether `/research`/`/plan`/`/implement` *default* to opus or sonnet (rationale text only).
