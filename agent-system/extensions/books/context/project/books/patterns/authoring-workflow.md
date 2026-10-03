# The Authoring Workflow: AUTHOR -> BUILD/TEST -> CERTIFY -> DOCUMENT

An executable checklist for bringing a book, or a family of books, into existence. Each stage's
items are checkable; where another document owns the detail, this one points rather than restates.

**The governing rule for the whole checklist**: every figure a stage produces is recorded as
**LANDED**, measured on the tree in front of you, **never inherited from a design artifact** --
and a deviation is written as a **deviation note** rather than silently absorbed. Gap claims defer
to `domain/known-gap-register.md`.

**The measured reference scale, 2026-10-03** (the figures a plan should size against):
`components/distsys/` carries **9** books, **32** layered modules, 12 book-module files and 286
`@[book_export]` occurrences; `components/framed_channel/` carries **13** real books (14
`book.toml` files including the family root), **101** layered modules and **647** exports;
`interface/` carries **4** books and **4** layered modules. Tree-wide: **27** real books, **175**
layered modules, **1,003** exports, **27** docs entries. A description of the reference
implementation as "nine layer-assigned code modules, four book modules, four manifests, four docs
entries" is describing a much earlier state.

---

## Stage 1: AUTHOR

### The code modules

- [ ] **Licence header on line 1, `module` on line 2.** This is **structural, not stylistic**: a
      `--` or `/- ... -/` comment parses **ahead of** the `module` keyword, so the header must come
      first for the file to remain a valid `module` file. Enforced by
      `components/framed_channel/scripts/check-spdx.sh` (123 lines), whose extension list is
      `rs|lean|sh|py|typ|css|js|mjs|ts` -- Markdown is not scanned.
- [ ] **Exactly one `book_layer <layer>` line per code module**, and it comes **FIRST** -- before
      any declaration and before any command. The execution-construct gate is fail-closed on an
      unstated layer, so a construct above the line hits the same refusal as a missing layer.
      Twelve values; see `domain/layer-vocabulary-and-matrix.md`.
- [ ] **`@[book_export]` on each intended export**, with **no kind argument** -- the kind is
      derived from `getOriginalConstKind?`. See `standards/metadata-split.md`.
- [ ] **Nothing else.** No `book_*` fact command in a code module: it warns and the build
      succeeds, which is worse than failing.
- [ ] **Add each new module to the lakefile's explicit `globs` list BY HAND.** Never a wildcard.
      See `tools/tooling-inventory.md` for the exact failure a wildcard produces.

### The book module

- [ ] **A PLAIN (private) import of the provider** (`import Books.Meta`). `public import Books.Meta`
      would make every downstream consumer load `Lean`.
- [ ] **PUBLIC imports of its own code modules.** This is what declares membership -- and it is
      **what makes a cross-book dependency declaration resolvable**: another book names your
      export by importing your **book module**, so your code modules must be publicly imported
      for that to resolve.
- [ ] **A module docstring. It IS the book's summary** -- there is no `[book].summary` field.
- [ ] **`book <Name>`**, equal to `book.toml`'s `name`.
- [ ] **`book_axioms [...]`** naming the permitted set. Exactly one per book.
- [ ] **Per-layer `book_policy` confinement lines, PLACED ON THE BOOK THAT OWNS EACH SUBJECT.** A
      subject that is not a member of the certifying book is a `policy-vacuous` refusal. This is
      the highest-severity placement rule in the convention; read
      `standards/metadata-split.md` before writing one.
- [ ] **`book_assume "<id>" "<text>" [<anchor>]`** with its discharging anchor where there is one.
      The anchor is resolved **at elaboration**, so a typo fails where you wrote it.
- [ ] **`book_not_claimed "<text>"`** for each thing a reader might assume and should not.
- [ ] **`book_requires <ident>`** for each cross-book hypothesis. Resolution is checked
      **transitively against statement cones**, so naming a constant whose declaring module is in
      the closure is **correct and sufficient**. Converge these off the warning stream rather than
      by reading source -- `patterns/warning-driven-convergence.md`.
- [ ] **No `book_layer` and no `@[book_export]`** in the book module; all three are mutually
      exclusive, in all three directions.

### The manifest and the docs entry

- [ ] **`book.toml` v2**: `schema = 2`, the `[book]` table, `[provenance]` only for a bridged book,
      `[docs] entry`. `status = "draft"` -- `certified` is refused on a first run
      (`stale-certified`). Omit `[trust]` unless you have a verdict; its absence means all six
      ground classes `not_applicable`, which is the honest record. See `domain/book-toml-v2.md`.
- [ ] **The `docs/` entry file exists** at the path `[docs] entry` names. Measured 2026-10-03: two
      real manifests declare an entry for a file that does not exist.

---

## Stage 2: BUILD / TEST

Every item below produces a figure. **Record each one as measured, with the command.**

- [ ] **Clean build green from an empty `.lake/`, with no network**, wall time recorded.
- [ ] **Zero-`sorry` census.** A `sorry` outside a `challenge` module refuses the book, and **a
      module with no layer row gets no benefit of the doubt**.
- [ ] **No `native_decide`, no search tactic, no vacuously-true definition.**
- [ ] **Axiom audit**: enumerate every export's axioms against the declared `book_axioms` budget,
      with **choice absent**, and **distinguish the number of SOURCES from the number of carrying
      declarations** -- they are different figures and conflating them overstates the audit.
- [ ] **Universe audit.**
- [ ] **Mathlib-freedom audit**: **no `require`, no `import`, no mention**, in any module **or
      lakefile**. All three, because any one alone passes a tree that fails the other two.
- [ ] **`#book_ledger`** reports: every code module layered; **the book module carrying no
      layer**; every intended export rowed with the **right derived kind**; and **no forged-row
      flag**.
- [ ] **`books-tool validate <manifest> --lib <dir>`** -- it decodes and checks all **seventeen**
      keys, which is **a stronger check than counting files**. A passing `grep` over the manifest
      is not evidence.
- [ ] **`books-tool check --lib <built lib dir>`** reports **zero unassigned** and **zero
      doubly-assigned** modules. `--lib` is repeatable; pass one per package.
- [ ] **A rebuild-isolation spot check**: edit a proof body and confirm **exactly that module**
      rebuilds. A figure materially above 1 means the exposure surface widened.
- [ ] **A declaration-inventory diff, signature by signature**, against the design artifact. **A
      weakened restatement that still type-checks is exactly what this catches** and nothing else
      does.
- [ ] **`check-spdx.sh`.**
- [ ] **`bash interface/scripts/layer-lint.sh <package roots>`** -- and record a **vacuous pass AS
      VACUOUS**. The lint's success line prints counts from which vacuity is inferable but never
      labels it.
- [ ] **The task-reference lint**, for anything written outside `specs/**`.

### The step the evidence makes mandatory

> **Run `interface/scripts/layer-lint.sh` at the end of ANY tagging phase.**

`lake build` **never invokes it**, and that omission is what let **44 layer violations sit
undetected across five phases that all reported green**. The lint needs no build, no network and
no toolchain, and it is the cheapest catcher for the two highest-cost rows in
`patterns/gate-collision-ledger.md`. `domain/gate-tiers.md` is why; this is the instruction.

**Caution, with no mechanical remedy**: the execution-construct gate's domain is "every module
whose import closure contains `Books.Meta`", and **no script enumerates that set**. A generated
file can therefore enter the gate's reach without appearing anywhere. Recorded as
`domain/known-gap-register.md` B6; until a lister exists, a gate refusal on a file you did not
know was in scope is the expected discovery path.

---

## Stage 3: CERTIFY

Operation is `tools/certify-guide.md`'s subject -- scoping, `--check` first, the `--no-build`
economics, and both ways the output misreports. **Read it before the first run.** The sequence,
kept here only so the checklist is complete:

- [ ] **Dependencies first, in topological order** -- the driver computes the order; do not
      certify a dependent before its dependency.
- [ ] **`reverify`** -- the only implemented pass, and the only first-implementation pass: it
      re-verifies **every recorded entry against constants**.
- [ ] **The advisory shake stage** -- reports `SKIPPED` on the pin and **never propagates its rc**.
      A `SKIPPED` line is the expected output, not a problem.
- [ ] **Computed `depends`** and the per-export ledger.
- [ ] **`interface_identity`, `identity`, `proof_identity`** -- three identities, not two.
- [ ] **The version check as a LEDGER DIFF**, not a text diff. It reads `statement_key` and
      `cone_key` to **attribute** a change. See `domain/identity-and-versioning.md`.
- [ ] **The authored judgments copied in with `source: "authored"`**
      (`books/lean/BookCert/Writer.lean`), so a reader of the certificate can tell a judgment from
      a re-verified fact.
- [ ] **The docs stage.**
- [ ] **Byte-stability check**: an unchanged tree regenerates the certificate **byte for byte**.
      `--no-write` prints to stdout and touches nothing, which is the cheapest way to confirm it.

---

## Stage 4: DOCUMENT

### Read this before authoring anything in this stage

**This stage is a design contract today, not an exercised one.** Measured 2026-10-03:

- **No real book has a Typst document.** The only two `book.typ` files in the tree are the library
  itself (`typst/lib/book.typ`) and the test probe.
- **25 of 27** real manifests declare `[docs] entry = "docs/book.md"`; **two** declare
  `entry = "book.typ"` for a file that does not exist.
- **Zero** real books carry a `book.record.json`, and its writer script
  (`books/tool/approve-guarantees.sh`) is **absent**.
- `typst/lib/book.typ` reads four top-level certificate names the writer does not emit, so **a
  real certificate cannot currently render**.

**And the extension's own rule file and the measured tree disagree.** `rules/books.md` item 3
mandates the flattened form -- `book.toml`, `book.cert.json` and `book.typ` **side by side** in
the book directory, never a `docs/` subdirectory -- and calls `docs/book.md` under a `docs/`
segment **legacy-and-held, not a model to copy**. The measured tree is almost entirely the latter.
**Both facts are true**: the rule is the extension's non-negotiable for new work, and the tree is
what exists. State both rather than choosing one silently.

### The stage, as a contract

- [ ] Author the book's document against the **certificate ALONE**, in three tiers
      (`overview | full | reference`). The contract, the label mechanics and the pins are
      `tools/typst-template-contract.md`.
- [ ] **Compile each tier standalone**, and **once embedded**, through
      `bash typst/scripts/build.sh`.
- [ ] **The tier-one prohibition lint** -- part of the docs stage, and **unbuilt**
      (`books/tool/docs-stage.sh` reports `tier_one_lint` by name under `unknown`).
- [ ] **The drift and completeness checks.**
- [ ] **The element-placement lint** and the **chapter-quality check**, with **no blocking
      finding**. Both ship in the typst extension (`typst-element-lint.sh`,
      `chapter-quality-check.sh`).

Reconciliation after a certification changed a digest is a separate, narrower contract:
`standards/reconciliation-contract.md`. Note its boundary now, because it constrains who may do
what: **agents write prose; PEOPLE write records.**

---

## Recording the result

- [ ] Every figure in the record is **LANDED** -- measured on this tree, with the command and the
      date. A figure carried over from a design artifact is a defect, not a shortcut.
- [ ] Every deviation from this checklist is a **written deviation note** naming what was skipped
      or altered and why. An absorbed deviation is indistinguishable from an oversight to the next
      reader.
- [ ] A vacuous lint pass is recorded **as vacuous**.
- [ ] A `SKIPPED` stage is recorded **as skipped**, not folded into a pass.
- [ ] The certifier's closing line is **not** the certification claim -- cross-check
      `book.cert.json` files on disk (`tools/certify-guide.md`, Misreport 1).

## Related

- `standards/metadata-split.md` -- the three places metadata may live, and the command syntax.
- `domain/layer-vocabulary-and-matrix.md` -- choosing a layer, and what it switches.
- `domain/gate-tiers.md` -- why the layer-lint step is mandatory.
- `tools/tooling-inventory.md` -- the tools each stage calls, and what each reads and writes.
- `patterns/gate-collision-ledger.md` -- read before integrating into a component with a gate.
