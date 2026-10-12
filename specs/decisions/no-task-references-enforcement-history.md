# Decision Record: No-Task-References Rule — Enforcement History

This record preserves the narrative history behind
`agent-system/extensions/core/rules/no-task-references-in-deliverables.md`'s Exemption Taxonomy
and Enforcement sections: how each exemption category and enforcement layer was discovered or
resolved over time. It was extracted from the rule file itself (task 986) to keep that file
reading as an actionable constraint rather than a changelog, while preserving the provenance for
future maintainers. The rule file's Exemption Taxonomy table and Enforcement section remain the
authoritative, current specification; this document is historical color only.

## Category 6 discovery: test fixtures for the reference-pattern detector itself

**Discovered during Phase 5 purge, not pre-declared in Phase 1**: this category was added when
the repo-wide scan flagged `scripts/tests/test-validate-no-task-references.sh` and
`scripts/tests/test-census-count.sh` — both author literal `task N` / `Task #N` / `tasks N-M`
strings on purpose, as input fixtures asserting the shared pattern library's regex behavior.
These are distinct from category 4 (quoted historical anti-patterns, which quote a REAL past
violation) — the fixture digits here are synthetic and were never a citation of any actual task.
Converting them to `{N}` would silently break the positive-match assertions (a placeholder never
satisfies `[0-9]+`), so they are marked and kept verbatim rather than converted.

## Category 7 discovery: memory vault frontmatter provenance fields

**Discovered during Phase 10 purge, not pre-declared in Phase 1**: this category was added when
the repo-wide scan flagged `.memory/10-Memories/*.md` frontmatter — `topic: "task-NNN"` and
`source: "..."` are written directly by `memory-harvest.sh` (and by `/learn`) as structured
provenance data recording which task produced the memory, not as prose a human author composed.
This directly conflicts with a naive purge, which would falsify the record; the field is marked
in place with an inline `task-ref-ok` comment on the same YAML line rather than rewritten,
consistent with how category 6 marks rather than rewords a machine-authored literal. Only the
memory's PROSE BODY (the `# {title}` section and everything below it) is purged of citations;
the frontmatter block above the second `---` is never rewritten for this rule, only marked.

## Resolved test case: git-workflow.md's Examples block

`.claude/rules/git-workflow.md`'s own `Examples` block self-tripped the write-time hook's
`PHASE_PATTERN` at `task {N} phase {P}: {phase_name}` rendered concretely. Category 2 applies:
the other rendered examples in that section were converted to placeholder form, and the one
retained rendered example (showing the compound task+phase commit form) is wrapped in a
`task-ref-ok:begin/end` region with reason `canonical rendered commit-message example`. A
path-scoped allowlist for that whole file was considered and rejected — it would grant blanket
immunity to a file that could also, in the future, accumulate real violations elsewhere in its
body.

## Declined: a path-level exemption category for archival/tombstone trees

A path-level exemption category covering archival or tombstone trees (the shape `Boneyard/**`
exemplifies) was considered as an eighth taxonomy category and declined, for three reasons:

1. Durable-anchor rewriting was demonstrated achievable for every occurrence in that path class
   — the repo-wide purge converted every citation across 53 files in archival trees to durable
   anchors (filenames, section headings, decision-record names) exactly as category 1's own
   `specs/**` exemption rationale requires elsewhere. No occurrence in this class resisted
   conversion, so no residual case needs excusing.
2. The write-time guard hook (`hooks/validate-no-task-references.sh`) already blocks a new
   citation from landing in an archival tree today, independent of whether a path exemption
   exists for that tree. Adding the category would close no present gap in coverage; it would
   only re-permit the citation pattern going forward in exactly the tree where it had just been
   fully removed.
3. Category 1's `specs/**` exemption rests on task numbers being the intrinsic subject matter of
   that tree — a task report or plan is *about* a task number by construction. An archival or
   tombstone README does not share that property: its content is retired documentation, not
   task-management metadata, so the category-1 rationale does not transfer.

The taxonomy therefore stays at seven categories; see
`agent-system/extensions/core/context/standards/task-reference-exemptions.md`'s Exemption
Taxonomy section for the current, authoritative table.

## Deploy-mechanism note (maintainer context, not part of the rule's own scope)

`agent-system/extensions/core/root-files/settings.json` is install-only by design — the deploy
loader's `manager.load` (`neotex.plugins.ai.shared.extensions.init`) skips a
`root-files/settings.json` copy once a target repo already has one, since that file carries
user/project-specific hook permissions and MCP configuration that must never be silently
overwritten. A new hook registration therefore does not reach an already-deployed repo's
`.claude/settings.json` through the root-files copy at all — it reaches it exclusively through
`merge-sources/settings-hooks.json` (an add-only, dedup-on-`deep_equal` merge target re-applied
on every load/resync/regenerate, reachable via the picker's `[Reload All]`/`[Regenerate]` entries
or `deploy-headless.sh`).

A second, related class of symptom — a brand-new `scripts/<subdir>/*.sh` file (e.g. this rule's
own `scripts/lib/task-reference-patterns.sh`, added when the taxonomy/library were first
authored) silently never reaching `.claude/scripts/<subdir>/` on an existing deploy — was
mis-diagnosed at the time this note was first written as an "already-loaded skip" analogous to
the settings.json case above. It was not: the root cause was the (now-retired) glob+allow-list
sync engine's top-path-segment allow-list match, which dropped every subdirectory-declared
`provides.scripts`/`provides.hooks` entry unconditionally, on both a fresh deploy and a resync
alike — it never ran a correct script copier for anyone, loaded or not. This is now fixed: the
deploy tree is driven by a single manifest-driven engine (`neotex.plugins.ai.shared.extensions`'s
`manager.load`/`manager.resync_all`/`manager.wipe`, reachable interactively via the picker's
`[Reload All]`/`[Regenerate]` entries and headlessly via `deploy-headless.sh`), which addresses
every declared entry — including subdirectory-declared ones — by its manifest path rather than by
a directory-glob allow-list. A scratch-tree regression harness
(`agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh`) asserts a
subdirectory-declared `scripts/lib/*.sh` entry lands on both a fresh deploy and a resync, guarding
against a regression of this exact defect class.
