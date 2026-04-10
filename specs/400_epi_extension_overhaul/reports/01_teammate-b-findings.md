# Research Report: Task #400 - Teammate B Findings

**Task**: 400 - Overhaul epidemiology extension
**Role**: ALTERNATIVE APPROACHES & PRIOR ART
**Started**: 2026-04-10T00:00:00Z
**Completed**: 2026-04-10T01:00:00Z
**Effort**: ~1 hour
**Sources/Inputs**: Codebase scan of `.claude/extensions/` (all 13 extensions), `/commands/research.md`, `/commands/plan.md`, `/commands/implement.md`, `specs/archive/125_epidemiology_r_extension/`
**Artifacts**: This report

---

## Key Findings (Prior Art and Alternative Patterns)

### 1. Critical Routing Gap: Epidemiology Falls Back to `skill-researcher`

The most important finding is a structural defect in the current epidemiology extension: it has no `routing` table in `manifest.json`. The core `/research`, `/plan`, and `/implement` commands loop through `extensions/*/manifest.json` looking for `routing.research[$task_type]` entries. Only `founder` and `present` extensions define routing tables. Every other extension (epidemiology, python, nix, latex, formal) falls back to the generic `skill-researcher` / `skill-planner` / `skill-implementer`, meaning the dedicated `skill-epidemiology-research` and `skill-epidemiology-implementation` skills are **never invoked by the standard pipeline**.

This is the same gap affecting python, nix, and latex extensions. The overhaul must add a routing table to the manifest.

Evidence:
- `/home/benjamin/.config/nvim/.claude/commands/research.md` lines 313-342: manifest loop with `skill-researcher` fallback
- `/home/benjamin/.config/nvim/.claude/extensions/epidemiology/manifest.json`: no `"routing"` key

### 2. Three Distinct Extension Architectures Exist

After scanning all 13 extensions, three patterns emerge:

| Pattern | Extensions | task_type | routing | commands |
|---------|------------|-----------|---------|----------|
| **Compound routing** | founder, present | yes (simple) | yes (compound keys) | yes (many) |
| **Simple type + thin skills** | python, nix, latex, lean, web, nvim, z3, formal | yes | no (gap/bug) | 0-2 |
| **Command-only, no task_type** | filetypes | null | no | 4 |

The epidemiology extension currently lives in pattern 2 (with routing gap). Task 400 should move it to a hybrid of patterns 2 and compound-routing (epi as extension prefix, sub-types for study variants).

### 3. Compound Task_Type Parsing: How It Works

The compound `founder:deck` key is parsed by the research/plan/implement commands using a two-pass lookup:

1. First pass: look for exact compound key `founder:deck` in `routing.research`
2. Second pass fallback: strip to base `founder`, look for `routing.research.founder`

This is implemented inline in all three core commands (not in a shared helper). The routing table lives in the extension's `manifest.json` under `"routing": { "research": {...}, "plan": {...}, "implement": {...} }`.

For the epidemiology extension, analogous keys would be:
- `epi` (bare): routes to `skill-epidemiology-research` (default)
- `epi:study`: routes to same or a specialized study-design skill
- `epi:analysis`: could route to same or an analysis-focused skill
- `epi:report`: could route to an implementation/reporting skill

Evidence:
- `/home/benjamin/.config/nvim/.claude/commands/research.md` lines 326-342
- `/home/benjamin/.config/nvim/.claude/extensions/founder/manifest.json`: `routing.research` has 11 compound keys
- `/home/benjamin/.config/nvim/.claude/extensions/present/manifest.json`: `routing.research` has 5 keys

### 4. Alternative to Compound Routing: Agent-Internal Keyword Dispatch (Formal Pattern)

The `formal` extension has 4 specialized agents (logic, math, physics, general-formal) but uses **no manifest routing table**. Instead:
- A single skill `skill-formal-research` always invokes `formal-research-agent`
- The `formal-research-agent` inspects task keywords at runtime and sub-routes to `logic-research-agent`, `math-research-agent`, or `physics-research-agent`

This is a viable alternative to compound `epi:study` routing: a single `skill-epidemiology-research` always delegates to a coordinator agent, which then routes internally based on whether the study involves infectious disease modeling, survival analysis, Bayesian inference, or cross-sectional analysis.

**Trade-off**: Agent-internal routing is more flexible but less visible (routing logic lives inside an agent file, not in a inspectable manifest table).

Evidence:
- `/home/benjamin/.config/nvim/.claude/extensions/formal/agents/formal-research-agent.md`
- `/home/benjamin/.config/nvim/.claude/extensions/formal/manifest.json`: no `"routing"` key

### 5. AskUserQuestion Flow Patterns: Four Exemplars

**Pattern A: Mode-then-questions (founder commands)**
Used in: `/market`, `/strategy`, `/analyze`, `/finance`, `/project`
Flow:
1. AskUserQuestion: pick MODE (VALIDATE/SIZE/SEGMENT/DEFEND)
2. AskUserQuestion: 3-5 domain-specific forcing questions (one at a time)
3. Store all responses in `forcing_data` JSON blob in task state
4. Create task at [NOT STARTED], STOP
5. Later: `/research N` uses `forcing_data` to skip re-asking

Example: `/market` asks 4 questions (problem, target entity, geography, price point) + 1 mode selection
File: `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/market.md`

**Pattern B: Materials-collection (present commands)**
Used in: `/slides`, `/deck`, `/grant`
Flow:
1. AskUserQuestion: talk type / purpose
2. AskUserQuestion: "What materials should inform this?" (accepts task refs, file paths, or "none")
3. AskUserQuestion: audience/context narrative
4. Store in forcing_data, create task, STOP

The materials-collection pattern is directly applicable to `/epi`: the user should provide data directories, protocol documents, or existing literature paths.
File: `/home/benjamin/.config/nvim/.claude/extensions/present/commands/slides.md`

**Pattern C: File-first, no forcing questions (filetypes pattern)**
Used in: `/convert`, `/scrape`, `/edit`
Flow:
1. Parse file path from arguments
2. Validate file exists
3. Immediately delegate to skill/agent
4. No AskUserQuestion, no task creation (ephemeral operation)

**Pattern D: File-first, autonomous enrichment (founder /meeting)**
Used in: `/meeting`
Flow:
1. Accept file path only (no forcing questions)
2. Create task with `notes_path` stored
3. Immediately delegate to `skill-meeting` which does web enrichment autonomously
4. No interactive questioning at all

File: `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/meeting.md`

### 6. R-Language Prior Art in the Repository

Searching the codebase for R-language patterns:

- **Dedicated extension** (`specs/archive/125_epidemiology_r_extension/`): The epidemiology extension was originally built in task 125, mirroring both `.opencode/` and `.claude/` trees. The research reports document `EpiModel`, `epidemia`, `EpiNow2`, `EpiEstim`, `survival`, `rstan`, `cmdstanr`, `rmcp`, `mcptools`.
- **No overlap with other extensions**: None of the other 12 active extensions (python, nix, latex, etc.) mention R, rmarkdown, quarto, tidyverse, or epidemiology tooling. The epidemiology extension is the sole R entry point.
- **MCP server configured**: `settings-fragment.json` in the epi extension registers `rmcp` via `uvx`. No `mcptools` entry, despite the original task 125 recommending both.
- **No `/epi` command** exists anywhere in the codebase currently. The `README.md` explicitly states "No dedicated commands."

Evidence:
- `/home/benjamin/.config/nvim/.claude/extensions/epidemiology/settings-fragment.json`: `{"mcp_servers": {"rmcp": {"command": "uvx", "args": ["rmcp"]}}}`
- `/home/benjamin/.config/nvim/.claude/extensions/epidemiology/README.md`: "No dedicated commands. Use core `/research`, `/plan`, `/implement`..."

### 7. When Extensions Create Dedicated Skills vs. Reuse Defaults

**Extensions that reuse `skill-researcher`/`skill-planner`/`skill-implementer`** (via routing gap): python, nix, latex, epidemiology, formal, z3, web, lean. These extensions have their own skill files but the routing gap means they are never invoked from the standard pipeline unless called directly.

**Extensions that override routing** (founder, present): Both have many sub-types where different sub-tasks genuinely need different agents (e.g., deck research needs slide-structure expertise vs. market research needs TAM modeling). The overhead of explicit routing tables is justified.

**Criteria for creating dedicated skills** (from observed patterns):
1. The domain has multiple distinct sub-workflows that require different agent expertise
2. The implementation phase is substantively different from generic (e.g., running R scripts vs. writing Lua)
3. There is MCP tooling specific to the domain (rmcp for epi, lean-lsp for lean4)
4. The extension expects to grow into multiple commands over time

Epidemiology meets criteria 2, 3, and potentially 4, but currently criterion 1 is ambiguous (study design vs. analysis vs. reporting). The minimal fix is adding a routing table pointing `epi` and `epi:study` to the existing skills. Splitting into sub-skills is optional unless the domain diverges enough.

**Evidence for "reuse default skills"**: python, nix, latex all provide dedicated agents but still fall back to generic skills in practice, and they function adequately for their use cases via context injection alone.

---

## Recommended Approach: At Least 2 Alternatives to Primary

### Alternative A: Minimal Routing Fix + Dedicated `/epi` Command (Materials-Collection Style)

**Structure**:
- Keep single task_type `epi` (rename from `epidemiology` for consistency with `epi:study` prefix)
- Add routing table to `manifest.json`:
  ```json
  "routing": {
    "research": {"epi": "skill-epidemiology-research", "epi:study": "skill-epidemiology-research"},
    "plan":     {"epi": "skill-planner", "epi:study": "skill-planner"},
    "implement": {"epi": "skill-epidemiology-implementation", "epi:study": "skill-epidemiology-implementation"}
  }
  ```
- Add `/epi` command following the `present/slides.md` Pattern B:
  - AskUserQuestion 1: Study type (COHORT / CASE_CONTROL / CROSS_SECTIONAL / INFECTIOUS_DISEASE / SURVIVAL / BAYESIAN)
  - AskUserQuestion 2: "Provide data directories, protocol files, or existing literature paths (comma-separated or 'none')"
  - AskUserQuestion 3: "Describe the research question and population"
  - Store forcing_data, create task with `task_type: "epi:study"`, STOP at [NOT STARTED]
  - Later: `/research N` uses forcing_data + provided materials to design the study

**Signature variants**:
- `/epi "Compare HIV incidence by treatment arm"` → interactive scoping, creates task
- `/epi 400` → resume existing epi:study task
- `/epi /path/to/protocol.md` → read protocol as context, then interactive scoping

**Tradeoffs**:
- Pro: Minimal new code, reuses existing skill-epidemiology-research and skill-epidemiology-implementation
- Pro: The materials-collection pattern (slides/grant) is well-tested for research workflows with file-based inputs
- Pro: `epi:study` sub-type allows future expansion (`epi:analysis`, `epi:surveillance`) without breaking existing tasks
- Con: Single research skill handles all epi variants (no specialization by study type)
- Con: The `plan` leg uses generic `skill-planner` unless a dedicated `skill-epidemiology-plan` is created

### Alternative B: Formal-Style Coordinator Agent with Agent-Internal Routing

**Structure**:
- Keep simple `epi` task_type (no compound subtypes in manifest)
- Add minimal routing table pointing to a coordinator agent:
  ```json
  "routing": {
    "research": {"epi": "skill-epidemiology-research"},
    "plan": {"epi": "skill-planner"},
    "implement": {"epi": "skill-epidemiology-implementation"}
  }
  ```
- Upgrade `epidemiology-research-agent` to function as a coordinator (like `formal-research-agent`):
  - Inspect task description and forcing_data for study type keywords
  - Route internally to specialized sub-agents: `epi-infectious-agent`, `epi-survival-agent`, `epi-cohort-agent`
- Add `/epi` command with same interactive scoping as Alternative A, but store detailed study type metadata

**Tradeoffs**:
- Pro: Routing logic is centralized in one coordinator agent, easier to extend without touching manifest
- Pro: The `formal` pattern is validated in production (task 102 review confirmed it works)
- Pro: Study type becomes implicit from task content rather than requiring the user to pick a sub-type
- Con: Requires creating multiple specialized sub-agents (more files to maintain)
- Con: Routing is less transparent (not visible in manifest.json inspection)
- Con: The coordinator adds an extra Task invocation layer (depth increases by 1)

### Alternative C: Filetypes-Style Command-Only (No Task Integration for Scoping Phase)

**Structure**:
- Keep the current extension as-is for task-based workflows
- Add `/epi` as a stateless scoping command (Pattern C / filetypes approach):
  - No task creation during `/epi`
  - `/epi` interactively asks questions and writes a scoping artifact to a directory (e.g., `epi/study-design-{date}.md`)
  - The user then runs `/task "epi:study - study description"` to create the formal task
  - `/research N` picks up the scoping artifact via `forcing_data.content_paths`

**Tradeoffs**:
- Pro: The scoping step is fully decoupled from the task system (simpler `/epi` command)
- Pro: Matches how epidemiologists actually work (protocol drafting before formal registration)
- Pro: No need to change manifest routing (task still uses generic pipeline with context injection)
- Con: Two-step creation flow is less ergonomic; users must remember to run both `/epi` then `/task`
- Con: The scoping artifact is not linked to the task in state.json unless manually added
- Con: Breaks the forcing_data pattern established by founder/present commands

---

## Evidence and Examples (Exact File Paths)

| Pattern | File Path | Key Lines |
|---------|-----------|-----------|
| Compound routing in manifest | `/home/benjamin/.config/nvim/.claude/extensions/founder/manifest.json` | `"routing": { "research": { "founder:deck": "skill-deck-research", ... } }` |
| Manifest routing lookup algorithm | `/home/benjamin/.config/nvim/.claude/commands/research.md` | Lines 313-342 (manifest loop + fallback) |
| Materials-collection AskUserQuestion flow | `/home/benjamin/.config/nvim/.claude/extensions/present/commands/slides.md` | STAGE 0 (Step 0.1-0.3) |
| Mode-then-questions AskUserQuestion flow | `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/market.md` | STAGE 0 (Step 0.1-0.2) |
| File-first, autonomous enrichment | `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/meeting.md` | Step 3 (no forcing questions) |
| Agent-internal keyword routing | `/home/benjamin/.config/nvim/.claude/extensions/formal/agents/formal-research-agent.md` | Domain Routing table |
| Filetypes command-only approach | `/home/benjamin/.config/nvim/.claude/extensions/filetypes/commands/convert.md` | Full file (no task creation) |
| Current epi extension gap | `/home/benjamin/.config/nvim/.claude/extensions/epidemiology/manifest.json` | No `"routing"` key |
| Current epi skills (not routed) | `/home/benjamin/.config/nvim/.claude/extensions/epidemiology/skills/skill-epidemiology-research/SKILL.md` | Full file |
| Thin-wrapper skill pattern | `/home/benjamin/.config/nvim/.claude/context/patterns/thin-wrapper-skill.md` | When to create vs. reuse |
| Task 125 original epi research | `/home/benjamin/.config/nvim/specs/archive/125_epidemiology_r_extension/reports/research-001.md` | Extension structure pattern |

### Comparison: Founder (Many Sub-Types) vs Present (Few Sub-Types)

**Founder**: 11 compound research keys (`founder:market`, `founder:analyze`, `founder:strategy`, `founder:legal`, `founder:project`, `founder:sheet`, `founder:finance`, `founder:financial-analysis`, `founder:deck`, `founder:meeting`, bare `founder`). Justification: each sub-type has meaningfully different research methodology and agent expertise. `deck` research reads source materials; `market` research does TAM/SAM/SOM; `legal` does contract review.

**Present**: 5 compound research keys (`present:grant`, `present:budget`, `present:timeline`, `present:funds`, `present:talk`, bare `present`). Present has fewer sub-types because grant writing, budgeting, and timeline management are more similar in methodology. Notably, `plan` and `implement` for most sub-types routes to the same generic `skill-planner` and `skill-grant` skills.

**Implication for epidemiology**: The epidemiology domain is methodologically diverse (infectious disease dynamics vs. survival analysis vs. cross-sectional studies are quite different), which would argue for founder-style granular sub-typing. However, the current implementation (2 agents) is much simpler than founder's (14 agents). A pragmatic overhaul would use 3-4 sub-types at most (`epi:study`, `epi:analysis`, `epi:report`, optionally `epi:surveillance`) with the same 2 skills handling all of them initially.

### Argument For vs. Against `epi:study` Sub-Typing

**For sub-typing**:
- Founder pattern has proven that compound task_types scale well and the routing algorithm handles them cleanly
- `epi:study` is semantically clearer than bare `epi` for the study-design phase
- Allows future `epi:report` to route to a different implementation skill that generates the final report artifact
- Consistent with task 400's explicit request for `epi:study` routing

**Against sub-typing** (or for minimal sub-typing):
- Present uses the same generic `skill-planner` for all its sub-types in the plan phase; sub-typing only matters when skills diverge
- The epidemiology domain has fewer distinct methodological branches than founder's business domains
- Fewer sub-types = simpler manifest, simpler user mental model
- The formal extension proves agent-internal routing can handle sub-domain dispatch without manifest complexity

**Recommendation**: Implement exactly 2 compound sub-types initially:
- `epi:study` (study design, protocol, analysis plan, implementation, reporting)
- bare `epi` (legacy/generic fallback)

Defer `epi:analysis`, `epi:surveillance`, `epi:review` until a real use case drives the split.

---

## Alternative `/epi` Command Signatures

### Signature 1: Purely Interactive (Analogous to `/market`, `/strategy`)

```
/epi "Compare vaccine efficacy in elderly cohort"   # Interactive scoping + task creation
/epi 400                                             # Resume existing epi:study task
/epi /path/to/protocol.md                           # Use protocol as context, then ask questions
```

Forcing questions:
1. Study type (COHORT / CASE_CONTROL / CROSS_SECTIONAL / INFECTIOUS_DISEASE / SURVIVAL / BAYESIAN)
2. Data directory paths (comma-separated file/directory paths, or "none")
3. Research question and population description

**Best for**: Users who are starting fresh with a vague idea and need the system to help structure the study design.

### Signature 2: Data-First, Minimal Interaction

```
/epi --from-data /path/to/data/dir       # Scan directory, infer study type, minimal questions
/epi --from-data /path/to/data.csv "Compare treatment arms by survival"
```

Flow: Read directory listing / CSV headers to infer study type, ask only 1-2 clarifying questions (study type confirmation + research question), then create task. Analogous to `/meeting` (Pattern D) which takes a file and enriches autonomously.

**Best for**: Users who already have data and just need the system to recognize the structure.

### Signature 3: Revision Mode (Convert Existing Task)

```
/epi --review 395   # Convert an existing general/meta task to epi:study
```

Flow: Read task 395 description and artifacts, ask "Is this suitable for epi:study routing?" (yes/no), update `task_type` from `general` to `epi:study`, add forcing_data from existing task description.

**Best for**: Users who created a task via `/task "..."` before `/epi` was available, or who want to reclassify a task.

---

## Confidence Level

- **Routing gap identification**: High (directly verified in manifest.json and research.md source)
- **AskUserQuestion pattern examples**: High (read full source of 5+ commands)
- **R-language prior art absence**: High (grep confirmed no overlap with other extensions)
- **Compound routing algorithm**: High (read implementation in research.md lines 308-342)
- **Formal/agent-internal routing as alternative**: High (read formal-research-agent.md)
- **Sub-typing recommendations (2 vs. more)**: Medium (based on observed founder/present patterns, not epi-specific domain expertise)
