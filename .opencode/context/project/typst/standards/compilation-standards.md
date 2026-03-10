# Typst Compilation Standards

**Created**: 2026-02-27
**Purpose**: Standards for compiling Typst documents in this project

---

## Basic Commands

### Single Compilation

```bash
typst compile document.typ
```

Output: `document.pdf` in same directory

### Watch Mode

```bash
typst watch document.typ
```

Continuously recompiles on file changes.

### Custom Output Path

```bash
typst compile document.typ output/document.pdf
```

## Compilation Workflow

### Development

1. Start watch mode: `typst watch main.typ`
2. Edit source files
3. View PDF in viewer (auto-refreshes)

### Production

1. Stop watch mode if running
2. Clean compile: `typst compile main.typ`
3. Verify output
4. Commit changes

## Error Handling

### Reading Error Messages

Typst provides clear error messages:

```
error: unknown variable: theorem
   --> chapters/01-introduction.typ:5:1
   |
 5 | #theorem[...]
   | ^^^^^^^^
help: did you mean: theorem (from template.typ)
```

### Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `unknown variable` | Undefined function | Add import |
| `expected ...` | Syntax error | Check brackets/commas |
| `cannot import` | Wrong package path | Verify @preview/ path |
| `file not found` | Missing include | Check relative path |

### Debugging Steps

1. Read the error message carefully
2. Check the indicated line number
3. Verify imports are present
4. Test in isolation if needed

## Project Structure

### Expected Files

```
project/
├── main.typ              # Entry point
├── template.typ          # Shared definitions
├── notation/
│   └── *.typ            # Notation modules
├── chapters/
│   └── *.typ            # Content chapters
└── output/              # Generated PDFs (optional)
```

### Build Scripts

For complex projects, create a build script:

```bash
#!/bin/bash
# build.sh

set -e

echo "Building document..."
typst compile main.typ

echo "Build complete: main.pdf"
```

## CI Integration

### GitHub Actions Example

```yaml
name: Build Typst
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: typst-community/setup-typst@v3
      - run: typst compile main.typ
      - uses: actions/upload-artifact@v4
        with:
          name: document
          path: main.pdf
```

## Performance

### Large Documents

- Split into chapters (included files)
- Use relative imports within chapters
- Consider PDF output size

### Font Handling

- Typst embeds fonts automatically
- Use system fonts or include font files
- Check font licensing for distribution
