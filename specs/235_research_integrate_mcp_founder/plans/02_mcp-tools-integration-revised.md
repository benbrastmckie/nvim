# Implementation Plan: Task #235 (Revised)

- **Task**: 235 - research_integrate_mcp_founder
- **Version**: 02 (Revised)
- **Created**: 2026-03-18
- **Status**: [NOT STARTED]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: 02_mcp-tools-research.md
- **Artifacts**: plans/02_mcp-tools-integration-revised.md (this file)
- **Standards File**: /home/benjamin/.config/nvim/.claude/CLAUDE.md
- **Type**: meta

## Revision Summary

**Previous Plan (v01)**: 6 phases, 4-6 hours, research-first approach
**This Plan (v02)**: 4 phases, 3-4 hours, implementation-focused with research complete

**Key Changes**:
1. Research phases removed (completed in 02_mcp-tools-research.md)
2. Focus on **free-tier only** tools (no paid subscriptions)
3. **Lazy loading** via agent-specific MCP configuration (not global manifest)
4. Reduced scope to 3 essential tools with highest value/effort ratio

## Overview

Integrate MCP tools into the founder extension using a **lazy loading** architecture where MCP servers are only loaded when specific agents are invoked, not globally. This prevents context clutter and reduces startup overhead.

**Selected Tools (Free Tier Only)**:

| Tool | Free Tier | No API Key | Primary Agent | Value |
|------|-----------|------------|---------------|-------|
| SEC EDGAR | Unlimited | Yes | market-agent | Public company financials |
| Brave Search | 1 req/sec | No (free API key) | All founder agents | General web search |
| Firecrawl | 500/month | No (free API key) | analyze-agent | Competitor website scraping |

**Excluded (per user requirements)**:
- Crunchbase: Requires paid tier for useful data volume
- LinkedIn: OAuth complexity, rate limiting
- Alpha Vantage: API key setup burden vs value

## Goals & Non-Goals

**Goals**:
- Integrate 3 essential MCP tools with free-tier access
- Implement lazy loading so tools only load with their assigned agent
- Document API key setup for Brave Search and Firecrawl
- Verify agents can invoke their assigned tools

**Non-Goals**:
- Paid API integrations
- Complex authentication flows (OAuth, etc.)
- Building custom MCP servers
- Global MCP server loading (explicit anti-goal)

## Architecture: Lazy Loading Pattern

### Problem
Loading all MCP servers globally in `manifest.json` clutters context for agents that don't need them.

### Solution
Use **agent-specific MCP configuration** in each agent's frontmatter via the `mcp-servers:` field. This field tells Claude Code to load specific MCP servers only when that agent is spawned.

```yaml
# In agent frontmatter
mcp-servers:
  - sec-edgar
  - brave-search
```

The MCP server definitions are still declared in `manifest.json`, but only loaded when an agent with matching `mcp-servers:` entries is invoked.

### Tool-to-Agent Mapping

| Agent | MCP Servers | Rationale |
|-------|-------------|-----------|
| market-agent | sec-edgar, brave-search | Market sizing needs financials + search |
| analyze-agent | brave-search, firecrawl | Competitor analysis needs search + scraping |
| strategy-agent | brave-search | GTM strategy needs general search |
| founder-plan-agent | (none) | Planning uses research outputs, not live data |
| founder-implement-agent | (none) | Implementation doesn't need external data |

## Implementation Phases

### Phase 1: Configure MCP Servers in Manifest [NOT STARTED]

**Goal**: Add MCP server definitions to manifest.json (declarations only, not auto-loaded).

**Tasks**:
- [ ] Add sec-edgar server configuration (no API key required)
- [ ] Add brave-search server configuration (requires BRAVE_API_KEY env var)
- [ ] Add firecrawl server configuration (requires FIRECRAWL_API_KEY env var)
- [ ] Document env var requirements in README

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/manifest.json` - Add mcp_servers field
- `.claude/extensions/founder/README.md` - Add setup section

**Verification**:
- manifest.json validates as proper JSON
- mcp_servers contains 3 server definitions
- README documents required env vars

**Configuration**:
```json
{
  "mcp_servers": {
    "sec-edgar": {
      "command": "npx",
      "args": ["-y", "@stefanoamorelli/sec-edgar-mcp"],
      "env": {}
    },
    "brave-search": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-brave-search"],
      "env": {
        "BRAVE_API_KEY": "${BRAVE_API_KEY}"
      }
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

---

### Phase 2: Update Agent Frontmatter for Lazy Loading [NOT STARTED]

**Goal**: Configure each agent to load only its required MCP servers.

**Tasks**:
- [ ] Add `mcp-servers: [sec-edgar, brave-search]` to market-agent.md
- [ ] Add `mcp-servers: [brave-search, firecrawl]` to analyze-agent.md
- [ ] Add `mcp-servers: [brave-search]` to strategy-agent.md
- [ ] Update `allowed-tools:` to include MCP tool names
- [ ] Verify founder-plan-agent and founder-implement-agent have no mcp-servers

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/market-agent.md`
- `.claude/extensions/founder/agents/analyze-agent.md`
- `.claude/extensions/founder/agents/strategy-agent.md`

**Verification**:
- Each agent file has valid frontmatter YAML
- mcp-servers field present only for data-gathering agents
- allowed-tools includes appropriate MCP tool prefixes

**Example frontmatter update**:
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
  - mcp__sec-edgar__*
  - mcp__brave-search__*
mcp-servers:
  - sec-edgar
  - brave-search
---
```

---

### Phase 3: Create Setup Documentation [NOT STARTED]

**Goal**: Document API key setup and usage patterns for users.

**Tasks**:
- [ ] Document how to obtain free Brave Search API key
- [ ] Document how to obtain free Firecrawl API key
- [ ] Create env var setup instructions (shell profile, .env patterns)
- [ ] Add troubleshooting section for common MCP issues
- [ ] Update EXTENSION.md capabilities section

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/README.md` - Expand setup section
- `.claude/extensions/founder/EXTENSION.md` - Update capabilities

**Verification**:
- Clear step-by-step API key instructions
- Environment variable names documented
- Common errors and solutions listed

**Setup documentation outline**:
```markdown
## MCP Tool Setup

### Brave Search (Free)
1. Visit https://brave.com/search/api/
2. Sign up for free developer account
3. Copy API key
4. Add to shell profile: `export BRAVE_API_KEY="your-key"`

### Firecrawl (Free Tier - 500 credits/month)
1. Visit https://firecrawl.dev/
2. Create free account
3. Copy API key from dashboard
4. Add to shell profile: `export FIRECRAWL_API_KEY="your-key"`

### SEC EDGAR (No Setup Required)
- Fully free, no API key needed
- Rate limited but generous for research use
```

---

### Phase 4: Verification and Testing [NOT STARTED]

**Goal**: Verify lazy loading works and agents can invoke their tools.

**Tasks**:
- [ ] Load founder extension and verify no MCP servers auto-start
- [ ] Invoke market-agent and verify sec-edgar + brave-search available
- [ ] Invoke analyze-agent and verify brave-search + firecrawl available
- [ ] Invoke strategy-agent and verify only brave-search available
- [ ] Invoke founder-plan-agent and verify no MCP servers loaded
- [ ] Test one real tool invocation per agent (if API keys configured)
- [ ] Create implementation summary

**Timing**: 1 hour

**Files to modify**:
- `specs/235_research_integrate_mcp_founder/summaries/01_mcp-integration-summary.md` - Create

**Verification**:
- Extension loads without errors
- Lazy loading confirmed (MCP servers only start with relevant agent)
- At least one tool invocation succeeds per configured agent
- Summary documents what was implemented and any known issues

---

## Testing & Validation

- [ ] manifest.json passes JSON validation
- [ ] Agent frontmatter passes YAML validation
- [ ] Extension loads without errors
- [ ] MCP servers only load when relevant agent invoked (lazy loading)
- [ ] sec-edgar tools accessible from market-agent
- [ ] brave-search tools accessible from all data agents
- [ ] firecrawl tools accessible from analyze-agent
- [ ] No MCP servers loaded for plan/implement agents

## Artifacts & Outputs

- `specs/235_research_integrate_mcp_founder/plans/02_mcp-tools-integration-revised.md` - This plan
- `.claude/extensions/founder/manifest.json` - Updated with mcp_servers
- `.claude/extensions/founder/agents/market-agent.md` - Updated frontmatter
- `.claude/extensions/founder/agents/analyze-agent.md` - Updated frontmatter
- `.claude/extensions/founder/agents/strategy-agent.md` - Updated frontmatter
- `.claude/extensions/founder/README.md` - Setup documentation
- `specs/235_research_integrate_mcp_founder/summaries/01_mcp-integration-summary.md` - Implementation summary

## Rollback/Contingency

If integration causes issues:
1. Remove `mcp-servers:` from agent frontmatter
2. Clear `mcp_servers` in manifest.json
3. Agents return to baseline file-only tools

If specific MCP server fails:
- Remove just that server from manifest and agent configs
- Other servers continue working independently

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| mcp-servers frontmatter not supported | High | Verify Claude Code supports this pattern first |
| API key not configured | Medium | Graceful degradation, clear error messages |
| Free tier rate limits | Low | Document limits, encourage caching |
| npx package fetch fails | Medium | Document offline fallbacks |
