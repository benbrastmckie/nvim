# Implementation Plan: Task #233

- **Task**: 233 - research_gstack_founder_extension
- **Status**: [NOT STARTED]
- **Effort**: 6-8 hours
- **Dependencies**: None
- **Research Inputs**:
  - [01_gstack-founder-integration.md](../reports/01_gstack-founder-integration.md)
  - [02_founder-skills-deep-dive.md](../reports/02_founder-skills-deep-dive.md)
- **Artifacts**: plans/01_founder-extension-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a founder/ extension implementing three strategic analysis commands (`/market`, `/analyze`, `/strategy`) following the command-skill-agent pattern. The extension integrates gstack's forcing questions and decision frameworks while maintaining compatibility with the existing agent system architecture.

### Research Integration

Key findings integrated from research reports:
- **Forcing questions pattern**: One question per AskUserQuestion, explicit push-back on vague answers
- **Mode-based operation**: 3-4 operational modes giving user explicit scope control
- **Completeness principle**: Always model multiple scenarios/options
- **Decision frameworks**: Two-way doors (move fast) vs one-way doors (be rigorous), inversion, focus as subtraction

## Goals & Non-Goals

**Goals**:
- Create `/market` command for TAM/SAM/SOM market sizing analysis
- Create `/analyze` command for competitive analysis and positioning
- Create `/strategy` command for go-to-market strategy development
- Implement command-skill-agent pattern for all three commands
- Create context files with forcing questions and decision frameworks
- Follow extension manifest pattern from present/ extension

**Non-Goals**:
- Browser automation (gstack's /browse, /qa)
- Git-based metrics collection (/retro functionality)
- Cookie management or server daemon architecture
- Real-time data fetching from market research APIs

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Forcing questions feel heavyweight | M | M | Make mode selection optional with sensible defaults |
| Question fatigue from users | M | M | Allow "skip" with graceful degradation |
| Overlap with existing /research | L | L | Position founder skills as strategic analysis, not web research |
| Context files become too large | M | L | Split into domain/patterns/templates subdirectories |

## Implementation Phases

### Phase 1: Extension Scaffold [COMPLETED]

**Goal**: Create the extension directory structure and manifest

**Tasks**:
- [ ] Create `.claude/extensions/founder/` directory structure
- [ ] Create `manifest.json` with routing and merge targets
- [ ] Create `EXTENSION.md` with extension documentation
- [ ] Create `index-entries.json` for context discovery

**Timing**: 30 minutes

**Files to create**:
- `.claude/extensions/founder/manifest.json`
- `.claude/extensions/founder/EXTENSION.md`
- `.claude/extensions/founder/index-entries.json`

**Verification**:
- manifest.json validates as JSON
- Extension structure matches present/ extension pattern

---

### Phase 2: Context Files [COMPLETED]

**Goal**: Create domain knowledge, patterns, and template files

**Tasks**:
- [ ] Create `context/project/founder/domain/business-frameworks.md` - TAM/SAM/SOM, business model canvas
- [ ] Create `context/project/founder/domain/strategic-thinking.md` - CEO cognitive patterns, YC principles
- [ ] Create `context/project/founder/patterns/forcing-questions.md` - Forcing question framework from gstack
- [ ] Create `context/project/founder/patterns/decision-making.md` - Two-way doors, inversion, focus as subtraction
- [ ] Create `context/project/founder/patterns/mode-selection.md` - Operational modes pattern
- [ ] Create `context/project/founder/templates/market-sizing.md` - TAM/SAM/SOM template
- [ ] Create `context/project/founder/templates/competitive-analysis.md` - Competitor analysis template
- [ ] Create `context/project/founder/templates/gtm-strategy.md` - Go-to-market template
- [ ] Create `context/project/founder/README.md` - Context directory documentation

**Timing**: 1.5 hours

**Files to create**:
- `.claude/extensions/founder/context/project/founder/domain/business-frameworks.md`
- `.claude/extensions/founder/context/project/founder/domain/strategic-thinking.md`
- `.claude/extensions/founder/context/project/founder/patterns/forcing-questions.md`
- `.claude/extensions/founder/context/project/founder/patterns/decision-making.md`
- `.claude/extensions/founder/context/project/founder/patterns/mode-selection.md`
- `.claude/extensions/founder/context/project/founder/templates/market-sizing.md`
- `.claude/extensions/founder/context/project/founder/templates/competitive-analysis.md`
- `.claude/extensions/founder/context/project/founder/templates/gtm-strategy.md`
- `.claude/extensions/founder/context/project/founder/README.md`

**Verification**:
- All context files have valid markdown structure
- Forcing questions match gstack patterns from research
- Templates include placeholder sections and guidance

---

### Phase 3: /market Command Stack [COMPLETED]

**Goal**: Implement /market command with skill and agent

**Tasks**:
- [ ] Create `commands/market.md` - Thin orchestrator with GATE IN/DELEGATE/GATE OUT
- [ ] Create `skills/skill-market/SKILL.md` - Skill wrapper with trigger conditions
- [ ] Create `agents/market-agent.md` - Market sizing agent with forcing questions

**Timing**: 1.5 hours

**Files to create**:
- `.claude/extensions/founder/commands/market.md`
- `.claude/extensions/founder/skills/skill-market/SKILL.md`
- `.claude/extensions/founder/agents/market-agent.md`

**Agent Behavior** (market-agent):
1. Determine TAM approach: top-down vs bottom-up vs value-theory
2. Use forcing questions for each market tier:
   - TAM: "How many entities worldwide have this problem?"
   - SAM: "Which segments can you NOT serve? Why?"
   - SOM: "What's your realistic market share in Year 1?"
3. Generate market-sizing artifact with concentric circles diagram
4. Return structured JSON with artifacts array

**Verification**:
- Command follows GATE IN/DELEGATE/GATE OUT pattern
- Skill routes to agent via Task tool
- Agent uses @-references for context loading
- Agent returns valid subagent-return.md format

---

### Phase 4: /analyze Command Stack [NOT STARTED]

**Goal**: Implement /analyze command with skill and agent

**Tasks**:
- [ ] Create `commands/analyze.md` - Thin orchestrator with argument parsing
- [ ] Create `skills/skill-analyze/SKILL.md` - Skill wrapper with trigger conditions
- [ ] Create `agents/analyze-agent.md` - Competitive analysis agent

**Timing**: 1.5 hours

**Files to create**:
- `.claude/extensions/founder/commands/analyze.md`
- `.claude/extensions/founder/skills/skill-analyze/SKILL.md`
- `.claude/extensions/founder/agents/analyze-agent.md`

**Agent Behavior** (analyze-agent):
1. Map competitive landscape: direct, indirect, potential competitors
2. Per-competitor analysis with forcing questions:
   - "What do they do better than you?"
   - "Where are they vulnerable?"
3. Generate 2x2 positioning map (ASCII)
4. Produce competitive battle cards
5. Return artifact with strategic recommendations

**Verification**:
- Follows command-skill-agent pattern
- Agent produces positioning map in artifact
- Forcing questions match gstack patterns

---

### Phase 5: /strategy Command Stack [NOT STARTED]

**Goal**: Implement /strategy command with skill and agent

**Tasks**:
- [ ] Create `commands/strategy.md` - Thin orchestrator with mode selection
- [ ] Create `skills/skill-strategy/SKILL.md` - Skill wrapper with trigger conditions
- [ ] Create `agents/strategy-agent.md` - GTM strategy agent with modes

**Timing**: 1.5 hours

**Files to create**:
- `.claude/extensions/founder/commands/strategy.md`
- `.claude/extensions/founder/skills/skill-strategy/SKILL.md`
- `.claude/extensions/founder/agents/strategy-agent.md`

**Agent Behavior** (strategy-agent):
1. Mode selection via AskUserQuestion: LAUNCH, SCALE, PIVOT, EXPAND
2. Positioning framework: "For [target] who [problem], [product] is a [category]..."
3. Channel analysis with forcing questions:
   - "Where do your customers already spend time?"
   - "What worked for your closest competitor?"
4. Generate GTM strategy artifact with 90-day plan
5. Define metrics and milestones per stage

**Verification**:
- Mode selection appears as first interaction
- GTM artifact includes positioning statement
- Channel prioritization uses forcing questions

---

### Phase 6: Integration and Testing [NOT STARTED]

**Goal**: Integrate extension and verify all components work together

**Tasks**:
- [ ] Update index-entries.json with all context file entries
- [ ] Verify manifest.json routing is correct
- [ ] Test /market command invocation
- [ ] Test /analyze command invocation
- [ ] Test /strategy command invocation
- [ ] Verify context files load via @-references
- [ ] Create README.md for extension root

**Timing**: 1 hour

**Files to update/create**:
- `.claude/extensions/founder/index-entries.json` (update with all entries)
- `.claude/extensions/founder/README.md`

**Verification**:
- All three commands can be invoked
- Context files are discovered via index.json queries
- Agents produce expected artifact formats
- No errors in manifest parsing

## Testing & Validation

- [ ] Extension loads without manifest errors
- [ ] `/market` produces market-sizing artifact with TAM/SAM/SOM
- [ ] `/analyze` produces competitive analysis with positioning map
- [ ] `/strategy` produces GTM strategy with 90-day plan
- [ ] Context files load via @-references in agents
- [ ] Forcing questions follow one-per-AskUserQuestion pattern
- [ ] Mode selection works for /strategy command
- [ ] All agents return valid subagent-return.md format

## Artifacts & Outputs

**Extension Structure**:
```
.claude/extensions/founder/
  manifest.json
  EXTENSION.md
  index-entries.json
  README.md

  commands/
    market.md
    analyze.md
    strategy.md

  skills/
    skill-market/
      SKILL.md
    skill-analyze/
      SKILL.md
    skill-strategy/
      SKILL.md

  agents/
    market-agent.md
    analyze-agent.md
    strategy-agent.md

  context/
    project/
      founder/
        README.md
        domain/
          business-frameworks.md
          strategic-thinking.md
        patterns/
          forcing-questions.md
          decision-making.md
          mode-selection.md
        templates/
          market-sizing.md
          competitive-analysis.md
          gtm-strategy.md
```

**Output Artifacts** (generated by commands):
- `founder/market-sizing-{datetime}.md` - TAM/SAM/SOM analysis
- `founder/competitive-analysis-{datetime}.md` - Competitor landscape
- `founder/gtm-strategy-{datetime}.md` - Go-to-market plan

## Rollback/Contingency

If extension fails to load or causes issues:
1. Delete `.claude/extensions/founder/` directory
2. No changes to core .claude/ files required
3. Extension is fully self-contained

If individual commands fail:
1. Check agent @-references resolve correctly
2. Verify manifest.json routing entries
3. Test skill invocation in isolation
