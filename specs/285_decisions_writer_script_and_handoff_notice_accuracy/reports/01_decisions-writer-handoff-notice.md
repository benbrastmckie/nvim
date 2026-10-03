# Research Report: Task #285

**Task**: 285 - Decisions writer script and handoff notice accuracy
**Started**: 2026-10-03T22:07Z
**Completed**: 2026-10-03T22:15Z
**Effort**: Small (two scoped defects; one new ~120-line script, one SKILL.md repoint, one
inventory entry, one conditional in one existing script)
**Dependencies**: None (independent of task 334's concurrent sibling scope — no file overlap)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/docs/architecture/handoff-schema.md`,
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
  `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`,
  `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
  `agent-system/extensions/core/scripts/system-defect-record.sh`,
  `agent-system/extensions/core/scripts/errors-append.sh`,
  `agent-system/extensions/core/scripts/events-append.sh`,
  `agent-system/extensions/core/scripts/lib/task-lookup-lib.sh`,
  `agent-system/extensions/core/scripts/task-lock.sh`,
  `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`,
  `agent-system/extensions/core/context/standards/shell-strict-mode.md`,
  `agent-system/extensions/{lean,nix,nvim}/agents/*.md`
**Artifacts**:
- This report: `specs/285_decisions_writer_script_and_handoff_notice_accuracy/reports/01_decisions-writer-handoff-notice.md`
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- **Defect 1** (no writer for `.decisions.json`): the shape is a FLAT JSON array
  (`handoff-schema.md` lines 962-1001), `orchestrate-build-dispatch.sh:388-392` is the reader and
  silently mishandles a wrong shape (the task 270-owned reader-side defect), and
  `skill-orchestrate/SKILL.md:272` instructs the lead to hand-author this file by cross-reference
  to a different document with no script to call. `system-defect-record.sh` is a directly
  reusable template for the append-pattern; `errors-append.sh`'s flock/atomic-mv discipline is the
  closer precedent since `.decisions.json` (like `errors.json`) is a long-lived, read-many,
  appended-rarely store rather than an append-only log like `events.jsonl`.
- **Defect 2** (handoff notice mislabel): the claim "base-mode research/plan/implement never
  write one" at `orchestrate-cycle-postflight.sh:693` is **false for plan and implement**, and
  the "base-mode" qualifier is a red herring — the correct predicate is **phase**, not **mode**.
  Verified directly against all seven dispatchable agent definition files that mention
  `.orchestrator-handoff.json` (general/lean/nix/nvim research and implementation agents, plus
  the single shared `planner-agent.md`): every **research** agent (general, lean, lean-hard, nix,
  nvim) carries an identical "research agents never write one" section forbidding the write **in
  any mode**; every **implementation** agent (general, lean, nix, nvim) and the **planner** agent
  carry an identical "(orchestrator-mode dispatches)" section **requiring** the write whenever
  `orchestrator_mode: true` — unconditional on hard/base mode. Since every dispatch reaching
  `orchestrate-cycle-postflight.sh` comes from `/orchestrate` (the script's own D1 comment,
  `orchestrate-cycle-postflight.sh:577-583`, confirms every caller is handoff-expected), a
  plan/implement dispatch reaching the `recovered=true` branch with no handoff is an **agent
  contract violation**, not an expected outcome — the opposite of what the current message claims.
  `$phase` is already a validated local (`research|plan|implement`, enforced at
  `orchestrate-cycle-postflight.sh:289-291`) in scope at line 693, so the fix needs no new plumbing.
- **Recommended approach**: branch the line-693 message on `$phase`. For `research`, keep an
  informational (non-RECOVERY) tag — this is the one genuinely expected no-handoff path. For
  `plan`/`implement`, keep the RECOVERY label and raise its substance to reflect that the absence
  is unexpected (the writer should have written one), naming the phase explicitly rather than the
  three-phase generalization the current text uses.

## Context & Scope

Task 285 closes two lead-facing contract-surface defects discovered live in the same session
(`sess_1790791567_96a2e0`, 2026-09-30, in a different repo): one is a documented-but-unimplemented
writer (the lead hand-authored `.decisions.json` wrong and burned two orchestrate cycles before
the cause was found), the other is a postflight notice that simultaneously claims to be a
`RECOVERY` (fault) condition and the expected path, while being factually wrong about which
phases the claim covers. Research was scoped to: (1) locating the exact schema and the exact
prose instruction for `.decisions.json`, confirming no writer script exists anywhere in the
source store; (2) finding a precedent append-one-entry-to-a-JSON-file script to pattern-match
deliverable 1a's new script against; (3) locating `docs/reference/utility-scripts-inventory.md`'s
existing entry format; (4) reading every agent definition file that mentions
`.orchestrator-handoff.json` to establish ground truth for which phases write it and under what
condition, so deliverable 2's correction is evidence-based rather than another guess layered on
the first one.

Out of scope (per dispatch): the reader-side `jq 'length'` type-safety gate at
`orchestrate-build-dispatch.sh:389-392` is explicitly task 270's territory — this task owns
authoring only, and the two should land independently. Also out of scope: the "hard-mode-
implement-only" phrase that appears inside the research agents' own "research agents never write
one" subsection (see Finding 4 below) — it is pre-existing, present identically in five files, and
not the line the dispatch names; flagged here as a related but separately-scoped follow-up, not
fixed in this task.

## Findings

### Codebase Patterns

**Decisions file shape and current (non-)writer** (`handoff-schema.md:962-1001`):
- Shape: a flat JSON array; each entry carries `question`, `answer`, `cycle` (integer),
  `timestamp` (ISO 8601 UTC) — all four required, no wrapper object.
- "Writer" prose (line 990) names "the loop's own branch move" as the writer, additive-only,
  created-if-absent. No script implements this anywhere in the source store — confirmed by a
  full-repo search for any script writing to a path ending in `.decisions.json`; the only hits
  are `orchestrate-build-dispatch.sh`'s **reader** at lines 388-410.
- `SKILL.md`'s Move 4 (`skill-orchestrate/SKILL.md:268-274`) is the sole instruction site: "Append
  each answer to that task's `specs/{padded}_{project}/.decisions.json` per handoff-schema.md's
  'Decisions File Schema' section" — no inline shape restated, forcing a second-file lookup the
  observed failure shows a lead can skip.
- The reader (`orchestrate-build-dispatch.sh:397-411`) is defensive about absence/emptiness
  (`[ -f ... ]`, `decisions_count -gt 0`) but not about *shape*: `jq 'length'` on an object (e.g.
  the observed `{"decisions":[...]}` mistake) returns `1` (one key), passes the `-gt 0` gate, and
  the subsequent `jq -r '.[] | "..."'` call then fails against the object's non-array value —
  this is the reader-side defect task 270 owns; it is cited here only to establish why a malformed
  write is dangerous, not to fix it.

**Precedent scripts for the new writer** (deliverable 1a names `system-defect-record.sh`
explicitly as "the precedent to follow for an append-one-entry-to-a-JSON-file writer" — confirmed
apt, with one refinement):
- `scripts/system-defect-record.sh` (full read) demonstrates the house style end-to-end: a
  `set -euo pipefail` Class A script, manual `while`-loop argument parsing (no `getopt`), fail-
  loud validation of every required argument and of any `--*-json` payload (`jq -e 'type ==
  "object"'` before use), `source lib/common.sh` for `common_repo_root`/`common_session_id`,
  `. deploy-root-guard.sh || exit 1` immediately after (refuses to run from the source store
  itself — "NOT RUNNABLE FROM THE SOURCE STORE" is stated explicitly in its header and is the
  correct posture for the new script too), and delegation to a lower-level appender
  (`events-append.sh`) rather than writing the target file directly.
- However, `system-defect-record.sh` itself does not contain the read-modify-write-under-lock
  logic — it delegates that to `events-append.sh`, which is a **JSONL line-append** (one `jq -c -n`
  object, one `>>`-equivalent append via the script's own atomicity, no read-modify-write of
  existing content). `.decisions.json` is a **JSON array file**, not JSONL, so the closer
  structural precedent for the write mechanics themselves is `scripts/errors-append.sh`'s
  `append` subcommand (full read), which:
  - Holds `flock -x 200` across the entire read -> merge -> validate -> atomic-`mv` sequence
    (`errors-append.sh:262-291`), against a dedicated lock file (`specs/.errors.lock`) sibling to
    the data file (`specs/errors.json`).
  - Lazily creates the file on first use (`errors-append.sh:267-268`) — mirrors handoff-
    schema.md's "creating it if absent" requirement for `.decisions.json` exactly.
  - Validates the **merged** document (not just the delta) against its expected shape before the
    `mv` (`errors-append.sh:280-284`), aborting with the pre-existing file left untouched on any
    failure — the right posture for `.decisions.json` too (never corrupt an existing, valid array
    on a failed append).
  - Builds the appended record via `jq -c -n` (never string concatenation) — the same discipline
    `system-defect-record.sh` and `events-append.sh` both use.
  - The one structural difference `.decisions.json` needs from `errors.json`'s pattern: `errors.json`
    is `{"errors": [...]}` (object-wrapped array); `.decisions.json` is a bare top-level array
    (`handoff-schema.md`'s shape, confirmed above) — so the merge jq is `. += [$entry]` directly on
    the document root, not `.errors += [$entry]`, and the lazy-create default is `[]`, not
    `{"errors": []}`.
- **Task-number-to-task-directory resolution**: the new script's CLI takes `--task N`, not a
  path, so it needs the same number->directory resolution every other task-scoped script uses.
  `scripts/lib/task-lookup-lib.sh` (full read) is the sanctioned, sourceable library for this —
  its own header states it is "the single source of truth for archive-aware task lookup" and
  lists itself as the thing "every consumer sources... rather than hand-copying the jq." Relevant
  functions: `task_lookup_entry <project_number> <state_file>` (active-wins record lookup) and
  `task_lookup_dir <project_number> <project_name> <repo_root>` (resolves to
  `specs/{NNN}_{project_name}`, falling back to the archive path, then to the still-nonexistent
  active path for brand-new tasks — never touches disk). `task-lock.sh:288-318`'s own
  `resolve_task_dir` wraps the same two calls with an additional on-disk `find` fallback and an
  opt-in create mode; since the new script only needs to resolve an **existing** task's directory
  (a decision can only be recorded against a task already mid-lifecycle under `/orchestrate`),
  sourcing `task-lookup-lib.sh` directly (as a handful of scripts already do) is sufficient and
  lighter than invoking `task-lock.sh` as a subprocess.

**Utility-scripts-inventory registration format** (`docs/reference/utility-scripts-inventory.md`,
header read in full): one bullet per script, backtick-quoted path first, one-sentence-to-short-
paragraph description covering purpose, invocation shape, and any notable caveat; several entries
cross-reference a companion doc (e.g. the `validate-return-meta.sh` entry references
`--fix`'s scope and an "Inclusion-criterion note" explaining why a lifecycle-adjacent script still
belongs in this nominally non-lifecycle list). `orchestrate-record-decision.sh` is ALSO lifecycle-
adjacent (invoked from `SKILL.md` Move 4, which is core orchestrate-loop machinery, not a
standalone operator tool) — deliverable 1a explicitly directs registering it here regardless, so
the new entry should carry the same kind of one-line inclusion note the `validate-return-meta.sh`
entry models, rather than silently appearing to violate the file's own stated scope.

### Ground truth for Defect 2: which phases write `.orchestrator-handoff.json`

Full grep across every agent file mentioning `orchestrator-handoff` (`agents/*.md` in core, lean,
nix, nvim extensions — 7 files with substantive sections, read in relevant part):

| Agent file | Section present | Condition to write |
|---|---|---|
| `general-research-agent.md`, `lean-research-agent.md`, `lean-research-hard-agent.md`, `nix-research-agent.md`, `neovim-research-agent.md` | "`.orchestrator-handoff.json` — research agents never write one" | **Never**, in any mode, including `orchestrator_mode: true` |
| `planner-agent.md` (single shared planner for all task types) | "`.orchestrator-handoff.json` (orchestrator-mode dispatches)" | **Always** when `orchestrator_mode: true`, "on success and on a `partial` or `blocked` outcome alike" — no hard/base distinction in the condition |
| `general-implementation-agent.md`, `lean-implementation-agent.md`, `nix-implementation-agent.md`, `neovim-implementation-agent.md` | "`.orchestrator-handoff.json` (orchestrator-mode dispatches)" | Same as planner: **always** when `orchestrator_mode: true`, mode-independent |
| `lean-implementation-hard-agent.md` | Inline writes (sorry_inventory variant), no separate conditional section | Always writes (hard-mode-only agent, so no base-mode comparison applies) |

The write condition in every implementation/planner file is textually identical: "On every
dispatch whose delegation context carries `orchestrator_mode: true`, this agent MUST write
`.orchestrator-handoff.json` before returning... A delegation context that does NOT carry
`orchestrator_mode: true` carries no handoff obligation." This is an `orchestrator_mode` gate, not
a hard/base-mode gate — a base-mode `/orchestrate` plan or implement dispatch sets
`orchestrator_mode: true` exactly as a `--hard` one does (confirmed by this very research
dispatch's own delegation context, which carries `"orchestrator_mode": true` for a `task_type:
meta` dispatch with no `--hard`). So "base-mode ... plan/implement never write one" is false on
the clearest possible evidence: the agents' own contracts require the opposite, unconditionally
on mode.

`orchestrate-cycle-postflight.sh` itself corroborates this independently: its own `--phase`
argument is validated to exactly `research|plan|implement` (lines 289-291), and its D1 comment
block (lines 577-583) states "every caller of this script today is a `dispatch[]` row... Move 2
supplies `handoff_path` to every such row, so every dispatch that reaches this script is, by
construction, handoff-expected" — with `--handoff-expected false` never actually passed anywhere
in the codebase today (confirmed by a full-repo grep: the only three non-comment hits for
`handoff-expected` are the flag's own declaration/validation and one downstream message). So
**every** plan/implement dispatch that reaches this script is, per the agents' own contracts,
expected to have written a handoff — the `recovered=true`-with-no-handoff branch at line 693 is
reachable for plan/implement only when the agent failed to honor its own contract, which is
exactly the kind of fault `RECOVERY`-with-defect-recording exists to flag, not something to wave
off as "expected."

For **research**, the opposite holds unconditionally: no research agent in any extension ever
writes the file, in any mode, so line 693's branch for `phase == research` is the one genuinely
expected, by-design path — informational, not a fault.

The dispatch's own evidence (from the observed session) is consistent with this: seq 4 (plan) and
seq 5 (implement) both show "dispatch_seq match — handoff confirmed as this dispatch's own
report," meaning a handoff WAS present and read on the happy path for those two phases in that
run — not that they "never write one."

### External Resources

None consulted — this is a pure in-repo contract-consistency defect; no external documentation
applies.

## Decisions

- **Script name and location**: `scripts/orchestrate-record-decision.sh`, matching the dispatch's
  own proposed name and sitting alongside its siblings (`system-defect-record.sh`,
  `errors-append.sh`, `events-append.sh`) in `agent-system/extensions/core/scripts/`.
- **Write-mechanics precedent to follow**: `errors-append.sh`'s flock + lazy-create + merge +
  validate-merged-doc + atomic-`mv` sequence, adapted from its `{"errors":[...]}` object wrapper
  to `.decisions.json`'s bare top-level array (lazy-create default `[]`, merge via `. += [$entry]`
  not `.errors += [$entry]`). `system-defect-record.sh` remains the right precedent for the
  *surrounding* shell (argument parsing, validation ordering, deploy-root-guard, source lib/common.sh)
  even though its own write delegates to a JSONL appender rather than performing an array merge
  itself.
- **Task-dir resolution**: source `scripts/lib/task-lookup-lib.sh` and call `task_lookup_entry` /
  `task_lookup_dir` directly, rather than shelling out to `task-lock.sh`, since no locking/
  creation semantics beyond the decisions-file's own flock are needed and the task is always
  pre-existing when a decision is recorded against it.
- **Lock file**: a dedicated `specs/{NNN}_{slug}/.decisions.lock` sibling to the data file,
  mirroring `errors.json`'s own-directory-adjacent `.errors.lock` convention (per-task rather than
  global, since `.decisions.json` is itself per-task).
- **Defect-2 fix shape**: branch the single line-693 message on the already-in-scope `$phase`
  local — informational/non-RECOVERY wording naming "research" explicitly for `phase == research`;
  keep the `RECOVERY:` label for `plan`/`implement`, reworded to state that the absence is
  unexpected for that phase's writer contract (never generalize across all three phases again).
  No new variables or plumbing are required; `$phase` is already validated and in scope at that
  line.
- **Out of scope, flagged only**: the "hard-mode-implement-only" phrase inside the five research
  agents' own "research agents never write one" subsections is a second, smaller inaccuracy
  (implementation writes are mode-independent, not hard-mode-specific) — not touched by this task
  since the dispatch names only the postflight notice; worth a follow-up note for whoever next
  touches those five files.

## Recommendations

1. **Deliverable 1a** — write `scripts/orchestrate-record-decision.sh` per the Decisions section
   above: `--task N --session SID --cycle C --question TEXT --answer TEXT`, flock-guarded
   read-modify-write against `specs/{NNN}_{slug}/.decisions.json` with atomic `mv`, lazy-create
   `[]`, validate the merged array (type + length) before the move, `jq -c -n` record
   construction with the four required fields (`question`, `answer`, `cycle` as a number,
   `timestamp` generated via `common_timestamp_iso`), `set -euo pipefail`, deploy-root-guard
   sourced, non-fatal-call convention documented in the header (mirroring
   `system-defect-record.sh`'s header note). `shellcheck` clean per `shell-strict-mode.md`'s
   Class A admission (no counter idiom, no documented non-`-e` dependency — straightforward fit).
2. **Deliverable 1a (inventory)** — add one bullet to `docs/reference/utility-scripts-inventory.md`
   naming the script, its CLI shape, and a short inclusion-criterion note (it is lifecycle-
   adjacent, like `validate-return-meta.sh`'s entry, but still belongs in this file per the
   dispatch's explicit instruction).
3. **Deliverable 1b** — in `skill-orchestrate/SKILL.md` Move 4 (around line 272), replace "Append
   each answer to that task's `specs/{padded}_{project}/.decisions.json` per handoff-schema.md's
   'Decisions File Schema' section" with an instruction to call
   `scripts/orchestrate-record-decision.sh` once per answered question, with the five arguments.
   Leave `handoff-schema.md`'s "Decisions File Schema" section's shape documentation in place
   unchanged (reference material for readers, per the dispatch) — optionally update its "Writer"
   paragraph's one sentence to name the script as the mechanism (still the loop's own branch
   move, now mediated through a script instead of hand-authored JSON), but this is a nice-to-have
   consistency touch, not a hard requirement of the dispatch's wording.
4. **Deliverable 2** — in `orchestrate-cycle-postflight.sh` at line 693, split the single `echo`
   into a phase-conditional: `phase == research` keeps an informational tag (not `RECOVERY:`)
   stating this is the expected, by-design path for the research writer specifically (never
   writes a handoff, in any mode); `phase == plan` or `phase == implement` keeps the `RECOVERY:`
   label, states plainly that this is unexpected because that phase's writer is contractually
   required to write one on every `orchestrator_mode: true` dispatch, and names the specific phase
   rather than generalizing across all three. No new variables needed — `$phase` is already
   validated (`research|plan|implement`) and in scope. Keep the existing `.return-meta.json`-
   recovery sentence (the part naming `status=${dispatch_status}` and "recovering the dispatch
   outcome from it") verbatim in both branches — only the lead-in label/claim changes.
5. Run `shellcheck` against the new script and the modified `orchestrate-cycle-postflight.sh`
   before considering either deliverable done, per the dispatch's acceptance criterion.

## Risks & Mitigations

- **Risk**: a planner mistakenly makes `.decisions.json`'s shape match `errors.json`'s object
  wrapper (`{"decisions": [...]}`) by over-copying the precedent instead of adapting it to the
  schema's actual bare-array shape. *Mitigation*: this report states the required shape
  explicitly and twice (Findings, Decisions) with the exact schema fields; the plan should include
  an explicit unit check (e.g. `jq -e 'type == "array"'` on the merged document, not
  `.decisions | type == "array"`).
- **Risk**: the Defect 2 fix narrows correctness to "the agents currently say X" rather than the
  structurally guaranteed invariant — if a future extension adds a research agent that forgets the
  "never write one" section, or an implementation agent that forgets the "orchestrator-mode
  dispatches" section, the postflight message would again go stale. *Mitigation*: out of scope for
  this task (which only owns the message's accuracy against the CURRENT, verified-identical
  contract text across all seven files), but worth a comment in the fixed message's surrounding
  code pointing at the agent files as the source of truth, so a future repointing is easy to find.
- **Risk**: concurrent sibling task 334 touches unrelated books-extension files
  (`agent-system/extensions/books/**`) on the same cycle — no overlap with this task's
  `agent-system/extensions/core/**` scope; confirmed no shared files. No mitigation needed beyond
  the standard re-read-before-edit discipline.

## Context Extension Recommendations

- **Topic**: Which-phases-write-the-handoff is documented identically across seven agent files but
  nowhere summarized in one place a script or doc could cite without re-deriving it.
- **Gap**: `docs/architecture/handoff-schema.md` documents the handoff's *shape* in detail but does
  not currently state the per-phase writer predicate (research never / plan+implement always-when-
  orchestrator-mode) as a single callout; a reader (or a future script fix) has to cross-reference
  all seven agent files, as this research did, to derive it.
- **Recommendation**: consider a short "Which Phases Write This File" callout in
  `handoff-schema.md` near its existing handoff-shape documentation, stating the predicate once so
  future fixes (including a future drift in the postflight message) have one canonical place to
  check instead of re-deriving it from the agent roster. Not required for this task's acceptance
  criteria; flagged as a follow-up.

## Appendix

### Search queries / commands used
- `grep -n "Decisions File Schema" -A 60 docs/architecture/handoff-schema.md`
- `grep -n "decisions.json\|Move 4" skills/skill-orchestrate/SKILL.md`
- Full read of `scripts/system-defect-record.sh`
- `grep -n "decisions_count\|jq 'length'" scripts/orchestrate-build-dispatch.sh`
- `grep -n "RECOVERY: no handoff written\|expected outcome for this phase" scripts/orchestrate-cycle-postflight.sh`
- `grep -n "orchestrator-handoff" agents/*.md` (core) and equivalent greps in `../lean/agents/`,
  `../nix/agents/`, `../nvim/agents/`
- Full or targeted reads of `planner-agent.md` (:460-510), `general-implementation-agent.md`
  (:690-765), `general-research-agent.md` (:220-245), and the matching sections of the lean/nix/
  nvim research and implementation agents
- `grep -n "flock" scripts/*.sh`; full read of `scripts/errors-append.sh`
- `grep -n "resolve_task_dir\|task_lookup_dir\|task_lookup_entry"` across `scripts/*.sh` and
  `scripts/lib/*.sh`; full read of `scripts/lib/task-lookup-lib.sh`
- `head -40 context/standards/shell-strict-mode.md`

### References
- `docs/architecture/handoff-schema.md:962-1001` (Decisions File Schema section)
- `skills/skill-orchestrate/SKILL.md:268-274` (Move 4, decisions-append instruction)
- `scripts/orchestrate-build-dispatch.sh:388-411` (reader; task-270-owned type-safety gap at
  :389-392 cited but not fixed here)
- `scripts/orchestrate-cycle-postflight.sh:289-291` (`$phase` validation),
  `:577-583` (D1 handoff-expected-by-construction comment), `:693` (the message to fix)
- `scripts/system-defect-record.sh` (full file; style/validation precedent)
- `scripts/errors-append.sh:240-291` (flock/atomic-mv/merge-validate precedent)
- `scripts/lib/task-lookup-lib.sh` (full file; task-number-to-directory resolution)
- `docs/reference/utility-scripts-inventory.md` (registration format and inclusion-criterion
  precedent via the `validate-return-meta.sh` entry)
- `agents/{general,lean,lean-hard,nix,neovim}-research*-agent.md` and
  `agents/{general,lean,nix,neovim}-implementation*-agent.md`, `agents/planner-agent.md`
  (ground truth for Defect 2)
