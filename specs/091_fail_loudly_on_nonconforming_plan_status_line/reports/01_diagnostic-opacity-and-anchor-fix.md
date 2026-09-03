# Research Report: Task #91

**Task**: 91 - Fail loudly on nonconforming plan status line
**Started**: 2026-09-03T17:15:00Z
**Completed**: 2026-09-03T17:31:00Z
**Effort**: 2-3 hours
**Dependencies**: None
**Research Inputs**: BimodalLogic peer-session filing (handed off, described in dispatch)
**Artifacts**:
- specs/091_fail_loudly_on_nonconforming_plan_status_line/reports/01_diagnostic-opacity-and-anchor-fix.md
**Standards**: report-format.md, subagent-return.md, artifact-formats.md, state-management.md
- **Sources/Inputs**: TBD

## Executive Summary

- All four defects named in the dispatch are confirmed by direct code reading (not just the
  peer-session's claim). No further investigation overturned any of them; the dispatch's
  "CORRECTION" (no empty-equals-empty false success exists) is also independently confirmed.
- `agent-system/extensions/core/scripts/update-plan-status.sh` (the edit target) is a 79-line
  script with exactly two failure exits (line 44/58 for missing plan file/dir — already fine)
  and one generic diagnostic exit at **line 76-77** (`Failed to update status in $plan_file`)
  that fires identically for all three malformed shapes.
- A directly reusable precedent already exists in the same directory:
  `update-phase-status.sh` (lines 295-329) already does line-numbered, content-quoting
  diagnostics for its own (phase-heading) status-mutation. The fix for `update-plan-status.sh`
  should mirror that script's `grep -n ... | cut -d: -f1` + `echo "Line ${n}: $(sed -n ...)"`
  idiom rather than invent a new diagnostic style.
- `commands/implement.md:353`, cited in the dispatch as a "documented defensive call site" for
  defect 4, **no longer exists in the current codebase**. It was deleted in commit `ff08eb967`
  ("task 124 phase 4: delete lifecycle command files and de-register from manifest") when the
  `/implement` lifecycle command was removed in favor of `skill-orchestrate`'s direct dispatch.
  The sole current caller of `update-plan-status.sh` is `update_plan_file()` inside
  `update-task-status.sh` itself (line 770), which branches on **exit code**, not stdout content,
  and is confirmed unaffected either way. This means defect 4 (stdout/rc ambiguity) is now a
  purely forward-looking robustness concern with zero live consumers — worth fixing cheaply, not
  worth over-engineering.
- `context/formats/plan-format.md` line 99 is exactly the "Consumers of this heading contract"
  paragraph the dispatch points to, and it names all three status-mutating scripts
  (`update-phase-status.sh`, `update-plan-status.sh`, `update-task-status.sh --phase-check`).
  The plan-level Status field itself (distinct from phase headings) is documented separately at
  lines 343-365 ("Plan-level vs. phase-level markers"). The new trailing-text tolerance policy
  belongs in the latter section (a plan-level-Status-field concern), with a one-line pointer
  added near line 99 for discoverability from the heading-contract list.
- No dedicated test file for `update-plan-status.sh` exists yet; it is exercised only indirectly
  via `agent-system/extensions/core/scripts/tests/test-update-task-status.sh`. The plan should
  budget for either a new `test-update-plan-status.sh` or an extension of the existing suite
  covering the three malformed shapes plus the well-formed and idempotent-no-op paths.

## Context & Scope

Verify each of the four defects described in the dispatch against the live source-store files
(`agent-system/extensions/core/scripts/update-plan-status.sh` and
`agent-system/extensions/core/scripts/update-task-status.sh`), identify the exact edit sites,
confirm or correct the "documented defensive call site" reference, and locate the correct
plan-format.md section for the trailing-text policy documentation the fix requires. This is a
`task_type: meta` task; per `.claude/rules/source-store-deploy-boundary.md` all edits target
`agent-system/extensions/core/**`, never the deployed `.claude/**` tree.

## Findings

### Codebase Patterns

**`update-plan-status.sh` full anatomy** (`agent-system/extensions/core/scripts/update-plan-status.sh`):
- Lines 33-45: resolve `plan_dir` (padded, then unpadded fallback); exit 1 with a clear message
  if the directory is missing (line 43) — already diagnostic, not in scope for this fix.
- Lines 47-59: resolve `plan_file` via version-ordered `ls` of `[0-9][0-9]_*.md`, falling back to
  a plain sort; exit 1 with a clear message if none found (line 57) — already diagnostic.
- Line 62 (idempotency read): `current_status=$(grep -m1 "^- \*\*Status\*\*:" "$plan_file" | sed
  's/.*\[\([^]]*\)\].*/\1/' || echo "")`. Confirmed: on a bracket-less line, `grep -m1` matches
  (the literal `- **Status**:` prefix is present) so `|| echo ""` never fires; `sed`'s
  substitution pattern requires a literal `[...]` to match, and when it doesn't, GNU `sed`
  emits the **input line unchanged** — so `current_status` becomes the full raw line text
  (e.g. `- **Status**: PARTIAL` with no brackets), never empty. This independently reproduces
  the dispatch's "CORRECTION" — there is no empty-equals-empty false-success path.
- Line 63-66: idempotency exit 0 when `current_status == new_status` — this is defect 4's
  silent-empty-stdout success path (already-at-target).
- Line 69 (the mutating sed): `sed -i "0,/^- \*\*Status\*\*: \[.*\]/{s/^- \*\*Status\*\*:
  \[.*\]$/- **Status**: [${new_status}]/}" "$plan_file"`. The **trailing `$` anchor** on the
  substitution's own pattern (not the address pattern, which has no anchor) is defect 2: any
  line with content after the closing `]` (e.g. `[IMPLEMENTING] (resumed; Phases 1R-10R
  closed)`) fails to match the `s///` half even though the `0,/.../ ` address half matched, so
  the substitution is silently skipped for that one attempt (sed does not error — a non-matching
  substitution inside a successful address range is simply a no-op) and the file is written back
  unchanged.
- Lines 72-78 (the generic diagnostic): re-reads `updated_status` with the same fragile sed as
  line 62, compares to `new_status`, and on any mismatch prints only `Failed to update status in
  $plan_file` (line 76) with no line number, no line content, no reason. This is defect 1's
  single generic-message chokepoint — the one both defect 2 (silent sed no-op) and a
  missing-prefix/missing-brackets shape all funnel through identically.

**Diagnostic precedent already in the same directory** — `update-phase-status.sh` lines 295-329:
```
line_number=$(grep -n "${PHASE_HEADING_PREFIX}${phase_number}:" "$plan_file" 2>/dev/null | head -1 | cut -d: -f1 || true)
...
current_status=$(sed -n "${line_number}s/.*\[\(.*\)\]$/\1/p" "$plan_file")
if [[ -z "$current_status" ]]; then
    echo "Could not extract status from phase ${phase_number} heading in $plan_file" >&2
    echo "Line ${line_number}: $(sed -n "${line_number}p" "$plan_file")" >&2
    exit 1
fi
...
if [[ "$updated_status" != "$new_status_display" ]]; then
    echo "Failed to update phase ${phase_number} status in $plan_file" >&2
    echo "Wanted '${new_status_display}', got '${updated_status}'" >&2
    exit 1
fi
```
This is a directly copyable idiom for `update-plan-status.sh`'s fix: locate the Status line's
number with `grep -n ... | head -1 | cut -d: -f1`, then quote `sed -n "${n}p" "$plan_file"`
verbatim in the error message, plus a stated reason. The plan should reuse this pattern rather
than inventing a new diagnostic shape, for consistency across the three status-mutating scripts
plan-format.md line 99 already treats as a group.

**Sole current caller — `update-task-status.sh:751-780`** (`update_plan_file()`):
```bash
if ! "$plan_script" "$task_number" "$project_name" "$plan_status"; then
    if [[ "$operation" == "postflight" ]]; then
        echo "Error: failed to update plan file status to [$plan_status] for task $task_number." >&2
        ...
        exit 3
    else
        echo "Warning: plan file update failed (non-fatal)" >&2
    fi
fi
```
Confirms the dispatch's defect 3 claims exactly:
- Branches on **exit code only** — `update-plan-status.sh`'s stdout is never read here, so
  changing what defect-1's fix prints to stderr, or changing defect-4's stdout contract, cannot
  break this caller.
- Preflight (`operation != postflight`) treats a failure as advisory (line 778, non-fatal
  warning) with **no line content, no reason** surfaced — this is the "preflight masks the
  leading indicator" defect. Because the underlying malformed Status line persists on disk, the
  same failure recurs verbatim at postflight, `exit 3` (line 776), which the header comment
  (lines 25-27) already documents as deliberately fatal-and-retryable. Dispatch item 3's claim
  that postflight "fails loudly and calls itself retryable" is accurate — lines 772-775 print a
  three-line explanation naming the target status and the retry semantics (though still without
  the offending line's content, since it is `update-plan-status.sh`'s own stderr, not this
  wrapper's, that would need to carry that detail).
- The code comment at lines 762-768 is exactly the rationale block dispatch item 3 refers to
  ("the argument for making postflight fatal, not a description of an undetected outcome") —
  confirmed verbatim: `"a failed [COMPLETED] write on implement postflight leaves state.json and
  the plan file in permanent, externally-invisible disagreement -- generate-todo.sh reads only
  state.json, never plan files"`.

**Defect 4's cited call site does not exist** — `commands/implement.md` is absent from
`agent-system/extensions/core/commands/` (confirmed via directory listing: only `errors.md`,
`fix-it.md`, `merge.md`, `meta.md`, `orchestrate.md`, `project-overview.md`, `review.md`,
`revise.md`, `spawn.md`, `tag.md`, `task.md`, `todo.md`, `README.md`, `zulip.md` remain — no
`research.md`, `plan.md`, or `implement.md`). `git log --all --oneline -- "**/implement.md"`
shows it was deleted in `ff08eb967` ("task 124 phase 4: delete lifecycle command files and
de-register from manifest"), part of the broader migration (documented in CLAUDE.md's Core Task
Types table) to route `general`/`meta`/`markdown` task types directly through
`skill-orchestrate`'s agent dispatch rather than through dedicated `/research`, `/plan`,
`/implement` command files. The only surviving reference to `update-plan-status.sh` in prose
docs is `skill-orchestrate/SKILL.md:1304`, which mentions it purely as a side-effect footnote
("the workflow-active marker write and the plan-level [STATUS] stamp (via
update-plan-status.sh)") and does not consume its stdout either. **Conclusion**: the "any future
stdout-consuming caller would be misled" framing in the dispatch is correct as a general
robustness argument, but the specific documented call site it names is stale (predates the
lifecycle-command deletion) — the plan should not treat `commands/implement.md` as something to
edit or verify against; it should note the citation is obsolete and, if desired, make stdout
reliable purely on forward-looking-robustness grounds rather than to fix a broken existing
caller.

**Plan-format.md structure relevant to fix (b)**:
- Line 99 (`**Consumers of this heading contract**:...`) is phase-heading-scoped (the `### Phase
  N: {name} [STATUS]` shape), not the plan-level `- **Status**:` field. It already names
  `update-plan-status.sh` as one of three consumers of *that* heading contract, which is a
  separate contract from the plan-level Status field this task touches.
- Lines 343-365 ("Plan-level vs. phase-level markers") is the section that actually documents the
  plan-level `- **Status**:` field's vocabulary and semantics — this is the correct place to add
  the trailing-text tolerance policy documentation fix (b) calls for, since it is a plan-level
  Status field concern, not a phase-heading concern. A short cross-reference note at line 99 (or
  immediately after it) pointing forward to the new subsection would keep the "three
  status-mutating scripts" list internally consistent without conflating the two contracts.
- Lines 5, 16, 380 show the plan-level Status field's existing canonical rendering as `- **Status**:
  [WORD]` with no trailing text in any current example — so choosing to standardize on
  "accept and preserve trailing text" (dispatch's implied preference, given defect 2's framing
  as an argument for tolerance) would be a genuinely new, not merely descriptive, format
  allowance and must be spelled out explicitly with its own example line, not just prose.

### External Resources

Not applicable — this is a pure codebase/shell-scripting fix; no external library or API
research was needed. (No `--lit` or `--hard` flag was passed for this dispatch.)

### Recommendations

1. **Fix (a) diagnostic opacity** — replace the single `grep -m1 | sed` idiom (lines 62 and 72)
   with a `grep -n | head -1 | cut -d: -f1` line-number lookup (mirroring
   `update-phase-status.sh:299`), then branch into three distinct, named checks against that
   line's raw content:
   - Missing `- **Status**:` prefix (grep finds no match at all → distinct message, distinct
     from "no plan file" and "no plan dir").
   - Prefix present, no `[...]` bracket pair.
   - Prefix and brackets present, but trailing text follows `]` (once policy (b) below is
     decided, this shape either becomes acceptable — see next point — or gets its own message).
   Each message should quote the offending line verbatim with its line number, following
   `update-phase-status.sh`'s `"Line ${n}: $(sed -n "${n}p" "$plan_file")"` idiom exactly, so all
   three status-mutating scripts converge on one diagnostic style.
2. **Fix (b) trailing-text policy** — the dispatch already frames tolerance as the recommended
   direction (defect 2 is presented as "the argument for tolerating it rather than rejecting
   it", and the resumed-plan shape is called "a legitimate resume workflow"). Recommend
   implementing tolerance: change the mutating `sed` to capture and preserve any trailing text
   after `]` (e.g. `s/^- \*\*Status\*\*: \[.*\]\(.*\)$/- **Status**: [${new_status}]\1/`) rather
   than requiring `$` immediately after the bracket, and update the idempotency-read regex
   (currently `.*\[\([^]]*\)\].*` at line 62, which is already trailing-text-tolerant on read —
   only the *write* path at line 69 has the `$`-anchor bug) to stay consistent. Document the
   accepted shape explicitly in plan-format.md's "Plan-level vs. phase-level markers" section
   (lines 343-365) with a concrete example line (e.g. `- **Status**: [IMPLEMENTING] (resumed;
   Phases 1R-10R closed)`), and add a one-line pointer near line 99 so a future reader of the
   phase-heading consumers list also finds the plan-level trailing-text rule.
3. **Fix (c) preserve asymmetry** — no code change needed at `update-task-status.sh:762-780`;
   confirm during implementation that the fatal-postflight / warn-preflight branch and its
   rationale comment (lines 762-768) are left untouched, and that the new preflight-visible
   warning (evaluate item 1, below) is additive rather than a fatality change.
4. **Evaluate item 1 (preflight warning should name the line)** — recommend yes: since
   `update-plan-status.sh` will now print a line-numbered diagnostic to its own stderr on
   failure (fix (a)), and `update-task-status.sh` already does not swallow that stderr (the
   comment at line 762-763 states "do not discard its stderr here"), the operator already sees
   the underlying line-numbered message at preflight time once fix (a) lands — the remaining
   gap is only that `update-task-status.sh`'s own wrapper line 778 says just "(non-fatal)" with
   no further context. A minimal one-line addition after 778 (e.g. echoing the plan file path
   and reiterating "this will hard-fail at postflight if unresolved") closes the operator-visible
   gap the dispatch describes, without touching fatality.
5. **Evaluate item 2 (plan-creation-time lint)** — worth flagging as a candidate but reasonably
   out of scope for this task's phase budget: `validate-artifact.sh` (found at
   `agent-system/extensions/core/scripts/validate-artifact.sh:143`) already extracts the last
   metadata field line via `grep -nE "^-?[[:space:]]*\*\*(${field_alt})\*\*:" ... | tail -1 | cut
   -d: -f1` for artifact validation — this could plausibly be extended to validate the Status
   line's bracket shape at creation time, but doing so is an independent enhancement (a new
   validation rule, not a bug fix) with its own scope/testing burden. Recommend noting it as a
   deferred follow-up rather than bundling it into this task's plan, unless the planner judges
   the addition trivial once fix (a)'s three-shape-detection logic already exists to reuse.
6. **Evaluate item 3 (idempotent no-op should echo path)** — recommend yes, low-risk: change
   line 63-66's early exit to `echo "$plan_file"; exit 0` instead of a bare `exit 0`. Confirmed
   safe against the sole current caller (`update-task-status.sh:770`), which branches on exit
   code (`if ! "$plan_script" ...`) and never inspects stdout — so this is a pure improvement
   with no regression risk to the one live consumer, directly closing defect 4's contract
   ambiguity per the script's own stated header ("Outputs: Updated plan file path on success,
   empty on failure/no-op" — making the no-op path also emit the path removes the one case where
   "success" and "no-op" were stdout-indistinguishable from "failure").
7. **Testing** — no dedicated `test-update-plan-status.sh` exists yet (only indirect coverage via
   `test-update-task-status.sh`). Recommend the plan add fixture-based tests for: each of the
   three malformed shapes (verify distinct messages, verify no file mutation), the trailing-text
   shape under the new policy (verify it succeeds and preserves the trailing annotation), the
   well-formed change path, and the already-at-target no-op path (verify stdout now equals the
   plan path per item 6 above).

## Decisions

- No decisions were made unilaterally in this research phase; the two "evaluate" items with
  clear, low-risk recommendations (preflight warning enrichment, idempotent-no-op stdout) are
  proposed above but left for the plan to confirm. Evaluate item 2 (creation-time lint) is
  recommended for deferral, not silent inclusion or exclusion.
- The stale `commands/implement.md:353` citation is corrected here rather than carried forward
  uncorrected into the plan.

## Risks & Mitigations

- **Risk**: changing the mutating `sed`'s anchor to tolerate trailing text could accidentally
  also start tolerating genuinely malformed lines it should still reject (e.g. text *before* the
  first bracket, or multiple bracket pairs on one line). **Mitigation**: scope the new pattern
  narrowly to "exactly one `[...]` pair, optionally followed by arbitrary trailing text on the
  same line," and add a fixture that a line with brackets in the middle of unrelated prose (not
  the resume-annotation shape) still gets classified as one of the three malformed shapes, not
  silently accepted.
- **Risk**: touching the shared regex idiom (`grep -m1 "^- \*\*Status\*\*:" | sed
  's/.*\[\([^]]*\)\].*/\1/'`) in two places (idempotency check at line 62, verification at line
  72) risks introducing an inconsistency between the two if only one is updated. **Mitigation**:
  factor the line-number lookup and content-extraction into a small shared shell function or
  clearly mirror both edit sites in the same commit/phase.
- **Risk**: this is a `task_type: meta` task — edits must land in
  `agent-system/extensions/core/scripts/update-plan-status.sh` and
  `agent-system/extensions/core/context/formats/plan-format.md`, never in the deployed
  `.claude/**` tree, and the fix must be redeployed and re-verified post-regeneration per the
  dispatch's acceptance criteria. **Mitigation**: plan should include an explicit redeploy +
  re-run-fixtures phase as its final verification step, not just "edit and test in source store."

## Context Extension Recommendations

- **Topic**: shared diagnostic idiom for status-line-mutating scripts.
- **Gap**: `plan-format.md`'s "Consumers of this heading contract" paragraph (line 99) documents
  *what* three scripts parse, but there is no context file describing the *diagnostic style*
  they should share (line-numbered, content-quoting stderr messages). This task will produce a
  second instance of that pattern; a future task touching `update-task-status.sh`'s own
  diagnostics could benefit from a documented convention.
- **Recommendation**: after this task lands, consider a short addition to
  `context/formats/plan-format.md` or a new `context/patterns/` note capturing the
  "line-numbered, verbatim-quoted diagnostic" convention now shared by two of the three scripts,
  so a third future consumer doesn't have to reverse-engineer it from source. Not required for
  this task's own acceptance criteria — noted for the planner's discretion only.

## Appendix

- Files read: `agent-system/extensions/core/scripts/update-plan-status.sh` (full, 79 lines),
  `agent-system/extensions/core/scripts/update-task-status.sh` (lines 1-40, 480-560, 730-800),
  `agent-system/extensions/core/scripts/update-phase-status.sh` (lines 270-340),
  `agent-system/extensions/core/context/formats/plan-format.md` (lines 1-30, 80-120, 340-400),
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (lines 1270-1320).
- Searches: `find`/`grep` for `update-plan-status.sh` and `update-task-status.sh` across
  `agent-system/extensions/core`; `find -iname implement.md` (repo-wide, found only under
  `.opencode/`, an unrelated system's mirror); `git log --all --oneline -- "**/implement.md"`
  (confirmed deletion commit `ff08eb967`); `find -path "*tests*" -iname "*plan-status*"` (no
  dedicated test file found).
- No web research performed (pure internal shell-script/doc fix).
