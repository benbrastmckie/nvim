# Teammate C Findings: Skills, Agents, Commands, and Box-Drawing Audit

**Task**: 349 - Review and update .claude/ agent system documentation for correctness and consistency
**Focus**: Skills/Agents/Commands cross-reference + Unicode box-drawing consistency
**Date**: 2026-04-01

---

## Key Findings

### Skills/Agents/Commands Cross-Reference

**1. skill-orchestrator and skill-git-workflow are undocumented in both mapping tables**

The Skill-to-Agent Mapping table in `CLAUDE.md` (lines 162-175) and the Skills table in `README.md` (lines 87-91) both omit two skills that exist in `/home/benjamin/.config/nvim/.claude/skills/`:

- `skill-orchestrator` - Routes commands to appropriate workflows based on task language and status. Invoked by `/task`, `/research`, `/plan`, `/implement` commands. Has no agent (direct execution).
- `skill-git-workflow` - Creates scoped git commits for task operations. Has no agent (direct execution). Referenced implicitly via `@.claude/rules/git-workflow.md` but never listed as a skill.

These skills exist and are active but are invisible to documentation readers.

**Confidence**: High (verified by directory listing and SKILL.md frontmatter)

---

**2. README.md skills table is significantly truncated**

The Skills table in `README.md` (lines 87-91) lists only 5 skills:
```
skill-researcher, skill-planner, skill-implementer, skill-meta, skill-status-sync
```

The full system has 15 skills. Missing from README.md:
- skill-refresh, skill-todo, skill-tag (direct execution skills)
- skill-team-research, skill-team-plan, skill-team-implement (team mode skills)
- skill-spawn (spawn-agent)
- skill-fix-it, skill-git-workflow, skill-orchestrator

`CLAUDE.md` is more complete (12 of 15 skills), but README.md should at minimum reference or link to the complete list.

**Confidence**: High

---

**3. /merge command exists but is not documented in CLAUDE.md or README.md**

`/home/benjamin/.config/nvim/.claude/commands/merge.md` exists and is fully functional (creates GitHub PRs or GitLab MRs). It is not listed in:
- CLAUDE.md Command Reference table (lines 83-98)
- README.md Quick Reference table (lines 13-27)
- `docs/architecture/system-overview.md` commands table (lines 78-89)
- `docs/guides/user-guide.md`

**Confidence**: High

---

**4. spawn-agent is missing from agents/README.md**

`/home/benjamin/.config/nvim/.claude/agents/README.md` lists 5 agents in its table but omits `spawn-agent.md` which exists in the same directory. The CLAUDE.md agents table correctly includes spawn-agent.

**Confidence**: High

---

**5. docs/guides/tts-stt-integration.md exists but is not referenced in docs/README.md**

The file `/home/benjamin/.config/nvim/.claude/docs/guides/tts-stt-integration.md` exists in the guides directory but does not appear in `docs/README.md`'s documentation map or guides section. The `neovim-integration.md` guide is referenced and may cover some overlap, but the TTS/STT file appears to be standalone content that is orphaned from the index.

**Confidence**: High

---

**6. system-overview.md commands table missing /fix-it, /refresh, /tag, /spawn, /merge commands**

`docs/architecture/system-overview.md` commands table (lines 78-89) lists 9 commands but omits:
- `/fix-it`
- `/refresh`
- `/tag`
- `/spawn`
- `/merge`

**Confidence**: High

---

**7. system-overview.md skills table shows neovim extension skills as core**

`docs/architecture/system-overview.md` Skills table (lines 101-108) lists `skill-neovim-research` and `skill-neovim-implementation` as key skills without noting they are extension skills (only available when neovim extension is loaded). Core skills like skill-meta, skill-status-sync, skill-refresh, skill-todo, skill-spawn are not listed. This gives a misleading picture of the core system.

**Confidence**: High

---

### Unicode Box-Drawing Audit

**8. ASCII box-drawing used in README.md architecture diagram (lines 40-60)**

`/home/benjamin/.config/nvim/.claude/README.md` uses ASCII `+---` box-drawing in its main architecture diagram (the three-layer Commands/Skills/Agents diagram). Per the box-drawing guide at `.claude/extensions/nvim/context/project/neovim/standards/box-drawing-guide.md`, Unicode box-drawing characters (`┌─┐│└┘`) should be used instead.

Affected lines in README.md: 40, 44, 48, 52, 56, 60

**Confidence**: High (box-drawing guide is explicit: use Unicode for professional diagrams)

---

**9. ASCII box-drawing in docs/architecture/system-overview.md**

Same issue as above. The three-layer architecture diagram in `system-overview.md` (lines 18, 26, 30, 38, 42, 50, 54, 61) uses `+-----+` ASCII boxes. This is the same diagram reproduced in two places, both with ASCII style.

**Confidence**: High

---

**10. ASCII box-drawing in docs/architecture/extension-system.md**

The extension system diagram (lines 15, 24, 28) uses `+----+` ASCII boxes to show the Extension Source -> Target Project copy flow.

**Confidence**: High

---

**11. ASCII box-drawing in context/reference/workflow-diagrams.md and context/patterns/team-orchestration.md**

`workflow-diagrams.md` uses `+---------+` boxes throughout all workflow diagrams (research, planning, implementation, etc.). `team-orchestration.md` uses `+--------+` boxes for the wave execution model diagram. These are context files, not user-facing docs, but consistency with the box-drawing standard still applies.

**Confidence**: Medium (context files may be intentionally minimal/ASCII for agent readability)

---

**12. ASCII boxes in docs/reference/standards/multi-task-creation-standard.md and agents/meta-builder-agent.md are intentional DAG examples**

The `+----+----+` pattern in these files (lines 247, 252 in multi-task-creation-standard.md; lines 1033, 1039, 1191, 1196 in meta-builder-agent.md) represents a DAG dependency graph visualization that agents generate as output. These are code examples of generated output format, not documentation boxes. Converting them to Unicode would be incorrect — the agent code generates these exact ASCII patterns.

**Confidence**: High (these are generated output examples, not decorative boxes)

---

### Documentation Standards

**13. docs/README.md documentation map is accurate and complete for indexed files**

All files listed in the `docs/README.md` documentation map were verified to exist. No dead links found in the primary docs/README.md index.

**Confidence**: High

---

**14. Reference standards directory is missing a skill-template**

`docs/templates/` contains `command-template.md` and `agent-template.md` but no `skill-template.md`. The `docs/guides/creating-skills.md` guide exists, but the templates directory doesn't have a parallel template for skills.

**Confidence**: Medium (may be intentional given skills are thin wrappers)

---

## Recommended Changes

### Priority 1: Correct Documentation Omissions

1. **Add /merge to CLAUDE.md Command Reference table** (after `/spawn`):
   ```
   | `/merge` | `/merge [--draft] [--assignee USER]` | Create PR/MR for current branch |
   ```
   Same addition needed in `README.md` Quick Reference table.

2. **Add skill-orchestrator and skill-git-workflow to CLAUDE.md Skill-to-Agent Mapping table**:
   ```
   | skill-orchestrator | (direct execution) | - | Route commands by task language/status |
   | skill-git-workflow | (direct execution) | - | Create scoped git commits for tasks |
   ```

3. **Add spawn-agent to agents/README.md table**:
   Add row: `| spawn-agent.md | Blocker analysis and task decomposition |`

4. **Add tts-stt-integration.md to docs/README.md**:
   In the Getting Started section, add:
   `- [TTS/STT Integration](guides/tts-stt-integration.md) - Voice input and audio notification setup`
   (or merge into the neovim-integration.md reference)

5. **Update system-overview.md commands table** to add `/fix-it`, `/refresh`, `/tag`, `/spawn`, `/merge`.

6. **Update system-overview.md skills table** to list core skills instead of extension skills as primary examples.

### Priority 2: Unicode Box-Drawing

7. **Convert README.md architecture diagram** (lines 35-62) from ASCII `+---+` to Unicode `┌───┐` style per box-drawing guide. This is the most user-visible diagram.

8. **Convert docs/architecture/system-overview.md diagrams** (same three-layer diagram, same fix needed).

9. **Convert docs/architecture/extension-system.md diagram** (lines 15-28).

10. **Decide on context file policy**: `workflow-diagrams.md` and `team-orchestration.md` use ASCII boxes. If these files are primarily read by agents (not humans), ASCII may be acceptable for token efficiency. If they are also human-readable docs, convert to Unicode.

### Priority 3: Minor Improvements

11. **Expand README.md skills table** to include all 15 skills or add a note pointing to CLAUDE.md for the complete list.

12. **Consider adding skill-template.md** to `docs/templates/` for consistency with command-template.md and agent-template.md.

---

## Summary Table

| # | Finding | File(s) | Severity | Confidence |
|---|---------|---------|----------|------------|
| 1 | skill-orchestrator and skill-git-workflow missing from mapping tables | CLAUDE.md, README.md | Medium | High |
| 2 | README.md skills table truncated (5 of 15 skills) | README.md | Low | High |
| 3 | /merge command not documented | CLAUDE.md, README.md, system-overview.md | Medium | High |
| 4 | spawn-agent missing from agents/README.md | agents/README.md | Low | High |
| 5 | tts-stt-integration.md not in docs/README.md index | docs/README.md | Low | High |
| 6 | system-overview.md commands table incomplete | docs/architecture/system-overview.md | Low | High |
| 7 | system-overview.md shows extension skills as core | docs/architecture/system-overview.md | Medium | High |
| 8 | ASCII boxes in README.md architecture diagram | README.md | Low | High |
| 9 | ASCII boxes in system-overview.md | docs/architecture/system-overview.md | Low | High |
| 10 | ASCII boxes in extension-system.md | docs/architecture/extension-system.md | Low | High |
| 11 | ASCII boxes in context files (workflow-diagrams.md, team-orchestration.md) | context/ | Low | Medium |
| 12 | DAG examples in meta-builder-agent.md are intentional ASCII | agents/meta-builder-agent.md | N/A (no change) | High |
| 13 | docs/README.md index is accurate | docs/README.md | N/A (no change) | High |
| 14 | No skill-template.md in docs/templates/ | docs/templates/ | Low | Medium |
