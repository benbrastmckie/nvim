## Filetypes Extension

File format conversion and manipulation: documents, spreadsheets, presentations, PDF annotations.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-filetypes | filetypes-router-agent | Format detection and routing |
| skill-filetypes | document-agent | Document format conversion (PDF/DOCX/Markdown) |
| skill-spreadsheet | spreadsheet-agent | Spreadsheet to LaTeX/Typst table conversion |
| skill-presentation | presentation-agent | Presentation extraction and slide generation |
| skill-scrape | scrape-agent | PDF annotation extraction |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/convert` | `/convert file.pdf` | Convert between document formats |
| `/table` | `/table data.xlsx` | Convert spreadsheets to LaTeX/Typst tables |
| `/slides` | `/slides deck.pptx` | Convert presentations to Beamer/Polylux/Touying |
| `/scrape` | `/scrape paper.pdf` | Extract PDF annotations to Markdown/JSON |
