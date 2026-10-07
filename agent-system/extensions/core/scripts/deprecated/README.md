# Deprecated Scripts

Dead-code core scripts preserved for reference (never deleted).

## Purpose

This directory contains scripts that were confirmed to have zero live callers anywhere in
`agent-system/extensions/**`, `lua/**`, or the deployed `.claude/**` tree, and were quarantined
rather than hard-deleted, per the QUARANTINE-NEVER-DELETE posture (see
`.claude/rules/source-store-deploy-boundary.md`). Files are retained for:

- Historical reference
- Understanding the evolution of the vault, archival, and lint workflows
- Recovery if equivalent functionality is ever needed again

## Contents

- **archive-task.sh** - Formerly implemented task archival. Superseded: `commands/todo.md` and
  `skills/skill-todo/SKILL.md` prose hand-implement the identical archival behavior directly
  (bash-in-markdown), and this is the **authoritative** implementation, not this script.
  `commands/todo.md` mentions this filename only once, as a naming-convention precedent for
  session-ID generation — never as an invocation.

- **orphan-detection.sh** - Formerly scanned `specs/` and `specs/archive/` for orphaned task
  directories. Superseded: `commands/todo.md` Step 2.5 ("Detect Orphaned Directories")
  reimplements the identical two-category orphan scan (`orphaned_in_specs[]` /
  `orphaned_in_archive[]`) directly in prose, and that prose is the **authoritative**
  implementation.

- **vault-operation.sh** - Formerly performed the vault archival operation (task renumbering,
  `specs/archive/` -> `specs/vault/{NN-vault}/` move, state reset). Superseded:
  `commands/todo.md` Steps 5.7-5.8 fully hand-implement vault creation, renumbering, and state
  reset, and that prose is the **authoritative** implementation. **Reactivation hazard**: this
  script's `specs/state.json` writes were never routed through the mutex-safe `state-write.sh`
  path (`context/patterns/task-lock.md`'s conversion notes describe migrating other consumers to
  that flag pair but this script was quarantined, not converted); it also used a fixed temp-path
  write vulnerable to concurrent-invocation collision and lacked the dependency/artifact
  renumbering logic the prose path now performs. Reactivating this script requires first closing
  the unmutexed-write gap and adding the renumbering logic — restoring a caller alone is
  insufficient and would resurrect a state-corruption hazard.

- **check-vault-threshold.sh** - Formerly checked whether `next_project_number` exceeded the
  vault threshold. Superseded by the inline threshold check in `commands/todo.md` Step 5.7.

- **claude-project-cleanup.sh** - Superseded duplicate; zero callers. Distinguish explicitly from
  the **live** `claude-cleanup.sh` + `claude-refresh.sh` pair (both invoked by
  `commands/refresh.md` and `skills/skill-refresh/SKILL.md`, and referenced by
  `install-aliases.sh`/`install-systemd-timer.sh`), which remain wired and active. This script is
  a same-sounding but functionally distinct, dead predecessor.

- **rename-session.sh** - OpenCode-TUI-scoped utility (its own header states it targets "the
  active OpenCode session in the current TUI instance" and is "a no-op when no OpenCode TUI is
  running"). Inapplicable to the Claude Code deploy path this repository uses; zero live callers
  regardless of system.

- **roadmap-sync.sh** - Dead predecessor of the similarly-named `roadmap-integration.sh`
  (quarantined alongside it below). Its own docstring describes a two-phase "scan"/"apply"
  roadmap-annotation design that `roadmap-integration.sh` also implemented; both are now dead,
  since `/todo` and `/review` no longer call either one (see the `roadmap-integration.sh` entry
  below for why). Recorded here explicitly so a future audit does not need to rediscover the
  supersession.

- **roadmap-integration.sh** - Formerly parsed `specs/ROADMAP.md` (`## Phase N:` headings with
  `- [ ]`/`- [x]` checkboxes, or pipe-delimited status tables), cross-referenced completed/
  abandoned tasks against it, and annotated high-confidence matches in place. Retired because
  `specs/ROADMAP.md` was rewritten (commit `d4ed9d72`, "roadmap: rewrite around
  dependency-ordered batches") into hand-curated `## Stage N: ...` prose that matches neither
  shape, so every invocation reported `phases=0, checkboxes=0, table_rows=0, parseable=false`
  and the `unparseable_roadmap` warning — the annotation feature was silently incapable of ever
  firing again against the current roadmap shape. `specs/ROADMAP.md`'s own header additionally
  states "Finished work is removed, not archived here", directly conflicting with this script's
  in-place `*(Completed: Task N, DATE)*` annotation model. Superseded: no replacement script —
  `/review`'s `## Roadmap Progress` section and `/todo`'s roadmap steps were removed outright and
  replaced with a plain pointer to `specs/ROADMAP.md`, since the roadmap is now intentionally
  hand-curated and not meant for mechanical annotation. **Reactivation hazard**: restoring a
  caller alone is insufficient. Both the `## Phase N:` heading regex and the `(task N`
  explicit-ref matcher would need rewriting to recognize `## Stage N:` prose and the current
  `- [ ] **{N}** — {description}` item format, AND the in-place annotation output format would
  still conflict with the roadmap's stated delete-on-completion policy. Fixing the parser alone
  does not resolve the second, independent conflict.

- **tests/test-roadmap-argv-ceiling.sh** - Dedicated test suite for `roadmap-integration.sh`'s
  argv-handling; hard-resolves the script path and `exit 2`s without it, so it could not survive
  in `scripts/tests/` once the script above was quarantined. No coverage loss of a still-live
  behavior: this suite tested only the retired script's own CLI parsing.

- **tests/test-roadmap-items-producer.sh** - Dedicated test suite for the
  `roadmap_items`/`completion_summary` -> `state.json` producer chain
  (`skill_propagate_completion_summary`), exercised via `roadmap-integration.sh` as the
  consumer-side harness. Hard-resolves the script and `exit 2`s without it. **Accepted coverage
  loss**: this was the only end-to-end test of the still-live producer chain
  (`agents/general-implementation-agent.md`'s Stage 6-roadmap `roadmap_items` population is
  unaffected by this retirement and remains live, now vestigial pending a follow-up task to
  retire it too — see the task that performed this quarantine for the full flagged follow-up).

- **validate-extension-index.sh** - Dead predecessor superseded by
  `check-extension-docs.sh`'s Rule T (`check_index_entries_schema`), which validates
  `index-entries.json` against `index.schema.json` and is wired into `verify-deploy.sh` as a
  doc-lint gate. This script's docstring (JSON structure, path prefixes, cross-system
  references, path resolution for `index-entries.json`) is now covered by Rule T; a comment near
  Rule T in `check-extension-docs.sh` confirms Rule T was a deliberate migration target. Recorded
  here explicitly so a future audit does not need to rediscover the supersession.

- **literature-retrieve.sh** - Deprecated by its own header ("superseded by
  `literature-briefing.sh` ... Do not add new usages") since before this quarantine, but missed
  the quarantine-never-delete process and remained declared in `manifest.json`
  `provides.scripts` — deploying on every reload with zero automated callers. Superseded:
  `literature-briefing.sh` (invoked via `literature-briefing-invoke.sh` from each importing
  skill's Stage 4a block, per `context/patterns/lit-stage4a-flow.md`) is the current live `--lit`
  injection mechanism. Confirmed invocation-dead before the move: the only remaining mentions
  across `agent-system/extensions/` were a doc guide's prose (now corrected — see
  `literature/context/guides/literature-organization.md`), a `check-extension-docs.sh` comment
  naming it as an illustrative example, and a `scripts/lib/common.sh` comment listing it among
  `common_repo_root`'s migrated consumers — none an invocation.

## Migration Status

None of the twelve scripts above is declared in `manifest.json` `provides.scripts`, and none is
invoked by any active skill, agent, command, or hook. Every behavior they provided is either
hand-implemented in `commands/todo.md`/`skills/skill-todo/SKILL.md` prose, or superseded by a
differently-named live script.

## Using Deprecated Code

To reactivate a quarantined script:

1. Review the script to understand its original purpose and interface.
2. Confirm no equivalent inline prose or differently-named live script already covers the same
   behavior.
3. For `vault-operation.sh` specifically: close the unmutexed-write and renumbering gaps
   described above BEFORE restoring any caller.
4. If needed, `git mv` the script back to `agent-system/extensions/core/scripts/` and re-add it
   to `manifest.json` `provides.scripts`.
5. Test thoroughly before committing.

## Removal Policy

Quarantined scripts may be hard-deleted in a future task when:

- No reference value remains (confirmed by a fresh dead-code audit).
- No migration or recovery need exists.

## Related Documentation

- [Core Extension manifest](../../manifest.json) - Declared script list
- [commands/todo.md](../../commands/todo.md) - Authoritative archival, orphan-scan, and
  vault-operation prose
- [context/patterns/task-lock.md](../../context/patterns/task-lock.md) - Mutex-safe state-write
  conversion notes
