# Research Report: Task #251

**Task**: Improve context efficiency throughout the Claude Code agent system
**Date**: 2026-03-19
**Focus**: Progressive disclosure and lazy loading to reduce CLAUDE.md context overhead

**Note**: Team research with team_size=2. This synthesis is based on teammate A findings
(01_teammate-a-findings.md). Teammate B did not complete; findings are from one investigator.

---

## Summary

The Claude Code agent system currently loads ~24,276 tokens of context on every session
start, consuming ~12% of a 200k context window before any task work begins. The primary
sources of overhead are four CLAUDE.md files (14,266 tokens) and five auto-applied rules
files (10,010 tokens). Three high-impact optimizations - stripping Quick Reference inline
content from the root CLAUDE.md, consolidating duplicated system CLAUDE.md files, and
splitting the oversized state-management rule - could reduce always-loaded overhead by
approximately 32% (~7,846 tokens) with no loss of functionality.

---

## Findings

### Finding 1: Always-Loaded Context Baseline

**CLAUDE.md files** (all 4 auto-loaded by Claude Code for any file under `~/.config/nvim/`):

| File | Tokens |
|------|--------|
| `~/.config/CLAUDE.md` | ~6,961 |
| `~/.config/nvim/.claude/CLAUDE.md` | ~3,309 |
| `~/.config/nvim/CLAUDE.md` | ~2,289 |
| `~/.config/.claude/CLAUDE.md` | ~1,707 |
| **Total** | **~14,266** |

**Rules files** (auto-applied via glob path matching):

| File | Tokens |
|------|--------|
| `state-management.md` | ~4,536 |
| `artifact-formats.md` | ~1,818 |
| `workflows.md` | ~1,510 |
| `error-handling.md` | ~1,200 |
| `git-workflow.md` | ~946 |
| **Total** | **~10,010** |

**Grand total: ~24,276 tokens always loaded.**

---

### Finding 2: Root CLAUDE.md Has ~4,440 Tokens of Redundant Inline Content

The root `~/.config/CLAUDE.md` contains 9 sections marked "Used by: all commands" that
each embed a "Quick Reference" block alongside a pointer to the authoritative full document.
This means the same content exists in both CLAUDE.md (always loaded) and a linked doc file
(lazy-loaded on demand). The inline Quick Reference blocks serve no unique purpose.

These 9 sections collectively consume ~4,440 tokens and could each be reduced to a
~40-token pointer-and-summary, saving ~4,080 tokens with no functionality change.

The 9 sections and their current token costs:

| Section | Tokens |
|---------|--------|
| Code Standards | 580 |
| Non-Interactive Testing Standards | 334 |
| Code Quality Enforcement | 465 |
| Error Logging Standards | 472 |
| Concurrent Execution Safety | 434 |
| Plan Metadata Standard | 278 |
| Hierarchical Agent Architecture | 918 |
| Skills Architecture | 391 |
| Documentation Policy | 568 |
| **Total** | **4,440** |

Importantly, 11 other sections in the same file already use the correct pointer-only pattern
(74-88 tokens each): Testing Protocols, Development Philosophy, Adaptive Planning,
Configuration Portability and Command Discovery, etc. These demonstrate the target pattern.

---

### Finding 3: Two System CLAUDE.md Files Duplicate ~1,581 Tokens

`~/.config/.claude/CLAUDE.md` (1,707 tokens) is an older, smaller version of
`~/.config/nvim/.claude/CLAUDE.md` (3,309 tokens). They share 12 section titles with
significant content overlap:

| Section | Similarity | Duplicate Tokens |
|---------|-----------|-----------------|
| jq Command Safety | 85% | 192 |
| Git Commit Conventions | 94% | 152 |
| Important Notes | 88% | 142 |
| Error Handling | 90% | 130 |
| Quick Reference | 80% | 74 |
| Rules References | ~50% | 228 |
| State Synchronization | ~39% | 555 |

Both files load on every session. The `.claude/CLAUDE.md` file appears to be a legacy
version from before the system was fully migrated to the nvim-specific `.claude/` directory.

---

### Finding 4: State-Management Rule Is Disproportionately Large

At 4,536 tokens, `state-management.md` is the largest auto-applied rule file - more than
the next two rules combined. It covers: status transitions, vault operations, state.json
schema (including vault history, completion fields, dependencies, artifact objects),
Recommended Order section logic, and error handling.

Much of this content (vault operations, full schema details, Recommended Order algorithm)
is only relevant during active state modification, not during the majority of read-heavy
operations that also match `specs/**` path patterns.

---

### Finding 5: Context Index Already Implements Correct Progressive Disclosure

The `~/.config/nvim/.claude/context/index.json` has 73 entries. Only 1 (the README.md)
is flagged `always: true`. The remaining 72 entries are agent-conditional or
language-conditional. This shows the system architecture already has the infrastructure
for lazy loading - the problem is confined to CLAUDE.md files and auto-applied rules files,
which bypass this system.

Skills and agents already use `@-references` for lazy loading context files on demand.
The gap is that CLAUDE.md files load eagerly and unconditionally.

---

## Recommendations

### Recommendation 1: Strip Quick Reference Inline Content from Root CLAUDE.md (HIGHEST PRIORITY)

**Effort**: Low (edit 9 sections, remove inline blocks)
**Savings**: ~4,080 tokens (~59% reduction in root CLAUDE.md)

Convert each of the 9 heavy sections from:
```
## Section Name
[Used by: all commands]

See [Full Doc](path) for complete details.

**Quick Reference**:
- bullet 1 (200-900 tokens of inline detail)
- bullet 2
...
```
To:
```
## Section Name
[Used by: all commands]

See [Full Doc](path) for complete documentation, patterns, and examples.
```

Use the already-correct "lean" sections (Testing Protocols, Development Philosophy, etc.)
as templates. This requires no infrastructure changes.

### Recommendation 2: Consolidate .claude/CLAUDE.md (MEDIUM PRIORITY)

**Effort**: Low (delete or replace with pointer)
**Savings**: ~1,581 tokens (~11% of CLAUDE.md load)

Either:
- Delete `~/.config/.claude/CLAUDE.md` entirely (Claude Code will fall back to the
  `nvim/.claude/CLAUDE.md` which is more complete)
- Or replace it with a minimal file that says: "See `nvim/.claude/CLAUDE.md` for the
  authoritative system configuration."

Verify no commands use `.claude/CLAUDE.md` paths specifically before deleting.

### Recommendation 3: Split State-Management Rule (MEDIUM PRIORITY)

**Effort**: Medium (split file, update glob patterns)
**Savings**: ~2,000-4,000 tokens for non-state operations

Create:
- `state-management-core.md` (~400 tokens): Status transitions, two-phase update pattern,
  critical rules. Auto-apply to `specs/**`.
- `state-management-schema.md` (~2,000 tokens): Full field schemas, vault operations,
  Recommended Order algorithm. Load via @-reference when writing state artifacts.
- Keep existing file as-is or remove in favor of the split.

### Recommendation 4: Externalize Worktree Metadata Header (LOW PRIORITY)

**Effort**: Low
**Savings**: ~185 tokens

The current `~/.config/CLAUDE.md` begins with a "Worktree Task:" block that is
task-specific. This block should not live in a file that loads for all sessions. Move
worktree metadata to a separate file (e.g., `.worktree-context.md`) that is only loaded
in the specific worktree context.

---

## Token Budget Summary

```
Current baseline: ~24,276 tokens always loaded

Savings potential:
  Recommendation 1 (QR stripping):         ~4,080 tokens
  Recommendation 2 (consolidation):        ~1,581 tokens
  Recommendation 3 (rule splitting):       ~2,000 tokens (conservative)
  Recommendation 4 (worktree header):        ~185 tokens
  Total potential savings:                  ~7,846 tokens

Target baseline: ~16,430 tokens (~32% reduction)
```

---

## Context Extension Recommendations

- **No new context gaps identified**: The existing `context/` directory and `index.json`
  infrastructure is sound. The problem is CLAUDE.md file design, not missing context files.
- **Potential new guide**: A "CLAUDE.md authoring guide" documenting the pointer-only
  pattern vs inline Quick Reference anti-pattern would prevent regression.

---

## Next Steps

1. Create implementation plan addressing Recommendations 1-4 in priority order
2. Start with Recommendation 1 (root CLAUDE.md QR stripping) - highest ROI, lowest risk
3. Measure actual token counts before/after using Claude Code's context reporting
4. Validate that no commands break after inline QR removal by running the test suite
