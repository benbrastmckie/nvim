# Implementation Plan: Task #280

- **Task**: 280 - Record-versioning rule, taxonomy, and pattern library (SOURCE STORE: `agent-system/extensions/core/`)
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None (foundational; tasks 281 and 282 consume this task's library)
- **Research Inputs**: `specs/280_record_versioning_rule_taxonomy_and_pattern_library/reports/01_rule-taxonomy-and-pattern-library-design.md`
- **Artifacts**: plans/01_record-versioning-rule-and-library.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

State the policy that deliverables outside `specs/**` describe the current design only and never
narrate their own draft history, and build the single mechanical source of truth that this rule's
two later enforcement consumers (a repo-wide lint, a write-time hook) will both source. The work
lands entirely in the source store `agent-system/extensions/core/` — never in the disposable
`.claude/` deploy tree — as three deliverable files plus a directly-executable test suite plus
three wiring surfaces. Done means: the rule is structurally parallel to its sibling
`rules/no-task-references-in-deliverables.md`, the taxonomy enumerates every category with a
BLOCKING/ADVISORY tier and the `version-ok` marker convention, the shared library is shellcheck
clean and sourceable standalone, the discriminator returns zero BLOCKING findings on the
already-swept Verification repo tree, and the full 21-gate set is green after a redeploy.

### Research Integration

`reports/01_rule-taxonomy-and-pattern-library-design.md` supplies four findings this plan is
built directly on:

1. **The sibling triad is a complete template.** Section shapes, the `is_exempt_path` /
   `strip_exempt_regions` signatures, the marker mechanics, and all three wiring surfaces are
   directly reusable.
2. **One wiring correction to the dispatch's literal text.** `manifest.json`'s
   `provides.context` is a *directory-name* array (`"standards"` is already present), not a file
   array — so the new taxonomy file needs **no** `provides.context` edit. The dispatch's literal
   instruction to "add the standard to provides.context" describes a mechanism the current schema
   does not have; it is already satisfied. Re-confirmed live during planning.
3. **The hard design problem has a structural answer.** Discriminate the record-version axis from
   the three durable axes by *shape* (dotted semver, `@vN` pins, hyphen-embedded cache-key
   segments, schema-filename slugs) in a marker-free pre-filter pass, not by a curated string
   whitelist. "supersedes" must require an adjacent `v[0-9]` qualifier to fire — bare
   "supersedes" is live, legitimate usage in the Verification repo today.
4. **Tiering is empirically settled, not a guess.** The bare-past-tense vocabulary category
   produced 8+ matches in accepted, non-versioning decision-record prose; it must be ADVISORY,
   with a stated escalation to BLOCKING only when the same line also carries a non-durable-axis
   `v[0-9]` token.

The report also flags that the dispatch's quoted footprint numbers predate a reorganization of
the Verification repo (`docs/book-convention.md` -> `books/convention.md`;
`docs/architecture-decisions.md` -> `records/architecture-decisions.md` plus per-decision files).
Every count in this plan is therefore marked as a hypothesis to re-derive live, never carried
forward as fact.

### Plan-Time Discovery Not in the Research Report

**The eager-context budget has exactly zero headroom.** Running
`REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
during plan authoring returned `TOTAL: 65950 B`, against
`context/config/orchestrator-context-budget.json`'s recorded `eager_load.baseline_bytes` of
`65950`. `verify-deploy.sh` gate 20 sub-check B fails when the total is **greater than** the
baseline, so the tree currently sits exactly at the ceiling. A frontmatter-absent rule file is
counted in full as eager (confirmed in `measure-eager-context.sh`'s channel-4 loop: a rule with
no `paths:` value is added unconditionally), and the sibling rule measures 2,017 B. Adding this
task's eager rule plus a `merge-sources/claudemd.md` bullet will therefore overshoot the gate by
roughly 1.8-2.1 KB unless the plan offsets it. Phase 5 exists for exactly this and follows the
trim-and-relocate precedent recorded twice in that config's own `note` field.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, so no ROADMAP.md consultation was performed.

## Goals & Non-Goals

**Goals**:

- `rules/no-record-versioning-in-deliverables.md` — the eager rule, structurally parallel to its
  sibling: `## Path Pattern`, `## Principle`, an explicit exceptions list, a closing taxonomy
  pointer, and the deliberate no-`paths:`-frontmatter HTML comment rationale.
- `context/standards/record-version-exemptions.md` — the full taxonomy and enforcement
  narrative, with a per-category BLOCKING/ADVISORY tier column and the `version-ok` marker
  convention.
- `scripts/lib/record-version-patterns.sh` — the ONLY place detection patterns, axis
  discrimination, tiering, and exemption logic are defined; shellcheck clean, sourceable
  standalone, Class C (no `set` line).
- `scripts/tests/test-record-version-patterns.sh` — executable positive/negative coverage, since
  no consumer exists yet to cover the library indirectly.
- All wiring surfaces: `manifest.json` (`provides.rules`, `provides.scripts`),
  `index-entries.json`, `merge-sources/claudemd.md`.
- Eager-context budget held at or under the recorded baseline without moving `baseline_bytes`.
- Zero BLOCKING discriminator findings on the Verification repo's `docs/` plus `README.md`.

**Non-Goals**:

- Building either enforcement consumer. The repo-wide lint and the write-time hook are separate,
  later tasks and are deliberately out of scope; the acceptance bar requires only a one-off
  *manual* discriminator run, not a wired gate.
- Re-opening the substance of the rule or the exempt-zone list. Both are ruled in the dispatch.
- Sweeping any repository for existing violations. The Verification repo's de-versioning sweep is
  already committed; this task builds the durable guard against recurrence.
- Editing `.claude/**` by hand. `.claude/` is a disposable deploy artifact regenerated from the
  source store; the only sanctioned way it changes here is a redeploy (Phase 6).
- Moving `eager_load.baseline_bytes`. That is a deliberate, reviewed change requiring explicit
  user authorization, never a silent re-derivation (see Risks).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Eager-context budget is at exactly zero headroom (65,950 / 65,950 B), so any eager addition fails gate 20 | H | H | Phase 5 reconciles by relocating an equal-or-greater byte count of narrative out of an eager surface into a non-eager home — the precedent recorded twice in `orchestrator-context-budget.json`'s own `note`. Keep the new rule compact and pointer-heavy. Contingency: a `baseline_bytes` move requires explicit user authorization and is never done silently |
| Forbidden vocabulary overlaps the three durable axes (`v1`/`v2` in toolchain pins, CI cache keys, schema filenames), making a naive regex noisy | H | M | `strip_durable_axis_lines` pre-filters by structural shape before any BLOCKING match; Phase 2 calibrates against a live corpus and must resolve every finding as sweep-miss-or-discriminator-bug before closing |
| The supersession/disposition-table category has zero real positive instances to calibrate against | M | H | Ship it as a low-confidence ADVISORY heuristic and state in the taxonomy that it is undercalibrated pending a real positive; do not force a brittle BLOCKING regex on it |
| Bare past-tense vocabulary is pervasive in legitimate decision-record prose (8+ accepted matches found in research) | M | H | ADVISORY tier, with an explicit, cheap escalation rule: promote to BLOCKING only when the same line also carries a non-durable-axis `v[0-9]` token |
| `shellcheck` fires SC2034 on externally-sourced pattern variables (the sibling library is not literally clean under this measure) | L | H | One `# shellcheck disable=SC2034` per exported variable, a precedented pattern in this source store |
| ugrep can silently fail to match a pattern chaining two or more independent `\b`-anchored subexpressions | M | L | Keep every new pattern to the single-`\b`-bracket shape per `context/standards/grep-word-boundary-portability.md`, and execute-test (never reason about) each pattern in Phase 2 |
| The dispatch's literal `provides.context` instruction would add a spurious, non-conforming file-level manifest entry | L | H | Phase 4 verifies `"standards"` is present and makes no edit there, recording the instruction as already satisfied rather than silently skipping it |
| Verification repo has drifted since the dispatch text was authored (files renamed and relocated) | M | H | Every count is a Scope Hypothesis; Phase 2 re-derives the footprint live and records actual numbers |
| A concurrent sibling task is dispatched on this same working tree this cycle | L | M | Re-read every file immediately before editing; stage an explicit file list only (never a directory or glob `git add`); never run `git-snapshot.sh` in its reverting default mode; report any foreign commit or modification rather than dismissing it |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is fully sequential: the
calibration pass (2) can change the library's pattern set, the taxonomy (3) documents the
calibrated tiers, the wiring (4) needs the taxonomy's actual `wc -l`, the budget reconciliation
(5) needs the rule's and the claudemd bullet's actual byte cost, and the gate set (6) needs all
of it deployed.

---

### Phase 1: Shared pattern library [COMPLETED]

**Goal**: Write `scripts/lib/record-version-patterns.sh` as the sole mechanical source of truth
for detection patterns, per-category tiering, axis discrimination, and exemption logic.

**Tasks**:

- [x] Re-read `scripts/lib/task-reference-patterns.sh` and `context/standards/shell-strict-mode.md` *(completed)*
      immediately before writing, to confirm the Class C posture (sourced-only, **no `set` line**)
      and the header-block shape.
- [x] Create the file with a header comment block modeled on the sibling's: one-line role *(completed)*
      statement; the "Neither consumer defines ... locally -- this is the ONLY place they are
      defined" sentence naming both planned consumers; a cross-reference to
      `context/standards/record-version-exemptions.md`; a `# Usage:` block showing `source`, the
      `grep -E` pairing (with `-i`), `is_exempt_path`, `strip_durable_axis_lines`, and
      `strip_exempt_regions` in the order a consumer must call them.
- [x] Section banner `# ─── Detection patterns ───`: define the BLOCKING set — *(completed)*
      a page-level-label pattern (a markdown heading or a `**Status**:` line carrying a `v[0-9]`
      token), a version-qualified supersession pattern (requires a `v[0-9]` token adjacent to
      `supersede`/`supersedes`/`supersession` — the bare word must NOT fire), the
      `(v1 Decision N)`-shaped attribution pattern, and the version-qualified migration-claim
      pattern ("carried forward from v1", "every v1 field removed" shapes).
- [x] Define the ADVISORY set: the bare past-tense vocabulary (`no longer`, `previously`, *(completed)*
      `formerly`, `used to`, `withdrawn`) and the low-confidence disposition-table heuristic (a
      heading matching `relates? to v[0-9]`, or a table header row carrying both a decision-number
      column and a `v[0-9]`-shaped column label).
- [x] Encode the tiering in the library so both consumers inherit it: export grouping variables *(completed)*
      (one BLOCKING group, one ADVISORY group) alongside the individual patterns, so neither
      consumer chooses a tier itself.
- [x] Keep every `\b` to a **single bracket** per `context/standards/grep-word-boundary-portability.md` *(completed)*
      — never two `\b`-anchored subexpressions chained across a wildcard run.
- [x] Add `# shellcheck disable=SC2034` immediately above each exported variable (the sibling's *(completed)*
      unannotated form does not pass a literal `shellcheck` run).
- [x] Section banner `# ─── Path-level exemption ───`: `is_exempt_path <path>` with the sibling's *(completed)*
      `case "$path" in specs/*|*/specs/*) return 0 ;; *) return 1 ;; esac` — the exemption is
      identical (exempt zone 1, plus zone 2 which is not a file path at all).
- [x] Section banner `# ─── Durable-axis exemption (marker-free) ───`: `strip_durable_axis_lines`, *(completed)*
      a stdin -> stdout filter modeled structurally on `strip_exempt_regions` (filter stdin, print
      survivors) but pattern-driven rather than marker-driven. Drop lines matching: dotted semver
      (`v[0-9]+\.[0-9]+`), `@v[0-9]+` action pins, hyphen-embedded CI cache-key segments
      (`[a-z]+-v[0-9]+-`), schema-artifact filename slugs (`v[0-9]+` adjacent to `.md`, `schema`,
      `toml`, or `cert`), and the dated `**Amended by** <doc>, <date>:` amendment-note line
      (exempt zone 4). Document in-comment that this is zone 3 made mechanical and needs no marker.
- [x] Section banner `# ─── Content-level exemption: marker convention ───`: *(completed)*
      `strip_exempt_regions` with the sibling's exact `awk` shape, substituting the three
      substrings `version-ok:begin`, `version-ok:end`, `version-ok`. Carry the sibling's comment
      explaining that comment syntax is irrelevant (plain substring match), that both forms
      require a trailing reason naming a taxonomy category, and that this function does not
      validate the reason text.
- [x] Run `shellcheck agent-system/extensions/core/scripts/lib/record-version-patterns.sh` and *(completed)*
      confirm exit 0.
- [x] Confirm the file is sourceable standalone: *(completed)*
      `bash -c 'source agent-system/extensions/core/scripts/lib/record-version-patterns.sh; is_exempt_path specs/x && echo exempt-ok; printf "a\n" | strip_exempt_regions >/dev/null && echo filter-ok'`.

**Timing**: 1.0 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the four-BLOCKING / two-ADVISORY pattern decomposition and the three
helper functions are carried from `reports/01_rule-taxonomy-and-pattern-library-design.md`'s
Recommendations item 3, not re-derived here. Confirm at implementation time by running Phase 2's
corpus pass before freezing variable names — if a single alternation covers a tier with no loss
of per-category reporting, collapse it rather than keeping a variable per category.

**Tier Justification**: the edit is one new sourced-only shell file with no consumer sourcing it
yet, fully covered by `shellcheck agent-system/extensions/core/scripts/lib/record-version-patterns.sh`
plus the standalone source-and-invoke smoke run in the task list above.

**Files to modify**:

- `agent-system/extensions/core/scripts/lib/record-version-patterns.sh` - new file: the shared
  pattern/tiering/exemption library

**Verification**:

- `shellcheck` on the new file exits 0 with no findings.
- The standalone `source` + `is_exempt_path` + `strip_exempt_regions` smoke run succeeds.
- The file contains no `set -e`/`set -u`/`set -o pipefail` line (Class C).
- Every exported variable carries a `# shellcheck disable=SC2034` annotation.

---

### Phase 2: Discriminator calibration and executable test suite [COMPLETED]

**Goal**: Prove the discriminator returns zero BLOCKING findings on the already-swept
Verification repo tree and the expected ADVISORY hits, then lock that behavior into an executable
suite that `run-all.sh` auto-discovers.

**Tasks**:

- [x] Re-derive the footprint live in `/home/benjamin/Projects/Logos/Verification`: *(completed)*
      `grep -rlE '\bv[0-9]\b' docs/*.md README.md`. Record the actual file list and per-file
      counts. Do NOT reuse the dispatch's or the research report's numbers.
- [x] Run the discriminator manually over that repo's `docs/`, `README.md`, `records/`, and *(completed)*
      `books/`: for each file, pipe content through `strip_durable_axis_lines` then
      `strip_exempt_regions`, then `grep -E -i` the BLOCKING group. Expect zero findings.
- [x] For every BLOCKING finding, resolve explicitly whether it is a real miss in the committed *(completed)*
      de-versioning sweep or a discriminator bug, and record which — do not close this phase with
      an unresolved finding.
- [x] Record the ADVISORY hit list separately (the "no longer" / "used to" / "formerly" prose the *(completed)*
      research found). A handful of ADVISORY hits is the expected, correct outcome, not a bug.
- [x] Write `scripts/tests/test-record-version-patterns.sh` modeled on *(completed)*
      `scripts/tests/test-phase-heading-patterns.sh` (the precedent for testing a sourced library
      directly). Include, per pattern, one real negative drawn from the live corpus and one
      positive: negatives `v4.31.0`, `book-cert-v2.md`, `lake-recheck-v3-`, bare
      "supersedes rule 3", "no longer holds", the dated `**Amended by**` line; positives
      synthesized from the dispatch's forbidden list (a `(v2)`-labeled heading, a
      `**Status**: v2, accepted ...; supersedes v1` line, a `(v1 Decision 4)` attribution, an
      "every v1 field removed" claim).
- [x] Add an assertion that `is_exempt_path` returns 0 for a `specs/**` path and 1 otherwise, and *(completed)*
      that `strip_exempt_regions` removes both the block and the inline `version-ok` forms.
- [x] Feed any pattern correction back into `scripts/lib/record-version-patterns.sh` and re-run *(completed)*
      `shellcheck` on both files.
- [x] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-record-version-patterns.sh` *(completed)*
      and confirm the suite is green.

**Timing**: 1.0 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: two figures are carried from
`reports/01_rule-taxonomy-and-pattern-library-design.md` (itself re-derived 2026-10-08) and must
be re-run live rather than reused — "eight files under `docs/` plus `README.md` match a bare
`\bv[0-9]\b`" and "zero page-level version labels remain in the current tree". Re-run the grep
and the discriminator pass at implementation time and record the actual numbers in this phase's
notes; if the file list has drifted again, the drift is expected and the live result governs.

**Tier Justification**: covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-record-version-patterns.sh`
plus `shellcheck` on the two touched shell files, since no other suite sources this library yet.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-record-version-patterns.sh` - new file:
  positive/negative fixture coverage for every pattern and all three helpers
- `agent-system/extensions/core/scripts/lib/record-version-patterns.sh` - pattern corrections
  surfaced by the calibration pass

**Verification**:

- The manual discriminator pass over the Verification repo returns **zero BLOCKING findings**;
  any finding is resolved as sweep-miss-or-bug and recorded before the phase closes.
- `run-all.sh --only test-record-version-patterns.sh` is green.
- `shellcheck` exits 0 on both touched shell files.

---

### Phase 3: Taxonomy standard and rule file [NOT STARTED]

**Goal**: Write the two prose deliverables — the on-demand taxonomy with per-category tiers and
the marker convention, and the compact eager rule that points at it.

**Tasks**:

- [ ] Re-read `context/standards/task-reference-exemptions.md` and
      `rules/no-task-references-in-deliverables.md` immediately before writing, to parallel their
      exact shapes.
- [ ] Write `context/standards/record-version-exemptions.md`:
      - Opening paragraph naming its companion rule, its on-demand loading status, and
        `scripts/lib/record-version-patterns.sh` as the mechanical source of truth this document
        describes but never redefines.
      - A `## State the Current Design Instead` worked Before/After example, with the quoted
        anti-pattern wrapped in `version-ok:begin` / `version-ok:end` carrying a reason naming a
        category (the document eats its own dog food, as the sibling does).
      - `## Exemption Taxonomy` table (`Category | Verdict | Marker required? | Example`)
        enumerating the four exempt zones: `specs/**`; git commit messages and PR/branch metadata;
        the three durable non-record axes (software/toolchain, file-format/schema, CI cache-key
        epoch) each as its own row with a live example; the dated cross-document amendment note.
        All four are marker-free.
      - `## Forbidden Categories and Tiers` table adding a **Tier** column: BLOCKING for
        page-level version labels, version-qualified supersession, the `(v1 Decision N)`
        attribution, and version-qualified migration claims; ADVISORY for the bare past-tense
        vocabulary, with the explicit escalation rule (promote to BLOCKING when the same line also
        carries a non-durable-axis `v[0-9]` token); ADVISORY (undercalibrated) for the
        disposition-table heuristic, stated as such pending a real positive instance.
      - `## Marker Convention`: `version-ok:begin` / `version-ok:end` block form and the inline
        `version-ok` form, matched as plain substrings so comment syntax is irrelevant; both
        require a trailing reason naming a category above; anything beyond the four exempt zones
        requires explicit user permission.
      - `## Enforcement` written **forward-looking**: the shared library exists; the repo-wide
        lint and the write-time hook do **not** exist yet, named by their planned filenames, and
        both will inherit the tiering from the library rather than each choosing it. A reader must
        never be misled into believing enforcement is already live.
      - Closing `## Design Principle: Discriminate the Record-Version Axis by Structural Shape,
        Not a String Whitelist` — record the three durable axes, the concrete shapes observed in a
        live repo, and the rule that a newly-encountered durable-axis shape is added to
        `strip_durable_axis_lines` without reopening the taxonomy's substantive ruling.
- [ ] Write `rules/no-record-versioning-in-deliverables.md`, deliberately compact (every byte is
      eager — see Phase 5):
      - The no-`paths:`-frontmatter HTML comment carrying this rule's own universal-scope
        rationale (any deliverable in any location could receive version language; a glob narrow
        enough to matter would have to be `**/*`), cross-referencing `source-store-deploy-boundary.md`
        and `pr-prohibition.md` as prior art for the same reasoning.
      - `## Path Pattern` — the entire repository except `specs/**/*`, git commit messages, and
        PR/branch metadata.
      - `## Principle` — deliverables state the current design only and never narrate their own
        draft history, with the forbidden list in compact form and the note that rejected
        alternatives are KEPT but stated on their own merits rather than attributed to an earlier
        draft.
      - `## Exceptions (version language IS permitted here)` — a flat bullet list of the four
        exempt zones, one short justification each.
      - Closing `## Full Taxonomy and Enforcement` pointer naming
        `.claude/context/standards/record-version-exemptions.md`,
        `scripts/lib/record-version-patterns.sh`, and the two planned consumer scripts by name.
- [ ] Cite only durable anchors in the rationale — the commit titled "docs: state the book
      convention without version history", `books/convention.md`,
      `records/architecture-decisions.md`, `docs/README.md`. **No task numbers** appear in either
      file (both live outside `specs/**`).
- [ ] Run `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` (doc-lint plus task-reference
      lint) and read the diff of both new files through end to end.

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: the category counts asserted above (four exempt zones, six forbidden
categories across two tiers) are the shape proposed in
`reports/01_rule-taxonomy-and-pattern-library-design.md` and settled by Phase 2's calibration.
Confirm the final counts once both files are written, and make the rule's closing pointer cite
the actual count — the sibling's "7-category" phrasing is count-specific and a stale number there
is a visible defect.

**Tier Justification**: both files are pure-guidance markdown with no executable surface, so
`suite_selection_select` returns `__FULL_SWEEP__` and no suite covers them; the honest covering
check is `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` plus the diff read-through the
`prose` tier prescribes.

**Files to modify**:

- `agent-system/extensions/core/context/standards/record-version-exemptions.md` - new file: full
  taxonomy, tier table, marker convention, forward-looking enforcement narrative
- `agent-system/extensions/core/rules/no-record-versioning-in-deliverables.md` - new file: the
  compact eager rule

**Verification**:

- The rule carries all four sibling-parallel sections plus the no-frontmatter HTML comment.
- The taxonomy's tier table assigns every forbidden category a BLOCKING or ADVISORY tier, and the
  tiers match what the library actually encodes.
- The Enforcement section states plainly that neither consumer exists yet.
- `verify-deploy.sh --only-gate 3,4` is green (no doc-lint finding, no task-number citation).

---

### Phase 4: Wiring (manifest, index entries, claudemd) [NOT STARTED]

**Goal**: Occupy all three wiring surfaces the sibling occupies, so the rule deploys, the library
and its suite are declared, and the deployed `CLAUDE.md` advertises the rule.

**Tasks**:

- [ ] Re-read each file immediately before editing (a sibling task is dispatched on this same
      working tree this cycle).
- [ ] `manifest.json`: add `"no-record-versioning-in-deliverables.md"` to `provides.rules`, beside
      the `"no-task-references-in-deliverables.md"` entry.
- [ ] `manifest.json`: add `"lib/record-version-patterns.sh"` and
      `"tests/test-record-version-patterns.sh"` to `provides.scripts`, each beside its sibling
      entry (`"lib/task-reference-patterns.sh"`, the `tests/` block).
- [ ] `manifest.json`: **verify** `provides.context` contains `"standards"` and make **no edit
      there**. Record in this phase's notes that the dispatch's literal "add the standard to
      provides.context" instruction is already satisfied by the directory-level entry — the array
      is directory-granular, and a file-level entry would not match the schema's actual shape.
- [ ] `index-entries.json`: add one object modeled exactly on the
      `standards/task-reference-exemptions.md` entry — `path`
      `"standards/record-version-exemptions.md"`, `domain` `"core"`, `subdomain` `"standards"`, a
      one-sentence `summary`, `line_count` from an actual `wc -l` of the written file, `keywords`
      (record-versioning, version-labels, deliverables, draft-history, `version-ok`), `topics`
      `["quality"]`, `load_when` with three empty arrays, `on_demand` `true`.
- [ ] `merge-sources/claudemd.md`: add one bullet to the "Rules References" core-rules list
      immediately beside the `no-task-references-in-deliverables.md` line, same one-line format.
      Keep it short — it is eager (see Phase 5).
- [ ] Validate both JSON files parse:
      `python3 -c "import json; json.load(open('agent-system/extensions/core/manifest.json')); json.load(open('agent-system/extensions/core/index-entries.json'))"`.
- [ ] Confirm membership with `jq -e` on each edited array (rule name present in
      `provides.rules`; both script paths present in `provides.scripts`; the new index entry
      findable by `path`).

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: "three strings added across two arrays, one bullet added, and
`provides.context` needs no edit" is carried from the research report's wiring finding and was
re-confirmed during plan authoring. Re-read `provides.context` live immediately before editing —
the no-op conclusion holds only while that array stays directory-granular.

**Tier Justification**: covered by a `python3 -c "import json; json.load(...)"` parse plus a
`jq -e` membership check on each edited array; declared-to-deployed parity is gate 5's job and is
reached in the final phase after the redeploy.

**Files to modify**:

- `agent-system/extensions/core/manifest.json` - one `provides.rules` entry, two
  `provides.scripts` entries; `provides.context` verified unchanged
- `agent-system/extensions/core/index-entries.json` - one new discovery entry for the taxonomy
- `agent-system/extensions/core/merge-sources/claudemd.md` - one bullet in the Rules References
  core-rules list

**Verification**:

- Both JSON files parse cleanly.
- `jq -e` confirms all three new array members and the new index entry.
- `provides.context` is byte-identical to its pre-phase state.
- The claudemd bullet sits immediately beside the sibling's and uses the same format.

---

### Phase 5: Eager-context budget reconciliation [NOT STARTED]

**Goal**: Keep the measured eager-load total at or under the recorded baseline after adding an
eager rule and a claudemd bullet, without moving `baseline_bytes`.

**Tasks**:

- [ ] Measure: `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
      and record the `TOTAL` line plus the per-file rules listing.
- [ ] Read `eager_load.baseline_bytes` from
      `context/config/orchestrator-context-budget.json` and compute the exact overage. Gate 20
      sub-check B fails only when the total is **greater than** the baseline, so landing exactly
      at it is acceptable.
- [ ] Close the overage by the method already recorded twice in that config's own `note`:
      relocate an equal-or-greater byte count of narrative **verbatim** out of an eager surface
      into a non-eager home, and verify each relocated clause is present in its new home
      **before** cutting the eager copy. Candidate pairs in order of established precedent:
      `rules/git-workflow.md` -> `context/standards/git-workflow-narrative.md`;
      `merge-sources/claudemd.md` -> an existing pointer target;
      `rules/artifact-formats.md` -> `context/reference/`.
- [ ] Re-measure and confirm `TOTAL` is at or under the baseline.
- [ ] Do **not** edit `baseline_bytes`. If no acceptable relocation closes the gap, stop and
      surface the question rather than moving the recorded ceiling — that is a deliberate,
      reviewed change requiring explicit user authorization.
- [ ] Append one dated sentence to the config's `note` field recording this reconciliation, in the
      same shape as the two existing dated entries (what was relocated, where to, and the landed
      figure relative to the unmoved baseline).

**Timing**: 1.25 hours

**Depends on**: 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the live total measured at plan-authoring time was **65,950 B against a
baseline of 65,950 B — exactly zero headroom** (re-derived by running
`measure-eager-context.sh --check`, not carried from any record), and the sibling rule measures
2,017 B. The required offset is the actual byte size of the new rule plus the new claudemd
bullet, which must be re-measured after Phases 3-4 rather than estimated from the sibling's size.

**Tier Justification**: covered by re-running
`REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check` and
comparing its `TOTAL` against `eager_load.baseline_bytes`, which is exactly gate 20 sub-check B's
own computation.

**Files to modify**:

- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` - one dated
  sentence appended to the `note` field; `baseline_bytes` untouched
- `agent-system/extensions/core/rules/git-workflow.md` - primary relocation source (narrative
  paragraphs cut after verification in their new home)
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` - primary relocation
  destination (relocated paragraphs added verbatim)

**Verification**:

- `measure-eager-context.sh --check` reports a `TOTAL` at or under
  `eager_load.baseline_bytes`, and zero volatile-file hits.
- `baseline_bytes` is byte-identical to its pre-phase value.
- Every relocated clause is grep-confirmable in its new non-eager home.
- The config's `note` carries a new dated entry describing the reconciliation.

---

### Phase 6: Redeploy, full gate set, and acceptance confirmation [NOT STARTED]

**Goal**: Deploy the source-store changes into `.claude/`, run the complete gate set green, and
re-confirm the acceptance criterion from the deployed library.

**Tasks**:

- [ ] Re-read every file touched in Phases 1-5 and run `git status --short`. Confirm no foreign
      uncommitted modification sits inside this task's own file set; if a foreign commit or
      modification is observed, check `git log` to confirm it is not this task's own work and
      report it rather than proceeding.
- [ ] Redeploy non-destructively:
      `bash agent-system/extensions/core/scripts/deploy-headless.sh`. This regenerates
      `.claude/` so it carries the new rule, the library, the test suite, and the reassembled
      `CLAUDE.md`.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` — no `--skip-slow`, no
      `--only-gate`. All gates must be green, notably gate 3 (doc-lint), gate 4 (task-reference
      lint), gate 5 (manifest-driven category parity and content-hash equality), gate 8
      (`tests/run-all.sh`, which auto-discovers the new suite by glob), gate 13 (whole-tree orphan
      detection), and gate 20 (eager-context budget).
- [ ] Re-run the acceptance discriminator pass from the **deployed** library
      (`.claude/scripts/lib/record-version-patterns.sh`) over
      `/home/benjamin/Projects/Logos/Verification`'s `docs/` and `README.md`: confirm **zero
      BLOCKING findings** and record the ADVISORY list as the expected outcome.
- [ ] Grep the three new deliverable files for task-number citations; gate 4 covers this
      repo-wide, but confirm directly since all three live outside `specs/**`.
- [ ] Confirm the library is still sourceable standalone from its deployed location.
- [ ] Commit with an explicit file list only — never a directory or glob `git add`, never
      `git add -A`, never `git commit -am`. Review `git status --short` and `git diff --staged`
      before committing.

**Timing**: 0.75 hours

**Depends on**: 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: "21 gates" is the live count derived from `verify-deploy.sh`'s own
`say "N. ..."` lines at plan-authoring time. Confirm the actual gate count and that every gate
reports green at implementation time rather than trusting this number; a gate added or removed
since plan authoring changes the count but not the obligation.

**Files to modify**:

- `.claude/**` - regenerated by `deploy-headless.sh`; never hand-edited

**Verification**:

- `bash .claude/scripts/verify-deploy.sh` — the complete gate set it aggregates — reports every
  gate green, with no `--skip-slow` and no gate subset.
- The acceptance discriminator pass over the Verification repo's `docs/` plus `README.md` returns
  zero BLOCKING findings, with every ADVISORY hit recorded and attributed.
- `.claude/rules/no-record-versioning-in-deliverables.md`,
  `.claude/context/standards/record-version-exemptions.md`,
  `.claude/scripts/lib/record-version-patterns.sh`, and
  `.claude/scripts/tests/test-record-version-patterns.sh` all exist in the deployed tree.
- The deployed `CLAUDE.md` advertises the new rule in its Rules References list.

---

## Testing & Validation

- [ ] `shellcheck` exits 0 on `scripts/lib/record-version-patterns.sh` and
      `scripts/tests/test-record-version-patterns.sh`.
- [ ] The library contains no `set` line and is sourceable standalone from both the source store
      and the deployed tree.
- [ ] `run-all.sh --only test-record-version-patterns.sh` is green; every pattern has at least one
      real negative from the live corpus and one positive.
- [ ] `is_exempt_path` returns 0 for `specs/**` paths and 1 otherwise.
- [ ] `strip_durable_axis_lines` drops all four durable-axis shapes plus the dated amendment note,
      and drops nothing else.
- [ ] `strip_exempt_regions` removes both the block and the inline `version-ok` forms.
- [ ] Manual discriminator pass over the Verification repo's `docs/` plus `README.md`: zero
      BLOCKING findings; ADVISORY findings enumerated and attributed.
- [ ] Both edited JSON files parse; all three new array members and the new index entry confirmed
      by `jq -e`.
- [ ] `measure-eager-context.sh --check` total at or under the unmoved `baseline_bytes`.
- [ ] `bash .claude/scripts/verify-deploy.sh` fully green after the redeploy.
- [ ] No task-number citations in any of the new deliverable files.

## Artifacts & Outputs

New files (source store, `agent-system/extensions/core/`):

- `rules/no-record-versioning-in-deliverables.md`
- `context/standards/record-version-exemptions.md`
- `scripts/lib/record-version-patterns.sh`
- `scripts/tests/test-record-version-patterns.sh`

Modified files:

- `manifest.json` (one `provides.rules` entry, two `provides.scripts` entries)
- `index-entries.json` (one new discovery entry)
- `merge-sources/claudemd.md` (one Rules References bullet)
- `context/config/orchestrator-context-budget.json` (one dated `note` entry)
- the eager/non-eager relocation pair chosen in Phase 5

Regenerated (never hand-edited): `.claude/**` via `deploy-headless.sh`.

Recorded (not a file deliverable): the Phase 2 and Phase 6 discriminator results — the live
footprint, the zero-BLOCKING confirmation, and the enumerated ADVISORY list.

## Rollback/Contingency

All work is additive plus narrowly-scoped wiring, so the revert path is mechanical: remove the
four new files, revert the four wiring and budget edits (and the Phase 5 relocation pair), then
re-run `bash agent-system/extensions/core/scripts/deploy-headless.sh` to bring `.claude/` back in
line. No existing behavior depends on any of it until the two consumer tasks land, so a partial
revert leaves nothing half-wired.

If a phase must be abandoned mid-way with uncommitted work, prefer fixing forward. For a genuine
rollback of uncommitted changes, follow `context/contracts/recovery.md`'s rollback rung for the
exact snapshot invocation shape, including its out-of-scope override flag for the deliberate
whole-tree case — never emit a bare reverting `git-snapshot.sh` as a routine start-of-phase
precaution, and use `--no-revert` for an ordinary defensive checkpoint instead.

Contingency on the one genuinely blocking risk: if Phase 5 cannot close the eager-context overage
by relocation, do not move `eager_load.baseline_bytes`. Stop, record the measured overage and the
relocation candidates already rejected, and surface the baseline move as a decision requiring
explicit user authorization.
