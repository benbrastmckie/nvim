# Generation Guidelines

**Version**: 1.0
**Created**: 2026-01-19
**Purpose**: Templates and guardrails for generating new components

---

## Command Generation

Commands should:

- Use YAML frontmatter with description and allowed tools
- Validate task existence and status
- Delegate to a skill (one invocation)
- Output standardized response

Reference: `@.opencode/context/core/formats/command-structure.md`

---

## Skill Generation

Skills should:

- Follow thin-wrapper pattern
- Own preflight → delegate → postflight
- Use Task tool (not Skill tool)
- Return structured JSON

Reference: `@.opencode/context/core/patterns/thin-wrapper-skill.md`

---

## Agent Generation

Agents should:

- Load context lazily
- Create artifacts in specs/{N}_{slug}
- Return structured JSON (subagent-return.md)

Reference: `@.opencode/context/core/formats/subagent-return.md`

---

## Related Documentation

- `@.opencode/context/core/architecture/system-overview.md`
- `@.opencode/context/core/architecture/component-checklist.md`
- `@.opencode/context/core/patterns/anti-stop-patterns.md`
