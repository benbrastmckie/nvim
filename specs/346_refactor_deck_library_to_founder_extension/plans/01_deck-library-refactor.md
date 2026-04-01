# Implementation Plan: Refactor Deck Library to Founder Extension

- **Task**: 346 - Refactor deck library from .context/ to founder extension
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_team-research.md, reports/01_teammate-a-findings.md, reports/01_teammate-b-findings.md
- **Artifacts**: plans/01_deck-library-refactor.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Move the deck library (54 files across 7 categories) from `.context/deck/` to `.claude/extensions/founder/context/project/founder/deck/` so it ships with the founder extension and is available in any repository. Use the initialize-on-first-use pattern (Approach B from research): when a deck agent runs and `.context/deck/` does not exist, it copies the seed library from the extension to `.context/deck/`, then all reads and writes use `.context/deck/` as the single path. This minimizes agent path churn and preserves the existing write-back mechanism.

### Research Integration

Team research (2 teammates) identified the critical tension between extension loader overwrite behavior and deck-builder-agent write-back. The seed-and-overlay architecture with initialize-on-first-use resolves this: the extension owns the canonical seed, `.context/deck/` serves as the mutable runtime copy. All 6 files with `.context/deck/` references were audited; only 2 agent files need an initialization guard added. Documentation references remain unchanged since agents continue using `.context/deck/` paths after initialization.

## Goals & Non-Goals

**Goals**:
- Ship the deck library as part of the founder extension so new repositories get it automatically
- Preserve the existing write-back mechanism in deck-builder-agent
- Keep `.context/deck/` as the single runtime path for all agent reads and writes
- Add initialization guards to deck-planner-agent and deck-builder-agent
- Update index registration from `.context/index.json` to extension `index-entries.json`

**Non-Goals**:
- Implementing a library version tracking or merge strategy for stale overlays
- Creating a standalone `/deck init` command (initialization happens inside agents)
- Changing the sub-index query pattern (agents continue to query `.context/deck/index.json` via jq)
- Modifying deck-research-agent (it has no `.context/deck/` references)
- Updating historical specs/345 artifacts (read-only historical records)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Extension loader overwrites `.claude/context/` on reload, but agents still use `.context/deck/` | L | L | By design: agents use `.context/deck/`, not `.claude/context/`. The extension seed is only a source for initialization. |
| Initialization guard adds latency on first `/deck` invocation | L | H | The `cp -r` of 54 files is sub-second. Acceptable one-time cost per repo. |
| `.context/deck/` diverges from extension seed over time | M | M | Acceptable by design. Write-back is intentional divergence. Future version field could detect staleness. |
| Forgetting to remove `.context/index.json` deck entry causes duplicate registration | L | L | Phase 3 explicitly removes the entry. Verification step confirms removal. |

## Implementation Phases

### Phase 1: Copy Deck Library to Extension [COMPLETED]

**Goal**: Create the seed library inside the founder extension context directory.

**Tasks**:
- [ ] Create destination directory `.claude/extensions/founder/context/project/founder/deck/`
- [ ] Copy entire `.context/deck/` tree to `.claude/extensions/founder/context/project/founder/deck/`
- [ ] Verify all 54 files and 7 categories (animations, components, contents, patterns, styles, themes, index.json) are present in the new location
- [ ] Verify `index.json` paths are relative (they use paths like `animations/fade-in.md` which are relative to the deck directory -- these remain valid)

**Timing**: 30 minutes

**Files to create**:
- `.claude/extensions/founder/context/project/founder/deck/` -- entire directory tree (54 files)

**Verification**:
- `find .claude/extensions/founder/context/project/founder/deck/ -type f | wc -l` returns 54
- `diff -r .context/deck/ .claude/extensions/founder/context/project/founder/deck/` shows no differences

---

### Phase 2: Add Initialization Guards to Agents [COMPLETED]

**Goal**: Add initialize-on-first-use logic so agents copy the seed library to `.context/deck/` when it does not exist.

**Tasks**:
- [ ] Add initialization guard to `deck-planner-agent.md` near the beginning of its execution flow (before Stage 1 library queries)
- [ ] Add initialization guard to `deck-builder-agent.md` near the beginning of its execution flow (before Stage 2 theme loading)
- [ ] The guard should be approximately:
  ```
  ### Library Initialization
  If `.context/deck/index.json` does not exist:
  1. Copy `.claude/extensions/founder/context/project/founder/deck/` to `.context/deck/`
  2. Log: "Initialized deck library from extension seed"
  ```
- [ ] Ensure the guard checks for `.context/deck/index.json` specifically (not just the directory) to handle partial states

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/deck-planner-agent.md` -- add ~5-line initialization guard
- `.claude/extensions/founder/agents/deck-builder-agent.md` -- add ~5-line initialization guard

**Verification**:
- Both agent files contain the initialization guard
- Guard references the correct extension seed path
- All existing `.context/deck/` references in both files remain unchanged (no path churn)

---

### Phase 3: Update Index Registration [COMPLETED]

**Goal**: Move the deck library registration from `.context/index.json` to the extension's `index-entries.json` so it is discoverable through the standard context index.

**Tasks**:
- [ ] Add one entry to `.claude/extensions/founder/index-entries.json` for the deck sub-index:
  ```json
  {
    "path": "project/founder/deck/index.json",
    "summary": "Slidev deck library sub-index with themes, patterns, animations, styles, content templates, and Vue components for agent-driven deck construction",
    "line_count": 477,
    "load_when": {
      "agents": ["deck-planner-agent", "deck-builder-agent", "deck-research-agent"],
      "languages": ["founder"],
      "commands": ["/deck"]
    }
  }
  ```
- [ ] Remove the `deck/index.json` entry from `.context/index.json`
- [ ] Verify no other `.context/index.json` entries reference deck files

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/index-entries.json` -- add 1 entry
- `.context/index.json` -- remove 1 entry

**Verification**:
- `jq '.entries[] | select(.path | test("deck"))' .claude/extensions/founder/index-entries.json` returns the new entry (after loader merge)
- `jq '.entries[] | select(.path | test("deck"))' .context/index.json` returns nothing
- Extension loader merge produces correct result in `.claude/context/index.json`

---

### Phase 4: Remove Original and Verify [NOT STARTED]

**Goal**: Remove the original `.context/deck/` directory (now that the extension owns the seed) and run end-to-end verification.

**Tasks**:
- [ ] Remove `.context/deck/` directory entirely
- [ ] Verify the extension seed at `.claude/extensions/founder/context/project/founder/deck/` contains all 54 files
- [ ] Simulate initialization: manually run the initialization guard logic (copy extension seed to `.context/deck/`) and verify the copy is complete
- [ ] Verify agent `@.context/deck/index.json` references will resolve after initialization
- [ ] Verify jq queries against `.context/deck/index.json` return expected results after initialization
- [ ] Clean up the simulated `.context/deck/` (remove it again so the repo ships without it, relying on agents to initialize on first use)

**Timing**: 30 minutes

**Files to remove**:
- `.context/deck/` -- entire directory (54 files, now lives in extension seed)

**Verification**:
- `.context/deck/` does not exist in the repository
- `.claude/extensions/founder/context/project/founder/deck/` contains 54 files
- No broken references remain in active (non-specs) files
- `grep -r '\.context/deck' .claude/extensions/founder/` shows only references inside agent initialization guards and the standard `.context/deck/` runtime paths (no stale references to removed files)

## Testing & Validation

- [ ] Extension seed contains all 54 files matching the original `.context/deck/` content
- [ ] Initialization guard in deck-planner-agent correctly copies seed to `.context/deck/` when missing
- [ ] Initialization guard in deck-builder-agent correctly copies seed to `.context/deck/` when missing
- [ ] After initialization, all jq queries in agents resolve against `.context/deck/index.json`
- [ ] `.context/index.json` no longer contains a deck entry
- [ ] `index-entries.json` contains the new deck sub-index entry
- [ ] Write-back paths in deck-builder-agent (lines 305-306) still target `.context/deck/` (unchanged)
- [ ] No `.context/deck/` directory ships in the repository (agents create it on first use)

## Artifacts & Outputs

- `plans/01_deck-library-refactor.md` -- this plan
- `summaries/01_deck-library-refactor-summary.md` -- execution summary (created during implementation)
- `.claude/extensions/founder/context/project/founder/deck/` -- new extension seed directory (54 files)
- Modified: `deck-planner-agent.md`, `deck-builder-agent.md`, `index-entries.json`, `.context/index.json`
- Removed: `.context/deck/` (54 files)

## Rollback/Contingency

If the refactor causes issues:
1. Restore `.context/deck/` from git history: `git checkout HEAD~1 -- .context/deck/`
2. Restore `.context/index.json` entry from git history
3. Remove the initialization guards from both agent files
4. Remove `.claude/extensions/founder/context/project/founder/deck/`
5. Revert `index-entries.json` changes

All changes are confined to tracked files, so `git revert` of the implementation commit is the simplest rollback path.
