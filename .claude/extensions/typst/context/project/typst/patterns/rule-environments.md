# Rule Environments

Custom Typst environments for presenting typing rules and inference rules consistently.

## Available Functions

### rule-block

Simple inline rule presentation with name and explanation.

**Signature**: `#rule-block(name, body)`

**Parameters**:
- `name`: The rule name (e.g., "Formation", "Introduction", "Elimination")
- `body`: Explanation text for the rule

**Usage**:
```typst
#rule-block("Formation")[
  Stipulates when the type is valid: we need $A$ to be a type and $B(x)$ to be a type for each $x : A$.
]
```

**Output**: Renders the name in bold, followed by a colon and the explanation text.

### rule-list

Grouped presentation of multiple typing rules with consistent spacing.

**Signature**: `#rule-list(..rules)`

**Parameters**: Variadic array of tuples, each containing:
- `name`: Rule name (string)
- `rule`: The inference rule in math notation (content)
- `explanation`: Explanation text (content)

**Usage**:
```typst
#rule-list(
  ("Formation",
   $frac(Gamma tack.r A : cal(U) quad Gamma, x : A tack.r B(x) : cal(U), Gamma tack.r Pi_(x:A) B(x) : cal(U))$,
   [Stipulates when the Pi type is valid.]),
  ("Introduction",
   $frac(Gamma, x : A tack.r b(x) : B(x), Gamma tack.r lambda x. b(x) : Pi_(x:A) B(x))$,
   [Stipulates how to build a term via lambda abstraction.]),
)
```

**Output**: Each rule is displayed with:
1. Bold name followed by colon
2. Centered inference rule
3. Explanation text in slightly smaller font

## Styling Details

- Consistent vertical spacing between rules (0.8em)
- Rule names are bold
- Inference rules are centered
- Explanations are in 0.95em font size
- Works well with theorem environments

## When to Use

Use these environments when:
- Presenting typing rules for a type former (Pi, Sigma, Identity, etc.)
- Showing inference rules with explanations
- Needing consistent indentation across related rules

Do NOT use for:
- Single isolated equations (use standard math mode)
- Definition lists (use standard Typst `/` syntax)
- Theorem statements (use thmbox environments)

## First-Item Indentation Issue

When presenting typing rules as bullet lists, the first item may have unwanted indentation due to Typst's paragraph settings.

### Problem

With `first-line-indent` set globally, the first item in a list inherits paragraph indentation:

```typst
// With global setting: #set par(first-line-indent: 1.8em)

*Formation*: ...       // <- Has unwanted 1.8em indent
*Introduction*: ...    // <- Normal (no indent)
*Elimination*: ...     // <- Normal (no indent)
```

### Cause

Typst applies `first-line-indent` to the first paragraph after a block boundary. When a bullet list follows a heading or other block element, the first list item is treated as the first paragraph.

### Standard Solution: Use rule-list

The `rule-list` function handles indentation internally and provides consistent formatting:

```typst
// USE THIS (preferred)
#rule-list(
  ("Formation", $...$, [explanation]),
  ("Introduction", $...$, [explanation]),
  ("Elimination", $...$, [explanation]),
)
```

This is the preferred approach for typing rules because:
- Consistent spacing between rules
- Centered inference rule display
- No first-item indentation issues

### Fallback: Reset par indent locally

When `rule-list` is inappropriate (e.g., mixed content types), reset indentation locally:

```typst
// USE THIS (fallback)
#block[
  #set par(first-line-indent: 0em)

  *Formation*: ...
  *Introduction*: ...
  *Elimination*: ...
]
```

### Anti-Pattern

Do NOT try to fix indentation by adding manual spacing or using inconsistent formatting:

```typst
// DO NOT USE
#h(-1.8em)*Formation*: ...    // Manual negative space - fragile
*Formation*: ...               // No fix - visually inconsistent
```
