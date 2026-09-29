## Typst Extension

This project includes Typst document development support via the typst extension.

### Scope

This extension covers formatting, compilation, styling, and structural concerns for existing
document content, **and the presentation quality of that content** — including chapter/manual
prose review, condensing, and the chapter-quality gate (source grounding, anti-fluff density,
presentation clarity, open-question honesty; see `standards/chapter-quality.md`). Originating or
mathematically verifying new content (proofs, theorems, and their correctness) routes to
`lean4`, `formal`, or `general` as appropriate, not to `typst`; `typst` owns how that content is
written up and presented once it exists, and the measurable quality of that write-up.

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
- Chapter-quality check: `bash .claude/scripts/chapter-quality-check.sh --verbose FILE...`
  (mechanical backstop for `standards/chapter-quality.md`'s SOURCE GROUNDING, ANTI-FLUFF DENSITY,
  PRESENTATION CLARITY, and OPEN-QUESTION HONESTY dimensions, plus structured reviewer prompts
  for its JUDGED rules; BLOCKING findings block, ADVISORY findings -- including every ANTI-FLUFF
  DENSITY finding -- are advisory-only and never affect the exit code)
