# Research Report: Task #486

**Task**: Align skill-meta and agent frontmatter/references
**Date**: 2026-04-19
**Mode**: Team Research (4 teammates)

## Summary

All four proposed fixes are confirmed correct by direct file inspection. The task is well-scoped as "Small" and directly advances the ROADMAP "Agent frontmatter validation" item. Two significant ancillary findings emerged: (1) meta-builder-agent is the only agent still using v1 console JSON return instead of v2 file-based protocol, and (2) `context: fork` is documented as required for thin-wrapper skills but no deployed skill currently uses it -- its runtime behavior is unverified.

## Key Findings

### Primary Approach (from Teammate A)

Four discrete fixes across 4 files (2 extension sources + 2 deployed copies):

**Fix 1 -- skill-meta frontmatter** (both copies):
- Add `context: fork` and `agent: meta-builder-agent` fields
- Remove commented-out "Original context" and "Original tools" blocks (lines 5-11)
- The `allowed-tools` question is addressed under Conflicts below

**Fix 2 -- stale `subagent-return.md` in skill-meta** (both copies):
- Line 109: "Validate return matches `subagent-return.md` schema" -> `return-metadata-file.md`
- Line 123: "See `.claude/context/formats/subagent-return.md`" -> `return-metadata-file.md`

**Fix 3 -- stale `subagent-return.md` in meta-builder-agent** (both copies):
- Mode-Context Matrix table row (line 93): `subagent-return.md` -> `return-metadata-file.md`
- The "Always Load" section (line 62) already correctly references `return-metadata-file.md`

**Fix 4 -- hardcoded `latex` in DetectDomainType** (both copies):
- Remove the line: `- Keywords: "latex", "document", "pdf", "tex" -> task_type = "latex"`
- Keywords fall through to `general`, which is appropriate since `/meta` creates system tasks

### Alternative Approaches (from Teammate B)

Cross-referencing other skills revealed a deeper issue beyond the 4 fixes:

| File | Frontmatter Clean | v2 Return Protocol | Postflight Complete |
|------|:-:|:-:|:-:|
| skill-researcher | No (legacy comments) | Yes | Yes |
| skill-planner | No (legacy comments) | Yes | Yes |
| skill-implementer | Yes | Yes | Yes |
| skill-reviser | Yes | Yes | Yes |
| **skill-meta** | **No** | **No (v1)** | **No (missing stages)** |
| **meta-builder-agent** | N/A | **No (v1 JSON return)** | N/A |

**Critical finding**: meta-builder-agent is the only agent still using v1 console JSON return (Stage 5 instructs "Return ONLY valid JSON"). All other agents write `.return-meta.json` and return brief text. skill-meta correspondingly lacks standard postflight stages (no metadata file read, no artifact linking via skill, git commit happens inside agent).

This v1-to-v2 migration is OUT OF SCOPE for task 486 but should be noted for task 485 or a follow-up.

### Gaps and Shortcomings (from Critic)

1. **`context: fork` runtime behavior is unverified**: No deployed skill currently uses this field. It may be purely documentary or may have runtime enforcement (context suppression, tool restriction). If it restricts tools, adding it could break skill-meta's postflight git commit. **Recommendation**: Add it as documented but note this risk for the implementer to verify.

2. **`subagent-return.md` is NOT fully deprecated**: It still defines the JSON schema written to `.return-meta.json` files. The two files are complementary: `subagent-return.md` = schema definition, `return-metadata-file.md` = protocol definition. The specific references being changed ARE stale (they point to the v1 console pattern), but a blanket "replace all subagent-return.md references" would be wrong.

3. **`agent:` field absence makes body text inaccurate**: skill-meta line 82 says "The `agent` field in this skill's frontmatter specifies the target: `meta-builder-agent`" but no such field exists. Adding it fixes this existing lie.

4. **`latex` is the ONLY extension domain to remove**: The `meta` and `general` branches are core types. After removal, latex keywords fall to `general`, which is correct for `/meta` context.

### Strategic Horizons (from Teammate D)

1. **Roadmap alignment**: Task 486 directly advances "Agent frontmatter validation" -- making skill-meta compliant before the lint script is written.

2. **Task 485 interaction**: Clean separation. 486 fixes implementation files, 485 rewrites the guide document. Independent and complementary.

3. **Memory integration gap**: skill-researcher, skill-planner, and skill-implementer all call `memory-retrieve.sh`; skill-meta does not. Out of scope for 486 but noted as a roadmap opportunity.

4. **`context: fork` system-wide gap**: The creating-skills guide documents it as "critical for token efficiency" but no skill uses it. Either aspirational documentation or a missed step in the thin-wrapper refactoring. Task 486 should add it as specified; a follow-up should audit the field's actual runtime behavior.

## Synthesis

### Conflicts Resolved

**Conflict 1: `allowed-tools` -- reduce to `Task` only vs keep current set**
- Teammate A: Reduce to `Task` per thin-wrapper template
- Teammate C: skill-meta needs `Bash` for postflight git commit; `context: fork` + reduced tools could break postflight
- **Resolution**: Keep `allowed-tools: Task, Bash, Edit, Read, Write` as-is. The skill's internal postflight (git commit) uses `Bash`, and the `allowed-tools` reduction is a separate concern from the 4 fixes described in the task. Reducing tools is not listed as a task objective and introduces unnecessary risk.

**Conflict 2: Replace all `subagent-return.md` references vs be surgical**
- Teammate A: Replace all references
- Teammate C: `subagent-return.md` is not fully deprecated; be surgical
- **Resolution**: Replace the 3 specific stale references (skill-meta lines 109 and 123, agent line 93). These all point to the v1 console pattern which is genuinely superseded. Do not sweep other files.

### Gaps Identified

1. **v1-to-v2 protocol migration** for meta-builder-agent and skill-meta is a larger task beyond 486's scope. Should be tracked separately (possibly folded into task 485 or a new task).
2. **Legacy frontmatter comments** exist in skill-researcher and skill-planner too, not just skill-meta. Task 486 should clean skill-meta's; others are separate.
3. **Memory integration** for skill-meta is a legitimate enhancement but out of scope.

### Recommendations

1. **Proceed with all 4 fixes as described** -- they are all confirmed correct
2. **Do NOT reduce `allowed-tools`** -- keep current set to avoid postflight risk
3. **Do NOT expand scope** to v1-to-v2 migration, memory integration, or other skills
4. **Edit extension source copies first** (`.claude/extensions/core/`), then mirror to deployed copies
5. **Note for implementer**: Verify `context: fork` has no adverse runtime effects after adding it

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary analysis | completed | high |
| B | Cross-references and patterns | completed | high |
| C | Critic (gaps and risks) | completed | high |
| D | Strategic horizons | completed | high |

## References

- `.claude/context/patterns/thin-wrapper-skill.md` -- canonical frontmatter template
- `.claude/context/formats/return-metadata-file.md` -- v2 file-based protocol (current)
- `.claude/context/formats/subagent-return.md` -- v1 schema definition (still active for schema)
- `specs/ROADMAP.md` -- "Agent frontmatter validation" item
- `.claude/context/formats/frontmatter.md` -- frontmatter field specification
