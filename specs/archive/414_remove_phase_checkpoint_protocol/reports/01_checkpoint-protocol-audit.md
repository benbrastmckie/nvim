# Research Report: Task #414

**Task**: 414 - Remove Phase Checkpoint Protocol from 10 extension agents
**Date**: 2026-04-13
**Sources**: Codebase analysis of all 10 target agents and 2 already-cleaned agents

## Executive Summary

- All 10 agents contain a "## Phase Checkpoint Protocol" section that duplicates logic now handled by the core implementation agent
- 6 of 10 agents have inline references in Critical Requirements sections that should also be removed
- 3 agents (deck-builder, founder-implement, grant-agent) have additional inline references in other sections
- 1 agent (grant-agent) has Stage 6 and Stage 7 content incorrectly nested under the Phase Checkpoint Protocol heading; these stages must be promoted to `## Execution Flow` peers, not deleted
- Total lines to remove (or restructure): 280 across all 10 agents
- No phase-to-stage mapping tables exist in any agent

## Reference: Already-Cleaned Agents

The following agents have already been cleaned and serve as the target pattern:

| Agent | Lines | Pattern |
|-------|-------|---------|
| `present/agents/pptx-assembly-agent.md` | 332 | No checkpoint section, no inline refs |
| `present/agents/slidev-assembly-agent.md` | 362 | No checkpoint section, no inline refs |
| `epi/agents/epi-implement-agent.md` | N/A | Extension not present locally |

**Pattern**: Complete removal of the `## Phase Checkpoint Protocol` section and all inline references to "update plan file phase markers" or per-phase commit instructions. Sections that follow (Error Handling, Critical Requirements) become directly adjacent.

---

## Agent-by-Agent Analysis

### 1. latex-implementation-agent.md (171 lines total)

**Phase Checkpoint Protocol section**: Lines 131-148
- Line 131: `## Phase Checkpoint Protocol` heading
- Lines 132-146: Standard 6-step protocol (compact variant, no Edit tool examples)
- Line 147: `---` horizontal rule
- Line 148: blank line
- **Lines to remove**: 131-148 (18 lines)
- **Preceding content**: Line 130 is blank (after Stage 8 heading)
- **Following content**: Line 149 `## Common Errors and Fixes`

**Inline references**:
- Line 164: `5. Update plan file phase markers with Edit tool` (in MUST DO list)
  - **Remove this line** (1 line)

**Phase-to-stage mapping table**: None

**Total lines to remove**: 19

---

### 2. typst-implementation-agent.md (152 lines total)

**Phase Checkpoint Protocol section**: Lines 110-127
- Line 110: `## Phase Checkpoint Protocol` heading
- Lines 111-125: Standard 6-step protocol (compact variant, no Edit tool examples)
- Line 126: `---` horizontal rule
- Line 127: blank line
- **Lines to remove**: 110-127 (18 lines)
- **Preceding content**: Line 109 is blank (after Stage 8 heading)
- **Following content**: Line 128 `## Typst vs LaTeX Differences`

**Inline references**:
- Line 145: `5. Update plan file phase markers with Edit tool` (in MUST DO list)
  - **Remove this line** (1 line)

**Phase-to-stage mapping table**: None

**Total lines to remove**: 19

---

### 3. python-implementation-agent.md (170 lines total)

**Phase Checkpoint Protocol section**: Lines 129-156
- Line 129: `## Phase Checkpoint Protocol` heading
- Lines 130-155: Detailed 6-step protocol (includes Edit tool old_string/new_string examples and git commit bash block)
- Line 156: blank line
- **Lines to remove**: 129-156 (28 lines)
- **Preceding content**: Line 128 is blank (after Stage 8 heading)
- **Following content**: Line 157 `## Critical Requirements`

**Inline references**:
- Line 164: `5. Update plan file phase markers with Edit tool` (in MUST DO list)
  - **Remove this line** (1 line)

**Phase-to-stage mapping table**: None

**Total lines to remove**: 29

---

### 4. nix-implementation-agent.md (747 lines total)

**Phase Checkpoint Protocol section**: Lines 698-720
- Line 698: `## Phase Checkpoint Protocol` heading
- Lines 699-719: Detailed 6-step protocol (includes git commit bash block with Co-Authored-By trailer)
- Line 720: blank line
- **Lines to remove**: 698-720 (23 lines)
- **Preceding content**: Line 697 is blank (after error recovery section)
- **Following content**: Line 721 `## Critical Requirements`

**Inline references**:
- Line 128: `- Phase list with status markers` -- NOT a checkpoint ref, just plan parsing. **Keep.**
- Line 733: `10. Update partial_progress after each phase completion` -- Refers to metadata partial_progress, not plan file markers. **Keep.**

**Phase-to-stage mapping table**: None

**Total lines to remove**: 23

---

### 5. neovim-implementation-agent.md (419 lines total)

**Phase Checkpoint Protocol section**: Lines 370-394
- Line 370: `## Phase Checkpoint Protocol` heading
- Lines 371-392: Detailed 6-step protocol (includes git commit bash block with Co-Authored-By trailer)
- Line 393: `---` horizontal rule
- Line 394: blank line
- **Lines to remove**: 370-394 (25 lines)
- **Preceding content**: Line 369 is blank (after plugin conflict section)
- **Following content**: Line 395 `## Critical Requirements`

**Inline references**:
- Line 107: `- Phase list with status markers` -- Plan parsing, not checkpoint ref. **Keep.**
- Line 406: `9. Always update plan file with phase status changes` (in MUST DO list)
  - **Remove this line** (1 line)
- Line 408: `11. **Update partial_progress** after each phase completion` -- Refers to metadata, not plan file. **Keep.**

**Phase-to-stage mapping table**: None

**Total lines to remove**: 26

---

### 6. web-implementation-agent.md (846 lines total)

**Phase Checkpoint Protocol section**: Lines 353-377
- Line 353: `## Phase Checkpoint Protocol` heading
- Lines 354-375: Detailed 6-step protocol (includes git commit bash block with Co-Authored-By trailer)
- Line 376: `---` horizontal rule
- Line 377: blank line
- **Lines to remove**: 353-377 (25 lines)
- **Preceding content**: Line 352 is blank (after Stage 8 return example)
- **Following content**: Line 378 `## Web-Specific Implementation Patterns`

**Inline references**:
- Line 147: `- Phase list with status markers (...)` -- Plan parsing, not checkpoint ref. **Keep.**
- Line 826: `6. Always update plan file with phase status changes` (in MUST DO list)
  - **Remove this line** (1 line)
- Line 831: `11. **Update partial_progress** after each phase completion` -- Refers to metadata. **Keep.**

**Phase-to-stage mapping table**: None

**Total lines to remove**: 26

---

### 7. z3-implementation-agent.md (165 lines total)

**Phase Checkpoint Protocol section**: Lines 124-151
- Line 124: `## Phase Checkpoint Protocol` heading
- Lines 125-150: Detailed 6-step protocol (includes Edit tool examples and git commit bash block)
- Line 151: blank line
- **Lines to remove**: 124-151 (28 lines)
- **Preceding content**: Line 123 is blank (after Stage 8 heading)
- **Following content**: Line 152 `## Critical Requirements`

**Inline references**:
- Line 159: `5. Update plan file phase markers with Edit tool` (in MUST DO list)
  - **Remove this line** (1 line)

**Phase-to-stage mapping table**: None

**Total lines to remove**: 29

---

### 8. founder-implement-agent.md (1640 lines total)

**Phase Checkpoint Protocol section**: Lines 1486-1514
- Line 1486: `## Phase Checkpoint Protocol` heading
- Lines 1487-1512: Detailed 6-step protocol (includes Edit tool examples and git commit bash block)
- Lines 1513-1514: `---` and blank line
- **Lines to remove**: 1486-1515 (30 lines, including blank line before next heading)
- **Preceding content**: Line 1485 is blank (after Phase 5 file mapping table)
- **Following content**: Line 1516 `## Error Handling`

**Inline references**:
- Line 27: `- Edit - Update plan phase markers` (in Allowed Tools section)
  - **Remove this line** (1 line)
- Line 111: `- Phase list with status markers` -- Plan parsing. **Keep.**
- Line 179: `- Phase markers for injected phases are not written back to the plan file (no heading to update)` -- Operational logic for implicit_typst_phase. **Keep** (independent of checkpoint protocol).
- Line 349: `1. Mark phase [IN PROGRESS] in plan file (or skip marker update if implicit_typst_phase=true)` -- Operational phase execution logic embedded in Phase 5 steps. **Keep** (describes what Phase 5 does, not the generic protocol).
- Line 389: `- If implicit_typst_phase=true: skip phase marker update (no heading in plan file)` -- Same operational context. **Keep.**
- Line 1620: `3. Always update phase markers in plan file` (in MUST DO list)
  - **Remove this line** (1 line)
- Line 1639: `8. Leave phase markers in [IN PROGRESS] state` (in MUST NOT list)
  - **Remove this line** (1 line)

**Phase-to-stage mapping table**: None

**Total lines to remove**: 33

---

### 9. deck-builder-agent.md (607 lines total)

**Phase Checkpoint Protocol section**: Lines 490-518
- Line 490: `## Phase Checkpoint Protocol` heading
- Lines 491-516: Detailed 6-step protocol (includes Edit tool examples and git commit bash block)
- Lines 517-518: blank line and `---`
- **Lines to remove**: 489-518 (30 lines, including preceding `---` at line 489)
  - Note: Line 489 is `---` that separates from the preceding section. After removing the checkpoint section, the `---` before `## Error Handling` (at line 519) provides the separator.
- **Preceding content**: Line 488 is blank (after Stage 8 return example)
- **Following content**: Line 519-520: blank + `## Error Handling`

**Inline references**:
- Line 26: `- Edit - Update plan phase markers` (in Allowed Tools section)
  - **Remove this line** (1 line)
- Lines 178-195: "Before each phase" / "After each phase" block with Edit tool examples and git commit instructions
  - This is a 18-line inline duplication of the checkpoint protocol embedded in Stage 3
  - **Lines 178-195 should be removed** (18 lines)

**Phase-to-stage mapping table**: None

**Total lines to remove**: 49

---

### 10. grant-agent.md (637 lines total)

**SPECIAL CASE**: The `## Phase Checkpoint Protocol` heading (line 397) contains not just the protocol content but also `### Stage 6: Write Metadata File` (line 431) and `### Stage 7: Return Brief Text Summary` (line 471). These stages are essential operational content that must be preserved.

**Phase Checkpoint Protocol content only**: Lines 397-429
- Line 397: `## Phase Checkpoint Protocol` heading
- Lines 398-427: Protocol content (detailed variant with Note about assemble workflow)
- Lines 428-429: blank + `---`
- **Lines to remove**: 397-429 (33 lines)

**Stage 6 and Stage 7 restructuring**: Lines 431-517
- These `###` sections are currently orphaned under the Phase Checkpoint Protocol heading
- After removing lines 397-429, they need to be placed correctly
- **Option A**: Promote to `## Stage 6: Write Metadata File` and `## Stage 7: Return Brief Text Summary`
- **Option B**: Move them under `## Execution Flow` (the existing parent for Stages 0-5) as `### Stage 6` and `### Stage 7`
- **Recommended**: Option B -- move under Execution Flow for consistency with other agents

**Inline references**: None outside the main section.

**Phase-to-stage mapping table**: None

**Total lines to remove**: 33 (with restructuring of Stage 6/7)

---

## Summary Table

| # | Agent | Section Lines | Inline Refs to Remove | Total Lines |
|---|-------|--------------|----------------------|-------------|
| 1 | latex-implementation-agent.md | 131-148 (18) | L164 (1) | 19 |
| 2 | typst-implementation-agent.md | 110-127 (18) | L145 (1) | 19 |
| 3 | python-implementation-agent.md | 129-156 (28) | L164 (1) | 29 |
| 4 | nix-implementation-agent.md | 698-720 (23) | None | 23 |
| 5 | neovim-implementation-agent.md | 370-394 (25) | L406 (1) | 26 |
| 6 | web-implementation-agent.md | 353-377 (25) | L826 (1) | 26 |
| 7 | z3-implementation-agent.md | 124-151 (28) | L159 (1) | 29 |
| 8 | founder-implement-agent.md | 1486-1515 (30) | L27, L1620, L1639 (3) | 33 |
| 9 | deck-builder-agent.md | 490-518 (30) | L26, L178-195 (19) | 49 |
| 10 | grant-agent.md | 397-429 (33) | None (but Stage 6/7 restructure) | 33 |
| | **TOTAL** | | | **286** |

## Complexity Classification

**Simple removal** (delete section + 0-1 inline refs):
1. latex-implementation-agent.md
2. typst-implementation-agent.md
3. python-implementation-agent.md
4. nix-implementation-agent.md
5. z3-implementation-agent.md

**Standard removal** (delete section + 1 inline ref in Critical Requirements):
6. neovim-implementation-agent.md
7. web-implementation-agent.md

**Complex removal** (multiple inline refs or restructuring needed):
8. founder-implement-agent.md -- 3 inline refs in Tools + Critical Requirements
9. deck-builder-agent.md -- Tools ref + 18-line inline duplicate in Stage 3
10. grant-agent.md -- Stage 6/7 content must be preserved and moved

## Implementation Recommendations

1. **Process simple agents first** (1-5): Straightforward section deletion + single line removal
2. **Process standard agents next** (6-7): Section deletion + Critical Requirements line
3. **Process complex agents last** (8-10): Require careful handling of additional references
4. **Grant agent requires restructuring**: Move Stage 6/7 content before deleting the heading
5. **Deck-builder requires double removal**: Both the section (lines 490-518) and the inline duplicate (lines 178-195)
6. **Renumber MUST DO/MUST NOT lists** after removing items from Critical Requirements sections
7. **Verify no trailing `---` separators** are left orphaned after removal

## Appendix: Protocol Variants

Three variants of the checkpoint protocol exist across agents:

**Compact (no examples)**: latex, typst
```
1. Read plan file, identify current phase
2. Update phase status to [IN PROGRESS]
3. Execute phase steps
4. Update phase status to [COMPLETED]/[BLOCKED]/[PARTIAL]
5. Git commit
6. Proceed to next phase
```

**Detailed with Edit examples**: python, z3, founder-implement, deck-builder, grant
```
(Same steps but includes Edit tool old_string/new_string examples)
```

**Detailed with Co-Authored-By**: nix, neovim, web, grant
```
(Same steps but git commit includes Co-Authored-By trailer)
```

Note: The Co-Authored-By trailer in these agents is outdated per user preference (feedback_no_coauthored_by.md). This is another reason to remove these sections.
