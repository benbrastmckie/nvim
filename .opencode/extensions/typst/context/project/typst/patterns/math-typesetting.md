# Math Typesetting in Typst

**Created**: 2026-02-27
**Purpose**: Mathematical notation and formatting in Typst

---

## Basic Math Mode

### Inline Math

```typst
The equation $x^2 + y^2 = r^2$ describes a circle.
```

### Display Math

```typst
$
  integral_0^infinity e^(-x^2) dif x = sqrt(pi) / 2
$
```

## Common Constructs

### Fractions

```typst
$frac(a, b)$           // Standard fraction
$a / b$                // Inline fraction
$a \/ b$               // Literal slash
```

### Subscripts and Superscripts

```typst
$x^2$                  // Superscript
$x_i$                  // Subscript
$x_i^2$                // Both
$sum_(i=1)^n$          // Sum with limits
```

### Greek Letters

```typst
$alpha, beta, gamma, delta, epsilon$
$Alpha, Beta, Gamma, Delta$
$phi, psi, omega, theta, lambda$
```

### Operators

```typst
$sin, cos, tan, log, ln, exp$
$lim, inf, sup, max, min$
$integral, sum, product$
```

### Sets and Logic

```typst
$in, subset, supset, union, sect$
$forall, exists, not, and, or$
$implies, iff$
```

## Custom Notation

### Number Sets

```typst
#let R = math.bb("R")
#let N = math.bb("N")
#let Z = math.bb("Z")
#let Q = math.bb("Q")
#let C = math.bb("C")

The real numbers $R$ contain $Q$.
```

### Custom Operators

```typst
#let argmax = math.op("argmax")
#let argmin = math.op("argmin")

$argmax_(x in X) f(x)$
```

### Semantic Brackets

```typst
#let sem(body) = $bracket.l.double #body bracket.r.double$

The semantics $sem(phi)$ denotes...
```

## Modal Logic Notation

```typst
// Modal operators
#let Box = sym.ballot
#let Diamond = sym.lozenge

$Box p -> p$           // Necessity implies truth
$Diamond p$            // Possibility
```

## Equation Numbering

### Numbered Equations

```typst
#set math.equation(numbering: "(1)")

$
  E = m c^2
$ <eq:einstein>

See @eq:einstein for the mass-energy relation.
```

### Selective Numbering

```typst
// Only number some equations
#let numbered = eq => math.equation(
  block: true,
  numbering: "(1)",
  eq,
)

#numbered($a = b$) <eq:numbered>
```

## Alignment

### Aligned Equations

```typst
$
  x &= a + b \
    &= c + d \
    &= e
$
```

### Cases

```typst
$
  f(x) = cases(
    x^2 &"if" x >= 0,
    -x^2 &"if" x < 0,
  )
$
```

## Best Practices

1. **Define notation modules**: Keep notation in separate files
2. **Use consistent operators**: Define once, use everywhere
3. **Prefer semantic names**: `#let implies` over `=>` symbols
4. **Document conventions**: Comment non-standard notation
5. **Test rendering**: Check complex formulas in output
