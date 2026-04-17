# Character Encoding and Emoji Policy

## NO EMOJIS IN FILE CONTENT

**NEVER use emojis in file content** - they can cause bad characters and encoding issues when saved to disk.

**Exception**: Emojis are allowed in runtime UI elements (pickers, notifications, etc.) where they are displayed but not saved to files.

### Forbidden Characters (in files)
- [x] Emojis (target, checkmarks, crosses, clipboards, etc.) - cause bad character encoding
- [x] Unicode symbols beyond basic box-drawing (lightbulbs, tools, rockets, etc.)
- [x] Any non-ASCII decorative characters that may not render properly

### Approved Alternatives
Instead of emojis, use:
- `[DONE]` instead of checkmark emojis
- `[FAIL]` instead of cross emojis
- `[!]` or `[WARN]` instead of warning emojis
- `[i]` or `[INFO]` instead of info emojis
- `**` for emphasis instead of decorative symbols
- Plain text descriptions instead of pictographs

### Safe Characters
- Basic ASCII (a-z, A-Z, 0-9, punctuation)
- Standard markdown symbols (*, -, #, etc.)
- Unicode box-drawing characters (see box-drawing-guide.md)
- Basic mathematical symbols (+, -, =, <, >, etc.)

### Encoding Guidelines
1. **Always use UTF-8 encoding** for all files
2. **Test file display** in multiple contexts (terminal, editor, web)
3. **Avoid fancy Unicode** unless specifically needed and tested
4. **Prefer ASCII** when possible for maximum compatibility
