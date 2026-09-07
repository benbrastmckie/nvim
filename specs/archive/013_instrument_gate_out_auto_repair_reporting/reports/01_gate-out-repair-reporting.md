# Research Report: Task 13 - Instrument gate-out auto-repair reporting

- **Task**: 13 - Instrument gate-out auto-repair reporting; stop silent in-place artifact mutation
- **Started**: 2026-09-03T17:30:00Z
- **Completed**: 2026-09-03T17:35:00Z
- **Effort**: ~1 hour (research)
- **Dependencies**: None
- **Sources/Inputs**:
  - `agent-system/extensions/core/scripts/command-gate-out.sh` (source-of-truth for the caller)
  - `agent-system/extensions/core/scripts/skill-base.sh` (`skill_validate_task_artifacts`, `skill_validate_artifact`, cross-function global-variable convention)
  - `agent-system/extensions/core/scripts/validate-artifact.sh` (fix/error/warning emission and exit-code contract)
  - `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` (confirms `skill_validate_task_artifacts` has zero existing test coverage)
  - `agent-system/extensions/core/scripts/events-append.sh`, `system-defect-record.sh` (existing durable-reporting conventions)
  - `agent-system/extensions/core/context/patterns/skill-postflight-flow.md`, `skill-lifecycle.md` (call-graph confirmation)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The traced defect is real and precisely as described: `validate-artifact.sh` already computes and prints exact fix/error/warning counts on stdout, but `skill_validate_task_artifacts` (`skill-base.sh:477-492`) only checks the exit code, discards it into one generic non-blocking `WARNING` string, and `command-gate-out.sh` never sees a number. `command-gate-out.sh` has exactly one call site for this function, so the fix is fully containable in the two files the task names.
- `--fix`'s actual blast radius is narrow and mechanical, verified by reading `validate-artifact.sh:127-165`: it only ever inserts literal `- **Field**: TBD` placeholder lines for missing *metadata* fields. It never touches required *sections*, never fabricates prose, and never edits existing content. This materially changes the risk calculus for Decision 3 below.
- Recommended fix: capture `validate-artifact.sh`'s stdout inside `skill_validate_task_artifacts`, parse its one terminal summary line (format is exit-code-discriminated and stable), and aggregate fixes/errors/warnings across all files into caller-visible global variables — the same "uppercase globals as a return channel" convention `skill-base.sh` already uses elsewhere (`TASK_DIR`, `TASK_TYPE`, `ARTIFACT_PATH`, `SUBAGENT_STATUS`, etc., set in `skill_preflight_update`/`skill_read_metadata`). `command-gate-out.sh` then prints one always-on report line from those globals after the call.
- Decision (stated in full below): **keep `--fix` in-place-mutating** on the gate-out path. The hazard named in the task is the *absence of a record*, not the mutation itself; the mutation is already narrow, self-flagging (`TBD` is not disguised as real content), and git-tracked. Reporting closes the transparency gap without an ergonomics regression that disabling `--fix` would cause.
- A related latent issue surfaces during this research and should be folded into the same fix: `validate-artifact.sh` collapses "fixed and now clean" and "fixed a metadata field but a required *section* is still missing" into the same exit code 2, so today's design intent ("gate-out reports zero format errors *and* zero auto-repaired fields" — two independent numbers) needs the errors-remaining count surfaced too, not just the fix count.
- `skill_validate_task_artifacts` currently has zero test coverage (confirmed by `test-skill-base-lifecycle.sh`'s own "Residual (uncovered)" footer); the plan should add fixture-driven tests exercising both the repair and no-repair directions, per the acceptance criterion's explicit "both directions must be demonstrated."

## Context & Scope

Task 13 asks for three things: (1) propagate `validate-artifact.sh`'s counts through `skill_validate_task_artifacts` instead of discarding them, (2) give `command-gate-out.sh` a reportable surface for those counts, and (3) explicitly decide whether `--fix` should keep mutating artifacts in place on the gate-out path or be replaced with report-and-leave-for-human. The task's declared `file_scope` is exactly `command-gate-out.sh` and `skill-base.sh` — this research confirms that scope is sufficient for the minimal fix (see "Scope Fork" in Recommendations for the one place a plan might legitimately want to widen it).

This research does not modify code; it maps the exact call chain, the exact text/exit-code contract of `validate-artifact.sh`, an established in-codebase convention for cross-function value propagation, and produces a concrete, low-risk design for `/plan` to implement.

## Findings

### Codebase Patterns

**The traced call chain, confirmed line-for-line:**
- `command-gate-out.sh:230-232` — `if [ -d "$task_dir" ]; then skill_validate_task_artifacts "$task_dir"; fi`. This is the only place in the whole `agent-system/extensions/` tree that calls `skill_validate_task_artifacts` (confirmed by grep across `.sh`/`.md`) — the fix is fully local to these two files, matching the task's declared `file_scope`.
- `skill-base.sh:477-492` (`skill_validate_task_artifacts`) loops `reports/*.md`, `plans/*.md`, `summaries/*.md` and for each: `if ! bash .claude/scripts/validate-artifact.sh "$f" "$type" --fix 2>/dev/null; then echo "WARNING: ... (non-blocking)."; fi`. Note `2>/dev/null` only discards *stderr*; `validate-artifact.sh` writes everything through `echo` (stdout) via its `log_error`/`log_warn`/`log_fix` helpers — the numbers are already flowing to the console, just never captured into a variable.
- `validate-artifact.sh:69-72` defines `log_error`/`log_warn`/`log_fix`, each incrementing a counter and echoing a `[ERROR]`/`[WARN]`/`[FIXED]` line. The terminal summary block (`:270-287`) is exit-code-discriminated and has exactly three mutually exclusive shapes:
  - exit 2 (fixes applied): `[FIXED] $fixes field(s) auto-repaired, $errors error(s), $warnings warning(s) remaining`
  - exit 0 (clean): `[PASS] $artifact_type artifact is valid ($warnings warning(s))`
  - exit 1 (unfixed errors): `[FAIL] $errors error(s), $warnings warning(s)`
  - (exit 3/4/5 are environment/usage failures — file not found, unknown type, missing phase-heading-pattern library — with no fix/error/warning counts at all; these are validation-could-not-run states, distinct from validation-found-issues.)
- These three summary lines are always the *last* line the script prints, which makes `tail -1` on captured stdout a reliable anchor for parsing regardless of how many `[ERROR]`/`[WARN]`/`[FIXED]`/`[INFO]` lines preceded it.

**What `--fix` actually mutates** (`validate-artifact.sh:127-165`): only missing *metadata* fields (`REPORT_METADATA`/`PLAN_METADATA`/`SUMMARY_METADATA` — e.g. `Task`, `Effort`, `Dependencies`), never required *sections*. The insertion is a fixed-format placeholder line, `- **Field**: TBD`, anchored immediately after the last existing metadata line via an `awk` pass, applied only when at least one existing metadata line exists to anchor on (otherwise it logs `Cannot auto-fix` and leaves the error uncorrected). This is a narrow, mechanical, self-evidently-incomplete mutation — not content fabrication.

**Existing convention for propagating values out of a sourced function** (this is the mechanism to reuse, not invent): `skill-base.sh` already uses plain uppercase globals as a return channel for functions that are `source`d into a caller's shell rather than run as subprocesses — e.g. `skill_preflight_update` sets `TASK_DIR`, `TASK_TYPE`, `TASK_STATUS`, `PROJECT_NAME`, `ARTIFACT_NUMBER`, etc. (`skill-base.sh:187-329`), and `skill_read_metadata` sets `SUBAGENT_STATUS`, `ARTIFACT_PATH`, `ARTIFACT_TYPE`, `ARTIFACT_SUMMARY`, `MEMORY_CANDIDATES` (`skill-base.sh:343-422`). `command-gate-out.sh` itself sources `skill-base.sh` at the top (not a subprocess call), so this same convention is directly available: `skill_validate_task_artifacts` can set globals the caller reads immediately afterward, with no IPC/tempfile needed.

**A related, narrower instrumentation gap exists in the sibling function** `skill_validate_artifact` (singular; `skill-base.sh:433-467`, used by ordinary per-command postflight, not by `command-gate-out.sh`). It has the identical discard pattern (`if ! bash validate-artifact.sh ... --fix 2>/dev/null; then echo WARNING; fi`) but already calls `events-append.sh` afterward with a generic "Verification stage completed" milestone/deviation event that also carries no fix/error/warning counts. This function is outside task 13's traced path (`command-gate-out.sh` never calls it) and outside its `file_scope`'s named call site, so it is out of scope for this task's acceptance criterion, but it is the same defect shape and worth a follow-up note (see Context Extension Recommendations) so it isn't silently missed once this task's pattern exists to copy.

**Test coverage**: `test-skill-base-lifecycle.sh:637-639` explicitly lists `skill_validate_task_artifacts` among functions with zero coverage in that suite ("Residual (uncovered by this suite, out of scope per this suite's own authoring plan)"). There is no other test file for it (`agent-system/extensions/core/scripts/tests/` has no `*gate-out*` or `*validate-artifact*` test file). The plan will need to add new fixture-driven test(s), not extend an existing one.

**Durable-reporting conventions already in the codebase** that could be reused for a stronger, queryable version of "reportable surface": `events-append.sh` (`specs/events.jsonl`, `--event-type`, `--category deviation|blocker|milestone|success`, `--detail-json`) and `system-defect-record.sh` (deduplicated defect records for `system_defect`/`deviation` rows). `skill_validate_artifact` already demonstrates the pattern of calling `events-append.sh` right after a validation pass. Both are available for a plan to adopt if durable/queryable reporting is wanted beyond stdout.

### External Resources

Not applicable — this is a pure codebase-internal defect (no external library, API, or documentation dependency).

### Recommendations

**1. Propagate counts (`skill-base.sh`, `skill_validate_task_artifacts`).** Capture each file's `validate-artifact.sh --fix` invocation via command substitution instead of running it bare, so its stdout can still be echoed to the console (preserving today's visible log behavior) *and* parsed:

```bash
skill_validate_task_artifacts() {
  local task_dir="$1"
  local subdir type f out rc line f_fixes f_errors f_warnings
  SKILL_VALIDATE_FIXES=0
  SKILL_VALIDATE_ERRORS=0
  SKILL_VALIDATE_WARNINGS=0
  SKILL_VALIDATE_FIXED_FILES=""
  for pair in "reports:report" "plans:plan" "summaries:summary"; do
    subdir="${pair%%:*}"; type="${pair##*:}"
    for f in "$task_dir"/"$subdir"/*.md; do
      [ -e "$f" ] || continue
      echo "Validating ${type} artifact: ${f}"
      rc=0
      out=$(bash .claude/scripts/validate-artifact.sh "$f" "$type" --fix 2>/dev/null) || rc=$?
      echo "$out"
      line=$(printf '%s\n' "$out" | tail -1)
      f_fixes=0; f_errors=0; f_warnings=0
      case "$rc" in
        0) f_warnings=$(echo "$line" | grep -oE '[0-9]+ warning' | grep -oE '[0-9]+' | head -1) ;;
        1) f_errors=$(echo "$line"   | grep -oE '[0-9]+ error'   | grep -oE '[0-9]+' | head -1)
           f_warnings=$(echo "$line" | grep -oE '[0-9]+ warning' | grep -oE '[0-9]+' | head -1) ;;
        2) f_fixes=$(echo "$line"    | grep -oE '^\[FIXED\] [0-9]+' | grep -oE '[0-9]+')
           f_errors=$(echo "$line"   | grep -oE '[0-9]+ error'   | grep -oE '[0-9]+' | head -1)
           f_warnings=$(echo "$line" | grep -oE '[0-9]+ warning' | grep -oE '[0-9]+' | head -1) ;;
        *) f_errors=1 ;;  # 3/4/5: validation could not run at all -- count as one error, never silently zero
      esac
      f_fixes="${f_fixes:-0}"; f_errors="${f_errors:-0}"; f_warnings="${f_warnings:-0}"
      SKILL_VALIDATE_FIXES=$((SKILL_VALIDATE_FIXES + f_fixes))
      SKILL_VALIDATE_ERRORS=$((SKILL_VALIDATE_ERRORS + f_errors))
      SKILL_VALIDATE_WARNINGS=$((SKILL_VALIDATE_WARNINGS + f_warnings))
      if [ "$f_fixes" -gt 0 ]; then
        SKILL_VALIDATE_FIXED_FILES="${SKILL_VALIDATE_FIXED_FILES:+${SKILL_VALIDATE_FIXED_FILES}, }${f}"
      fi
      if [ "$rc" -ne 0 ]; then
        echo "WARNING: ${type} artifact ${f} has format issues (non-blocking): ${f_fixes} fixed, ${f_errors} error(s), ${f_warnings} warning(s). Review output above." >&2
      fi
    done
  done
  return 0
}
```

This follows the existing global-variable-as-return-channel convention exactly (uppercase, no `local`, set unconditionally at function entry so a caller never reads a stale value from a previous invocation). `SKILL_VALIDATE_FIXED_FILES` is a human-readable comma-joined path list — sufficient for a one-line report; a JSON array (`jq -R -s -c 'split(", ")'`) is a trivial follow-up if a machine consumer needs it later.

**2. Give `command-gate-out.sh` a reportable surface.** Immediately after the existing call (`command-gate-out.sh:230-232`), print an always-on line — for both the repaired and the clean case, since the acceptance criterion requires both directions to be demonstrable from the same code path:

```bash
if [ -d "$task_dir" ]; then
  skill_validate_task_artifacts "$task_dir"
  echo "[gate-out] Artifact validation for task ${task_number}: ${SKILL_VALIDATE_FIXES:-0} field(s) auto-repaired, ${SKILL_VALIDATE_ERRORS:-0} error(s), ${SKILL_VALIDATE_WARNINGS:-0} warning(s) remaining."
  if [ "${SKILL_VALIDATE_FIXES:-0}" -gt 0 ]; then
    echo "[gate-out] Auto-repaired artifact(s): ${SKILL_VALIDATE_FIXED_FILES}"
  fi
fi
```

This is directly testable: a test invokes `command-gate-out.sh` against a fixture task directory and asserts on its captured stdout, exactly like the existing `[gate-out]`/`[PRE-EXISTING VERIFY-DEPLOY FAILURE]` announcement lines already in this file that tests would capture the same way.

**Optional strengthening (recommended, not required for acceptance):** also call `events-append.sh` once per gate-out run with the aggregate counts (`--event-type artifact_auto_repair --category deviation|milestone --detail-json '{"fixes":N,"errors":E,"warnings":W,"files":[...]}'`), mirroring `skill_validate_artifact`'s existing post-validation event call. This makes the report durable and queryable via `events-query.sh` rather than console-only, which matters more for the stated hazard (silent, unrecorded mutation across a fleet of automated runs) than a stdout line alone. This is additive and does not change the minimal fix above.

**3. Decision: keep `--fix` in-place-mutating on the gate-out path.**

Reasoning:
- The mutation's actual blast radius, confirmed by reading the code (not assumed), is a single mechanical case: inserting a literal `- **Field**: TBD` placeholder for a *missing metadata field*. It never touches required sections or existing prose, and never fabricates substantive content. The placeholder text is itself self-flagging (`TBD` is an obvious, un-hideable incompleteness marker), so mutation does not manufacture a false appearance of completeness.
- Every artifact under `specs/` is git-tracked; the mutation was always auditable via `git diff`/`git blame` even before this fix. What was actually missing was a *record that a repair happened at all* — the task's own framing ("nothing anywhere recording that it was") — not disclosure of the mutation's content. Recommendation 1+2 close exactly that gap.
- Disabling `--fix` on this specific path would regress today's ergonomics for a purely mechanical, non-blocking, best-effort lifecycle step: every trivial missing metadata field (a common, low-stakes omission) would newly become a hard stop requiring manual intervention in an otherwise-automated pipeline, which the acceptance criterion does not ask for and the task description frames as a decision to make on the merits, not a default to assume.
- Residual risk worth carrying forward explicitly (not blocking, but real): `validate-artifact.sh`'s exit code conflates "fixed and now fully clean" with "fixed a metadata field but a required *section* is still separately missing" — both exit 2. Recommendation 1 surfaces `SKILL_VALIDATE_ERRORS` alongside `SKILL_VALIDATE_FIXES` precisely so this case is visible in the same report line (a task whose section is still missing shows a nonzero errors-remaining count even though fixes also happened), rather than reintroducing a narrower version of the same silence one field over. This also directly answers the original unverifiable acceptance text ("gate-out reports zero format errors *and* zero auto-repaired fields") — both numbers, not just one.

**Scope Fork (for `/plan` to resolve, not decided here):** `file_scope` names only `command-gate-out.sh` and `skill-base.sh`. The design above stays entirely inside that scope by parsing `validate-artifact.sh`'s existing human-phrased summary line via regex, anchored on its exit code. This is workable and low-risk (the three summary shapes are stable, and this codebase already parses subprocess output by regex/grep elsewhere in `command-gate-out.sh` itself, e.g. `_gate_out_deploy_findings`'s `grep '^FINDING '`). A more robust *alternative* would be to add one new, stable, wording-independent machine line to `validate-artifact.sh` itself (e.g. `echo "COUNTS fixes=$fixes errors=$errors warnings=$warnings" >&2` right before the existing summary block, on every exit path including 0/1/2), which the parser in `skill_validate_task_artifacts` could match with one fixed-format regex instead of three prose-shaped ones. This trades a one-line, backward-compatible addition to a file *outside* the declared scope for materially lower parser fragility against future wording changes to the human-readable messages. `/plan` should pick one explicitly; this report recommends the in-scope option as the default (it fully satisfies the acceptance criterion) but flags the alternative because `file_scope` is documented as "descriptive/anticipated, not filesystem-validated" and a one-line, additive, non-breaking change to `validate-artifact.sh` is a small, legible deviation if `/plan` judges the robustness worth it.

## Decisions

- **D1**: `--fix` remains in-place-mutating on the `command-gate-out.sh` path. See Decision 3 above for full reasoning; this is a technical judgment resolvable from the code's actual (narrow, mechanical, self-flagging) behavior, not a preference requiring the user's input.
- **D2**: Counts are propagated via uppercase global variables (`SKILL_VALIDATE_FIXES`, `SKILL_VALIDATE_ERRORS`, `SKILL_VALIDATE_WARNINGS`, `SKILL_VALIDATE_FIXED_FILES`) set by `skill_validate_task_artifacts` and read by `command-gate-out.sh` immediately after the call, reusing the exact convention `skill-base.sh` already uses for `TASK_DIR`/`ARTIFACT_PATH`/`SUBAGENT_STATUS`/etc., rather than inventing a new IPC mechanism (temp file, subshell-exported JSON, etc.).
- **D3**: The report surfaces both the fix count and the errors/warnings-remaining count in the same line, not fixes alone, because the original (unverifiable) acceptance text named both independently and because of the exit-code conflation noted under Decision 3's residual-risk bullet.
- **D4 (left open for `/plan`)**: whether to parse `validate-artifact.sh`'s existing prose summary line (stays within the declared `file_scope`) or add one new stable machine-readable line to `validate-artifact.sh` (more robust, requires widening `file_scope` by one file). Both fully satisfy the stated acceptance criterion; this report recommends the in-scope option as the default.

## Risks & Mitigations

- **Risk**: regex-based parsing of `validate-artifact.sh`'s human-phrased summary line is fragile against future wording changes. **Mitigation**: anchor parsing on the exit code (0/1/2) first, using the message text only to extract the numbers within that known shape; add a small regression test that pins the exact three summary-line formats so a future wording change to `validate-artifact.sh` fails loudly here instead of silently degrading counts to zero. (See the Scope Fork above for the alternative that removes this risk entirely at the cost of touching one more file.)
- **Risk**: exit codes 3/4/5 (file-not-found, unknown-type, missing phase-heading-pattern library) carry no fix/error/warning counts at all — a naive parser could silently record these as zero, hiding a real validation-could-not-run condition behind an all-clear report. **Mitigation**: the recommended `case` statement's default branch counts these as `f_errors=1` explicitly rather than falling through to zero, so a validation failure is never silently invisible in the aggregate.
- **Risk**: a task directory with many artifacts could produce a long `SKILL_VALIDATE_FIXED_FILES` list, cluttering the one-line report. **Mitigation**: not a blocker at current scale (task directories rarely carry more than a handful of reports/plans/summaries); revisit only if it becomes a real readability problem.
- **Risk**: `skill_validate_task_artifacts` has no test coverage today, so a regression in the new aggregation logic would not be caught automatically. **Mitigation**: the implementation phase must add fixture-driven tests (see Context Extension Recommendations) rather than relying on manual verification alone, directly per the acceptance criterion's "both directions must be demonstrated."

## Context Extension Recommendations

- **Topic**: `skill_validate_artifact` (singular; `skill-base.sh:433-467`) has the same discard-the-counts defect as `skill_validate_task_artifacts`, one call removed from `command-gate-out.sh` and outside task 13's traced path and `file_scope`.
  **Gap**: no context file currently documents this as a known, related gap, so a future task could rediscover it from scratch.
  **Recommendation**: once this task lands and establishes the parsing/aggregation pattern, file a short follow-up note (or a new small task) pointing at `skill_validate_artifact` to apply the same fix, referencing this task's report by path for the reusable pattern rather than re-deriving it.

## Appendix

- `validate-artifact.sh` exit codes referenced above: `0` = valid, `1` = errors found (unfixed), `2` = auto-fixed, `3` = file not found, `4` = unknown type, `5` = environment error (plan-type only, missing `scripts/lib/phase-heading-patterns.sh`).
- Confirmed single call site for `skill_validate_task_artifacts`: `grep -rn "skill_validate_task_artifacts" agent-system/extensions/core/ --include="*.sh" --include="*.md"` returns only `command-gate-out.sh:231` as an actual invocation; all other hits are comments/docs.
- `test-skill-base-lifecycle.sh:634-639` is the source for the "zero existing test coverage" finding.
