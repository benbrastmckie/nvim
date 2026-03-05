# Research Report: Task #140

**Task**: OC_140 - Document progressive disclosure best practices in context-loading guide
**Date**: 2026-03-06
**Language**: meta
**Focus**: Documentation of progressive context disclosure patterns

## Summary

This task updates the context-loading-best-practices.md documentation with findings and recommendations from OC_137. The research identified multiple patterns for optimizing context injection: stage-progressive loading, conditional context injection, discovery-layer pattern, and context budget guidelines.

## Background

OC_137 research-003.md identified 5 opportunities for improving progressive disclosure:
1. Conditional status-marker injection (verified - already optimized)
2. Stage-progressive loading (demonstrated in OC_139)
3. Discovery-layer pattern for agents (implemented in OC_137 Phase 5)
4. Context budget enforcement (guidelines needed)
5. Context injection to revise flow (implemented in OC_137 Phase 4)

## Documentation Needed

### 1. Stage-Progressive Loading Pattern
Document the tiered loading approach demonstrated in OC_139:
- Load minimal context for validation (Stage 1)
- Load format specs only when needed (Stage 3)
- Benefits: 40-50% context reduction

### 2. Conditional Context Injection
Document the pattern verified in OC_137 Phase 6:
- Only inject context that will be used
- Example: status-markers.md only for transition skills
- Guidelines for deciding what to inject

### 3. Discovery-Layer Pattern
Document the pattern implemented in OC_137 Phase 5:
- Give agents awareness without bloat
- Context Discovery Index vs "Always Load"
- When to load which context files

### 4. Context Budget Guidelines
Add measurable guidelines:
- Keep skill context injection under 800 lines
- Target <10% context window for routing
- Reserve 60-80% for execution

### 5. Troubleshooting Section
Add debugging guidance:
- How to verify context is being loaded correctly
- How to check which template source was used
- Common context injection failures

## Files to Modify

- `.opencode/docs/guides/context-loading-best-practices.md`

## Next Steps

Run `/plan OC_140` to create implementation plan.
