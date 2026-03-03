# Hybrid Frontmatter Adapter

**Version**: 1.0  
**Created**: 2026-01-24  
**Purpose**: Enable dual frontmatter compatibility for command discovery and routing  

---

## Overview

The Hybrid Adapter allows commands to support **both legacy and new frontmatter formats**:

```yaml
# LEGACY FORMAT (for discovery & routing)
name: command_name
agent: orchestrator
routing:
  language_based: true
  # ... routing config

# NEW FORMAT (preserved for future use)
command: command_name
mode: command
arguments:
  # ... argument definitions
```

## Frontmatter Transformation Rules

### 1. Dual Frontmatter Support
Commands can specify **both formats simultaneously**:

```yaml
---
# Legacy fields (required for current system)
name: research
agent: orchestrator
routing:
  language_based: true
  lean: lean-research-agent
  default: general-research-agent

# New fields (preserved for future migration)
command: research
mode: command
arguments:
  name: task_number
  type: integer
  required: true
  description: Task number to research
```

### 2. Auto-Detection Logic
**Priority Order**:
1. **Legacy fields present** → Use legacy pattern for routing
2. **New fields only** → Use new pattern with adapter
3. **Both present** → Use hybrid mode (legacy routing, new validation)

### 3. Argument Parsing Strategy
**Legacy Mode**: Parse from `$ARGUMENTS` using bash techniques  
**New Mode**: Parse from structured arguments array  
**Hybrid Mode**: Try legacy first, fallback to new

## Implementation Notes

### File Structure
Commands using hybrid pattern should:
- Keep all legacy frontmatter fields for discovery
- Preserve all new frontmatter fields for future compatibility
- Use legacy routing for agent selection
- Use new context loading strategies where available

### Migration Path
**Phase 1**: Add legacy fields to existing commands  
**Phase 2**: Create hybrid adapter layer for new features  
**Phase 3**: Gradual migration to new-only format

### Compatibility Matrix

| Pattern | Discovery | Routing | Context Loading | Migration Status |
|----------|------------|---------|------------------|----------------|
| Legacy Only | ✅ | ✅ | ❌ | Current Issue |
| New Only | ❌ | ❌ | ✅ | Future Goal |
| Hybrid | ✅ | ✅ | ✅ | **Current Solution** |

---

**See Also**: 
- `command-discovery.md` - Discovery algorithm details
- `argument-normalizer.md` - Argument parsing strategies  
- `context-bridge.md` - Context loading integration