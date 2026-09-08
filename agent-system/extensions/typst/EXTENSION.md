## Typst Extension

This project includes Typst document development support via the typst extension.

### Scope

This extension covers formatting, compilation, styling, and structural concerns for existing
document content. Content-creation work (proofs, theorems, chapters, textbook prose) routes to
`lean4`, `formal`, or `general` as appropriate, not to `typst`.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `typst` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (typst compile, typst-element-lint.sh) |

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
- Element-placement/density lint: `bash .claude/scripts/typst-element-lint.sh --verbose FILE...`
  (mechanical backstop for `standards/semantic-element-usage.md`'s Universal Placement Rule;
  placement findings block, item-count and density findings are advisory-only)
