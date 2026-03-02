## Lean 4 Extension

This project includes Lean 4 theorem prover support via the lean extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `lean4` | WebSearch, WebFetch, Read, Lean MCP | Read, Write, Edit, Bash (lake), Lean MCP |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-lean-research | lean-research-agent | Lean/Mathlib research |
| skill-lean-implementation | lean-implementation-agent | Lean proof implementation |
| skill-lake-repair | lean-implementation-agent | Lake build repair |
| skill-lean-version | (direct execution) | Lean version management |

### MCP Integration

The `lean-lsp` MCP server provides:
- Goal state inspection (`lean_goal`)
- Proof search (`lean_state_search`, `lean_hammer_premise`)
- Mathlib lookup (`lean_loogle`, `lean_leansearch`, `lean_leanfinder`)
- Code actions and diagnostics

### Commands

- `/lake` - Build management and error handling
- `/lean` - Lean-specific proof assistance
