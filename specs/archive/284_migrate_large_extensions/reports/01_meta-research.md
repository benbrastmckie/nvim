# Research: Migrate Large Extensions to Slim Pattern

## Problem

5 large EXTENSION.md files account for ~764 of ~1,111 total extension lines. After the slim standard (Task #283) is defined, these need migration.

## Migration Targets

| Extension | Current Lines | Target Lines | Savings |
|-----------|--------------|--------------|---------|
| founder | 234 | ~50 | 184 |
| present | 216 | ~50 | 166 |
| filetypes | 143 | ~50 | 93 |
| memory | 91 | ~40 | 51 |
| web | 80 | ~40 | 40 |
| **Total** | **764** | **~230** | **~534** |

## Migration Pattern Per Extension

1. Audit current EXTENSION.md content
2. Identify essential routing info (keep)
3. Move documentation to `context/{extension}/` files
4. Add new context files to `index-entries.json`
5. Update EXTENSION.md with @-reference pointers
6. Verify extension loading still works

## Verification

- Extension loads via `<leader>ac` without errors
- Routing tables still resolve correctly
- Context files discoverable via index.json queries
- No broken @-references

## Dependencies

- Requires Task #283 (slim standard) to be completed first
