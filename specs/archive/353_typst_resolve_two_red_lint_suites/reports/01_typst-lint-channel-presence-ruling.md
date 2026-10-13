# Research Report: Task #353

**Task**: 353 - Resolve the two red typst lint suites: chapter-quality-check.sh's stderr-into-JSON
corruption, and typst-element-lint.sh's presence-versus-density check overlap
**Started**: 2026-10-08T05:00:00Z
**Completed**: 2026-10-08T05:40:00Z
**Effort**: small (two narrow, disjoint fixes; no new interfaces)
**Dependencies**: None (the predecessor in state.json is a territory-serialization edge on the
shared `known-failures.txt` registry, not a work dependency -- see dispatch's own "WHY THE
DEPENDENCY EDGE EXISTS" section)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/typst/scripts/chapter-quality-check.sh`,
  `agent-system/extensions/typst/scripts/typst-element-lint.sh`, both suites' test files,
  `agent-system/extensions/core/scripts/lint/lint-json-channel-discipline.sh`,
  `agent-system/extensions/typst/context/project/typst/standards/semantic-element-usage.md`,
  `agent-system/extensions/core/scripts/tests/known-failures.txt`
- Live test runs: both named suites, plus `test-chapter-quality-check.sh` as a regression check
- `shellcheck 0.11.0` via `nix-shell -p shellcheck` against all four touched/adjacent scripts
**Artifacts**:
- This report: `specs/353_typst_resolve_two_red_lint_suites/reports/01_typst-lint-channel-presence-ruling.md`
**Standards**: report-format.md, subagent-return.md, shell-strict-mode.md

## Executive Summary

- **Item A** (channel corruption) is confirmed live and isolated to exactly one call site:
  `chapter-quality-check.sh:676`'s `check_placement()`. A full `lint-json-channel-discipline.sh`
  auto-discovery sweep of all 211 shipped (non-test) scripts under `agent-system/extensions/`
  found exactly one violation, at that line -- no sibling script anywhere in the extension tree
  (typst or otherwise) repeats the `2>&1`-then-parse-as-structured-output shape.
- The minimal, idiomatic fix is to **drop the `2>&1` entirely**, not to add a temp-file capture.
  `check_placement()` never inspects the sibling's stderr content, so letting stderr inherit the
  caller's own fd 2 (rather than merging it into the captured stdout payload) satisfies "still
  observable, not discarded" with no new temp-file lifecycle to manage.
- **Item B** (density vs. presence) is **not a bug in either check** -- both already behave
  exactly as their own header comments document. The fixture `case-h2` conflated two independent
  edge conditions (remarks below the density floor, AND zero theorem-family elements) into one
  assertion that only accounted for the first. Recommended ruling: **resolution (iii)** -- fix
  `case-h2` to carry one theorem-family element (isolating only the density-floor condition it was
  meant to test) and add a new fixture that positively exercises check 4's presence warning, a
  path the suite currently has **zero** coverage of.
- `semantic-element-usage.md`'s own Remark "Legal placement" rationale ("a remark typically
  follows some substantial result... because a reflection needs something to reflect on")
  independently supports check 4 firing on a remarks-only, zero-theorem-family file -- this rules
  out resolution (ii) (narrowing presence to "no semantic vocabulary at all"), which would weaken
  exactly the blind spot check 4 exists to catch.
- `known-failures.txt` rows for both suites are `category=real-defect`, `owner=needs-owner`.
  Both resolutions above are fix-track, not formal-acceptance-track, so both rows should be
  **deleted outright** once each suite is green -- not kept with a reassigned owner.
- `shellcheck 0.11.0` found **pre-existing, unrelated** findings in three of the four files this
  task's file_scope touches or sits beside (not introduced by, and not required to fix, either
  defect). These are enumerated under Findings and flagged as a scope decision for planning.

## Context & Scope

Task 353 batches two independent red suites in the typst extension, disjoint in subject files,
sharing only the extension and a shared advisory registry (`known-failures.txt`). Item A is a
mechanical defect with a stated fix direction; Item B explicitly requires "a ruling, not a patch"
and must not be rushed to match Item A's shape. This report investigates both to the point of a
concrete, justified recommendation, without editing any file (research phase).

## Findings

### Item A: channel-discipline violation, confirmed and isolated

`check_placement()` in `chapter-quality-check.sh` (line 676):

```sh
out=$(bash "$sibling" --verbose "$f" 2>&1)
while IFS= read -r line; do
  clean=$(printf '%s' "$line" | sed -E 's/\x1b\[[0-9;]*m//g')
  if [[ "$clean" == '[FAIL]'* ]]; then ...
  elif [[ "$clean" == '[WARN]'* ]]; then ...
  fi
done <<< "$out"
```

`2>&1` merges the collaborator's (`typst-element-lint.sh`) stderr into the captured `$out`, which
is then line-parsed for `[FAIL]`/`[WARN]` markers -- exactly the INGEST shape
`lint-json-channel-discipline.sh` flags (its header groups this with the jq-pipe and
here-string-fed-`while read` shapes as "the collaborator can still exit 0, so a degraded-path
warning never fires and the caller silently ingests a garbage row while reporting success").

Running `test-lint-json-channel-discipline.sh` against the real corpus today: 10/12 assertions
pass; the two real-corpus assertions fail with exactly one reported violation, at
`chapter-quality-check.sh:676`, and nowhere else among the 211 checked files.

**Sibling sweep (required by the dispatch's "ALSO SETTLE" instruction)**: a direct
`grep -rn '2>&1' agent-system/extensions/typst/scripts/` turns up matches only in the two test
files (`test-typst-element-lint.sh`, `test-chapter-quality-check.sh`), where `$(cmd 2>&1)` is
captured once and then only ever substring-`grep`-checked for literal `[FAIL]`/`[WARN]` text --
never re-parsed as a second-order structured payload, so these do not share the defect's risk
shape, and the lint's own design deliberately scopes to non-test `*.sh` files for this reason.
Combined with the full-corpus lint run above (which covers every shipped script in every loaded
extension, not just typst), the answer to "does any sibling script use the same shape" is:
**no** -- `chapter-quality-check.sh:676` is the only instance in the entire `agent-system/extensions/`
tree today.

**Why stderr is not actually observed firing in the one live corpus pass**: `typst-element-lint.sh`
only writes to stderr on CLI misuse (`unknown option`, `no PATH given`, `path does not exist`, `no
.typ files found`) -- none of which fire on the single-valid-file invocation `check_placement()`
makes. The lint still correctly flags the call site as a structural risk (a future stderr write --
e.g. a diagnostic added to the AWK-driving per-check logic -- would silently corrupt `$out` with no
warning), consistent with the task description's "reachable today, not theoretical" framing: the
shape is live and parsed as structured text now, even though no current stderr write happens to be
non-empty in the exercised path.

**Recommended fix**: remove `2>&1` so stderr is simply left unredirected (inherited from
`chapter-quality-check.sh`'s own fd 2), i.e.:

```sh
out=$(bash "$sibling" --verbose "$f")
```

This satisfies the acceptance bullet verbatim ("stdout and stderr separated and stderr still
observable (not discarded)") with the minimum possible change: `check_placement()` never needs to
inspect stderr content, only avoid letting it corrupt the stdout payload, so no `mktemp` capture
file is needed here. A different, heavier convention already exists in this codebase for the case
where a caller DOES need to inspect/relay captured stderr content specifically --
`orchestrate-predispatch-review.sh:466-480` captures stdout via `$(... 2>"$stderr_file")` and
separately `cat`s the stderr file when non-empty -- but that pattern is unneeded machinery here and
should not be copied reflexively.

**Regression check**: `check_placement()`'s stdout-only findings (`emit_blocking`/`emit_advisory`
in `chapter-quality-check.sh`, and `typst-element-lint.sh`'s own `[FAIL]`/`[WARN]`/`[INFO]` lines)
are all written via plain `echo -e` to stdout, never `>&2` -- confirmed by direct inspection of both
scripts. `test-chapter-quality-check.sh`'s placement-delegation assertions (`case-j`, `case-j2`)
capture `chapter-quality-check.sh`'s own combined output via an outer `2>&1` at the test level, not
by re-parsing the sibling's output a second time -- removing the inner `2>&1` does not change what
either test sees, since the sibling never writes to stderr in any exercised fixture. Ran
`test-chapter-quality-check.sh` live: 83/83 passing today, independent of this fix (confirms no
hidden coupling to inspect before changing the inner capture).

### Item B: both checks behave as documented; the fixture conflates two conditions

`typst-element-lint.sh` check 3 (density) and check 4 (presence) headers, verbatim:

- Check 3: "Guarded by an absolute floor so a file with few remarks and zero theorem-family
  elements does not warn merely because the ratio is undefined/trivial."
- Check 4: "...placement (check 1) can only police elements that are PRESENT; a chapter using
  none of the vocabulary is invisible to checks 1-3, which is exactly the drift this check exists
  to surface... A file outside this class and still legitimately narrative or not-yet-written is
  expected to WARN here -- that is the check doing its job, not a false positive to special-case
  away."

Both statements are about different axes: check 3's floor concerns the remarks-vs-theorems
*ratio* being undefined/trivial at low remark counts; check 4 concerns theorem-family *presence*
at all, independent of remark count. `case-h2` (2 remarks / 0 theorem-family elements, non-exempt
filename) sits exactly at the intersection: check 3 is silent (2 < `DENSITY_FLOOR=3`) exactly as
its floor is designed to do, but check 4 independently fires (family == 0, outside the
introduction/appendix-/glossary exemption) exactly as ITS header says it should. The fixture's
inline comment ("2 remarks / 0 theorems -- silent (absolute floor of 3 remarks not met)") and its
assertion (`assert_not_contains ... "[WARN]"`) both only account for check 3 -- the fixture's
author never considered check 4's independent trigger condition when writing this specific case.

**`semantic-element-usage.md` constrains the answer, and rules out resolution (ii)**: the
standard's own "Remark" section states, "A remark **typically follows some substantial result** --
a theorem, a proof, a definition that just landed -- because a reflection needs something to
reflect *on*." A file with remarks but zero theorem-family elements is precisely the shape this
sentence calls out as suspect: the remarks have nothing to reflect on. This is independent,
pre-existing documentation support for check 4 firing on exactly `case-h2`'s shape -- not merely
"check 4 isn't technically wrong," but "the standard that check 3 cites also independently
motivates check 4's behavior here." Resolution (ii) (narrow presence to require *zero semantic
vocabulary at all*, i.e. stay silent when remarks are present) would suppress the signal in
precisely the case the standard flags as most suspect -- a chapter that is all reflection and no
substance. Rejected.

**Resolution (i) is feasible but costlier than it looks.** The two WARN message strings are not
in fact indistinguishable -- density's message is anchored by the unique substring `"#remark
occurrences vs"` and presence's by `"zero theorem-family elements (definition/theorem/lemma/
corollary/example) in a file"` -- so a narrowed assertion *could* discriminate by a longer,
more-specific substring than the shared `"theorem-family"` token the dispatch calls out as
ambiguous. But this is substring-matching the rendered, colorized human-readable string, which is
exactly the fragile "discriminate by rendered text" approach the dispatch flags as needing "a
machine-readable discriminator rather than a substring match" to do properly -- a genuinely
machine-readable fix would mean exposing the AWK-driving loop's raw `WARN\tdensity\t...` /
`WARN\tpresence\t...` tag to callers (a new structured-output mode), which is a real interface
change to `typst-element-lint.sh`, out of proportion to what this fixture-authoring mistake needs.

**Checked: no existing fixture exercises check 4's presence warning firing at all.** A direct
search of `test-typst-element-lint.sh` for `presence`, `introduction`, `appendix-`, `glossary`, or
`exemption` returns zero matches. The suite has 37 assertions covering checks 1-3 densely but
**never positively exercises check 4** -- not its firing condition, not its exemption-class
basename matching. This is an independent, real coverage gap, not an artifact of the current
failure.

**Recommended ruling: resolution (iii).** Change `case-h2`'s fixture to carry one theorem-family
element (e.g. one `#theorem(...)` or `#definition(...)` alongside its two `#remark`s), which
isolates the density floor exactly as the fixture's comment always claimed to test (2 remarks <
floor of 3 stays silent) while also satisfying check 4 (family != 0, so presence stays silent
too) -- zero code changes to either check. Then add a **new** fixture (e.g. `case-h3`) with 2
remarks and 0 theorem-family elements under a non-exempt filename, asserting that the presence
`[WARN]` **does** fire with its documented message -- closing the coverage gap found above. This
changes only the fixture layer: no assertion elsewhere, and no check logic, is touched, which
satisfies the dispatch's "do not change more than one of the three without saying so" -- the
fixture is the one thing changed (plus one new, additive fixture), density and presence checks are
untouched, and the existing `assert_not_contains "[WARN]"` assertion for `case-h2` is *kept*
unchanged in meaning (it continues to assert "no warning fires on this density-floor-under-test
shape"), only the fixture content changes to make that assertion actually test what it claims to.

### `known-failures.txt`: both rows are fix-track, not acceptance-track

Both existing rows (`test-lint-json-channel-discipline.sh`, `test-typst-element-lint.sh`) carry
`category=real-defect`, `owner=needs-owner`. Given both rulings above resolve as code/fixture
fixes (not "the assertion was wrong and the check's current behavior is accepted as correct" --
in Item B's case the check's behavior IS being accepted as correct, but the thing being corrected
is the TEST, which is the dispatch's own explicit "ON FIX" path: "DELETE the row outright once the
suite is green under `tests/run-all.sh`"), both rows should be **deleted outright** once each
suite reaches 12/12 and 37/37 respectively. Neither row should be kept with
`owner=typst_resolve_two_red_lint_suites` under the formal-acceptance branch -- that branch is for
cases where the *assertion itself* is kept as permanently wrong/moot, which is not the outcome
here: in both cases the suite reaches 100% green with the recommended fixes, and a green suite
must not keep a known-failing exception per the file's own header ("A fixed suite must not keep a
known-failing exception; leaving the row is how a stale exception silently masks a future
regression of the same suite").

### Shellcheck baseline: pre-existing findings, unrelated to both defects

`shellcheck 0.11.0` (via `nix-shell -p shellcheck`) against the four scripts this task's
`file_scope` touches or sits beside:

| File | Finding | Pre-existing? |
|------|---------|----------------|
| `chapter-quality-check.sh:495` | SC2016 (info) -- literal backtick pattern inside single-quoted `grep -oE` regex, not an actual expansion bug | Yes, unrelated to `check_placement` (line 676) |
| `chapter-quality-check.sh:527` | SC2034 (warning) -- `ratio` local declared but unused in `check_claim_ratio` | Yes, unrelated |
| `typst-element-lint.sh:91` | SC2034 (warning) -- `SCRIPT_DIR` computed but never referenced anywhere else in the file | Yes, unrelated (this script resolves its sibling path differently; `SCRIPT_DIR` here is genuinely dead) |
| `test-lint-json-channel-discipline.sh:58,68` | SC2329 (info, unused `cleanup`... actually registered via `trap`, likely a shellcheck false-positive on indirect invocation) and SC2034 (warning, `LAST_STDERR` set but never read) | Yes, unrelated |
| `lint-json-channel-discipline.sh:60,207` | SC2034 (`YELLOW` unused), SC2016 (info, literal-backtick-in-single-quotes, same false-positive shape as above) | Yes, unrelated |
| `test-typst-element-lint.sh`, `test-chapter-quality-check.sh` | none | Clean today |

None of these findings sit on lines this task's recommended fixes touch. The dispatch's
acceptance bullet "Shellcheck clean per context/standards/shell-strict-mode.md" is unconditional,
and shellcheck operates file-wide (there is no way to scope a "clean" claim to only a diff), so
planning needs an explicit decision: either (a) treat "clean" as scoped to the touched
function/lines and leave these six pre-existing findings as an out-of-scope, documented carry-over,
or (b) fold in the handful of genuinely trivial one-line fixes (drop the unused `ratio`/`SCRIPT_DIR`/
`YELLOW`/`LAST_STDERR` locals; either requote or `# shellcheck disable=SC2016` the two literal-backtick
patterns with a one-line rationale) as collateral cleanup in the same task, since literally none of
them require any design judgment. Recommendation: (b) -- all six are mechanical, zero-risk, and
"shellcheck clean" reads as a per-file bar in context, not a per-diff one.

## Decisions

- **Item A fix shape**: remove `2>&1` from `chapter-quality-check.sh:676` (inherit stderr to the
  caller's own fd 2) rather than introducing a `mktemp`-based stderr capture file. No code in
  `check_placement()` needs to inspect stderr content, so the simpler of the two channel-separation
  conventions already present in this codebase (direct-inherit vs. `orchestrate-predispatch-review.sh`'s
  capture-and-relay) is the correct fit here.
- **Item B ruling: resolution (iii)**. `case-h2` is amended to include one theorem-family element
  (isolating the density-floor condition it was always meant to test); a new fixture is added to
  give check 4's presence-warning path its first positive-path test coverage. Neither check's
  logic changes. This is a FIX-track outcome, not a formal-acceptance-track outcome.
- **`known-failures.txt`**: both rows owned by this task are deleted outright once their suites
  are green -- neither is converted to a formally-accepted exception.
- **Shellcheck scope**: recommend folding the six pre-existing, trivial, unrelated findings
  (enumerated above) into this task's cleanup, since the acceptance bullet is unconditional and
  shellcheck has no diff-scoped notion of "clean."

## Recommendations

1. In `chapter-quality-check.sh`'s `check_placement()` (around line 676), change
   `out=$(bash "$sibling" --verbose "$f" 2>&1)` to `out=$(bash "$sibling" --verbose "$f")`,
   leaving stderr to inherit the caller's own fd 2 rather than merging it into the captured
   payload. Re-run `test-lint-json-channel-discipline.sh` and confirm 12/12.
2. In `test-typst-element-lint.sh`, amend the `case-h2` fixture (currently 2 remarks / 0
   theorem-family elements) to add exactly one theorem-family element (a `#theorem` or
   `#definition`), keeping its existing `assert_not_contains ... "[WARN]"` assertion, so it
   isolates only the density-floor condition. Add a new fixture (e.g. `case-h3`) with 2 remarks /
   0 theorem-family elements under a non-exempt basename, asserting the presence `[WARN]` DOES
   fire and contains the expected `"zero theorem-family elements"` text. Re-run
   `test-typst-element-lint.sh` and confirm 37/37 (or 38/38 if the new fixture adds an assertion
   count, whichever the implementation lands as -- the acceptance bullet's literal "37/37" should
   be read as "the existing 37 plus any new fixture's own assertions, all green," not as a hard
   ceiling that forbids adding coverage).
3. Delete both rows (`test-lint-json-channel-discipline.sh`, `test-typst-element-lint.sh`) from
   `agent-system/extensions/core/scripts/tests/known-failures.txt` once both suites are confirmed
   green under `scripts/tests/run-all.sh`.
4. Fold in the six pre-existing, trivial shellcheck findings enumerated in Findings (unused
   `ratio`/`SCRIPT_DIR`/`YELLOW`/`LAST_STDERR` locals; two literal-backtick-in-single-quotes
   SC2016 info findings, resolved by requoting or a one-line `# shellcheck disable=SC2016`
   justification) as collateral cleanup, so the acceptance bullet's "shellcheck clean" is
   literally true for every touched/adjacent file, not just the two defect fixes.
5. Redeploy from the source store (`agent-system/extensions/typst/**` and
   `agent-system/extensions/core/scripts/tests/known-failures.txt` are the edit targets; never
   hand-edit a deployed `.claude/**` copy) and re-run the full `scripts/tests/run-all.sh` sweep
   before closing the task, per the dispatch's acceptance bullets.

## Risks & Mitigations

- **Risk**: dropping `2>&1` silently changes behavior if some currently-untested code path in
  `typst-element-lint.sh` DOES write diagnostic text to stderr during a normal (non-CLI-misuse)
  run, and some caller depended on that text being folded into `$out`. **Mitigation**: confirmed
  by direct inspection that every `[FAIL]`/`[WARN]`/`[INFO]` line in `typst-element-lint.sh` is
  written via plain `echo -e` to stdout (fd 1), never `>&2`; the only stderr writes are the four
  CLI-usage-error paths, none of which are reachable from `check_placement()`'s single-valid-file
  invocation shape. Verified `test-chapter-quality-check.sh` (83/83) and
  `test-typst-element-lint.sh` depend on none of this.
- **Risk**: resolution (iii)'s new fixture could itself introduce a second, independent
  shellcheck or suite-structure issue if authored carelessly (e.g. reusing a `WORKDIR` subpath
  that collides with an existing case). **Mitigation**: the suite already uses per-case
  `$WORKDIR/case-N.typ` naming consistently; a new `case-h3.typ` following the same convention
  carries no new structural risk. Not something research can fully foreclose, but low-risk given
  the existing pattern density in this file.
- **Risk**: "shellcheck clean" scope ambiguity (file-wide vs. diff-scoped) could become a
  late-discovered gate failure if the implementation phase assumes diff-scoping and plan/gate
  checks assume file-wide. **Mitigation**: flagged explicitly above with a concrete, itemized
  fix list; recommend folding in the six trivial fixes now rather than deferring the ambiguity.

## Context Extension Recommendations

- **Topic**: direct-inherit vs. capture-and-relay as the two sanctioned stderr-separation idioms
  for this codebase's `2>&1`-into-structured-parse defect class.
- **Gap**: `context/standards/shell-script-testing.md` and the channel-discipline lint's own
  header document the INGEST/EMIT defect taxonomy thoroughly, but neither records that there are
  two legitimate fix shapes (plain `2>&1` removal when the caller never needs stderr content, vs.
  `orchestrate-predispatch-review.sh`'s `mktemp`-and-relay pattern when it does), and when to
  choose which.
- **Recommendation**: a short addendum to `lint-json-channel-discipline.sh`'s own header (or a
  pointer from it) naming both idioms and their selection criterion, so a future fix to a flagged
  violation does not default to the heavier capture-and-relay pattern out of caution when the
  simpler fix suffices. Not performed here since this is a meta/standards-authoring change outside
  this task's typst-scoped `file_scope`.

## Appendix

### Commands run

```
bash agent-system/extensions/core/scripts/tests/test-lint-json-channel-discipline.sh
bash agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh
bash agent-system/extensions/typst/scripts/tests/test-chapter-quality-check.sh
grep -rn '2>&1' agent-system/extensions/typst/scripts/
grep -n "presence\|introduction\|appendix-\|glossary\|exemption" agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh
nix-shell -p shellcheck --run "shellcheck -x <each touched/adjacent script>"
```

### Key file:line references

- `agent-system/extensions/typst/scripts/chapter-quality-check.sh:676` -- the Item A defect site
- `agent-system/extensions/typst/scripts/typst-element-lint.sh:26-35` -- checks 3/4 header rationale
- `agent-system/extensions/typst/scripts/typst-element-lint.sh:291-300` -- checks 3/4 implementation
- `agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh:250-259` -- `case-h2` fixture
- `agent-system/extensions/typst/context/project/typst/standards/semantic-element-usage.md:119-123` --
  Remark "Legal placement" rationale cited against resolution (ii)
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh:466-480` -- the heavier
  capture-and-relay stderr-separation convention, cited as an alternative not needed here
- `agent-system/extensions/core/scripts/tests/known-failures.txt` -- both rows this task owns
