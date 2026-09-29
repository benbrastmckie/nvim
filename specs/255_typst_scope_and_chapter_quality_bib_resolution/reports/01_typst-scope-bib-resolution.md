# Research Report: Task #255

**Task**: 255 - Reconcile typst extension scope ownership and fix chapter-quality-check.sh Rule 1.3 bib resolution
**Started**: 2026-09-29
**Completed**: 2026-09-29
**Effort**: medium (two independent-file-scope phases)
**Dependencies**: None
**Sources/Inputs**: agent-system/extensions/typst/ (EXTENSION.md, manifest.json, context/project/typst/**, scripts/chapter-quality-check.sh, scripts/tests/test-chapter-quality-check.sh), agent-system/extensions/core/scripts/lib/task-type-detect.sh, live reproduction against /home/benjamin/Projects/Logos/Verification
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Part 1 boundary decided**: `typst` owns presentation/quality of prose and chapters
  (including theorem/definition *presentation*, not their mathematical content); `lean4`/
  `formal`/`general` own originating and verifying mathematical content. Two of the four
  "contradicting" files (`textbook-standards.md`, `type-theory-foundations.md`) already carry
  their own `**Scope note**` disclaiming content-authorship and are *not* actually in tension
  with the extension boundary — only `chapter-quality.md` (content-quality judging) and, by
  extension, the "chapter/manual work routes to `general`" keyword gap are the real
  contradiction. EXTENSION.md's Scope section is nonetheless the one file that must change: it
  currently says categories 3/5 files evidence the extension actually owns.
- **Part 1 routing fix verified by direct execution, not assumption**: the current
  `keyword_overrides.typst.keywords` list cannot ever resolve a chapter/manual task to `typst`,
  because `agent-system/extensions/core/scripts/lib/task-type-detect.sh`'s weak-signal table
  (step 4) maps `chapter`/`textbook` to `general` while `typst`'s own weak-signal entry is a
  single keyword (`typst`) that can never reach the `>=2` distinct-match threshold on its own —
  so the ONLY viable fix point is the extension's own `keyword_overrides` (step 2, which
  precedes and overrides step 4). I built a scratch copy of `agent-system/extensions` with four
  added keywords and ran `detect_task_type` directly: `review and condense the typst manual
  chapters` now resolves to `typst` (was `general`), while `write a chapter for the textbook on
  group theory` (no "typst" mention) still resolves to `general`, and `prove a lemma about lean4
  theorem in mathlib` still resolves to `lean4` — no collision.
- **Part 2 both bugs reproduced live** against `/home/benjamin/Projects/Logos/Verification`,
  exactly as the dispatch describes. Root cause of BUG 2a confirmed structurally: the manual's
  root document (`typst/manual/LogosVerificationManual.typ`) declares
  `#bibliography("bibliography.bib", ...)` and `#include`s every chapter; no chapter file itself
  ever carries the declaration. BUG 2b confirmed by candidate count: `find` under repo root
  currently returns 2 `.bib` files (the real one plus a vendored
  `framed_channel/aeneas/.lake/packages/mathlib/docs/references.bib`); excluding `.lake/` (and
  the other named vendor/build directories) drops this to exactly 1, letting branch (b) resolve
  correctly on its own for this specific repro.
- **Recommended fix shape for Part 2**: (i) exclude `.lake/`, `.git/`, `node_modules/`,
  `target/`, `build/` from the branch-(b) `find`; (ii) add a nearest-ancestor walk — from the
  checked file's own directory up to the already-resolved `root` (inclusive) — checking, at each
  level, sibling `*.typ` files (non-recursive) for a `#bibliography("...")` declaration, using
  the first (nearest) match; this is a **new resolution attempt inserted between existing branch
  (a) and existing branch (b)**, never touching either. Verified this does not perturb the
  existing `dirscan` CLI fixture: `mktemp -d` workdirs in this environment are confirmed
  (tested directly) to NOT sit inside a git worktree, so `resolve_repo_root` for the nested
  fixture file falls back to `root == filedir`, giving the ancestor walk zero room to run — no
  regression, but flag for the implementer to re-verify empirically once the code exists (the
  dispatch's own caution about this fixture is well-founded in principle, just not realized in
  this exact fixture today).
- **Test case-f disposition**: remains valid unchanged. It is a genuinely bib-less, non-git
  fixture (`WORKDIR/nobib/case-f.typ`, zero `.bib` anywhere reachable, no ancestor levels to
  search) — it exercises the true "nothing resolves" path, which BOTH bug fixes leave alone. It
  needs no re-scoping, but the implementer must add it to an explicit "still-NOT-EVALUATED"
  case list alongside new 2a/2b regression cases so the suite documents *why* it still passes
  post-fix rather than leaving it looking untouched by coincidence.
- **PASSED-banner judgment call**: recommend upgrading the environment note to a distinct
  `[WARN]`-tier line specifically when the NOT-EVALUATED rule is tagged BLOCKING, and qualifying
  the final banner text (e.g. `CHAPTER QUALITY CHECK PASSED (1 BLOCKING rule not evaluated)`)
  when any BLOCKING rule went unevaluated for any checked file — while keeping the exit code at
  0. This preserves the header's explicit "never fail on unresolved bibliography" design while
  closing the "PASSED banner read in isolation is misleading" gap the dispatch flags. Argued in
  full under Decisions.

## Context & Scope

Two defects in the `typst` extension (source store: `agent-system/extensions/typst/`) that
jointly disable chapter-quality enforcement: (1) the extension's own scope documentation and
`keyword_overrides` misroute chapter/manual-prose work to `general`, so the typst agents that
would run the chapter-quality gate never get dispatched; (2) even when the typst
implementation agent does run, `chapter-quality-check.sh`'s BLOCKING Rule 1.3 (citation keys
resolve in the `.bib`) is silently skipped in the common multi-file-manual and
vendored-dependency cases. This research covers both parts; SCOPE DISCIPLINE keeps them as
independently committable phases (disjoint files: `EXTENSION.md` + `manifest.json` vs.
`scripts/chapter-quality-check.sh` + its test).

All edits described here are recommendations for the planning/implementation phases — this
research dispatch made no source-store edits. Every finding below was verified by direct
inspection or execution, not assumed.

## Findings

### Codebase Patterns

**Full context/project/typst/ inventory** (27 files) confirms the dispatch's claim that the
scope note undersells the corpus, but with an important correction: only two of the four named
categories are genuinely in tension with the current Scope text.

| File | What it actually contains | Already content-authorship-agnostic? |
|---|---|---|
| `standards/chapter-quality.md` | Four dimensions judging chapter **content** quality: SOURCE GROUNDING (claims trace to citations), ANTI-FLUFF DENSITY, PRESENTATION CLARITY, OPEN-QUESTION HONESTY | **No** — this is squarely about the quality of written prose content, not just its formatting |
| `standards/textbook-standards.md` | Definition-ordering, motivation requirements, professional tone, chapter structure | **Yes** — opens with an explicit `**Scope note**`: "Authoring the underlying mathematical content ... is not a `typst` task type concern" |
| `standards/type-theory-foundations.md` | DTT-vs-set-notation presentational convention for existing math content | **Yes** — carries the identical `**Scope note**` verbatim |
| `patterns/theorem-environments.md` | `thmbox` package invocation mechanics only; explicitly defers "what each environment is for" to `semantic-element-usage.md` | **Yes** — pure markup mechanics |
| `templates/chapter-template.md` | File-naming and `.typ` skeleton structure (imports, heading shape) | **Yes** — pure structural template, no content-authorship guidance |

So the actual contradiction is narrower than "roughly a third of the corpus" — it is
`chapter-quality.md` specifically (content-quality judgment) plus the consequence that
chapter/manual *review, condensing, and quality work* has nowhere else in this extension's
current Scope text to live, even though the extension already ships (and auto-loads, per
`index-entries.json`) exactly the standard that governs it.

**`index-entries.json` corroborates the extension already treats these as core, not
peripheral**: all five files above are wired with `load_when.task_types: ["typst"]`, and
`chapter-quality.md` and `textbook-standards.md` are auto-loaded for *both*
`typst-research-agent` and `typst-implementation-agent` — i.e., the extension's own mechanical
context-loading contract already behaves as if chapter/prose-quality work is typst's job.

**Enforcement is already live, not merely documented**: `agents/typst-implementation-agent.md`
runs `chapter-quality-check.sh --verbose` at Stage 4C (per phase) and Stage 5 (whole-document
final pass) as MUST DO items 7–8, and `agents/typst-research-agent.md` Stage 2 explicitly loads
`chapter-quality.md` "when the research feeds chapter content ... as calibration context."

**OBSERVED CONSEQUENCE reproduced directly.** Using
`agent-system/extensions/core/scripts/lib/task-type-detect.sh`'s public `detect_task_type`
function against the unmodified source store:

```
$ source agent-system/extensions/core/scripts/lib/task-type-detect.sh
$ detect_task_type "review and condense the typst manual chapters" specs/state.json agent-system/extensions
general
```

**Root cause traced past the extension's own `keyword_overrides` list to the core weak-signal
table.** `task-type-detect.sh`'s `DTD_WEAK_SIGNAL_TABLE` (step 4, the fallback reached whenever
no extension `keyword_overrides` entry matches in step 2) contains:

```
"general|textbook,chapter,thesis,dissertation"
"typst|typst"
```

Two consequences follow, and both matter for the fix:
1. `chapter`/`textbook` in a description are *already* weak signals for `general` — this is
   precisely why a bare "typst manual chapters" description falls through to `general` today.
2. `typst`'s own weak-signal entry has exactly **one** keyword. Since step 4 requires
   `>= DTD_WEAK_THRESHOLD` (2) **distinct** matched keywords for a type to win, `typst` can
   **never** resolve via step 4 on its own, no matter how many times "typst" appears in the
   text. **The extension's `manifest.json` `keyword_overrides` (step 2) is therefore the only
   place this can be fixed** — step 2 is checked before step 4 and, per its own doc comment, is
   "final (not subject to alias remapping by step 5)." This is a stronger and more precise
   justification for REQUIRED item 3 than the dispatch's framing (which reads as "the override
   list needs more phrases" without naming why step 4 can't pick up the slack) — it should be
   carried into the plan so the implementer doesn't try to fix this via the weak-signal table
   instead (which is out of `typst`'s file scope anyway per SCOPE DISCIPLINE, since it lives in
   `agent-system/extensions/core/`).

**Keyword-collision audit across every loaded extension's `keyword_overrides`** (all 20
`agent-system/extensions/*/manifest.json` files enumerated and diffed):

```
cslib:  lean, lean4, mathlib, theorem, proof, lint-fix   |  pr: pr, pull request, submit, upstream, branch, rebase, cherry-pick
email:  inbox, email, gmail, himalaya, notmuch, unsubscribe, junk mail, draft reply, mbsync, aerc, mail triage, logos, protonmail, proton
latex:  latex formatting, latex compile, latex compilation, latexmk, pdflatex, bibtex, biblatex, latex package, latex macro, vimtex, latex template, tex compile error, latex style
rust:   rust, cargo, rustc, clippy, crates.io
typst:  typst formatting, typst compile, typst compilation, typst package, typst template, typst style, typst layout, fletcher diagram
```

(all other extensions have empty `keyword_overrides`). No existing phrase collides with
`"typst chapter"`, `"typst manual"`, `"chapter quality"`, or `"chapter prose"`, and — because
`_dtd_scan_keyword_overrides` iterates `<extensions_dir>/*/manifest.json` in alphabetical
directory-name order and takes the first match — `typst` sorting after `latex`, `lean`,
`literature` in that order poses no risk either, since none of those manifests' keyword lists
contain "chapter" or "manual" in any form.

**Verified fix by direct execution** (not merely proposed): built a scratch copy of
`agent-system/extensions`, added four keywords to `typst.keywords`
(`typst chapter`, `typst manual`, `chapter quality`, `chapter prose`), and re-ran
`detect_task_type`:

| Description | Before | After |
|---|---|---|
| "review and condense the typst manual chapters" | `general` | `typst` |
| "typst chapter quality pass on the introduction" | (n/a, new phrasing) | `typst` |
| "write a chapter for the textbook on group theory" (no "typst") | `general` | `general` (unchanged — correct, no false positive) |
| "prove a lemma about lean4 theorem in mathlib" | `lean4` | `lean4` (unchanged — no collision) |

This satisfies ACCEPTANCE items 2 and 3 in a form the implementer can reuse directly as the
verification step (same four keywords, same test descriptions).

### Part 2: chapter-quality-check.sh Rule 1.3 bibliography resolution

**Both bugs reproduced live** against `/home/benjamin/Projects/Logos/Verification`:

```
$ bash .claude/scripts/chapter-quality-check.sh --verbose typst/manual/chapters/01-introduction.typ
...
[INFO] Rule 1.3 NOT EVALUATED: no resolvable .bib file (no #bibliography(...) declaration and
       zero or multiple *.bib candidates under /home/benjamin/Projects/Logos/Verification)
SCORE ...: MECHANICAL 4/6 | BLOCKING 0 | ADVISORY 7 | JUDGED 12 prompts pending
CHAPTER QUALITY CHECK PASSED (mechanical coverage only -- judged rules still pending adjudication)
```
Exit code 0, exactly as described.

**BUG 2a structural confirmation**: the manual's root document declares the bibliography and
includes every chapter; no chapter file carries the declaration itself.

```
$ grep -n '#bibliography' typst/manual/LogosVerificationManual.typ
261:#bibliography("bibliography.bib", title: [References], style: "ieee")
$ grep -n '#include' typst/manual/LogosVerificationManual.typ | head -3
186:#include "chapters/01-introduction.typ"
203:#include "chapters/02-core-logic.typ"
204:#include "chapters/03-verified-components.typ"
```

So branch (a) (`resolve_bibliography`'s `grep -m1 -oE '#bibliography\(...\)' "$f"`) can never
match any chapter file in this manual — exactly the file type Rule 1.3 exists to check.

**BUG 2b candidate-count confirmation**:

```
$ find /home/benjamin/Projects/Logos/Verification -type f -name '*.bib'
./typst/manual/bibliography.bib
./framed_channel/aeneas/.lake/packages/mathlib/docs/references.bib
```
Two candidates -> branch (b)'s `[[ ${#candidates[@]} -eq 1 ]]` test fails -> unresolvable.
Excluding `.lake/`, `.git/`, `node_modules/`, `target/`, `build/` from the same `find`:

```
$ find . -type f -name '*.bib' \( -path '*/.lake/*' -o -path '*/.git/*' \
    -o -path '*/node_modules/*' -o -path '*/target/*' -o -path '*/build/*' \) \
    -prune -o -type f -name '*.bib' -print
./typst/manual/bibliography.bib
```
Exactly one candidate. **Notable secondary finding**: for *this specific repro*, fixing 2b alone
(the exclusion) is already sufficient to resolve Rule 1.3 for `01-introduction.typ`, because
after exclusion there happens to be exactly one genuine `.bib` under the whole repo root, so
branch (b) succeeds on its own. BUG 2a is nonetheless a real, independent defect (per ACCEPTANCE
item 4, which names it as its own required demonstration) — it will resurface the moment a repo
has more than one genuine (non-vendored) manual/bibliography pair under the same root, which
branch (b)'s single-candidate assumption cannot disambiguate. Both fixes are required; do not
treat the 2b exclusion as making 2a optional.

**Recommended fix shape for BUG 2a — nearest-ancestor search, not full include-graph
resolution.** Consistent with the script's existing documented design philosophy ("KNOWN
LIMITATIONS: documented rather than solved with a full Typst parser"), recommend: walk upward
from the checked file's own directory to the already-computed `root` (inclusive), and at each
directory level, grep that level's own `*.typ` files (non-recursively — siblings only, not a
subtree scan) for a `#bibliography("...")` declaration; resolve the first (nearest) match's path
relative to that ancestor directory (reusing the existing `filedir`-relative resolution already
proven at lines 355–358, which this recommendation does not touch). For the reproduction case,
this resolves at exactly one level up (`chapters/` -> `manual/`, where
`LogosVerificationManual.typ` lives). This is inserted as a **new resolution attempt between the
existing branch (a) and branch (b)** — i.e. try declared-path-in-file (a, unchanged), then
ancestor-declared-path (new), then single-root-candidate (b, unchanged, but now `find`-excluded
per 2b). Document this as a new KNOWN LIMITATIONS bullet: the ancestor walk assumes a single
unambiguous declaring `.typ` file per level; two sibling `.typ` files at the same ancestor level
with conflicting `#bibliography(...)` declarations is left unresolved (falls through to branch
(b)), matching the script's existing "under-firing is the safer bias" philosophy for BLOCKING
rules.

**Existing test-suite interaction, checked concretely, not assumed.** I confirmed directly in
this environment that `mktemp -d` produces a workdir that is *not* inside any git working tree:

```
$ w=$(mktemp -d) && cd "$w" && git rev-parse --show-toplevel
fatal: not a git repository (or any of the parent directories): .git
```

`resolve_repo_root` therefore falls back to `root == "$(dirname "$f")"` (the file's own
directory) for every fixture in `test-chapter-quality-check.sh`. Working through each flagged
fixture under this concrete fact:

- **Case-f** (`WORKDIR/nobib/case-f.typ`, zero `.bib` anywhere, no declaration): `root ==
  filedir`, so the recommended ancestor walk has a range of exactly one directory (itself) —
  identical to today's behavior. **Disposition: case-f remains valid, unmodified.** It is the
  genuine "nothing resolves anywhere" case both fixes leave untouched. Recommend the
  implementer add an explicit comment at case-f noting it was re-examined against both new
  branches and confirmed unaffected, so a future reader does not mistake its survival for an
  oversight.
- **Case-a / case-e** (declared-path branch, `#bibliography("refs.bib")` present in-file):
  unaffected by definition — branch (a) is explicitly out of scope for this fix per the
  dispatch's "NARROWING FINDING," and neither is touched by either recommended change.
- **`dirscan` CLI fixture** (`nested/violation.typ` has no declaration and no local `.bib`;
  `dirscan/refs.bib` sits one level up from `nested/`): under the concrete non-git fallback
  confirmed above, `root` for `nested/violation.typ` computes to `dirscan/nested` itself (its
  own dirname), **not** `dirscan/` — so the recommended ancestor walk's range is
  `[dirscan/nested, dirscan/nested]`, i.e. it cannot reach `dirscan/refs.bib` either. **No
  regression against this fixture as currently written**, contrary to what a purely
  theoretical read of the fixture might suggest. This is a refinement of the dispatch's own
  caution (well-founded as a general principle — the fixture *would* be sensitive if `root`
  ever resolved above the file's own directory) rather than a contradiction of it: recommend the
  implementer still add one explicit assertion to the `dirscan` case confirming
  `nested/violation.typ`'s Rule 1.3 stays NOT EVALUATED post-fix, converting this from an
  unstated assumption into a checked regression guard.

**Header contract update required in the same commit** (per dispatch and per the script's own
documented rule-inventory-must-never-drift contract): lines 99–101's bibliography-resolution
prose must be rewritten to state the three-branch order (declared-path -> nearest-ancestor
declared-path -> single-root-candidate-after-exclusion) and must name the five excluded
directory patterns.

## Decisions

1. **Boundary (Part 1, REQUIRED item 1)**: `typst` owns presentation and quality of prose and
   chapters, including the *presentation* of theorems/definitions (how they are marked up,
   formatted, and how their surrounding prose is quality-checked for grounding/density/clarity/
   honesty). `lean4`/`formal`/`general` own originating and mathematically verifying content —
   deciding what a proof says, whether a claim is true, or authoring new mathematical results.
   Argument: every context file inspected that discusses theorems/DTT (`theorem-environments.md`,
   `type-theory-foundations.md`) is pure presentation/notation-convention material, and the two
   files with an explicit scope note already draw exactly this line themselves ("Authoring the
   underlying mathematical content ... is not a `typst` task type concern"). `chapter-quality.md`
   is the one file that is genuinely about content — but it judges quality of *already-written*
   prose (sourcing, density, clarity, honesty), not correctness of mathematical claims, so it
   sits naturally on the "presentation/quality of existing content" side of the line, not the
   "originate new mathematical content" side.
2. **EXTENSION.md Scope rewrite (Part 1, REQUIRED item 2)** — recommended replacement text for
   the "### Scope" section (edit lands in `agent-system/extensions/typst/EXTENSION.md`, the
   `claudemd` merge source for `.claude/CLAUDE.md` section `extension_typst`, never the deployed
   file directly):

   > This extension covers formatting, compilation, styling, structural concerns, and the
   > presentation quality of existing document content — including chapter/manual prose review,
   > condensing, and the chapter-quality gate (source grounding, anti-fluff density, presentation
   > clarity, open-question honesty). Originating or mathematically verifying new content (new
   > proofs, new theorems, new results) is not a `typst` concern and routes to `lean4`, `formal`,
   > or `general` as appropriate; `typst` owns how that content is written up and presented once
   > it exists, and the measurable quality of that write-up.

3. **Keywords (Part 1, REQUIRED item 3)** — add exactly these four qualified phrases to
   `manifest.json`'s `keyword_overrides.typst.keywords` (verified via direct execution above, no
   collision against any other loaded extension's keyword list): `"typst chapter"`,
   `"typst manual"`, `"chapter quality"`, `"chapter prose"`. Deliberately avoided bare `"chapter"`
   or bare `"manual"` per the dispatch's KEYWORD SAFETY CONSTRAINT — both would fire on unrelated
   `general`/other-extension descriptions that merely mention a book chapter or a user manual.
4. **PASSED-banner surfacing (Part 2, severity question)**: upgrade the per-file environment
   note to `[WARN]` (distinct from plain `[INFO]`) specifically when the skipped rule is tagged
   BLOCKING in the standard, and append a qualifier to the final banner
   (`CHAPTER QUALITY CHECK PASSED (N BLOCKING rule(s) not evaluated)`) whenever any checked file
   had at least one BLOCKING rule go NOT EVALUATED — while leaving the exit code at 0 for this
   condition, unchanged. Rationale: the header's "never fail on unresolved bibliography" design
   is deliberate and load-bearing (an unresolvable `.bib` is an environment fact, not a chapter
   defect, so failing the build over it would be exactly the "fires on correct documents" failure
   mode this script's own advisory-severity philosophy exists to avoid) — so exit-code behavior
   should not change. But a `[WARN]`-tier line and a qualified banner cost nothing in
   false-positive risk while directly closing the dispatch's own stated problem: "misleading to
   anyone reading only the last line." This requires a new global counter (a `TOTAL_BLOCKING_
   SKIPPED`-shaped variable, incremented inside `emit_not_evaluated` when the rule argument is
   known-BLOCKING) since the existing `FILE_RULE_NOTEVAL` array is reset per-file and cannot
   answer "did any file skip a BLOCKING rule" on its own by the time the final banner prints.

## Risks & Mitigations

- **Risk**: a future contributor adds another BLOCKING rule that can also go NOT EVALUATED
  (mirroring Rule 1.3) without wiring it into the new global skip-counter recommended in Decision
  4, silently regressing the banner-qualifier fix. **Mitigation**: recommend the implementer make
  `emit_not_evaluated` itself look up the rule's BLOCKING/ADVISORY tag (a small table already
  implicit in the standard's rule list) rather than hardcoding "1.3 is BLOCKING" at each call
  site, so the counter increments automatically for any future NOT-EVALUATED BLOCKING rule.
- **Risk**: the nearest-ancestor search (BUG 2a fix) could, in a real (non-fixture) repository
  with an unusual layout, ascend past the intended manual root and pick up an unrelated
  `#bibliography(...)` declaration from a sibling project sharing the same git top-level.
  **Mitigation**: bounding the walk at the already-resolved `root` (git top-level or fallback)
  keeps the blast radius identical to the existing branch (b)'s scope; this is the same
  trust boundary the script already accepts for branch (b), not a new one.
- **Risk**: the `dirscan`-fixture non-regression finding above is contingent on `mktemp -d`
  never resolving inside a git worktree in the implementer's environment. This held here and is
  a safe general assumption (`TMPDIR` defaults to `/tmp`, not inside any repo), but is worth a
  one-line comment in the test file rather than a silent assumption, in case a future CI
  environment sets `TMPDIR` unusually.
- **Risk (scope discipline)**: Part 1 and Part 2 touch disjoint files but share the acceptance
  question; an implementer under time pressure might be tempted to land them as one commit.
  **Mitigation**: the dispatch's own SCOPE DISCIPLINE already mandates two separate commits;
  carry this into the plan explicitly as two phases.

## Context Extension Recommendations

- **Topic**: chapter/manual prose-review and chapter-quality-check invocation guidance for
  `typst-research-agent`.
- **Gap**: `context/project/typst/README.md`'s "For Research" / "For Implementation" load lists
  do not mention `chapter-quality.md` at all (only `typst-style-guide.md` and
  `theorem-environments.md` for research), even though `index-entries.json` and
  `typst-research-agent.md` Stage 2 both already treat it as core, conditionally-loaded context.
- **Recommendation**: once the Scope rewrite lands, update `context/project/typst/README.md`'s
  "Key Files" and "For Research"/"For Implementation" sections to list
  `standards/chapter-quality.md` alongside the existing entries, so a human skimming the README
  sees the same picture the index and agents already act on.

## Appendix

- Commands run: `detect_task_type` (baseline and scratch-copy-with-added-keywords, four test
  descriptions), `grep`/`jq` inventory of all `agent-system/extensions/*/manifest.json`
  `keyword_overrides`, `find`/`grep` reproduction against
  `/home/benjamin/Projects/Logos/Verification` (both un-excluded and exclusion-simulated `.bib`
  search), `git rev-parse --show-toplevel` from a fresh `mktemp -d` to confirm non-git fallback
  behavior, `bash .claude/scripts/chapter-quality-check.sh --verbose typst/manual/chapters/01-introduction.typ`
  in the Verification repo (live reproduction).
- Files read in full or in relevant part: `agent-system/extensions/typst/EXTENSION.md`,
  `manifest.json`, `README.md` (context and extension-root), every file under
  `context/project/typst/` listed in the inventory table, `agents/typst-research-agent.md`,
  `agents/typst-implementation-agent.md` (Stage 4C/5 and MUST DO sections),
  `scripts/chapter-quality-check.sh` (header, `resolve_bibliography`, `check_bib_keys`,
  `process_file`, final summary/banner), `scripts/tests/test-chapter-quality-check.sh` (all
  cases a/e/f, dirscan CLI fixture), `agent-system/extensions/core/scripts/lib/task-type-detect.sh`
  (full resolution ladder, all five steps).
