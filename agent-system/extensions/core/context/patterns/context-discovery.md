# Context Discovery Patterns

**Created**: 2026-02-24
**Updated**: 2026-03-30
**Purpose**: jq query patterns for three-layer context discovery

## Three-Layer Architecture

Context is discovered from three independent sources, loaded in parallel:

| Layer | Index | Path Prefix | Description |
|-------|-------|-------------|-------------|
| Agent context | `.claude/context/index.json` | `.claude/context/` | Core patterns + extension context (merged by loader) |
| Project context | `.context/index.json` | `.context/` | User-defined project conventions (may be empty) |
| Project memory | `.memory/` (no index) | `.memory/` | Learned facts, loaded directly as files |

Extension context is merged INTO `.claude/context/index.json` by the extension loader. There is no separate extension query.

## Rule Loading: Two Independent Paths

`.claude/rules/*.md` files are loaded via two mechanisms that operate independently of each
other and of the three-layer context-index architecture above:

1. **Harness-native `paths:` frontmatter glob**: Claude Code auto-loads a rule file into session
   context whenever a touched/referenced path matches its own YAML `paths:` frontmatter glob
   (e.g. `paths: "**/*"` on `pr-prohibition.md` matches every path; `paths: specs/**/*` on
   `state-management.md` matches only `specs/` paths). This is a harness mechanism, unrelated to
   `.claude/context/index.json` and unrelated to any `@`-import list.
2. **`CLAUDE.md` "Rules References" list**: the curated subset of rules listed under CLAUDE.md's
   "Rules References" section. These entries are plain backticked paths (documentation pointers),
   deliberately NOT resolving `@`-imports — see the "Eager vs. Lazy Loading Channels" section of
   `architecture/context-layers.md` for the full channel inventory, the `@`-resolution semantics
   (directory-relative; broken refs are silently inert), and the
   no-volatile-files-in-eager-prefix constraint.

A rule file can be live via path 1 alone, with no entry in path 2's list at all — this is common
and not a defect. **A dead-code audit MUST check a rule file's own `paths:` frontmatter before
declaring it "unwired" or "dead" on the basis of absence from the `@`-import list.** Concluding
a rule is dead purely from CLAUDE.md's list omitting it is a category error: the list documents
a curated subset, not the sole loading path, and this exact error has previously produced a
false "dead rule" finding in a codebase review.

## Layer 1: Agent Context

All paths in `.claude/context/index.json` are relative to `.claude/context/`.

### Query by Agent Name

```bash
jq -r '.entries[] |
  select(.load_when.agents[]? == "planner-agent") |
  .path' .claude/context/index.json
```

### Query by Language

```bash
jq -r '.entries[] |
  select(.load_when.task_types[]? == "meta") |
  .path' .claude/context/index.json
```

### Query by Command

```bash
jq -r '.entries[] |
  select(.load_when.commands[]? == "/implement") |
  .path' .claude/context/index.json
```

### Query by Domain

```bash
jq -r '.entries[] |
  select(.domain == "core") |
  .path' .claude/context/index.json
```

### Query Always-Load Files

```bash
jq -r '.entries[] |
  select(.load_when.always == true) |
  .path' .claude/context/index.json
```

### Exclude Deprecated Files

```bash
jq -r '.entries[] |
  select(.deprecated == true | not) |
  select(.load_when.agents[]? == "planner-agent") |
  .path' .claude/context/index.json
```

### Query by Topic or Keyword

```bash
# By topic
jq -r '.entries[] |
  select(.topics[]? == "delegation") |
  .path' .claude/context/index.json

# By keyword (case-insensitive)
jq -r '.entries[] |
  select(.keywords[]? | test("jq"; "i")) |
  .path' .claude/context/index.json
```

## Layer 2: Project Context

All paths in `.context/index.json` are relative to `.context/`. This layer may have no entries initially.

```bash
# Query project context (safe if file missing or entries empty)
jq -r '.entries[] | .path' .context/index.json 2>/dev/null
```

## Layer 3: Project Memory

`.memory/` files are loaded directly -- no index needed.

```bash
# List all memory files
find .memory -name "*.md" -type f 2>/dev/null
```

## Multi-Layer Discovery

### Full Context for an Agent

Query all three layers to build a complete context set:

```bash
# Layer 1: Agent context (core + extensions)
jq -r --arg a "planner-agent" '.entries[] |
  select(.load_when.agents[]? == $a) |
  ".claude/context/" + .path' .claude/context/index.json

# Layer 2: Project context (if any)
if [ -f .context/index.json ]; then
  jq -r '.entries[] | ".context/" + .path' .context/index.json
fi

# Layer 3: Project memory (independent)
if [ -d .memory ]; then
  find .memory -name "*.md" -type f
fi
```

## Budget-Aware Loading

### Get Line Counts

```bash
jq -r '.entries[] |
  select(.load_when.agents[]? == "planner-agent") |
  "\(.line_count)\t\(.path)"' .claude/context/index.json
```

### Filter by Line Count Budget

```bash
jq -r '.entries[] |
  select(.load_when.task_types[]? == "meta") |
  select(.line_count < 300) |
  .path' .claude/context/index.json
```

### Calculate Total Context Budget

```bash
jq '[.entries[] |
  select(.load_when.agents[]? == "planner-agent") |
  .line_count] | add' .claude/context/index.json
```

### `line_count`'s real consumer

The three queries above are not merely descriptive: `validate-context-budgets.sh` computes
`total_tokens = sum(line_count) * 8` per agent and fails the gate on overage against per-agent
hard caps (e.g. 8000 for `general-research-agent`, 15000 for `meta-builder-agent`/
`planner-agent`). Accuracy of `line_count` therefore has a real downstream effect, not just a
cosmetic one. `line_count` is kept exact (matching `wc -l` of each entry's own source file, in
every extension's `agent-system/extensions/*/index-entries.json`, loaded or not) by
`generate-context-line-counts.sh` (`--check` to report drift, `--write` to correct it), and
`check-extension-docs.sh`'s Rule R re-checks this on every `verify-deploy.sh` run so it cannot
silently rot again. Note that `validate-context-budgets.sh` itself is **not** currently wired
into `verify-deploy.sh` or any other automated gate — it remains a manual/CI-invoked script, and
wiring it in is a separate, not-yet-scheduled follow-up.

## Combined Queries

### Adaptive Context Loading (Recommended Pattern)

Load context that matches any active dimension - always, agent, language, or command:

```bash
# Full combined query for adaptive context loading
jq -r --arg agent "general-implementation-agent" \
      --arg task_type "meta" \
      --arg cmd "/implement" '
  .entries[] |
  select(
    (.load_when.always == true) or
    any(.load_when.agents[]?; . == $agent) or
    any(.load_when.task_types[]?; . == $task_type) or
    any(.load_when.commands[]?; . == $cmd)
  ) |
  select(.deprecated == true | not) |
  .path' .claude/context/index.json
```

**Priority Order**:
1. `always: true` - Universal files loaded for all contexts
2. `agents[]?` - Agent-specific context
3. `task_types[]?` - Task-type-specific context
4. `commands[]?` - Command-specific context

**Empty Array Semantics**:
- Empty arrays `[]` mean "never match this dimension"
- To load unconditionally, use `"always": true`
- Entries must match at least one dimension to be discoverable

### Agent + Task Type

```bash
jq -r '.entries[] |
  select(
    any(.load_when.agents[]?; . == "general-implementation-agent") or
    any(.load_when.task_types[]?; . == "meta")
  ) |
  select(.deprecated == true | not) |
  .path' .claude/context/index.json
```

### Command with Budget Limit

```bash
jq -r '.entries[] |
  select(.load_when.commands[]? == "/implement") |
  select(.line_count < 500) |
  "\(.path) (\(.line_count) lines)"' .claude/context/index.json
```

## Priority Loading Strategy

1. Always-load files (critical patterns, standards)
2. Agent-specific files (from `load_when.agents`)
3. Language-specific files (from `load_when.task_types`)
4. Project context (from `.context/index.json`)
5. Project memory (from `.memory/`)
6. Topic-specific files (as needed for task)

## Hook-Shape Policy: `agents[]` vs. `commands[]` vs. Both

An entry's `load_when.agents` and `load_when.commands` arrays are two independent reach hooks,
not two names for the same thing:

- **`agents[]`**: the entry loads whenever a listed agent is dispatched, no matter which command
  triggered the dispatch.
- **`commands[]`**: the entry loads whenever a listed command runs, no matter which agent (if
  any) that command goes on to dispatch.

**When to author each shape**:

- **`agents[]` only** (the common case for agent-scoped content): the content is specific to an
  agent's job -- e.g. `general-implementation-agent`'s write conventions -- and should load for
  that agent regardless of which command dispatched it. Most entries belong here.
- **`commands[]` only**: the content is command-level workflow guidance not tied to any single
  agent -- e.g. a direct-execution command like `/todo` or `/task` that never dispatches a
  subagent at all, so there is no agent to hook onto.
- **Both, legitimately**: only when the command's real dispatch reach is WIDER than the agents
  already listed -- most commonly `/orchestrate`, whose reach is the union of the research, plan,
  and implement agents across a task's lifecycle, or a command that dispatches to a genuinely
  different agent than the ones already in `agents[]`.

**When both is redundant, not legitimate**: if an entry's `commands[]` array contains only
commands that ALL route to an agent already present in that same entry's `agents[]`, the
`commands[]` hook adds no reach beyond what `agents[]` already provides -- it is a redundant
duplicate hook, not a legitimate dual-addressed shape. The fix is to drop `commands[]` (set it to
`[]`) and keep `agents[]` alone; the entry's actual load reach is unchanged by doing so, since
`agents[]` already covered every case `commands[]` was adding.

**Enforcement**: this is not merely documented policy -- `validate-context-budgets.sh`'s
Double-Loading Check enforces it mechanically. It derives the current command-to-agent routing
table live from deployed artifacts (`manifest.json`'s `routing_agents` block for `/research`,
`/plan`, `/implement`, and the sole `subagent_type:` line in each of `skill-meta`,
`skill-spawn`, `skill-reviser`'s `SKILL.md` for `/meta`, `/spawn`, `/revise`) and classifies
every entry carrying both hooks into one of three buckets: **redundant** (a build-breaking
violation), **legitimate-dual** (informational only), or **unclassifiable-command** (a command
outside the known six-command route table and the literal direct-command roster -- most often an
extension command whose route is not mechanically derivable from any manifest today;
informational only, never silently folded into "legitimate"). See that script's own
`--- Double-Loading Check ---` section and its preceding comment block for the current criterion,
command roster, and bucket definitions -- this document states the authoring policy those buckets
exist to enforce, not a second copy of the criterion itself.

## Validation

### Validate Index with Script

```bash
# Run validation script
.claude/scripts/validate-index.sh .claude/context/index.json

# Outputs:
# - Orphaned entries (empty load_when without always:true)
# - Missing files
# - Duplicate paths
# - Budget estimates per agent/language
```

### Check All Paths Exist (Manual)

```bash
jq -r '.entries[].path' .claude/context/index.json | while read p; do
  [ -f ".claude/context/$p" ] || echo "MISSING: $p"
done
```

### Check Command Scope (Domain-Specific Files)

Domain-specific context files (paths under `project/*`) should never have generic workflow
commands in their `load_when.commands` arrays. These files should only be discovered via
their domain-specific agents, task types, and domain-specific commands.

**Generic commands (must NOT appear in project/* entries)**:
`/plan`, `/implement`, `/research`, `/task`, `/revise`, `/review`, `/errors`, `/todo`, `/spawn`

**Domain-specific commands (OK in project/* entries)**:
`/market`, `/analyze`, `/strategy`, `/legal`, `/project`, `/sheet`, `/convert`, `/table`,
`/slides`, `/scrape`, `/grant`, `/deck`, `/learn`

```bash
# Detect project/* entries with generic workflow commands (should return 0)
jq '[.entries[] | select(
  (.path | test("^project/")) and
  any(.load_when.commands[]?;
    . == "/plan" or . == "/implement" or . == "/research" or
    . == "/task" or . == "/revise" or . == "/review" or
    . == "/errors" or . == "/todo" or . == "/spawn")
)] | length' .claude/context/index.json
# Should return 0
```

**Rationale**: Generic commands like `/plan` and `/implement` match ALL tasks regardless of
language. If domain files include these commands, they get loaded for every planning or
implementation operation across all domains, wasting context budget and polluting unrelated
workflows.

### Check for Orphaned Entries

Entries with empty `load_when` arrays (no agents, task_types, commands) and without `always: true` are orphaned and will never be loaded:

```bash
jq '[.entries[] | select(
  (.load_when.agents | length) == 0 and
  (.load_when.task_types | length) == 0 and
  (.load_when.commands | length) == 0 and
  (.load_when.always == true | not)
)] | length' .claude/context/index.json
# Should return 0
```

## Reachability Mechanisms

A context file is reachable through any of THREE independent, equally sanctioned mechanisms —
none of them is an accidental gap, and a file reachable by any one of the three is not dead
however unloved it looks:

1. **By filename** — a backticked or plain path naming the file, anywhere in the source store
   (including inside another context file, e.g. a directory README's tree listing or a sibling
   pattern file).
2. **By directory** — a reference to a containing directory, which reaches every file in its
   subtree transitively, even with no mention of any individual file or subdirectory beneath it.
   Agent prose that names only a top-level content directory (rather than enumerating every file
   or subdirectory under it) is using this mechanism deliberately, not leaving files unreferenced.
3. **Via index** — a per-extension `index-entries.json` entry with a non-empty `load_when` (or
   `always: true`), which the loader resolves at deploy/runtime. The source store holds no single
   merged `index.json`: style-3 data lives in 22 separate per-extension `index-entries.json`
   files, one per extension's own `context/` subtree.

The mechanical check that evaluates all three, as a non-short-circuiting union, is
`context-reachability.sh` (source-store only, `--root` to retarget, `--check` for a per-file
table with a non-zero exit on a genuinely zero-reference finding). See that script's own header
for the full per-style algorithm and its documented OVER-counting caveat.

## Maintenance

When adding new context files:

1. Add entry to the appropriate `index.json` (agent context or project context)
2. Set appropriate `load_when` conditions
3. Include accurate `line_count`
4. Run validation to ensure paths exist

When deprecating files:

1. Set `deprecated: true`
2. Add `replacement` field with new file path
3. Update agents that reference the deprecated file
