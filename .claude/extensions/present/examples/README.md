# Pitch Deck Theme Examples

This directory contains complete, compilable investor pitch deck examples demonstrating four professional color themes.

## Available Examples

| Example | Theme | Best For |
|---------|-------|----------|
| [professional-blue-pitch.typ](professional-blue-pitch.typ) | Professional Blue | Fintech, enterprise B2B, professional services |
| [premium-dark-pitch.typ](premium-dark-pitch.typ) | Premium Dark | Premium products, luxury brands, sophisticated tech |
| [minimal-light-pitch.typ](minimal-light-pitch.typ) | Minimal Light | Data-focused, analytics, enterprise software |
| [growth-green-pitch.typ](growth-green-pitch.typ) | Growth Green | Sustainability, health, environmental tech |

## Quick Start

1. Copy an example to your project directory
2. Replace `[TODO: ...]` placeholders with your content
3. Compile with `typst compile filename.typ`

```bash
# Example compilation
typst compile professional-blue-pitch.typ

# Watch mode for live preview
typst watch professional-blue-pitch.typ
```

## Shared Configuration

[shared-config.typ](shared-config.typ) contains reusable utilities:

- **Color palette definitions** - All four theme palettes with hex codes
- **Typography helpers** - Montserrat + Inter font configuration
- **Layout utilities** - Two-column grids, team member cards, metric displays
- **Chart placeholders** - Styled placeholders for data visualization

### Using Shared Configuration

```typst
#import "shared-config.typ": *

// Access color palettes
#let colors = professional-blue

// Use metric display
#metric-display(value: "500K", label: "Active Users", color: colors.primary)

// Use two-column layout
#two-columns(
  [Left content],
  [Right content],
)
```

## Font Requirements

Examples use Montserrat and Inter fonts. If unavailable, Typst falls back to system fonts.

### Installing Fonts (Optional)

**macOS**: `brew install font-montserrat font-inter`

**Linux**: Download from Google Fonts and install to `~/.local/share/fonts/`

**NixOS**: Add to configuration:
```nix
fonts.packages = with pkgs; [ montserrat inter ];
```

## Structure

Each example follows the YC-recommended 10-slide structure:

1. Title
2. Problem
3. Solution
4. Traction
5. Why Us / Why Now
6. Business Model
7. Market Opportunity
8. Team
9. The Ask
10. Thank You

## Customization

See the main extension README for detailed customization guidance:
- Color modifications
- Font changes
- Chart integration
- Animation options

## Related Files

- [../README.md](../README.md) - Extension documentation
- [../context/project/present/patterns/touying-pitch-deck-template.md] - Base template reference
- [../context/project/present/patterns/pitch-deck-structure.md] - YC design principles
