# Research Report: Scaffold the books extension (manifest, two-block routing, agents, skills, commands, rule, tests)

- **Task**: 297 - Scaffold the books extension: manifest, routing, agents, skills, commands, rule and tests
- **Started**: 2026-10-03T00:00:00Z
- **Completed**: 2026-10-03T00:00:00Z
- **Effort**: large (research only; see Recommendations for plan-phase sizing)
- **Dependencies**: None
- **Sources/Inputs**:
  - Codebase: `agent-system/extensions/{cslib,lean,typst}/manifest.json` and their `agents/`,
    `skills/`, `commands/`, `rules/`, `index-entries.json`, `opencode-agents.json`, `EXTENSION.md`
  - `agent-system/extensions/core/scripts/lib/task-type-detect.sh`,
    `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh`
  - `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`
  - Live script execution: `detect_task_type` against real and simulated manifests (see Findings)
  - `~/Projects/Logos/Verification/docs/book-convention.md` (Decisions 1, 2, 3, 6, 7, 8, 17, 18)
  - `~/Projects/Logos/Verification/docs/architecture-decisions.md` (Decisions 2, 3, 8, 9)
  - `~/Projects/Logos/Verification/docs/development.md`, `books/README.md`
  - `~/Projects/Logos/Verification/books/{lean,tool,certifier,schema,scripts,tests}/` (live tree)
  - `~/Projects/Logos/Verification/specs/TODO.md` task 164 ("Add reconcile command to agent system")
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md,
  no-task-references-in-deliverables.md

## Executive Summary

- **Task-type detection**: measured and reproduced the dispatch's three test cases exactly. The
  correct, in-scope fix is narrow multi-word `keyword_overrides` (branch b); a residual gap (any
  `.lean` filename mention forces `lean4` unconditionally via the step-1 strong anchor, before
  `books` is ever consulted) is real, unfixable from inside the extension, and is recorded as
  added scope to spawn against core, not absorbed here.
- **Reconciliation decision**: the design record (Decision 17, 13 clauses) fully specifies the
  `/reconcile` workflow already scoped onto a different, NOT STARTED task ("Add reconcile command
  to agent system," targeting the typst and lean extensions). The `books` extension is the more
  coherent home for that command and its lifecycle hook. Recommendation: do not build `/reconcile`
  in this task; record the move-into-`books` recommendation as added scope to spawn, and leave the
  existing placement alone until that follow-up lands.
- **Tooling reality check (time-sensitive, material)**: the certifier's certificate writer and
  shell driver are fully landed as of today's measurement — real `book.cert.json` files exist for
  the thirteen `framed_channel` books and the `TwoPhaseCommit` book, with `passes: ["reverify"]`.
  This is **more landed** than the task dispatch's own grounding paragraph states (it describes an
  earlier snapshot). What remains genuinely unbuilt is the certifier's **docs stage** (the
  documentation-reconciliation half) and its two downstream scripts
  (`approve-guarantees.sh`, `book-health.sh`), confirmed absent by direct search.
- **Book directory layout correction**: the dispatch's own grounding paragraph says the book
  directory holds `book.toml`, `book.cert.json` and `docs/`. This is **stale**. The current,
  amended convention (`book-convention.md` Decision 1, `architecture-decisions.md` Decision 2 and
  9, and task 164's own 2026-10-02 correction) is **flattened**: `book.typ` sits directly beside
  `book.toml` and `book.cert.json`, never under a `docs/` subdirectory. The rule deliverable must
  use the flattened layout.
- **Routing, agents, commands, skills**: decided and justified below — two routing blocks only
  (per the dispatch's own scope correction, confirmed already in effect for `cslib`/`lean`/
  `typst` on disk); `routing_agents["books:certify"]` added (backed by landed tooling),
  `"books:document"` deliberately NOT added (zero landed backing); `--hard` variants ARE
  justified; both `/book` and `/certify` ARE justified as separate commands with non-overlapping
  scope.

## Context & Scope

This is a research-only dispatch (phase: research). No files under `agent-system/extensions/
books/**` are created by this report; the deliverable is the evidence and decisions a subsequent
`/plan 297` needs to produce a complete, defensible implementation plan. The task's own dispatch
file (`specs/297_.../.dispatch/1.md`) is authoritative over the stale four-block wording that
survives in `specs/TODO.md`'s entry 297 (the dispatch's trailing `SCOPE CORRECTION` amendment is
treated as current).

Everything below is restricted to the source-store wiring: `agent-system/extensions/books/`
(manifest, agents, skills, commands, rules, `EXTENSION.md`, `index-entries.json`,
`opencode-agents.json`, `README.md`, `scripts/tests/`). The domain context corpus
(`context/project/books/**`) is a separate, dependent task and is referenced only via plain
backticked pointers, never authored here.

## Findings

### 1. Precedent manifests (measured directly, not assumed)

- `agent-system/extensions/cslib/manifest.json` **already has only `routing_agents` and
  `routing_agents_hard`** — no `routing` or `routing_hard` block exists on disk today. Same for
  `lean/manifest.json` and `typst/manifest.json`. This independently confirms the dispatch's
  trailing `SCOPE CORRECTION` (author two blocks, not four): the routing-ladder-collapse work is
  further along than the original task description assumed, and two-block authoring is simply
  what matches the current tree, not a special case for `books`.
- `cslib`: `task_type: "cslib"`, `dependencies: ["core","lean","literature"]`,
  `routing_agents.plan.cslib: "planner-agent"` (not a bespoke planner),
  `keyword_overrides.cslib.keywords: ["lean","lean4","mathlib","theorem","proof","lint-fix"]`,
  `keyword_overrides.cslib.aliases: ["lean4"]` (remaps a weak-signal `lean4` resolution to
  `cslib` — a precedent for how an alias entry changes behavior; `books` needs none, see Decision
  2 below). `routing_agents_hard` covers `research.cslib` and `implement.cslib` only (no hard
  plan agent — plan always goes to `planner-agent`, hard or not).
- `lean`: `task_type: "lean4"`, `dependencies: ["core","literature"]`, `keyword_overrides: null`,
  and — the load-bearing finding for sub-routes — **`routing_agents` already declares the
  compound keys `lean4:lake` and `lean4:version`**, both mapped to the *same* agent as the base
  `lean4` key (`lean-research-agent`/`lean-implementation-agent`/`planner-agent`). A repo-wide
  grep for the literal strings `"lean4:lake"` and `"lean4:version"` outside `manifest.json` found
  **zero** occurrences: nothing in any command, skill, or script currently *sets* a task's
  `task_type` to either compound value. The only way a task acquires that `task_type` today is a
  user passing `--task-type lean4:lake` explicitly at `/task` creation (`commands/task.md` step 2
  extracts a trailing `--task-type` flag verbatim, bypassing detection). The compound sub-routes
  are therefore a **declared-but-manually-opt-in** convention, not an automatically-produced one —
  important context for deciding whether `books:certify`/`books:document` are worth declaring (see
  Decision 3).
- `typst`: `dependencies: ["core"]` (no `lean`, no `literature`), `routing_agents` only (no hard
  block — typst ships **no** `--hard` variants at all), both `research.typst` and
  `implement.typst` map to typst's own agents, `plan.typst` maps to `planner-agent`.
  `keyword_overrides.typst.keywords` are all unambiguous multi-word `typst `-prefixed phrases
  except two bare-looking ones (`"chapter quality"`, `"chapter prose"`) that are themselves
  two-word phrases, not single common words — confirms the project's own established practice of
  using phrase-length (not single-word) keywords to avoid cross-extension collisions.
- Full keyword survey across all 20 current extensions (`jq -c '.keyword_overrides'` on every
  manifest): only `cslib`, `email`, `latex`, `rust`, `typst` declare any `keyword_overrides` at
  all; none contains any `book`-prefixed or layer/matrix-related token. No collision risk for the
  `books` keyword set chosen in Decision 2.
- Agent model tiers (measured): `typst-research-agent` and `typst-implementation-agent` are both
  `model: sonnet`. `lean-research-agent`, `lean-implementation-agent`, and both lean hard variants
  are all `model: opus` (lean/formal/math agents are the Tier-1 "Deep Reasoning" exception named
  explicitly in `agent-frontmatter-standard.md`'s tier table). `cslib-research-agent` is `opus`,
  `cslib-implementation-agent` is `sonnet`. The task dispatch fixes `books` at **Sonnet for
  workers**, which is `typst`'s choice, not `lean`'s or `cslib`'s partial-opus choice — this is an
  explicit instruction, not something research re-derives, but it is worth recording that it
  diverges from the lean-adjacency intuition a reader might otherwise apply.

### 2. Task-type detection: live-measured, not theoretical

Reproduced the dispatch's three measurements exactly by sourcing
`agent-system/extensions/core/scripts/lib/task-type-detect.sh` and calling `detect_task_type`
against the real `specs/state.json` and `agent-system/extensions`:

| Description | Result |
|---|---|
| "Certify the framed_channel book and reconcile its guarantees against the ledger" | `general` |
| "Add book_layer to Interface.lean and declare book_export" | `lean4` |
| "Author the book.toml v2 manifest and the three-tier docs entry" | `general` |

Both directional facts in the dispatch are confirmed by reading the script itself:

- **Step 1 (strong anchors) resolves before any extension is consulted.** The `lean4` strong
  anchor is the regex `\.lean\b` plus the literals `mathlib`/`lean4`/`mathlib4`. Any `books`
  description naming a `.lean` file — which is extremely common for this domain, since authoring
  `book_layer`/`book_export` happens *inside* `.lean` files — hits this anchor and resolves to
  `lean4` **unconditionally**, before `books`'s own `keyword_overrides` are ever read. This is
  structural and cannot be fixed by anything `books` declares.
- **Step 2 (`keyword_overrides` scan) is alphabetical-first-match-wins and final.** `books` sorts
  before all 20 existing extension directory names (`ls -d agent-system/extensions/*/` confirms
  `books` < `core` alphabetically), so once created it is **always** scanned first among 21. An
  over-broad `books` keyword (a bare `"ledger"`, `"certify"`, or `"guarantee"`) would therefore
  capture tasks meant for `lean4`/`cslib`/`typst` before their own overrides are ever reached.

**Live test of the within-scope mitigation (branch b).** Built a scratch extensions directory
containing every real manifest plus a candidate `books` manifest declaring only unambiguous,
multi-word tokens:
`["book.toml","book_layer","book_export","book module","book.cert.json","layer matrix",
"certified unit","book_ledger","book_axioms","book_requires","book_policy","book_assume",
"book_not_claimed","books-tool"]`, then re-ran `detect_task_type` with this directory:

| Description | Result | Note |
|---|---|---|
| "Author the book.toml v2 manifest and the three-tier docs entry" | `books` | was `general`; now correctly routes |
| "Add book_layer to Interface.lean and declare book_export" | `lean4` | **unchanged** — confirms the residual gap below |
| "Certify the framed_channel book and reconcile its guarantees against the ledger" | `general` | **unchanged** — no book-specific token present; needs an explicit `--task-type books` at `/task` creation |
| "Write the book.cert.json validator for the layer matrix check" | `books` | correctly routes via two different tokens |
| "Prove the theorem using Mathlib lemmas in a new lean4 file" | `lean4` | unaffected — no collision |
| "Fix typst compilation error in the chapter template" | `typst` | unaffected — no collision |
| "Submit a pull request upstream for the cslib branch" | `pr` | unaffected — no collision |

**Decision (recorded with evidence, see Decisions §1)**: adopt branch (b) — narrow, multi-word,
unambiguous `keyword_overrides` — as the in-scope mitigation. Branch (a) (teaching core's strong
anchors to recognize `book.toml`/`book_layer`/`book.cert.json` ahead of the `.lean`-regex anchor)
is the only way to close the residual gap demonstrated by the unchanged `lean4` row above, and it
edits a file outside `extensions/books/` — **added scope to spawn, not to absorb**, per the
dispatch's own instruction.

### 3. Reconciliation ownership: Decision 17 fully specifies what task 164 already scoped

`docs/book-convention.md` Decision 17 ("Documentation reconciliation and book-health signals," 13
clauses, accepted 2026-09-30, amended 2026-10-02) is the design record task 164's own `--- SCOPE
---` block operationalizes, clause for clause:

| Task 164 scope item | Decision 17 clause |
|---|---|
| `/reconcile` reads the queue, shows stale/missing/orphaned per book, dispatches per book under the reconciliation contract, documenter pack only | Clauses 1-3, 8-9 (the eight-clause contract; the documenter pack) |
| Lifecycle postflight hook running the docs stage for every book in a finished task's file scope | Clause 1 ("the trigger is certification, never a save or a commit... the docs stage runs wherever certification runs") |
| Write guard: `book.typ` of the named book only, flattened beside `book.toml` (corrected 2026-10-02) | Clause 9.2 ("Writes are allowed to `book.typ` of the named book and nowhere else") |
| Signing stays with the person; the command prints the invocation and never runs it | Clause 9's closing paragraph: "A person closes the loop with `books/tool/approve-guarantees.sh`... Whether a declared agent may ever be the one who signs is reserved, not decided" |
| Book-health section in `/review` | Clause 10 ("`/review` gains a 'Book health' section that reads the latest [report]") |
| Fixtures: stale by digest, missing, orphaned, contract violation, red docs stage | Clause 2's four computed conditions + clause 6 (fixture set) |

This is not a case where research must guess at scope: the design record and the already-written
task description for "Add reconcile command to agent system" line up exactly. **The `books`
extension is the more coherent home** for this command and hook, because every input and output
the command touches (`book.cert.json`'s `docs` field, `book.record.json`, `book.read.json`,
`book.typ`, `books/tool/approve-guarantees.sh`, `books/tool/book-health.sh`) is book-lifecycle
state, not typst-formatting or lean-build state — `typst` and `lean` were the only extensions that
*existed* when that task was scoped, not the best-fit home.

**Decision (recorded, see Decisions §2)**: do NOT build `/reconcile`, its lifecycle hook, or the
write guard in this task. Record the recommendation that they move from (typst command/skill) +
(lean lifecycle hook) into `books` as **added scope to spawn** — a follow-up task against the
existing "Add reconcile command to agent system" task's own scope, not an absorption here. This
avoids the dispatch's explicit prohibition on silently reimplementing that work, and avoids
scope creep into a task whose own deliverable list (1-7) never mentions `/reconcile`.

### 4. Tooling reality check: the certifier has progressed since the dispatch was written

The dispatch's own grounding paragraph states: *"NOT yet landed — phases 1-12 of the certifier's
plan are complete, 13-23 outstanding: the certificate writer, `books/schema/book-cert-v2.md`, the
shell driver, and the acceptance suite."* Direct measurement of the live `~/Projects/Logos/
Verification` tree today contradicts this for three of those four items:

- **The certificate writer exists and runs.** `books/lean/BookCert/Writer.lean` is a real,
  compiled module. Real certificates exist in real book directories —
  `components/framed_channel/books/{book,varint,stuff,ladder,crc8}/book.cert.json` and
  `components/distsys/books/two_phase_commit/book.cert.json` — not only fixtures. Sampling
  `components/framed_channel/books/book.cert.json` directly: `.passes == ["reverify"]`, confirming
  the certifier's first implementation pass is genuinely running end to end.
- **`books/schema/book-cert-v2.md` exists** alongside `books/schema/book-toml-v2.md` under
  `books/schema/`.
- **The shell driver exists and is a graph-level, not book-level, operation.**
  `books/scripts/certify.sh` discovers every `book.toml` under given roots, builds the
  module-grain dependency graph, and certifies **dependencies first in topological order across
  the whole discovered graph**, refusing the run if any book is refused. It exposes `--check` (a
  pre-launch check: memory headroom, freshness via `lake build --no-build`, root/package
  resolution), `--only NAME` (repeatable, single-book selection within the graph), `--no-build`,
  `--no-shake`, `--no-write`, and `--graph-from FILE` (acceptance-suite-only, since a real
  dependency cycle among books cannot exist in Lean's own import graph).
- **What is still genuinely unbuilt**, confirmed by direct search and by
  `docs/development.md:139` ("**The docs stage does not exist yet**"): the certifier's **docs
  stage** (the documentation-reconciliation half: the `book.cert.json.docs` field, the
  documentation queue JSON) and its two downstream scripts — `books/tool/approve-guarantees.sh`
  and `books/tool/book-health.sh --json` — neither exists under `books/tool/` (confirmed by a
  targeted search; only `books/tool/record-read-test.sh`, a **third**, already-landed script for
  Decision 17 clause 10's read-test record, exists there). The four *reserved* certifier passes
  named in Decision 8 (`meta_import_ledger`, `leanchecker`, `exported_view_replay`, `trust_scope`)
  are also still unimplemented — `passes` is `["reverify"]` everywhere measured.

**Consequence for deliverable 4 (commands)**: a `/book`/`/certify` command pair can be designed
against **real, working, landed** certification capability today, not against vapor. The
dispatch's "write against the design record, not the half-landed tool" caution remains correct in
spirit — only the **documentation** half (owned by the reconciliation decision in §3, not by
`/book`/`/certify`) is still blocked.

### 5. Book directory layout: the dispatch's grounding paragraph is stale

The dispatch's own "WHAT A LEAN BOOK IS" section states the book directory holds "`book.toml`,
`book.cert.json` and `docs/`". This is **superseded**. Direct reading of the current design
record:

- `book-convention.md` Decision 1 ("Book directory layout"): *"A book's metadata and documentation
  live in `<package-dir>/books/<name>/`, holding `book.toml`, `book.cert.json` and the book's own
  document `book.typ` directly — not under a `docs/` subdirectory."*
- `architecture-decisions.md` Decision 2 (amended 2026-09-30, note dated 2026-09-30): *"a book
  directory holding the manifest, the generated certificate and the book's own document `book.typ`
  (flattened: no `docs/` subdirectory, per `docs/book-convention.md` Decision 1 as amended
  2026-10-01; the original wording was 'a directory with a hand-written `book.toml`')."*
- `architecture-decisions.md` Decision 9 names the concrete path: `<package-dir>/books/<name>/
  book.typ`, and states the Typst compile-root move to `--root .` exists *specifically* so a
  book's own `book.typ` (which sits outside `typst/`) can compile standalone.
- Task 164's own file-scope correction (2026-10-02) independently confirms the flattened path for
  the write guard: *"Writes are allowed to `book.typ` of the named book only -- flattened beside
  `book.toml`, not `docs/book.typ`"*.
- The real, landed book directories agree: `book-convention.md` Decision 1's own validated-by
  marker records the first from-scratch book (`TwoPhaseCommit`) with `"[docs] entry FLATTENED to
  book.typ beside it"`, while the seven older distsys books still carry
  `entry = "docs/book.md"` *pending their own held conversion* — i.e. the flattened layout is the
  **current and future** convention; the un-flattened one is explicitly legacy-and-held, not a
  second valid shape.

**Consequence**: the Deliverable 5 rule file, and any rule content or path glob referencing book
directory contents, must use the flattened layout
(`<package-dir>/books/<name>/{book.toml,book.cert.json,book.typ,book.record.json,book.read.json}`,
no `docs/` segment) as the default. A book whose `[docs] entry` genuinely needs a multi-file
`docs/` subdirectory remains legal (Decision 1 permits it for that case) but is not the common
case the rule should model.

### 6. Design record detail needed for the rule deliverable (Deliverable 5)

- **Facts in Lean, judgments in TOML, everything else computed** (`book-convention.md` Decision
  6): a code module carries exactly `@[book_export]` (no kind argument) and one `book_layer
  <layer>` line; the book module carries `book`, `book_assume`, `book_not_claimed`, `book_axioms`,
  `book_policy`, `book_requires`. The certifier **warns** on any `book_*` command found in a code
  module. A metadata edit in a code module rebuilds every importer; the same edit in the book
  module rebuilds only the book module — this is *why* the split exists, not an arbitrary rule.
- **The certificate is the only input of every non-Lean tool** (Decision 8): Typst, CI, doc-drift
  checks, and the diagram generator read `book.cert.json` and nothing else; no consumer reads a
  `.olean` or parses Lean source.
- **Twelve `book_layer` values and the import matrix** (Decisions 2-3): eight base layers
  (`interface | laws | extraction | impl | instances | refinement | challenge | evidence`) plus
  four opt-in split tiers (`impl.defs`, `impl.proofs`, `instances.defs`, `instances.proofs`).
  Enforced twice: at elaboration (a one-line error on a forbidden import) and at certification
  (the record of truth, recomputed from the import graph). Two universal rules sit outside the
  matrix: Mathlib/Aeneas confinement, and terminal layers (`challenge`, `evidence`).
- **The `Books.+` glob collision is real and already documented as a certifier-package design
  constraint**, not a hypothetical: `books/README.md` states it explicitly — a second package
  claiming the `Books` root (`books/lean` already owns it) fails with `bad import 'Books.Meta'`,
  which is exactly why `books/lean/BookCert/` uses its own root `BookCert` with explicit
  per-module `globs` in `lakefile.toml` rather than a wildcard. This is strong independent
  confirmation that the rule's "explicit globs, never `Books.+`" non-negotiable is correctly
  scoped and not overstated.
- **Licence header convention**: confirmed via `components/framed_channel/scripts/check-spdx.sh`
  — every hand-written `.lean`/`.sh` (and `.rs`/`.py`/`.typ`/`.css`/`.js`/`.mjs`/`.ts`) file must
  carry `Copyright (c) YYYY Benjamin Brast-McKie. PROPRIETARY AND CONFIDENTIAL. See LICENSE.`
  within its first 3 lines. The exact header **text** is this consuming repository's own
  convention, not a universal fact the `books` extension should hardcode; the rule should state
  the *structural* invariant (header-before-`module`, `module` on line 2 when the header is line
  1, since a comment parses ahead of the `module` keyword) and point to the consuming repo's own
  SPDX convention for the exact text, so the rule travels correctly to a future repo with a
  different licence header.

### 7. Command design precedent and implications for `/book` / `/certify`

- `/lake` and `/lean` (lean extension) are **direct-execution, non-lifecycle** commands: their
  logic lives inline in the command `.md` file's numbered steps; they are not routed through
  `routing_agents` at all. `/lean`'s four modes (`check|upgrade|rollback|doctor`) show the
  established pattern for a single command owning several related operational concerns via a mode
  argument, when those concerns share one lifecycle (version management).
- `cslib`'s `/vet` and `/pr` show the **paired-skill convention**: every direct-execution command
  has a same-purpose skill directory (`skill-cslib-vet`, `skill-pr-implementation`) whose own
  description states "Invoke for /<command> command," giving the command a second, agent-callable
  entry point distinct from the user-typed slash form.
- Given §4's finding that `books/scripts/certify.sh` is a **graph-wide** (multi-book,
  dependency-ordered) operation by design, while deliverable 4's `/book` is framed as a
  **single-book** workflow ("author -> build -> test -> certify over one book"), these are two
  genuinely distinct concerns, not one operation artificially split in two the way a merged
  `/book [build|certify]` mode design would suggest. This mirrors `/lake` (build concern) vs.
  `/lean` (version concern) rather than folding unrelated concerns into one mode-switched command.

## Decisions

1. **Task-type detection (branch b adopted, branch a spawned).** `books.keyword_overrides` is
   narrow and multi-word (see the list tested in Findings §2). The residual gap — a `.lean`-naming
   `books` description being captured by `lean4`'s step-1 strong anchor regardless of what `books`
   declares — is real, measured, and unfixable from inside the extension. It is recorded here as
   **added scope to spawn** against `agent-system/extensions/core/scripts/lib/task-type-detect.sh`
   (teach the `lean4` strong-anchor step, or add a `books` strong anchor ahead of it, to recognize
   `book.toml`/`book_layer`/`book.cert.json`), not touched by this task. Until that follow-up
   lands, a `books` task whose description happens to name a `.lean` file must be given an
   explicit `--task-type books` at `/task` creation to route correctly — this residual is
   documented, not silently absorbed.

2. **Reconciliation ownership: do not build `/reconcile` here; recommend moving it into `books`.**
   The existing "Add reconcile command to agent system" task's scope (a `/reconcile` command and
   skill, a lean-extension lifecycle postflight hook, a write guard, a `/review` Book-health
   section, and five fixtures) is left exactly where it is placed today (typst + lean extensions),
   with a recorded recommendation that it move into `books` once that task is next revised or
   re-scoped — **added scope to spawn**, never silently reimplemented or duplicated here.
   Deliverable 4's command set (`/book`, `/certify`) is scoped to exclude any reconciliation
   behavior.

3. **Routing sub-routes: `books` and `books:certify` only — NOT `books:document`.** `books:certify`
   is backed by real, landed tooling today (`books-tool validate`, `books-tool check`,
   `books/scripts/certify.sh`, confirmed in Findings §4) and is added to `routing_agents`/
   `routing_agents_hard`, mapped to the same base agents as `books` (mirroring `lean4:lake`'s
   identical-agent mapping — no dedicated certify research/implementation agent is justified
   today). `books:document` is deliberately NOT added: the docs stage it would represent has zero
   landed backing (not even the intermediate validate/check primitives `certify` already has), so
   declaring a routing sub-route for it would be scaffolding with nothing behind it. Revisit once
   the docs stage lands (see Decision 2) or the reconciliation move is enacted.

4. **Agents: author `--hard` variants.** `books-research-agent` and `books-implementation-agent`
   (both `model: sonnet`, per the dispatch's explicit instruction) ship alongside
   `books-research-hard-agent` and `books-implementation-hard-agent` (also `model: sonnet` — the
   hard variant never changes model tier from its base in any existing precedent: lean keeps opus
   across base and hard, cslib keeps opus/sonnet across base and hard respectively). Justification
   for choosing `--hard` at all (over typst's no-hard-variant precedent): `books` tasks are
   frequently exactly the H3 reference-grounding use case named in `CLAUDE.md`'s own "When to Use
   `--hard`" list (literature/spec-to-implementation faithfulness against a 2450-line, 18-decision
   design record), carry the same elaboration-time-cryptic-error profile as `lean4`/`cslib`
   (a one-line layer-matrix violation, the `Books.+` glob collision), and the metadata-split rule's
   rebuild-cost asymmetry (Decision 6) makes a wrong placement choice expensive to unwind — a
   genuinely deflection-prone, correctness-critical profile much closer to `lean4`/`cslib` than to
   `typst`'s comparatively low-stakes formatting/compilation work. H-technique selection follows
   `cslib`'s set (H2/H3/H4 research; H2/H7/H9 implementation) rather than `lean4`'s (H2/H3/H4/H5
   research; H2/H9 implementation), because `books` is a composite domain spanning Lean (facts) +
   TOML (judgments) + Typst (docs) like `cslib` (Lean + contribution standards + CI), not a
   pure-Lean domain like the `lean4` extension itself.

5. **Commands: author both `/book` and `/certify`, not one merged command.** `/book <name>`
   drives the single-book developer loop (resolve the named book's `book.toml` → `lake build` its
   module scope → `books-tool validate` → `books-tool check --lib <built-lib-dir>`), explicitly
   reporting (never silently skipping) that full documentation reconciliation is out of its scope
   (owned by Decision 2 above). `/certify [NAME...|--root PATH] [--check|--only NAME|--no-build|
   --no-shake|--no-write]` is a thin, flag-passthrough wrapper around the real
   `books/scripts/certify.sh`, justified as distinct from `/book` because certification is a
   graph-wide, dependency-ordered operation over potentially many books (Findings §4, §7), not a
   single-book concern — the same shape of justification that keeps `/lake` and `/lean` as two
   commands rather than one. Each command pairs with a same-purpose direct-execution skill
   (`skill-books-build`, `skill-books-certify`), following the `cslib` `/vet`+`skill-cslib-vet`
   precedent.

6. **Rule content: use the flattened book-directory layout.** The `books`-scoped rule
   (`paths: ["**/books/**", "**/Book.lean", "**/Book/*.lean"]`) documents the current, amended
   layout (`book.toml`, `book.cert.json`, `book.typ` flattened, no `docs/` segment) per Findings
   §5, carries the facts-in-Lean/judgments-in-TOML split (§6), the certificate-as-sole-input rule,
   explicit per-module `globs` / never `Books.+` (with the `bad import 'Books.Meta'` failure mode
   cited as measured fact, not hypothetical), the licence-header-then-`module` *structural*
   invariant (pointing to the consuming repo's own SPDX text rather than hardcoding
   Benjamin Brast-McKie's), never hand-editing a generated certificate or Typst fragment, and never
   authoring a computed field (the `book.toml` v2 "what's NOT authored, and where it lives
   instead" table from Decision 7 is the ready-made source for this last point).

## Recommendations

1. **Plan-phase manifest skeleton** (priority: must-have): `task_type: "books"`,
   `dependencies: ["core","lean","typst"]`, `provides.context: ["project/books"]`,
   `merge_targets` for `claudemd` (`EXTENSION.md`, `section_id: "extension_books"`), `index`
   (`index-entries.json`), and `opencode_json` (`opencode-agents.json`) — following the `typst`
   manifest's exact three-`merge_targets` shape (no `settings` target needed; `books` has no
   environment-variable concerns analogous to lean's Comparator overrides).
2. **Agents** (priority: must-have): four agent files (`books-research-agent.md`,
   `books-implementation-agent.md`, `books-research-hard-agent.md`,
   `books-implementation-hard-agent.md`), all `model: sonnet`, following `typst-research-agent.md`
   / `typst-implementation-agent.md`'s structure for the base pair and `cslib-research-hard-agent.md`
   / `cslib-implementation-hard-agent.md`'s structure (H-technique prose, not model tier) for the
   hard pair.
3. **Skills** (priority: must-have): `skill-books-research`, `skill-books-implementation`,
   `skill-books-research-hard`, `skill-books-implementation-hard` (lifecycle pair + hard variants,
   mirroring `skill-cslib-research`/`skill-cslib-implementation` + hard), plus the two
   direct-execution skills `skill-books-build` and `skill-books-certify` backing the two commands.
   No lifecycle skill is needed for the `books:certify` sub-route itself (it reuses the base pair,
   per Decision 3).
4. **Commands** (priority: must-have): `book.md` and `certify.md`, modeled on `lake.md`'s
   step-numbered inline-bash structure; `certify.md`'s options table should pass through
   `certify.sh`'s real flags verbatim (`--check`, `--only NAME`, `--no-build`, `--no-shake`,
   `--no-write`) and explicitly omit `--graph-from` (acceptance-suite-only per its own script
   header).
5. **Rule** (priority: must-have): one file, `books.md`, `paths: ["**/books/**", "**/Book.lean",
   "**/Book/*.lean"]`, content per Decision 6 above.
6. **Scripts/tests** (priority: decide at plan time, lean toward minimal): recommend starting
   with **zero** extension-local scripts (both commands' logic inline, mirroring `/lake`/`/lean`'s
   own precedent) and therefore no `scripts/tests/` fixtures at first landing; add a shared
   book-resolution helper script (and its fixture) only if `/book` and `/certify`'s inline
   book-name-to-`book.toml`-path resolution logic is measured to duplicate enough to justify
   extraction. This is a judgment call deliberately left open for the plan phase rather than
   fixed here, since no such duplication exists yet (nothing has been written).
7. **`EXTENSION.md`/`index-entries.json`/`opencode-agents.json`/`README.md`** (priority:
   must-have): follow the `typst` extension's exact templates (reproduced in full in this
   report's source reads) — `EXTENSION.md`'s `### Scope` section should state explicitly that
   authoring/proving the underlying Lean content is out of scope for `books` (routes to `lean4`/
   `cslib`/`formal`), exactly as `typst`'s own `### Scope` note excludes "originating or
   mathematically verifying new content."
8. **Follow-ups to spawn, not absorb** (both named explicitly so they are not lost):
   (a) amend `task-type-detect.sh`'s strong-anchor step (or add a `books` strong anchor ahead of
   `lean4`'s) to close the `.lean`-filename-capture gap in Finding §2;
   (b) move the "Add reconcile command to agent system" task's deliverables into `books` once that
   task is next revised, per Decision 2.

## Risks & Mitigations

- **Risk**: the Verification repo's `books/` tooling is actively changing (confirmed: the
  certifier writer/shell driver landed between the dispatch being written and this research being
  done, same day). **Mitigation**: the plan phase should re-verify Findings §4's landed/unlanded
  boundary against the live tree immediately before implementing, rather than trusting this
  report's snapshot indefinitely.
- **Risk**: a `books` task created without an explicit `--task-type` and naming a `.lean` file
  will silently route to `lean4` instead of `books` (Finding §2's residual gap), producing a
  plausible but wrong research/implementation agent dispatch with no error. **Mitigation**:
  document this explicitly in `EXTENSION.md`'s own text (not only in this report) so a task author
  knows to pass `--task-type books` when a `.lean` filename is unavoidable in the description, and
  spawn the core-anchor follow-up per Recommendation 8(a).
- **Risk**: declaring `routing_agents["books:certify"]` with no distinct agent behind it could be
  mistaken for a no-op and pruned later by someone unaware of the `lean4:lake`/`lean4:version`
  precedent. **Mitigation**: the manifest's own code is unambiguous (identical agent name on both
  keys, exactly like `lean`'s), and this report records the rationale so a future reader does not
  need to rediscover it.

## Context Extension Recommendations

- **Topic**: lean-book-standard domain knowledge for agent context.
- **Gap**: `context/project/books/` does not exist yet (explicitly a separate, dependent task per
  this task's own description). Once it lands, `index-entries.json` entries in this task's
  manifest should point into it following the `typst` `index-entries.json` template reproduced in
  Findings §1/§7 — `load_when.task_types: ["books"]`, `load_when.agents` scoped per-file to
  whichever of the four `books` agents actually consumes it.
- **Recommendation**: when `context/project/books/` is planned, structure it in parallel with
  `context/project/typst/{patterns,standards,templates,tools}/` and `context/project/lean4/
  {domain,patterns,tools}/` rather than inventing a third directory shape, since `books` is a
  composite of both domains.

## Appendix

- Live script invocations and their outputs are reproduced verbatim in Findings §2 (task-type
  detection) and §4 (`passes: ["reverify"]` certificate sample); not restated here.
- Full `cslib`/`lean`/`typst` `manifest.json` contents, `lake.md`/`lean.md` command bodies,
  `skill-cslib-vet`/`skill-pr-implementation` frontmatter, `typst`'s `index-entries.json` and
  `opencode-agents.json`, and `agent-frontmatter-standard.md`'s tier table were read in full during
  this research and are the direct source for every template reference in Findings/Recommendations
  above; paths are given inline at first mention rather than repeated here.
- Design-record citations (`book-convention.md` Decisions 1, 2, 3, 6, 7, 8, 17, 18;
  `architecture-decisions.md` Decisions 2, 3, 8, 9) were read in full, not excerpted from a
  secondary summary; every quoted fragment above is copied verbatim from the source file.
