# Implementation Plan: Task #235

- **Task**: 235 - research_integrate_mcp_founder
- **Status**: [NOT STARTED]
- **Effort**: 4-6 hours
- **Dependencies**: None
- **Research Inputs**: None
- **Artifacts**: plans/01_mcp-tools-integration.md (this file)
- **Standards**:
  - .claude/context/core/standards/plan.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Research and integrate MCP (Model Context Protocol) tools to enhance the founder extension's market research and business strategy capabilities. Currently, the founder extension v2.0 has 5 agents (market, analyze, strategy, plan, implement) that rely entirely on user input via forcing questions with no independent data gathering capabilities. The `mcp_servers` field in manifest.json is empty. This plan will research available MCP tools for market data, company information, competitive intelligence, and financial data, then integrate the best options into the extension.

### Current State Analysis

The founder extension agents have limited tools:
- `AskUserQuestion` - Interactive forcing questions
- `Read/Write/Glob` - File operations
- `Bash` - Verification only

No web research tools (WebSearch, WebFetch) or external data APIs are available to these agents, limiting their ability to gather independent market intelligence.

## Goals & Non-Goals

**Goals**:
- Identify MCP tools suitable for market research (market data, industry reports)
- Identify MCP tools suitable for business strategy (competitive intelligence, trends)
- Evaluate tools for authentication requirements, cost, and reliability
- Integrate selected tools into manifest.json mcp_servers field
- Update agent Allowed Tools sections to include new MCP capabilities
- Verify integration with basic functionality tests

**Non-Goals**:
- Building custom MCP servers (using existing community/official tools)
- Comprehensive tool evaluation with production testing (basic verification only)
- Modifying agent execution flow or forcing question patterns
- Adding paid API integrations without explicit approval

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| No suitable free MCP tools exist | High | Medium | Fallback to WebSearch/WebFetch tools |
| MCP tools require API keys | Medium | High | Document setup requirements, use env vars |
| Tool integration breaks existing agents | High | Low | Test agents after integration |
| Inconsistent tool availability | Medium | Medium | Design with graceful degradation |

## Implementation Phases

### Phase 1: Research MCP Tools for Market Research [NOT STARTED]

**Goal**: Identify and document available MCP tools for market data, company information, and industry reports.

**Tasks**:
- [ ] Search for MCP marketplace/registry for market research tools
- [ ] Research official Anthropic MCP servers (if any for business data)
- [ ] Investigate community MCP tools for company data (Crunchbase, PitchBook, etc.)
- [ ] Document financial data MCP options (stock data, market indices)
- [ ] Evaluate industry report access MCPs (Gartner, Statista, etc.)
- [ ] Create comparison table of market research tools

**Timing**: 1-1.5 hours

**Files to modify**:
- Create: `specs/235_research_integrate_mcp_founder/reports/01_market-research-mcp.md`

**Verification**:
- Report contains at least 3-5 evaluated tools
- Each tool has authentication, cost, and capability documented

---

### Phase 2: Research MCP Tools for Business Strategy [NOT STARTED]

**Goal**: Identify MCP tools for competitive intelligence, trend analysis, and strategic data.

**Tasks**:
- [ ] Research competitive intelligence MCPs (company tracking, news)
- [ ] Investigate trend analysis tools (Google Trends, social listening)
- [ ] Explore web scraping/search MCPs for competitor monitoring
- [ ] Document LinkedIn/professional network MCPs (if available)
- [ ] Evaluate news aggregation MCPs for market signals
- [ ] Create comparison table of strategy tools

**Timing**: 1-1.5 hours

**Files to modify**:
- Create: `specs/235_research_integrate_mcp_founder/reports/02_strategy-tools-mcp.md`

**Verification**:
- Report contains at least 3-5 evaluated tools
- Tools cover competitive, trends, and news categories

---

### Phase 3: Tool Evaluation and Selection [NOT STARTED]

**Goal**: Evaluate researched tools and select best options for integration.

**Tasks**:
- [ ] Score each tool on: ease of setup, reliability, data quality, cost
- [ ] Identify authentication requirements (API keys, OAuth, etc.)
- [ ] Check for rate limits and usage restrictions
- [ ] Determine which tools are actively maintained
- [ ] Select 2-4 tools for integration (prioritize free/open options)
- [ ] Document selection rationale

**Timing**: 0.5-1 hour

**Files to modify**:
- Create: `specs/235_research_integrate_mcp_founder/reports/03_tool-evaluation.md`

**Verification**:
- Clear selection of tools to integrate
- Selection criteria documented with scores

---

### Phase 4: Integrate MCP Servers into Manifest [NOT STARTED]

**Goal**: Add selected MCP servers to the founder extension manifest.json.

**Tasks**:
- [ ] Define mcp_servers entries for each selected tool
- [ ] Document required environment variables for authentication
- [ ] Add setup instructions to extension README
- [ ] Update manifest.json with mcp_servers configuration

**Timing**: 0.5 hour

**Files to modify**:
- `.claude/extensions/founder/manifest.json` - Add mcp_servers entries
- `.claude/extensions/founder/README.md` - Add setup instructions (if exists, or create)

**Verification**:
- manifest.json validates as proper JSON
- mcp_servers field contains selected tools
- Setup instructions are clear and complete

---

### Phase 5: Update Agent Tool Access [NOT STARTED]

**Goal**: Update founder agents to include new MCP tools in Allowed Tools sections.

**Tasks**:
- [ ] Update market-agent.md Allowed Tools with market data MCPs
- [ ] Update analyze-agent.md Allowed Tools with competitive intel MCPs
- [ ] Update strategy-agent.md Allowed Tools with trend/news MCPs
- [ ] Add usage guidance comments for each new tool
- [ ] Document tool-to-agent mapping rationale

**Timing**: 0.5-1 hour

**Files to modify**:
- `.claude/extensions/founder/agents/market-agent.md` - Add MCP tools
- `.claude/extensions/founder/agents/analyze-agent.md` - Add MCP tools
- `.claude/extensions/founder/agents/strategy-agent.md` - Add MCP tools

**Verification**:
- Each agent has appropriate tools for its domain
- Tool descriptions in agents match manifest configuration

---

### Phase 6: Verification and Documentation [NOT STARTED]

**Goal**: Verify integration works and document the changes.

**Tasks**:
- [ ] Test extension load with new mcp_servers
- [ ] Verify agents can invoke MCP tools (manual check)
- [ ] Create summary documentation of added capabilities
- [ ] Update extension EXTENSION.md if capabilities section exists
- [ ] Document any known limitations or setup requirements

**Timing**: 0.5-1 hour

**Files to modify**:
- `.claude/extensions/founder/EXTENSION.md` - Update capabilities (if exists)
- `specs/235_research_integrate_mcp_founder/summaries/01_mcp-integration-summary.md` - Create summary

**Verification**:
- Extension loads without errors
- MCP tools appear in tool listings when extension is active
- Documentation accurately reflects new capabilities

## Testing & Validation

- [ ] manifest.json passes JSON validation after modification
- [ ] Extension loads successfully with new mcp_servers
- [ ] At least one MCP tool is callable from each updated agent
- [ ] No regression in existing agent functionality
- [ ] Setup instructions are reproducible

## Artifacts & Outputs

- `specs/235_research_integrate_mcp_founder/reports/01_market-research-mcp.md` - Market research tools evaluation
- `specs/235_research_integrate_mcp_founder/reports/02_strategy-tools-mcp.md` - Strategy tools evaluation
- `specs/235_research_integrate_mcp_founder/reports/03_tool-evaluation.md` - Final selection and rationale
- `specs/235_research_integrate_mcp_founder/summaries/01_mcp-integration-summary.md` - Implementation summary
- `.claude/extensions/founder/manifest.json` - Updated with mcp_servers
- `.claude/extensions/founder/agents/*.md` - Updated with new tools

## Rollback/Contingency

If integration causes issues:
1. Revert manifest.json mcp_servers to empty object `{}`
2. Remove MCP tool entries from agent Allowed Tools sections
3. Keep research reports for future reference
4. Document blockers encountered for retry with different approach

Fallback option: If no suitable MCP tools exist, recommend adding WebSearch and WebFetch tools to agents instead for basic web research capability.
