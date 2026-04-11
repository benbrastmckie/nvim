---
title: "Rename talk-agent to slides-agent: Execution Plan"
task: 401
date: 2026-04-10
status: [NOT STARTED]
type: plan
---

# Implementation Plan: Task #401 - Rename talk-agent to slides-agent

- **Task**: 401 - rename_talk_agent_to_slides_agent
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/401_rename_talk_agent_to_slides_agent/reports/01_rename-references-audit.md
- **Artifacts**: plans/01_rename-execution.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, artifact-formats.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Rename the `talk-agent` identifier to `slides-agent` and the `skill-talk` identifier to `skill-slides` across the `present` extension, aligning naming with the already-renamed `/slides` command. The rename is mechanical: two filesystem renames (agent file + skill directory) plus textual substitutions across 8 active files in the extension and 1 top-level schema doc. Semantic English "talk" usage (research talk, talk modes, talk library data layer) is explicitly preserved per task 399's scope boundary. Execution is structured in 6 phases: FS renames first, then JSON/manifest updates, then internal content edits, then top-level doc edits, then verification via grep + extension doc-lint script.

### Research Integration

Research report `01_rename-references-audit.md` provides complete file/line-level inventory. Key findings incorporated:
- 8 active extension files + 1 top-level schema doc require edits
- 2 filesystem renames: `agents/talk-agent.md` -> `agents/slides-agent.md`, `skills/skill-talk/` -> `skills/skill-slides/`
- Library layer `context/project/present/talk/**` must be preserved (task 399 boundary)
- Parallel `.opencode/agent/subagents/talk-agent.md` file may need renaming (to verify)
- Pre-existing tautology bug at `skill-talk/SKILL.md:95` noted for optional fix
- Report glob `*_talk-research.md` in commands/slides.md must be renamed in sync with report template to avoid breaking STAGE 2 Step 3

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (meta naming-cleanup task; not roadmap-tracked).

## Decision Resolution

Six planner decision points from the research report, resolved with the safest defaults per delegation context:

| # | Decision | Choice | Rationale |
|---|----------|--------|-----------|
| 1 | Rename `task_type: "talk"` -> `"slides"`? | **RENAME** | Delegation context specifies "command present:talk -> present:slides" and user task description asks for full consistency. No live state.json entries have `task_type: "talk"` (verified in Phase 0 check). Safest default per delegation instructions is full identifier rename. |
| 2 | Rename routing keys `present:talk` -> `present:slides`? | **RENAME** | Follows from Decision 1. Routing keys must stay aligned with task_type values per extension-task-types.md convention. Delegation context explicitly lists `present:talk -> present:slides`. |
| 3 | Rename `workflow_type: "talk_research"` -> `"slides_research"`? | **RENAME** | Pure internal identifier, cheap to update (5-7 lines across 2 files). Consistency win. |
| 4 | Rename report filename template `{MM}_talk-research.md` -> `{MM}_slides-research.md`? | **RENAME** | Must be renamed in sync with the glob in `commands/slides.md` to avoid breaking STAGE 2 Step 3. Atomic rename in Phase 4 prevents partial-state breakage. |
| 5 | Rename library paths `context/project/present/talk/**`? | **PRESERVE** | Task 399 documented scope boundary. Delegation context explicitly says "preserve semantic 'talk' words" and "preserve specs/ history files". Library is a data layer, not an identifier. |
| 6 | Fix pre-existing tautology bug at `skill-talk/SKILL.md:95`? | **DEFER** | Out of scope for rename task. Flag in summary for potential task 402. Touching validation logic risks scope creep. |

**Additional scope-preservation decisions from delegation context**:
- Skill dir `skill-talk` -> `skill-slides`: **RENAME** (explicit delegation instruction "skill skill-talk -> skill-slides if applicable").
- OpenCode subagent key `"talk"` -> `"slides"`: **RENAME** (follows from agent file rename; structural JSON key change in `opencode-agents.json:63`).
- Semantic "talk" words in prose (e.g., "research talk", "academic talks", "Talk Modes" table headers, "talk library"): **PRESERVE** (explicit delegation instruction).
- `specs/` history files: **PRESERVE** (explicit delegation instruction).
- `forcing_data.talk_type` data schema: **PRESERVE** (data schema, not identifier; would require migration).
- Migration notes "previously named `/talk`" in slides.md:23 and README.md:81: **PRESERVE** (accurate historical record).

## Goals & Non-Goals

**Goals**:
- All identifier occurrences of `talk-agent` replaced with `slides-agent` in the 8 active extension files.
- All identifier occurrences of `skill-talk` replaced with `skill-slides` in the 8 active extension files.
- Filesystem renames completed via `git mv` to preserve history.
- Routing keys `present:talk` renamed to `present:slides` in manifest and top-level schema doc.
- `workflow_type` identifier and report filename template renamed consistently.
- OpenCode parallel tree (`.opencode/agent/subagents/talk-agent.md` if present) renamed.
- Extension doc-lint script `.claude/scripts/check-extension-docs.sh` passes.
- Post-rename grep confirms zero hits for `talk-agent`, `skill-talk`, `present:talk` in active (non-specs, non-library) paths.

**Non-Goals**:
- Modifying `specs/` history (reports, plans, summaries, archives).
- Renaming library layer `context/project/present/talk/**` or any files within it.
- Renaming `forcing_data.talk_type` field or its enum values.
- Rewriting semantic English "talk" prose.
- Fixing the tautology bug at `skill-talk/SKILL.md:95` (defer to separate task).
- Touching task 399 archive summaries that document the preservation boundary.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Accidental substitution of semantic "talk" prose | M | M | Use targeted `Edit` calls with unique context strings (not bare `s/talk/slides/g`). Never use `replace_all` on the bare word "talk". Verify via Phase 6 grep that preserved prose remains intact. |
| Breaking library-layer paths `context/project/present/talk/` | H | L | Explicitly exclude the library subtree from all edits. Verify with `rg 'slides' .claude/extensions/present/context/project/present/talk/` returning empty. |
| Partial rename leaves broken glob `*_talk-research.md` | H | M | Phase 4 atomically updates both the agent report template and the slides.md glob in the same phase. |
| Loaded extension state (running Claude session) breaks mid-rename | M | L | Document in summary that users must reload extension via `<leader>ac` after pulling. Not a rollback-blocking issue. |
| OpenCode parallel file `.opencode/agent/subagents/talk-agent.md` forgotten | M | M | Phase 1 includes explicit `ls` check for the file; Phase 4 renames references. |
| Orphan state.json entry with `task_type: "talk"` | M | L | Phase 0 pre-check greps `specs/state.json` for active `"task_type": "talk"`; if found, note and migrate in Phase 4. |
| False positives in grep verification (Phase 6) | L | M | Use anchored/word-boundary patterns and exclude `specs/` and `context/project/present/talk/` from results. |

## Preserve List (explicit non-rename)

| Token / Path | Why |
|---|---|
| "Research talk", "academic talk", "give a talk", "talk modes" (prose) | English semantic noun; not an identifier |
| "Talk Modes", "Talk Library" section headers | Human-readable prose |
| `forcing_data.talk_type` field + CONFERENCE/SEMINAR/... values | Data schema, not an identifier |
| `.claude/extensions/present/context/project/present/talk/**` | Task 399 scope boundary (library data layer) |
| `talk-structure.md`, `talk/patterns/*`, `talk/contents/**` | Library data paths |
| `specs/**` historical records | Do not rewrite history |
| Migration notes "previously named `/talk`" in slides.md:23, README.md:81 | Accurate migration history |
| `listen more than talk` in funder-research.md:181 | Unrelated prose |
| `skill-talk/SKILL.md:95` tautology bug | Defer to separate task |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |
| 4 | 5 | 2 |
| 5 | 6 | 1, 2, 3, 4, 5 |

Phases 2 and 3 can run in parallel after Phase 1 completes (both modify different JSON files, no overlap). Phase 4 modifies files inside the renamed skill dir and agent file, so it must wait for Phase 1. Phase 5 modifies a top-level doc that depends on the routing-key rename choice committed in Phase 2. Phase 6 is verification.

---

### Phase 1: Filesystem Renames [NOT STARTED]

**Goal**: Atomically rename the agent file and skill directory on disk (and parallel `.opencode` file if present) using `git mv` to preserve history.

**Tasks**:
- [ ] Verify no active `task_type: "talk"` entries in `specs/state.json` (pre-check; note any findings for Phase 4 migration).
- [ ] `git mv .claude/extensions/present/agents/talk-agent.md .claude/extensions/present/agents/slides-agent.md`
- [ ] `git mv .claude/extensions/present/skills/skill-talk .claude/extensions/present/skills/skill-slides`
- [ ] Check if `.opencode/agent/subagents/talk-agent.md` exists; if yes, `git mv` to `slides-agent.md`.
- [ ] Verify renames with `ls` on both new paths.

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/agents/talk-agent.md` -> `slides-agent.md` (rename only)
- `.claude/extensions/present/skills/skill-talk/` -> `skills/skill-slides/` (rename only)
- `.opencode/agent/subagents/talk-agent.md` -> `slides-agent.md` (rename only, if exists)

**Success Criteria**:
- New paths exist; old paths do not.
- `git status` shows renames (not delete+add).
- No other files modified in this phase.

---

### Phase 2: Update manifest.json Routing [NOT STARTED]

**Goal**: Update the extension manifest to point at the renamed agent file, skill directory, and rename routing keys `present:talk` -> `present:slides`.

**Tasks**:
- [ ] Edit `.claude/extensions/present/manifest.json`:
  - Line 8: `"agents": [..., "talk-agent.md"]` -> `"slides-agent.md"`
  - Line 9: `"skills": [..., "skill-talk"]` -> `"skill-slides"`
  - Line 23 (research table): `"present:talk": "skill-talk"` -> `"present:slides": "skill-slides"`
  - Line 31 (plan table): `"present:talk": "skill-planner"` -> `"present:slides": "skill-planner"`
  - Line 39 (implement table): `"present:talk": "skill-talk"` -> `"present:slides": "skill-slides"`
- [ ] Validate JSON parses: `jq . .claude/extensions/present/manifest.json`.

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/manifest.json` - 5 line-level edits (lines 8, 9, 23, 31, 39)

**Success Criteria**:
- `jq` parses the file cleanly.
- No remaining `talk-agent`, `skill-talk`, or `present:talk` tokens in the file.
- Routing keys aligned across research/plan/implement tables.

---

### Phase 3: Update Extension context/index-entries.json + opencode-agents.json [NOT STARTED]

**Goal**: Update JSON files that register the agent in the extension's context-loader index and the opencode parallel agent registry.

**Tasks**:
- [ ] Edit `.claude/extensions/present/index-entries.json`:
  - Line 349: `"agents": ["talk-agent"]` -> `["slides-agent"]` (presentation-types.md entry)
  - Line 363: `"agents": ["talk-agent"]` -> `["slides-agent"]` (talk-structure.md entry; NOTE: keep the library filename "talk-structure.md" unchanged in the path field)
  - Preserve lines 343, 344, 354, 357, 358 (semantic keyword tags).
  - Preserve `"commands": ["/slides"]` (already correct).
- [ ] Edit `.claude/extensions/present/opencode-agents.json`:
  - Line 63: Structural JSON key rename `"talk": {` -> `"slides": {`
  - Line 66: `"prompt": "{file:.opencode/agent/subagents/talk-agent.md}"` -> `"...slides-agent.md}"`
- [ ] Validate both JSON files parse: `jq . <file>`.

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/index-entries.json` - 2 line-level edits (lines 349, 363)
- `.claude/extensions/present/opencode-agents.json` - 2 line-level edits (lines 63, 66)

**Success Criteria**:
- Both files are valid JSON.
- No remaining `talk-agent` tokens in either file.
- `opencode-agents.json` has top-level key `slides` (not `talk`).
- `index-entries.json` path field `talk-structure.md` preserved unchanged (library preservation).

---

### Phase 4: Update Internal References in Extension Files [NOT STARTED]

**Goal**: Update all internal identifier references inside the renamed agent file, the renamed skill file, the commands/slides.md file, EXTENSION.md, and README.md.

**Tasks**:

**4.1 `.claude/extensions/present/agents/slides-agent.md`** (already renamed in Phase 1):
- [ ] Line 2: `name: talk-agent` -> `name: slides-agent`
- [ ] Preserve line 3 (semantic "Research talk material synthesis agent...")
- [ ] Line 7: `# Talk Agent` -> `# Slides Agent`
- [ ] Line 11: `Invoked by \`skill-talk\`` -> `Invoked by \`skill-slides\`` (preserve "research talks" prose earlier on line)
- [ ] Line 17: `- **Name**: talk-agent` -> `- **Name**: slides-agent`
- [ ] Line 19: `- **Invoked By**: skill-talk` -> `skill-slides`
- [ ] Line 86: `"agent_type": "talk-agent"` -> `"slides-agent"`
- [ ] Line 88: `"delegation_path": ["orchestrator", "talk", "skill-talk", "talk-agent"]` -> `["orchestrator", "slides", "skill-slides", "slides-agent"]`
- [ ] Line 103: `"task_type": "talk"` -> `"slides"` (Decision 1: rename)
- [ ] Line 106: `"workflow_type": "talk_research"` -> `"slides_research"` (Decision 3)
- [ ] Lines 185, 235: `reports/{MM}_talk-research.md` -> `reports/{MM}_slides-research.md` (Decision 4)
- [ ] Line 242: `"agent_type": "talk-agent"` -> `"slides-agent"`
- [ ] Line 243: `"workflow_type": "talk_research"` -> `"slides_research"`
- [ ] Line 245: `"delegation_path": [..., "talk-agent"]` -> `[..., "slides-agent"]`
- [ ] Preserve lines 46-61 (library paths `talk/index.json`, `talk-structure.md`, `talk/patterns/*`).
- [ ] Preserve lines 121-124 pattern table (library paths).
- [ ] Preserve lines 148, 198, 216, 236, 286 (semantic "talk content", "talk type" prose).

**4.2 `.claude/extensions/present/skills/skill-slides/SKILL.md`** (already renamed in Phase 1):
- [ ] Line 2: `name: skill-talk` -> `name: skill-slides`
- [ ] Line 3: `description: Research talk material synthesis ... Invoke for talk tasks.` -> `...Invoke for slides tasks.` (preserve "Research talk material" prose; rename only the final "talk tasks" identifier phrase)
- [ ] Line 13: `# Talk Skill` -> `# Slides Skill`
- [ ] Line 15: `delegates talk research work to \`talk-agent\`` -> `delegates slides research work to \`slides-agent\``
- [ ] Line 43: `routes to talk-agent` -> `routes to slides-agent`
- [ ] Lines 45-47: `talk_research` workflow_type references -> `slides_research` (Decision 3)
- [ ] Lines 105-121, 220-223, 268: `talk_research` -> `slides_research`
- [ ] Line 147: `"skill": "skill-talk"` -> `"skill-slides"`
- [ ] Line 165: `"delegation_path": ["orchestrator", "slides", "skill-talk"]` -> `[..., "skill-slides"]`
- [ ] Line 189: `subagent_type: "talk-agent"` -> `"slides-agent"`
- [ ] Line 194: `Skill(talk-agent)` -> `Skill(slides-agent)`
- [ ] Line 60, 74, 172, 302-303: `task_type: "talk"` -> `"slides"` (Decision 1)
- [ ] Preserve line 95 tautology bug (Decision 6: defer).
- [ ] Preserve lines 6-7 library path comments in YAML frontmatter.
- [ ] Preserve lines 35-36 semantic "talk tasks" comments (if in prose context).
- [ ] Lines 239-242 (`commit_action="complete talk research"`): preserve prose ("talk research" is an English phrase describing the work product, not an identifier).

**4.3 `.claude/extensions/present/commands/slides.md`**:
- [ ] Preserve line 23 migration note "This command was previously named `/talk`" (accurate history).
- [ ] Line 154: `delegate to skill-talk for research` -> `delegate to skill-slides`
- [ ] Line 195: `task_type is "talk"` -> `"slides"` (Decision 1)
- [ ] Line 253: `delegate to skill-talk for research` -> `delegate to skill-slides`
- [ ] Line 264: `task_type is talk` -> `task_type is slides`
- [ ] Line 272: `skill: "skill-talk"` -> `"skill-slides"`
- [ ] Line 286: report path reference `*_talk-research.md` -> `*_slides-research.md` (Decision 4)
- [ ] Line 308: `task_type` comment -> align with slides
- [ ] Line 323: glob `*_talk-research.md` -> `*_slides-research.md` (Decision 4)
- [ ] Line 424: `task_type` reference -> slides
- [ ] Line 428: `| \`/research N\` | skill-talk | ...` -> `| \`/research N\` | skill-slides | ...`
- [ ] Line 430: `| \`/implement N\` | skill-talk (assemble) | ...` -> `skill-slides (assemble)`
- [ ] Preserve prose lines: 14, 18, 57, 59, 73, 400 ("confirm talk design"), 442 ("for talk tasks" — if appears as prose description).

**4.4 `.claude/extensions/present/EXTENSION.md`**:
- [ ] Line 13: `| skill-talk | talk-agent | opus | Research talk material synthesis and presentation assembly |` -> `| skill-slides | slides-agent | opus | Research talk material synthesis and presentation assembly |` (preserve description prose)
- [ ] Line 41: `| \`present\` | \`talk\` | \`skill-talk\` | \`skill-talk\` | ... |` -> `| \`present\` | \`slides\` | \`skill-slides\` | \`skill-slides\` | ...`
- [ ] Preserve line 55 "The talk library at `context/project/present/talk/` contains:" (library prose).
- [ ] Preserve line 56 "Patterns: Slide structure definitions for each talk mode" (prose).
- [ ] Preserve lines 43, 53, 79 "Talk Modes" / "Talk Library" section headers.

**4.5 `.claude/extensions/present/README.md`**:
- [ ] Preserve line 81 migration note (accurate history).
- [ ] Preserve line 88 library path.
- [ ] No identifier changes (talk-agent not mentioned); verify with grep.

**Timing**: 40 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- `.claude/extensions/present/agents/slides-agent.md` - ~12 line-level edits
- `.claude/extensions/present/skills/skill-slides/SKILL.md` - ~17 line-level edits
- `.claude/extensions/present/commands/slides.md` - ~11 line-level edits
- `.claude/extensions/present/EXTENSION.md` - 2 line-level edits
- `.claude/extensions/present/README.md` - verification only

**Success Criteria**:
- No `talk-agent` tokens remain in any of the 5 files.
- No `skill-talk` tokens remain in any of the 5 files.
- No `present:talk` tokens remain.
- No `talk_research` workflow_type tokens remain.
- No `*_talk-research.md` glob patterns remain.
- Prose references ("research talk", "Talk Modes" header, migration notes) are intact.
- YAML frontmatter in renamed files is valid.

---

### Phase 5: Update Top-Level Schema Doc [NOT STARTED]

**Goal**: Update the one top-level `.claude/` reference doc that cites the `present:talk` compound routing value as an example.

**Tasks**:
- [ ] Edit `.claude/context/reference/state-management-schema.md`:
  - Line 84: `- **Compound values**: \`present:grant\`, \`founder:deck\`, \`present:talk\`, etc.` -> `- **Compound values**: \`present:grant\`, \`founder:deck\`, \`present:slides\`, etc.`
- [ ] Verify no other top-level files reference `talk-agent`, `skill-talk`, or `present:talk` (grep outside `specs/` and outside `extensions/present/context/project/present/talk/`).

**Timing**: 5 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/context/reference/state-management-schema.md` - 1 line edit (line 84)

**Success Criteria**:
- Example updated.
- Grep of `.claude/context/` and `.claude/docs/` and `.claude/rules/` for `present:talk` returns zero hits.
- `specs/` directory untouched.

---

### Phase 6: Verification [NOT STARTED]

**Goal**: Confirm zero residual identifier references in active paths, library layer untouched, and extension doc-lint passes.

**Tasks**:
- [ ] `rg 'talk-agent' .claude/extensions/present/` -> expect 0 hits
- [ ] `rg 'skill-talk' .claude/extensions/present/` -> expect 0 hits
- [ ] `rg 'present:talk' .claude/` (excluding `specs/`) -> expect 0 hits
- [ ] `rg 'talk_research' .claude/extensions/present/` -> expect 0 hits
- [ ] `rg '_talk-research\.md' .claude/extensions/present/` -> expect 0 hits
- [ ] `rg '\btalk\b' .claude/extensions/present/context/project/present/talk/` -> expect unchanged (library preserved)
- [ ] `rg '\btalk\b' .claude/extensions/present/agents/ .claude/extensions/present/skills/ .claude/extensions/present/commands/ .claude/extensions/present/manifest.json .claude/extensions/present/EXTENSION.md .claude/extensions/present/README.md` -> inspect hits manually; expect only semantic/prose occurrences (e.g., "research talk", "Talk Modes" header, migration notes)
- [ ] `jq . .claude/extensions/present/manifest.json .claude/extensions/present/index-entries.json .claude/extensions/present/opencode-agents.json` -> expect all valid
- [ ] `bash .claude/scripts/check-extension-docs.sh` -> expect exit code 0
- [ ] `ls .claude/extensions/present/agents/slides-agent.md .claude/extensions/present/skills/skill-slides/SKILL.md` -> expect both present
- [ ] `ls .claude/extensions/present/agents/talk-agent.md .claude/extensions/present/skills/skill-talk/ 2>/dev/null` -> expect empty (old paths gone)
- [ ] Verify library file count unchanged: `find .claude/extensions/present/context/project/present/talk/ -type f | wc -l` matches pre-rename count.

**Timing**: 15 minutes

**Depends on**: 1, 2, 3, 4, 5

**Files to modify**: none (verification only)

**Success Criteria**:
- All grep checks above return expected results.
- Extension doc-lint script passes.
- JSON files all parse.
- Filesystem shows only new paths, not old.
- Library layer unchanged.

---

## Testing & Validation

- [ ] All six phases complete with success criteria met
- [ ] Phase 6 grep verification passes (zero identifier residuals)
- [ ] Extension doc-lint script `.claude/scripts/check-extension-docs.sh` exits 0
- [ ] JSON files (manifest.json, index-entries.json, opencode-agents.json) parse cleanly
- [ ] Git status shows renames (not delete+add) for the two FS operations
- [ ] Library layer file count unchanged before and after

## Artifacts & Outputs

- Renamed: `.claude/extensions/present/agents/slides-agent.md`
- Renamed: `.claude/extensions/present/skills/skill-slides/` (and contents)
- Renamed: `.opencode/agent/subagents/slides-agent.md` (if parallel file existed)
- Modified: `.claude/extensions/present/manifest.json`
- Modified: `.claude/extensions/present/index-entries.json`
- Modified: `.claude/extensions/present/opencode-agents.json`
- Modified: `.claude/extensions/present/commands/slides.md`
- Modified: `.claude/extensions/present/EXTENSION.md`
- Verified unchanged: `.claude/extensions/present/README.md`
- Modified: `.claude/context/reference/state-management-schema.md`
- Implementation summary: `specs/401_rename_talk_agent_to_slides_agent/summaries/01_rename-execution-summary.md`

## Rollback/Contingency

- **Single-phase rollback**: `git checkout -- <file>` for textual edits in Phases 2-5.
- **Full rollback**: `git reset --hard HEAD` (before commit) or `git revert <commit-sha>` (after commit) to undo all filesystem renames and edits atomically.
- **Partial rollback during Phase 4**: Each sub-phase (4.1-4.5) is independently revertible via `git checkout --`. If Phase 6 verification surfaces a residual, targeted Edit calls can patch without full rollback.
- **Emergency fallback**: If the rename breaks the loaded extension mid-session, users reload via `<leader>ac` or restart Claude Code; no persistent state corruption is possible because state.json is not modified by this task (only pre-check read).
