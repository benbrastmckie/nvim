# Command Routing Context

Token budget: ~200 tokens

## Language → Skill Routing

| Language | Research Skill | Implementation Skill |
|----------|---------------|---------------------|
| neovim | skill-neovim-research | skill-neovim-implementation |
| general | skill-researcher | skill-implementer |
| meta | skill-researcher | skill-implementer |
| markdown | skill-researcher | skill-implementer |

**Note**: Additional languages (latex, typst) are available via extensions in `.claude/extensions/`.

## Status Transitions

| Command | From Status | To Status (In-Progress) | To Status (Complete) |
|---------|-------------|------------------------|---------------------|
| /research | not_started | researching | researched |
| /plan | researched, not_started | planning | planned |
| /implement | planned, implementing, partial | implementing | completed |
| /revise | planned, implementing | planning | planned |

## Task Lookup

```bash
jq -r --arg num "$N" '.active_projects[] | select(.project_number == ($num | tonumber))' specs/state.json
```

## Session ID

```bash
# Portable command (works on NixOS, macOS, Linux - no xxd dependency)
sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')
```
