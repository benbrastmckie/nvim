# Spreadsheet to Table Conversion Patterns

Patterns for converting spreadsheet data (XLSX, CSV, ODS) to LaTeX and Typst table formats.

## LaTeX Table Generation

### pandas DataFrame.to_latex()

The primary method for generating LaTeX tables from spreadsheet data.

```python
import pandas as pd

# Read spreadsheet
df = pd.read_excel("data.xlsx")  # or pd.read_csv("data.csv")

# Basic LaTeX output
latex = df.to_latex(index=False)

# With booktabs (recommended)
latex = df.to_latex(
    index=False,
    escape=True,
    header=True,
    column_format='l' + 'r' * (len(df.columns) - 1)  # Left-align first, right-align rest
)
```

### booktabs Package Integration

For professional-looking tables, use booktabs formatting.

**LaTeX Preamble Requirement**:
```latex
\usepackage{booktabs}
```

**Generated Table Structure**:
```latex
\begin{tabular}{lrrr}
\toprule
Name & Q1 & Q2 & Q3 \\
\midrule
Product A & 100 & 150 & 200 \\
Product B & 80 & 120 & 160 \\
\bottomrule
\end{tabular}
```

### Column Format Options

| Type | Format | Description |
|------|--------|-------------|
| Left-aligned | `l` | Text columns |
| Right-aligned | `r` | Numeric columns |
| Centered | `c` | Headers, short text |
| Paragraph | `p{width}` | Long text with wrapping |

**Auto-detection heuristic**:
```python
def get_column_format(df):
    formats = []
    for col in df.columns:
        if pd.api.types.is_numeric_dtype(df[col]):
            formats.append('r')
        else:
            formats.append('l')
    return ''.join(formats)
```

### Handling Special Characters

pandas `escape=True` handles most LaTeX special characters:
- `&` -> `\&`
- `%` -> `\%`
- `$` -> `\$`
- `#` -> `\#`
- `_` -> `\_`
- `{` -> `\{`
- `}` -> `\}`

**Manual escaping** (if needed):
```python
def escape_latex(text):
    special = {'&': r'\&', '%': r'\%', '$': r'\$', '#': r'\#',
               '_': r'\_', '{': r'\{', '}': r'\}', '~': r'\textasciitilde{}',
               '^': r'\^{}', '\\': r'\textbackslash{}'}
    for char, escape in special.items():
        text = text.replace(char, escape)
    return text
```

## Typst Table Generation

### Using csv() Function

Typst can import CSV data directly.

**Basic table from CSV**:
```typst
#let data = csv("data.csv")

#table(
  columns: data.first().len(),
  ..data.flatten()
)
```

### Using tabut Package

For more formatting control, use the tabut package.

```typst
#import "@preview/tabut:0.3.0": *

#let data = csv("data.csv")

#tabut(
  data,
  columns: (auto,) * data.first().len(),
  fill: (_, row) => if calc.odd(row) { luma(240) } else { white },
  stroke: none,
)
```

### Direct Table Construction

For XLSX data (via pandas to structured data):

```typst
#table(
  columns: 4,
  stroke: none,
  inset: 6pt,
  align: (left, right, right, right),

  // Header
  [*Name*], [*Q1*], [*Q2*], [*Q3*],
  table.hline(stroke: 0.5pt),

  // Data rows
  [Product A], [100], [150], [200],
  [Product B], [80], [120], [160],

  table.hline(stroke: 0.5pt),
)
```

### Typst Package Options

| Package | Purpose | Features |
|---------|---------|----------|
| **tabut** | Data tables | CSV import, zebra striping, sorting |
| **tablex** | Complex layouts | Merged cells, advanced alignment |

## Multi-Sheet Workbook Handling

### Listing Available Sheets

```python
import pandas as pd

xl = pd.ExcelFile("workbook.xlsx")
print(xl.sheet_names)  # ['Sheet1', 'Data', 'Summary']
```

### Reading Specific Sheet

```python
# By name
df = pd.read_excel("workbook.xlsx", sheet_name="Data")

# By index (0-based)
df = pd.read_excel("workbook.xlsx", sheet_name=0)
```

### Processing All Sheets

```python
xl = pd.ExcelFile("workbook.xlsx")
for sheet_name in xl.sheet_names:
    df = pd.read_excel(xl, sheet_name=sheet_name)
    output_path = f"tables/{sheet_name}.tex"
    with open(output_path, 'w') as f:
        f.write(df.to_latex(index=False))
```

## CSV Intermediate Pattern

For Typst output, generating a clean CSV intermediate is often the best approach:

```python
import pandas as pd

# Read source (XLSX, ODS, etc.)
df = pd.read_excel("source.xlsx")

# Clean data for Typst
df = df.fillna('')  # Replace NaN with empty string
df.to_csv("data.csv", index=False)

# Generate Typst file
typst_code = '''#let data = csv("data.csv")

#table(
  columns: data.first().len(),
  ..data.flatten()
)
'''
with open("table.typ", 'w') as f:
    f.write(typst_code)
```

## Advanced Formatting

### Number Formatting

```python
# Format numbers with thousands separator
df['amount'] = df['amount'].apply(lambda x: f'{x:,.2f}')

# Currency formatting
df['price'] = df['price'].apply(lambda x: f'\\${x:,.2f}')  # LaTeX
df['price'] = df['price'].apply(lambda x: f'${x:,.2f}')   # Typst
```

### Date Formatting

```python
# Convert datetime to string
df['date'] = pd.to_datetime(df['date']).dt.strftime('%Y-%m-%d')
```

### Column Width Control (LaTeX)

```latex
% Use tabularx for automatic width
\usepackage{tabularx}

\begin{tabularx}{\textwidth}{X r r r}
% X column expands to fill width
\end{tabularx}
```

## Tool Fallback Patterns

### Primary: pandas + openpyxl
- Full Excel feature support
- Preserves cell formatting info
- Handles formulas (reads calculated values)

### Fallback: xlsx2csv + pandas
```bash
# Extract CSV from XLSX
xlsx2csv data.xlsx data.csv

# Then process with pandas
python3 -c "import pandas as pd; print(pd.read_csv('data.csv').to_latex())"
```

### Basic: markitdown
- Extracts tables as markdown
- May lose formatting
- Good for quick extraction
