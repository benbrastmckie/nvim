# Source Store / Deploy Boundary

<!-- Deliberately eager (no `paths:` frontmatter): this rule's only automated enforcement is a
PostToolUse, non-blocking hook, so an agent gated on first path-touch would learn the rule only
AFTER the violating write landed. Keeping it eager is a recorded decision from the
context-loading audit (see context/architecture/context-layers.md, eager-vs-lazy channels) —
do not add a `paths:` glob here without first moving enforcement to a pre-write gate. -->

## Path Pattern

Applies to: any write whose target path is `.claude/**` in a repository whose `.claude/` tree was
produced by a deploy — i.e. any tree carrying a `<project-root>/.claude-extensions.json`. This is
a *target-path* rule, not a content-scanning rule, and it is repository-independent: it applies
the same way in the repository that owns the source store and in every repository the system
deploys into.

## Principle

`.claude/` in a deployed tree is a gitignored, disposable deploy artifact regenerated from a
source store. Hand-authored files landing in `.claude/` are silently wiped by the next
regeneration — the edit appears to succeed but has no lasting effect.

## Correct Edit Target

The source store's location is machine- and repository-specific, so it is resolved, not assumed.
Follow this procedure:

1. Read `<project-root>/.claude-extensions.json`.
2. Under its `extensions` object, select the entry for the owning extension: `core` for core
   system files (commands, skills, agents, rules, context, hooks, scripts, merge-sources), or the
   extension's own name (e.g. `nix`, `lean`) for extension-owned files.
3. Read that entry's `source_dir` field — an absolute path.
4. Confirm `source_dir` exists on disk.
5. Edit under `<source_dir>/**`, at the path mirroring the deployed one. For example, deployed
   `.claude/hooks/validate-meta-write.sh` mirrors to `<source_dir>/hooks/validate-meta-write.sh`
   (with `source_dir` resolved from the `core` entry).

### If the source store is unreachable

The source store is not reachable from this tree when any of the following holds:
- `.claude-extensions.json` is missing or unparseable.
- The `extensions` object has no entry for the relevant extension.
- The entry has no `source_dir` field.
- The recorded `source_dir` does not exist on disk on this machine.

In any of these cases, do **not** hand-author `.claude/**` as a substitute — it is exactly the
outcome this rule prevents. Instead, record the needed change as a task via `/task`, describing
the deployed path, the intended change, and the reason it could not be made directly. Filing a
task is the sanctioned outcome; a silent report or an in-place `.claude/**` edit is not.

**Before** (observed anti-pattern, illustrative only):
```
Write .claude/hooks/validate-meta-write.sh
```

**After** (illustrating one machine's resolved value — read `source_dir` from
`.claude-extensions.json` per the procedure above rather than typing this path directly):
```
Write <source_dir>/hooks/validate-meta-write.sh
# e.g. /home/example/repo/agent-system/extensions/core/hooks/validate-meta-write.sh
```

## Exceptions

- Writes under `specs/**` (task-management artifacts) are unaffected — task creation and
  artifact authoring there is legitimate regardless of lifecycle stage.
- The deploy/reload process, which writes the entire `.claude/` tree by design, is not a
  violation.

## Enforcement

Two layers, neither of which alone is a guarantee:

- **Advisory hook**: `validate-meta-write.sh` (PostToolUse, non-blocking) fires on `Write`/`Edit`
  targeting `.claude/**` paths (including `.claude/scripts/**` and `.claude/hooks/**`) and injects
  a corrective `additionalContext` message naming the correct source-store target. It never
  blocks the write.
- **Agent reinforcement**: implementer-agent contracts include a MUST NOT bullet against
  hand-authoring `.claude/**` files (see agent files).

**Known limitation**: a PostToolUse hook sees only a `file_path` argument. It cannot know task
type, lifecycle stage, command context, or which repository the path belongs to — its
`specs/*|*/specs/*` skip matches unconditionally regardless of repo. It is therefore only ever an
advisory nudge on path *shape*, not a backstop for target-root correctness, and it is not a
guarantee that the rule is followed. The durable enforcement is this rule file plus the agent
contracts; the hook is the reminder.
