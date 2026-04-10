# Research Report: Task #400 — Critic Findings (Teammate C)

**Task**: 400 - Overhaul epidemiology extension: /epi command, epi:study routing, and infrastructure completion
**Role**: CRITIC — gaps, blind spots, and unvalidated assumptions
**Started**: 2026-04-10T00:00:00Z
**Completed**: 2026-04-10T00:30:00Z
**Effort**: ~30 min (direct codebase audit)
**Sources/Inputs**: Direct filesystem inspection of epidemiology/, founder/, present/, commands/, skills/, agents/, Lua extension loader, doc-lint script, specs/TODO.md, state.json
**Artifacts**: This report

---

## Executive Summary

- The epidemiology extension is a functional stub with agents and context, but lacks a `routing` section in manifest.json — meaning it is currently silently unreachable via the routing mechanism used by `/research`, `/plan`, and `/implement`.
- The extension's `index-entries.json` uses `"languages"` in `load_when`, while the main `context/index.json` uses `"task_types"` — a field-name mismatch that would prevent context from loading correctly after merge.
- No tasks with `task_type: "epidemiology"` exist in the active state or archive, so renaming to `epi:study` carries zero migration risk from existing tasks, but the keyword routing in `task.md` currently maps keywords to `"epidemiology"` and must be updated.
- The doc-lint script does NOT validate the presence of a `routing` section, so the extension passes all lint checks despite being functionally unroutable.
- The proposed `/epi` command design and `epi:study` compound type address real gaps, but several epidemiology-domain concerns (IRB, reproducibility, pre-registration, missing data, reporting guidelines) are absent from both the task description and the existing extension content.

---

## Key Findings (Gaps and Blind Spots)

### 1. The manifest.json has no `routing` section — routing is currently broken

Founder and present both declare a `routing` block in their manifests with explicit research/plan/implement skill mappings. The epidemiology manifest has no `routing` key:

```
epidemiology manifest keys: name, version, description, task_type, dependencies, provides, merge_targets
```

The routing logic in `research.md` (and equivalently in `plan.md` and `implement.md`) works by scanning every `manifest.json` for `.routing.research[$task_type]`. With no `routing` key present, this lookup returns empty, and the fallback `skill_name = "skill-researcher"` is used — the generic researcher agent, not the epidemiology one.

**Consequence**: Any task with `task_type: "epidemiology"` created today silently falls back to `skill-researcher`, not `skill-epidemiology-research`. The extension's specialized agents are never invoked through the standard workflow.

**What the planner must add**: A `routing` section in `manifest.json` following the founder/present pattern, covering all three operations (research, plan, implement) for both the bare `epi` type and the `epi:study` compound key.

### 2. `index-entries.json` uses `"languages"` but the main index uses `"task_types"`

The epidemiology extension's `index-entries.json` declares `load_when.languages: ["r", "epidemiology"]`. The canonical `context/index.json` uses `load_when.task_types` as the field name. The context discovery query pattern (from CLAUDE.md) uses `.load_when.task_types[]?`:

```bash
jq -r '.entries[] | select(any(.load_when.task_types[]?; . == $task_type)) | .path' .claude/context/index.json
```

If the epidemiology index entries were merged as-is, the `languages` field would not be recognized, and the context files would never load for epidemiology tasks.

**What the planner must fix**: Change `"languages"` to `"task_types"` in all four entries in `index-entries.json`, updating the values from `["r", "epidemiology"]` to `["epi", "epi:study"]` (or whatever the canonical new task type name is). The `"agents"` field in `load_when` is valid and should be preserved.

### 3. The extension's context files are not currently in the main `context/index.json`

Running `python3` inspection confirms 0 epidemiology entries in the main context index. The extension has not been loaded (or its load state does not persist into the index). This means the context files (`r-packages.md`, `statistical-modeling.md`, `mcp-guide.md`) are invisible to the context discovery system.

This is expected behavior if the extension has never been loaded via `<leader>ac`, but it means the extension is currently inert for all practical purposes.

### 4. The doc-lint script passes, but does not validate the routing section

`bash .claude/scripts/check-extension-docs.sh` reports `epidemiology PASS`. The script checks for: README.md, EXTENSION.md, manifest.json, agent files, skill SKILL.md files, command files, rules, scripts, and README drift. It does not check whether a `routing` section exists in the manifest. This means the lint gate cannot catch the routing gap described in Finding 1.

**Blind spot for the planner**: Adding a `routing` section check to the doc-lint script should be part of this task's scope, or the extension will remain silently unroutable and lint will give false confidence.

### 5. Task-type keyword routing in `task.md` maps to `"epidemiology"` — must be updated

`task.md` contains this mapping:
```
"epidemiology", "epimodel", "stan", "infectious" → epidemiology
```

If the canonical task type changes to `epi:study`, this mapping must change accordingly. The keyword list also conflates "stan" with epidemiology (Stan is used in many non-epidemiology Bayesian contexts across lean4, formal, and other extensions). This is a pre-existing inaccuracy that the overhaul could address.

### 6. No existing `epi:study` tasks to migrate — zero migration risk, but zero precedent

There are no tasks with `task_type: "epidemiology"` in `specs/state.json` or anywhere in `specs/archive/`. This confirms there is no data-migration risk from renaming. However, it also means the extension has never been used in practice for any logged task. The extension's design has not been validated against real use.

### 7. `founder` and `present` are structurally different reference models

The task description says to compare against "founder/ and present/". These are not equivalent:

- **founder**: 9 commands, 14 agents, 14 skills, full routing table with compound keys, `mcp_servers` entries, large content library
- **present**: 5 commands, 5 agents, 5 skills, routing table with compound keys, small but complete content library

Epidemiology currently has: 0 commands, 2 agents, 2 skills, no routing, minimal context (4 files).

`present` is the correct reference model for an extension starting from 2 agents and growing to a single entry-point command. `founder` is the reference for multi-sub-command architectures. The task likely intends `/epi` to be the single entry point (analogous to `/slides` or `/grant`), not the multi-command founder pattern.

**Blind spot**: If the planner uses founder as the primary template, they may over-engineer the command hierarchy (e.g., creating `/epi:study`, `/epi:model`, `/epi:analyze` as separate commands). The simpler `present`-style `/epi` with mode selection inside the command is more appropriate.

### 8. The EXTENSION.md still uses "Language Routing" framing, not "Task Type" framing

The `EXTENSION.md` file says `Language: epidemiology → skill-epidemiology-research`, using the old language-based framing. After the `epi:study` rename, this section must be updated to use `Task Type` framing matching the format used in `present/EXTENSION.md` (which references `present:grant`, `present:budget`, etc.).

### 9. Domain-specific requirements missing from the extension and task description

A serious epidemiological study workflow involves steps that the generic research/plan/implement pipeline does not handle and that the existing context files do not mention:

| Requirement | Present in extension? | Present in task description? |
|---|---|---|
| IRB/ethics approval documentation | No | No |
| Pre-registration (OSF, ClinicalTrials.gov) | No | No |
| Reproducibility tooling (renv, Docker) | No | No |
| Reporting guidelines (STROBE for observational, CONSORT for RCTs, PRISMA for reviews) | No | No |
| Causal inference DAG documentation | Mentioned briefly in README | No |
| Missing data handling (MCAR/MAR/MNAR, multiple imputation) | No | No |
| Sample size / power calculation justification | No | No |
| Sensitivity analysis plan | Mentioned indirectly in README | No |
| Blinding / allocation concealment | No | No |
| Data access and confidentiality (no sensitive paths in git commits) | No | No |

If `/epi` scoping questions do not collect at least ethics status, study design type, target reporting guideline, and reproducibility approach, the resulting task description will be missing information that determines the entire implementation approach.

### 10. The `"r"` alias in the routing is semantically ambiguous

The current extension claims `r` as an alias for `epidemiology` in routing (README and EXTENSION.md). R is a general-purpose statistical language used by the lean4, typst, python, and other extensions' users. Reserving `r` as an alias for the epidemiology extension would incorrectly route any R-based task that is not epidemiological (e.g., an R-based data cleaning script for a completely different domain). The alias should be dropped or scoped.

### 11. The `patterns/` directory is listed in agents but not in `provides.context`

The implementation agent context says `Loads from: project/epidemiology/patterns/`. The `context/project/epidemiology/patterns/` directory exists and contains `statistical-modeling.md`. However, the `index-entries.json` lists this file with path `project/epidemiology/patterns/statistical-modeling.md`. The `provides.context` in `manifest.json` lists only `"project/epidemiology"` (not recursively explicit). This is fine as-is if the loader handles recursive discovery, but should be confirmed.

### 12. `opencode-agents.json` references a `.opencode/` path that does not exist in this repo

The `opencode-agents.json` points to `.opencode/agent/subagents/epidemiology-research-agent.md`. There is no `.opencode/` directory in this repository at the nvim config level. This file is vestigial from a parallel OpenCode system and will never resolve correctly from the nvim config directory.

---

## Unvalidated Assumptions (Explicit List)

1. **"epi:study" is the right compound key** — unvalidated. No epidemiology task has ever been created in this system. The task description assumes `study` is the primary sub-type, but an epidemiology workflow might require multiple compound types (e.g., `epi:model`, `epi:analysis`, `epi:report`). The task description should state whether `/epi` always produces `epi:study` tasks or whether it supports multiple sub-types via mode selection.

2. **The extension is loaded and active** — false. No epidemiology entries appear in the main `context/index.json`, confirming the extension has not been loaded in any active session that persisted its merge state. The extension exists as files but is not functionally active.

3. **R is the assumed implementation language** — partially validated. All context files, agents, and skills reference R. However, `mcp-guide.md` references `rmcp` (a Python package installed via `pip`). Stan (referenced in agents and context) is often called via R but is a separate language. The assumption that R-only tooling is sufficient has not been validated by actual use.

4. **`founder/` and `present/` are complete reference models** — partially true for `present`, false for `founder` as a template. `present` is well-structured and directly analogous. `founder` is more complex than needed for this task. Using `founder` as the primary reference risks over-engineering.

5. **The `/epi` command creates `epi:study` tasks and then exits** — unvalidated. The task description says the command "produces an epi:study task" and the user then runs `/research` and `/plan`. This matches the `present`-style flow. But if the command is expected to also run research immediately (like some older `founder` commands did), the design is different.

6. **The `routing` section absence is an oversight** — likely true but unconfirmed. It may have been intentionally omitted if the extension was designed to be called only via direct skill invocation, not through the `/research` command routing mechanism. The task description treats this as a gap to fix, which is the correct interpretation.

7. **The "interactive questions" for `/epi` are sufficient to scope any study** — unvalidated. The task description says questions should collect "paths to relevant directories, data files, descriptions, or other supporting content." This is a file-gathering framing, not a study-design-scoping framing. The questions listed in the present-style commands (e.g., grant mechanism, funding body, prior drafts) are analogous, but for epidemiology, the study-design decisions (cross-sectional vs. cohort, exposure definition, outcome definition, confounders) are more important than file paths.

8. **`skill-epidemiology-implementation` should handle the final report generation** — assumed but not stated. The task description says `/implement` should "generate a final report of findings." Neither the current implementation agent nor skill says anything about report generation. This would be a new capability.

9. **rmcp is available in the user's environment** — unvalidated. The `settings-fragment.json` configures `rmcp` via `uvx rmcp`. If the `rmcp` package is not installed or `uvx` is not available, the MCP-dependent features in the implementation agent will fail silently.

---

## Open Questions

1. **Should `epi` replace `epidemiology` entirely as the extension name (directory, manifest name, agent names), or is `epi` only the task_type prefix?** The task description says `epi` is the "extension prefix" for compound types (e.g., `epi:study`), but the extension directory remains `epidemiology/`. These should be consistent.

2. **What other compound sub-types should be defined alongside `epi:study`?** If the extension eventually supports `epi:model`, `epi:analysis`, or `epi:report` as separate routing targets (analogous to `present:grant`, `present:budget`, `present:timeline`), the routing table and `/epi` command mode design should accommodate them now rather than requiring a future overhaul.

3. **What should happen when `/epi` is invoked with a task number?** The `present`-style commands resume research on existing tasks when given a task number. Should `/epi N` resume the task (running skill-epidemiology-research), or should it run a design-confirmation step analogous to `/slides N --design`?

4. **Should the `/epi` command collect ethics/IRB status as a required forcing question?** Ethics approval status affects what data can be accessed, what operations can be performed, and what the final report must include. Omitting this question would produce incomplete task metadata. Is this within scope for the `/epi` command?

5. **What is the expected output artifact of `/implement` for an `epi:study` task?** The task description says "generate a final report of findings." Is this a Quarto document? A plain R Markdown file? A structured Markdown report in the specs directory? The implementation agent needs explicit guidance on output format.

6. **Should the extension's context files be updated to reflect real reproducibility standards?** The current context references no reproducibility tooling (renv, Docker, `groundhog`). Adding a `patterns/reproducibility.md` context file would be part of a complete overhaul, but is it in scope for this task?

7. **Does the `"r"` alias need to be preserved?** If dropped from routing, any user who created a task with `task_type: "r"` would lose routing to the epidemiology extension. Given no such tasks exist, this is a clean break — but should be an explicit decision.

8. **What does the doc-lint script need to validate after this overhaul?** At minimum, it should check for a `routing` section in manifests that declare commands. Should the planner add this check as part of this task?

9. **Is `rmcp` (the MCP server) actually installed and functional in the user's environment?** The extension's settings-fragment adds it via `uvx rmcp`. If this fails, the implementation agent's tool list references unavailable tools. Validation should be part of the implementation phase.

10. **How should data file paths collected by `/epi` be stored in task metadata?** The task description says the command should collect "paths to relevant directories, data files." The `forcing_data` pattern used by `present` and `founder` commands stores this in state.json. But file paths to data outside the `.config/nvim/` tree may be sensitive. How should the `/epi` implementation handle absolute paths to data directories?

---

## Confidence Level

**High confidence** (verified by direct file inspection):
- The `routing` section is absent from the epidemiology manifest — this is a concrete finding, not a hypothesis.
- The `load_when.languages` vs. `load_when.task_types` field mismatch is real and would prevent context loading.
- No epidemiology tasks exist in active state or archive — confirmed by grepping all specs.
- The doc-lint script does not check for `routing` sections — confirmed by reading the full script.
- `present` and `founder` are structurally very different; `present` is the closer analogy — confirmed by comparing manifests and file counts.
- `opencode-agents.json` references a non-existent `.opencode/` path — confirmed.

**Medium confidence** (inferred from patterns, not directly tested):
- The `"r"` alias is semantically too broad and would cause routing conflicts — reasonable inference, not tested with an actual R-only task.
- The epidemiology-domain requirements (IRB, reproducibility, reporting guidelines) are absent from the context — confirmed by reading all context files, but whether they are needed depends on the user's actual use case.

**Lower confidence** (requires further investigation):
- Whether the extension loader handles recursive context discovery for `provides.context: ["project/epidemiology"]` — would need to read the full `loader.lua` or test empirically.
- Whether `rmcp` is installed and functional in the current environment — not tested.
