# Subagents Directory

This directory contains execution subagents that are invoked by command files through the orchestrator's three-layer delegation architecture.

## Architecture

```
Layer 1: Orchestrator (.opencode/agent/orchestrator.md)
  |
  v
Layer 2: Command Files (.opencode/commands/*.md)
  |
  v
Layer 3: Subagents (this directory)
```

## Subagent Categories

### Research Agents
- `lean-research-agent.md` - Lean 4/Mathlib research
- `general-research-agent.md` - General web/codebase research
- `logic-research-agent.md` - Mathematical logic research
- `math-research-agent.md` - Mathematical foundations research
- `latex-research-agent.md` - LaTeX documentation research
- `typst-research-agent.md` - Typst documentation research

### Implementation Agents
- `lean-implementation-agent.md` - Lean proof implementation
- `general-implementation-agent.md` - General file implementation
- `latex-implementation-agent.md` - LaTeX document implementation
- `typst-implementation-agent.md` - Typst document implementation

### Planning Agents
- `planner-agent.md` - Implementation plan creation

### Utility Agents
- `meta-builder-agent.md` - System builder for .opencode/ changes
- `document-converter-agent.md` - Document format conversion

## Usage

Subagents are not invoked directly. They are delegated to by command files based on task language and operation type. See `.opencode/OPENCODE.md` for the Skill-to-Agent mapping table.
