# Research Report: Task #280

**Task**: 280 - Record-versioning rule, taxonomy, and pattern library (SOURCE STORE:
agent-system/extensions/core/)
**Started**: 2026-10-08
**Completed**: 2026-10-08
**Effort**: medium
**Dependencies**: None (foundational task; 281 and 282 depend on this one)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/rules/no-task-references-in-deliverables.md`,
  `agent-system/extensions/core/context/standards/task-reference-exemptions.md`,
  `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh`,
  `agent-system/extensions/core/scripts/check-task-references.sh`,
  `agent-system/extensions/core/hooks/validate-no-task-references.sh`,
  `agent-system/extensions/core/manifest.json`, `index-entries.json`, `merge-sources/claudemd.md`,
  `agent-system/extensions/core/context/standards/shell-strict-mode.md`,
  `agent-system/extensions/core/context/standards/grep-word-boundary-portability.md`
- External repo cross-check: `/home/benjamin/Projects/Logos/Verification` (the "Verification
  repo" named in the dispatch) — `docs/*.md`, `README.md`, `records/architecture-decisions.md`,
  `records/architecture-decisions/*.md`, `books/convention.md`, `docs/records.md`
- `shellcheck` run against the sibling library
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The sibling (`no-task-references-in-deliverables.md` / `task-reference-exemptions.md` /
  `task-reference-patterns.sh`) is a complete, working template. Every required section shape,
  the marker-convention mechanics, the `is_exempt_path`/`strip_exempt_regions` function
  signatures, and the manifest/index/claudemd wiring pattern are all directly reusable.
- **One wiring correction to the dispatch's literal instructions**: `manifest.json`'s
  `provides.context` array lists whole subdirectories (`"standards"`), not individual files —
  `standards/task-reference-exemptions.md` has no file-level entry there today. The new
  `context/standards/record-version-exemptions.md` is therefore already covered by the existing
  `"standards"` entry and needs **no** `provides.context` edit. Only `provides.rules` (new rule
  filename) and `provides.scripts` (new library filename) need new entries, mirroring the
  sibling's two actual entries at lines 60 and 129 of `manifest.json`.
- **The hard design problem has a workable architecture**, found by cross-checking the Verification
  repo's live content: discriminate the three durable axes from record-versioning language using
  *structural* signals (dotted semver `v4.31.0`/`v0.1.0`, `@v[0-9]+` action pins, hyphen-embedded
  CI cache-key segments `-v[0-9]+-`, and known schema-filename tokens like `book-toml-v2`,
  `book-cert-v2`), not a human-curated word list. These signals are pre-filtered (an automatic,
  marker-free exemption pass) before the record-version detector ever runs, exactly paralleling
  `strip_exempt_regions`'s role but pattern-driven instead of marker-driven.
- **Tiering confirmed empirically**: the bare-past-tense vocabulary category ("no longer",
  "previously", "formerly", "used to", "withdrawn") produced 8+ matches in the Verification
  repo's *already-accepted, non-versioning* decision-record prose during this research (e.g.
  "no longer holds" in a re-measurement verdict, "used to live in two places" describing a real
  repo reorganization). None of these are record-versioning narration. This category MUST be
  advisory-only, confirming the dispatch's instinct; it is not merely the "leading candidate," it
  is the only category this research found zero safe way to make blocking.
- **"supersedes" is not itself a forbidden token.** Live, accepted usage in the Verification repo
  uses bare "supersedes"/"this record supersedes rule 3" to mean one *current* ruling overriding
  another current ruling — a legitimate, permitted pattern distinct from "supersedes v1" (a
  version-qualified claim about a prior draft of the *same* document), which is what the dispatch
  actually forbids. The detector must require the `v[0-9]` qualifier adjacent to "supersedes" to
  fire, not match the bare word.
- **The dispatch's quoted verification numbers are now stale** (footprint of the actual file
  renamed/split since the dispatch text was authored — see Findings). The *structural* claim
  (8 files under `docs/` plus `README.md` match a bare `\bv[0-9]\b`; the sweep target file
  carries legitimate residual matches) still holds and is directly re-verifiable; only the
  specific filename and mention-count changed. The plan should re-verify counts at
  implementation time rather than trust the numbers quoted in the task description verbatim.
- **`shellcheck` is not literally zero-finding on the sibling library** (`SC2034 "appears
  unused"` fires twice, on both exported pattern variables, because shellcheck cannot see the
  external `source`-time consumers). The new library should add explicit
  `# shellcheck disable=SC2034` annotations (a precedented pattern elsewhere in this codebase,
  e.g. `scripts/skill-base.sh`) to achieve a literal clean run, which is a deliberate, small
  improvement over the sibling's unannotated form rather than a byte-for-byte copy of it.

## Context & Scope

Task 280 is the first of a three-task chain (280 -> 281 -> 282) that introduces a new rule:
deliverables outside `specs/**` must describe the current design only, never their own draft
history (no page-level version labels, no "supersedes v1" framing, no "(v1 Decision N)"
attributions, no supersession/disposition tables, and a strongly-advisory bare-past-tense
vocabulary category). This task produces exactly three files plus wiring in the **source store**
(`agent-system/extensions/core/`, never the deployed `.claude/`):

1. `rules/no-record-versioning-in-deliverables.md` — the eager, always-loaded rule, structurally
   parallel to `rules/no-task-references-in-deliverables.md`.
2. `context/standards/record-version-exemptions.md` — the lazy, full taxonomy + enforcement
   narrative, structurally parallel to `context/standards/task-reference-exemptions.md`.
3. `scripts/lib/record-version-patterns.sh` — the sole source of truth for detection patterns,
   axis discrimination, and exemption logic, structurally parallel to
   `scripts/lib/task-reference-patterns.sh`.

Tasks 281 (repo-wide lint consumer) and 282 (write-time blocking hook consumer) are explicitly
**out of scope** here; this task builds the policy and the shared mechanism only, and the
acceptance bar only requires a one-off *manual* run of the library's discriminator, not a wired
consumer script.

The research scope was: (a) fully characterize the sibling rule/taxonomy/library as the literal
model to parallel, (b) resolve exactly how the three wiring surfaces (manifest.json,
index-entries.json, merge-sources/claudemd.md) are structured so the plan's wiring edits are
precise, and (c) independently verify the dispatch's empirical claims about the Verification
repo's `docs/` tree against that repo's *live* state, since the task description's numbers were
written at an earlier point in that repo's history and that repo has since been reorganized.

## Findings

### Codebase Patterns

**Sibling rule (`rules/no-task-references-in-deliverables.md`)** — exact shape to parallel:
- Opens with an HTML comment explaining the deliberate absence of `paths:` frontmatter (eager,
  universal scope — any file anywhere could receive the forbidden language). The comment
  explicitly cross-references `source-store-deploy-boundary.md` and `pr-prohibition.md` as prior
  art for the same reasoning. The new rule's dispatch explicitly asks to carry this rationale
  forward "if the same universal-scope reasoning applies (it does)."
- Four sections in this exact order: `## Path Pattern`, `## Principle`, `## Exceptions (... )`,
  `## Full Taxonomy and Enforcement` (a closing pointer paragraph, not literally this heading
  text verbatim — the sibling's actual heading is `## Full Taxonomy and Enforcement`).
- The Exceptions list is a flat bullet list of the exempt zones with short justification per
  bullet, not prose.
- The closing pointer names both downstream files by exact path and names the as-yet-unbuilt
  consumer scripts by name (`check-task-references.sh`, `hooks/validate-no-task-references.sh`),
  exactly as task 280's rule should name `281`/`282`'s eventual consumer scripts even though they
  don't exist yet — the sibling itself was once in this same "policy before consumers" position.

**Sibling taxonomy (`context/standards/task-reference-exemptions.md`)** — exact shape to
parallel:
- Opens by restating its companion relationship to the rule file and its own on-demand loading
  status, then a "Reference Durable Anchors Instead" worked Before/After example using a
  `task-ref-ok` marker on the quoted-anti-pattern block itself (eating its own dog food).
- The core of the file is one table: `Category | Verdict | Marker required? | Example`, one row
  per exemption category (7 rows in the sibling). The new taxonomy should use the same table
  shape, but add a **Tier** column (`BLOCKING` / `ADVISORY`) since the dispatch explicitly asks
  for per-category tiering absent from the sibling (the sibling has no advisory tier at all —
  every sibling category is a clean path/marker exemption, never a severity judgment call).
- A `## Enforcement` section describing the three layers (repo-wide lint, write-time hook, agent
  contracts via `no-task-references-bullet.md`) plus a coverage-lint paragraph
  (`lint-agent-contracts.sh` Check C). Task 280 should write this section in **forward-looking**
  form since 281/282 don't exist yet — model it on the sibling's prose but note explicitly that
  the lint/hook are *planned, not yet built* (this is itself the kind of fact a research report
  should flag precisely so the plan doesn't accidentally claim a consumer exists before 281/282
  land).
- A closing `## Design Principle: Default to Repo-Wide Scope, Never a Hard-Coded Directory List`
  section recording a real defect class the sibling's own lint script once had. There is no
  directly analogous defect for record-version detection to record pre-emptively; the new
  taxonomy's closing section should instead record the axis-discrimination design principle (see
  Recommendations) since that is this task's actual hard problem, playing the same "durable
  design-principle note for future maintainers" role.

**Sibling library (`scripts/lib/task-reference-patterns.sh`)** — exact shape to parallel:
- Header comment block: one-line role statement, then "Exports the pattern variables and
  exemption logic consumed by BOTH ... Neither consumer defines ... locally -- this is the ONLY
  place they are defined," then a `context/standards/...` cross-reference, then a `# Usage:`
  block showing exactly how a consumer should call it (`source`, `grep -E` with `-i`,
  `is_exempt_path`, `strip_exempt_regions`).
- No `set` line at all — classified Class C under `context/standards/shell-strict-mode.md`
  ("sourced-only, never executed directly"); `record-version-patterns.sh` must be Class C too,
  for the identical reason (both `check-task-references.sh`-style and
  `validate-no-task-references.sh`-style consumers `source` it into a caller shell that must not
  have its error-handling behavior changed by the act of sourcing).
- Three `# ─── Section ─── ` banner comments: "Detection patterns", "Path-level exemption",
  "Content-level exemption: marker convention."
- `is_exempt_path <path>`: a `case "$path" in specs/*|*/specs/*) return 0 ;; *) return 1 ;; esac`
  — trivial, path-level, no marker needed. The new library's `is_exempt_path` should be
  byte-identical in spirit (same `specs/**` exemption; record-versioning language is permitted
  there too per the dispatch's exempt-zone 1).
- `strip_exempt_regions`: a single `awk` one-liner using a `in_block` flag toggled by the
  substring markers, falling through to `{ print }` for everything else. The new library's
  marker is `version-ok:begin`/`version-ok:end`/`version-ok` (inline) per the dispatch — same
  exact `awk` shape, three substring triggers, one state variable.
- **Important structural note for the new library that the sibling does not need**: the sibling
  only has *marker*-based content exemption (`strip_exempt_regions`). The new library additionally
  needs an *automatic, pattern-based* content exemption for the three durable axes (zone 3 — "no
  marker needed"). This is a new function with no sibling precedent; see Recommendations for its
  proposed shape and name (`strip_durable_axis_lines`, run before the marker-based exemption and
  before the blocking/advisory match, mirroring but not reusing `strip_exempt_regions`'s stdin/
  stdout filter contract literally per the dispatch's explicit instruction to model it on that
  function).

**Consumers (read for shape only — not touched by this task)**:
- `scripts/check-task-references.sh`: `git ls-files`-driven repo-wide scan, `is_exempt_path` for
  path exemption, `strip_exempt_regions` piped before matching, exit codes 0/1/2 (clean / found /
  usage-error). Gate 4 of `scripts/verify-deploy.sh`.
- `hooks/validate-no-task-references.sh`: PreToolUse `Write|Edit` hook, blocks via `exit 2` (not
  `permissionDecision: deny` — documented-buggy for bare-allow-listed tools), fails OPEN (`exit 0`
  + stderr warning) if the shared library is missing or fails to source. Both consumers will need
  an analogous "BLOCKING tier fires `exit 2`, ADVISORY tier reports but exits 0" branch once 281/
  282 exist — the tiering decision this task's library encodes is exactly what lets both
  consumers "inherit it rather than each choosing," per the dispatch.

**Wiring surfaces — verified exact shape**:
- `manifest.json`: `provides.rules` and `provides.scripts` are **flat filename arrays** (e.g.
  `"no-task-references-in-deliverables.md"` at line 60, `"lib/task-reference-patterns.sh"` at
  line 129). The new rule and library need one new string each in these two arrays, modeled
  exactly on those two existing entries (same relative-path shape, `lib/` prefix kept for the
  script).
- `provides.context` is a **directory-name array**, not a file array (confirmed by reading the
  full array: `["README.md", "routing.md", "validation.md", "index.schema.json", "architecture",
  "checkpoints", "config", "contracts", "formats", "guides", "meta", "orchestration", "patterns",
  "processes", "reference", "repo", "schemas", "standards", "templates", "troubleshooting",
  "workflows"]`). `"standards"` is already present, so **no `provides.context` edit is needed**
  for the new taxonomy file — it is already covered. This directly contradicts the dispatch's
  literal instruction to "add ... the standard to provides.context," which appears to describe a
  file-level mechanism that does not exist in the current manifest schema. The plan should treat
  this as a no-op (verify `"standards"` is present, make no edit) rather than add a spurious
  file-level entry that would not match the schema's actual shape.
- `index-entries.json`: one JSON object per discoverable context file, with keys `path` (relative
  to `context/`), `domain`, `subdomain`, `summary`, `line_count`, `keywords` (array), `topics`
  (array — `"quality"` for the sibling), `load_when` (`{agents: [], commands: [], task_types: []}`
  — empty for an always-on-demand doc), `on_demand` (`true`). The new entry for
  `record-version-exemptions.md` should copy this shape exactly, with its own summary/keywords/
  line_count once the file is written.
- `merge-sources/claudemd.md`: a single bullet appended to the "Rules References" core-rules
  list, sibling line: `` - `.claude/rules/no-task-references-in-deliverables.md` - No task-number
  citations outside specs/** ``. The new bullet should sit immediately beside it (the dispatch's
  instruction), one line, same format: `` - `.claude/rules/no-record-versioning-in-deliverables.md`
  - <short description> ``.

**Shell strict-mode / shellcheck**:
- `context/standards/shell-strict-mode.md` already names
  `scripts/lib/task-reference-patterns.sh` as the canonical Class C exemplar (sourced-only, no
  `set` line) in its own classification narrative (line 144) — the new library is the second
  instance of this exact class and should be added to that doc's Class C population list when
  the plan touches it (not required by the dispatch's deliverable list, but keeps that doc's
  "re-derive live" population claim accurate; flagged here as a Context Extension candidate, see
  below).
- Running `shellcheck` directly against the sibling library produces **exit 1**, not exit 0:
  two `SC2034 "appears unused"` warnings, one per exported pattern variable (`TASK_PATTERN`,
  `PHASE_PATTERN`), because shellcheck's static analysis cannot see that a separate script will
  later `source` this file and use the variables. This means the dispatch's acceptance bar
  ("Shared library is shellcheck clean") cannot be satisfied by literally copying the sibling's
  un-annotated form. Precedent exists elsewhere in this codebase for suppressing exactly this
  class of warning on intentionally-exported variables: `# shellcheck disable=SC2034` appears in
  `scripts/skill-base.sh`, `scripts/deprecated/vault-operation.sh`,
  `scripts/deprecated/archive-task.sh`, and two test files. The new library should add one such
  disable comment per exported pattern variable (and per exported array, if the tiering design
  below uses bash arrays) to achieve a literal `shellcheck` exit-0 result.
- `context/standards/grep-word-boundary-portability.md` documents a real, previously-verified
  defect: ugrep (the engine used only when a `grep` command is typed directly into an agent's
  own Bash-tool shell, never when a `.sh` file is executed as a subprocess) can silently fail to
  match a pattern chaining two or more independent `\b`-anchored subexpressions across a wildcard
  run, even though GNU grep (the engine every `.sh`/hook subprocess actually uses) matches the
  identical pattern correctly. `TASK_PATTERN`/`PHASE_PATTERN` are each a *single* `\b...\b`
  bracket (the explicitly-safe shape per that doc), not a chain — the sibling is unaffected. Any
  new pattern this task writes should keep the same single-`\b`-bracket shape and must be
  execute-tested (not just reasoned about) against both a real positive and real negative line
  before being committed, per that standard's "Execute-Before-Commit Obligation."

### External Resources (Verification Repo Cross-Check)

The dispatch's RATIONALE and verification-footprint claims name
`/home/benjamin/Projects/Logos/Verification` as "the Verification repo" (confirmed by content
match: `docs/architecture-decisions.md`, `docs/book-convention.md`, `specs/ROADMAP.md`,
`records/library-layout.md` etc. are real paths there). This research re-ran the dispatch's
verification claims against that repo's **current** state (2026-10-08) rather than trusting the
numbers in the task description, since task descriptions are written once and a fast-moving
sibling repo can drift before this task is picked up:

- **The target file has been renamed and relocated since the dispatch text was written.**
  `docs/book-convention.md` no longer exists; its content now lives at `books/convention.md`
  (290 lines) plus a new reader-facing `docs/book-convention-overview.md`. Likewise
  `docs/architecture-decisions.md` no longer exists; it is now `records/architecture-decisions.md`
  (a slim index) plus one file per decision under `records/architecture-decisions/NN-slug.md`.
  Git history in that repo shows this move: `acadcaf8 ... relocate all six artifacts, retire the
  baseline, rewrite the docs index`.
- **The structural claim survives the rename; the specific numbers do not.** `books/convention.md`
  today carries exactly 2 bare `v[0-9]`-shaped mentions (not 4): a decision-row link text
  `` `book.toml` v2 schema `` and a filename reference `book-cert-v2.md`, both legitimate
  file-format/schema-version citations (exempt zone 3b), zero record-versioning language.
  `grep -rlE '\bv[0-9]\b' docs/*.md README.md` on the current tree still matches exactly **8
  files** (`consuming.md`, `setup-without-nix.md`, `book-convention-overview.md`, `diagnostics.md`,
  `development.md`, `ci.md`, `stability-and-versioning-policy.md`, `README.md`) — the dispatch's
  "eight files under docs/ plus README.md" file-count claim is independently re-confirmed, even
  though the per-file mention counts have shifted because the swept file itself moved and was
  further edited. **Recommendation for the plan**: re-run this exact grep at implementation time
  immediately before writing the taxonomy's verification-footprint claims, rather than copying
  the dispatch's numbers forward — they are already one reorg behind.
- **The one "Amended by" dated cross-document amendment note (exempt zone 4) is confirmed,
  exactly one instance, but at a different path than the dispatch names.** It is now at
  `records/architecture-decisions/02-books.md` line 9: `` **Amended by
  [books/convention.md](../../books/convention.md)**, 2026-09-30: this decision fixes only the
  principle of a book; the concrete design is decided there ... `` — matching the dispatch's
  described house style exactly (dated, names the amending document, states what changed about a
  decision the *current* record owns), just not at `docs/architecture-decisions.md` as the
  dispatch's rationale paragraph names it.
- **No page-level version labels or version-qualified Status lines exist anywhere in the current
  tree** (`grep -rnE '^#.*\(v[0-9]'` and `grep -rnE '\*\*Status\*\*:.*v[0-9]'` across `docs/`,
  `records/`, `records/architecture-decisions/`, `books/convention.md`, `README.md` all return
  zero matches) — the sweep described in the dispatch's rationale is confirmed still clean today,
  supporting the acceptance criterion's expectation of a zero-BLOCKING-finding baseline.
- **Bare "supersedes" is live, accepted, non-versioning usage in this exact repo today** — direct
  evidence the detector must not treat the word itself as forbidden:
  - `records/architecture-decisions/04-lean-toolchain-and-mathlib-policy.md:35`: "This decision
    supersedes nothing in `docs/`: no existing page states a toolchain or Mathlib policy for this
    decision to replace" — one *current* ruling's relationship to other *current* rulings, no
    draft-history framing, no `v[0-9]` anywhere nearby.
  - `docs/documentation-placement.md:28` and `:160`: "This record supersedes rule 3 explicitly, in
    both records" / "This supersedes those three destinations explicitly" — same pattern, a rule
    overriding another rule's current scope, not a document narrating its own prior draft.
  - None of these would be caught by the dispatch's actual forbidden pattern #2 ("'supersedes v1'
    framing") if the detector requires a `v[0-9]` token adjacent to "supersedes" — confirming that
    requiring the version qualifier, not matching the bare word, is the correct and necessary
    design.
- **Bare past-tense vocabulary is extremely common, accepted, non-versioning prose in this exact
  repo today** — direct evidence for the dispatch's own "most false-positive-prone... leading
  advisory candidate" framing, found without even trying:
  `records/architecture-decisions/09-manual-compile-root.md` alone uses "no longer" six times in
  one file, documenting a **real, dated, fact-level correction** to a decision's own claim ("the
  central... claim held only at acceptance and no longer holds") — legitimate decision-record
  content, not record-versioning narration, and not something a blocking rule should ever flag.
  `docs/records.md:9` uses "used to live in two places" to describe a genuine repository
  reorganization fact, again legitimate. `records/architecture-decisions/02-books.md` uses
  "formerly Decision 8, retired in" twice — this one is closer to the forbidden pattern's spirit
  (an attribution to a retired numbered decision) but is about a *decision number*, not a
  *document draft version* (`vN`), so it is out of this rule's scope entirely (decision
  retirement/renumbering is that repo's own decision-record convention, a different axis from
  page-draft versioning).
- **No durable-axis false negative risk found**: every `v[0-9]` occurrence that is a genuine
  toolchain/schema/CI-cache citation in this tree is either (a) part of a dotted semver
  (`v4.31.0`, `v0.1.0`, `v4.34.0`), (b) immediately preceded by `@` (`actions/checkout`-style pins
  — none found literally in this repo's docs, but the pattern is named in the dispatch as a
  general durable-axis example), (c) embedded inside a hyphen-joined identifier
  (`elan-v2-`, `lake-recheck-v3-`, `pnpm-v1-`, `lake-bridge-v3-`), or (d) part of a known
  schema-artifact filename/slug (`book-toml-v2-schema.md`, `book-cert-v2.md`,
  `book-evidence-snapshot-v1.md`, `book-evidence-run-v1.md`, `book-evidence-observation-v1.md`).
  This is a complete, concrete catalog of every durable-axis *shape* actually observed in a live
  repo, useful as the taxonomy's worked-example set and as the discriminator's test fixtures.

## Recommendations

1. **Rule file**: write `rules/no-record-versioning-in-deliverables.md` with the sibling's exact
   four-section shape (`## Path Pattern`, `## Principle`, `## Exceptions`, closing pointer
   section) and the same no-`paths:`-frontmatter HTML comment rationale, updated to name this
   rule's own universal-scope justification (any deliverable anywhere could receive version
   language) rather than copying the sibling's task-number-specific wording verbatim.

2. **Taxonomy standard**: write `context/standards/record-version-exemptions.md` modeled on
   `task-reference-exemptions.md`'s structure, with these required deltas:
   - Add a **Tier** column (`BLOCKING`/`ADVISORY`) to the exemption/category table — the sibling
     has no precedent for this since every sibling category is a clean exemption, never a
     severity call.
   - Encode the four exempt zones from the dispatch (specs/**, git/PR metadata, the three durable
     axes, the dated cross-document amendment note) as path-level/marker-free/structural
     exemptions — none of them need the `version-ok` marker.
   - Encode the `version-ok:begin`/`version-ok:end`/`version-ok` marker convention for anything
     beyond those four, requiring a trailing reason naming a taxonomy category (mirror
     `task-ref-ok`'s requirement exactly).
   - Tier the forbidden-language categories as follows, based on this research's direct evidence:
     - **BLOCKING**: page-level version labels in titles/status lines (regex anchored on a
       markdown heading or a `**Status**:` line containing `v[0-9]`); `supersedes` co-occurring
       with a `v[0-9]` token (not bare "supersedes"); the `(v1 Decision N)`-shaped attribution
       (`\(v[0-9]+\s+Decision\s+[0-9]+\)`, a precise, low-false-positive regex).
     - **ADVISORY**: the bare past-tense vocabulary category in isolation ("no longer",
       "previously", "formerly", "used to", "withdrawn") — this research found this phrasing
       pervasive in legitimate decision-record prose with zero `v[0-9]` co-occurrence; promote a
       hit to BLOCKING only when the same line also contains a bare (non-durable-axis) `v[0-9]`
       token, giving a cheap, concrete escalation rule rather than an unqualified word list.
     - **ADVISORY, lower confidence**: the supersession/disposition-TABLE pattern (forbidden
       category #3) — a markdown table is a structural shape, not a word, and this research found
       no reliable single-line regex for "a table that disposes of an earlier draft's decisions."
       Recommend flagging it heuristically (a heading matching `relates? to v[0-9]` or a table
       whose header row contains both a decision-number column and a `v[0-9]`-shaped column
       label) and leaving it advisory rather than inventing a brittle blocking rule for something
       this research found zero real positive instances of to calibrate against.
   - Record the axis-discrimination design principle (see item 3 below) as the taxonomy's closing
     section, in place of the sibling's now-inapplicable "Design Principle: Default to Repo-Wide
     Scope" section (that principle is about enumeration scope, which this task's library does
     not touch — it inherits `is_exempt_path`'s existing `specs/**` shape verbatim).
   - State explicitly, in the Enforcement section, that the repo-wide lint and the write-time hook
     (281, 282) do not exist yet at the time this file is written, so a reader is never misled
     into believing enforcement is already live.

3. **Shared library** `scripts/lib/record-version-patterns.sh`:
   - Class C (no `set` line), header comment block modeled on the sibling's, `is_exempt_path`
     copied verbatim (same `specs/*|*/specs/*` case statement — the exemption is identical).
   - New function `strip_durable_axis_lines` (stdin -> stdout, `awk` or `grep -v`-based), run
     *before* the BLOCKING/ADVISORY match and before `strip_exempt_regions`, that drops any line
     matching one of the concrete durable-axis shapes catalogued above: dotted semver
     (`v[0-9]+\.[0-9]+(\.[0-9]+)?`), `@v[0-9]+` pins, hyphen-embedded CI cache-key segments
     (a line containing `[a-z]+-v[0-9]+-`), and known schema-filename slugs
     (`book-toml-v[0-9]+`, `book-cert-v[0-9]+`, `book-evidence-[a-z]+-v[0-9]+`, or more generally
     any `v[0-9]+` immediately adjacent to `.md` / `schema` / `toml`). This function needs no
     marker — it is zone 3's "no marker needed" exemption made mechanical.
   - `strip_exempt_regions` for the `version-ok` marker, same `awk` shape as the sibling,
     substituting the three substrings.
   - Export `BLOCKING_PATTERN`/`ADVISORY_PATTERN` (or an array, if the per-category tiering
     needs more than two patterns — likely, given three BLOCKING sub-patterns above) with
     `# shellcheck disable=SC2034` on each, to achieve a literal shellcheck-clean result (see
     Findings — the sibling itself is not literally clean under this measure).
   - Every new `\b`-bearing pattern must follow the single-bracket shape
     (`grep-word-boundary-portability.md`'s "not known to be affected" shape) and must be
     execute-tested against a real positive and real negative line from the Verification-repo
     corpus gathered in this report before being committed.

4. **Wiring**: add one string to `manifest.json`'s `provides.rules` and one to `provides.scripts`
   (mirroring the sibling's exact two entries); make **no** edit to `provides.context` (already
   covered by the existing `"standards"` directory entry — verify this assumption still holds at
   implementation time in case the manifest schema changes between now and then); add one new
   object to `index-entries.json` in the sibling's exact shape; add one bullet to
   `merge-sources/claudemd.md`'s Rules References list beside the sibling's.

5. **Acceptance verification**: re-run `grep -rlE '\bv[0-9]\b' docs/*.md README.md` (and the
   equivalent over `records/` if the plan wants broader coverage) against
   `/home/benjamin/Projects/Logos/Verification` at implementation time — do not trust this
   report's or the dispatch's numbers as a substitute for a fresh run, since that repo is actively
   changing. Use the discriminator to confirm zero BLOCKING findings on that tree; a handful of
   ADVISORY findings (the "no longer"/"used to" prose this research found) is the expected,
   correct outcome, not a bug.

6. **Context Extension (optional, non-blocking)**: `context/standards/shell-strict-mode.md`'s
   Class C population list (line ~144) names only the sibling library today; once
   `record-version-patterns.sh` exists, it belongs in that same list for the doc's "re-derive
   live" claim to stay accurate. This is a small, separate edit the dispatch's deliverable list
   does not require — flagging it here rather than making it unasked.

## Decisions

- Treat the Verification repo's current (2026-10-08) file layout, not the dispatch's quoted
  layout, as ground truth for the taxonomy's worked examples and the acceptance-criterion
  verification run — the dispatch's own framing ("at the time of writing") anticipates drift.
- Model the new `strip_durable_axis_lines` function's stdin/stdout contract on
  `strip_exempt_regions` structurally (same shape: filter stdin, print survivors) without
  literally reusing its marker-substring logic, since durable-axis exemption is pattern-based and
  marker-free by the dispatch's own zone-3 ruling ("no marker needed").
- Recommend requiring a `v[0-9]` co-occurrence to escalate the bare-past-tense category from
  ADVISORY to BLOCKING on a given line, rather than leaving that category permanently advisory
  with no escalation path — this gives the taxonomy a principled, evidence-based rule instead of
  an unqualified word list, directly answering the "hard design problem" the dispatch names.
- Recommend `# shellcheck disable=SC2034` annotations on every externally-sourced pattern
  variable in the new library, a small, precedented deviation from the sibling's unannotated form,
  because the sibling itself does not pass a literal `shellcheck` run and the dispatch's
  acceptance bar reads as requiring one.

## Risks & Mitigations

- **Risk**: the supersession/disposition-table category (forbidden pattern #3) has no reliable
  regex and this research found zero real positive instances to calibrate a heuristic against.
  **Mitigation**: ship it as a low-confidence advisory heuristic (heading/table-header match) in
  this task, and explicitly flag in the taxonomy that it is undercalibrated pending a real
  positive example — do not force a blocking rule on it now.
- **Risk**: a future durable-axis shape not in this report's catalog (e.g. a new CI tool's
  versioned cache-key convention) causes a false-positive BLOCKING finding once 281/282 go live.
  **Mitigation**: the taxonomy should state the discrimination principle generally (structural
  shape, not an enumerated whitelist of literal strings) so a new durable-axis instance can be
  added to `strip_durable_axis_lines` without reopening the taxonomy's substantive ruling.
- **Risk**: copying the sibling's `provides.context` instruction literally (per the dispatch's
  literal wording) could add a spurious, non-conforming file-level entry to `manifest.json`.
  **Mitigation**: this report documents the actual (directory-level) schema; the plan should
  verify `"standards"` is present and make no further edit, flagging the dispatch's instruction
  as already-satisfied rather than silently skipping a step.

## Context Extension Recommendations

- **Topic**: Class C shell-script population tracking.
- **Gap**: `context/standards/shell-strict-mode.md` names only one Class C library
  (`task-reference-patterns.sh`) in its "re-derive live" narrative; once this task adds a second,
  the doc's population list is one entry stale until someone updates it.
- **Recommendation**: a future (non-blocking, not part of this task's deliverable list) edit to
  add `scripts/lib/record-version-patterns.sh` to that list.

## Appendix

Search queries / commands used:
- `find . -name "task-reference-patterns.sh"`, `-name "no-task-references-in-deliverables.md"`,
  `-name "task-reference-exemptions.md"` (locate the sibling triad in the source store)
- `cat .claude-extensions.json` (confirm `agent-system/extensions/core/` is `source_dir`)
- Full reads of the sibling rule, taxonomy, and library files
- `python3 -c "json.load(...)"` against `manifest.json` to inspect `provides.rules`/`.context`/
  `.scripts` array shapes precisely (confirmed directory- vs file-level granularity)
- `grep -n` against `index-entries.json` and `merge-sources/claudemd.md` for the sibling's exact
  entry/bullet shape
- `find / -iname "*verification*"`, `find /home/benjamin -iname "*verif*"` to locate "the
  Verification repo" named in the dispatch (`/home/benjamin/Projects/Logos/Verification`)
- `git log --oneline -5 -- docs/book-convention.md` in that repo (discovered the file had been
  relocated)
- `grep -rlE '\bv[0-9]\b' docs/*.md README.md` and per-file counts, in that repo, current state
- `grep -n "Amended by" -r docs/ records/ books/`, `grep -rnE '^#.*\(v[0-9]'`,
  `grep -rnE '\*\*Status\*\*:.*v[0-9]'`, `grep -rlE 'supersedes'`,
  `grep -rnE '\b(no longer|previously|formerly|used to|withdrawn|supersedes|carried forward
  from)\b'` in that repo, current state
- `shellcheck scripts/lib/task-reference-patterns.sh` (confirmed exit 1 / SC2034 x2)
- `grep -rln "shellcheck disable=SC2034"` in the source store (precedent for suppressing it)
- Read `context/standards/shell-strict-mode.md` and
  `context/standards/grep-word-boundary-portability.md` in full
