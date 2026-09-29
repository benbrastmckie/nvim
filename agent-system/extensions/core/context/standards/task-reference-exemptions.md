# Task-Reference Exemption Taxonomy

Companion to `rules/no-task-references-in-deliverables.md` (the always-eager principle). This
file carries the full exemption taxonomy and enforcement narrative, loaded on demand. The
mechanical source of truth for pattern and exemption logic is
`scripts/lib/task-reference-patterns.sh` — both enforcement scripts consume it; neither defines
its own logic, and this document describes (never redefines) that behavior.

## Reference Durable Anchors Instead

When a deliverable needs to explain provenance, prior context, or "why does this section exist,"
cite a durable anchor: a sibling document's filename, a section heading, a decision-record name,
or a verified fact — never the ephemeral task number that happened to produce it.

**Before** (observed anti-pattern, illustrative only):
<!-- task-ref-ok:begin quoted historical anti-pattern -->
```markdown
## 13. Index Freshness, Reindex, and the Absence of an Auto-Indexer (tasks 823-824)

**Architecture context (task 35)**: the freshness machinery below is mechanism 3 ...
```
<!-- task-ref-ok:end -->

**After**:
```markdown
## 13. Index Freshness, Reindex, and the Absence of an Auto-Indexer

**Architecture context**: the freshness machinery below is mechanism 3 of the notmuch indexing
pipeline described in `wrapper-contracts.md` section 9 (mbsync trigger paths) ...
```

The durable anchor is the section/document reference ("section 9", "mbsync trigger paths"), not
the ephemeral identifier that happened to write it.

## Exemption Taxonomy

This is the single source of truth for what counts as a citation and what is exempt. Both
`scripts/check-task-references.sh` (the repo-wide lint gate) and
`hooks/validate-no-task-references.sh` (the write-time guard) consume this taxonomy
mechanically through one shared library, `scripts/lib/task-reference-patterns.sh` — neither
script defines pattern or exemption logic on its own.

**Exemption marker convention**: a line containing the substring `task-ref-ok:begin` opens an
exempt region that runs through (and includes) the next line containing `task-ref-ok:end`;
comment syntax is irrelevant (markdown `<!-- -->`, shell `#`, Lua `--`) since the token is
matched as a plain substring. A single line containing the substring `task-ref-ok` is itself
exempt (inline form). Both the block form and the inline form REQUIRE a trailing reason naming
one of the categories below, carried on the begin marker (block form) or the inline marker line
(inline form); the end marker itself may be bare.

| Category | Verdict | Marker required? | Example |
|----------|---------|-------------------|---------|
| 1. `specs/**` artifacts | Path-level exemption, no marker, unchanged | No | Any file under `specs/**` |
| 2. Git commit-message convention examples | Convert to placeholders (`task {N}: {action}`, `task {N} phase {P}: {phase_name}`); a single genuinely-rendered example per convention may keep concrete numbers | Yes, for the one retained rendered example only | `task {N}: create {title}` (placeholder); one marked rendered instance kept for illustration |
| 3. Command-usage examples | Keep concrete numbers — the flag takes a number and a placeholder makes the example unusable | Yes | `/research 7, 22-24, 59` |
| 4. Quoted historical anti-patterns | Keep verbatim — the point is to show a real past violation as a negative example | Yes | The **Before** block above |
| 5. Placeholder-bearing prose | Not matched by `TASK_PATTERN` at all; recorded here as a constraint on future pattern changes, never broaden the digit-requirement | No (not applicable — never matches) | `task {N}`, `specs/{NNN}_{SLUG}/`, `MM_{short-slug}.md` |
| 6. Test fixtures for the reference-pattern detector itself | Keep concrete digits verbatim — the fixture's whole purpose is asserting the shared library's regex triggers (or does not trigger) on a specific literal string; a placeholder would not match `[0-9]+` and would silently disable the assertion | Yes | `assert_triggers "positive: task 788" ... "See task 788 for context"` in `scripts/tests/test-validate-no-task-references.sh` and the five-named-forms fixture block in `scripts/tests/test-census-count.sh` <!-- task-ref-ok quoting the actual fixture strings, category 6 --> |
| 7. Memory vault frontmatter provenance fields (`topic`, `source`) | Keep concrete numbers verbatim in the YAML frontmatter block only — `memory-harvest.sh` and `/learn` write `topic: "task-${task_number}"` / `source: "${source_artifact}"` as structured provenance data, not deliverable prose; a placeholder would misrepresent which task actually produced the memory | Yes, inline on the frontmatter line itself as a `#`-prefixed trailing comment (the only comment syntax YAML recognizes; `<!-- -->` is NOT valid here and can break strict parsers) | `topic: "task-595"  # task-ref-ok inline, category 7` |

For the discovery history behind categories 6 and 7, and the git-workflow.md resolved test case,
see `specs/decisions/no-task-references-enforcement-history.md`.

## Enforcement

Three layers. `specs/**` is the ONLY exempt tree — every other git-tracked file in the
repository, in any repo this system deploys into, is a deliverable subject to this rule.

- **Repo-wide lint gate**: `.claude/scripts/check-task-references.sh` enumerates every
  git-tracked file in the repository via `git ls-files` (so gitignored/vendored/generated paths
  are excluded by construction) and exits non-zero on any unexempted finding outside `specs/**`.
  The scan is repo-appropriate by construction — it does not hard-code this repo's own directory
  layout, so a consumer repo with a different source-tree layout (e.g. a `docs/` and a
  language-specific source dir, rather than this repo's `agent-system/extensions/`, `.opencode/`,
  `lua/`, `.memory/`) is scanned in full rather than scanning nothing. It is wired as gate 4 of
  `scripts/verify-deploy.sh`. The lint and the write-time gate below share exactly one scope
  predicate (`is_exempt_path`, from the shared library), so the two enforcement layers cannot
  silently diverge in scope.
- **Write-time gate**: `.claude/hooks/validate-no-task-references.sh` is a blocking PreToolUse
  gate (matcher `Write|Edit`) that scans new/edited content outside `specs/**` for task-number
  citation patterns and denies the write via exit code 2 (not `permissionDecision: "deny"`, which
  is documented-buggy for tools bare-allow-listed in `settings.json`'s `permissions.allow` — see
  `guard-destructive-git.sh` for the same pattern). It fails OPEN (exit 0, stderr warning) if its
  own shared pattern library cannot be sourced, so a broken guard never blocks every write in the
  repo. **`.memory/**` coverage, empirically verified**: `skill-todo`'s Stage 14 memory-harvest
  logic (the live path — distinct from the separate, presently-uncalled `memory-harvest.sh`
  script) creates new memory files via the `Write` tool with natural-language instructions, not a
  Bash heredoc, so this hook DOES see and can block `.memory/**` memory-candidate harvest writes.
  The heredoc gap exists only in `memory-harvest.sh` itself, which is not on the live `/todo`
  path today.
- **Agent contracts**: every agent that authors deliverable files outside `specs/**` carries an
  explicit MUST-NOT bullet against citing task numbers, sourced from one canonical fragment,
  `agent-system/extensions/core/context/contracts/no-task-references-bullet.md`. That fragment is
  a generated-copy source (not an `@`-import — `@`-references in an agent body do not auto-resolve
  at subagent spawn) and states the exact in-scope/out-of-scope classification rule: an agent must
  carry the bullet if and only if it authors deliverable files outside `specs/**`. This covers
  every dispatchable implementation agent (core and extensions alike), the planning agents
  (`planner-agent`, `reviser-agent`), and `meta-builder-agent`; research
  agents whose only output is a `specs/**` report are out of scope by that same rule, not by
  oversight.
- **Coverage lint**: `lint-agent-contracts.sh` (Check C) enforces bullet presence across the full
  in-scope set defined by the fragment above, reading the expected text from the fragment file
  itself rather than a hardcoded string, so drift between the fragment and any agent's literal
  copy fails loudly instead of silently re-accumulating. See
  `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`.

**Deploy-mechanism note**: for maintainer context on why a `root-files/settings.json` hook
registration or a new `scripts/<subdir>/*.sh` file might not reach an already-deployed repo, and
how the manifest-driven deploy engine now guards against that defect class, see
`specs/decisions/no-task-references-enforcement-history.md`.

## Design Principle: Default to Repo-Wide Scope, Never a Hard-Coded Directory List

`check-task-references.sh` originally enumerated a fixed `TREE_ROOTS` list encoding this repo's
own layout (`agent-system/extensions`, `.opencode`, `lua`, `.memory`). In a consumer repo with a
different source-tree layout, that list matched nothing the repo actually shipped, so the lint
scanned zero files while claiming repo-wide coverage. The general principle this defect exposed:
a lint or gate script consumed by multiple repos of differing layout should default to the widest
safe scope — repo-wide minus a documented exempt set (`specs/**` here) — rather than a hard-coded
list of one repo's own directories. `git ls-files` makes this cheap: it already excludes
gitignored/vendored/generated paths by construction, so "widest safe scope" does not require any
new exemption machinery beyond the one that already exists. Apply this same default when writing
a new cross-repo lint or gate script.
