# Custom Macro Conventions

## Purpose

This document defines patterns for creating and using custom LaTeX macros. Custom macros ensure consistent typography across documents and simplify maintenance.

## Macro Categories

### 1. Product/System Names

Define macros for product or system names that require consistent styling:

| Macro | Output | Definition |
|-------|--------|------------|
| `\productname` | *ProductName* | `\emph{ProductName}` |
| `\toolone` | Tool-One | `Tool-One` (with proper hyphenation) |
| `\tooltwo` | Tool-Two | `Tool-Two` (with proper hyphenation) |

**Usage Pattern**:
```latex
% Define in your .sty file:
\newcommand{\productname}{\emph{ProductName}}
\newcommand{\toolone}{Tool-One}
\newcommand{\tooltwo}{Tool-Two}
```

**When to Use**:
- Introducing the system: "The \productname{} addresses these limitations..."
- Describing capabilities: "The \productname{} provides two mechanisms..."

**When NOT to Use**:
- In italicized contexts where double-emphasis would occur
- In section titles (use plain text)
- When referring to the general concept rather than the system

### 2. Technical Term Macros

Define macros for frequently used technical terms:

```latex
% Example definitions
\newcommand{\verifier}{Proof-Checker}
\newcommand{\refuter}{Model-Checker}
```

**Usage**:
```latex
% CORRECT: Using tool macros
The \verifier{} certifies derivations.
The \refuter{} constructs counterexamples.

% INCORRECT: Plain text with inconsistent formatting
The Proof-Checker certifies derivations.
The model checker constructs counterexamples.
```

### 3. Mathematical Notation Macros

See `notation-conventions.md` for mathematical notation macros.

## Macro Design Principles

### 1. Semantic Naming

Name macros by their semantic meaning, not their appearance:

```latex
% Good: Semantic names
\newcommand{\necessity}{\Box}
\newcommand{\possibility}{\Diamond}

% Bad: Appearance-based names
\newcommand{\squarebox}{\Box}
\newcommand{\diamondshape}{\Diamond}
```

### 2. Empty Braces for Spacing

When a macro might appear before punctuation or text, design for consistent spacing:

```latex
% Usage with empty braces for spacing control
The \productname{} is implemented in...

% The {} ensures proper spacing before "is"
```

### 3. Parameterized Macros

For macros with arguments, use descriptive parameter positions:

```latex
% Single parameter
\newcommand{\srcref}[1]{\texttt{#1}}

% Multiple parameters
\newcommand{\srcmodule}[2]{\texttt{#1.#2}}
```

## Implementation Pattern

### Style File Organization

Create a dedicated `.sty` file for project macros:

```latex
% notation.sty
\NeedsTeXFormat{LaTeX2e}
\ProvidesPackage{notation}[2024/01/01 Project Notation]

% ============================================================
% Product Names
% ============================================================
\newcommand{\productname}{\emph{ProductName}}

% ============================================================
% Tool Names
% ============================================================
\newcommand{\verifier}{Proof-Checker}
\newcommand{\refuter}{Model-Checker}

% ============================================================
% Mathematical Notation
% ============================================================
\newcommand{\set}[1]{\{#1\}}
\newcommand{\tuple}[1]{\langle #1 \rangle}
\newcommand{\sem}[1]{\llbracket #1 \rrbracket}

% ============================================================
% Cross-References
% ============================================================
\newcommand{\srcref}[2]{\texttt{#1.#2}}
\newcommand{\fileref}[1]{\texttt{#1}}
```

### Loading the Package

In your main document:

```latex
\usepackage{assets/notation}
```

## Best Practices

### Do

1. **Define all product names as macros**: Ensures consistent styling
2. **Document macro definitions**: Include usage examples in comments
3. **Group related macros**: Organize by category in the `.sty` file
4. **Test macro output**: Verify rendering in both PDF and standalone contexts

### Don't

1. **Don't use inline formatting for recurring terms**: Use macros instead
2. **Don't mix macro and plain text for the same concept**: Be consistent
3. **Don't create macros for one-time uses**: Only for recurring patterns
4. **Don't nest emphasis macros**: Avoid `\emph{\productname{}}` scenarios

## Migration Notes

When establishing macros in an existing document:

1. **Search and replace systematically**: Find all instances of the plain text
2. **Test compilation**: Ensure no regressions
3. **Update documentation**: Add macros to style guide
4. **Add NOTE markers**: For macros not yet defined in `.sty` file

Example NOTE marker:
```latex
% NOTE: \productname macro not yet in notation.sty - add during next update
The \productname{} provides...
```
