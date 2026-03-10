# Presentation Extraction and Slide Generation Patterns

Patterns for extracting content from PowerPoint presentations and generating academic slide formats (Beamer, Polylux, Touying).

## PPTX Extraction with python-pptx

### Basic Slide Content Extraction

```python
from pptx import Presentation
from pptx.util import Inches, Pt

prs = Presentation("source.pptx")

for slide_num, slide in enumerate(prs.slides, 1):
    print(f"=== Slide {slide_num} ===")

    # Extract text from shapes
    for shape in slide.shapes:
        if shape.has_text_frame:
            for para in shape.text_frame.paragraphs:
                level = para.level  # Bullet level (0 = top level)
                text = para.text.strip()
                if text:
                    print(f"{'  ' * level}- {text}")
```

### Title and Body Extraction

```python
def extract_slide_content(slide):
    title = ""
    body = []

    for shape in slide.shapes:
        if shape.has_text_frame:
            if shape.is_placeholder:
                ph_type = shape.placeholder_format.type
                if ph_type == 1:  # Title
                    title = shape.text_frame.text.strip()
                elif ph_type in [2, 7]:  # Body, Content
                    for para in shape.text_frame.paragraphs:
                        body.append({
                            'level': para.level,
                            'text': para.text.strip()
                        })

    return {'title': title, 'body': body}
```

### Speaker Notes Extraction

```python
def extract_speaker_notes(slide):
    if slide.has_notes_slide:
        notes_slide = slide.notes_slide
        return notes_slide.notes_text_frame.text.strip()
    return ""
```

### Table Extraction

```python
def extract_table(shape):
    if shape.has_table:
        table = shape.table
        rows = []
        for row in table.rows:
            row_cells = []
            for cell in row.cells:
                row_cells.append(cell.text.strip())
            rows.append(row_cells)
        return rows
    return None
```

### Image Extraction

```python
import os
from pptx.enum.shapes import MSO_SHAPE_TYPE

def extract_images(prs, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    images = []

    for slide_num, slide in enumerate(prs.slides, 1):
        for shape_num, shape in enumerate(slide.shapes):
            if shape.shape_type == MSO_SHAPE_TYPE.PICTURE:
                image = shape.image
                ext = image.ext
                filename = f"slide{slide_num}_img{shape_num}.{ext}"
                filepath = os.path.join(output_dir, filename)

                with open(filepath, 'wb') as f:
                    f.write(image.blob)

                images.append({
                    'slide': slide_num,
                    'path': filepath,
                    'format': ext
                })

    return images
```

## Beamer Generation (LaTeX)

### Basic Beamer Structure

```latex
\documentclass{beamer}
\usetheme{metropolis}

\title{Presentation Title}
\author{Author Name}
\date{\today}

\begin{document}

\maketitle

\begin{frame}{Slide Title}
  \begin{itemize}
    \item First point
    \item Second point
  \end{itemize}
\end{frame}

\begin{frame}{Another Slide}
  Content here
  \note{Speaker notes appear here}
\end{frame}

\end{document}
```

### pandoc Markdown to Beamer

Create structured markdown for pandoc:

```markdown
---
title: Presentation Title
author: Author Name
theme: metropolis
---

# Section Title

## Slide Title

- First point
- Second point

::: notes
Speaker notes here
:::

## Another Slide

Content with **emphasis**
```

Convert with pandoc:
```bash
pandoc -t beamer -o slides.tex slides.md
```

### Common Beamer Themes

| Theme | Description |
|-------|-------------|
| `metropolis` | Modern, clean (recommended) |
| `Madrid` | Traditional academic |
| `Warsaw` | Classic with sidebar |
| `Frankfurt` | Minimal with progress |
| `Berkeley` | Sidebar navigation |

## Polylux Generation (Typst)

### Basic Polylux Structure

```typst
#import "@preview/polylux:0.3.1": *

#set page(paper: "presentation-16-9")
#set text(size: 20pt)

#polylux-slide[
  #align(center + horizon)[
    = Presentation Title
    Author Name
  ]
]

#polylux-slide[
  = Slide Title

  - First point
  - Second point
]

#polylux-slide[
  = Another Slide

  #v(1em)
  Content with *emphasis*
]
```

### Speaker Notes in Polylux

```typst
#import "@preview/polylux:0.3.1": *

// Enable speaker notes mode
#enable-handout-mode(true)

#polylux-slide[
  = Slide Title

  Content here

  #speaker-note[
    Remember to mention X and Y
  ]
]
```

## Touying Generation (Typst)

### Basic Touying Structure

```typst
#import "@preview/touying:0.4.0": *

#let s = themes.simple.register()
#let (init, slides) = utils.methods(s)
#show: init

#let (slide, empty-slide) = utils.slides(s)
#show: slides

= Section Title

== Slide Title

- First point
- Second point

== Another Slide

Content with *emphasis*
```

### Touying with Theme

```typst
#import "@preview/touying:0.4.0": *

#let s = themes.dewdrop.register(
  aspect-ratio: "16-9",
  footer: [Author Name],
)
#let (init, slides) = utils.methods(s)
#show: init

#let (slide, empty-slide) = utils.slides(s)
#show: slides

= Welcome

== Introduction

This is a Touying presentation
```

### Touying Themes

| Theme | Description |
|-------|-------------|
| `simple` | Minimal, clean |
| `dewdrop` | Colorful, modern |
| `university` | Academic style |
| `stargazer` | Dark theme |
| `aqua` | Blue gradient |

## markitdown Fallback

For basic extraction when python-pptx is unavailable:

```bash
markitdown presentation.pptx > presentation.md
```

markitdown extracts:
- Slide text content
- Basic structure
- Some tables

markitdown does NOT extract:
- Speaker notes
- Images
- Formatting details
- Animations/overlays

## Conversion Pipeline

### Full Pipeline: PPTX to Beamer

```python
# Step 1: Extract with python-pptx
content = extract_all_slides(prs)

# Step 2: Generate structured markdown
markdown = generate_markdown(content)

# Step 3: Convert to Beamer with pandoc
subprocess.run(['pandoc', '-t', 'beamer', '-o', 'slides.tex', 'slides.md'])
```

### Full Pipeline: PPTX to Typst

```python
# Step 1: Extract with python-pptx
content = extract_all_slides(prs)
images = extract_images(prs, 'images/')

# Step 2: Generate Typst directly
typst_code = generate_polylux_slides(content, images)

# Step 3: Write output
with open('slides.typ', 'w') as f:
    f.write(typst_code)
```

## Image Handling

### Relative Paths in Output

When generating slides with images:

**Beamer**:
```latex
\begin{frame}
  \includegraphics[width=\textwidth]{images/slide1_img0.png}
\end{frame}
```

**Typst**:
```typst
#polylux-slide[
  #image("images/slide1_img0.png", width: 100%)
]
```

### Image Directory Structure

```
output/
  slides.tex (or slides.typ)
  images/
    slide1_img0.png
    slide2_img0.jpg
    slide3_img0.png
```
