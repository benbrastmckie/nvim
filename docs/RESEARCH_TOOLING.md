# Research Tooling

## Purpose

This document describes the research and academic writing tools integrated into the NeoVim configuration, including LaTeX editing with VimTeX, Markdown workflows, Jupyter notebook support, citation management, and document conversion utilities.

## LaTeX Support

### VimTeX Integration

VimTeX provides comprehensive LaTeX editing support through integration with external tools.

**Core Features**:
- Real-time compilation with latexmk
- PDF viewing with Zathura (forward and inverse search)
- Syntax highlighting and concealment
- Completion for commands, environments, and citations
- Error navigation and quickfix integration

**Key Commands**:

| Command | Description |
|---------|-------------|
| `\ll` | Start/stop continuous compilation |
| `\lv` | Open PDF viewer (Zathura) |
| `\lc` | Clean auxiliary files |
| `\le` | Show compilation errors |
| `\lt` | Show table of contents |
| `\lk` | Stop compilation |

**Configuration**: `lua/neotex/plugins/text/vimtex.lua`

### LaTeX Compilation

```
Source File (.tex)
       │
       ▼
┌─────────────────────┐
│ latexmk             │
│ • Manages build     │
│ • Runs XeLaTeX      │
│ • Handles bibtex    │
│ • Build isolation   │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ PDF Output          │
│ • sioyek displays   │
│ • synctex enabled   │
└─────────────────────┘
```

### LaTeX Compilation Optimization

The configuration includes global optimizations for faster and more reliable LaTeX compilation.

**Global Configuration** (`~/.config/latexmk/latexmkrc`):
- **Engine**: XeLaTeX for Unicode and modern font support
- **Build Isolation**: Artifacts stored in `build/` directory
- **Auxiliary File Handling**: `$emulate_aux = 1` for faster processing
- **Loop Prevention**: Maximum 5 recompilation attempts
- **Error Reporting**: `-file-line-error` for better debugging

**VimTeX Compiler Settings**:
- **Method**: Explicitly set to `latexmk`
- **Engine**: XeLaTeX with `-xelatex` flag
- **Error Visibility**: Quickfix mode re-enabled (mode 2)
- **Error Filtering**: Common noise filtered from quickfix

**Project-Specific Overrides**:
Create a `.latexmkrc` in your project directory to override global settings:
```perl
$pdf_mode = 1;    # Use pdflatex instead of xelatex
$out_dir = '.';   # Build in source directory
```

**Draft vs Final Mode**:
- **Draft Mode** (`<leader>ld`): Fast iteration with `$draft_mode=1`
- **Final Mode** (`<leader>lf`): Optimized build for distribution
- **Continuous** (`<leader>lc`): VimTeX auto-recompilation on save

Note: XeLaTeX draft mode provides infrastructure for fast compilation but may not show significant speed improvements compared to final mode. The primary benefit is the separation of draft and final workflows.

**Alternative Compilation Backends**:

*Tectonic* (optional, for compatible documents):
- Modern Rust-based LaTeX engine with automatic package management
- Faster compilation for simpler documents (5-20% improvement)
- Self-contained with reproducible builds
- Limitations: Not all LaTeX packages supported (e.g., some Springer templates, algorithm packages)
- Installation: `nix profile install nixpkgs#tectonic`
- Usage: `tectonic --synctex document.tex`
- Best for: Modern LaTeX workflows, simple documents, reproducible builds
- Not recommended for: Complex academic templates, legacy packages

**Performance Benefits**:
- Build artifacts isolated from source files
- Cleaner project directory structure
- Better error messages in quickfix window
- Consistent compilation behavior across projects
- Draft/final mode separation for workflow clarity

### Forward and Inverse Search

**Forward Search** (Navigate from source to PDF):
- Place cursor in LaTeX source
- Press `\lv` to open PDF at corresponding location
- Zathura scrolls to matching position

**Inverse Search** (Navigate from PDF to source):
- Ctrl+Click in Zathura PDF viewer
- NeoVim jumps to corresponding LaTeX source line
- Works through SyncTeX protocol

### LaTeX Text Objects

VimTeX provides custom text objects for LaTeX structures:

| Object | Description | Example Usage |
|--------|-------------|---------------|
| `ie` / `ae` | Inside/around environment | `cie` changes environment content |
| `i$` / `a$` | Inside/around math | `ci$` changes inline math |
| `id` / `ad` | Inside/around delimiters | `did` deletes delimiter contents |
| `ic` / `ac` | Inside/around command | `cac` changes command and arguments |

### LaTeX Surrounds

Custom surrounds for LaTeX (via nvim-surround, defined in
`lua/neotex/plugins/tools/surround.lua`):

| Key | Result | Description |
|-----|--------|-------------|
| `e` | `\begin{env}...\end{env}` | Environment (prompts for name) |
| `b` | `\textbf{text}` | Bold text |
| `i` | `\textit{text}` | Italic text |
| `c` (or `t`) | `\texttt{text}` | Typewriter (monospace) |
| `l` | `\href{url}{text}` | Link (prompts for URL) |
| `M` | `\[text\]` | Display math |
| `q` | `` `text' `` | LaTeX single quotes |
| `Q` | `` ``text'' `` | LaTeX double quotes |
| `m` (or `$`) | `$text$` | Inline math |

**Usage**: `ysiw + e` prompts for environment name, then surrounds word

### LaTeX Templates

Document templates available in `templates/` directory:

- **Article templates**: Standard academic papers
- **Beamer presentations**: Slide decks with themes
- **Report templates**: Multi-chapter documents
- **Springer templates**: Publisher-specific formats
- **Custom letter templates**: Professional correspondence

Access templates with dashboard (`e` key) or `:edit ~/config/nvim/templates/[template].tex`

## Markdown Support

### Markdown Editing Features

**Smart List Handling**:
- Auto-continue lists on `<CR>` in insert mode
- Increment numbered lists automatically
- Handle nested lists with proper indentation
- Toggle checkboxes with `<leader>mc`

**Markdown-Specific Surrounds**:

| Key | Result | Description |
|-----|--------|-------------|
| `b` | `**text**` | Bold (strong emphasis) |
| `i` | `*text*` | Italic (emphasis) |
| `` ` `` | `` `text` `` | Inline code |
| `c` | `` ```lang\ntext\n``` `` | Fenced code block (prompts for language) |
| `l` | `[text](url)` | Link (prompts for URL) |
| `~` | `~~text~~` | Strikethrough (GFM) |

### Markdown Preview

Real-time Markdown rendering in browser:

**Commands**:
- `:MarkdownPreview` - Start preview server
- `:MarkdownPreviewStop` - Stop preview server
- `:MarkdownPreviewToggle` - Toggle preview

**Features**:
- Live reload on buffer save
- Syntax highlighting in code blocks
- GitHub Flavored Markdown support
- Table rendering
- Task list checkboxes

**Configuration**: Preview opens in default browser at `localhost:port`

### Markdown Workflows

**Note-Taking**:
1. Create markdown file for topic
2. Use Lectic integration for AI-assisted writing (`<leader>ml`)
3. Process selections with `<leader>ms`
4. Export to PDF with Pandoc when complete

**Documentation**:
1. Write content in Markdown
2. Use fenced code blocks for examples
3. Preview with `:MarkdownPreview`
4. Convert to target format with Pandoc

## Jupyter Notebook Support

### Jupytext Integration

Convert between notebook formats transparently:

**Supported Formats**:
- `.ipynb` ↔ `.py` (Python percent format)
- `.ipynb` ↔ `.md` (Markdown with code cells)
- `.ipynb` ↔ `.jl` (Julia)
- `.ipynb` ↔ `.R` (R markdown)

**Workflow**:
1. Open `.ipynb` file in NeoVim
2. Edit as text (Python with `# %%` cell markers or Markdown)
3. Save changes
4. Jupytext syncs changes to `.ipynb` format

### Notebook Navigator

Cell-based navigation and execution:

**Cell Navigation**:

| Key | Action |
|-----|--------|
| `<leader>jj` | Navigate to next cell |
| `<leader>jk` | Navigate to previous cell |
| `<leader>jo` | Insert cell below |
| `<leader>jO` | Insert cell above |

**Cell Execution**:

| Key | Action |
|-----|--------|
| `<leader>je` | Execute current cell |
| `<leader>jn` | Execute cell and move to next |
| `<leader>ja` | Run all cells in file |
| `<leader>jb` | Run current and all cells below |

**Cell Management**:

| Key | Action |
|-----|--------|
| `<leader>js` | Split cell at cursor position |
| `<leader>ju` | Merge with cell above |
| `<leader>jd` | Merge with cell below |
| `<leader>jc` | Comment current cell |

### Iron.nvim REPL Integration

Interactive REPL for cell execution:

**REPL Commands**:

| Key | Action |
|-----|--------|
| `<leader>ji` | Start IPython REPL |
| `<leader>jt` | Send motion to REPL |
| `<leader>jl` | Send current line to REPL |
| `<leader>jf` | Send entire file to REPL |
| `<leader>jv` | Send visual selection to REPL |
| `<leader>jq` | Exit REPL |
| `<leader>jr` | Clear REPL screen |

**Cell Markers**:
- **Python**: Cells delimited by `# %%` or `#%%` comments
- **Markdown**: Cells delimited by code blocks (triple backticks)

### Notebook Workflow Example

```python
# %% [markdown]
# # Data Analysis Notebook
#
# This notebook analyzes the dataset.

# %% Setup
import pandas as pd
import numpy as np

data = pd.read_csv('data.csv')

# %% Analysis
result = data.describe()
print(result)

# %% Visualization
import matplotlib.pyplot as plt

data.plot(kind='scatter', x='x', y='y')
plt.show()
```

**Execution Flow**:
1. Navigate between cells with `<leader>jj`/`<leader>jk`
2. Execute cells with `<leader>je`
3. Run all with `<leader>ja`
4. View output in REPL window

## Citation Management

### BibTeX Integration

VimTeX provides completion for citations and bibliography entries.

**Citation Completion**:
1. Type `\cite{` in LaTeX document
2. Trigger completion (usually automatic)
3. Select from bibliography entries
4. Entry format: `Author(Year): Title`

**Bibliography File**:
- Location: Specified in LaTeX document with `\bibliography{file}`
- Format: Standard BibTeX `.bib` file
- Auto-completion reads from this file

### Zotero Integration (External)

While not directly integrated, Zotero can export to BibTeX:

1. **Export from Zotero**: File → Export Library → BibTeX format
2. **Update bibliography**: Save as `references.bib` in LaTeX project
3. **Use in LaTeX**: `\bibliography{references}`
4. **Cite**: `\cite{AuthorYear}` with completion

## Document Conversion

### Pandoc Integration

Convert between document formats using Pandoc:

**Common Conversions**:

```bash
# Markdown to PDF
pandoc document.md -o document.pdf

# Markdown to LaTeX
pandoc document.md -o document.tex

# LaTeX to DOCX
pandoc document.tex -o document.docx

# Jupyter to PDF (via LaTeX)
jupyter nbconvert notebook.ipynb --to pdf
```

**Usage from NeoVim**:
```vim
:!pandoc % -o %:r.pdf
```

### Export Workflows

**Academic Paper**:
1. Write in LaTeX with VimTeX
2. Compile to PDF with `\ll`
3. Optionally convert to DOCX for collaborators: `pandoc paper.tex -o paper.docx`

**Technical Documentation**:
1. Write in Markdown
2. Preview with `:MarkdownPreview`
3. Export to PDF: `pandoc doc.md -o doc.pdf --pdf-engine=xelatex`

**Data Analysis**:
1. Work in Jupyter notebook (`.py` with Jupytext)
2. Execute cells interactively
3. Convert to PDF report: `jupyter nbconvert analysis.ipynb --to pdf`

## PDF Annotation Extraction (External)

While not directly integrated, PDF annotations can be extracted:

**Tools**:
- `pdfannots`: Extract annotations from PDF to Markdown
- `pdf2txt`: Extract text content for analysis

**Workflow**:
1. Annotate PDF with external reader (Zathura, Okular)
2. Extract annotations: `pdfannots paper.pdf > notes.md`
3. Import notes into research document

## Research Workflow Examples

### Literature Review

1. **Collect PDFs**: Store in organized directory structure
2. **Annotate**: Use PDF reader for highlighting and comments
3. **Extract notes**: Use `pdfannots` or manual note-taking in Markdown
4. **Synthesize**: Write review in Markdown or LaTeX
5. **Cite**: Use BibTeX for references

### Writing Academic Papers

1. **Start from template**: Use LaTeX template from `templates/`
2. **Structure document**: Sections, subsections with `\section{}`
3. **Write content**: Use VimTeX text objects for editing
4. **Add citations**: `\cite{}` with completion from `.bib` file
5. **Compile**: Continuous compilation with `\ll`
6. **Review**: PDF viewing with forward/inverse search
7. **Finalize**: Clean auxiliary files with `\lc`

### Data Analysis Projects

1. **Create notebook**: Use `.py` file with `# %%` cell markers
2. **Setup environment**: Start REPL with `<leader>ji`
3. **Develop analysis**: Execute cells iteratively with `<leader>je`
4. **Document findings**: Add markdown cells with explanations
5. **Generate figures**: Create visualizations in code cells
6. **Export report**: Convert to PDF with `jupyter nbconvert`

## Tool Configuration

### VimTeX Settings

**Key Settings** (in `vimtex.lua`):
- Compiler: `latexmk` with PDF output
- Viewer: `zathura` with SyncTeX
- Concealment: Enabled for cleaner display
- Fold: Disabled for performance

### Markdown Settings

**Key Settings**:
- Auto-formatting: Disabled (preserves manual formatting)
- List continuation: Enabled
- Checkbox toggling: Enabled
- Preview: Uses default browser

### Jupyter Settings

**Key Settings**:
- Format: Python percent format (`.py` with `# %%`)
- REPL: IPython for Python notebooks
- Auto-conversion: Jupytext handles `.ipynb` ↔ `.py`

## Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [MAPPINGS.md](MAPPINGS.md) - Complete keybinding reference
- [Text Plugins README](../lua/neotex/plugins/text/README.md) - Plugin configurations
- [Templates README](../templates/README.md) - Document template catalog

## Notes

Research tooling priorities:
- **LaTeX**: Primary format for academic writing with full VimTeX integration
- **Markdown**: Quick documentation and note-taking with preview
- **Jupyter**: Data analysis with cell-based execution
- **Conversion**: Pandoc for format flexibility

These tools work together to provide a complete research and academic writing environment within NeoVim.
