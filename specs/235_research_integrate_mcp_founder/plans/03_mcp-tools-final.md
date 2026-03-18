# Implementation Plan: Task #235 (Final)

- **Task**: 235 - research_integrate_mcp_founder
- **Version**: 03 (Final)
- **Created**: 2026-03-18
- **Status**: [COMPLETED]
- **Effort**: 2-3 hours
- **Dependencies**: None
- **Research Inputs**: 02_mcp-tools-research.md
- **Artifacts**: plans/03_mcp-tools-final.md (this file)
- **Standards File**: /home/benjamin/.config/nvim/.claude/CLAUDE.md
- **Type**: meta

## Revision Summary

**Previous Plan (v02)**: 3 tools (SEC EDGAR, Brave Search, Firecrawl)
**This Plan (v03)**: 2 tools (SEC EDGAR, Firecrawl) - dropped Brave Search

**Rationale**: WebSearch built into Claude Code provides equivalent general search capability. Firecrawl adds unique value (full page scraping) that WebSearch lacks.

## Overview

Integrate 2 MCP tools into the founder extension using **lazy loading** architecture:

**Selected Tools (Free Tier Only)**:

| Tool | Free Tier | API Key | Primary Agent | Value |
|------|-----------|---------|---------------|-------|
| SEC EDGAR | Unlimited | None | market-agent | Public company financials |
| Firecrawl | 500/month | Required | analyze-agent | Full page scraping, competitor analysis |

**Dropped**:
- Brave Search: WebSearch provides equivalent functionality

## Tool-to-Agent Mapping

| Agent | MCP Servers | Rationale |
|-------|-------------|-----------|
| market-agent | sec-edgar | Public company financials for market sizing |
| analyze-agent | firecrawl | Scrape competitor websites, pricing pages |
| strategy-agent | (none) | Uses WebSearch for general research |
| founder-plan-agent | (none) | Planning uses research outputs |
| founder-implement-agent | (none) | Implementation doesn't need external data |

## Implementation Phases

### Phase 1: Configure MCP Servers in Manifest [COMPLETED]

**Goal**: Add MCP server definitions to manifest.json.

**Tasks**:
- [ ] Add sec-edgar server configuration (no API key required)
- [ ] Add firecrawl server configuration (requires FIRECRAWL_API_KEY env var)
- [ ] Document env var requirements in README

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/founder/manifest.json` - Add mcp_servers field
- `.claude/extensions/founder/README.md` - Add setup section

**Configuration**:
```json
{
  "mcp_servers": {
    "sec-edgar": {
      "command": "npx",
      "args": ["-y", "@stefanoamorelli/sec-edgar-mcp"],
      "env": {}
    },
    "firecrawl": {
      "command": "npx",
      "args": ["-y", "firecrawl-mcp"],
      "env": {
        "FIRECRAWL_API_KEY": "${FIRECRAWL_API_KEY}"
      }
    }
  }
}
```

**Verification**:
- manifest.json validates as proper JSON
- mcp_servers contains 2 server definitions

---

### Phase 2: Update Agent Frontmatter for Lazy Loading [COMPLETED]

**Goal**: Configure agents to load only their required MCP servers.

**Tasks**:
- [ ] Add `mcp-servers: [sec-edgar]` to market-agent.md
- [ ] Add `mcp-servers: [firecrawl]` to analyze-agent.md
- [ ] Update `allowed-tools:` to include MCP tool names
- [ ] Verify strategy-agent, founder-plan-agent, founder-implement-agent have no mcp-servers

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/market-agent.md`
- `.claude/extensions/founder/agents/analyze-agent.md`

**Example frontmatter updates**:

market-agent.md:
```yaml
---
name: market-agent
description: Market research and sizing analysis
allowed-tools:
  - AskUserQuestion
  - Read
  - Write
  - Glob
  - Bash
  - WebSearch
  - mcp__sec-edgar__*
mcp-servers:
  - sec-edgar
---
```

analyze-agent.md:
```yaml
---
name: analyze-agent
description: Competitive analysis and positioning
allowed-tools:
  - AskUserQuestion
  - Read
  - Write
  - Glob
  - Bash
  - WebSearch
  - mcp__firecrawl__*
mcp-servers:
  - firecrawl
---
```

**Verification**:
- Each agent file has valid frontmatter YAML
- mcp-servers field present only for market-agent and analyze-agent

---

### Phase 3: Create Setup Documentation [COMPLETED]

**Goal**: Document API key setup for Firecrawl.

**Tasks**:
- [ ] Document how to obtain free Firecrawl API key
- [ ] Create env var setup instructions
- [ ] Update EXTENSION.md capabilities section

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/founder/README.md` - Add setup section
- `.claude/extensions/founder/EXTENSION.md` - Update capabilities

**Setup documentation**:
```markdown
## MCP Tool Setup

### SEC EDGAR (No Setup Required)
- Fully free, no API key needed
- Provides access to public company filings (10-K, 10-Q, 8-K)
- Rate limited but generous for research use

### Firecrawl (Free Tier - 500 credits/month)
1. Visit https://firecrawl.dev/
2. Create free account
3. Copy API key from dashboard
4. Add to shell profile: `export FIRECRAWL_API_KEY="your-key"`

Firecrawl provides:
- `scrape`: Full page content as markdown
- `crawl`: Recursive site crawling
- `map`: Site structure mapping
- `extract`: LLM-powered data extraction
```

**Verification**:
- Clear step-by-step Firecrawl setup
- SEC EDGAR documented as zero-config

---

### Phase 4: Verification and Testing [COMPLETED]

**Goal**: Verify lazy loading works and agents can invoke their tools.

**Tasks**:
- [ ] Load founder extension and verify no MCP servers auto-start
- [ ] Invoke market-agent and verify sec-edgar available
- [ ] Invoke analyze-agent and verify firecrawl available
- [ ] Invoke strategy-agent and verify no MCP servers loaded
- [ ] Test sec-edgar tool invocation (no API key needed)
- [ ] Test firecrawl tool invocation (if API key configured)
- [ ] Create implementation summary

**Timing**: 45 minutes

**Files to modify**:
- `specs/235_research_integrate_mcp_founder/summaries/01_mcp-integration-summary.md` - Create

**Verification**:
- Extension loads without errors
- Lazy loading confirmed
- sec-edgar tools work without configuration
- firecrawl tools work with API key

---

## Testing & Validation

- [ ] manifest.json passes JSON validation
- [ ] Agent frontmatter passes YAML validation
- [ ] Extension loads without errors
- [ ] MCP servers only load when relevant agent invoked
- [ ] sec-edgar tools accessible from market-agent
- [ ] firecrawl tools accessible from analyze-agent
- [ ] No MCP servers loaded for other agents

## Artifacts & Outputs

- `specs/235_research_integrate_mcp_founder/plans/03_mcp-tools-final.md` - This plan
- `.claude/extensions/founder/manifest.json` - Updated with mcp_servers
- `.claude/extensions/founder/agents/market-agent.md` - Updated frontmatter
- `.claude/extensions/founder/agents/analyze-agent.md` - Updated frontmatter
- `.claude/extensions/founder/README.md` - Setup documentation
- `specs/235_research_integrate_mcp_founder/summaries/01_mcp-integration-summary.md` - Implementation summary

## Rollback/Contingency

If integration causes issues:
1. Remove `mcp-servers:` from agent frontmatter
2. Clear `mcp_servers` in manifest.json
3. Agents return to baseline tools

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| mcp-servers frontmatter not supported | High | Verify Claude Code supports this pattern |
| Firecrawl API key not configured | Medium | Graceful degradation, clear docs |
| npx package fetch fails | Medium | Document offline fallbacks |
