# Epidemiology Extension

R-based epidemiology research and implementation. Covers study design, statistical modeling, causal inference, missing data handling, and Bayesian analysis.

## Command

`/epi` -- Stage 0 interactive command. Presents study design options and routes to the appropriate task type for downstream research, plan, and implement-phase workflows.

## Compound Routing

Three task type keys route to extension agents:

| Key | Description |
|-----|-------------|
| `epi` | General epidemiology tasks |
| `epi:study` | Study-specific analysis tasks |
| `epidemiology` | Full-name alias (equivalent to `epi`) |

## Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-epi-research | epi-research-agent | opus | Study design, causal inference, literature review |
| skill-epi-implement | epi-implement-agent | opus | R code, statistical modeling, data analysis |

Planning routes directly to the core `planner-agent` (no per-function skill layer).

## MCP Server

The `rmcp` MCP server is optional. When available, it enables direct R session interaction for package exploration and code execution. See `context/project/epidemiology/tools/mcp-guide.md`.

## File Inventory

### Agents
- `agents/epi-research-agent.md` -- Research agent definition
- `agents/epi-implement-agent.md` -- Implementation agent definition

### Skills
- `skills/skill-epi-research/SKILL.md` -- Research skill
- `skills/skill-epi-implement/SKILL.md` -- Implementation skill

### Commands
- `commands/epi.md` -- `/epi` command definition

### Context (15 files)

**Domain** (6 files): `study-designs.md`, `causal-inference.md`, `missing-data.md`, `data-management.md`, `reporting-standards.md`, `r-workflow.md`

**Patterns** (4 files): `statistical-modeling.md`, `observational-methods.md`, `analysis-phases.md`, `strobe-checklist.md`

**Templates** (2 files): `analysis-plan.md`, `findings-report.md`

**Tools** (2 files): `r-packages.md` (323 lines, covers EpiModel, epidemia, EpiEstim, EpiNow2, survival, Stan, tidyverse, and more), `mcp-guide.md`

**Overview** (1 file): `README.md`

### Configuration
- `manifest.json` -- Extension manifest with routing table
- `index-entries.json` -- Context index entries (15 entries)
- `EXTENSION.md` -- CLAUDE.md merge fragment
- `opencode-agents.json` -- OpenCode agent definitions
- `settings-fragment.json` -- Settings merge fragment

## References

- [EpiModel](https://www.epimodel.org/)
- [epidemia](https://imperialcollegelondon.github.io/epidemia/)
- [EpiEstim](https://mrc-ide.github.io/EpiEstim/)
- [EpiNow2](https://epiforecasts.io/EpiNow2/)
- [Stan](https://mc-stan.org/)
