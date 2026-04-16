---
next_project_number: 456
---

# TODO

## Task Order

*Updated 2026-04-16. 14 active tasks remaining.*

### Pending

- **455** [NOT STARTED] -- Separate model selection from effort flags, add --haiku and --sonnet
- **454** [NOT STARTED] -- Memory system documentation and end-to-end validation (depends: 448, 453)
- **453** [NOT STARTED] -- Integrate /distill with /todo suggestions and retrieval tombstone filtering (depends: 447, 452)
- **452** [NOT STARTED] -- Implement distill compress and refine operations (depends: 450, 451)
- **451** [NOT STARTED] -- Implement distill combine operation with keyword superset guarantee (depends: 449)
- **450** [NOT STARTED] -- Implement distill purge operation with tombstone pattern (depends: 449)
- **449** [NOT STARTED] -- Create /distill command with scoring engine and health report (depends: 444)
- **448** [NOT STARTED] -- Add passive memory nudge stop hook (depends: 446)
- **447** [NOT STARTED] -- Upgrade /todo memory harvest with pre-classification and batch review (depends: 446)
- **446** [NOT STARTED] -- Add memory candidate emission to agents and return metadata (depends: 445)
- **445** [NOT STARTED] -- Implement two-phase auto-retrieval for memory system (depends: 444)
- **444** [NOT STARTED] -- Create skill-memory with /learn command and memory index infrastructure
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 455. Separate model selection from effort flags, add --haiku and --sonnet
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta

**Description**: Refactor the `/research`, `/implement`, and `/plan` command flag system to separate two currently conflated concerns: **model selection** (which model family to use) and **effort level** (how deeply the model reasons). Currently `--fast` maps to Sonnet and `--hard`/`--opus` both map to Opus, conflating "cheaper model" with "less effort" and "expensive model" with "more effort". These should be independent dimensions, and the missing `--haiku` and `--sonnet` model flags should be added.

**Current state (problematic)**:
- `--fast` → Sonnet (conflates effort with model choice)
- `--hard` → Opus (conflates effort with model choice)
- `--opus` → Opus (alias for `--hard`)
- No `--haiku` or `--sonnet` flags
- Only `/research` and `/implement` support flags; `/plan` has no model flags
- Agent frontmatter standard only documents `opus` and `sonnet` (no `haiku`)
- Docs claim agents default to Sonnet but actual agent files declare `model: opus` (task 442 inconsistency)
- Team mode skills hardcode `default_model="sonnet"` and ignore model flags entirely

**Target state**:

Two orthogonal flag dimensions:

| Flag | Dimension | Effect |
|------|-----------|--------|
| `--fast` | Effort | Lighter reasoning, faster output |
| `--hard` | Effort | Deeper reasoning, more thorough analysis |
| `--haiku` | Model | Use latest Haiku (currently claude-haiku-4-5) |
| `--sonnet` | Model | Use latest Sonnet (currently claude-sonnet-4-6) |
| `--opus` | Model | Use latest Opus (currently claude-opus-4-6) |

The Agent tool's `model` parameter already accepts `"haiku"`, `"sonnet"`, and `"opus"` and resolves to the latest version of each family, so model flags avoid staleness by design.

**Effort dimension**: `--fast` and `--hard` should influence reasoning depth without changing the model. If combined with a model flag, they compose (e.g., `--hard --haiku` = deep reasoning on Haiku). If used alone without a model flag, effort flags should still apply to whatever model the agent defaults to. Implementation options:
- Prompt-level guidance injected into delegation context (e.g., "Use thorough, step-by-step reasoning" for `--hard`; "Prioritize speed and conciseness" for `--fast`)
- Or mapped to the agent's reasoning effort parameter if available

**Composability**: Model and effort flags compose freely:
- `/research 42 --opus --hard` = Opus with deep reasoning
- `/research 42 --haiku --fast` = Haiku with light reasoning
- `/research 42 --hard` = default model with deep reasoning
- `/research 42 --sonnet` = Sonnet with default effort
- If conflicting flags of the same dimension are given, last one wins

**Files requiring changes**:

1. **Commands** (flag parsing):
   - `.claude/commands/research.md` -- Replace current 3-flag parsing with 5-flag two-dimension parsing; pass both `model_flag` and `effort_flag` to skill
   - `.claude/commands/implement.md` -- Same changes as research.md
   - `.claude/commands/plan.md` -- Add model and effort flag support (currently has none)

2. **Skills** (flag handling and delegation):
   - `.claude/skills/skill-researcher/SKILL.md` -- Accept both `model_flag` and `effort_flag`; pass model to Agent tool's `model` parameter; inject effort guidance into delegation prompt
   - `.claude/skills/skill-implementer/SKILL.md` -- Same changes
   - `.claude/skills/skill-planner/SKILL.md` -- Same changes
   - `.claude/skills/skill-team-research/SKILL.md` -- Accept and propagate model/effort flags instead of hardcoding `default_model="sonnet"`
   - `.claude/skills/skill-team-implement/SKILL.md` -- Same changes
   - `.claude/skills/skill-team-plan/SKILL.md` -- Same changes
   - `.claude/skills/skill-orchestrator/SKILL.md` -- Pass flags through to routed skills

3. **Agent frontmatter standard**:
   - `.claude/docs/reference/standards/agent-frontmatter-standard.md` -- Add `haiku` as valid model value; document the two-dimension flag system; update examples; fix the sonnet-vs-opus default inconsistency

4. **Agent files** (fix task 442 inconsistency):
   - All 7 core agents in `.claude/agents/` -- Verify and correct `model:` frontmatter to match the intended default (resolve the docs-say-sonnet-but-files-say-opus discrepancy)
   - All extension agents -- Same verification

5. **CLAUDE.md documentation**:
   - `.claude/CLAUDE.md` -- Update Model Enforcement paragraph and command reference table to document both dimensions; add flag examples

6. **Extension commands** (propagate flag support):
   - Check all extension commands that delegate to skills (e.g., present extension's slides command) and ensure model/effort flags are parsed and propagated consistently

**Verification**:
- `/research 42 --opus` spawns agent with `model: "opus"`
- `/research 42 --haiku` spawns agent with `model: "haiku"`
- `/research 42 --sonnet` spawns agent with `model: "sonnet"`
- `/research 42 --fast` uses default model but adds effort guidance to prompt
- `/research 42 --hard --haiku` spawns Haiku agent with deep reasoning guidance
- `/plan 42 --opus` works (currently unsupported)
- `--fast --hard` → last wins (`--hard`)
- `--haiku --opus` → last wins (`--opus`)
- Agent frontmatter `model:` values match documented defaults
- Team mode skills respect model flags instead of hardcoding sonnet

---

### 454. Memory system documentation and end-to-end validation
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Tasks #448, #453

**Description**: Comprehensive documentation update and end-to-end validation for the complete memory system (both self-learning memory from tasks 444-448 and distillation from tasks 449-453). This is the capstone task that validates everything works together.

**Documentation updates:**
1. **`.claude/CLAUDE.md` Memory Extension section**: Create a complete Memory Extension section documenting: memory-index.json schema, two-phase retrieval mechanism, auto-retrieval default with `--clean` opt-out, memory candidate emission from agents, `/todo` harvest workflow with pre-classification, `/distill` command with all flags, memory_health state.json field, and the full memory lifecycle (`/learn` create -> retrieval use -> `/todo` harvest capture -> `/distill` maintain).
2. **`.claude/skills/skill-memory/README.md`**: Add distill mode documentation with flag reference, scoring engine parameters, tombstone pattern and `--gc` lifecycle, distill-log.json schema, and the relationship between `/learn`, `/todo` harvest, and `/distill`.
3. **`.claude/context/index.json`**: Add entries for all new memory-related context files (distill-usage.md, memory-index schema docs, etc.). Verify all memory-related entries are current.
4. **`.claude/context/project/memory/distill-usage.md`** (new): Create usage guide for `/distill` documenting the lifecycle: `/learn` (create) -> retrieval (use) -> `/todo` harvest (capture) -> `/distill` (maintain).
5. **`/memory --reindex` documentation**: Document force-regeneration of `memory-index.json` from filesystem state for manual recovery.

**End-to-end validation:**
- Run `/research N` on a test task and verify memories are automatically injected via index-based two-phase retrieval (no `--remember` flag needed)
- Run `/research N --clean` and verify no memories are injected
- Verify `memory-index.json` is valid JSON with all required fields after generation
- Verify validate-on-read detects stale index (add a memory file without running /learn, then trigger retrieval)
- Complete a research and implementation cycle, then run `/todo` and verify memory candidates appear with pre-classification
- Approve memory candidates in `/todo` and verify MEM-*.md files are created with correct frontmatter
- Verify retrieval statistics accumulate correctly across multiple operations
- Verify Stop hook fires only after lifecycle command completion
- Run `/distill` bare and verify health report with correct metrics
- Verify each `/distill` flag parses correctly and routes to the right operation
- Manually verify scoring for at least 3 memories (staleness, zero-retrieval penalty, size penalty, composite)
- Verify tombstoned memories are excluded from retrieval scoring
- Verify token budget enforcement: injected memories never exceed 3000 tokens total
- Verify vault stays under 50 files after typical usage cycle

**Source**: Plan 68 Phase 6 + Plan 69 Phase 6 (combined)

---

### 453. Integrate /distill with /todo suggestions and retrieval tombstone filtering
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Tasks #447, #452

**Description**: Wire up the distillation system with `/todo` for conditional maintenance suggestions, and update memory retrieval to skip tombstoned memories. This connects the two major subsystems (self-learning memory and distillation).

**`/todo` conditional suggestions:**
- Update `.claude/skills/skill-todo/SKILL.md` output section to add conditional "Next Steps":
  - Read `memory_health` from state.json (or compute if absent)
  - Always suggest `/review` after archival (unconditional)
  - Suggest `/distill --report` when `total_memories >= 10` (awareness tier)
  - Suggest `/distill` (full interactive) when ANY of:
    - `total_memories >= 30`
    - `never_retrieved / total_memories > 0.5` (and total_memories >= 5)
    - `last_distilled` older than 30 days (or null and total_memories >= 10)
  - Suppress all `/distill` suggestions when `total_memories < 5`
  - Format as numbered list: `1. Review archive... 2. Run /review... 3. Run /distill to maintain memory vault ({N} memories, {health_score}/100 health)`

**Retrieval tombstone filtering:**
- Add `status` field to `memory-index.json` entry schema (default: `"active"`, set to `"tombstoned"` when tombstoned)
- Update memory retrieval logic (documented in skill-researcher, skill-planner, skill-implementer) to filter: skip entries where `status == "tombstoned"` during two-phase retrieval scoring
- Update index regeneration in skill-memory to read `status` from memory file frontmatter and include in index entries

**State tracking:**
- Ensure `/distill` updates `memory_health` in state.json after every invocation: recount total_memories (excluding tombstoned), never_retrieved, recalculate health_score, update `last_distilled` timestamp and increment `distill_count` (only for non-bare invocations that perform operations)

**Files to modify**: `.claude/skills/skill-todo/SKILL.md`, `.claude/skills/skill-memory/SKILL.md`, `specs/state.json`

**Source**: Plan 69 Phase 5

---

### 452. Implement distill compress and refine operations
- **Effort**: large
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Tasks #450, #451

**Description**: Implement COMPRESS (reduce verbose memories to key points) and REFINE (fix metadata quality issues) operations for `/distill`, plus the `--auto` flag for safe automatic operations.

**Compress operation (`--compress`):**
- Candidate identification: select memories where `token_count > 600`
- Present candidates via AskUserQuestion with multiSelect showing token count, topic, retrieval count
- Compression execution for each selected memory:
  - Read full content, generate compressed version: extract key points, preserve code blocks and examples, remove redundant prose
  - Move original content to `## History > ### Pre-Compression ({date})` section (same pattern as UPDATE operation in skill-memory)
  - Recalculate `token_count` in frontmatter
  - **Preserve all keywords** -- compression must not drop keywords
- Log to distill-log.json with tokens_before, tokens_after, compression_ratio, keywords_preserved

**Refine operation (implicit, runs with `--auto` or standalone):**
- Candidate identification for metadata quality issues:
  - Missing or sparse keywords: memories with < 4 keywords
  - Duplicate keywords within a single memory
  - Missing `summary` field in frontmatter
  - Missing or incorrect category classification
  - Topic path inconsistencies
- **Automatic fixes** (no confirmation needed, run with `--auto`):
  - Deduplicate keywords within each memory
  - Add missing summary field (generate from first line of content)
  - Normalize topic paths (lowercase, consistent separators)
- **Interactive fixes** (require confirmation):
  - Keyword enrichment: suggest additional keywords based on content analysis
  - Category reclassification: suggest category changes based on content
  - Topic path correction: suggest topic changes based on cluster analysis

**`--auto` flag execution:**
- Run refine automatic fixes (keyword dedup, summary generation, topic normalization)
- Rebuild memory-index.json from filesystem state (validate-on-read regeneration)
- Update memory_health in state.json
- Skip all interactive operations
- Log all changes to distill-log.json

**Files to modify**: `.claude/skills/skill-memory/SKILL.md`, `.claude/commands/distill.md`, `.memory/distill-log.json`

**Source**: Plan 69 Phase 4

---

### 451. Implement distill combine operation with keyword superset guarantee
- **Effort**: large
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Task #449

**Description**: Implement the COMBINE operation for `/distill --merge` that identifies duplicate/overlapping memories, presents merge candidates by topic cluster, merges selected pairs with keyword superset enforcement, and updates cross-references.

**Merge candidate identification:**
- For each topic cluster, compute pairwise keyword overlap between all memories
- Pair memories where overlap > 60%
- Rank pairs by overlap score descending
- Group candidates by topic cluster for presentation

**Interactive selection:**
- Present merge candidates via AskUserQuestion per topic cluster:
  - `"Topic: {cluster_name} - Select pairs to merge ({N} candidates):"`
  - Options: `"Merge: MEM-{a} + MEM-{b}"` with overlap percentage and shared keywords

**Merge execution for each selected pair:**
- Determine primary memory (higher retrieval_count, or older if equal)
- Merge content: primary content + `## Merged From {secondary}` section with secondary content
- **Keyword superset guarantee**: `merged_keywords = union(primary.keywords, secondary.keywords)` -- verify `len(merged_keywords) >= len(union)`, fail merge if not satisfied
- Update frontmatter: `modified = today`, merge combined `retrieval_count`, keep earliest `created` date
- Tombstone the secondary memory (same tombstone pattern as purge, with `tombstone_reason: "merged_into:{primary_id}"`)

**Post-merge cleanup:**
- Update Connections sections: scan all memories for `[[{secondary_id}]]` references, replace with `[[{primary_id}]]`
- Regenerate memory-index.json and index.md after all merges complete

**Logging**: Each merge logged to distill-log.json with primary, secondary, overlap_score, keywords_before/after, keyword_superset_verified flag, pre/post metrics

**Files to modify**: `.claude/skills/skill-memory/SKILL.md`, `.claude/commands/distill.md`, `.memory/distill-log.json`

**Source**: Plan 69 Phase 3

---

### 450. Implement distill purge operation with tombstone pattern
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Task #449

**Description**: Implement the PURGE operation for `/distill --purge` that identifies stale memories, presents them for interactive selection, tombstones selected entries, and provides `--gc` for hard deletion after grace period.

**Purge candidate identification:**
- Select memories where `zero_retrieval_penalty == 1.0` (retrieval_count == 0 AND days_since_created > 30) OR `staleness_score > 0.8`
- Category-aware TTL advisory thresholds (used for ranking, not automatic action):
  - CONFIG: 180 days, WORKFLOW: 365 days, PATTERN: 540 days, TECHNIQUE: 270 days, INSIGHT: no TTL

**Interactive selection:**
- Present candidates via AskUserQuestion with multiSelect showing score, created date, retrieval count, token count per memory

**Tombstone pattern for selected memories:**
- Add `status: tombstoned`, `tombstoned_at: ISO8601`, `tombstone_reason: "purge"` to memory frontmatter
- Do NOT delete file; do NOT remove from index
- Tombstoned memories are excluded from retrieval (update retrieval scoring to skip `status: tombstoned`)

**`--gc` flag for hard deletion:**
- Scan for tombstoned memories where `tombstoned_at` is older than 7-day grace period
- Present list via AskUserQuestion for confirmation
- On confirmation: delete memory files, remove from memory-index.json, regenerate index.md
- Log deletion to distill-log.json

**Link-scan step**: After tombstoning, scan all non-tombstoned memories for `[[MEM-{affected-slug}]]` references in Connections sections; warn user about stale links

**Logging**: Each purge logged to distill-log.json with memories_affected, action (tombstoned/deleted), scores, pre/post metrics

**Files to modify**: `.claude/skills/skill-memory/SKILL.md`, `.claude/commands/distill.md`, `.memory/distill-log.json`

**Source**: Plan 69 Phase 2

---

### 449. Create /distill command with scoring engine and health report
- **Effort**: large
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Task #444

**Description**: Build the `/distill` command, distillation scoring engine, health report generator, distill-log infrastructure, and `memory_health` state.json field. This is the foundation for all distillation operations (purge, combine, compress, refine).

**Command file** (`.claude/commands/distill.md`):
- Argument parsing for: bare (health report), `--purge`, `--merge`, `--compress`, `--auto`, `--gc` flags
- Route each flag to the appropriate operation section in skill-memory's `mode=distill` pipeline

**Scoring engine** (in `.claude/skills/skill-memory/SKILL.md` `mode=distill` section):
- Composite score calculation from four components:
  - **Staleness**: `days_since_last_retrieval / 90` (capped at 1.0), with FSRS-inspired adjustment: `if retrieval_count > 0 AND days_since_created > 60: reduce staleness by 0.3`
  - **Zero-retrieval penalty**: `1.0 if retrieval_count == 0 AND days_since_created > 30, else 0.0`
  - **Size penalty**: `max(0, (token_count - 600) / 600)` (linear penalty above 600 tokens)
  - **Duplicate score**: highest keyword overlap with any other memory
  - **Composite**: `(staleness * 0.3) + (zero_retrieval * 0.25) + (size * 0.2) + (duplicate * 0.25)`
- Topic-cluster grouping: group memories by topic prefix before scoring, process clusters independently

**Health report** (bare `/distill` invocation):
- Total memories, total tokens, average tokens per memory
- Category distribution (PATTERN, CONFIG, WORKFLOW, TECHNIQUE, INSIGHT)
- Topic cluster sizes
- Retrieval statistics: retrieved at least once vs never retrieved, most/least retrieved
- Purge candidates (zero-retrieval > 30 days), merge candidates (overlap > 60%), compress candidates (> 600 tokens)
- Overall health score: `100 - (purge_candidates * 3) - (merge_candidates * 5) - (compress_candidates * 2)`, clamped to 0-100

**Distill-log** (`.memory/distill-log.json`):
```json
{
  "version": 1,
  "operations": [],
  "summary": {
    "total_operations": 0,
    "last_distilled": null,
    "memories_purged": 0,
    "memories_merged": 0,
    "memories_compressed": 0,
    "memories_refined": 0
  }
}
```

**State tracking** (`memory_health` in state.json):
```json
"memory_health": {
  "last_distilled": null,
  "distill_count": 0,
  "total_memories": N,
  "never_retrieved": N,
  "health_score": 100,
  "status": "healthy"
}
```

**Files to create**: `.claude/commands/distill.md`, `.memory/distill-log.json`
**Files to modify**: `.claude/skills/skill-memory/SKILL.md`, `specs/state.json`

**Source**: Plan 69 Phase 1

---

### 448. Add passive memory nudge stop hook
- **Effort**: small
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Task #446

**Description**: Add a lightweight Stop hook that detects completed lifecycle operations and prints a one-line reminder about memory capture, increasing user awareness without any writes or state changes.

**Hook script** (`.claude/hooks/memory-nudge.sh`):
- Check if the just-completed response involved `/research`, `/implement`, or `/plan` completion
- If yes, print: `Memory: artifacts available for /learn --task N`
- Uses only echo (no file writes, no MCP calls, no state changes)
- Is idempotent and non-blocking

**Settings integration:**
- Add Stop hook entry to `.claude/settings.json` hooks array referencing the new script
- Test that the hook fires after lifecycle command completion and does not fire for non-lifecycle operations

**Files to create**: `.claude/hooks/memory-nudge.sh`
**Files to modify**: `.claude/settings.json`

**Source**: Plan 68 Phase 5

---

### 447. Upgrade /todo memory harvest with pre-classification and batch review
- **Effort**: large
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Task #446

**Description**: Upgrade `/todo` Stage 7 (HarvestMemories) to collect memory candidates from completed task metadata, apply three-tier pre-classification, and present a single batch AskUserQuestion for user approval. Approved memories are created using a new autonomous code path with proper index regeneration.

**Stage 7 (HarvestMemories) modifications:**
- Collect `memory_candidates` from state.json for each completed task being archived
- Implement three-tier pre-classification:
  - **Tier 1** (pre-selected): PATTERN or CONFIG category with confidence >= 0.8
  - **Tier 2** (presented, not pre-selected): WORKFLOW or TECHNIQUE with confidence >= 0.5
  - **Tier 3** (hidden by default): INSIGHT or confidence < 0.5

**Deduplication step:**
- For each candidate, query `memory-index.json` keywords for overlap
- If keyword overlap > 60%, mark as potential UPDATE instead of CREATE
- If overlap > 90%, mark as NOOP and exclude

**Stage 9 (InteractivePrompts) modification:**
- Present pre-classified candidates in a single AskUserQuestion with Tier 1 pre-selected, Tier 2 as options, Tier 3 hidden (shown only if user requests)

**Stage 14 (CreateMemories) modification:**
- Implement autonomous memory creation for approved candidates -- write MEM-{slug}.md files directly (bypassing skill-memory's per-segment interactive flow) with proper frontmatter including `retrieval_count: 0`, `last_retrieved: null`, `keywords` from `suggested_keywords`, and `summary`
- Regenerate `memory-index.json` after creating memories (reuse the index regeneration pattern from task 444)

**Files to modify**: `.claude/skills/skill-todo/SKILL.md`

**Source**: Plan 68 Phase 4

---

### 446. Add memory candidate emission to agents and return metadata
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Task #445

**Description**: Extend the return metadata schema so agents can emit structured memory candidates alongside their normal output. No memory writes occur -- candidates are stored as data in `.return-meta.json` for later processing by `/todo`.

**Return metadata schema extension:**
- Add `memory_candidates` array to `.claude/context/formats/return-metadata-file.md` with fields:
  - `content` (string, max 300 tokens)
  - `category` (enum: TECHNIQUE|PATTERN|CONFIG|WORKFLOW|INSIGHT)
  - `source_artifact` (path string)
  - `confidence` (float 0-1)
  - `suggested_keywords` (array of strings for index entry)

**Agent updates:**
- `general-research-agent.md`: emit 0-3 memory candidates for novel findings (key research findings, not task-specific details)
- `general-implementation-agent.md`: emit 0-3 memory candidates for reusable patterns, configuration discoveries, or workflow insights
- `planner-agent.md`: emit 0-1 memory candidates when planning reveals architectural patterns or dependency insights

**Skill postflight propagation:**
- Update `skill-researcher/SKILL.md` postflight to propagate `memory_candidates` from `.return-meta.json` to state.json task entry
- Update `skill-implementer/SKILL.md` postflight to propagate `memory_candidates` from `.return-meta.json` to state.json task entry
- Add `memory_candidates` to the `completion_data` schema in state.json

**Files to modify**: `.claude/context/formats/return-metadata-file.md`, `.claude/agents/general-research-agent.md`, `.claude/agents/general-implementation-agent.md`, `.claude/agents/planner-agent.md`, `.claude/skills/skill-researcher/SKILL.md`, `.claude/skills/skill-implementer/SKILL.md`

**Source**: Plan 68 Phase 3

---

### 445. Implement two-phase auto-retrieval for memory system
- **Effort**: large
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Task #444

**Description**: Make memory retrieval automatic for all `/research`, `/plan`, and `/implement` operations using two-phase retrieval: score the JSON index to select top-K candidates, then read only selected memory files into context.

**Two-phase retrieval pattern (implement in each skill):**
- **Phase 1 (Score)**: Read `memory-index.json`, extract keywords from task description, score each entry using: `0.5 * keyword_overlap + 0.3 * topic_match + 0.2 * recency_bonus`, select top-K where score > 0.2 (K = min(5, entries above threshold)), budget check: `sum(selected.token_count) < 3000` tokens
- **Phase 2 (Retrieve)**: Read each selected memory file, inject into delegation context as `<memory-context>` block
- **Update**: Increment `retrieval_count` and set `last_retrieved` to current date in `memory-index.json` for retrieved entries; also update memory file frontmatter to stay in sync

**Skill-level integration:**
- `skill-researcher/SKILL.md` Stage 4 (Prepare Delegation Context): Add two-phase retrieval
- `skill-planner/SKILL.md` Stage 1 (Parse Delegation Context): Add two-phase retrieval
- `skill-implementer/SKILL.md` delegation context preparation: Add two-phase retrieval

**Flag handling:**
- Add `--clean` flag to skill-researcher: when present, skip memory retrieval entirely
- Remove any `--remember` flag logic (retrieval is now always-on by default)

**Files to modify**: `.claude/skills/skill-researcher/SKILL.md`, `.claude/skills/skill-planner/SKILL.md`, `.claude/skills/skill-implementer/SKILL.md`, `.claude/CLAUDE.md` (update Memory Extension section)

**Source**: Plan 68 Phase 2

---

### 444. Create skill-memory with /learn command and memory index infrastructure
- **Effort**: large
- **Status**: [NOT STARTED]
- **Task Type**: meta

**Description**: Create the foundational memory skill (`skill-memory`) with `/learn` command and the machine-queryable memory index (`memory-index.json`). This is the prerequisite for all subsequent memory system tasks.

**Note**: No `skill-memory` or `/learn` command currently exists in this project. The `.memory/` vault structure exists (Obsidian-based with `10-Memories/`, `20-Indices/`, `30-Templates/`) with 1 existing memory file (`MEM-plan-delegation-required.md`), but there is no skill to manage it programmatically.

**Skill creation** (`.claude/skills/skill-memory/`):
- Create `SKILL.md` with full memory management pipeline:
  - **CREATE**: Generate `MEM-{slug}.md` in `.memory/10-Memories/` with frontmatter (title, category, topic, tags, keywords, summary, retrieval_count: 0, last_retrieved: null, created, modified, token_count)
  - **UPDATE**: Modify existing memory content, preserving history in `## History` section
  - **EXTEND**: Append new information to existing memory
  - **Index Regeneration**: Scan `.memory/10-Memories/MEM-*.md`, extract frontmatter, compute token count (`word_count * 1.3`), extract keywords from body (top 8 by frequency excluding stop words), build JSON entries, write `memory-index.json`
- Create `README.md` documenting operations and usage

**Command creation** (`.claude/commands/learn.md`):
- Create `/learn` command with argument parsing
- Support: `/learn "content"` (create), `/learn --task N` (create from task artifacts), `/learn --update MEM-slug` (update existing)

**Memory index** (`.memory/memory-index.json`):
- Schema: `version`, `generated_at`, `entry_count`, `total_tokens`, `entries` array
- Per-entry: `id`, `path`, `title`, `summary` (one-line), `topic`, `category`, `keywords` (array), `token_count`, `created`, `modified`, `last_retrieved`, `retrieval_count`
- **Validate-on-read**: Before using the index, check all listed files exist and no unlisted `MEM-*.md` files are present; if mismatch, regenerate

**Template update** (`.memory/30-Templates/memory-template.md`):
- Add `retrieval_count: 0`, `last_retrieved: null`, `keywords: []`, `summary: ""` frontmatter fields

**Backfill existing memories:**
- Update existing memory files in `.memory/10-Memories/` with new frontmatter fields (`retrieval_count: 0`, `last_retrieved: null`, `keywords` from tags, `summary` from first content sentence)

**Index documentation:**
- Update `.memory/20-Indices/index.md` to document the new JSON index and retrieval tracking fields
- Generate initial `memory-index.json` from current vault state

**Files to create**: `.claude/skills/skill-memory/SKILL.md`, `.claude/skills/skill-memory/README.md`, `.claude/commands/learn.md`, `.memory/memory-index.json`
**Files to modify**: `.memory/30-Templates/memory-template.md`, `.memory/10-Memories/MEM-*.md` (backfill), `.memory/20-Indices/index.md`

**Source**: Plan 68 Phase 1 + skill-memory foundation

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Task Type**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](087_investigate_wezterm_terminal_directory_change/reports/research-001.md)

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

---

### 78. Fix Himalaya SMTP authentication failure when sending emails
- **Effort**: 1-2 hours
- **Status**: [PLANNED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Planning Started**: 2026-02-13
- **Planning Completed**: 2026-02-13
- **Task Type**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](078_fix_himalaya_smtp_authentication_failure/reports/research-001.md)
- **Plan**: [implementation-001.md](078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md)

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: "Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted". The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.

---

## Recommended Order

### Memory system (tasks 444-454)

**Wave 1** (foundation):
1. **444** [NOT STARTED] -> research (unblocks everything)

**Wave 2** (parallel):
2. **445** [NOT STARTED] -> research (depends: 444, auto-retrieval)
3. **449** [NOT STARTED] -> research (depends: 444, /distill foundation)

**Wave 3** (parallel):
4. **446** [NOT STARTED] -> research (depends: 445, agent emission)
5. **450** [NOT STARTED] -> research (depends: 449, purge)
6. **451** [NOT STARTED] -> research (depends: 449, combine)

**Wave 4** (parallel):
7. **447** [NOT STARTED] -> research (depends: 446, /todo harvest)
8. **448** [NOT STARTED] -> research (depends: 446, nudge hook)
9. **452** [NOT STARTED] -> research (depends: 450+451, compress/refine)

**Wave 5**:
10. **453** [NOT STARTED] -> research (depends: 447+452, /todo integration)

**Wave 6** (capstone):
11. **454** [NOT STARTED] -> research (depends: 448+453, docs + e2e validation)

### Model/effort flag refactor
12. **455** [NOT STARTED] -> research (independent, can run anytime)

### Existing backlog
13. **78** [PLANNED] -> implement
14. **87** [RESEARCHED] -> plan
