# Cross-References

## Typst Label System

### Creating Labels

Add labels with angle brackets after any element:

```typst
= Syntax <ch-syntax>

== Formulas <sec-formulas>

#definition("Formula") <def-formula>

#theorem("Completeness") <thm-completeness>
```

### Label Naming Conventions

| Element Type | Prefix | Example |
|--------------|--------|---------|
| Chapter | `ch-` | `<ch-syntax>` |
| Section | `sec-` | `<sec-formulas>` |
| Definition | `def-` | `<def-formula>` |
| Theorem | `thm-` | `<thm-completeness>` |
| Lemma | `lem-` | `<lem-helper>` |
| Axiom | `ax-` | `<ax-main>` |
| Figure | `fig-` | `<fig-diagram>` |
| Table | `tab-` | `<tab-operators>` |
| Equation | `eq-` | `<eq-definition>` |

---

## Referencing

### Basic Reference

```typst
See @def-formula for the definition of formulas.

The proof of @thm-completeness uses @lem-helper.
```

### Reference with Context

```typst
As shown in @ch-syntax, formulas are defined inductively.

The operators in @sec-formulas include various modalities.
```

### Equation References

```typst
$ phi.alt arrow.r psi $ <eq-implication>

By @eq-implication, implication is primitive.
```

---

## Code Cross-References

### Commands for Source References

```typst
// Full module path reference
#let srcref(module, name) = raw(module + "." + name)

// Simple name reference
#let coderef(name) = raw(name)
```

### Usage Patterns

#### Referencing a Definition

```typst
The formula type is implemented as #srcref("Core.Syntax", "Formula").
```

Output: `Core.Syntax.Formula`

#### Referencing a Function

```typst
This result corresponds to #coderef("completeness_theorem") in the formalization.
```

Output: `completeness_theorem`

#### Inline Code

```typst
The constructor `atom s` creates atomic formulas.
```

Use backticks for inline identifiers that don't need full path references.

---

## Table of Contents

### Basic Outline

```typst
#outline(title: "Contents", indent: auto)
```

### Styled TOC

```typst
// Bold chapter entries, normal sections
#show outline.entry.where(level: 1): it => {
  v(0.5em)
  strong(it)
}
#outline(title: "Contents", indent: auto)
```

---

## Figure References

### Creating Labeled Figures

```typst
#figure(
  table(
    columns: 4,
    // table content...
  ),
  caption: [Primitive operators],
) <tab-primitives>
```

### Referencing Figures

```typst
@tab-primitives shows the primitive operators.
```

---

## Cross-Chapter References

### Pattern

Labels are global across all included files:

```typst
// In 01-syntax.typ
#definition("Formula") <def-formula>

// In 02-semantics.typ
The formulas from @def-formula are interpreted as follows...
```

### Best Practices

1. **Use unique labels**: Prefix with chapter context if needed
2. **Keep labels stable**: Don't rename labels once published
3. **Document key labels**: Note important cross-reference targets

---

## External Links

### Basic Links

```typst
#link("https://example.com")[Link Text]
```

### Styled Links

Style links with a consistent color:

```typst
#let URLblue = rgb(0, 0, 150)
#show link: set text(fill: URLblue)

// Then links automatically use URLblue
See #link("https://github.com/...")[the repository].
```

### Project-Specific Links

```typst
// Define reusable link
#let projectrepo = link("https://github.com/user/repo")[`Repository`]

// Usage
This is documented in the #projectrepo project.
```

---

## Best Practices

1. **Label early**: Add labels when creating content, not later
2. **Use consistent prefixes**: Follow the naming conventions table
3. **Keep code refs current**: Update source references when code changes
4. **Test cross-references**: Compile to verify all references resolve
5. **Avoid orphaned labels**: Remove labels for deleted content
