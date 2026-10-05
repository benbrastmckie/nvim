# Research Report: Task #337

**Task**: 337 - Resolve the handoff-field gap: writers omit required `blockers`/`summary`, and a hard HANDOFF VALIDATION FAILED is printed and then dropped with no durable trace
**Started**: 2026-10-05
**Completed**: 2026-10-05
**Effort**: medium (no new files; edits to ~4 existing scripts/docs plus one new Signal A class)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/validate-handoff.sh`,
  `orchestrate-cycle-postflight.sh`, `orchestrate-stage5-gates.sh`, `skill-base.sh`
  (`skill_corroborate_phase_counts`, `skill_orchestrate_append_detected_defect`),
  `system-defect-record.sh`, `hooks/validate-handoff-location.sh`,
  `agents/general-implementation-agent.md`
- Docs: `docs/architecture/handoff-schema.md`, `context/patterns/system-defect-discrimination.md`
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The validator (`validate-handoff.sh`) is correctly strict: it already FAILs when `summary` or
  `blockers` is missing. The defect is entirely downstream — the one live call site that invokes
  it during postflight (`skill_corroborate_phase_counts` in `skill-base.sh:1548`) discards its
  exit code via `bash .claude/scripts/validate-handoff.sh "$handoff_path" >&2 || true` by
  explicit design ("log-only, non-gating producer-defect diagnostic"). The FAIL banner reaches
  stderr and nothing else — no `events.jsonl` row, no `detected_defects` entry, no field on
  `.return-meta.json` or `state.json`.
- Root cause of the omissions themselves: handoff authorship is 100% hand-written JSON per
  per-agent prose ("summary and blockers are BOTH required top-level fields... so write both
  every time" — `general-implementation-agent.md:766-770`). There is no shared composing
  mechanism and no write-time gate. The task's own second confirming instance (task 341) shows
  this prose only worked when the orchestrator additionally nudged that one dispatch by hand in
  its resume message — i.e. prose-reliance is not self-sustaining.
- **Decision: adopt option (i), writer-side obligation**, implemented as a **write-time
  PostToolUse content gate** mirroring the already-proven `hooks/validate-handoff-location.sh`
  pattern (same matcher, same "exit 2 after the write, fix-forward" semantics, same
  `system-defect-record.sh` recorder call) — not a composing-helper script, which an agent could
  simply decline to call and therefore does not meet "cannot be forgotten."
- **Durable trace (mandatory regardless of (i)/(ii)): wire a recorder at the existing discarded
  `|| true`** in `skill_corroborate_phase_counts`, following the `HANDOFF_STALE_OR_ABSENT`
  template already used four times in `orchestrate-cycle-postflight.sh` — this is a textbook
  Class (a) "loud but unactioned" site per `system-defect-discrimination.md`, needing exactly "a
  recorder call added beside the existing banner."
- `sorry_inventory` and `continuation_path` WARNs: **the WARN should go** for both, scoped
  narrowly (not by deleting the checks, by tightening their trigger conditions) — see Decisions.

## Context & Scope

Researched how `.orchestrator-handoff.json` is authored, validated, and consumed across the
research → postflight pipeline, to resolve two coupled defects: (1) required fields (`blockers`,
`summary`) are omitted per-dispatch by hand-authoring agents with no mechanical obligation to
include them; (2) a resulting hard FAIL from `validate-handoff.sh` is printed to stderr and then
has no effect on any durable state, so the task completes anyway via the unrelated
COMPLETION-CLAIM GATE (which only ever reads `phases_completed`/`phases_total`, never the
validator's verdict). A secondary, explicitly coupled question: whether the companion WARNs for
absent `sorry_inventory` and `continuation_path` are genuinely optional (and so should stop
firing) or expected (and belong in whatever mechanism this task establishes).

Out of scope (per the dispatch's explicit non-goal): relaxing `validate-handoff.sh`'s FAIL
checks to make the failure stop appearing. That direction is prohibited and nothing below does
it — the WARN-relaxation decided in this report touches only the two WARN-producing checks, never
the FAIL-producing `status`/`summary`/`artifacts`/`blockers`/`phases_completed`/`phases_total`
required-field checks.

## Findings

### Codebase Patterns

**Why the validator's verdict currently has zero durable effect.**
`skill_corroborate_phase_counts()` (`skill-base.sh:1478-1549`) is called from
`orchestrate-cycle-postflight.sh:648` on every `implemented`-status, handoff-present dispatch:

```bash
cpc_line=$(skill_corroborate_phase_counts "$task_number" "$corroboration_plan_path" "$notice_prefix" "$handoff_file")
```

Inside that function (`skill-base.sh:1543-1548`):

```bash
if [ -n "$handoff_path" ] && [ -f "$handoff_path" ]; then
  # Log-only, non-gating producer-defect diagnostic (D5/B1). Never allowed to influence this
  # function's own return value — guarded with `|| true` ...
  bash .claude/scripts/validate-handoff.sh "$handoff_path" >&2 || true
fi
```

This is a deliberate design (the comment documents the "never allowed to influence" intent for
the *phase-count corroboration* return value, which is correct — a producer-defect diagnostic
should not itself decide phase accounting). But nobody else reads the validator's exit code
either: `orchestrate-cycle-postflight.sh`'s only two outcome-determining reads of the handoff are
`dispatch_status`/`phases_completed`/`phases_total`/`plan_markers_verified`
(`orchestrate-cycle-postflight.sh:613-620`) and the separate, independent
`skill_gate_completion_claim` (3-case gate, documented in `handoff-schema.md:371-426`), which
reads only the two phase-count integers. A handoff with a correct phase count and a missing
`summary`/`blockers` sails straight through Case 2 ("phase accounting present and complete"),
exactly matching both measured incidents (task 190/191 in the first batch; task 340 in the
second).

**This is a known, already-solved shape in this codebase — Class (a) "loud but unactioned."**
`context/patterns/system-defect-discrimination.md`'s detection-point registry names exactly this
pattern as its own class: "Already emits a clear, human-legible signal at the point of
detection, but nothing downstream converts that signal into a durable record... These sites need
a recorder call added beside the existing banner — the diagnosis is already in hand." Four
existing sites in `orchestrate-cycle-postflight.sh` already follow this exact template for the
sibling class `HANDOFF_STALE_OR_ABSENT` (lines 515-527, 569-581, and two more); the clearest to
copy verbatim is lines 515-527:

```bash
if is_live; then
  record_result=$(bash "${SCRIPT_DIR}/system-defect-record.sh" \
    --defect-class HANDOFF_STALE_OR_ABSENT \
    --detecting-site "${detecting_site_prefix}:cycle-postflight-stale-handoff" \
    --task "$task_number" --session "$session_id" \
    --message "handoff mtime $handoff_mtime predates this dispatch window ($dispatch_start_ts)" \
    --attributed-path "$attributed_path" \
    2>/dev/null) || echo "Note: system-defect recording failed (non-fatal)" >&2
  skill_orchestrate_append_detected_defect "$defect_store" "$notice_prefix" \
    "HANDOFF_STALE_OR_ABSENT" "$attributed_path" \
    "${detecting_site_prefix}:cycle-postflight-stale-handoff" \
    "handoff mtime $handoff_mtime predates this dispatch window ($dispatch_start_ts)" \
    "$record_result"
else
  echo "${notice_prefix} [dry-run] would record HANDOFF_STALE_OR_ABSENT (stale) — no write performed." >&2
fi
```

This single call pair writes BOTH durable channels the dispatch asks for in one shot:
`system-defect-record.sh` appends the `event_type: "system_defect"` row to `specs/events.jsonl`
(deduplicated by `{defect_class}:{attributed_path}`), and
`skill_orchestrate_append_detected_defect` appends to the loop-guard/multi-state file's
`.detected_defects[]` array, which the batch output template already renders.

**Attribution is already available at the call site.** `orchestrate-cycle-postflight.sh` is
invoked with `--agent NAME` (`agent_name` variable, set at line 258, consumed at line 1546 for an
unrelated metrics call) — exactly what `system-defect-record.sh --dispatched-agent NAME` needs to
resolve `agent-system/extensions/*/agents/NAME.md` mechanically. This is the correct attribution
target (the dispatched agent authored the malformed JSON; this is not an orchestrator-plumbing
bug), matching the `RECOVERY_DECLINED` row's own precedent ("attributed to the dispatched agent's
own file via `--dispatched-agent`, never to `skill-orchestrate/SKILL.md`").

**Root cause of the omissions: hand-authored JSON, no shared composer, no write-time gate.**
`general-implementation-agent.md:731-770` instructs the agent to write the handoff by hand,
closing with "The handoff validator FAILS on either one missing, so write both every time" — pure
prose, re-read fresh on every dispatch, with no mechanical consequence if skipped. Grep confirms
no composing helper script exists anywhere in `agent-system/extensions/core/scripts/` (only
`validate-handoff.sh` exists; there is no `write-orchestrator-handoff.sh` or equivalent). This
matches the dispatch's own observation (a): the SAME agent (`general-implementation-agent`)
produced both a clean handoff and a defective one in the same batch/session, so the defect is
per-dispatch inconsistency in authorship, not a template bug fixable by editing one agent file's
prose more forcefully.

**The second confirming instance supplies the decisive evidence against prose-only
remediation.** Task 341's handoff was clean *only* because the orchestrator, having just watched
task 340 fail, manually told the agent in its resume message to include `summary`/`blockers`.
That is an existence proof that an instruction can work, immediately followed by proof that it
only works when someone remembers to add it for that one dispatch — which is exactly the
unforgettable-mechanism gap option (i) is meant to close.

**The precedent for a write-time, cannot-be-forgotten gate already exists in this codebase, for
a sibling problem.** `hooks/validate-handoff-location.sh` is a `PostToolUse` hook (matcher
`Write|Edit`) that fires on every write to a file named `.orchestrator-handoff.json`, regardless
of which agent or which dispatch, and:
1. Checks the write landed inside `specs/{NNN}_{SLUG}/` (a content-independent, path-only check).
2. On violation, prints a loud remediation banner to stderr and `exit 2` — PostToolUse runs after
   the write, so this does not prevent the bad file from existing; it surfaces the failure as an
   error the model must act on to fix forward, documented explicitly in the hook's own header.
3. Calls `system-defect-record.sh --defect-class HANDOFF_MISLOCATED ...` unconditionally on
   violation, Signal-B-unresolved (`--attributed-path "unresolved:hooks/validate-handoff-location.sh"`)
   since no dispatched-agent identity is available at a bare PostToolUse hook invocation for a
   `specs/**` path.

This is structurally the exact mechanism needed for required-field enforcement — the only new
work is a second check (required-field presence, i.e. `validate-handoff.sh`'s own logic) added
beside the existing location check, in the same hook invocation.

**Known, already-accepted limitation of this hook class.** Per the hook's own header and
`handoff-schema.md`'s "Path Resolution Contract" section, PostToolUse hooks keyed on
`tool_input.file_path` see only Write/Edit-tool writes; they are structurally blind to a
hypothetical Bash-redirect write (`echo "$json" > "$handoff_path"`), since a Bash tool call's
`tool_input` carries the raw, unexpanded command text, not the resolved path. This codebase
already encountered and resolved this exact tension once: a Bash-redirect handoff-writer helper
function in `skill-base.sh` was *deleted* (not patched around) specifically "closing the coverage
gap by removing the class of writer rather than patching the hook," with the orchestrator-side
stray-handoff sweep named as the mechanism-agnostic backstop for any future Bash-redirect writer.
**Implication for this task**: do not introduce a new Bash-script-driven direct file write as
the write-time enforcement mechanism (that would reopen exactly the gap this codebase already
closed by deletion). The content gate belongs inside the existing Write/Edit-matched hook, not in
a new Bash helper that writes the file itself. A convenience *composing* helper (assembling
correct JSON text for the agent to pass to the Write tool) remains legitimate and is a reasonable
secondary aid, but must never be the enforcement mechanism itself, since nothing stops an agent
from skipping it and hand-writing JSON directly — only the hook, which fires unconditionally on
every actual Write/Edit, satisfies "enforced somewhere that cannot be forgotten per-dispatch."

**`sorry_inventory`/`continuation_path` WARN sites, checked against their documented
consumers** (handoff-schema.md field definitions, cross-checked against `validate-handoff.sh`):
- `sorry_inventory`'s only documented consumers are the (deleted) hard engine's H5 divergence
  audit and `orchestrate-cycle-postflight.sh`'s `implemented)` skeleton-follow-up reporting, which
  the schema doc states explicitly is "a no-op for a base-mode handoff, which never populates
  this field." Core's own standalone hard-mode implementation agent is deleted; core's
  `general`/`meta`/`markdown` task types now resolve *every* implement dispatch (hard or base
  effort flag) to the same base-mode `general-implementation-agent`, which never sets `skeleton`
  or populates `sorry_inventory`. For core, the WARN at `validate-handoff.sh`'s non-skeleton
  branch (`else: log_warn "Optional field absent: sorry_inventory..."`) therefore fires on
  **every single core implement dispatch, unconditionally, forever** — a WARN with zero
  remaining diagnostic value for the population of writers that can actually reach it today
  (cslib/lean hard-mode agents are the only writers for whom the field is ever actionable, and
  `validate-handoff.sh` has no way to know which writer it is looking at).
- `continuation_path`'s "absent" WARN (`validate-handoff.sh`'s block checking
  `continuation_path`/`continuation_context` presence, unconditioned on `status`) fires
  regardless of `status`, even though the field is correctly, schematically absent/null whenever
  `status = "implemented"` (per `handoff-schema.md:340`: "`null` when `status = \"implemented\"`"
  — the overwhelmingly common case). A second, properly status-conditioned check already exists
  further down in the same script (Check 5, "Status/continuation consistency") that correctly
  WARNs only when `status` is `partial`/`blocked` and no continuation pointer is set. The earlier,
  unconditioned check is redundant with — and strictly noisier than — that later, correctly-scoped
  one.

### External Resources

Not applicable — this is a self-contained orchestrator-infrastructure question; no external
library or API is involved.

## Decisions

1. **Adopt option (i): writer-side obligation**, not option (ii) (postflight-side
   normalization). Rationale: normalizing absent `blockers` to `[]` is cheap and arguably always
   correct, but deriving `summary` from `.return-meta.json` post-hoc would make a non-compliant
   handoff silently "pass" with a backfilled value the dispatching agent never actually composed
   as *this* handoff's own completion summary — trading a loud, fixable rejection for a quiet,
   possibly-misleading substitution. It also treats the symptom forever at every future read site
   instead of fixing authorship once at the source, and does nothing to prevent the identical
   omission recurring on the very next dispatch. The measured defect is explicitly "per-dispatch
   inconsistency in hand-authored JSON" — the fix belongs at the point of hand-authoring.
2. **Mechanism for (i): a write-time PostToolUse content gate, not a composing-helper script.**
   Extend (or add a sibling to) `hooks/validate-handoff-location.sh` so that, after its existing
   location check passes, it additionally invokes `validate-handoff.sh`'s required-field logic
   against the just-written content and, on FAIL, emits the same "exit 2, fix-forward" signal
   plus a `system-defect-record.sh` call — reusing the hook class's own already-proven, already
   battle-tested enforcement posture rather than inventing a new one. A composing helper (if added
   at all) is advisory/convenience only, never the enforcement point, since an agent can bypass a
   helper it is merely invited to call but cannot bypass a hook that fires on every Write/Edit to
   the matched filename.
3. **The postflight-side durable trace is mandatory and independent of decisions 1–2.** Wire a
   recorder call at the currently-discarded `|| true` in `skill_corroborate_phase_counts`
   (`skill-base.sh:1548`), following the `HANDOFF_STALE_OR_ABSENT` template verbatim
   (`orchestrate-cycle-postflight.sh:515-527`), under one new Signal A instance,
   **`HANDOFF_VALIDATION_FAILED`** (`validate-handoff.sh` exits non-zero against a dispatch's
   handoff), attributed via `--dispatched-agent "$agent_name"` (available at the
   `orchestrate-cycle-postflight.sh` call site that reaches `skill_corroborate_phase_counts`).
   This is required regardless of how well decisions 1–2 close the writer-side gap going forward,
   because it is the backstop for every handoff that still reaches postflight invalid (hook
   disabled, agent ignored the hook's exit-2 signal, or a handoff written before this change
   exists on disk) and because the dispatch's own text mandates a durable trace "either way."
   The SAME new class name should be reused at the write-time hook site (decision 2) rather than
   minting a second class — both sites detect the identical schema violation, just at different
   points in the pipeline, exactly mirroring how `HANDOFF_STALE_OR_ABSENT` already fires from four
   different sites under one shared class name.
4. **`sorry_inventory`'s absent-WARN: relax, scoped to the already-skeleton-conditioned
   branch.** The WARN is genuine noise for every base-mode writer (the entirety of core's writer
   population today) and the schema doc already documents the field as hard-mode-only. Do not
   delete the FAIL-path skeleton checks (those remain exactly as strict); only silence or
   downgrade the "optional field absent" WARN in the non-skeleton branch, since its absence there
   is the expected, universal case, not an exception worth flagging every time.
5. **`continuation_path`'s absent-WARN: relax by tightening its trigger to `status in
   {partial, blocked}`.** This removes the redundant, unconditioned early check while leaving the
   later, correctly status-scoped Check 5 (which already WARNs exactly when it matters: `partial`
   or `blocked` with no continuation pointer set) fully intact. Net effect: the WARN continues to
   fire in the one case it is actually informative, and stops firing in the ~100% case
   (`implemented`) where absence is schematically correct.
6. **No FAIL-producing check is touched.** `status`, `summary`, `artifacts`, `blockers`,
   `phases_completed`, `phases_total` remain exactly as strict as today — consistent with the
   dispatch's explicit non-goal.

## Recommendations

1. **`agent-system/extensions/core/context/patterns/system-defect-discrimination.md`**: add
   `HANDOFF_VALIDATION_FAILED` as a new (seventeenth) Signal A instance — "a dispatch's
   `.orchestrator-handoff.json` fails `validate-handoff.sh`'s required-field checks (status,
   summary, artifacts, blockers, phases_completed, phases_total)" — naming both detecting sites
   (the write-time hook and the postflight log-only diagnostic) and the dispatched-agent
   attribution rule. File it under "Class (a) — loud but unactioned" in the detection-point
   registry, alongside the existing `HANDOFF_STALE_OR_ABSENT` rows it's modeled on.
2. **`agent-system/extensions/core/scripts/system-defect-record.sh`**: add
   `HANDOFF_VALIDATION_FAILED` to the closed defect-class `case` statement (currently 16 values;
   becomes 17).
3. **`agent-system/extensions/core/scripts/skill-base.sh`** (`skill_corroborate_phase_counts`,
   around line 1543-1548): capture `validate-handoff.sh`'s exit code instead of discarding it;
   on non-zero, surface it in the function's own stdout contract (an added field, e.g.
   `handoff_valid=false`, alongside the existing `phases_completed=... phases_total=...
   plan_markers_verified=...` line) so the caller (`orchestrate-cycle-postflight.sh`) can record
   the defect using its own `$agent_name`/`$session_id`/`$defect_store`/`$notice_prefix` context —
   `skill_corroborate_phase_counts` itself has neither the loop-guard file path nor a clean
   agent-name parameter today, so the recorder CALL belongs at the caller, not inside this
   function; only the signal needs to cross the function boundary.
4. **`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`** (around line
   648-658, the existing WORK (c) corroboration block): read the new `handoff_valid` signal and,
   when false, call `system-defect-record.sh --defect-class HANDOFF_VALIDATION_FAILED
   --dispatched-agent "$agent_name" ...` and `skill_orchestrate_append_detected_defect` —
   copy the `HANDOFF_STALE_OR_ABSENT` block at lines 515-527 verbatim, changing only the class
   name, message, and attribution argument (`--dispatched-agent` instead of `--attributed-path`).
5. **`agent-system/extensions/core/hooks/validate-handoff-location.sh`** (or a new sibling hook
   with the identical matcher/basename-match preamble): after the existing location check passes,
   add a required-field content check — either by shelling out to `validate-handoff.sh "$FILE"`
   directly and checking its exit code, or by re-implementing just the required-field subset
   inline (avoiding a second process spawn) — and on failure, emit the hook's loud-banner + `exit
   2` pattern plus a `system-defect-record.sh --defect-class HANDOFF_VALIDATION_FAILED` call.
   Leave Signal B unresolved (`--attributed-path "unresolved:..."`) at this site exactly as the
   existing `HANDOFF_MISLOCATED` call does, since a bare PostToolUse hook invocation carries no
   reliable dispatched-agent identity — unlike the postflight-side call (recommendation 4), which
   does have `$agent_name` and should use `--dispatched-agent` there instead.
6. **`agent-system/extensions/core/scripts/validate-handoff.sh`**: two narrow WARN-scoping edits,
   per Decisions 4–5 — (a) in the non-skeleton branch, downgrade or remove the unconditional
   "Optional field absent: sorry_inventory" WARN; (b) gate the early, unconditioned
   `continuation_path`/`continuation_context` absence WARN on `status in {partial, blocked}`,
   leaving the later, already-correct Check 5 untouched. Update the script's own `--help` text
   (currently documents both WARNs unconditionally) to match.
7. **`agent-system/extensions/core/docs/architecture/handoff-schema.md`**: record this task's
   ruling on `sorry_inventory`/`continuation_path` (Decisions 4–5) in the field-definition
   sections for those two fields, so a future reader does not re-derive the same question, and
   add `HANDOFF_VALIDATION_FAILED` to the "Handoff Writers" / validator-wiring narrative near the
   existing "log-only, non-gating" paragraph, correcting it to describe the now-wired recorder.
8. **`agent-system/extensions/core/agents/general-implementation-agent.md`** (and any sibling
   `*-implementation-agent.md`/`planner-agent.md` files with the same prose pattern at
   `general-implementation-agent.md:766-770`): no behavioral change is required once the hook
   exists (the hook is the enforcement; the prose becomes a correctness aid, not the sole
   safeguard), but the prose should be updated to mention the write-time gate explicitly, so an
   agent that sees its write rejected understands why, rather than treating the hook's banner as
   a novel, undocumented failure.
9. Optional, lower-priority convenience: a shared JSON-assembly helper agents may call to reduce
   hand-authoring errors in the first place — explicitly NOT the enforcement mechanism (see
   Decision 2), so this can be deferred or dropped from the implementation plan without
   weakening the fix.

## Risks & Mitigations

- **Hook false-positive risk**: a content check added to a write-time hook could reject a
  legitimately-partial intermediate write (e.g., an agent writing a skeleton handoff before
  filling in `summary`). Mitigation: `validate-handoff.sh` is already exercised extensively
  against real handoff shapes; reusing it (rather than a new, independently-derived check) means
  no new false-positive surface is introduced beyond what already exists for the manual
  `bash validate-handoff.sh` invocation agents are already told to expect.
- **Double-counting defects**: the write-time hook and the postflight recorder could both fire
  for the same underlying handoff if the agent never fixes the write-time rejection.
  `system-defect-record.sh`'s own dedup rule (identity key `{defect_class}:{attributed_path}`,
  non-terminal-task suppression) already handles this — no new dedup logic is needed, only
  correct reuse of the one shared class name (Decision 3).
- **Scope creep into the deleted hard-mode machinery**: `sorry_inventory`/`skeleton` validation
  (the FAIL-producing skeleton branch) must not be touched while relaxing the WARN branch — the
  plan phase should scope the `validate-handoff.sh` edit narrowly to the `else` (non-skeleton)
  branch only, verified by a diff review before commit.

## Context Extension Recommendations

None beyond the doc update already captured in Recommendation 7 (`handoff-schema.md`'s own field
definitions) — the two context documents most relevant to this task
(`system-defect-discrimination.md`, `handoff-schema.md`) are current, well-maintained, and already
describe (and will need to continue describing) the exact mechanisms this task extends; no
undocumented topic was discovered that needs a new standalone context file.

## Appendix

Search queries / investigation steps used:
- Read `.dispatch/3.md` in full (task context, scope, explicit non-goal, sites).
- `grep -rn "validate-handoff"` across `agent-system/extensions/core/scripts/` to enumerate every
  call site and confirm there is exactly one live invocation of `validate-handoff.sh`.
- Read `validate-handoff.sh` in full (required-field FAIL checks vs. WARN checks, status/
  continuation consistency logic).
- Read `docs/architecture/handoff-schema.md` in full (Handoff Writers table, field definitions,
  the documented "log-only, non-gating" wiring status, Postflight Boundary).
- Read `context/patterns/system-defect-discrimination.md` in full (Signal A/B predicate,
  detection-point registry's three classes, recursion guard, dedup rule).
- Traced `skill_corroborate_phase_counts` (`skill-base.sh:1478-1549`) and its two call sites
  (`orchestrate-cycle-postflight.sh:648`, `orchestrate-stage5-gates.sh:192`) to confirm exactly
  where the validator's exit code is discarded and what context (`$agent_name`, `$defect_store`,
  `$notice_prefix`) is available at each.
- Read `hooks/validate-handoff-location.sh` in full as the enforcement-mechanism precedent.
- Read `general-implementation-agent.md`'s `.orchestrator-handoff.json` authoring section
  (lines 690-770) to confirm the hand-authored-JSON root cause and the exact prose text that
  currently carries the whole burden of compliance.
