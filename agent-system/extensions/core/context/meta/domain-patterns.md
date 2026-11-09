# Domain Patterns for System Generation

**Purpose**: Common domain patterns and their typical agent/context structures for use by meta-builder-agent when creating extensions or evaluating system architecture.
**Last Updated**: 2026-04-19

---

## Development Domain Pattern

**Characteristics**: Code generation, testing, build, deployment workflows

### Typical Use Cases

- Code generation and refactoring
- Test authoring and execution
- Build validation and type checking
- Code review and quality assurance

### Recommended Agent Structure

```
{domain}-research-agent     (domain research)
{domain}-implementation-agent (domain implementation)
```

Agents are registered in the extension manifest under `provides.agents` and routed via `routing.research`, `routing.plan`, and `routing.implement`.

### Context Organization

```
extensions/{ext}/context/
  domain/          # Core domain concepts
  patterns/        # Common implementation patterns
  standards/       # Coding conventions
  tools/           # Tool-specific guides
```

### Integration Points

- Version control (git)
- Build systems (make, cmake, cargo, npm)
- Test frameworks (pytest, jest, busted)
- Language servers and linters

---

## Extension Domain Pattern (Template)

**Characteristics**: Domain-specific tooling, workflows, and conventions provided by an extension

### When to Use

Create a new extension when a domain requires:
- Dedicated research and implementation agents
- Domain-specific context files (standards, patterns, tools)
- Custom routing for the research, plan, and implement phases
- Domain-specific rules auto-applied by file path

### Manifest Structure

Each extension declares its capabilities in `manifest.json`:

```json
{
  "name": "{ext}",
  "version": "1.0.0",
  "description": "Brief description",
  "task_type": "{ext}",
  "dependencies": ["core"],
  "provides": {
    "agents": ["{ext}-research-agent.md", "{ext}-implementation-agent.md"],
    "skills": ["skill-{ext}-research", "skill-{ext}-implementation"],
    "commands": [],
    "rules": ["{ext}-rules.md"],
    "context": ["project/{ext}"],
    "scripts": [],
    "hooks": []
  },
  "routing": {
    "research": { "{ext}": "skill-{ext}-research" },
    "implement": { "{ext}": "skill-{ext}-implementation" }
  }
}
```

### Context Organization

```
extensions/{ext}/
  manifest.json
  context/
    project/{ext}/
      domain/       # Core domain concepts
      patterns/     # Common implementation patterns
      standards/    # Coding conventions
      tools/        # Tool-specific guides
  agents/           # Agent definitions
  skills/           # Skill definitions
  rules/            # Auto-applied rules
```

### Integration Points

- Domain-specific build/test tools
- Language servers and linters
- Package managers and registries
- Domain-specific documentation sources

See `.claude/extensions/*/manifest.json` for concrete examples (nvim, nix, core).

---

## Domain Type Detection

### Development Indicators

- Keywords: code, test, build, deploy, refactor, review
- Tools: git, make, npm, cargo, pytest, jest
- Artifacts: source files, test files, build configs

### Extension Domain Indicators

Extension-specific indicators are defined in the extension's manifest and context. Each extension declares its own task_type, routing entries, and context files. See `.claude/extensions/*/manifest.json`.

---

## Sizing Guidelines

| Dimension | Simple | Moderate | Complex |
|-----------|--------|----------|---------|
| Agents | 2 (research + impl) | 3-4 | 5+ |
| Task types | 1 | Multiple / sub-routing | Many compound types |
| Context files | 1-3 | 4-7 | 8+ |
| Example | nvim extension | formal verification | enterprise platform |

---

## Related Resources

- **Meta Guide**: `.claude/context/meta/meta-guide.md`
- **Extension Development**: `.claude/context/guides/extension-development.md`
- **Context Revision Guide**: `.claude/context/meta/context-revision-guide.md`
