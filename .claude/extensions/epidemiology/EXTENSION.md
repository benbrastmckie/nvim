## Epidemiology Extension

Epidemiology research and implementation support using R and related tooling.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `epidemiology` | skill-epidemiology-research | skill-epidemiology-implementation |
| `r` | rmcp, WebSearch | Rscript, Read, Write |

### Skill-to-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-epidemiology-research | epidemiology-research-agent | Study design, analysis planning, and literature review |
| skill-epidemiology-implementation | epidemiology-implementation-agent | R code implementation, statistical modeling, and data analysis |

### Domain Routing

**Epidemiology Domain** (triggers epidemiology-research-agent):
- Infectious disease modeling (SIR, SEIR)
- Survival analysis (Cox models, Kaplan-Meier)
- Bayesian inference (Stan, epidemia)
- Time-varying reproduction number (EpiEstim, EpiNow2)

### Context Import References

Load context files on-demand:

```
Epidemiology domain:
@.claude/extensions/epidemiology/context/project/epidemiology/README.md
@.claude/extensions/epidemiology/context/project/epidemiology/tools/r-packages.md
```
