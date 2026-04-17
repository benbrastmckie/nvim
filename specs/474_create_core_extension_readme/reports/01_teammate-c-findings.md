# Teammate C Findings: Critical Gaps in Task 474

## Key Findings

### 1. The task is incomplete: there are TWO failures, not one

Running `check-extension-docs.sh` against the current state reveals:

```
[core]
  FAIL: README.md missing (.claude/extensions/core//README.md)
  FAIL: manifest declares 16 skill(s) but has no routing block
```

The task description only mentions the missing README. It does not mention the routing block
failure. The README will not fully fix the CI check -- after creating the README, the script
will still fail on core unless either:

a) The manifest gets a `routing` block added, or
b) The `check_routing_block()` function in `check-extension-docs.sh` is modified to exempt
   core (or any non-domain extension without a `task_type` field)

**Evidence**: Every other extension with skills has a `routing` block. Only `core` does not.
This is because core's skills serve the agent system infrastructure, not a user-facing task
type. The routing check in the script (`if skill_count > 0, verify routing exists`) does not
distinguish between domain-routing skills and infrastructure skills.

**Impact**: If the implementer only creates a README and does nothing about the routing check,
the script will still exit with code 1. The task goal ("pass `check-extension-docs.sh`") will
not be achieved.

**Recommended resolution**: The fix has two valid options:
- Add an exemption to `check_routing_block()` for extensions with no `task_type` field
  (since `task_type` is absent from core's manifest, unlike all domain extensions), OR
- Add a `routing` block to core's manifest that maps the infrastructure task types
  (`general`, `meta`, `markdown`) to their skills

The exemption approach is architecturally cleaner because it encodes in the validator the
distinction between domain extensions and infrastructure payloads.

### 2. check-extension-docs.sh checks README content, not just existence

The script's `check_readme_vs_manifest()` function verifies that every command listed in
`manifest.json` is mentioned by name in `README.md`. For core, this means all 14 commands
must appear in the README:

```
/errors, /fix-it, /implement, /merge, /meta, /plan, /refresh,
/research, /review, /revise, /spawn, /tag, /task, /todo
```

A README that only documents core's role conceptually, without listing all these commands,
will produce 14 additional failures. The README must mention each command by its slash name
(e.g., `/implement` not just "implement").

**Confidence: High** -- the check is unambiguous in the source at line `grep -q "/$cmd_name"`.

### 3. The README audience is ambiguous

The task says to document core's "role as foundational system payload." But who reads this?

- **Extension developers** who want to understand how extensions relate to core
- **Agents** performing `/meta` tasks who need to know what core provides
- **Human users** running `/meta` to understand system structure
- **The check-extension-docs.sh script** (functionally, it needs command mentions)

The `nvim` extension README (the most analogous complex extension) has ~300 lines with deep
Lua code examples. The `documentation-standards.md` says docs/ READMEs are for humans, but
extension READMEs live in `extensions/*/` which is outside `docs/`. The template
`extension-readme-template.md` targets domain extensions that expose a `task_type` -- core
has no `task_type` and no user-facing routing.

**Risk**: Using the standard extension README template without adaptation will produce content
that doesn't fit core's nature. Sections like "Language Routing" and "Workflow" make no sense
for core.

### 4. README vs EXTENSION.md duplication risk

`EXTENSION.md` for core already documents:
- What it provides (counts per category)
- Key capabilities
- That it is "always active" and "foundational"
- Dependencies (none)

A README that documents the same things will violate the documentation-standards.md rule:
"Do not duplicate information across files."

The README must add value beyond EXTENSION.md. Valid additions:
- Architecture tree showing the directory structure
- The routing block absence explanation (which EXTENSION.md omits)
- How core differs from domain extensions (it is always loaded, has no task_type, deploys to
  all `.claude/` subdirectories rather than a domain-scoped subset)
- A reference to EXTENSION.md rather than repeating its content

### 5. Core has special loader behavior that the README should document

From `manifest.lua` (line 263-274), core has a dedicated `get_core_provides()` function and
a `build_allow_list()` function. The loader uses core's provides as a whitelist to filter
what files get synced in the "Load Core" operation. No other extension has this role.

From `extension-system.md` (line 336): "Core index entries loaded via core's merge_targets.index
(same as other extensions)" -- the context index loading is the same, but the sync behavior
is not.

The README should note that core participates in the Lua extension system as an infrastructure
provider, not a domain extension, and that the loader uses core's manifest as the sync allow-list.

### 6. Stale content risk: counts will drift

`EXTENSION.md` includes a table with exact counts (8 agents, 14 commands, 6 rules, 16 skills,
27 scripts, 11 hooks, 15 dirs context). These counts are already in EXTENSION.md and will
require updating every time new files are added to core.

If the README duplicates these counts, it doubles the maintenance surface. The README should
either:
- Cross-reference EXTENSION.md for the count table, or
- Omit counts entirely and describe categories qualitatively

Stable content (what will not drift): the conceptual distinction between core and domain
extensions, the absence of `task_type`, the reason routing block is absent.

---

## Recommended Approach

1. **Fix the routing block failure first** -- determine which option the implementer should
   take (script exemption vs manifest change) before writing the README. This is a blocker
   that the task description missed.

2. **Ensure all 14 command names appear in the README** -- even if just in a table or list.
   The script does a literal `grep -q "/$cmd_name"` check.

3. **Differentiate README from EXTENSION.md** -- do not re-list counts. Cross-reference
   EXTENSION.md for the provides inventory. Focus the README on:
   - What makes core different from domain extensions (no `task_type`, always loaded,
     deploy scope covers all of `.claude/`)
   - Why routing block is absent
   - The provides categories with links or brief descriptions (not counts)
   - Commands list (required by check script)

4. **Keep it shorter than the nvim README** -- core has no code patterns, no domain-specific
   workflow, no external tools. The template's "simple extension" track (~120 lines) is more
   appropriate, but modified to omit language routing entirely and add an infrastructure
   section.

---

## Evidence / Examples

### check-extension-docs.sh routing check (lines 64-74 of script):

```bash
check_routing_block() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"
  local skill_count
  skill_count=$(jq -r '.provides.skills | length' "$manifest" 2>/dev/null)
  if [[ "$skill_count" -gt 0 ]]; then
    local has_routing
    has_routing=$(jq -r 'has("routing")' "$manifest" 2>/dev/null)
    if [[ "$has_routing" == "false" ]]; then
      fail "manifest declares $skill_count skill(s) but has no routing block"
    fi
  fi
}
```

This check has no core-specific exemption.

### All other extensions with skills have routing:

| Extension | Skills | Has routing |
|-----------|--------|-------------|
| core | 16 | No (FAIL) |
| python | 2 | Yes |
| nvim | 2 | Yes |
| nix | 2 | Yes |
| founder | 15 | Yes |
| memory | 1 | Yes |
| (all others) | 2-5 | Yes |

### manifest.json difference: core has no `task_type` field

Domain extensions have `"task_type": "latex"` (etc.). Core's manifest has no `task_type`
field at all. This is the cleanest discriminator for a script exemption.

---

## Confidence Level

| Finding | Confidence |
|---------|------------|
| Second check-script failure (routing block) is real | High -- verified by running the script |
| All 14 commands must appear in README | High -- verified by reading script source |
| README-EXTENSION.md duplication risk | High -- EXTENSION.md already covers the territory |
| Core has special loader role (allow-list) | Medium -- inferred from manifest.lua source; could be more loader-specific context |
| Routing exemption is the cleaner fix | Medium -- design judgment call, not a factual claim |
