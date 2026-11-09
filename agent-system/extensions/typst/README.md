# Typst Extension

Typst document development support with single-pass compilation and modern scripting syntax.

## Overview

| Task Type | Agent | Purpose |
|-----------|-------|---------|
| `typst` | typst-research-agent | Typst documentation/package research |
| `typst` | typst-implementation-agent | Typst document implementation |

## Installation

Loaded via the extension picker. Once loaded, `typst` becomes a recognized task type.

## Commands

No dedicated commands. Use the core research, plan, and implement phases (dispatched via `/orchestrate`) with `task_type: "typst"`.

## Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-typst-research | typst-research-agent | Typst documentation research |
| skill-typst-implementation | typst-implementation-agent | Typst document implementation |

## Language Routing

| Task Type | Research Tools | Implementation Tools |
|-----------|----------------|---------------------|
| `typst` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash(typst compile) |

## Typst vs LaTeX

| Aspect | Typst | LaTeX |
|--------|-------|-------|
| Compilation | Single-pass (fast) | Multi-pass (slow) |
| Syntax | Modern, scripting-like with `#` | Macro-based |
| Bibliography | Built-in | bibtex/biber |
| Package import | `#import "@preview/..."` | `\usepackage{...}` |

## Common Operations

```bash
typst compile main.typ          # One-shot compilation
typst watch main.typ            # Live rebuild on save
```

- **Diagrams**: Use the `fletcher` package for commutative diagrams
- **Math**: Inline `$...$`, display `$ ... $` on its own line
- **Packages**: Prefer `@preview` packages from the Typst package registry

## References

- [Typst Documentation](https://typst.app/docs/)
- [Typst Package Registry](https://typst.app/universe/)
- [fletcher package](https://typst.app/universe/package/fletcher)
