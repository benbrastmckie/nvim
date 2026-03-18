# Research Report: Task #233

**Task**: 233 - research_gstack_founder_extension
**Started**: 2026-03-18T00:00:00Z
**Completed**: 2026-03-18T00:30:00Z
**Effort**: 2-3 hours implementation
**Dependencies**: None
**Sources/Inputs**: GitHub repository garrytan/gstack, WebSearch, existing extension structure analysis
**Artifacts**: specs/233_research_gstack_founder_extension/reports/01_gstack-founder-integration.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- gstack is Garry Tan's open-source "software factory" that transforms Claude Code into a virtual engineering team with 15 specialized skills
- The most valuable elements for a founder/ extension are: `/office-hours` (YC-style strategic guidance), `/plan-ceo-review` (product-level planning), `/retro` (metrics and retrospectives), and `/design-consultation` (design system creation)
- Integration approach: Adapt the decision frameworks and question structures while maintaining the existing extension architecture pattern
- Recommended scope: 3-4 skills focusing on strategic thinking, product review, and metrics - NOT browser automation or QA (those require significant infrastructure)

## Context & Scope

The research analyzed the gstack repository (https://github.com/garrytan/gstack) to identify which elements would be valuable for a "founder/" extension in the existing agent system. The focus was on:

1. Understanding gstack's architecture and skill design patterns
2. Identifying skills most relevant to founder/strategic work
3. Mapping gstack patterns to the existing extension structure
4. Recommending a practical integration approach

## Findings

### gstack Overview

gstack is a collection of 15+ Claude Code skills created by Y Combinator CEO Garry Tan. Key characteristics:

| Aspect | Description |
|--------|-------------|
| Purpose | Transform single AI assistant into specialized team roles |
| Architecture | Skill-based with SKILL.md prompt templates |
| Installation | `~/.claude/skills/gstack/` directory |
| Output | Claimed 10,000+ LOC/day productivity |
| License | MIT (fully open source) |

### Skill Categories Analysis

**Planning & Strategy Skills** (HIGH RELEVANCE):

| Skill | Purpose | Integration Value |
|-------|---------|-------------------|
| `/office-hours` | YC-style product diagnostic and strategic brainstorming | **HIGH** - Core founder skill |
| `/plan-ceo-review` | CEO-level product strategy review before implementation | **HIGH** - Strategic planning |
| `/plan-eng-review` | Architecture and technical design review | MEDIUM - Already have /plan |
| `/plan-design-review` | Design audit with AI slop detection | MEDIUM - Specialized |

**Metrics & Analysis Skills** (MEDIUM RELEVANCE):

| Skill | Purpose | Integration Value |
|-------|---------|-------------------|
| `/retro` | Weekly retrospective with productivity metrics | **HIGH** - Team insights |
| `/design-consultation` | Complete design system creation | MEDIUM - Specialized |

**Development & Testing Skills** (LOW RELEVANCE):

| Skill | Purpose | Integration Value |
|-------|---------|-------------------|
| `/review` | Staff engineer code review | LOW - Already have review |
| `/qa`, `/qa-only` | Browser-based QA testing | LOW - Requires Playwright infra |
| `/browse` | Browser automation | LOW - Major infrastructure |
| `/ship` | Release automation | LOW - Project-specific |

### Key Design Patterns from gstack

**1. Question Structure (AskUserQuestion)**

Every decision point follows this strict format:
```
1. Re-ground: State project, branch, current task (1-2 sentences)
2. Simplify: Explain in plain language; avoid jargon
3. Recommend: Preference with one-line reason
4. Options: Lettered (A, B, C...) with effort scales and completeness scores
```

**2. Mode-Based Operation**

`/plan-ceo-review` uses four distinct modes:
- SCOPE EXPANSION - "Dream big" posture
- SELECTIVE EXPANSION - "Hold baseline + cherry-pick"
- HOLD SCOPE - "Maximum rigor" posture
- SCOPE REDUCTION - "Strip to essentials"

**3. Founder vs Builder Mode**

`/office-hours` routes to different question sets:
- **Startup Mode**: Six forcing questions (Q1-Q6) on demand reality, status quo, specificity
- **Builder Mode**: Generative brainstorming (coolest version, fastest ship path, 10x version)

**4. Completeness Principle**

Core philosophy: "When AI reduces marginal cost of completeness to near-zero, optimize for full implementation rather than shortcuts."

**5. Forced Alternatives**

Every design/plan requires 2-3 distinct approaches:
- Minimal viable (ships fastest)
- Ideal architecture (best long-term)
- Lateral/creative (reframes problem)

### Artifact Patterns

**Design Documents** (`~/.gstack/projects/{slug}/`):
```
- Problem statement + demand evidence
- Premises + approaches considered
- Recommended path + success criteria
- "The Assignment" - one concrete action
- "What I noticed" - mentor-style observations
```

**CEO Plan Documents**:
```
- Vision and scope decisions table
- Phase planning with dependencies
- NOT in scope section (explicit rejections)
- Failure modes registry
- 11-section analysis structure
```

**Retrospective JSON** (`.context/retros/{date}.json`):
```
- Metrics summary (commits, LOC, contributors)
- Per-author statistics
- Session analysis (deep/medium/micro)
- Streaks and trends
```

### Existing Extension Architecture Alignment

The existing extension system provides:

| Component | gstack Equivalent | Integration Approach |
|-----------|-------------------|----------------------|
| manifest.json | package.json | Use manifest.json format |
| EXTENSION.md | CLAUDE.md section | Use EXTENSION.md format |
| agents/*.md | N/A (gstack uses skills only) | Create founder-specific agents |
| skills/*/SKILL.md | */SKILL.md | Adapt SKILL.md format |
| context/project/* | .context/ | Use context/ structure |
| rules/*.md | N/A | Create founder-rules.md |

## Recommendations

### Recommended Founder Extension Structure

```
extensions/founder/
  manifest.json
  EXTENSION.md
  index-entries.json

  skills/
    skill-office-hours/
      SKILL.md           # YC-style strategic guidance
    skill-ceo-review/
      SKILL.md           # Product-level plan review
    skill-retro/
      SKILL.md           # Weekly retrospective

  agents/
    founder-advisor-agent.md    # Routes to appropriate skill

  rules/
    founder-thinking.md         # Strategic thinking patterns

  context/
    project/
      founder/
        README.md
        domain/
          yc-principles.md      # YC startup principles
          product-thinking.md   # Product strategy patterns
        patterns/
          forcing-questions.md  # Question frameworks
          decision-making.md    # Decision patterns
        templates/
          design-doc.md         # Design document template
          ceo-plan.md           # CEO plan template
```

### Skill Adaptation Recommendations

**1. /founder-hours (adapted from /office-hours)**

Adapt the YC office hours skill with:
- Startup mode for actual startup work
- Builder mode for side projects
- Six forcing questions framework
- Premise challenge phase
- Forced alternatives generation
- Design document output

**2. /founder-review (adapted from /plan-ceo-review)**

Adapt the CEO review with:
- Four-mode system (expand/selective/hold/reduce)
- 11-section analysis structure
- Failure modes registry
- NOT in scope documentation
- Integration with existing /plan command

**3. /founder-retro (adapted from /retro)**

Adapt the retrospective with:
- Git-based metrics collection
- Session analysis
- Per-contributor insights
- Trend tracking
- JSON artifact persistence

### Integration Considerations

**Should Integrate**:
- Question structure patterns (re-ground, simplify, recommend, options)
- Mode-based operation for different contexts
- Completeness principle philosophy
- Forced alternatives requirement
- Design document templates

**Should NOT Integrate**:
- Browser automation (/browse, /qa) - requires Playwright infrastructure
- Cookie management - security complexity
- Server daemon architecture - unnecessary for strategic skills
- Template generation system - existing extension system is simpler

### Implementation Priority

| Priority | Skill | Effort | Value |
|----------|-------|--------|-------|
| 1 | skill-office-hours | 2-3 hours | Strategic guidance |
| 2 | skill-ceo-review | 2-3 hours | Product planning |
| 3 | skill-retro | 1-2 hours | Metrics insights |
| 4 | founder-advisor-agent | 1 hour | Routing |

## Decisions

1. **Scope Decision**: Focus on strategic/advisory skills, exclude browser automation
2. **Architecture Decision**: Use existing extension pattern, not gstack's SKILL.md.tmpl system
3. **Artifact Decision**: Store founder artifacts in `specs/{N}_{slug}/founder/` subdirectory
4. **Integration Decision**: Create standalone extension, not merge into core

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| SKILL.md complexity may not translate well | Start with simplified versions, iterate |
| Question frameworks may feel heavyweight | Make mode selection optional with sensible defaults |
| Metrics collection requires git access | Already available in agent system |
| Design document format conflicts | Use founder/ subdirectory in artifacts |

## Context Extension Recommendations

- **Topic**: Founder/startup strategic thinking
- **Gap**: No existing context for product strategy or YC-style thinking patterns
- **Recommendation**: Create `context/project/founder/` with decision frameworks and templates

## Appendix

### Search Queries Used

1. GitHub repository fetch: `https://github.com/garrytan/gstack`
2. ARCHITECTURE.md fetch for skill design patterns
3. Individual SKILL.md files for office-hours, plan-ceo-review, retro, design-consultation
4. WebSearch: "gstack garry tan CEO review office hours planning skills 2026"

### Key References

- [gstack GitHub Repository](https://github.com/garrytan/gstack)
- [gstack on Product Hunt](https://www.producthunt.com/products/gstack)
- [MarkTechPost Coverage](https://www.marktechpost.com/2026/03/14/garry-tan-releases-gstack-an-open-source-claude-code-system-for-planning-code-review-qa-and-shipping/)
- [TechCrunch Analysis](https://techcrunch.com/2026/03/17/why-garry-tans-claude-code-setup-has-gotten-so-much-love-and-hate/)

### gstack Key Files

| File | Purpose |
|------|---------|
| ARCHITECTURE.md | Skill design patterns and reference system |
| CLAUDE.md | Configuration and conventions |
| plan-ceo-review/SKILL.md | CEO-level product review |
| office-hours/SKILL.md | YC-style strategic guidance |
| retro/SKILL.md | Team retrospective |
| design-consultation/SKILL.md | Design system creation |

### Existing Extension Pattern Reference

From `.claude/extensions/nvim/manifest.json`:
```json
{
  "name": "nvim",
  "version": "1.0.0",
  "description": "...",
  "language": "neovim",
  "provides": {
    "agents": ["agent.md"],
    "skills": ["skill-name"],
    "rules": ["rule.md"],
    "context": ["project/domain"]
  },
  "merge_targets": {
    "claudemd": { "source": "EXTENSION.md", "target": ".claude/CLAUDE.md" },
    "index": { "source": "index-entries.json", "target": ".claude/context/index.json" }
  }
}
```
