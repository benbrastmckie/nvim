## Typst Extension

This project includes Typst document development support via the typst extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `typst` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (typst compile) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-typst-research | typst-research-agent | Typst documentation research |
| skill-typst-implementation | typst-implementation-agent | Typst document implementation |

### Typst vs LaTeX

- Typst uses single-pass compilation (faster)
- Modern scripting syntax with `#` prefix
- Built-in bibliography management
- Simpler package import with `#import`

### Common Operations

- Compile: `typst compile main.typ`
- Watch: `typst watch main.typ`
- Format: Use consistent indentation for readability
- Diagrams: Use `fletcher` package for commutative diagrams
