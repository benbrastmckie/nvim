# Typst Bibliography

**Created**: 2026-02-27
**Purpose**: Bibliography and citation patterns in Typst

---

## Basic Setup

Typst has built-in bibliography support (no separate bibtex/biber):

```typst
// At the end of your document
#bibliography("references.bib")
```

## Citation Syntax

### Inline Citations

```typst
// Author-year style
As shown by @smith2020...

// Multiple citations
Several authors @smith2020 @jones2021 have shown...

// With page numbers
@smith2020[pp. 42-43]
```

### Footnote Citations

```typst
// Citation in footnote
See the original work#footnote[@smith2020].
```

## BibTeX Format

Typst reads standard .bib files:

```bibtex
@article{smith2020,
  author = {Smith, John},
  title = {An Important Paper},
  journal = {Journal of Things},
  year = {2020},
  volume = {10},
  pages = {1-20},
}

@book{jones2021,
  author = {Jones, Jane},
  title = {A Comprehensive Book},
  publisher = {Academic Press},
  year = {2021},
}
```

## Bibliography Styles

### Available Styles

```typst
// IEEE style (default)
#bibliography("references.bib")

// Chicago author-date
#bibliography("references.bib", style: "chicago-author-date")

// APA
#bibliography("references.bib", style: "apa")
```

### Custom Styling

```typst
// Customize bibliography heading
#show bibliography: set heading(numbering: none)

// Different title
#bibliography("references.bib", title: "References")
```

## Hayagriva Format

Typst also supports its native Hayagriva YAML format:

```yaml
# references.yml
smith2020:
  type: article
  title: An Important Paper
  author: Smith, John
  date: 2020
  parent:
    type: periodical
    title: Journal of Things
    volume: 10
  page-range: 1-20
```

```typst
#bibliography("references.yml")
```

## Tips

1. **Convert existing bibliographies**: Most .bib files work directly
2. **Check entries**: Run once to see any parsing errors
3. **Unused entries**: Typst only includes cited works
4. **Multiple bibliographies**: Use for different sections if needed

## Cross-References with Lean

For documents referencing Lean code:

```typst
// Reference theorem in Lean
See `Bimodal.Metalogic.soundness` in the Lean source.

// Link to documentation
#link("Theories/Bimodal/Metalogic.lean")[Source code]
```
