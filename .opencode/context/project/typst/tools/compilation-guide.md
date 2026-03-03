# Typst Compilation Guide

**Created**: 2026-02-27
**Purpose**: Commands and workflows for compiling Typst documents

---

## Basic Commands

### Compile

```bash
typst compile input.typ [output.pdf]
```

Compiles `input.typ` to PDF. Output defaults to `input.pdf`.

### Watch Mode

```bash
typst watch input.typ [output.pdf]
```

Continuously watches for changes and recompiles.

### Version Info

```bash
typst --version
```

## Command Options

### Font Paths

```bash
typst compile --font-path ./fonts document.typ
```

Add additional font search directories.

### Root Directory

```bash
typst compile --root . document.typ
```

Set the root for relative paths.

### Diagnostic Output

```bash
typst compile --diagnostic-format=short document.typ
```

Options: `human`, `short`

## Workflow Examples

### Development

```bash
# Start watching in background
typst watch main.typ &

# Or use a PDF viewer that auto-refreshes
```

### Production Build

```bash
#!/bin/bash
# build.sh

set -e

echo "Compiling document..."
typst compile main.typ

echo "Checking for warnings..."
typst compile --diagnostic-format=short main.typ 2>&1 | head -20

echo "Done: main.pdf"
ls -lh main.pdf
```

### Multiple Documents

```bash
# Compile all .typ files in directory
for f in *.typ; do
    typst compile "$f"
done
```

## Error Handling

### Understanding Errors

Typst provides clear, actionable errors:

```
error: unknown variable: theorem
   --> chapter-01.typ:15:1
   |
15 | #theorem[Content]
   | ^^^^^^^^
help: did you mean `thmbox` from @preview/thmbox?
```

### Common Fixes

| Error Message | Solution |
|--------------|----------|
| `unknown variable` | Add import statement |
| `expected content` | Check function arguments |
| `cannot find file` | Verify path is relative to root |
| `underfull hbox` | Adjust text or hyphenation |

## Integration

### Makefile

```makefile
.PHONY: all clean

DOCS := $(patsubst %.typ,%.pdf,$(wildcard *.typ))

all: $(DOCS)

%.pdf: %.typ
	typst compile $<

clean:
	rm -f *.pdf
```

### VS Code

Install the "Typst LSP" extension for:
- Syntax highlighting
- Error diagnostics
- Completion suggestions
- Watch mode integration

### Neovim

Use `typst-lsp` with nvim-lspconfig:

```lua
require('lspconfig').typst_lsp.setup{}
```

## Performance Tips

1. **Use watch mode** for development
2. **Split large documents** into chapters
3. **Precompile templates** if rarely changed
4. **Minimize package imports** to essentials

## Troubleshooting

### Slow Compilation

- Check for complex diagrams
- Reduce image resolution
- Split into smaller files

### Missing Fonts

```bash
# List available fonts
typst fonts

# Add font directory
typst compile --font-path ~/.fonts document.typ
```

### Cache Issues

```bash
# Clear Typst cache
rm -rf ~/.cache/typst
```
