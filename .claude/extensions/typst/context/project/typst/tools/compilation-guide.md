# Typst Compilation Guide

## Basic Compilation

```bash
# Compile to PDF
typst compile document.typ

# Output to specific path
typst compile document.typ output.pdf
```

## Watch Mode

Automatically recompile on changes:

```bash
typst watch document.typ
```

## Command Options

| Option | Description |
|--------|-------------|
| `--root <path>` | Set project root |
| `--font-path <path>` | Add font directory |
| `--input <key>=<value>` | Set input variables |
| `--format <format>` | Output format (pdf, svg, png) |

## Package Management

Packages are automatically downloaded from Typst Universe on first use:

```typst
#import "@preview/thmbox:0.2.0": *
#import "@preview/fletcher:0.5.0": *
```

## Error Handling

Typst provides clear, readable error messages:

```
error: expected closing bracket
  ┌─ document.typ:42:10
  │
42 │   #theorem[
  │           ^ expected ']' before end of paragraph
```

## Performance

Typst is significantly faster than LaTeX:
- Single-pass compilation
- Incremental recompilation in watch mode
- No auxiliary file overhead

## Neovim Integration

With typst.vim or similar:
- `:TypstCompile` - Compile document
- `:TypstWatch` - Start watch mode
- Automatic compilation on save
