# Research Report: Task #331

**Task**: 331 - Topic-keyed post-task observer seam for extensions
**Started**: 2026-10-03T19:27:00Z
**Completed**: 2026-10-03T20:10:00Z
**Effort**: 3-6 hours (per task estimate)
**Dependencies**: 327 (completed), 330 (completed)
**Sources/Inputs**: Codebase exploration (agent-system/extensions/core/scripts/*, manifest.json
  files across all loaded extensions, docs/guides/creating-extensions.md,
  context/reference/state-management-schema.md, context/schemas/events-schema.json)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's own measured line numbers for `scripts/orchestrate-cycle-postflight.sh` are
  now stale (task 330 landed between the measurement and this research pass, as the dispatch
  itself warned would happen). The script is 1762 lines; the dispatch_status case arm (where
  every `issue-record.sh` call lives) runs 950-1256, and the per-dispatch metrics write (WORK
  (m)) runs ~1486-1544 -- both well past the "~1048-1125" estimate. The correct insertion point
  for the new observer call is **after line 1543** (WORK (m)'s closing `fi`) and **before line
  1545** (`WORK (i)` per-task commit), or later still, after `persisted_status` is computed
  (~line 1703) -- see Findings and Recommendations for the tradeoff.
- Both of the dispatch's "WHY NOT LIFECYCLE HOOKS" measurements verify exactly as stated:
  `skill_get_extension_dir()` (skill-base.sh:150-169) does **equality**, not prefix, match
  against a manifest's single-valued top-level `task_type` field (never `topic`); and
  `orchestrate-cycle-postflight.sh` sets no `TASK_TYPE` (only a lowercase local `task_type`), so
  `skill_run_extension_hook "postflight" ... "${TASK_TYPE:-}"` (skill-base.sh:1089) always
  receives an empty string on this path. Both are correctly reasoned grounds for a new seam.
- `scripts/lib/manifest-routing-lib.sh`'s existing ladder (`routing_lookup`/`routing_lookup_flat`)
  is a **first-match-wins, single-value resolver** -- it is the wrong shape to reuse verbatim for
  observers, which must potentially invoke **every** matching observer across **every** loaded
  extension, not resolve to one winner. The manifest-enumeration idiom (iterate
  `${ROUTE_MANIFEST_ROOT:-.claude}/extensions/*/manifest.json`, skip core-vs-noncore via
  `routing_core_manifest()`, prefix match via `cut -d: -f1`) is directly reusable; the
  first-match-wins return contract is not.
- `specs/events.jsonl` (via `scripts/events-append.sh`) is the correct target for the rc event,
  not a new store. Its schema is `{event_type (open string), category (closed enum:
  deviation|blocker|milestone|success), session_id, task, checkpoint, message, detail, ...}`
  — matching the task description's "RECORDED AS AN EVENT" requirement exactly, and matching the
  existing precedent that a non-blocking lifecycle-hook failure already appends a
  `deviation`-category row.
- `context/reference/state-management-schema.md:124` is the exact line carrying the
  presentational-only framing of `topic` that the dispatch requires rewritten
  ("Free-text topic label, aggregated into the top-level `active_topics` array") — confirmed as
  the only Project Entry Fields table row for `topic`.
- A minor correction to the dispatch's own claim: `scripts/memory-retrieve.sh` also reads a field
  named `.topic` (lines 85, 97-99), but it is the **memory-index entry's own** `topic` taxonomy
  value used as a keyword-scoring bonus during `/research`/`/plan`/`/implement` memory retrieval
  -- not `active_projects[].topic`, and not a dispatch/routing decision. It does not contradict
  the dispatch's "nothing dispatches on `active_projects[].topic`" claim, but the guide language
  should say "the first place `active_projects[].topic` becomes a **dispatch-matching** key" to
  avoid an easy over-read.

## Context & Scope

Researched the exact current (post-task-330) shape of `scripts/orchestrate-cycle-postflight.sh`,
the existing manifest-routing ladder, the existing lifecycle-hook mechanism this task's own
description argues against reusing, the unified `specs/events.jsonl` store as the rc-event
target, the manifest.json schema conventions used by comparable blocks (`hooks`,
`keyword_overrides`, `routing_agents`), `docs/guides/creating-extensions.md`'s existing
"Lifecycle Hooks" section (the closest documented analog for the new "observers" section), and
`scripts/check-extension-docs.sh`'s existing Rule-lettered check structure (through Rule W) to
find the right modeling checks for a new "declared observer is documented" rule. Scope was
read-only measurement; no files were modified.

## Findings

### Codebase Patterns

**`scripts/orchestrate-cycle-postflight.sh` (1762 lines) -- re-measured structure:**

- `--task-type` flag parsed at line 244 into a **local, lowercase** `task_type` variable (never
  exported as `TASK_TYPE`). This variable is already in scope for the whole script and is
  exactly what an observer invocation needs for its `task_type` argument -- no new plumbing
  required for that one field.
- The `topic` field is **never read anywhere in this script today**. A new fresh `jq` read
  against `$STATE_FILE` (`.active_projects[] | select(.project_number == $num) | .topic // ""`)
  is required, mirroring the existing `persisted_status` read's own style (plain read, `is_live`-
  independent, falls back to an empty/sentinel value on any failure).
- `case "$dispatch_status" in ... esac` (status-transition arm) spans lines 950-1256. Every
  `issue-record.sh` call site in this script lives inside this block (deploy-pending sub-case at
  1083, blocker-bearing-partial at 1168, failed/blocked at 1189, off-schema catch-all at 1250).
- WORK (m), the per-dispatch `dispatch-metrics.sh` call, spans lines ~1486-1544, strictly AFTER
  the case block above closes (1256) -- confirming metrics already see every issue-log write
  from this cycle.
- WORK (i), the per-task scoped commit, begins at line 1545, immediately after WORK (m)'s closing
  `fi` (line 1543) and a blank line (1544).
- `persisted_status` (state.json's actual current status, read fresh, independent of `is_live`)
  is computed later still, after WORK (j)'s multi-state bookkeeping, at roughly line 1693-1703 --
  the single cleanest existing source for "the resting status reached" the dispatch asks the
  observer to receive as an argument.
- The script's own file-header WORK-letter inventory runs through (m); a new observer call is a
  natural WORK (n) (or similarly next-lettered) addition, with its own paragraph in that header
  comment block, matching this script's established self-documentation convention.

**`scripts/lib/manifest-routing-lib.sh` (257 lines) -- the existing shared ladder:**

- `routing_lookup()` / `routing_lookup_flat()` implement a **5-step, first-match-wins**
  precedence (non-core exact -> non-core compound-base -> core exact -> core compound-base ->
  miss), returning exactly one winning value via two globals (`_ROUTE_LAST_VALUE`,
  `_ROUTE_LAST_VIA`), explicitly documented as "must be called directly, never via command
  substitution" (a subshell would strand the globals).
- `routing_core_manifest()` identifies the core manifest by `.name == "core"` (not by
  `routing_exempt`, which `literature`/`slidev` also set).
- The prefix-match idiom used at Steps 2/4 of both ladders is exactly the "segment before the
  first `:`" rule the dispatch specifies for observer matching: `grep -q ":"` to detect a
  compound value, then `cut -d: -f1` to extract the base.
- **This ladder's return contract does not fit observer resolution.** An observer match is
  "does ANY loaded extension declare an observer whose topic/task_type (prefix-aware) matches
  this task", and when yes, invoke it -- potentially **more than one** extension's observer for
  the same task (a task with topic `books` and task_type `lean4` could in principle match both a
  `books`-topic observer and a `lean4`-task_type observer declared by two different extensions).
  `routing_lookup`'s "first match wins, return one value" semantics would silently drop every
  observer but the first found, which is the wrong behavior for a side-effecting, advisory,
  "notify everyone who's interested" seam. The manifest-enumeration scaffolding (the
  `for _route_manifest in .../manifest.json; do ... done` loop, the core/non-core skip, the
  prefix-match helpers) is reusable almost verbatim; the single-value short-circuit return is not.

**Lifecycle hooks -- both "why not reuse" claims verified against live code:**

- `skill_get_extension_dir()` (`scripts/skill-base.sh:150-169`) does a **two-step join**:
  enumerate `active` extensions from `.claude-extensions.json`, then for each, read its deployed
  manifest's own **single-valued, top-level** `task_type` field and compare with **string
  equality** (`[ "$ext_task_type" = "$task_type" ]`) against the caller's task_type. No prefix
  awareness, no `topic` awareness -- confirming reason 1 in the dispatch exactly.
- `skill_run_extension_hook "postflight" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}" ...`
  appears at `skill-base.sh:1089`, inside `skill_postflight_update()`. Since
  `orchestrate-cycle-postflight.sh` (which calls `skill_postflight_update`) never sets a
  `TASK_TYPE` environment variable anywhere in its 1762 lines (only the unrelated local
  lowercase `task_type`), this read is unconditionally empty on the `/orchestrate` path --
  confirming reason 2 in the dispatch exactly. (The three OTHER `skill_run_extension_hook` call
  sites -- preflight line 465, context_injection line 528, verification line 706 -- are reached
  from the single-task `/research`/`/plan`/`/implement` commands' own skill bodies, which DO
  call `skill_validate_input` first and therefore DO have `TASK_TYPE` exported; only the
  `/orchestrate` batch path is affected. This is consistent with -- not a contradiction of -- the
  dispatch's framing, since the new seam is specifically about the `/orchestrate` postflight
  completion arm.)

**`specs/events.jsonl` -- the rc-event target, already fully specified:**

- `scripts/events-append.sh` is the single sanctioned writer (`flock`-guarded append, lazy file
  creation). Required flags: `--event-type`, `--category` (closed enum:
  `deviation|blocker|milestone|success`), `--session`, `--message`. Optional: `--task`,
  `--checkpoint`, `--duration`, `--detail-json`, `--error-ref`, `--cwd`, `--cc-session-id`.
- `context/schemas/events-schema.json` confirms the same shape and additionally documents
  `detail` as an "open, event_type-specific structured payload" -- the natural home for the
  observer's own name, matched key (`topic`/`task_type`/`both`), resolved script path, exit
  code, wall-clock duration, and whether a timeout fired.
- Direct precedent for this exact category split already exists:
  `docs/guides/creating-extensions.md`'s Lifecycle Hooks section states "A non-zero hook exit
  additionally appends one `deviation`-category row to the unified event store" -- the observer
  rc event should mirror this: `category: success` on rc 0, `category: deviation` on non-zero rc,
  a crash, a missing/non-executable script, or a timeout, with the distinguishing detail living
  in `--detail-json`, not in a new category value (the enum is closed and should stay closed).

**Manifest schema conventions for a new `observers` block:**

- No formal JSON Schema file constrains `manifest.json`'s top level (`context/schemas/` holds
  schemas for `events`, `errors`, `state`, `orchestrator-handoff`, and `frontmatter` -- there is
  no `manifest-schema.json`). Adding a new top-level `observers` key requires no schema-file
  change.
- The closest-shaped existing block is `keyword_overrides`, keyed by an open name with a nested
  object per entry (`books/manifest.json:66-85`): `{"books": {"keywords": [...], "aliases":
  []}}`. The new `observers` block should follow the same shape: keyed by an open observer name,
  each entry an object `{"script": "scripts/x.sh", "topic": "...", "task_type": "..."}` (either
  or both of `topic`/`task_type` present, per the match-if-either contract).
- Top-level lifecycle `hooks` (not `provides.hooks`) already exist on `nix/manifest.json:61-64`
  and `nvim/manifest.json:56-58` as the simplest live examples
  (`{"preflight": "scripts/nix-preflight.sh", "context_injection": "scripts/nix-context.sh"}`),
  confirming the "basename resolved against deployed `.claude/scripts/`, must also appear in
  `provides.scripts`" deploy contract documented in `docs/guides/creating-extensions.md`'s Hook
  Schema section applies identically to any extension-declared script path, including a future
  `observers.*.script` value.
- `scripts/dispatch-metrics.sh`'s own `provides.scripts` registration
  (`core/manifest.json:94` for the script, `:213` for `tests/test-dispatch-metrics.sh`) confirms
  **both** the implementation script and its test file must be separately declared in
  `provides.scripts` for either to deploy -- the same two-entry registration
  `scripts/run-task-observers.sh` and `scripts/tests/test-run-task-observers.sh` will need in
  `core/manifest.json`.

**`docs/guides/creating-extensions.md` -- the Lifecycle Hooks section as the template:**

Section runs lines 655-833 (`## Lifecycle Hooks` through the `---` before `## Troubleshooting`),
with sub-sections `### Hooks vs. provides.hooks`, `### Hook Schema`, `### Hook Execution
Contract`, `### Lifecycle Stage Mapping`, two worked bash examples, and `### Adding Hooks to Your
Extension` (a 4-step mkdir/touch/chmod/manifest-edit/jq-verify walkthrough). A new `## Post-Task
Observers` section (or similarly named) modeled on this exact sub-section skeleton -- schema,
execution contract (now: timeout + non-blocking + rc-as-event, not "warning logged"), the
ordering guarantee, the "match-if-either + prefix-aware" contract, a worked example, and the
"why not lifecycle hooks" rationale as its own callout -- keeps the guide internally consistent
rather than inventing a new documentation shape.

**`context/reference/state-management-schema.md` -- the exact `topic` line to rewrite:**

Two occurrences, both reading "Free-text topic label, aggregated into the top-level
`active_topics` array": line 69 (top-level `active_topics` field description, referencing
`active_projects[].topic`) and line 124 (the Project Entry Fields table's own `topic` row). Line
124 is the one the dispatch means ("the `topic` field's description must stop implying it is
presentational only") -- it currently carries zero indication that `topic` is now a
dispatch-matching key for the observer seam. Line 69's wording is accurate as-is (it already
only describes aggregation) and needs no change.

**`scripts/check-extension-docs.sh` -- the Rule-lettered check structure (currently A-W):**

- The closest analog, Rule W (`check_lifecycle_hooks_resolve`, lines 610-640), validates each
  `hooks.<stage>` entry's stage name against a closed set, resolves the script's basename against
  `provides.scripts`, and emits an `advisory` (not `fail`) when the resolved deployed path is
  missing or non-executable. A new `observers` structural check should mirror this exactly for
  script resolution (closed set of valid keys per entry -- `script` required, `topic`/`task_type`
  optional-but-at-least-one-required -- and the same provides.scripts/deployed/executable
  advisory chain).
- Separately, the "declared observer with no documentation is caught" requirement from the
  dispatch's deliverables list matches the shape of `check_readme_vs_manifest` (lines 1034-1059),
  which currently only checks that `provides.commands` entries are mentioned in the extension's
  own `README.md` (`grep -q "/$cmd_name" "$readme"`) and emits a hard `fail()`, not an advisory.
  A new sibling check -- for each key under `observers`, require that key name (or its `script`
  basename) appear somewhere in the extension's own `README.md` -- directly satisfies "a declared
  observer with no documentation is caught" at the per-extension level, independent of and
  additional to the one-time, generic schema documentation this task also owes in
  `docs/guides/creating-extensions.md`.
- The next available Rule letter is **X** (A-W are already assigned, per the file's own header
  index at lines 52-77).

### External Resources

No external (web) research was needed or performed -- this is a pure internal-mechanism/seam
design task with every relevant fact measurable directly from the codebase.

## Recommendations

1. **Insertion point** (supersedes the dispatch's now-stale "~1048-1125" estimate): add the new
   observer-invocation block either (a) immediately after WORK (m)'s closing `fi` at line 1543
   and before WORK (i)'s commit at line 1545 -- guaranteeing the call is gated only by
   `is_live` and sees every issue-log/metrics write from this cycle, matching the letter of the
   ordering contract -- or (b) later still, right after `persisted_status` is computed
   (~line 1703), so the observer's "resting status reached" argument can be `$persisted_status`
   verbatim (state.json's own actual current status) rather than requiring a second
   case-on-`dispatch_status` translation. Recommend **(b)**: it is strictly simpler (one existing
   variable, already correct under every branch including off-schema/dry-run), it still runs
   after both per-dispatch records (the ordering contract's only real requirement), and
   `specs/events.jsonl` is not part of this script's per-task commit scope (`stage_paths` never
   includes it) so there is no commit-ordering reason to prefer (a).
2. **Gating**: mirror WORK (m)'s own documented reasoning ("Deliberately NOT gated on
   `have_outcome`, `research_gate_failed`, or `dispatch_status` -- only on `is_live`") rather than
   trying to detect "did a genuine NEW resting-state transition happen this cycle," which is
   under-specified at several of the case arms (e.g. the `blocked)` and ordinary non-blocker
   `partial)` arms explicitly perform **no** state.json transition at all, yet are still exactly
   the outcomes an observer may want to see). Invoke `run-task-observers.sh` unconditionally
   under `is_live` on every postflight cycle, passing whatever `$persisted_status` currently is;
   let the observer author decide whether a given status value is interesting.
3. **`manifest-routing-lib.sh` extension**: add a new function (e.g. `routing_resolve_observers`)
   alongside, not inside, `routing_lookup`/`routing_lookup_flat` -- same manifest-enumeration
   idiom, same core/non-core and prefix-match helpers, but returning **every** match found (one
   line per match, e.g. `manifest_path<TAB>observer_name<TAB>script<TAB>matched_on`) rather than
   short-circuiting on the first hit. Do not force this into `routing_lookup`'s existing
   single-value contract.
4. **rc event**: `--event-type task_observer_run` (or equivalent open string),
   `--category success` on rc 0, `--category deviation` on non-zero rc / crash / missing /
   non-executable / timeout, `--task "$task_number"`, `--session "$session_id"`, and a
   `--detail-json` payload carrying the observer name, the extension that declared it, the
   matched key (`topic`/`task_type`/`both`), the resolved script path, the exit code, the
   wall-clock duration, and a `timed_out` boolean.
5. **Timeout mechanism**: no script in this codebase currently uses the coreutils `timeout`
   command (`grep` across all of `scripts/*.sh` found zero hits) -- this will be the first.
   Confirm `timeout`'s availability in every supported runtime (the project runs on both NixOS
   and the user's own Linux box per the environment info; macOS's BSD coreutils historically
   lack `timeout` unless GNU coreutils is installed as `gtimeout`) before committing to it as the
   sole mechanism, or provide a documented fallback (background the observer, `sleep`-poll with
   `kill -0`, matching `context/patterns/bounded-build-waiter.md`'s own writer-liveness
   convention) for a plan-phase decision.
6. **Manifest schema**: no `context/schemas/manifest-schema.json` exists to update. Model the new
   `observers` block directly on `keyword_overrides`'s shape (open-keyed object of per-entry
   objects), e.g.:
   ```json
   "observers": {
     "books-observe": {
       "script": "scripts/books-observe.sh",
       "topic": "books",
       "task_type": "books"
     }
   }
   ```
7. **`check-extension-docs.sh`**: add Rule X as two checks: (a) structural resolution, modeled on
   Rule W (`check_lifecycle_hooks_resolve`) -- `script` required and resolvable via
   `provides.scripts` + deployed + executable (advisory on deploy-state, fail on
   undeclared-in-provides, exactly like Rule W's own split); at least one of `topic`/`task_type`
   present (fail otherwise); and (b) a documentation check modeled on
   `check_readme_vs_manifest` -- each declared observer's name (or script basename) must appear
   in the extension's own `README.md`, `fail()` otherwise. This is the mechanism that makes "a
   declared observer with no documentation is caught" (the acceptance criterion) literally true.
8. **Guide wording precision**: when writing the "why `topic`" rationale into
   `docs/guides/creating-extensions.md` and the schema rewrite in
   `state-management-schema.md:124`, phrase the claim as "`active_projects[].topic` becomes a
   **dispatch-matching** key for the first time" rather than an unqualified "`topic` is never a
   routing key today" -- `scripts/memory-retrieve.sh` already reads a *different* `topic` field
   (a memory-index entry's own topic taxonomy value) as a retrieval-scoring bonus, which is a
   true statement worth not accidentally contradicting.

## Decisions

- Confirmed the dispatch's "WHY NOT REUSE THE LIFECYCLE-HOOK CONTRACT" reasoning (both numbered
  points) against live code exactly as stated; no correction needed there.
- Decided the existing `manifest-routing-lib.sh` ladder's first-match-wins contract must NOT be
  reused verbatim for observer resolution (multiple matches must all fire); only its manifest-
  enumeration and prefix-match helpers are shared.
- Decided `specs/events.jsonl` via `scripts/events-append.sh` is the correct, already-existing rc-
  event target -- no new event store or schema field is needed; `category` stays within the
  existing closed 4-value enum (`success`/`deviation`), with distinguishing detail carried in
  `--detail-json`.
- Decided the dispatch's own "~1048-1125" measured insertion point is stale and must be
  re-measured at plan time regardless of this report's own line numbers (which are themselves a
  point-in-time snapshot and will shift again if another concurrent task touches this same
  file first).
- Did not decide between insertion-point options (a) and (b) above on this task's behalf --
  recommended (b) with reasoning, left as a plan-phase decision since it is a genuine design
  tradeoff, not a measured fact.

## Risks & Mitigations

- **Line-number staleness recurring**: this file is a known hot spot (three tasks in a row have
  touched it: 327, 330, and now 331, with 332 depending on 331). Mitigation: the plan must
  re-grep for the WORK-letter comment markers (`# ─── WORK (m):` etc.) rather than trusting any
  hardcoded line number, including this report's own.
- **`timeout` portability**: if the consuming environment lacks GNU `timeout`, a hanging observer
  could wedge an orchestration despite the "give it a timeout" requirement being met literally in
  code but not in practice. Mitigation: detect `command -v timeout` and document the fallback (or
  require it as a hard dependency and fail the observer resolution loudly, non-blockingly, if
  absent) during planning.
- **Multiple-match ordering**: if two extensions both declare an observer matching the same task
  (one on `topic`, another on `task_type`), the dispatch doesn't specify invocation order between
  them. Mitigation: document a deterministic order (e.g. manifest directory sort order, matching
  the existing `for _route_manifest in .../manifest.json` glob's natural filesystem ordering) so
  test expectations are stable.

## Context Extension Recommendations

- **Topic**: Observer seam schema and the `topic`-as-dispatch-key precedent.
  **Gap**: `docs/guides/creating-extensions.md` has no section for this new manifest block yet
  (expected -- this is exactly what this task's own deliverables add).
  **Recommendation**: add `## Post-Task Observers` modeled on the existing `## Lifecycle Hooks`
  section's five-part skeleton (schema, execution contract, ordering/stage mapping equivalent,
  worked example, "why not X" rationale), per Finding above.
- **Topic**: `manifest-routing-lib.sh`'s scope.
  **Gap**: the library's own header comment documents exactly two sibling ladders
  (`routing_lookup`, `routing_lookup_flat`) and nothing about a "resolve-all-matches" shape; a
  third function family added by this task should get an equally thorough header comment so a
  future reader does not mistake it for a third single-value ladder.
  **Recommendation**: when added, extend `manifest-routing-lib.sh`'s own file-header comment
  block (not just the function's local comment) to list the new function alongside the existing
  two, preserving the "single source of truth" framing the header already claims.

## Appendix

### Search queries / commands used

- `grep -n "task-type\|TASK_TYPE" scripts/orchestrate-cycle-postflight.sh`
- `sed -n` ranges across `scripts/orchestrate-cycle-postflight.sh` (lines 1-60, 990-1180,
  1256-1600, 1600-1762) to re-measure the completion arm, WORK (m), WORK (i), WORK (j), and the
  final-output block.
- `grep -n "TASK_TYPE" scripts/skill-base.sh` and `sed -n '140,172p'` /
  `sed -n '1060,1100p'` to verify both "why not lifecycle hooks" claims line-for-line.
- `cat scripts/lib/manifest-routing-lib.sh` (full file, 257 lines).
- `grep -rn "events.jsonl\|append_event\|record_event" scripts/*.sh scripts/lib/*.sh` and
  `cat scripts/events-append.sh` / `context/schemas/events-schema.json` (full).
- `grep -n "\"hooks\"\|\"routing_agents\"\|\"keyword_overrides\"\|\"hard_contracts\"\|\"name\"\|\"task_type\""
  */manifest.json` across `agent-system/extensions/*` to survey manifest block conventions.
- `sed -n '655,833p' docs/guides/creating-extensions.md` (full Lifecycle Hooks section).
- `grep -n "topic" context/reference/state-management-schema.md` and `sed -n '60,130p'`.
- `grep -rln "\.topic\b" scripts/*.sh scripts/lib/*.sh` plus targeted `grep -n "topic"` on
  `memory-retrieve.sh`, `manage-topics.sh`, `validate-state.sh`,
  `orchestrate-predispatch-review.sh` to verify the dispatch's "topic is never a dispatch key"
  claim and find the one nuance (memory-retrieve.sh's unrelated same-named field).
- `sed -n '1,125p' scripts/check-extension-docs.sh` (header/rule index) and
  `sed -n '610,655p'` / `sed -n '1034,1068p'` (Rules W and the README-vs-manifest check) as
  modeling targets for a new Rule X.
- `grep -rn "^timeout \|command -v timeout\|gtimeout" scripts/*.sh` (zero hits -- confirms no
  existing timeout-invocation precedent in this codebase).
- `find . -iname "*manifest*schema*"` (confirms no formal manifest.json JSON Schema file exists).
