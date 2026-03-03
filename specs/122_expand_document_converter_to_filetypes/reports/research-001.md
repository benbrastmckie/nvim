# Research Report: Task #122

**Task**: 122 - Expand Document Converter to Filetypes Extension
**Date**: 2026-03-03
**Focus**: Best practices for filetype conversion in academic workflows (Excel, PowerPoint, spreadsheets) with LaTeX/Typst integration for presentation slide decks

## Summary

The existing document-converter extension provides a solid foundation for file conversion via markitdown and pandoc. Expanding it into a "filetypes" extension requires adding specialized conversion pipelines for Excel/spreadsheet-to-LaTeX/Typst tables, PowerPoint extraction and Beamer/Polylux slide generation, and bidirectional flows between office formats and typesetting systems. The tooling ecosystem in 2025-2026 is mature, with markitdown (now with MCP server), pandas, openpyxl, python-pptx, and native Typst CSV/XLSX import packages providing strong programmatic support.

## Findings

### 1. Current Extension Architecture

The document-converter extension at `.claude/extensions/document-converter/` provides:

- **Manifest**: Declares agent, skill, command, and merge targets
- **Agent**: `document-converter-agent.md` - handles conversion execution with tool detection and fallback chains
- **Skill**: `skill-document-converter/SKILL.md` - thin routing wrapper with trigger conditions
- **Command**: `convert.md` - user-facing `/convert` with checkpoint-based execution
- **Supported formats**: PDF, DOCX, XLSX, PPTX, HTML, Images to Markdown; Markdown to PDF

The current architecture uses a **tool fallback chain**: markitdown (primary) -> pandoc (fallback) -> typst (PDF fallback). This pattern should be preserved and extended for new filetypes.

### 2. Excel/Spreadsheet Conversion Ecosystem

#### 2.1 Extraction Tools (Office -> Intermediate)

| Tool | Input Formats | Output | Strengths | Weaknesses |
|------|---------------|--------|-----------|------------|
| markitdown | XLSX, XLS | Markdown tables | Simple, LLM-optimized | Loses formatting, no merged cells |
| openpyxl | XLSX | Python objects | Full Excel feature access, preserves styles | Requires Python scripting |
| xlsx2csv | XLSX | CSV | Fast, streaming, handles large files | Loses formatting entirely |
| ssconvert (gnumeric) | XLSX, ODS, CSV | Multiple formats | Broad format support, CLI | Requires gnumeric installed |
| pandas (read_excel) | XLSX, XLS, ODS | DataFrame | Powerful data manipulation | Heavy dependency |

#### 2.2 Generation Tools (Intermediate -> LaTeX/Typst)

| Tool | Input | Output | Strengths | Weaknesses |
|------|-------|--------|-----------|------------|
| pandas.DataFrame.to_latex() | DataFrame | LaTeX tabular | Built-in booktabs, column formatting | Requires pandas |
| csv2latex | CSV | LaTeX tabular | Standalone CLI, longtable support | Basic formatting only |
| excel2latexviapython | XLSX | LaTeX | Preserves Excel formatting | Small project, limited maintenance |
| Typst native csv() | CSV | Typst table | Built-in, no extra tools | CSV only, no XLSX direct |
| rexllent (Typst package) | XLSX | Typst table | Direct XLSX import in Typst | No merged cells, limited styles |
| spreet (Typst package) | XLSX, ODS | Typst dictionary | Spreadsheet decoder for Typst | Raw data only, no formatting |
| tabut (Typst package) | CSV/records | Typst table | Advanced table processing | Requires data format conversion |

#### 2.3 Recommended Pipeline: Excel to LaTeX

```
XLSX -> openpyxl/pandas -> DataFrame -> pandas.to_latex(booktabs=True) -> .tex
                                     \-> CSV -> csv2latex -> .tex (alternative)
```

**Why pandas**: The `DataFrame.to_latex()` method supports booktabs formatting (`\toprule`, `\midrule`, `\bottomrule`), column alignment, multicolumn headers, float formatting, and longtable environments. This is the standard for academic publication-quality tables.

#### 2.4 Recommended Pipeline: Excel to Typst

```
XLSX -> xlsx2csv/pandas -> CSV -> Typst csv() function -> Typst table
XLSX -> rexllent package -> Direct Typst table (simpler, limited)
```

**Why CSV intermediate**: Typst has native CSV reading via `csv("data.csv")`, and the tabut package provides advanced record-based table generation from CSV data. The CSV intermediate format also serves as a universal bridge between any spreadsheet tool and Typst.

### 3. PowerPoint/Presentation Conversion Ecosystem

#### 3.1 Extraction Tools (PPTX -> Intermediate)

| Tool | Capabilities | Strengths | Weaknesses |
|------|-------------|-----------|------------|
| markitdown | Slide text extraction, optional LLM image descriptions | Simple, integrated | Loses layout, no speaker notes by default |
| python-pptx | Full PPTX API: text, images, tables, shapes, notes | Complete programmatic access | Requires Python scripting |
| pptx-to-md | PPTX -> YAML -> Pandoc Markdown | Beamer-friendly output | Two-step process |
| pptx-to-beamer | PPTX -> Markdown -> Beamer via pandoc | Direct Beamer generation | Limited formatting preservation |

#### 3.2 Generation Tools (Intermediate -> Slides)

| Tool | Input | Output | Strengths | Weaknesses |
|------|-------|--------|-----------|------------|
| pandoc | Markdown | Beamer LaTeX | Well-established, math support | Cannot read FROM PPTX directly |
| pandoc | Markdown | PPTX (PowerPoint) | Direct generation | Less control than native |
| Typst + Polylux | Typst markup | PDF slides | Modern, fast compilation | Newer ecosystem |
| Typst + Touying | Typst markup | PDF slides | Rich themes, concise syntax | Newer ecosystem |

#### 3.3 Recommended Pipeline: PowerPoint to LaTeX Beamer

```
PPTX -> python-pptx (extract text, images, notes)
     -> Structured Markdown (with slide separators)
     -> pandoc -t beamer -> .tex Beamer slides
```

**Key consideration**: Pandoc cannot read PPTX files directly. The extraction step must use python-pptx or markitdown to produce Markdown first, then pandoc converts Markdown to Beamer.

#### 3.4 Recommended Pipeline: PowerPoint to Typst Slides

```
PPTX -> python-pptx/markitdown (extract text, images)
     -> Structured Markdown
     -> Agent-assisted Typst generation (Polylux or Touying format)
```

**Why agent-assisted**: Unlike LaTeX Beamer where pandoc can do automatic conversion, Typst slide packages (Polylux, Touying) require format-specific markup that pandoc does not yet generate. An LLM agent can intelligently transform extracted slide content into Polylux/Touying format with proper theme application.

### 4. Typst Presentation Ecosystem (2025-2026)

Two main packages dominate the Typst presentation space:

#### 4.1 Polylux

- Beamer equivalent for Typst
- Metropolis theme available (popular in academia)
- Quarto integration via "projector" extension
- Active development, used in 2026 production presentations
- Syntax: `#polylux-slide[...]`

#### 4.2 Touying

- More advanced than Polylux in some respects
- Concise syntax with "global variables" via automatic injection
- Multiple built-in themes (university, metropolis, aqua, etc.)
- Better sub-slide (overlay) support than Polylux
- Syntax: `= Section Title` with `#slide[...]`

**Recommendation**: Support both packages. Touying is the more feature-rich option and is closer to Beamer's capabilities. Polylux is simpler and has broader ecosystem integration. The agent should detect which package the user's project uses and generate appropriate markup.

### 5. Bidirectional Conversion Architecture

The expanded "filetypes" extension should support flows in both directions:

#### 5.1 Inbound (Office -> Academic)

```
XLSX/CSV/ODS -> LaTeX tables (.tex)
XLSX/CSV/ODS -> Typst tables (.typ)
PPTX -> LaTeX Beamer slides (.tex)
PPTX -> Typst Polylux/Touying slides (.typ)
DOCX -> LaTeX document (.tex)     [existing via pandoc]
DOCX -> Typst document (.typ)     [existing via pandoc]
PDF -> Markdown (.md)             [existing via markitdown]
```

#### 5.2 Outbound (Academic -> Office)

```
LaTeX tables (.tex) -> XLSX (via pandas)
Typst tables (.typ) -> CSV -> XLSX
Markdown tables -> XLSX (via md-converter MCP or pandas)
LaTeX Beamer (.tex) -> PPTX (via beamer2pptx or pandoc)
Typst slides (.typ) -> PDF -> PPTX (via pdf2pptx, lossy)
Markdown -> DOCX/PPTX (via pandoc)  [existing]
```

#### 5.3 Conversion Quality Matrix

| Conversion | Fidelity | Automation | Notes |
|------------|----------|------------|-------|
| XLSX -> LaTeX table | High | Full | pandas + booktabs produces publication quality |
| XLSX -> Typst table | Medium-High | Full | Via CSV intermediate or rexllent |
| PPTX -> Beamer | Medium | Semi | Layout lost, content preserved |
| PPTX -> Polylux/Touying | Medium | Agent-assisted | Requires LLM interpretation |
| Beamer -> PPTX | Low-Medium | Semi | Via beamer2pptx or pandoc |
| CSV -> LaTeX/Typst | High | Full | Clean data, clean output |

### 6. MCP Server Integration

Several MCP servers are now available for document conversion:

| MCP Server | Capabilities | Integration |
|------------|-------------|-------------|
| markitdown-mcp | Office -> Markdown (all formats) | Claude Desktop, April 2025 |
| mcp-pandoc | Universal format conversion | Pandoc wrapper |
| md-converter | Markdown -> DOCX, XLSX, PPTX | Reverse direction |
| mcp-md-pdf | Markdown -> Word, PDF with templates | Professional formatting |

**Recommendation**: The filetypes extension should leverage these MCP servers where available, but maintain CLI fallback for environments without MCP. The existing tool detection pattern in document-converter-agent.md is the correct approach.

### 7. Tool Dependencies and Installation

#### 7.1 Core Dependencies (Always Required)

```bash
pip install markitdown          # Office -> Markdown (base)
```

#### 7.2 Spreadsheet Dependencies

```bash
pip install openpyxl            # XLSX read/write
pip install pandas              # DataFrame operations + to_latex()
pip install xlsx2csv            # Fast XLSX -> CSV
apt install csv2latex           # CSV -> LaTeX (alternative)
```

#### 7.3 Presentation Dependencies

```bash
pip install python-pptx         # PPTX read/write/creation
pip install markitdown[pptx]    # PPTX -> Markdown
```

#### 7.4 LaTeX/Typst Dependencies

```bash
apt install pandoc              # Universal converter
apt install texlive-base        # LaTeX compilation (for Beamer)
# Typst is assumed installed via typst extension
```

#### 7.5 Optional/Advanced

```bash
pip install markitdown[all]     # All markitdown format support
pip install beamer2pptx         # Beamer -> PowerPoint (reverse)
apt install gnumeric            # ssconvert for format bridging
```

### 8. Extension Renaming Strategy

Renaming from `document-converter` to `filetypes`:

#### 8.1 What Changes

| Component | Old | New |
|-----------|-----|-----|
| Extension directory | `extensions/document-converter/` | `extensions/filetypes/` |
| Agent | `document-converter-agent.md` | `filetypes-agent.md` (or keep + add specialized agents) |
| Skill | `skill-document-converter/` | `skill-filetypes/` |
| Command | `/convert` | `/convert` (keep, add `/table`, `/slides` sub-commands) |
| EXTENSION.md section | `extension_document_converter` | `extension_filetypes` |

#### 8.2 Agent Architecture Options

**Option A: Single Expanded Agent** (simpler)
- One `filetypes-agent.md` handles all conversions
- Tool selection logic becomes more complex
- Easier to maintain single agent definition

**Option B: Specialized Sub-Agents** (recommended)
- `filetypes-router-agent.md` - routes to specialized agent
- `spreadsheet-agent.md` - Excel/CSV/ODS operations
- `presentation-agent.md` - PowerPoint/Beamer/Polylux operations
- `document-agent.md` - PDF/DOCX/Markdown operations (current functionality)

**Recommendation**: Option B aligns with the project's existing hierarchical agent architecture and provides cleaner separation of concerns. Each sub-agent can have focused tool dependencies and context.

### 9. Academic Workflow Integration Points

#### 9.1 Citation/Bibliography Integration

- Zotero with Better BibTeX exports `.bib` files automatically
- Tables from Excel data papers often need citation columns
- The filetypes extension should preserve citation markers during conversion

#### 9.2 Figure/Image Pipeline

- PPTX often contains figures that need extraction for LaTeX/Typst inclusion
- python-pptx can extract embedded images with original resolution
- Images should be saved alongside converted content with cross-references

#### 9.3 Data Table Workflow

Typical academic data workflow:
```
Raw data (CSV/XLSX) -> Analysis (Python/R) -> Results (DataFrame)
                                            -> LaTeX table (paper)
                                            -> Typst table (textbook)
                                            -> XLSX (supplementary materials)
```

The filetypes extension should support this pipeline natively.

### 10. Existing LaTeX and Typst Extension Integration

The latex and typst extensions already provide:

- **LaTeX**: Document structure patterns, theorem environments, cross-references, compilation guides, VimTeX integration
- **Typst**: Fletcher diagrams, rule environments, textbook standards, compilation guide, Polylux/Touying awareness

The filetypes extension should **complement** these by:
- Providing data import capabilities (Excel -> LaTeX/Typst tables)
- Providing content migration capabilities (PPTX -> Beamer/Polylux)
- Acting as a **bridge** between office formats and academic typesetting
- Enabling round-trip workflows where academic output can be exported back to office formats

## Recommendations

### 1. Rename and Expand Extension

Rename `document-converter` to `filetypes` with expanded manifest covering spreadsheet, presentation, and document conversion capabilities.

### 2. Implement Specialized Sub-Agents

Create separate agents for spreadsheet operations, presentation operations, and document operations, coordinated by a routing agent.

### 3. Prioritize These Conversion Pipelines

**Phase 1 (Core)**:
- XLSX/CSV -> LaTeX table (pandas + booktabs)
- XLSX/CSV -> Typst table (CSV intermediate + native csv())
- PPTX -> Markdown extraction (markitdown/python-pptx)

**Phase 2 (Academic Slides)**:
- PPTX -> LaTeX Beamer (via Markdown + pandoc)
- PPTX -> Typst Polylux/Touying (agent-assisted)
- Markdown -> PPTX (pandoc, for sharing with non-LaTeX colleagues)

**Phase 3 (Round-trip)**:
- LaTeX table -> XLSX (pandas reverse)
- Beamer -> PPTX (beamer2pptx)
- CSV/data file management utilities

### 4. Maintain Tool Fallback Chains

Preserve the existing pattern of primary tool -> fallback tool for each conversion type. Each agent should detect installed tools and use the best available option.

### 5. Add New Commands

- `/convert` - Keep for general file conversion (existing)
- `/table` - Specialized for spreadsheet-to-table conversion with format options
- `/slides` - Specialized for presentation conversion and generation

### 6. Leverage MCP Servers Where Available

Use markitdown-mcp and mcp-pandoc for environments that support MCP, with CLI fallback for headless/CI environments.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Heavy Python dependencies (pandas, openpyxl, python-pptx) | Installation complexity | Make dependencies optional with clear error messages, use pip groups |
| Lossy PPTX -> Beamer conversion | User frustration | Set clear expectations in documentation, focus on content not layout |
| Typst slide packages are young | API changes, breakage | Abstract slide generation behind agent layer, easy to update |
| Too many conversion paths | Maintenance burden | Start with Phase 1 (most impactful), expand gradually |
| Name collision with other "filetypes" concepts | Confusion | Use clear naming in docs: "filetypes extension" = format conversion |

## References

- [Microsoft MarkItDown](https://github.com/microsoft/markitdown) - Python tool for converting files and office documents to Markdown
- [MarkItDown MCP Server](https://www.pulsemcp.com/servers/markitdown) - MCP integration for MarkItDown
- [pandas DataFrame.to_latex()](https://pandas.pydata.org/docs/reference/api/pandas.DataFrame.to_latex.html) - Publication-quality LaTeX table generation
- [python-pptx](https://python-pptx.readthedocs.io/) - Python library for PowerPoint file manipulation
- [openpyxl](https://openpyxl.readthedocs.io/) - Python library for Excel XLSX read/write
- [xlsx2csv](https://github.com/dilshod/xlsx2csv) - Fast XLSX to CSV converter
- [csv2latex](https://ctan.org/pkg/csv2latex) - CSV to LaTeX table converter
- [rexllent](https://typst.app/universe/package/rexllent/) - Typst package for Excel spreadsheet import
- [spreet](https://typst.app/universe/package/spreet/) - Typst spreadsheet decoder
- [tabut](https://typst.app/universe/package/tabut/) - Typst advanced table generation from data
- [Touying](https://touying-typ.github.io/docs/intro/) - Typst presentation package
- [Polylux](https://polylux.dev/book/) - Typst slides package (Beamer equivalent)
- [pptx-to-beamer](https://github.com/tomaz-suller/pptx-to-beamer) - PowerPoint to Beamer conversion via pandoc
- [pptx-to-md](https://github.com/phlummox/pptx-to-md) - PowerPoint to Beamer-friendly Markdown
- [beamer2pptx](https://github.com/martinGithub/beamer2pptx) - Beamer to PowerPoint conversion
- [Excel2LaTeX via Python](https://github.com/michaelkirker/excel2latexviapython) - Excel to LaTeX with formatting
- [md-converter](https://github.com/Duds/md-converter) - Markdown to DOCX/XLSX/PPTX with MCP server
- [mcp-pandoc](https://github.com/vivekVells/mcp-pandoc) - Pandoc MCP server for format conversion
- [Typst CSV function](https://typst.app/docs/reference/data-loading/csv/) - Native CSV data loading in Typst
- [Making Slides in 2026](https://perrotta.dev/2026/02/making-a-slides-presentation-in-2026/) - Modern presentation workflow with Typst + Polylux
- [Typst with Pandoc](https://slhck.info/software/2025/10/25/typst-pdf-generation-xelatex-alternative.html) - Typst as pandoc PDF engine

## Context Extension Recommendations

- **Topic**: Spreadsheet-to-table conversion patterns
- **Gap**: No context file covers Excel/CSV to LaTeX/Typst table generation workflows
- **Recommendation**: Create `context/project/filetypes/patterns/spreadsheet-tables.md` in the filetypes extension

- **Topic**: Presentation slide conversion patterns
- **Gap**: No context file covers PPTX to Beamer/Polylux/Touying workflows
- **Recommendation**: Create `context/project/filetypes/patterns/presentation-slides.md` in the filetypes extension

- **Topic**: Typst presentation packages (Polylux/Touying)
- **Gap**: Typst extension context does not cover slide deck creation
- **Recommendation**: Add `context/project/typst/patterns/slide-decks.md` to the typst extension when presentation support is added

## Next Steps

Run `/plan 122` to create an implementation plan based on these findings. The plan should follow the phased approach (Core -> Academic Slides -> Round-trip) and include the extension renaming, agent architecture, and tool dependency management.
