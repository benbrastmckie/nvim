# Research Report: Task #483

**Task**: 483 - Document that an extension lifecycle hook can never fire without a declared task_type
**Started**: 2026-11-06T10:21:00Z
**Completed**: 2026-11-06T10:40:00Z
**Effort**: small (two coordinated documentation edits, no code changes)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/skill-base.sh`,
  `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`,
  `agent-system/extensions/core/docs/guides/creating-extensions.md`,
  `agent-system/extensions/core/context/guides/extension-development.md`,
  `.claude-extensions.json` (source_dir resolution)
- Issue-log evidence: `specs/482_create_sapience_extension/issues.jsonl` entries
  `iss_1793844574027_V05zIp` and `iss_1793845054770_eL3BT2`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The mechanism described in the dispatch is independently re-confirmed by direct source
  reading, byte-for-byte: `skill_get_extension_dir()` in
  `agent-system/extensions/core/scripts/skill-base.sh` gates extension resolution at line 178 on
  `[ -n "$ext_task_type" ] && [ "$ext_task_type" = "$task_type" ]`, and all four
  `skill_run_extension_hook` call sites (lines 478, 541, 761, 1146 of the same file) pass the
  current dispatched task's own `task_type`. Every line number the dispatch cites matches the
  current source exactly.
- The two target documentation files are confirmed at the line numbers the dispatch names:
  `creating-extensions.md`'s `## Lifecycle Hooks` heading is at line 688 and
  `### Observers vs. Lifecycle Hooks` at line 880; `extension-development.md`'s manifest field
  table `task_type` row is at line 83 and its `### Resource-Only Extensions` prose is at
  line 323-325 (the dispatch's "~line 79" / "~line 256" are close estimates of the same rows).
- Neither file currently states the standalone consequence ("no `task_type` means no hook can
  ever fire") as its own prominent claim. `creating-extensions.md`'s existing
  `### Observers vs. Lifecycle Hooks` subsection states the resolution rule correctly but frames
  it only as a comparison against the observer seam, in service of a different point (why hooks
  cannot serve a topic-grouped seam). `extension-development.md`'s resource-only-extension prose
  tells authors they may omit `task_type` with no warning about the hook consequence.
- The hardcoded cross-cutting precedent (`<memory-context>` injection) is confirmed at
  `orchestrate-build-dispatch.sh` line 342: a direct call to `.claude/scripts/memory-retrieve.sh`
  from core's own dispatch builder, not an extension hook of any kind.
- Recommended approach: add one new, prominent subsection near the top of
  `## Lifecycle Hooks` in `creating-extensions.md` stating the prerequisite, the exact gate
  expression, the per-domain-vs-cross-cutting distinction, the core-only precedent, and a
  pointer (not a duplicate) to the observer comparison; then add a short pointer sentence to
  `extension-development.md`'s `### Resource-Only Extensions` prose linking back to it. This is
  a documentation-only change with a clean, low-risk edit surface.

## Context & Scope

This task researches where and how to document a specific, already-verified gap in the
extension-authoring guidance: a `manifest.json` top-level `hooks` declaration is dead code for
any extension that omits `task_type` (as a "resource-only" extension is explicitly told it may
do), because hook resolution is gated on exact `task_type` string equality against the
*currently dispatched task's* own `task_type`. The task is documentation-only — the resolution
mechanism itself (`skill_get_extension_dir()`, the four `skill_run_extension_hook` call sites,
the non-blocking exit-code contract) is explicitly out of scope for any code change, and no new
cross-cutting hook seam is to be proposed or designed. The dispatch's "verified mechanism"
section is itself a set of claims to re-verify against current source, not to take on faith;
this research independently re-derived each one from the live files.

## Findings

### Codebase Patterns

**The resolver (re-verified against current source, `agent-system/extensions/core/scripts/skill-base.sh`):**

```bash
# lines 162-179 (skill_get_extension_dir)
for ext_name in $(jq -r '.extensions | to_entries[] | select(.value.status=="active") | .key' \
    "$extensions_json" 2>/dev/null); do
  ext_manifest=".claude/extensions/${ext_name}/manifest.json"
  [ -f "$ext_manifest" ] || continue
  ext_task_type=$(jq -r '.task_type // empty' "$ext_manifest" 2>/dev/null)
  if [ -n "$ext_task_type" ] && [ "$ext_task_type" = "$task_type" ]; then
    echo ".claude/extensions/${ext_name}"
    return 0
  fi
done
```

The gate at line 178 is exactly `[ -n "$ext_task_type" ] && [ "$ext_task_type" = "$task_type" ]`.
An extension manifest with no `task_type` key yields `ext_task_type=""` from the `jq -r
'.task_type // empty'` lookup, which fails the `-n` test unconditionally — the equality check is
never even reached. The loop iterates every *active* extension and returns the first manifest
whose own `task_type` matches the task's; an extension that never sets `task_type` can never be
the one this function resolves to, for any task of any type.

All four hook call sites pass the currently dispatched task's own type, confirmed at:
- line 478 (`preflight`, inside `skill_preflight_update()`)
- line 541 (`context_injection`, inside `skill_context_injection()`, before agent delegation)
- line 761 (`verification`, inside the gate-out path, after `skill_validate_task_artifacts`)
- line 1146 (`postflight`, inside `skill_postflight_update()`)

Each call is `skill_run_extension_hook "<stage>" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}"
"$session_id" "$operation"` — the third argument is always the live task's `task_type`, never a
list of all loaded extensions' types, and never anything an extension without a `task_type`
could match.

**Per-domain, not cross-cutting, precedent:** the `nvim` and `nix` extensions' own
`context_injection` hooks fire only because each extension's manifest declares `task_type: nvim`
/ `task_type: nix` respectively — their hooks run exclusively when the dispatched task's own type
equals that value. There is no code path by which either hook could fire on a task of a
different type, let alone on every task regardless of type. Citing them as precedent for a
hook that should fire across all task types (the premise this task exists to correct) inverts
what the mechanism actually does.

**The one real cross-cutting precedent is not an extension hook at all:**
`agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` line 342:

```bash
memory_context=$(bash "${SKILL_REPO_ROOT}/.claude/scripts/memory-retrieve.sh" "$description" "$task_type" "$memory_arg3" 2>/dev/null) || memory_context=""
```

This is a hardcoded call inside core's own dispatch-building script, unconditional on any
extension's `task_type`, producing the `<memory-context>` block injected into every dispatch.
Replicating this shape for a new, task-type-independent purpose requires editing core's own
script — it is not something a new or existing extension's manifest can express via the `hooks`
seam, regardless of whether that extension declares a `task_type`.

**Post-task observers are a documented, separate seam that also does not solve pre-work
orientation.** `creating-extensions.md`'s `## Post-Task Observers` section (line 874) and its
`### Observers vs. Lifecycle Hooks` subsection (line 880) already state: observers run AFTER a
task reaches a resting state, matched by prefix-aware `topic`/`task_type` matching, with every
matching observer firing (never first-match-wins) — a different resolution mechanism from
lifecycle hooks' first-match string equality. Because observers fire only post-completion, they
structurally cannot provide context *before* an agent begins work, independent of the
`task_type`-declaration question this task addresses.

### Current Documentation Gaps (verified against live files)

1. `agent-system/extensions/core/docs/guides/creating-extensions.md`
   - `## Lifecycle Hooks` (line 688) through `### Adding Hooks to Your Extension` (line 845)
     documents the `hooks` schema, the `hooks` vs. `provides.hooks` distinction, basename path
     resolution, the 5 positional arguments, the non-blocking exit-code contract, and the
     observability globals — but never states, as its own claim, that a declared `task_type` is
     a *precondition* for any hook to fire at all.
   - `### Observers vs. Lifecycle Hooks` (line 880) already contains the correct resolution-rule
     statement ("resolved by manifest `task_type` string equality against a single-valued
     top-level `task_type` field") but states it only in service of explaining why hooks cannot
     serve a *topic-grouped* seam like observers do — a reader looking at the Lifecycle Hooks
     section itself, never reaching the Observers section, would not encounter it.
2. `agent-system/extensions/core/context/guides/extension-development.md`
   - The manifest field table's `task_type` row (line 83) reads: "Task type this extension
     handles (omit for resource-only extensions)" — permission with no consequence stated.
   - `### Resource-Only Extensions` (lines 323-325) tells authors outright: "Extensions that only
     provide shared resources (no agents, commands, or routing) can omit `task_type` entirely,"
     again with no mention that a `hooks` declaration in such a manifest would never fire.

This is precisely the gap that made the false premise in the sapience-extension task plausible:
an author who read either the Hook Schema section or the resource-only-extension permission
would find nothing contradicting a cross-cutting `hooks.context_injection` design for a
`task_type`-less extension.

### External Resources

Not applicable — this is a pure codebase-documentation task with no external dependency or
library surface.

## Decisions

- **Add one new subsection to `creating-extensions.md`'s `## Lifecycle Hooks`, placed
  immediately after the section's introductory paragraph and before `### Hooks vs.
  provides.hooks`** (i.e., inserted between the current lines 690 and 692), rather than editing
  the existing `### Observers vs. Lifecycle Hooks` subsection in place. Rationale: acceptance
  criterion 1 requires the statement be prominent and not buried in the observer comparison;
  inserting a new, early subsection inside `## Lifecycle Hooks` itself (rather than only inside
  the observer-comparison subsection, which a reader may never reach) satisfies that directly.
  Suggested heading: `### Prerequisite: A Declared task_type`.
- **Cross-reference, do not duplicate, `### Observers vs. Lifecycle Hooks`.** The new subsection
  should end with a one-line pointer to that existing subsection for the full resolution-rule
  comparison and the WHY-TOPIC rationale, rather than restating its content. This satisfies
  acceptance criterion 7 directly.
- **Content the new subsection must carry** (mapped to acceptance criteria 1-5):
  1. The explicit claim: a hook fires only when the declaring extension's own `task_type`
     string-equals the dispatched task's `task_type`; no `task_type` declared means no firing
     path for any of the four hooks.
  2. Name `skill_get_extension_dir()` in `scripts/skill-base.sh` and quote the exact gate:
     `` [ -n "$ext_task_type" ] && [ "$ext_task_type" = "$task_type" ] ``.
  3. State that `nvim`/`nix` are per-domain precedents (each fires only on its own declared
     type), not cross-cutting ones, so citing them as precedent for a type-independent hook is
     incorrect.
  4. Name the `memory-retrieve.sh` / `<memory-context>` call in
     `orchestrate-build-dispatch.sh` as the one real cross-cutting pre-dispatch injection, state
     plainly it is a core-script call and not an extension hook, and that no extension-declarable
     cross-cutting seam exists today.
  5. Note, briefly, that post-task observers do not solve pre-work orientation either (fire only
     after a resting state), pointing at `## Post-Task Observers` rather than re-explaining it.
- **In `extension-development.md`, add the pointer to the `### Resource-Only Extensions` prose**
  (not a rewrite of the field-table row, which stays a one-line schema reference) — a short
  paragraph immediately following the existing permission sentence, stating that omitting
  `task_type` also forfeits all four lifecycle hooks, with a link to the new
  `creating-extensions.md` subsection. This satisfies acceptance criterion 6 using the "and/or"
  the dispatch allows, chosen over the field-table row because the resource-only prose is where
  an author is actively told they may omit `task_type` — the more load-bearing location for a
  warning to land.
- **No code changes.** `skill-base.sh` is read-only for this task; the resolver, the hook
  argument contract, and the exit-code/observability behavior are unchanged. No new hook seam is
  proposed.
- **No task-number references land in the edited prose** — the backlog-reconciliation and
  issue-log evidence cited in this report and in the dispatch stay confined to `specs/**`
  artifacts (this report, the task description, the issues.jsonl entries), consistent with
  `no-task-references-in-deliverables.md`.

## Recommendations

1. Implementation phase should edit `agent-system/extensions/core/docs/guides/creating-extensions.md`
   (the source store, never `.claude/**`) to insert a new `### Prerequisite: A Declared task_type`
   subsection between the current lines 690 and 692, carrying the five content points listed
   under Decisions above, closing with a pointer to `### Observers vs. Lifecycle Hooks`.
2. Implementation phase should edit `agent-system/extensions/core/context/guides/extension-development.md`'s
   `### Resource-Only Extensions` prose (around current lines 323-325) to add a short paragraph
   stating that omitting `task_type` also forfeits all four lifecycle hooks, linking to the new
   `creating-extensions.md` subsection by file and section name (a relative markdown link in the
   style already used elsewhere in the same file, e.g. `../../docs/guides/creating-extensions.md`).
3. After both edits land, redeploy (`bash .claude/scripts/deploy-headless.sh`, bounded wait per
   `context/patterns/external-process-wait.md`) and diff the deployed copies
   (`.claude/docs/guides/creating-extensions.md`,
   `.claude/context/guides/extension-development.md`) against the source store to confirm they
   match, satisfying acceptance criterion 8.
4. Keep both edits prose-only, inside existing section structure — no manifest-schema change, no
   new example blocks needed beyond the quoted gate expression, since the schema and execution
   contract are already fully documented elsewhere in the same file.
5. Do not touch `skill-base.sh` beyond the read-only verification already performed in this
   report.

## Risks & Mitigations

- **Risk**: a future reader skims past a new subsection inserted mid-section and still misses
  the constraint. **Mitigation**: place it immediately after the section's own introductory
  sentence (before any other subsection), per Decisions above, rather than appending it at the
  end of `## Lifecycle Hooks` where it would again be the last thing read.
- **Risk**: the new subsection drifts from `### Observers vs. Lifecycle Hooks` over time if both
  separately restate the resolution rule. **Mitigation**: the cross-reference-not-duplicate
  decision above is the mitigation; implementation should resist the temptation to inline the
  observer-comparison content for completeness.
- **Risk**: redeploy step is skipped or only partially verified. **Mitigation**: acceptance
  criterion 8 explicitly requires a post-redeploy diff confirmation; implementation phase should
  treat that as a required verification step, not an optional nicety.

## Context Extension Recommendations

None — this is a meta/documentation task whose entire deliverable is itself the context
extension (the two guidance files). No further context-file gap was identified beyond the edits
this task already scopes.

## Appendix

- Line numbers verified by direct `grep -n` / `sed -n` reads against current source on
  2026-11-06, not inferred from the dispatch's own claims:
  - `skill-base.sh`: `skill_get_extension_dir()` resolver body lines 162-179, gate expression at
    line 178; `skill_run_extension_hook` call sites at lines 478, 541, 761, 1146.
  - `orchestrate-build-dispatch.sh`: `memory-retrieve.sh` call at line 342.
  - `creating-extensions.md`: `## Lifecycle Hooks` at line 688, `### Hooks vs. provides.hooks`
    692, `### Hook Schema` 711, `### Hook Execution Contract` 742, `### Lifecycle Stage Mapping`
    789, `## Post-Task Observers` 874, `### Observers vs. Lifecycle Hooks` 880.
  - `extension-development.md`: manifest field table `task_type` row at line 83,
    `### Resource-Only Extensions` heading at line 323, its body at lines 325 onward.
- Issue-log cross-check: `specs/482_create_sapience_extension/issues.jsonl` entries
  `iss_1793844574027_V05zIp` (research phase, class `dispatch-premise-incorrect`, severity
  `costly`) and `iss_1793845054770_eL3BT2` (plan phase, class `scope-deviation`, severity
  `minor`) both independently corroborate the same refutation this report re-derived from
  source.
- `.claude-extensions.json` confirms the source-store path used throughout this report:
  `agent-system/extensions/<name>` is each extension's `source_dir`.
