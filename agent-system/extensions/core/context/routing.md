# Command Routing Context

Token budget: ~200 tokens

## Language → Skill/Agent Routing

| Language | Research Skill | Implementation |
|----------|---------------|---------------------|
| lean4 | skill-lean-research | skill-lean-implementation |
| latex | skill-latex-research | skill-latex-implementation |
| typst | skill-typst-research | skill-typst-implementation |
| python | skill-python-research | skill-python-implementation |
| nix | skill-nix-research | skill-nix-implementation |
| web | skill-web-research | skill-web-implementation |
| epi, epi:study | skill-epi-research | skill-epi-implement |
| z3 | skill-z3-research | skill-z3-implementation |
| formal, logic, math, physics | skill-formal-research (or subtype-specific) | general-implementation-agent (direct, no skill layer) |
| general | general-research-agent (direct, no skill layer) | general-implementation-agent (direct, no skill layer) |
| meta | general-research-agent (direct, no skill layer) | general-implementation-agent (direct, no skill layer) |
| markdown | general-research-agent (direct, no skill layer) | general-implementation-agent (direct, no skill layer) |

## Status Transitions

| Phase/Command | From Status | To Status (In-Progress) | To Status (Complete) |
|---------|-------------|------------------------|---------------------|
| research dispatch | not_started | researching | researched |
| plan dispatch | researched, not_started | planning | planned |
| implement dispatch | planned, implementing, partial | implementing | completed |
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
