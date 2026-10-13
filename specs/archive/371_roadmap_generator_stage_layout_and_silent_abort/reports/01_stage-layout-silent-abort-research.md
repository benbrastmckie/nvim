# Research Report: Task #371

**Task**: 371 - Teach roadmap-integration.sh the stage-based ROADMAP layout and fix its silent abort
**Started**: 2026-10-09T23:59:00Z
**Completed**: 2026-10-10T01:10:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` (source store, full read)
- `agent-system/extensions/core/context/formats/roadmap-format.md` (generation contract)
- `agent-system/extensions/core/context/patterns/roadmap-update.md` (caller contract)
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` (Step 5 call site)
- Live reproduction against `~/Projects/BimodalLogic` (deployed `.claude/scripts/roadmap-integration.sh`, current HEAD `555c34c34`, and the `79f3fe7cc` fixture commit via `git show`)
- `bash -x` trace of the crash path
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Sub-fault 1 and 2 confirmed mechanically, exact location pinpointed.** `--regenerate` against
  BimodalLogic's live `specs/ROADMAP.md` exits 1 with zero stdout/stderr. A `bash -x` trace shows
  the script dies inside `mode_regenerate`'s `covered_ids_json="$(covered_ids_from "$authored_next")"`
  assignment: `extract_section()` returns empty for all eight hardcoded headers (none exist in the
  stage-based file), so `authored_next=""`, and `covered_ids_from("")`'s pipeline
  (`grep -E '^/orchestrate ' | grep -oE ... | sort -nu | jq ...`) has its first two `grep`s exit 1
  on no-match; under `pipefail` the pipeline's exit status is 1; because this is a bare (non-`local`)
  assignment, not guarded by `if`/`while`/`||`, `set -e` kills the script the instant the assignment
  completes — **after** the value is computed, so the trace shows `covered_ids_json='[]'`
  immediately before the process exits. The script never reaches its own final lines (the
  `<!-- roadmap-generation ... -->` stderr marker print is literally the last code in the file,
  after the `case "$MODE" in ... esac` block that crashed) — so the marker's "always-present"
  promise is false on this path, exactly as the dispatch states.
- **Sub-fault 3 is not hypothetical — `--prune --dry-run` reproduces it live, right now, with exit
  0.** Unlike `--regenerate`, `--prune`'s code path never hits a `pipefail`-fatal pipe, so it does
  not crash. Instead it **silently succeeds** at a near-total content wipe: the dry-run diff shows
  it would replace all ~280 lines of Stage 0–4 / "Not scoped as tasks" / "Maintenance" / "Related"
  prose with the fixed empty 8-section skeleton (`## Goal`, `## Gate state`, ... all empty bodies),
  because none of `extract_section()`'s eight literal headers match the file's actual headers. The
  stderr marker (`pruned=0 retained=0`) gives no hint anything is wrong. This is strictly worse
  than the `--regenerate` crash: nothing signals a problem at all. (Recorded as
  `iss_1791591951895_UGC6Ej`.)
- **`--print` is confirmed unaffected**, exactly as the dispatch asked to verify rather than
  assume: it never calls `load_existing_sections`/`extract_section` at all (those are declared
  "used only by --regenerate/--prune" in the script's own comment), so it has no dependency on the
  file's header vocabulary. Ran clean against the live BimodalLogic tree.
- **The regression fixture's own file disputes the premise it is being asked to satisfy.**
  BimodalLogic's live `specs/ROADMAP.md` carries a `## Maintenance` section stating *"Hand-curated
  prose, not mechanically parsed or annotated"* and a `## Related` entry listing
  `roadmap-format.md` as *"the legacy parseable structure, superseded above"*. Its own stage
  headers already drifted across two hand-edit commits within this research window (`## Run order
  at a glance` → `## Next batches`; `Stage 1 — Decidability of L⁺ (preempts everything)` → `Stage 1
  — Decidability of L⁺`). This does not reopen the settled, do-not-re-litigate ruling that the
  roadmap stays a generated artifact and `--regenerate` stays live — but it is new, mechanically
  observed evidence the plan should weigh when deciding *how much* of the stage layout to teach the
  generator to round-trip structurally versus treat as an opaque authored blob. (Recorded as
  `iss_1791591965521_hlSikc`.)
- **The conclusion stage's own caller-contract documentation is already stale**, independent of
  this defect: `roadmap-update.md` states *"As of this contract, `roadmap-integration.sh` has no
  live caller"*, but `conclusion-stage.md` Step 5 does call `--regenerate` unconditionally. This is
  task 372's territory (its Gap 2(a) names exactly this), not fixed here — noted for completeness.
- **No caller resolves the deprecated copy.** A repo-wide grep of every non-deprecated reference to
  `roadmap-integration.sh` (manifest, index-entries, the two test files, the three context docs,
  and the script calling itself) shows zero hits for `scripts/deprecated/roadmap-integration.sh`
  outside that file's own `deprecated/README.md` entry. Confirmed, not assumed.

## Context & Scope

Task 371 asks for three things against `core/scripts/roadmap-integration.sh` and
`core/context/formats/roadmap-format.md`: (1) make the script's own "always-present stderr
marker" promise true, including on error paths; (2) audit the whole script for the
grep-under-`pipefail`-on-no-match shape, not just the one call site; (3) make a loud,
permanent, named refusal the behavior when the script meets a `## ` header vocabulary it
does not recognize, rather than a silent destructive overwrite. `--print` and `--prune` were to
be checked (not assumed) for the same vocabulary dependency, and the deprecated sibling script
checked for live callers. File scope was deliberately left unset for plan time.

This research re-confirms the dispatch's own already-measured evidence by independent
reproduction (bash -x trace, live `--regenerate`/`--prune`/`--print` runs against the actual
BimodalLogic working tree, read-only / `--dry-run` throughout — nothing in that repo was
modified), and extends it with the `--prune` silent-success finding, which the dispatch's EVIDENCE
section did not itself test.

## Findings

### Codebase Patterns

**The fixed section vocabulary is hardcoded in three separate places, all needing the same fix**:
1. `extract_section()` call sites inside `load_existing_sections()` (`roadmap-integration.sh:602-612`)
   — eight literal header strings.
2. `assemble_roadmap()` (`roadmap-integration.sh:388-395`) — the fixed template `printf` that
   reassembles the file; this is what overwrites the stage-based content once the section
   extraction (above) has already returned empty for everything.
3. `extract_preamble()` (`roadmap-integration.sh:360-363`) is vocabulary-agnostic (grabs everything
   between the title line and the first `## ` line) and is **not** part of the defect — it worked
   correctly in the reproduction (the preamble survived in the `--prune --dry-run` diff above the
   first `-## Next batches` hunk).

**The grep-under-pipefail shape exists at exactly one call site**, `covered_ids_from()`
(`roadmap-integration.sh:382-386`). An audit of every other `grep`/pipeline in the script
(`render_open_work`, `render_coverage_appendix`, `status_token`, `parse_retention`,
`count_terminal_task_lines`, `count_pruned_next_ids`, `prune_open_work_body`, `prune_next_body`,
`mode_regenerate`'s own `RUNS_COUNT` line) shows every other no-match-prone `grep`/`jq -e` call is
already guarded: `RUNS_COUNT="$(grep -cE '^/orchestrate ' <<<"$authored_next" || true)"` explicitly
suffixes `|| true`; every `jq -e` membership test in `status_token`/`count_terminal_task_lines`/
`count_pruned_next_ids`/`render_coverage_appendix` is wrapped in `if`/`if !`, which `set -e`
already exempts. `covered_ids_from()` is the **only** unguarded case — confirming the dispatch's
own claim that this is a single-call-site defect, not a systemic pattern, though the audit itself
(not just patching the one site) is still the right discipline per the dispatch's sub-fault 2
framing.

**`--print`'s independence is structural, not incidental.** `mode_print()`
(`roadmap-integration.sh:338-341`) calls only `render_open_work`/`render_coverage_appendix '[]'`,
which read `active_tasks_json`/`active_topics_json`/`WAVE_OF` (all derived from `state.json` and
`generate-task-order.sh --print`, never from `$ROADMAP_PATH`) and the `RETAIN_*` maps, which stay
globally empty outside `--regenerate`'s `parse_retention` call. `roadmap-update.md`'s own
documented promise ("`--print` ... Never touches: `specs/ROADMAP.md` (not even read)") is
accurate and was reconfirmed by running it against the live file with no `-f`/read error and
correct tasks/topics counts in the stderr marker.

**`--prune`'s crash-free silent destruction**, reproduced verbatim (truncated; full diff was
captured during research):

```
$ cd ~/Projects/BimodalLogic && bash .claude/scripts/roadmap-integration.sh --prune --dry-run
--- specs/ROADMAP.md
+++ /tmp/tmp.bKdzrHp4AK
@@ -11,259 +11,18 @@
-## Next batches
+## Goal
...
-## Maintenance
...
-## Related
...
+## Unfiled observations (none worth a task yet)
<!-- roadmap-generation mode=prune tasks=53 topics=10 runs=0 pruned=0 retained=0 -->
$ echo $?
0
```

Mechanism: `mode_prune()` calls the same `load_existing_sections()` as `--regenerate`, so
`RM_GOAL`/`RM_GATE`/.../`RM_OBS` are all empty for the same header-mismatch reason. But
`prune_open_work_body("")` and `prune_next_body("")` (its two body-transform functions) are plain
`awk` scripts over empty input with no `grep`/pipefail-fatal step — they simply emit nothing and
return 0. `assemble_roadmap()` then reassembles the eight sections, all empty, and
`write_or_diff()` (in `--dry-run`) prints the diff and exits 0. **No code path in `--prune`
currently detects "none of my sections exist in this file" as an error at all** — it is
indistinguishable, from the script's own perspective, from a legitimately mostly-empty roadmap.

### External Resources

Not applicable — this is a pure codebase/shell-semantics defect with a local regression fixture;
no external library or documentation was consulted beyond `bash`'s own `pipefail`/`set -e`
semantics (verified empirically via `bash -x`, not from memory): under `pipefail`, a pipeline's
exit status is the rightmost non-zero status among its stages (here, the second `grep -oE`
matching nothing on empty input, since `sort`/`jq` both exit 0 regardless); a bare (non-`local`)
assignment statement whose right-hand command substitution's pipeline fails is **not** exempted by
`set -e`'s usual carve-outs (it is not the condition of `if`/`while`/`until`, not an operand of
`&&`/`||`, not prefixed with `!`) — so the shell exits immediately once the assignment is made.

### The Regression Fixture's Own Stated Intent

BimodalLogic's live `specs/ROADMAP.md` (current HEAD `555c34c34`, and already present in the
`79f3fe7cc` fixture commit the dispatch names) contains, verbatim:

> **## Maintenance** — "This file is hand-curated prose and is not mechanically parsed or
> annotated" (`79f3fe7cc`'s wording) / "Hand-curated prose, not mechanically parsed or annotated"
> (current HEAD's wording)

> **## Related** — "`.claude/context/formats/roadmap-format.md` — the legacy parseable structure,
> superseded above" (current HEAD only; absent from `79f3fe7cc`)

Between the two commits examined, the top-level header text itself already changed by hand:
`## Run order at a glance` → `## Next batches`; `## Stage 1 — Decidability of L⁺ (preempts
everything)` → `## Stage 1 — Decidability of L⁺`; two new per-stage bullet items (751, 752) were
added inline. None of this breaks anything mechanically (no grammar currently depends on these
exact strings outside the fixed 8-section vocabulary that doesn't match either version) — it is
evidence of *degree of stability*, offered for the plan's judgment on scope, not a re-litigation
of the settled ruling that the roadmap stays generated and `--regenerate` stays live.

BimodalLogic's own task list independently already carries task **752**, titled in its own Stage 3
bullet as *"the silent `roadmap-integration.sh --regenerate` abort"* — i.e., the target repo has
already filed its own local tracking item for this exact defect, corroborating the dispatch's
EVIDENCE section from the other side.

### Caller-Contract State (context, not in file scope for 371)

`roadmap-update.md`'s "No Live Caller Yet" section is stale: it states `roadmap-integration.sh`
"has no live caller" and names a hypothetical future wiring, but
`conclusion-stage.md:344` (`Step 5 — Roadmap update`) already calls
`bash .claude/scripts/roadmap-integration.sh --regenerate` unconditionally on every
`/orchestrate` conclusion stage, with `--prune` explicitly excluded from that call site "per this
task's D3" (an idempotent-regenerate-only policy — a policy whose idempotence assumption this very
defect violates on an unrecognized vocabulary). This exact gap is task 372's Gap 2(a); it is not
addressed here and `roadmap-update.md`/`conclusion-stage.md` are both out of this task's file
scope per its own "NOT IN SCOPE" section.

### Deprecated Script

`agent-system/extensions/core/scripts/deprecated/roadmap-integration.sh` exists. A grep across
every `agent-system/extensions/` reference to `roadmap-integration.sh` that is *not* inside the
`deprecated/` path itself returns: the manifest, `index-entries.json`, the live script (self-doc),
`orchestrate-conclusion-aggregate.sh` (a comment only, naming the shared no-match-as-error
discipline), the two test files, `utility-scripts-inventory.md`, `roadmap-update.md`, and
`roadmap-format.md`. None resolve the `deprecated/` copy. The inventory doc itself states the live
script is "Fresh replacement for the quarantined `scripts/deprecated/roadmap-integration.sh`, not
a restoration of it." Confirmed: no caller resolves the deprecated copy.

## Decisions

- Treated the dispatch's EVIDENCE section as authoritative for sub-faults 1 and 2 and
  **re-confirmed by independent reproduction** (bash -x trace against the live BimodalLogic tree)
  rather than re-deriving from first principles — per the dispatch's own instruction.
- Extended testing to `--prune` and `--print` as the dispatch explicitly asked ("CONFIRM rather
  than assume"), using `--dry-run`/read-only invocations against the real BimodalLogic working
  tree so no destructive write occurred during research.
- Did not attempt to design the fix's exact code shape (e.g., the specific two-vocabulary
  detection mechanism sketched under Recommendations) as a committed decision — that is plan-time
  work. This report surfaces the self-declared "hand-curated, not mechanically parsed" / "legacy
  ... superseded" evidence and the observed header drift as load-bearing facts for that design
  choice, without re-litigating the settled "roadmap stays generated" ruling.
- Did not touch `roadmap-update.md` or `conclusion-stage.md` (task 372's territory) despite
  finding the stale "no live caller" claim, consistent with this task's explicit "NOT IN SCOPE".
- Logged both novel findings (the `--prune` silent-destruction reproduction, and the fixture's
  self-declared non-mechanical intent plus header drift) to `issues.jsonl` as they were confirmed,
  per the dispatch's Issue Log instruction (`iss_1791591951895_UGC6Ej`, `iss_1791591965521_hlSikc`).

## Recommendations

1. **Fix sub-fault 1 (silent death) directly**: move the `<!-- roadmap-generation ... -->` stderr
   marker emission so it fires on every exit path, not just the fall-through success path at the
   bottom of the file — e.g. via a `trap ... EXIT` that prints the marker with whatever counters
   were last set (defaulting `RUNS_COUNT`/`PRUNED_COUNT`/`RETAINED_COUNT` to their already-present
   `0` initializations, and adding a `status=ok|error` field or a distinct marker variant on the
   error path) rather than relying on the script reaching its last lines unharmed. Any exit-path
   fix must be verified to still print on a clean `--print`/`--regenerate`/`--prune` run (the
   existing `test-roadmap-generation.sh` suite presumably already pins the marker's current
   shape — re-run it, don't just read it).
2. **Fix sub-fault 2 (the one unguarded pipe)** at `covered_ids_from()`: the minimal fix is
   appending `|| true` to the pipeline (matching the pattern already used two lines above it for
   `RUNS_COUNT`) or rewriting the leading `grep -E` as `grep -E ... || :` before the rest of the
   pipe. Re-verify afterward that no other call site needs the same treatment (the audit in
   Findings above found none, but the plan/implementation phase should re-run that audit after any
   refactor rather than trusting this report's snapshot).
3. **Fix sub-fault 3 (permanent destructive-overwrite refusal)**: add a vocabulary-recognition
   gate, checked once near the top of `mode_regenerate()`/`mode_prune()` right after
   `load_existing_sections()` (or inside it), that compares the existing file's actual `## `
   headers against the vocabulary(ies) the script knows how to round-trip and **refuses loudly**
   (named reason, non-zero exit, no write) when none match — this is the permanent property
   sub-fault 3 asks for, independent of how many vocabularies end up supported.
4. **Scope decision for the planner**: given the regression fixture's own declared
   "hand-curated, not mechanically parsed" intent and its already-observed header drift (see
   Findings), consider teaching the generator a **second, narrower vocabulary** rather than a full
   structural parse of the Stage N prose: recognize a `## Run order at a glance`-or-similar header
   whose body is a fenced `/orchestrate ...` block (structurally identical to the existing `## Next`
   Run Grammar this script already parses/emits) as the one genuinely mechanically-regenerable
   piece, and treat everything else in a stage-based file (preamble, every `## Stage N`, "Not
   scoped as tasks", "Maintenance", "Related") as a single opaque authored blob retained
   byte-for-byte. This keeps `--regenerate` "real" (satisfying the settled ruling) without
   committing to parsing free-form bullet prose whose header text itself already changed twice in
   this file's short history. A header-set membership test (e.g., "exists a `^## Stage \d+`
   header") is safer against cosmetic renames than matching the exact current header strings.
   This is a recommendation, not a decision — the planner should weigh it against the alternative
   of refusing loudly on this file unconditionally and only round-tripping the original 8-section
   vocabulary (which would make `--regenerate`/`--prune` permanently no-ops on BimodalLogic's
   roadmap specifically, while still satisfying "do not retire --regenerate" globally).
5. **Update `roadmap-format.md`** regardless of which scope option 4 resolves to: the task's own
   "WHAT IS OWED" section requires the generation contract to describe whatever layout(s) the
   generator now emits — a generator/spec disagreement is explicitly named as the precondition
   that produced this defect, so closing that gap is not optional cleanup.
6. **`--prune` needs the same gate as `--regenerate`** (recommendation 3 covers both mode
   entry points) — do not fix `--regenerate`'s crash alone and leave `--prune`'s silent
   exit-0 destruction unaddressed; the live reproduction above shows it is the more dangerous of
   the two on this exact fixture.
7. **No action needed** on `scripts/deprecated/roadmap-integration.sh` (confirmed dead, no
   caller) or on `--print` (confirmed structurally unaffected) beyond what file-scope setting at
   plan time already anticipates.

## Risks & Mitigations

- **Risk**: A fix that only patches `covered_ids_from()` and the stderr-marker path (sub-faults 1
  and 2) without adding the vocabulary-recognition refusal (sub-fault 3) would make `--regenerate`
  *succeed* on BimodalLogic's file the same way `--prune` already does today — i.e., it would stop
  crashing and start silently destroying content instead, which is strictly worse than the current
  loud crash. **Mitigation**: sequence the fix so sub-fault 3's refusal gate lands no later than
  sub-fault 2's pipe fix; do not ship one without the other.
- **Risk**: Teaching the generator a second vocabulary that tries to faithfully round-trip the
  Stage N bullet prose risks being fragile against the kind of hand-edit drift already observed
  twice in this file's recent history, producing a new generation of "the generator doesn't
  recognize my headers" incidents on the very file it was just taught. **Mitigation**: see
  Recommendation 4 — scope the second vocabulary to the one structurally stable piece (the
  Run-order/Next-batches fenced `/orchestrate` block) and treat the rest as an opaque retained
  blob, rather than attempting per-task status-token extraction from free prose that has no fixed
  grammar.
- **Risk**: `--max-tasks`/coverage-appendix behavior and the `## Next` Run Grammar's exact regex
  (`^/orchestrate ([\d, ]+)(\s{3}# (.+))?$`) assume no leading `# Stage N` comment lines inside the
  fence — but BimodalLogic's fenced block *does* contain inline `# Stage 1 — ...` comment lines
  separating groups of `/orchestrate` lines (see the Run order code block quoted in Findings).
  Any implementation that reuses the existing Next-Grammar line regex verbatim must account for
  these comment lines (currently they would simply fail to match `^/orchestrate `, which is
  harmless for extraction but means they'd be silently dropped on a round-trip unless explicitly
  preserved). **Mitigation**: flag this at plan time; it is a concrete new parsing requirement, not
  present in the original 8-section `## Next` grammar.
- **Risk**: Fixing the stderr-marker-on-every-path promise via a `trap ... EXIT` could change
  the marker's emitted field values on an error path in a way existing callers
  (`orchestrate-conclusion-aggregate.sh`'s stated reliance on counts, per `roadmap-update.md`)
  don't expect. **Mitigation**: the existing marker format already has five numeric fields; an
  error-path marker should either reuse them at their already-present `0` defaults or add a
  clearly-named new field — this is a format decision for `roadmap-format.md`'s own "Stderr
  Marker" section (recommendation 5), not a silent behavior change.

## Context Extension Recommendations

- **Topic**: cross-repo generator robustness / closed-vocabulary section parsing under hand-edit
  drift.
- **Gap**: no existing context file documents the general pattern this defect exemplifies — a
  mechanically-generated section grammar silently producing empty extraction results when a
  target repo's hand-maintained file drifts away from the expected header vocabulary, with no
  built-in detection. `roadmap-format.md` documents *this* generator's vocabulary but not the
  general failure mode.
- **Recommendation**: after this task's fix lands, consider whether
  `context/patterns/jq-escaping-workarounds.md`-style general-pattern documentation (a short
  pattern note under `context/patterns/`) is warranted for "closed-vocabulary section extraction
  must fail loudly on total non-match" as a reusable lesson for any future per-repo generator
  (`task-order-format.md`'s sibling script is the most obvious next place this could recur, per
  `roadmap-format.md`'s own cross-reference to it as a "structurally parallel sibling contract").
  Not filed as a task here — left as a suggestion for the planner/implementer to judge once the
  concrete fix shape is known.

## Appendix

### Search queries / commands used

- `jq`/`grep` over `specs/state.json` and `specs/TODO.md` to locate task 371's own record and slug.
- Full `Read` of `roadmap-integration.sh` (691 lines) and `roadmap-format.md` (164 lines).
- `git show 79f3fe7cc:specs/ROADMAP.md` and current-HEAD `specs/ROADMAP.md` in
  `~/Projects/BimodalLogic`, diffed by inspection for header drift.
- `bash .claude/scripts/roadmap-integration.sh --regenerate --dry-run` (exit 1, zero output) and
  under `bash -x ... 2>trace.log` (confirmed crash site) against the live BimodalLogic tree.
- `bash .claude/scripts/roadmap-integration.sh --prune --dry-run` (exit 0, full destructive diff
  captured) and `--print` (exit 0, correct output, stderr marker present) against the same tree.
- `grep -rln "roadmap-integration\.sh" agent-system/extensions/` filtered against `/deprecated/`
  to confirm no live caller of the deprecated copy.
- `grep -n "roadmap-integration" conclusion-stage.md orchestrate-conclusion-aggregate.sh
  postflight-tool-restrictions.md` to locate and confirm the actual Step 5 live caller.

### References

- `agent-system/extensions/core/scripts/roadmap-integration.sh`
- `agent-system/extensions/core/context/formats/roadmap-format.md`
- `agent-system/extensions/core/context/patterns/roadmap-update.md`
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` (Step 5, lines ~335-350)
- `agent-system/extensions/core/scripts/deprecated/roadmap-integration.sh` (confirmed dead)
- `~/Projects/BimodalLogic/specs/ROADMAP.md` (regression fixture, both at `79f3fe7cc` and current
  HEAD `555c34c34`)
- Issue log entries: `iss_1791591951895_UGC6Ej` (the `--prune` silent-destruction reproduction),
  `iss_1791591965521_hlSikc` (the fixture's self-declared non-mechanical intent and header drift)
