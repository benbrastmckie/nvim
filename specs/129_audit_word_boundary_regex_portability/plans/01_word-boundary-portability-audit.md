# Implementation Plan: Task #129

- **Task**: 129 - Empirically audit `\b` word-boundary grep patterns for compositional failure under the deployed grep
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: 88, 128, 261 (state.json). The sequencing dependency is a file-footprint
  collision avoidance only: `skill-orchestrate/SKILL.md` belongs to the adversarial-gate fix and
  is untouched here.
- **Research Inputs**: specs/129_audit_word_boundary_regex_portability/reports/01_word-boundary-grep-audit.md
- **Artifacts**: plans/01_word-boundary-portability-audit.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research phase completed the empirical audit and found **zero repairs required**: it also
corrected the dispatch's root-cause framing on the one point the dispatch itself warned would
"sink the audit" — "the deployed grep is ugrep 7.8.4" holds only for a command an agent types or
pastes into its own Bash-tool shell, while any `\b` pattern inside a `.sh` script or hook
executed as a subprocess resolves to GNU grep 3.12, which does not exhibit the compositional
defect at all. This plan therefore does two things: it **independently re-executes** the audit's
load-bearing empirical claims (the engine split, the 8 `file_scope` sites, and the two genuinely
ugrep-exposed agent-instruction Markdown files) so the recorded results are the implementer's own
observations rather than inherited assertions, and it **lands the portability guidance note** in
the source store with full index/deploy wiring so the defect class does not recur. Definition of
done: every site carries a freshly recorded empirical result, no working pattern was rewritten,
any pattern that does turn out broken is repaired and demonstrated against both a positive and a
negative real input, and the guidance note exists, is indexed, and is deployed.

### Research Integration

Key findings carried into the phase structure:

- **The engine split is the load-bearing fact** (report Finding 1). It is re-verified first
  (Phase 1) because every later scoping judgment depends on it: `.sh`/hook sites run GNU grep
  (immune), agent-instruction fenced-`bash` blocks run ugrep (exposed).
- **Only a *chain* of two or more `\b`-anchored subexpressions separated by a wildcard run is
  broken** under ugrep's `-E`. A lone `\b` or a single `\b...\b` bracket is not affected. This is
  the classification rule Phases 1 and 2 apply per site.
- **All 8 `file_scope` sites tested WORKING** (report Finding 2), via dedicated test suites where
  they exist and live runs otherwise. Phase 2 re-runs exactly those mechanisms rather than
  spot-testing fragments — the dispatch's BINDING CONSTRAINT forbids fragment-only evidence.
- **The dispatch's "CONFIRMED INSTANCE" is stale** (report Finding 3): `lean-sorry-census.sh`
  already uses a Python `(?<![.\w])sorry\b` negative lookbehind (fixed in commit `232b05b7f`) and
  its suite already carries the `set_option warn.sorry false in` fixture plus an anti-vacuous
  guard, 17/17 passing. Phase 2 re-runs that suite and records the result; no regex change and no
  new fixture is authored. The residual action is administrative and belongs to the consumer repo.
- **`literature-convert.sh` is a false positive** (`\begin{` contains the substring `\`+`b`), and
  `literature-chunk.sh`'s `XREF_PATTERN` is dead code. Both are recorded, neither is edited.
- **The guidance note text is already drafted verbatim in the report** and is adapted (not
  re-invented) in Phase 3, anchored to the existing `HOOK_REGEX_BOUNDARY_DEFECT` vocabulary entry
  in `patterns/system-defect-discrimination.md`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Re-execute, and record, a per-site empirical result for every genuine grep-pattern `\b` site in
  the source store, under the engine that actually runs it in production, with both a positive and
  a negative input where the site is at-risk-shaped.
- Repair only sites demonstrated BROKEN, choosing per-site between dropping `\b` where the
  surrounding delimiters already bound the token and switching that one invocation to `-P`.
- Land `agent-system/extensions/core/context/standards/grep-word-boundary-portability.md` stating
  the invocation-context split, the compositional (not "ignored") nature of the ugrep `-E` defect,
  the delimiter-anchored preference, and the execute-before-commit obligation.
- Wire the note into `agent-system/extensions/core/index-entries.json` and deploy it, so it is
  discoverable rather than orphaned in the source store.
- Cross-reference the note from the existing `HOOK_REGEX_BOUNDARY_DEFECT` entry so the defect
  vocabulary and the remediation guidance point at each other.

**Non-Goals**:
- Touching `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` or the
  adversarial-verification gate pattern — owned by a separate task, out of scope by dispatch.
- Rewriting any pattern demonstrated WORKING. A blanket `\b` removal is explicitly wrong:
  `guard-destructive-git.sh`'s `--hard\b` and `(drop|clear)\b` are live, and a false positive in a
  destructive-git guard is a worse outcome than the defect being audited.
- Changing `lean-sorry-census.sh`'s regex or adding the fixture the dispatch requested — both
  already exist upstream; re-verification replaces re-implementation.
- Editing the cslib consumer repo, or any file outside this repository.
- Removing `literature-chunk.sh`'s dead `XREF_PATTERN` (no live risk to mitigate; recorded as a
  note for whoever next touches that file).
- Hand-authoring anything under `.claude/**`; every edit targets `agent-system/extensions/**` and
  reaches `.claude/` only through a deploy.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer trusts the report's per-site table instead of re-running it, reproducing exactly the "reasoning instead of executing" trap the dispatch forbids | H | M | Phases 1-2 require the raw command and its observed output per site; a phase cannot close on a cited report row |
| A site is re-classified BROKEN, contradicting the report | M | L | Phase 2 carries an explicit repair branch: per-site choice of `\b` drop vs. `-P`, plus a mandatory positive-match AND negative-reject demonstration before commit |
| Repairing a guard pattern introduces a false positive in `guard-destructive-git.sh`, weakening a live destructive-git block | H | L | That file's 50-case suite is the gate; any edit there must keep 50/50 and add a negative case for the specific rewritten branch |
| Verification runs under the wrong engine (e.g. a `.sh` site tested by pasting its pattern at the Bash-tool top level) and reports a phantom failure | H | M | Phase 1 pins the engine-determination procedure first; every later site records which engine its evidence was gathered under |
| Guidance note lands in the source store but is never indexed or deployed, so nobody reads it | M | M | Phase 4 makes the index entry, the line-count check, and the deploy+validate round a gating step, not an afterthought |
| Note text drifts into the imprecise "ugrep is the deployed grep" framing the dispatch warns about | M | M | Phase 3 requires the invocation-context split to be the note's first assertion, and a reviewer read-back against Finding 1 |
| A note authored outside `specs/**` cites a task number, tripping the deliverable lint | L | M | Phase 3 runs `check-task-references.sh` over the new and edited files before commit |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 1 and 2 are independent: Phase 1
establishes the engine-determination procedure and audits the ugrep-exposed Markdown sites;
Phase 2 audits the `.sh`/hook sites through their own test mechanisms. Phase 3 needs both, because
the note asserts what they observed.

---

### Phase 1: Re-establish the engine split and audit the ugrep-exposed sites [COMPLETED]

**Goal**: Independently reproduce the invocation-context engine split, then execute every
genuinely ugrep-exposed `\b` site (the fenced-`bash` blocks in the two lean agent-instruction
Markdown files) as its full unmodified production pattern against a real positive input and a real
negative input under the deployed ugrep.

**Tasks**:
- [x] Record the engine in each of the two contexts, as raw commands with their output: `grep --version` and `type grep` at the Bash-tool top level; `bash -c 'grep --version'`, `env -i bash -lc 'grep --version'`, and a literal `bash /tmp/.../probe.sh` whose body is `grep --version`. *(completed)*
- [x] Reproduce the compositional failure directly: run the unmodified gate pattern `\|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b[^|]*\|` with `-i` against the literal header line `| Claim | Source / counterexample | Verification method | Confidence |` at the Bash-tool top level (expect NOMATCH), then the same pattern with `-P` (expect MATCH), then the same pattern inside a `.sh` file run as `bash file.sh` (expect MATCH under GNU grep). *(completed)*
- [x] Re-enumerate the ugrep-exposed site set: search `agent-system/extensions/**/*.md` for `\b` occurrences inside fenced `bash` blocks that are meant to be pasted into an agent's own Bash tool, and confirm or correct the report's set (`lean/agents/lean-implementation-agent.md`, 4 sites; `lean/agents/lean-implementation-hard-agent.md`, 1 site). *(completed: count and file set confirmed exactly as reported)*
- [x] Build a realistic Lean fixture in the scratchpad (a `Foo.lean` containing `theorem foo_bar_baz`, `noncomputable def helper_widget`, `lemma old_name_helper`) plus negative probes (`old_name_helperx`, a nonexistent name). *(completed)*
- [x] For each enumerated site, run its full unmodified pattern (with its real variable values substituted) at the Bash-tool top level under ugrep against the positive fixture and against the negative probe; record both results verbatim. *(completed)*
- [x] Classify each site WORKING or BROKEN on that evidence alone, and record whether its shape is a lone `\b` / single `\b...\b` bracket (unaffected) or a chain of two or more `\b`-anchored subexpressions separated by a wildcard run (at risk). *(completed: all 5 sites WORKING, all single-\b-shaped)*
- [x] Repair only sites classified BROKEN: prefer dropping `\b` where the surrounding pattern already delimits the token, otherwise switch that one invocation to `-P`. Re-run the positive and negative inputs after the edit. If none is broken, make no edit and record that. *(completed: none broken, no edit made)*
- [x] Write the per-site evidence (command, engine, positive result, negative result, classification) into the phase progress file so Phase 5 can lift it into the summary. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: The report asserts exactly 5 ugrep-exposed sites across exactly 2 files, all
single-`\b`-shaped and therefore all WORKING. Treat both the count and the file set as hypotheses:
confirm by re-running the enumeration search over `agent-system/extensions/**/*.md` before
accepting the set, and record the observed count even if it differs from 5.

**Files to modify**:
- None expected. `agent-system/extensions/lean/agents/lean-implementation-agent.md` and
  `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` are edited only if a
  site in them is demonstrated BROKEN.

**Verification**:
- Both engine contexts are recorded with their raw command output; the top-level context reports
  ugrep and the subprocess context reports GNU grep.
- The gate pattern reproduces NOMATCH under top-level `-E`, MATCH under `-P`, and MATCH inside a
  `.sh` file — the compositional defect is demonstrated, not cited.
- Every enumerated site has a positive-input result and a negative-input result recorded, under a
  named engine.
- No WORKING site was edited.

---

### Phase 2: Re-execute the `file_scope` and `.sh`/hook site audit [COMPLETED]

**Goal**: Re-run every `.sh`/hook `\b` site through the mechanism that actually exercises it in
production (its dedicated test suite where one exists, a live run of the script otherwise), record
the observed result per site, and repair only sites demonstrated BROKEN.

**Tasks**:
- [x] Re-enumerate genuine grep-pattern `\b` sites across `agent-system/extensions/**`, excluding LaTeX/Typst macro false positives (`\begin`, `\bf`, `\bigl`, `\bullet`, `\binom`, `\bot`, ...), `sed`/jq/Python-`re` patterns, and prose mentions. Record the observed count against the report's ~32 call sites / ~26 pattern definitions. *(completed: enumeration reconfirms the report's site set; 3 additional non-grep constructs inspected and excluded — sed in generate-task-order.sh, Python re in roadmap-integration.sh/literature_combining_detect.py)*
- [x] Run `extensions/core/scripts/tests/test-guard-destructive-git.sh` and record the pass/fail counts (covers `--hard\b` and `(drop|clear)\b`). *(completed: 50/50 pass)*
- [x] Run the deployed `check-extension-docs.sh` against every real extension and record the result (covers `[A-Za-z0-9_-]+\.(sh|sql)\b`). *(completed: PASS all 21 extensions OK)*
- [x] Run `extensions/core/scripts/tests/test-lint-postflight-boundary.sh` (covers `Agent\b` and the meta-pattern). *(completed: 6/6 pass)*
- [x] Run `extensions/core/scripts/test-session-runtime-files.sh` (covers `\$_seeded\b`, `\bexit\b`, `\breturn 1\b`). *(completed: 6/6 pass)*
- [x] Run `extensions/core/scripts/tests/test-lake-build-guard.sh` and record case 12b's result specifically, separating it from any pre-existing unrelated failure (report saw case 3 failing on stdout/stderr interleaving). *(completed: 47/0 this run — case 12b (\b assertion) PASS; case 3 also PASS this run, a discrepancy from the report recorded honestly, not \b-related)*
- [x] Re-verify `literature-audit.sh`'s P1-P4 extraction patterns by running the literal `grep -oE` lines, inside a `.sh` file so GNU grep is the engine, against a fixture containing `Theorem 3.1`, `Definition 2.4`, `Lemma 5`, `Theorem A`, and a `theoretically` false-positive probe; record extracted tokens and confirm the probe yields zero matches. *(completed: P1/P2/P3 all correct, probe 0 matches; P4 found to be documented-only with no live grep call — recorded as a finding)*
- [x] Run `extensions/lean/scripts/tests/test-lean-sorry-census.sh` and record the result, confirming the `set_option warn.sorry false in` fixture and the anti-vacuous guard are present and passing. Make no change to the script or its fixtures. *(completed: 17/17 pass, no code change made)*
- [x] Run the remaining covering suites and record results: `test-validate-no-task-references.sh` (`task-reference-patterns.sh`), `test-task-type-detect.sh` (`task-type-detect.sh`, 3 sites), `test-census-count.sh` (`\bTARGET\b`), `test-lean-comparator-run.sh` (`lean_lib[[:space:]]+\`?${name}\b`), and the `sess_930\b` assertion within `test-orchestrate-recover-message-findings.sh`. *(completed: 31/31, 10/10, 8/8, 22/22+1 skip, sess_930\b assertion PASS respectively)*
- [x] Confirm the two recorded non-sites by inspection and record them as such: `literature-convert.sh`'s `\\begin\{` false positive, and `literature-chunk.sh`'s defined-but-never-referenced `XREF_PATTERN` dead code. *(completed)*
- [x] Separate any observed failure into "`\b`/grep-related" vs. "pre-existing and unrelated" with a one-line justification each; only the former enters the repair branch. *(completed: all observed failures — test-lake-build-guard.sh none this run, test-orchestrate-recover-message-findings.sh's 2 acceptance-e2e failures — are pre-existing/unrelated, not \b-related)*
- [x] Repair branch (only for a site demonstrated BROKEN): choose per-site between dropping `\b` where the surrounding delimiters already bound the token and switching that invocation to `-P`; then demonstrate the repaired pattern matches a real positive input AND rejects a real negative input; for `guard-destructive-git.sh` specifically, keep the suite at 50/50 and add a negative case for the rewritten branch. *(completed: zero sites BROKEN, no repair made)*
- [x] Write the per-site evidence table into the phase progress file. *(completed)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The report asserts 8 `file_scope` files with every site WORKING, ~32 genuine
grep-`\b` call sites repo-wide (~26 distinct pattern definitions), and zero repairs needed. All
three are hypotheses: confirm the enumeration by re-running the search, and record the observed
counts and per-site classifications even where they differ from the report. A recorded mismatch is
a finding, not a plan error.

**Files to modify**:
- None expected. Any of the enumerated `.sh`/hook files is edited only if one of its sites is
  demonstrated BROKEN, and then only that one invocation.

**Verification**:
- Every enumerated site has a recorded result naming the mechanism that produced it and the engine
  it ran under; no row is satisfied by a citation to the research report.
- Every failure observed anywhere in the run is classified `\b`-related or pre-existing-unrelated,
  with justification.
- No WORKING pattern was rewritten.
- If any repair happened: positive-match and negative-reject evidence exists for it, and the
  covering suite still passes at its prior count or better.

---

### Phase 3: Author the portability guidance note [NOT STARTED]

**Goal**: Land `grep-word-boundary-portability.md` under the core standards context directory,
stating the audit's precise findings, and cross-reference it from the existing defect-vocabulary
entry.

**Tasks**:
- [ ] Create `agent-system/extensions/core/context/standards/grep-word-boundary-portability.md`, adapting the report's drafted text, with the invocation-context split as its **first** assertion: `.sh`/hook subprocess execution resolves to GNU grep; a command typed or pasted into an agent's own Bash-tool shell (including a fenced `bash` block copied out of an agent-instruction Markdown file) runs under ugrep.
- [ ] State the defect compositionally, not as a missing feature: ugrep's `-E` engine mis-evaluates a `\b` appearing downstream of an earlier `\b`-anchored subexpression separated by a wildcard run; every fragment can match in isolation while the composed pattern fails; `-P` on the identical unmodified pattern matches correctly. Include the bisection evidence shape as a worked example.
- [ ] State the shape rule: a lone `\b`, or a single `\b...\b` bracket around one token or alternation, is not known to be affected; only a chain of two or more `\b`-anchored subexpressions in one linear pattern is at risk.
- [ ] State the preference for delimiter-anchored alternatives where the surrounding pattern already bounds the token (a pipe-delimited table cell, a whitespace- or quote-bounded field), rather than adding further `\b`s to a pattern that already has one.
- [ ] State the `-P` remedy for the case where `\b` is genuinely needed and the pattern will run under ugrep.
- [ ] State the execute-before-commit obligation: any new `\b` pattern must be run against a real positive input AND a real negative input under the actual mechanism that will run it in production — never reasoned about, never tested as a simplified stand-in, never assumed safe by analogy to a working pattern elsewhere.
- [ ] Add a short "how to determine which engine applies" procedure (the `type grep` / `bash -c 'grep --version'` pair from Phase 1) so a reader can settle the question in one command rather than inferring it.
- [ ] Add a pointer to the note from the `HOOK_REGEX_BOUNDARY_DEFECT` entry in `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`, and a back-pointer from the note to that vocabulary entry.
- [ ] Verify the note contains no task-number reference and no reference to the separately-owned gate task: run `bash agent-system/extensions/core/scripts/check-task-references.sh` (or the deployed equivalent) and confirm the new and edited files are clean.
- [ ] Read the finished note back against report Finding 1 and confirm it nowhere asserts that ugrep is unconditionally "the deployed grep".

**Timing**: 0.75 hours

**Depends on**: 1, 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/standards/grep-word-boundary-portability.md` - new file, the guidance note
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` - add a pointer from the `HOOK_REGEX_BOUNDARY_DEFECT` entry to the new note

**Verification**:
- The note exists at the stated path and its first substantive assertion is the invocation-context
  split.
- All five required points are present: engine split, compositional defect, shape rule,
  delimiter-anchored preference, `-P` remedy, execute-before-commit obligation.
- `check-task-references.sh` reports no findings for the new and edited files.
- Both cross-reference directions resolve to real files and real headings.

---

### Phase 4: Index, validate, and deploy the note [NOT STARTED]

**Goal**: Make the note discoverable through the context index and present in the deployed tree,
with every relevant validator green.

**Tasks**:
- [ ] Add one entry for `standards/grep-word-boundary-portability.md` to `agent-system/extensions/core/index-entries.json`, matching the shape of the neighboring `standards/` entries: `path`, `domain: "core"`, `subdomain: "standards"`, `summary`, `line_count`, `keywords` (3-6, e.g. grep, regex, word-boundary, ugrep, portability), `topics`, `load_when` (empty agent/task_type/command arrays), `on_demand: true`.
- [ ] Confirm no `manifest.json` change is needed: `provides.context` enumerates directories (`standards`), not individual files — verify by reading the list rather than assuming.
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` and reconcile the new entry's `line_count` until it reports clean.
- [ ] Run `bash agent-system/extensions/core/scripts/check-extension-docs.sh` and confirm Rule T (index-entries schema conformance) reports no findings for the new entry.
- [ ] Deploy with `bash agent-system/extensions/core/scripts/deploy-headless.sh` (default non-destructive resync) so `.claude/context/standards/grep-word-boundary-portability.md` and the regenerated `.claude/context/index.json` appear.
- [ ] Run `bash .claude/scripts/validate-context-index.sh` and confirm the new path resolves and the entry's fields validate.
- [ ] Confirm the deployed copy matches the source copy byte-for-byte (`diff`), demonstrating the source store is the real edit target and nothing was hand-authored under `.claude/`.

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Exactly one new `index-entries.json` entry and zero `manifest.json` changes
are expected, on the hypothesis that `provides.context` is directory-granular. Confirm by reading
`manifest.json`'s `provides.context` list before concluding no manifest edit is required.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - one new entry for the note
- `.claude/context/standards/grep-word-boundary-portability.md` and `.claude/context/index.json` -
  regenerated by the deploy, never hand-authored

**Verification**:
- `generate-context-line-counts.sh --check` exits clean.
- `check-extension-docs.sh` reports no Rule T findings.
- The deployed note exists and `diff` against the source copy is empty.
- `validate-context-index.sh` reports no errors for the new entry.

---

### Phase 5: Record the audit evidence and close out bookkeeping [NOT STARTED]

**Goal**: Consolidate every per-site empirical result into the task's durable record, and record
the two administrative follow-ups the audit surfaced without acting outside this repository.

**Tasks**:
- [ ] Assemble the Phase 1 and Phase 2 evidence into a single per-site table in `specs/129_audit_word_boundary_regex_portability/summaries/01_word-boundary-portability-audit-summary.md`: site, file, full pattern as executed, engine, verification mechanism, positive-input result, negative-input result, classification, and repaired-or-untouched.
- [ ] Record explicitly in the summary that no WORKING pattern was rewritten, and list any repair with its positive-match and negative-reject evidence.
- [ ] Record the two administrative follow-ups: (a) `lean-sorry-census.sh` was already fixed upstream in commit `232b05b7f` with fixtures in place, so the cslib consumer repo's local task should be abandoned with a pointer to that commit and this audit once that repo re-syncs its extension copy — no cross-repo edit is made here; (b) `literature-chunk.sh`'s `XREF_PATTERN` is dead code, noted for whoever next touches the file.
- [ ] Record the dispatch-framing correction in the summary: the "CONFIRMED INSTANCE" text and the unqualified "the deployed grep is ugrep 7.8.4" framing were both stale, and state the corrected version.
- [ ] Append `agent-system/extensions/core/context/standards/grep-word-boundary-portability.md` to this task's `file_scope` in `specs/state.json`, appending rather than replacing the array.
- [ ] Confirm `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` is untouched across the whole task (`git diff --name-only` over the task's commits), satisfying the sequencing constraint.

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `specs/129_audit_word_boundary_regex_portability/summaries/01_word-boundary-portability-audit-summary.md` - new, the evidence record
- `specs/state.json` - append the note path to `file_scope`

**Verification**:
- The summary's table has a row for every site enumerated in Phases 1 and 2, each with a recorded
  positive and (where applicable) negative result and a named engine.
- The four acceptance criteria are each explicitly addressed in the summary.
- `skill-orchestrate/SKILL.md` appears in no diff produced by this task.

## Testing & Validation

- [ ] `test-guard-destructive-git.sh` passes at 50/50.
- [ ] `test-lean-sorry-census.sh` passes at 17/17, including the `set_option warn.sorry false in` fixture and the anti-vacuous guard.
- [ ] `test-lint-postflight-boundary.sh`, `test-session-runtime-files.sh`, `test-validate-no-task-references.sh`, `test-task-type-detect.sh`, `test-census-count.sh`, and `test-lean-comparator-run.sh` all pass at their recorded counts or better.
- [ ] `check-extension-docs.sh` reports all extensions OK, with no Rule T findings.
- [ ] `generate-context-line-counts.sh --check` exits clean.
- [ ] `validate-context-index.sh` reports no errors.
- [ ] `check-task-references.sh` reports no findings in the new or edited non-`specs/**` files.
- [ ] Any pre-existing unrelated failures (`test-lake-build-guard.sh` case 3;
  `test-orchestrate-recover-message-findings.sh`'s acceptance-e2e assertions;
  `test-lean-comparator-run.sh`'s binary-availability skip) are recorded as pre-existing with
  justification, not silently absorbed and not "fixed" opportunistically.

## Artifacts & Outputs

- `agent-system/extensions/core/context/standards/grep-word-boundary-portability.md` (new)
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` (pointer added)
- `agent-system/extensions/core/index-entries.json` (one new entry)
- `.claude/context/standards/grep-word-boundary-portability.md` and `.claude/context/index.json` (deploy output)
- `specs/129_audit_word_boundary_regex_portability/summaries/01_word-boundary-portability-audit-summary.md` (new)
- `specs/state.json` (`file_scope` append)
- Per-phase progress files under `specs/129_audit_word_boundary_regex_portability/progress/`

## Rollback/Contingency

- The expected footprint is one new markdown file, one pointer line, one JSON entry, and deploy
  output. Each is committed as its own green sub-step, so reverting a single phase is a targeted
  `git revert` of that commit — no working-tree discard is needed.
- If a repair in Phase 1 or 2 turns out to introduce a false positive (most consequentially in
  `guard-destructive-git.sh`), revert that one file's commit and record the site as WORKING-as-was
  with the failed-repair evidence, rather than leaving a weakened guard in place.
- If a genuine whole-tree rollback becomes necessary, follow `context/contracts/recovery.md`'s
  rollback rung for the exact snapshot-then-rollback invocation shape, including its
  out-of-scope override flag; do not emit a bare default-mode `git-snapshot.sh` as a routine
  precaution.
- If the deploy in Phase 4 misbehaves, `.claude/` is a disposable artifact: re-run
  `deploy-headless.sh` from the corrected source store rather than editing the deployed tree.
