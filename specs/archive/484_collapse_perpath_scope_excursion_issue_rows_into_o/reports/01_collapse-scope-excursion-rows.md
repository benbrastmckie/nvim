# Research Report: Task #484

**Task**: 484 - Collapse per-path scope-excursion issue rows into one record per drop event
**Started**: 2026-11-22T00:00:00Z
**Completed**: 2026-11-22T00:00:00Z
**Effort**: medium
**Dependencies**: Serialize behind #430, #446, #469 (file_scope overlap on the same two emitter
scripts and their test suites — see Risks & Mitigations)
**Sources/Inputs**: - Codebase (agent-system/extensions/core/scripts/, context/formats/,
context/standards/), repo-wide grep enumeration, existing issues.jsonl corpus
**Artifacts**: - specs/484_collapse_perpath_scope_excursion_issue_rows_into_o/reports/01_collapse-scope-excursion-rows.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The existing `tags` seam on `issue-record.sh`'s schema already has a documented, unused
  write-side collapse convention (`tags.occurrence = {count, first_seen, last_seen}` via
  `--tags-json`) that `context/formats/issue-log.md` explicitly names as applicable to "a single
  dispatch's scores of same-class 'scope excursion' rows." No consumer has ever actually used it.
  This task is that convention's first real caller, extended with a full `tags.dropped_paths`
  array to satisfy the no-suppression requirement (the documented `{count, first_seen,
  last_seen}` shape alone would not retain the individual paths).
- **Zero changes are needed to `issue-record.sh`'s CLI/schema** and **zero changes are needed to
  `orchestrate-conclusion-aggregate.sh`'s grouping pipeline**. Both already treat `tags` as an
  open, unvalidated object and group/count by JSONL *line*, not by path — so writing fewer,
  richer lines at the two emitters is suffiicent on its own to fix the aggregate-dominance
  symptom, with no read-side code change required.
- The fix is emitter-side only, at exactly two call sites: `scripts/git-commit-phase.sh` (~line
  779, inside `for f in "${files_touched[@]}"`) and `scripts/git-commit-scoped.sh` (~line 888,
  inside V10's `for p in "${pathspecs[@]}"`). Both already maintain a per-iteration drop array
  that survives past the loop (`kept_files_touched`'s complement in git-commit-phase.sh needs a
  new sibling array; `containment_dropped` in git-commit-scoped.sh already exists and is read
  again after the loop at line 1398) — the natural change is to move the `issue-record.sh` call
  from inside the loop to once, after the loop, over the accumulated array.
- Recommend a small new shared library (mirroring the existing `engine-written-state-paths-lib.sh`
  / `derived-artifact-probe-lib.sh` precedent both scripts already source) holding one function
  that builds the batched `--tags-json` and fires the single `issue-record.sh` call — this avoids
  duplicating the new call shape's JSON-construction logic at both sites while keeping the
  per-script loop/accumulation logic (which differs: `files_touched` vs `pathspecs`) local to
  each script.
- A third site, `orchestrate-cycle-postflight.sh`'s WORK (h)/(i) "EXCURSION DROPPED" filter,
  confirmed to print per-path stderr notices but **never** call `issue-record.sh` — and this
  asymmetry contradicts an explicit claim in `context/standards/git-staging-scope.md` ("the
  warning and the issue row every site already fires on a drop"). This looks like unintentional
  doc/code drift rather than a deliberate design choice; see Findings for the exact citation and
  Decisions for the recommended disposition.

## Context & Scope

Researched how the `scope excursion` issue-log class is currently emitted, why a single
multi-file drop event produces one `issues.jsonl` row per dropped path, and what write-side and
read-side changes would collapse that into one row per drop event while keeping every dropped
path recoverable. Per the dispatch's explicit non-goals, this research takes no position on the
containment predicate's calibration (#430/#446), infrastructure-path allowlisting (#469), or
class-vocabulary normalization (#477); it only researches the *recording* shape of a drop that is
already decided.

## Findings

### Codebase Patterns

**Exactly two emitters of class `scope excursion`, confirmed by two independently-shaped
searches.** Pattern A (`grep -rn '--class "scope excursion"' scripts/ --include="*.sh"`,
excluding `tests/`) finds only `scripts/git-commit-phase.sh:779` and
`scripts/git-commit-scoped.sh:888`. Pattern B (`grep -rn "issue-record.sh"` across the same tree,
excluding `tests/`, then inspecting every `--class` literal and every `issue_args+=(--class ...)`
dynamic-array build in `orchestrate-cycle-postflight.sh` and `orchestrate-cycle-plan.sh`) finds no
third site whose `--class` value is, or is dynamically set to, `"scope excursion"` — every other
call site in those two files uses a different literal class (`orchestration defect`,
`resource/OOM including misdiagnosis`, `cost-forced exclusion or substituted verification`,
`source store excursion`, etc.). The two patterns agree: the dispatch's "exactly two emitters"
claim is confirmed exhaustively, not just spot-checked.

- `git-commit-phase.sh`'s loop (`for f in "${files_touched[@]}"`, starting ~line 617) builds
  `kept_files_touched` for admitted paths and, in the `else` branch (~line 761-782), calls
  `warn()`, then `issue-record.sh --class "scope excursion"`, then
  `propose_file_scope_addition()` — all three unconditionally, once per dropped path, inside the
  loop body. There is currently no array accumulating *only* the drops (as opposed to the kept
  set); one would need to be introduced (e.g. `dropped_scope_excursion=()`), appended to in that
  same `else` branch, and consumed once after `files_touched=("${kept_files_touched[@]}")`.
- `git-commit-scoped.sh`'s V10 containment guard, inside `for p in "${pathspecs[@]}"` (loop opens
  line 814), appends every drop to `containment_dropped` (declared line 764) *and* calls
  `issue-record.sh` inline (~line 887-890), per pathspec. Unlike the first script,
  `containment_dropped` **already survives past the loop** — it is read again at line 1398 for
  the exit-7 decision. This makes `git-commit-scoped.sh` the easier of the two sites to convert:
  the accumulation already exists, only the `issue-record.sh` call needs to move from inside the
  loop to a single post-loop call over `containment_dropped`.
- A **sibling, out-of-scope class with the identical defect shape**: `git-commit-phase.sh`'s
  "REPOSITORY CLASSIFICATION" block (lines ~533-559), which runs *before* the Containment
  Self-Check, emits `--class "source store excursion"` once per dropped path from inside its own
  `for f in "${files_touched[@]}"` loop. This is textually and semantically the same per-path
  fan-out problem, under a different class name. The dispatch frames its required outcomes
  entirely around the `scope excursion` class (123 entries, "exactly TWO emitters" of *that*
  class); `source store excursion` is not named as in scope and should not be folded in here —
  flagging it only as a related finding for a possible future, separately-scoped task.

**The `tags` seam already documents the exact mechanism this task needs, unused until now.**
`context/formats/issue-log.md`'s "Occurrence Collapse" section (lines ~188-208) specifies: a
caller that already knows a repeated event's count *before its first `issue-record.sh` call*
writes exactly one line carrying `tags.occurrence = {count, first_seen, last_seen}` via the
existing, already-general `--tags-json` flag — "needs no schema change and no writer change."
The doc's own worked example names this exact scenario: "the same convention that collapses a
run of byte-identical Sapience 503 bodies into one entry also collapses a single dispatch's
scores of same-class 'scope excursion' rows into one entry, as long as the caller itself already
knows the count before its first call." Both emitter loops *do* know the full drop set before
any `issue-record.sh` call would need to fire, once restructured to accumulate-then-emit — this
is precisely the precondition the doc's own convention requires.

Searching for existing *users* of this convention (`grep -rln "tags.occurrence\|--tags-json"`)
found it documented but **never actually consumed** anywhere in the codebase.
`orchestrate-cycle-postflight.sh:1595` has a comment explicitly declining to use it at one call
site because "it serves a caller that already knows a repeat count before its first call, which
this call site does not" — confirming the convention's precondition is understood codebase-wide,
and confirming this task's two emitters (which *do* satisfy that precondition, once restructured)
would be the convention's first real caller.

**The documented `tags.occurrence` shape alone does not satisfy this task's no-suppression
requirement.** `{count, first_seen, last_seen}` retains only a count and two timestamps — not the
set of paths. The dispatch is explicit: "the full set of dropped paths must remain recoverable
from the record, per issue-log.md's no-suppression posture." Recommendation: extend the
`tags` object at these two call sites with a sibling key, e.g. `tags.dropped_paths` (the full
JSON array of every dropped path for that one event), alongside `tags.occurrence.count`
mirroring the array's length for quick scanning. `tags` is validated by `issue-record.sh` only as
`type == "object"` (no interior-shape validation) — see `issue-record.sh:259`, and
`issue-log.md`'s own "The `tags` Seam" section confirms core "neither validates its interior
shape nor depends on any key inside it." Adding a new key is therefore not a schema change to
`issue-record.sh` at all.

**`issue-record.sh` needs no CLI or schema change.** Its five hard-required args
(`--task-dir`/`--task`, `--kind`, `--class`, `--severity`, `--what-happened`) and its existing
optional `--tags-json` already cover everything the collapsed shape needs. The one
`what_happened` string per batched call should name the count and point at `tags.dropped_paths`
rather than list every path inline (keeping the free-prose field readable at any N), e.g.:
`"git-commit-phase.sh dropped 20 paths from a phase commit pathspec: not contained in this
task's declared file_scope; see tags.dropped_paths for the full list."`

**`orchestrate-conclusion-aggregate.sh` needs no read-side change either.** Its grouping pipeline
(lines ~334-357) does `group_by(.class | canon_class($class_aliases))` over raw JSONL *lines*,
builds `citations` from `{task, entry_id}` pairs — one per line in the group — caps rendering at
10 with an explicit `citations_remainder` count, and computes `severity_max` by scanning
`.severity` across the group (today always `minor` for this class, unaffected by the change).
None of this logic references path counts; it is already schema-tolerant of an open `tags`
object with arbitrary new keys. Reducing 123 lines (today's measured volume for this class in one
aggregate run) to however many *distinct drop events* actually occurred directly fixes the
"5x every other class combined" symptom, because the aggregate's dominant signal today is literal
line count, not path count. A reader wanting the exhaustive path list for a specific event opens
that event's own `entry_id` in its task's `issues.jsonl` and reads `tags.dropped_paths` — the
full set stays recoverable, just not inline in the aggregate's own citation list (which already
truncates at 10 regardless, today and after this change).

**`issue-grouping.sh` is NOT a consumer of `issues.jsonl` — the dispatch's Verification section
names the wrong script.** `grep -rln "issues\.jsonl"` across `scripts/`, `context/`, and `docs/`
does not include `issue-grouping.sh` at all; a separate check confirms `issue-grouping.sh` is
never invoked from `orchestrate-conclusion-aggregate.sh`. `issue-grouping.sh` and its caller
`tier-selection.sh` implement the unrelated `/review`-command issue-triage pipeline, operating on
a structurally different schema (`source: review|roadmap`, `file_path`, `severity:
critical|high|medium|low`) than `issue-record.sh`'s `issues.jsonl` schema (`kind`, `class`,
`severity: blocking|costly|minor|none`). **Correction for planning/verification**: the real
read-time consumer to re-verify against existing corpus rows is
`orchestrate-conclusion-aggregate.sh`'s own `group_by` pipeline (and, downstream of it,
`context/contracts/conclusion-stage.md`'s channel-b/c proposal renderer), not `issue-grouping.sh`.

**Existing corpus is small and will remain parseable without any migration.** This repository's
own `specs/*/issues.jsonl` currently carries 8 `scope excursion` rows across 6 task directories
(via `grep -rh '"class":"scope excursion"' specs/*/issues.jsonl | wc -l` and the directory-count
variant). Every required field stays unchanged in shape; only a new, previously-absent `tags` key
is introduced at new write time. Pre-existing single-path rows (with `tags: {}` or no
`dropped_paths` key) remain fully valid JSON, group by `class` exactly as before, and need no
backfill — satisfying Verification item 3 ("a schema change must not strand the existing
corpus") because this is additive, not a schema change.

**Existing tests tolerate the new shape without modification, but do not yet test it.**
`scripts/tests/test-git-commit-phase.sh` Case 16 (and others) asserts only
`grep -q "scope excursion" issues.jsonl && grep -q "<path>" issues.jsonl` — a substring test that
will still pass once the path moves from `what_happened` into `tags.dropped_paths`, since both
are plain JSON text on the same line. No existing case asserts "exactly one line" or exercises a
multi-path drop in a single call — this is genuinely new coverage the plan must add, matching
Verification item 1 exactly ("a multi-path drop asserts exactly one issue row naming every
dropped path").

**Third-site asymmetry: likely doc/code drift, not a deliberate design choice.**
`orchestrate-cycle-postflight.sh`'s WORK (h)/(i) block (the per-cycle whole-task completion
commit) computes `excursions_json` (WORK h) and, in WORK (i)'s per-path loop (lines ~2088-2099),
prints `"EXCURSION DROPPED: '${f}' ... Containment predicate: drop-and-warn, never refuse."` to
stderr for every dropped path — confirmed by `grep -n "EXCURSION DROPPED"` returning only these
two echo sites, neither adjacent to any `issue-record.sh` invocation. Yet
`context/standards/git-staging-scope.md`'s "Three Containment sites, not one" section explicitly
states, describing Site 2's `proposed_file_scope` deposit: "This changes nothing about the
predicate or the drop-and-warn posture at this or either of the other two sites — the deposit is
additive to, and never a substitute for, **the warning and the issue row every site already
fires on a drop**." That sentence asserts parity across all three sites that the code does not
have — Site 1 (postflight) fires the warning but never the issue row. Two live possibilities, to
be decided at plan time: (a) the doc sentence is stale/wrong and should be corrected to describe
only two sites as issue-row-emitting, or (b) Site 1 should gain its own batched `issue-record.sh`
call for genuine three-site parity (which would also need the same collapse treatment, since WORK
(i)'s loop can equally drop many paths in one cycle). Nothing in the dispatch's required outcomes
mandates picking (b) — the problem statement's "exactly TWO emitters" language is about the
`scope excursion` class as it exists today, and this task's required outcomes are scoped to
collapsing those two. Recorded here as the dispatch asked ("confirm whether that asymmetry is
deliberate") rather than decided; the evidence points toward unintentional drift.

### External Resources

Not applicable — this is a pure in-repo tooling/logging-shape question with no external library
or API surface involved.

## Recommendations

1. **Representation (Required Outcome 1)**: one `issue-record.sh` call per drop event, with
   `--tags-json` carrying `{"dropped_paths": [...], "occurrence": {"count": N, "first_seen": ...,
   "last_seen": ...}}` — the full array, never a bounded sample, because a bounded sample would
   violate the no-suppression requirement (there is no other durable store of the full path list;
   the per-path `warn()` lines go only to stderr/dispatch transcript, not to any queryable
   artifact). `first_seen`/`last_seen` collapse to the same instant for a same-process loop (no
   meaningful time spread within one commit call), so these are a direct, low-cost reuse of the
   already-documented shape rather than new design.
2. **Collapse site (Required Outcome 2)**: emitter-side, at both `git-commit-phase.sh` and
   `git-commit-scoped.sh`, restructuring each per-path loop to accumulate-then-emit-once rather
   than emit-per-iteration. Do **not** push this into `issue-record.sh`'s own CLI contract (the
   existing `--tags-json` seam already covers it with zero schema change) and do **not** attempt
   a read-time-only fix (grouping at aggregate time cannot recover which lines belong to the same
   drop event without an emitter-side marker already present — exactly the architectural reason
   `issue-log.md` frames `tags.occurrence` as a write-side, not read-side, convention). To avoid
   duplicating the new call-construction logic at two sites (the dispatch's own stated concern),
   factor the shared "build `--tags-json`, call `issue-record.sh` once" step into one function in
   a small new library file, sourced by both scripts exactly as `lib/engine-written-state-paths-
   lib.sh` and `lib/derived-artifact-probe-lib.sh` already are today — this is a reuse of an
   existing, already-proven sharing pattern between these same two scripts, not a new
   architectural seam.
3. **Severity/posture (Required Outcome 3)**: no change needed — both emitters already use
   `--severity minor` and drop-and-warn (never refuse); confirmed by direct inspection of both
   call sites. The plan should simply preserve these literals unchanged inside the new batched
   call.
4. **Third-site asymmetry**: surface the `git-staging-scope.md` doc-vs-code mismatch found above
   as an explicit plan-time decision point rather than silently fixing the doc or silently adding
   a new call site; either disposition is small, but picking one is this task's to make, not
   research's.
5. **Verification target correction**: when carrying the dispatch's Verification item 2/3 forward
   into the plan, substitute `orchestrate-conclusion-aggregate.sh`'s `group_by` pipeline for
   `issue-grouping.sh`, which this research found is not actually a consumer of `issues.jsonl`.

## Decisions

- Representation: full `tags.dropped_paths` array + `tags.occurrence.count` mirror, not a bounded
  sample and not a read-time-only grouping scheme — decided above against the no-suppression
  requirement and the architectural reason read-time grouping cannot substitute for a write-side
  marker.
- Collapse site: emitter-side via a small new shared library function, not inside
  `issue-record.sh` and not purely at aggregate read time — decided above against the concrete
  precondition (count known before first call) and the existing sharing precedent between these
  two scripts.
- Scope boundary confirmed: `source store excursion` (same per-path-loop shape, different class,
  same `git-commit-phase.sh`) is explicitly left out of this task's required outcomes, which are
  worded entirely around the `scope excursion` class.

## Risks & Mitigations

- **Serialization risk (already flagged by the dispatch)**: `file_scope` here overlaps #430, #446,
  and #469 on these exact two scripts and their test suites. Landing this collapse concurrently
  with a containment-predicate or allowlist change on the same files/tests risks merge conflicts
  and test fixtures asserting incompatible call shapes at the same lines. Mitigation: serialize
  this task behind those three, exactly as the dispatch's own Serialization Note instructs — this
  research did not re-open that question, only reconfirms the same two files are the shared
  territory.
- **Test fixture drift**: the plan must add new multi-path-drop test cases to both
  `test-git-commit-phase.sh` and `test-git-commit-scoped.sh` (Verification item 1) without
  breaking the existing substring-based assertions in Cases 15/16/19 (git-commit-phase.sh) and the
  V10/Z-series (git-commit-scoped.sh) that already `grep` for a dropped path's literal string in
  `issues.jsonl` — confirmed above that these survive unmodified since the path string still
  appears on the same line, just inside `tags` instead of `what_happened`.
- **Doc drift left unresolved if not explicitly decided**: if the plan does not explicitly pick a
  disposition for the `git-staging-scope.md` "every site already fires" sentence, a future reader
  will re-discover the same contradiction this research found and re-spend the investigation.

## Context Extension Recommendations

- **Topic**: write-side occurrence collapse has a documented convention
  (`context/formats/issue-log.md`'s "Occurrence Collapse" section) but, before this task, zero
  real callers anywhere in the codebase.
- **Gap**: the convention's only worked example is a hypothetical ("Sapience 503 bodies" /
  "scope excursion rows") rather than a citation to a landed implementation — a future reader has
  no concrete call site to copy from.
- **Recommendation**: once this task lands, add a cross-reference from `issue-log.md`'s
  "Occurrence Collapse" section to the new shared library function as the convention's first real
  implementation, so the next caller with a similar precondition has a concrete pattern to copy
  rather than only prose.

## Appendix

- Search queries/commands used:
  - `grep -rn '\-\-class "scope excursion"' scripts/ --include="*.sh"` (Pattern A, excluding
    tests/)
  - `grep -rn "issue-record.sh" scripts/ --include="*.sh"` (Pattern B, excluding tests/, manually
    cross-checked for dynamic `--class` builds)
  - `grep -n "issue_args+=(--class\|issue_args=(--class\|class.*scope" scripts/orchestrate-cycle-postflight.sh scripts/orchestrate-cycle-plan.sh`
  - `grep -rln "issues\.jsonl" scripts/ context/ docs/` (confirms `issue-grouping.sh` absent)
  - `grep -rln "issue-grouping" scripts/ context/ docs/` (confirms only `tier-selection.sh` calls
    it, for the unrelated `/review` schema)
  - `grep -rh '"class":"scope excursion"' specs/*/issues.jsonl | wc -l` and the directory-count
    variant (existing corpus: 8 rows / 6 task directories in this repo)
  - `grep -rln "tags.occurrence\|occurrence.*count\|--tags-json" scripts/ context/` (locates the
    one declining call site's comment in `orchestrate-cycle-postflight.sh:1595`)
- Key files read in full or in relevant part: `agent-system/extensions/core/scripts/git-commit-
  phase.sh`, `.../git-commit-scoped.sh`, `.../issue-record.sh`, `.../orchestrate-conclusion-
  aggregate.sh`, `.../orchestrate-cycle-postflight.sh`, `.../issue-grouping.sh`,
  `.../context/formats/issue-log.md`, `.../context/standards/git-staging-scope.md`,
  `.../context/contracts/conclusion-stage.md`, `.../scripts/tests/test-git-commit-phase.sh`,
  `.../scripts/tests/test-git-commit-scoped.sh`.
