# Research: Slim nvim/CLAUDE.md

## Problem

`nvim/CLAUDE.md` is 224 lines. Significant portions are reference material that doesn't need to be in always-loaded context.

## Content Audit

| Section | Lines | Always Needed? | Action |
|---------|-------|----------------|--------|
| Commands (1-8) | 8 | Yes | Keep |
| Code Standards (10-29) | 20 | Yes | Keep |
| Project Organization (30-35) | 6 | Yes | Keep |
| Documentation Policy (31-68) | 38 | Rarely | Move to context |
| Box Drawing Characters (70-121) | 52 | Rarely | Move to context |
| Emoji Policy (123-154) | 32 | Rarely | Move to context |
| Testing Protocols (156-174) | 19 | Sometimes | Keep (concise) |
| Lua Assertion Patterns (176-214) | 39 | Rarely | Move to context |
| Standards Discovery (216-224) | 9 | Yes | Keep |

## Proposed Slimmed Structure (~85 lines)

Keep: Commands, Code Standards, Project Organization, Testing Protocols (concise), Standards Discovery
Move to context: Documentation Policy template, Box Drawing guide, Emoji Policy, Assertion Patterns

## Target Context Files

- `.claude/context/project/neovim/standards/documentation-policy.md` (~38 lines)
- `.claude/context/project/neovim/standards/box-drawing-guide.md` (~52 lines)
- `.claude/context/project/neovim/standards/emoji-policy.md` (~32 lines)
- `.claude/context/project/neovim/standards/lua-assertion-patterns.md` (~39 lines)

## Impact

- Saves ~138 lines from always-loaded context
- Content still discoverable via index.json when needed
