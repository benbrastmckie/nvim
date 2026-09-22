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

Read `source_dir` from `<project-root>/.claude-extensions.json` and edit under it, at the path
mirroring the deployed one — never hand-author under `.claude/**` directly. For the full
resolution procedure, the unreachable-source-store fallback, a worked example, the Exceptions
list, and the Enforcement narrative, see
`context/standards/source-store-deploy-boundary-narrative.md`.
