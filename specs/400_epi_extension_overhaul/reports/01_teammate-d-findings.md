# Research Report: Task #400 - Teammate D (Horizons)

**Task**: 400 - Overhaul epidemiology extension: /epi command, epi:study routing, and infrastructure completion
**Role**: HORIZONS - Strategic direction, long-term alignment
**Started**: 2026-04-10T00:00:00Z
**Completed**: 2026-04-10T00:00:00Z
**Effort**: Medium (strategic analysis, no implementation)
**Sources/Inputs**: specs/ROADMAP.md, specs/TODO.md, .claude/extensions/epidemiology/, .claude/extensions/founder/, .claude/extensions/present/, .claude/commands/research.md, .claude/commands/plan.md, .claude/commands/implement.md

---

## Key Findings

### Roadmap Alignment

The current ROADMAP.md (Phase 1) lists four documentation infrastructure items and three agent system quality items. Task 400 advances the following roadmap items **directly**:

1. **Extension slim standard enforcement** (Phase 1, Agent System Quality): the epidemiology extension currently violates the slim standard in a critical way — it declares no `routing` block in `manifest.json`. All other compound-key extensions (founder, present) carry explicit `routing` maps for research/plan/implement. Fixing this during task 400 is the forcing function the roadmap calls for.
2. **Agent frontmatter validation** (Phase 1, Agent System Quality): the current agents use `skills:` in their frontmatter, which is not in the minimal standard (`name`, `description`, optional `model`). Task 400 can normalize these.
3. **Manifest-driven README generation** (Phase 1, Documentation Infrastructure): the epi manifest lists `"commands": []` — there is nothing to generate a README section for. After task 400 adds `/epi` and `epi:study` routing, the manifest becomes a complete input for the future generator. The extension will serve as a concrete test case for that tooling.

**Not directly advancing**: CI enforcement, marketplace metadata, context discovery caching, hot-reload.

### What is Missing vs. the Mature Pattern

Comparing the epidemiology extension against founder (the most complete reference) reveals three structural gaps:

| Capability | founder | present | epidemiology | Gap |
|------------|---------|---------|--------------|-----|
| Compound-key routing block in manifest | Yes | Yes | **No** | Critical |
| Dedicated command files | 9 commands | 5 commands | **0** | Critical |
| Pre-task forcing questions (Stage 0) | Yes (all commands) | Yes (all commands) | **No** | Critical |
| task_type prefix uses short key | `founder` | `present` | `epidemiology` (long) | Medium |
| Plan/implement routing | Explicit | Explicit | **Implicit** (inherits from bare key) | Medium |
| Rules files | None | None | None | Acceptable |

The epidemiology manifest declares `"task_type": "epidemiology"` — a 12-character flat key with no sub-type differentiation. Present uses `present`, founder uses `founder`. The task description asks to use `epi` as the prefix, making the compound form `epi:study`. This rename is a clean, minimal-footprint change that aligns the extension with the existing pattern.

### Adjacent Roadmap Items That Can Ride This Task

The task description already implies adding a commands directory. If we treat `/epi` as the canonical example of the **"interactive scoping command with file-path collection"** pattern, two future roadmap items become easier:

- Future `/founder-study` or `/lean-proof-project` commands can copy the `/epi` pattern directly.
- The manifest-driven README generator will find a fully-populated `provides.commands` array in epi's manifest when it runs, producing correct output without retroactive patches.

---

## Recommended Approach

### Strategic Framing

Task 400 should be scoped as: **"complete the extension to a first-class citizen using the compound-key pattern, and establish `/epi` as the canonical example of a scoping command for domain-specific studies."**

This framing avoids two failure modes:
- **Over-ambitious**: Do not attempt to generalize the scoping pattern into a reusable template during this task. Templates require two working examples before the pattern stabilizes. `/epi` is the first example; a generic template now would be premature and would likely be ripped out after `/founder-study` reveals different requirements.
- **Under-ambitious**: Do not merely fix routing and leave the command list empty. The `/epi` command is the user-facing payoff; without it, the extension cannot be distinguished from a library entry.

### Recommended Scope for Task 400

**Must include** (without these, the task is incomplete):
1. Rename `task_type` from `"epidemiology"` to `"epi"` in manifest.json and propagate to all callers (index-entries.json load_when arrays, EXTENSION.md routing table, agent descriptions, README).
2. Add `routing` block to manifest.json with `epi:study` -> appropriate skills for research/plan/implement, and `epi` (bare) as fallback to the same skills.
3. Create `commands/epi.md` with Stage 0 pre-task forcing questions that collect: study description, study type (observational/RCT/modeling), data file paths, protocol/description document paths, R project root, and any existing analysis scripts.
4. Update manifest `"commands": ["epi.md"]` and update `opencode-agents.json` to match (it currently references opencode agents; this is already populated, just needs the command added).
5. Add a `skill-epi-plan` or route plan to `skill-planner` explicitly in routing (currently implicit).

**Should include** (high value, low complexity):
6. Normalize agent frontmatter: remove `skills:` field, keep `name`, `description`, `model`.
7. Update `index-entries.json` to use `task_types` array instead of `languages` array (the current schema uses `load_when.languages`, but the routing schema uses `task_type`; the epi index-entries uses `"languages": ["r", "epidemiology"]` — this should migrate to `"task_types": ["epi", "epi:study"]` to match how founder and present declare their load_when conditions).
8. Add a plan-specific agent or route plan to `skill-planner` for the study design output.

**Should not include** (defer to future tasks):
- Generalized scoping command template (needs a second example first)
- Docker/renv reproducibility scaffolding (specialized; warrants its own task)
- PubMed literature search integration via WebSearch (can be added to the research agent's instructions without a new skill)
- Quarto/Rmarkdown output format for findings (the current system produces .md; Quarto is a different rendering pipeline that would require a convert command or a new agent)

### Adjacent Opportunities (Low-Cost, High-Value)

Two adjacent changes can be batched with task 400 at nearly zero marginal cost:

**A. Standardize the routing fallback documentation.** The core `/research`, `/plan`, and `/implement` commands already handle compound-key fallback (`if compound key, try base`). This is undocumented in the epidemiology EXTENSION.md. Adding one sentence to the routing table would prevent future confusion.

**B. Add `settings-fragment.json` reference to README.** The epi extension includes `settings-fragment.json` for configuring `rmcp` via `uvx`. Neither the README nor EXTENSION.md mentions this. A one-line addition to the README would surface this to users.

---

## Creative / Unconventional Options

### Option 1: Scoping Artifact (Novel Pattern)

Rather than storing collected paths only in `forcing_data` inside `state.json`, the `/epi` command could write a scoping artifact to `specs/{NNN}_*/scoping/01_study-scope.md`. This would be the first "scoping" artifact type in the system.

**Pros**: The scoping document becomes a readable, version-controlled record of study intent. The research agent can load it directly via `@`-reference. It surfaces in git history. Future analysts can review what was collected before research began.

**Cons**: Introduces a new artifact directory (`scoping/`) alongside `reports/`, `plans/`, `summaries/`. The `artifact-formats.md` rules do not mention scoping artifacts; adding this requires a rules update. The risk is that a half-baked new artifact type creates inconsistencies if other extensions do not follow suit.

**Verdict**: Include if a scoping directory is explicitly defined and registered in `artifact-formats.md`. Otherwise, defer. The scoping data in `forcing_data` is sufficient for the agents. A scoping document could be the output of the research agent's first phase rather than the command itself.

### Option 2: STROBE Checklist Auto-Generation

The STROBE statement (Strengthening the Reporting of Observational Studies in Epidemiology) is a 22-item checklist used for reporting observational studies. The research agent could, during the planning phase, automatically generate a `strobe-checklist.md` tailored to the study type (cohort, case-control, or cross-sectional).

**This is high value for an epidemiologist** and requires no new infrastructure: the research agent merely needs STROBE awareness in its context. The implementation is adding a `context/project/epidemiology/patterns/strobe-checklist.md` file (the 22 items with prompts for each) and instructing the research agent to reference it during plan generation.

**Verdict**: Include as a context file addition. Zero implementation risk; immediately useful.

### Option 3: DAG Stub Generation

Directed Acyclic Graphs (DAGs) are the standard tool for causal reasoning in epidemiology. The `/epi` command could collect exposure and outcome variables, then ask the user to name potential confounders. The research agent would generate a dagitty-compatible stub (or a `ggdag` R snippet) as part of the study scope.

**This is genuinely delightful for an epidemiologist** and distinguishes the epi extension from a generic R extension.

**Implementation path**: The `/epi` Stage 0 could include a question: "What is the primary exposure? What is the primary outcome? Name 1-3 suspected confounders." These are stored in `forcing_data.causal_structure`. The research agent generates a `study_dag.R` stub using `ggdag`. This requires no new agents or skills — only new questions in the command and new instructions in the research agent.

**Verdict**: High value, low complexity. Include as an optional Stage 0 question with a "skip" option.

### Option 4: PubMed Literature Search During Research

The research agent could include a WebSearch step targeting PubMed (using `site:pubmed.ncbi.nlm.nih.gov` or the NCBI Entrez API via WebFetch) to pull prior art on the study topic automatically.

**Verdict**: This is a pure research agent instruction change. Add it to the `epidemiology-research-agent.md` capabilities section with a note that WebSearch should include PubMed-targeted queries. No structural change needed.

### Option 5: R Package Management via renv / Dockerfile

Adding renv snapshot generation and Dockerfile creation to the implementation agent would support reproducibility. This is genuinely valuable for epidemiology research but is specialized enough to warrant its own task once the core infrastructure exists.

**Verdict**: Explicitly out of scope for task 400. Note in the plan as a future task.

### Option 6: Quarto / Rmarkdown for Findings Reports

The final report from `/implement` could be generated as a Quarto document (`.qmd`) rather than a plain `.md` file, since Quarto can embed R output, figures, and references.

**Verdict**: This is architecturally distinct from the current system, which assumes `.md` artifact outputs. A Quarto output would require a conversion pipeline (Quarto CLI) and changes to how artifacts are linked in TODO.md. Defer to a separate task. Document as a known future direction in the extension README.

---

## Long-Term Trajectory (6-12 Months)

A mature epidemiology extension in 6-12 months would look like:

1. `/epi` command with full Stage 0 scoping (study type, data paths, causal structure), producing `epi:study` tasks.
2. A specialized `epi-plan-agent` that generates study design documents (estimand, DAG, statistical analysis plan) distinct from code implementation plans.
3. A `strobe-checklist.md` context file automatically referenced during planning.
4. PubMed-aware research agent.
5. A `dagitty`/`ggdag` stub generator.
6. A second command, e.g., `/epi-report`, that assembles final findings into a structured epidemiology report with STROBE-compliant sections.
7. Potentially: renv and Dockerfile generation as a reproducibility phase in the implementation skill.

**What task 400 must scaffold correctly to enable this trajectory**:

- The `epi:study` task type must be the stable sub-type for observational/modeling studies. Future sub-types (`epi:rct`, `epi:modeling`, `epi:systematic-review`) extend from this base.
- The `forcing_data` schema collected by `/epi` must include `causal_structure` fields (`exposure`, `outcome`, `confounders`) from day one, even if the DAG stub generation is optional. Adding these fields retroactively would break existing tasks.
- The research agent must be given explicit PubMed search instructions in its prompt, not just in context files. Context files can be pruned; agent prompts are persistent.

**What would be a mistake to build now**:

- A generic "scoping command template" that other extensions inherit. The pattern is not stable yet.
- A `skill-epi-plan` skill with a fully custom planner agent. The existing `skill-planner` is sufficient; differentiation comes from context files (STROBE, DAG patterns), not from a new agent.
- Quarto output for findings. This requires Quarto CLI, a conversion step, and changes to artifact linking rules. The complexity is out of proportion to the benefit at this stage.

---

## Strategic Challenges This Task Could Address

### 1. Inconsistency in Extension Task Type Declaration

The epidemiology `index-entries.json` uses `"languages"` in `load_when`, while the routing infrastructure uses `task_type`. The founder and present extensions use `"task_types"` in their index entries. This inconsistency means the epi context is not loaded by the standard context-discovery query that filters by `task_types`. Task 400 is the natural moment to fix this — migrating from `"languages": ["r", "epidemiology"]` to `"task_types": ["epi", "epi:study"]` and adding `"commands": ["/epi"]`.

### 2. Missing Pattern: Interactive Scoping Commands That Collect File Paths

The `/market` and `/grant` commands collect metadata (problem, geography, mechanism) but not file paths to local data files. The `/slides` command collects source material paths. The `/epi` command is the first case where collecting paths to local data files is the primary scoping action (data directory, protocol PDF, codebook). This establishes a pattern that `/lean-proof-project` and future domain-specific commands can follow.

The key design decision: should path inputs be validated at Stage 0 (before task creation) or deferred to research time? The `/slides` command defers validation (paths are stored in `forcing_data` and read during research). This is the right pattern for `/epi` too: collect paths eagerly, validate lazily. Document this as a convention in the command.

### 3. Task Attachments Convention

Task 400 could introduce the concept of "task attachments" — local file paths stored in `forcing_data` that agents load as primary inputs. This is distinct from the current pattern where agents discover inputs from the task description text. Attachments enable structured, typed input references:

```json
"forcing_data": {
  "attachments": [
    {"type": "data_dir", "path": "/path/to/data/"},
    {"type": "protocol", "path": "/path/to/protocol.pdf"},
    {"type": "codebook", "path": "/path/to/codebook.md"}
  ]
}
```

This convention could be adopted by other commands. However, formalizing it into a system-wide standard (with validation in `artifact-formats.md` or `state-management-schema.md`) is premature. For task 400, store paths as simple strings in `forcing_data` following the `/slides` pattern. Document the `attachments` concept in the `/epi` command file as a future generalization point.

---

## Confidence Level

**High confidence**:
- The three structural gaps (no routing block, no commands, no compound task_type) are clear and well-supported by comparison with founder and present manifests.
- The roadmap alignment analysis is based on direct reading of ROADMAP.md Phase 1 items.
- The `index-entries.json` language/task_type inconsistency is confirmed by reading both the epi index and the core context-discovery query patterns.

**Medium confidence**:
- The recommendation to defer a generic scoping template is based on the principle that two examples are needed before a pattern can be extracted. If the user already has a second scoping command in mind, the template could be designed in parallel.
- The DAG stub generation as a Stage 0 question is creative but untested; the complexity of the question (exposure/outcome/confounders) may be too much for an interactive CLI prompt and may work better as a research-phase output.

**Lower confidence**:
- The 6-12 month trajectory extrapolates from the current extension pattern. Domain priorities could shift.
- The "task attachments" convention is speculative; whether other extensions would adopt it is unknown.
