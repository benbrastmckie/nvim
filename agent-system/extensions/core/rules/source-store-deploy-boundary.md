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

Read `.extensions.<name>.source_dir` from `.claude-extensions.json` and edit the mirrored path
under it — never hand-author under `.claude/**` directly. For the full
resolution procedure, the unreachable-source-store fallback, a worked example, the Exceptions
list, and the Enforcement narrative, see
`context/standards/source-store-deploy-boundary-narrative.md`.

## Task Siting (Where a Source-Store Task Is Created)

This subsection is distinct from the `Path Pattern` above: that section governs where a WRITE
lands once a task is already underway; this one governs where the TASK RECORD ITSELF is created
in the first place. A task whose declared edit target is a source-store path (resolvable via
`.extensions.<name>.source_dir` in `.claude-extensions.json`, as above) must be created in the
repository whose local filesystem actually contains that `source_dir` — never in a repository
where the path does not exist on disk, such as a deploy-only repository that only ever receives
the regenerated `.claude/**` mirror.

This is a narrower principle than, and does not revoke, the `specs/**` exemption in
`context/standards/source-store-deploy-boundary-narrative.md`'s Exceptions list: a task's own
artifacts (reports, plans, summaries) may legitimately live in whatever repository the run
happens from, because artifact authoring under `specs/**` is unaffected by lifecycle stage or
edit target. The siting principle in this subsection is a separate, additional constraint on
where the TASK is filed, applying specifically to a task whose edit target is a source-store
path — it does not change where that task's own `specs/**` artifacts live once the task is
correctly sited.
