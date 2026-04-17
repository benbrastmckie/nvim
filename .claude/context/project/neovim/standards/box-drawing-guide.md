# Box Drawing and ASCII Diagrams

When creating diagrams in documentation, use Unicode box-drawing characters for professional-looking diagrams that render well in modern editors.

## Recommended Unicode Box Drawing Characters

These UTF-8 characters create clean, professional diagrams (as used in ARCHITECTURE_V3.md):

### Corners
- `┌` (U+250C) - Top left corner
- `┐` (U+2510) - Top right corner
- `└` (U+2514) - Bottom left corner
- `┘` (U+2518) - Bottom right corner

### Lines
- `─` (U+2500) - Horizontal line
- `│` (U+2502) - Vertical line

### Intersections
- `├` (U+251C) - Vertical line with right branch
- `┤` (U+2524) - Vertical line with left branch
- `┬` (U+252C) - Horizontal line with down branch
- `┴` (U+2534) - Horizontal line with up branch
- `┼` (U+253C) - Four-way intersection

## Example Professional Diagram
```
┌─────────────────────────────────────────────────────────────┐
│                    Component Name                           │
│              Description of component                       │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────┴────────────────────────────────────────┐
│                    Another Component                        │
│              Can access the component above                 │
└─────────────────────────────────────────────────────────────┘
```

## How to Type These Characters
1. **Copy from this guide**: Copy the characters directly from above
2. **Unicode input**:
   - Linux: Ctrl+Shift+U, then type the hex code (e.g., 250C for ┌)
   - Mac: Use Character Viewer or Unicode Hex Input
   - Windows: Alt+X after typing the hex code
3. **Editor plugins**: Many editors have box-drawing plugins
4. **Copy from existing files**: ARCHITECTURE_V3.md has examples

## Best Practices
1. **Use Consistently**: Use the same style throughout a document
2. **UTF-8 Encoding**: Ensure your file is saved with UTF-8 encoding
3. **Test Display**: Verify the diagram displays correctly in GitHub/GitLab
4. **Align Carefully**: Use monospace fonts and align characters precisely
5. **Modern Editors**: These characters work well in Neovim, VS Code, etc.
