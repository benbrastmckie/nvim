# Research: EXTENSION.md Slim-Down Standard

## Problem

When extensions are loaded via `<leader>ac`, their EXTENSION.md content is injected into CLAUDE.md context. Total across 14 extensions: ~1,111 lines.

## Extension Size Audit

| Extension | EXTENSION.md Lines | Category |
|-----------|-------------------|----------|
| founder | 234 | Large |
| present | 216 | Large |
| filetypes | 143 | Large |
| memory | 91 | Medium |
| web | 80 | Medium |
| lean4 | ~70 | Small |
| latex | ~60 | Small |
| typst | ~50 | Small |
| python | ~45 | Small |
| nix | ~40 | Small |
| z3 | ~30 | Small |
| epidemiology | ~25 | Small |
| formal | ~20 | Small |
| neovim | ~7 | Minimal |

## What EXTENSION.md Must Contain (Essential Routing)

1. Language routing table (skill + agent mappings)
2. Command list (name, usage, one-line description)
3. Context import pointers (lazy @-references)

## What Can Move to Context Files

1. Detailed usage examples
2. Migration guides
3. Architecture documentation
4. Troubleshooting sections
5. Extended configuration options

## Proposed Standard

- EXTENSION.md maximum: 50-60 lines
- Must contain: routing table, command list, context pointers
- Everything else: context files loaded on-demand via index.json
- Create `.claude/docs/reference/standards/extension-slim-standard.md`

## Impact

- Target: reduce total EXTENSION.md from ~1,111 to ~350 lines (~68% reduction)
- Foundation task for #284 (actual migration)
