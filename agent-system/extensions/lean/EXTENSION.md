## Lean 4 Extension

This project includes Lean 4 theorem prover support via the lean extension: proof development,
Mathlib search, and Lake build management, backed by the `lean-lsp` MCP server.

### Routing Table

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `lean4` | WebSearch, WebFetch, Read, Lean MCP | Read, Write, Edit, Bash (lake), Lean MCP |

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-lean-research | lean-research-agent | Lean/Mathlib research |
| skill-lean-implementation | lean-implementation-agent | Lean proof implementation |
| skill-lake-repair | lean-implementation-agent | Lake build repair |
| skill-lean-version | (direct execution) | Lean version management |

Rules (both apply to `**/*.lean`): `lean4.md` — Lean 4 conventions and MCP tool guidance;
`plan-compliance.md` — plan-sequence compliance. `--hard` routing: see hard-mode pointer below.

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/lake` | `/lake` | Build management and error handling |
| `/lean` | `/lean` | Lean-specific proof assistance |
| `/lean` | `/lean doctor` | Probe the Comparator environment: binary presence + C3 `lean4export` version match |

### Context Pointers

- `.claude/context/project/lean4/README.md` - Lean context index and navigation
- `.claude/context/project/lean4/domain/hard-mode.md` - `--hard` routing, agents, contracts
- `.claude/context/project/lean4/tools/mcp-tools-guide.md` - Lean MCP server tool reference
- `.claude/context/project/lean4/tools/blocked-mcp-tools.md` - Blocked tools and alternatives
- `.claude/context/project/lean4/patterns/mcp-fallback-table.md` - MCP tool fallback strategies
- `.claude/context/project/lean4/tools/comparator-guide.md` - Comparator trust model: what a green result does and does not certify
