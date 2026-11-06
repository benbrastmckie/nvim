# Research Report: Task #385

**Task**: 385 - Lean4 plan with zero Lean goals
**Started**: 2026-11-05T00:00:00Z
**Completed**: 2026-11-05T00:00:00Z
**Effort**: small (2 files + 1 design record, no code logic beyond one new `extract_r1` branch)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/context/formats/plan-format.md`
- Codebase: `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`
- Codebase: `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md`
- Codebase: `agent-system/extensions/lean/agents/lean-implementation-agent.md` (`--compare` preflight)
- Codebase: `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` and its
  `fixtures/challenge/` directory (existing coverage survey)
- Codebase: `agent-system/extensions/core/context/standards/task-reference-exemptions.md` and
  `record-version-exemptions.md` (precedent for the HTML-comment marker idiom this design reuses)
**Artifacts**:
- `specs/385_lean4_plan_with_zero_lean_goals/reports/01_zero-lean-goals-plan-shape.md` (this report)
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md,
no-task-references-in-deliverables.md

## Executive Summary

- The gap is real and exactly as described: a lean4 plan with zero theorem goals has no
  sanctioned shape in `plan-format.md`, and both ways of trying to express "nothing to prove"
  (section present-but-empty, or section omitted) collapse into the *same* `exit 71` that
  `lean-challenge-snapshot.sh` already uses for a genuine config error.
- **Chosen mechanism**: an explicit, mechanically-recognized opt-out marker — a single literal
  line, `<!-- lean-challenge-statements:none -->`, placed inside a *present* `## Lean Challenge
  Statements` section that otherwise carries no ```` ```lean ```` fenced blocks. This reuses the
  codebase's own existing "substring marker" idiom (`task-ref-ok`, `version-ok`) rather than
  inventing a new convention, and keeps the three distinct cases mechanically separable:
  section absent (R2 legacy fallback, unchanged), section present-with-blocks (R1 normal path,
  unchanged), section present-empty-with-marker (new zero-goal path), section present-empty-
  without-marker (still the existing hard failure).
- A new, dedicated exit code **`72`** ("zero-goal plan — no Challenge produced, intentional")
  reports the new path, distinguishable from `71` (config error) by construction, not by parsing
  stderr text.
- `--compare`/Comparator needs **no code change**: a zero-goal plan never writes
  `challenge/manifest.json` (snapshot mode exits 72 before any manifest write), so
  `lean-implementation-agent.md`'s existing `challenge_missing` preflight verdict already covers
  it harmlessly and advisory-only, exactly as it already does for any plan where nobody ran the
  snapshot. This needs documenting as the settled behavior, not implementing.
- One pre-existing gap surfaced during research and logged to `issues.jsonl`: the test suite has
  *no* fixture at all for the present-but-empty-section hard-failure path (acceptance criterion
  (c)) today — it must be added during implementation, not assumed to already exist.

## Context & Scope

Scoped to two extensions per the dispatch: `extensions/core/context/formats/plan-format.md`
(the `## Lean Challenge Statements (format, lean/lean4 plans only)` section, lines 584-629 in
the source-store copy) and `extensions/lean/scripts/lean-challenge-snapshot.sh` plus its design
record `extensions/lean/context/project/lean4/domain/challenge-snapshot.md`. All edits land in
the **source store** (`agent-system/extensions/{core,lean}/...`, resolved from
`.claude-extensions.json`'s `source_dir` fields: `core` → `agent-system/extensions/core`, `lean`
→ `agent-system/extensions/lean`), never under the deployed `.claude/**` tree, followed by a
redeploy. Also surveyed (read-only, to settle the `--compare` question): the Comparator preflight
block in `lean-implementation-agent.md` and the existing regression suite
`test-lean-challenge-snapshot.sh` / `fixtures/challenge/*`.

## Findings

### Codebase Patterns

**The script's three-way branch today** (`lean-challenge-snapshot.sh`, `extract_r1`/main
resolution block):

| `extract_r1` exit | Meaning | Caller action today |
|---|---|---|
| `0` | Section present, ≥1 ` ```lean ` block | `ROUTE="plan-declared"`, proceed normally |
| `1` | Section absent entirely | Falls through to R2 git-baseline fallback |
| `2` | Section present, **zero** ` ```lean ` blocks | Hard `exit 71` (malformed R1 section) |

Separately, after either R1 or R2 resolves, an **unconditional** guard
(`lean-challenge-snapshot.sh:928`) checks `[ ! -s "$GOALS_FILE" ]` and exits `71` with "no
identifiers found under `**Goals**:` ... nothing to snapshot" if the plan's own `- **Goals**:`
block named zero identifiers. This is what currently catches the "section omitted entirely"
shape too (R2 fallback runs, finds nothing to extract from a greenfield git tree, and lands on
this same empty-GOALS_FILE guard) — both the "I genuinely have nothing to prove" case and "I
forgot to write Goals" case produce the identical `71`.

**`plan-format.md`'s gating is binary, not ternary**: both the numbered-section list entry
(`#6`) and the `## Lean Challenge Statements (format, lean/lean4 plans only)` section itself
state only "present only when `task_type` is `lean`/`lean4`" — there is no third state for
"present, lean4-typed, but genuinely nothing to prove." The section's own identifier-set
cross-validation rule (`- **Goals**:` identifiers MUST equal the section's declared identifiers)
is stated as an unconditional hard requirement with no zero-element carve-out.

**Existing marker-comment convention already in this codebase**: `task-reference-exemptions.md`
and `record-version-exemptions.md` both define a "line containing the substring `X-ok`"
exemption-marker convention (`task-ref-ok`, `version-ok`) consumed by their respective lint
scripts as a plain substring match, not a parsed directive. This is a direct, reusable precedent
for a new `lean-challenge-statements:none` marker rather than inventing fresh conventions or
relying on free-form prose detection (which would be fragile to rephrasing).

**`--compare` already tolerates a missing manifest harmlessly**: `lean-implementation-agent.md`'s
Comparator preflight (around its "Preflight 1" branch) checks `[ ! -f "$manifest_path" ]` and, if
absent, sets `comparator_verdict="challenge_missing"` with `comparator_ran=false` — entirely
advisory (the step's own "ADVISORY MUST NOTs" paragraph forbids this from ever setting
`verification_passed: false` or `status: partial`). Since a zero-goal snapshot run never writes
a manifest (it exits `72` before reaching the manifest-write code path), this preflight branch
already fires for a zero-goal plan with zero new code. The only (optional, non-blocking) rough
edge: its `reason_detail` text — "Run lean-challenge-snapshot.sh to create the snapshot Challenge
before using --compare" — reads as an instruction to go create one, which is not quite right for
a plan that deliberately has none; this is a wording nit, not a logic gap, and is called out
below as an optional follow-up rather than part of this task's required scope.

**No regression coverage for the present-but-empty-section path today.** A full read of
`test-lean-challenge-snapshot.sh`'s case inventory (R1-R21, M1-M3, C1-C4, AV1) turned up cases
for R1-absent (R3), R1-present-with-mismatch (R2), R1-unresolvable (R4), and the empty-**Goals**-
block regression (R21) — but no case drives `extract_r1`'s status-`2` branch (section present,
zero ` ```lean ` blocks) at all. Acceptance criterion (c) ("a fixture lean4 plan with a
present-but-empty section still fails loudly") is therefore not merely "keep passing an existing
test" — it is a net-new fixture/case the implementation phase must author. Logged to
`issues.jsonl` (`specification_gap`/minor) so it isn't silently assumed away.

### External Resources

Not applicable — this is a closed-world, codebase-internal design question with no external
library or API surface; no web research was needed or performed.

## Decisions

1. **Marker shape**: a lean/lean4 plan with zero Lean goals carries a *present*
   `## Lean Challenge Statements` section containing the exact literal line
   `<!-- lean-challenge-statements:none -->` and no ` ```lean ` fenced blocks. The marker is
   matched as a plain substring (mirroring `task-ref-ok`/`version-ok`), so surrounding prose
   explaining the rationale is permitted and encouraged, but the marker line itself is fixed
   text, not a template to paraphrase.
2. **`- **Goals**:` must also be empty** (name zero identifiers) when the marker is present. If
   the marker is present but `**Goals**:` still names identifiers, that is a genuine
   inconsistency (the plan claims no goals while also naming some) and MUST fail loudly — reusing
   the existing config-error vocabulary (`71`), not the new `72` path.
3. **New `extract_r1` exit status `3`** (distinct from `0`/`1`/`2`): section present, zero
   ` ```lean ` blocks, marker line present. Internal to the script only; never surfaces as a
   process exit code itself.
4. **New process exit code `72`**: "Zero-goal plan — intentional, no Challenge produced." Fires
   only when (status `3`) AND the `**Goals**:` block is also empty. No manifest is written, no
   module is assembled, no git commit happens — a pure, side-effect-free early exit, printed as an
   explicit informational message (not buried as a generic success/failure line) so an operator
   or caller script can tell at a glance this was a deliberate no-op, not a crash.
5. **Section-absent-entirely stays wired to R2, unchanged** (acceptance (d)). The marker is the
   *only* sanctioned way to express "zero goals, deliberately" — omitting the section continues
   to mean "pre-R1-feature legacy plan," which is a materially different claim (there might be
   real declarations to recover via git-baseline extraction) and must not be conflated with "this
   plan has no theorem deliverable by design."
6. **Present-but-empty-without-marker stays a hard `71`**, unchanged (acceptance (c)). The
   existing `extract_r1` status-`2` → `exit 71` path is preserved verbatim for every empty
   section that does NOT carry the exact marker line; only a recognized, deliberate marker
   escapes it.
7. **`--compare`/Comparator: no code change.** Document, in `challenge-snapshot.md`, that a
   zero-goal plan never produces a manifest, so `lean-implementation-agent.md`'s existing
   `challenge_missing` preflight path (advisory-only, already a no-op on gating) is the settled,
   correct behavior for such a plan. `--compare` is, in effect, inapplicable to a zero-goal plan
   — the same disposition the originating task recorded ad hoc in its own Decisions before this
   feature existed, now made general and mechanical rather than task-specific prose.
8. **`plan-format.md` placement**: add a new subsection, `### Zero Lean Goals (no theorem
   deliverable)`, directly under the existing `## Lean Challenge Statements (format, lean/lean4
   plans only)` section (after its current bullet list, before `## Goal Polarity`). This keeps
   the precedent the file already documents — "this is not a novel conditional-section shape" —
   intact: the zero-goal case is a documented sub-case of the *same* section, not a competing new
   top-level section.
9. **`challenge-snapshot.md` placement**: add exit code `72` as a new row in the existing
   "Exit-Code Vocabulary" table, and add a short subsection (e.g. "Zero-Goal Marker") near the R1
   description explaining the marker, its interaction with cross-validation, and the settled
   `--compare` disposition from Decision 7. No change to the "Alternatives Evaluated and
   Rejected" section is needed, though the new mechanism could optionally be noted there as the
   rejected-alternatives list's natural sibling (not required).

## Recommendations

**plan-format.md** — insert after the existing bullet list under `## Lean Challenge Statements
(format, lean/lean4 plans only)` (i.e. after the `import` lines bullet, before `## Goal
Polarity`):

```
### Zero Lean Goals (no theorem deliverable)

A lean/lean4-typed plan whose implementation has no theorem, lemma, def, instance, or abbrev
deliverable (tooling, documentation, or infrastructure work scoped under `task_type: lean4`)
still carries this section — gating stays binary on `task_type`, not on whether the plan happens
to prove anything — but has nothing to pin. Such a plan MUST:

- Carry `## Lean Challenge Statements` containing, verbatim, the marker line
  `<!-- lean-challenge-statements:none -->`, and no ```` ```lean ```` fenced blocks. Prose
  explaining the rationale may surround the marker.
- Name zero identifiers under `- **Goals**:`.
- Record the "no theorem deliverable" rationale under `## Decisions`.

This is the sole sanctioned shape for the zero-goal case. A section that is merely empty (no
```` ```lean ```` blocks and no marker) is a malformed R1 section and fails loudly exactly as
before (`lean-challenge-snapshot.sh` exit `71`) — the marker is a deliberate opt-out, not a
default. Omitting the section entirely is NOT equivalent to this marker: an absent section still
falls back to the R2 legacy extraction route, which is a different claim (there may be an
existing declaration to recover) and fails with its own `71` if none is found. See
`context/project/lean4/domain/challenge-snapshot.md`'s Exit-Code Vocabulary for the dedicated
`72` exit this marker produces, and its Zero-Goal Marker subsection for the full mechanics.
```

Also append one clause to numbered list entry `#6` (`**Lean Challenge Statements** (lean/lean4
plans only) ...`) pointing at the new subsection, e.g. "...; see also the zero-Lean-goals case
below" — keep this edit minimal, a pointer only.

**lean-challenge-snapshot.sh** — the implementation-ready shape of the change (for the
implementation phase to carry out, not performed by this research dispatch):

1. In `extract_r1`'s Python heredoc: after finding the section and extracting its
   ` ```lean ... ``` ` blocks, if `blocks` is empty, check the section text (not just the fenced
   blocks) for the literal substring `lean-challenge-statements:none`. If present, exit with a
   new status `3` (write nothing further — no names file content, no module content needed since
   the caller for status `3` never reaches the write-module/cross-validate code path the same
   way). If absent, keep the existing `sys.exit(2)` behavior verbatim (acceptance (c)).
2. In the main resolution block (around the existing `r1_status` branch), add a `3` arm: set
   `ROUTE="zero-goal"` and skip straight past the unconditional empty-`GOALS_FILE` guard's
   existing "nothing to snapshot" `71` message — replace that guard's single unconditional check
   with a two-way branch: `ROUTE="zero-goal"` AND `GOALS_FILE` empty → print the zero-goal
   informational message and `exit 72`; `ROUTE="zero-goal"` AND `GOALS_FILE` non-empty → hard
   `71` naming the inconsistency (Decision 2); every other `ROUTE` keeps today's exact "no
   identifiers found ... nothing to snapshot" `71` message and behavior unchanged (acceptance
   (d)).
3. Update the file-header exit-code comment block (currently documenting `0/64/65/71/73/74`) to
   add `72` with the same wording used in `challenge-snapshot.md`'s table, keeping the two in
   sync per that header's own convention.
4. `--check` mode needs no change: a zero-goal plan never has a manifest, so `do_check` already
   produces its existing "no manifest found ... run the snapshot (without --check) first" `71` —
   accurate, if slightly generic, and out of this task's required scope to reword.

**challenge-snapshot.md** — add `| `72` | Zero-goal plan — intentional, no Challenge produced
(marker-recognized, `**Goals**:` also empty) | (new; no Comparator analogue) |` to the
Exit-Code Vocabulary table, and a short new subsection near the R1 description (e.g. directly
after "### Fail-loud on partial resolution") documenting: the marker text, the "Goals must also
be empty" cross-check (Decision 2), and the settled `--compare`/Comparator disposition
(Decision 7) — a zero-goal plan never acquires a manifest, so the existing `challenge_missing`
advisory preflight verdict in `lean-implementation-agent.md` is correct, unchanged behavior for
it.

**Test fixtures (implementation phase, not this report)**: at minimum, add (a) a zero-goal
fixture plan exercising the new marker + empty Goals (expect `72`, no manifest written); (b) a
fixture pairing the marker with a non-empty Goals block (expect `71`, Decision 2); and (c) the
currently-missing present-but-empty-without-marker fixture (expect `71`, acceptance (c)) flagged
in the Findings section above and already logged to `issues.jsonl`.

## Risks & Mitigations

- **Risk**: a plan author pastes the marker text slightly wrong (typo, different comment
  syntax) and silently falls through to the existing hard `71` instead of the intended `72`.
  **Mitigation**: this is the same failure mode the codebase already accepts for `task-ref-ok`/
  `version-ok` (plain substring match, no fuzzy recovery) and is strictly safer than the
  alternative of a soft/fuzzy match that could misclassify a genuinely malformed section as
  intentional — failing loud-but-wrong-coded is acceptable; failing silently-but-matched is not.
- **Risk**: scope creep into rewording `lean-implementation-agent.md`'s `challenge_missing`
  `reason_detail` text. **Mitigation**: explicitly scoped out above (Decision 7) as an optional,
  non-blocking follow-up — the acceptance criteria name only `plan-format.md` and the snapshot
  script/its design record.
- **Risk**: the new `extract_r1` status-`3` branch could accidentally also swallow the existing
  status-`2` malformed case if the substring check is too loose (e.g. matching inside a fenced
  block's own prose). **Mitigation**: the marker check should run against the *section* text
  (after fenced-block extraction confirms zero blocks), exactly mirroring where the existing
  status-`2` decision already happens — no new text range to get wrong.

## Context Extension Recommendations

- **Topic**: shell-script "marker-driven opt-out" conventions.
- **Gap**: `task-ref-ok`/`version-ok` document this idiom per-rule, but there is no single
  cross-reference describing the pattern generically for a future tool author wanting to add
  their own recognized marker (e.g. this task's `lean-challenge-statements:none`).
- **Recommendation**: optional, not required for this task — a short shared note (e.g. in
  `context/patterns/`) naming the convention once, so future additions cite it instead of
  re-deriving the idea from `task-ref-ok`/`version-ok` by example each time. Not acted on here;
  flagged for a future `/meta` task if desired.

## Appendix

- Searches performed: `grep -n "Lean Challenge\|lean4\|task_type"` against `plan-format.md`;
  full read of `lean-challenge-snapshot.sh` (1087 lines); full read of relevant sections of
  `challenge-snapshot.md`; `grep -rln "lean-challenge-snapshot.sh\|challenge-snapshot"` across
  `agent-system/extensions/lean/` to find every consumer; read of the Comparator preflight block
  in `lean-implementation-agent.md`; survey of `test-lean-challenge-snapshot.sh`'s full case
  inventory (header comment + `# Case` grep) and its `fixtures/challenge/` directory listing.
- `.claude-extensions.json` resolution: `core` → `agent-system/extensions/core`, `lean` →
  `agent-system/extensions/lean` (both confirmed via direct `source_dir` read).
- Issue logged: `specification_gap`/minor — missing regression fixture for the present-but-
  empty-section hard-failure path, `specs/385_lean4_plan_with_zero_lean_goals/issues.jsonl`.
