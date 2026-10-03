# The Metadata Split, as an Authoring Rule

**Facts in Lean, judgments in TOML, everything else computed.** That is Decision 6
(`docs/book-convention.md:610-798`), and it decides, for every piece of a book's metadata, which
of three places it is allowed to live in. Putting a piece in the wrong place is sometimes refused,
sometimes warned about, and -- in one case this document singles out -- **silently reported as a
pass**.

**Implementation**: `books/lean/Books/Meta.lean`, whose own docstring (`:9-20`) states the split.
Gap claims defer to `domain/known-gap-register.md`.

## The three places

| Place | Holds | Written by |
|---|---|---|
| A **code module** | facts about the code: `@[book_export]`, one `book_layer` line | the author, in Lean |
| The **book module** | judgments and declarations about the book: `book`, `book_assume`, `book_not_claimed`, `book_axioms`, `book_policy`, `book_requires` | the author, in Lean |
| **`book.toml`** | judgments no elaborator can check: name, module, version, status, licence, maintainers, trust verdicts, provenance, the docs entry | the author, in TOML |
| **`book.cert.json`** | everything else | the **certifier**, never by hand |

`book.toml`'s own rule: "a field belongs in `book.toml` exactly when a human decides it and no
elaborator can check it" (`books/schema/book-toml-v2.md`). See `domain/book-toml-v2.md` for the
fifteen fields and the computed-instead list, and
`domain/certificate-ledger-and-records.md` for what the certifier computes.

## In a code module, exactly two things

### 1. `@[book_export]` on a declaration -- and **no kind argument**

The kind is **derived**, from `getOriginalConstKind?`. There is no `@[book_export theorem]` form
to write and no way to assert a kind that the environment does not already hold. The ledger row's
`kind` field is therefore a measurement, not a claim: the `FORGE-D` fixture in
`books/tests/manifest/run.sh` pins that a `def` tagged `@[book_export]` reads as `definition`.

A post-hoc `@[book_export]` on an **imported** constant is refused at elaboration (`FORGE-A`),
and the extension handles are non-public so an importer cannot reach `addEntry` at all
(`FORGE-E`, the direct-handle case). See `standards/forgery-probe-discipline.md`.

In a **restricted** layer, `@[book_export]` additionally refuses `isUnsafe`,
`@[implemented_by]` and `@[extern]` at the handler (`Meta.lean:435`) -- see
`domain/layer-vocabulary-and-matrix.md`.

### 2. One `book_layer <layer>` line

One per module, at most one, and the layer must be one of the twelve
(`domain/layer-vocabulary-and-matrix.md`). It must come **first**: the execution-construct gate is
fail-closed on an unstated layer, so a construct above the line is refused by the same branch
that refuses a missing layer. That is what makes "`book_layer` first" one rule rather than two.

**Nothing else.** No fact command, and no `book`.

## In the book module, everything else

Six fact commands and one reader, with the syntax exactly as `Meta.lean:444-451` declares it:

```lean
syntax (name := bookCmd)           "book " ident : command
syntax (name := bookLayerCmd)      "book_layer " ident : command
syntax (name := bookAssumeCmd)     "book_assume " str str (ident)? : command
syntax (name := bookNotClaimedCmd) "book_not_claimed " str : command
syntax (name := bookAxiomsCmd)     "book_axioms " "[" ident,* "]" : command
syntax (name := bookPolicyCmd)     "book_policy " ident " never_imports " ident : command
syntax (name := bookRequiresCmd)   "book_requires " ident : command
syntax (name := bookLedgerCmd)     "#book_ledger" : command
```

What each one does, and what it resolves:

| Command | Resolves | Notes |
|---|---|---|
| `book <Name>` | nothing | one per module; must equal `book.toml`'s `name`. The module becomes a **book module** and is a member of no book (Decision 1) |
| `book_assume "<id>" "<text>" [<anchor>]` | the **optional anchor**, at elaboration | "so a typo fails where the author wrote it rather than at certification" (`Meta.lean:489-493`) |
| `book_not_claimed "<text>"` | nothing | prose only |
| `book_axioms [<ident>,*]` | **every identifier** | the permitted axiom set. An axiom **outside** it refuses the book |
| `book_policy <subject> never_imports <pattern>` | **neither operand** -- deliberately | the subject may be a layer name; the pattern is a module-name **prefix** that need not exist in this environment |
| `book_requires <ident>` | the identifier, plus **three checks** (below) | a composition hypothesis: an export of *another* book |
| `#book_ledger` | -- | reads it all back: layers from both module-system tiers, export rows with their derived kinds, both attribution columns, and the facts |

### `book_requires`: the three checks, and the authoring consequence

`elabBookRequires` (`Meta.lean:530-546`) checks that (1) the constant is **imported**, not
declared here; (2) its declaring module carries a `@[book_export]` row for it; and (3) that module
is **not** one of this module's own direct imports.

Check 3 is the one that keeps `book_requires` from colliding with Decision 1's membership rule:
a book module's direct code-module imports **are** its own book's members. The authoring
consequence, stated in the source: a book module names another book's export by importing that
book's **book module**, not its code module -- and **a book module must import its own code
modules publicly if another book will ever `book_requires` its exports**. That public import is
what makes a cross-book dependency declaration resolvable at all.

Resolution is checked **transitively against statement cones** at certification, so naming a
constant whose declaring module is in the closure is correct and sufficient. For converging on
the right set mechanically rather than by reading source, see
`patterns/warning-driven-convergence.md`.

## A `book_*` command in a code module WARNS, and the build succeeds

Every fact elaborator but `book` itself opens with `warnIfCodeModule`. Decision 6's posture is
that the certifier warns and the build succeeds -- the `WARN` fixture case in
`books/tests/manifest/run.sh` pins exactly that. **Do not author a fact command in a code module
to "save a hop"**: the row is not where any reader looks for it, and nothing fails to tell you.

`book` is the exception and is **refused**, by the mutual-exclusion guard below.

## The mutual-exclusion guard, in all three directions

`book`, `book_layer` and `@[book_export]` are mutually exclusive in one module, by three guards
that each **name which of the three fired**:

| Guard site | Refusal |
|---|---|
| `elabBook` (`Meta.lean:454-465`) | ``book: this module already names a book`` / ``book: this module states a `book_layer`, so it is a code module and may not name a book`` |
| `elabBookLayer` (`:467-479`) | ``book_layer: this module already states a layer`` / ``book_layer: this module names a book, so it is a book module and states no layer`` |
| the `@[book_export]` handler (`:425`) | the book-module leg: a book module is a member of no book, so it exports nothing |

**The shape this refuses is a denial, not an elevation** (`Meta.lean:549-560`). A forged `book`
command in a code module made that module a book module -- a member of no book -- so the module
dropped out of its own book's membership and took its **source hash and its `checkSorries`
coverage** with it, with nothing refused anywhere. That is the attack the guard closes, and it is
why the guard is three guards rather than one check at certification.

## The highest-severity rule in this document: `book_policy` subject placement

**A `book_policy` row belongs on the book that OWNS ITS SUBJECT.**

A subject that is not a member of the certifying book **resolves to nothing** and certifies as
`"outcome": "holds"` with `"checked_modules": []`. That is reported as a **pass**. Nothing in the
certificate, the run log, or `DEPENDS.md` distinguishes "checked and held" from "checked
nothing".

The measured instance: twelve `book_policy` rows were placed on a composite book whose five
members contained no module the rows named. All twelve certified green. A **deliberately
violated probe certified clean at zero refusals**. Moved to the three books that own the subjects,
the identical probe is refused twice by name and all twelve hold with non-empty
`checked_modules`.

Three independent sources specified it the same wrong way: a task description, its plan, and
**Decision 4's own worked example in `docs/book-convention.md`**. The rule is documented nowhere
in Decision 4's text; the only hint in the design record is a parenthetical in Decision 3's
*rejected alternatives* list ("per-book narrowing is what `book_policy` is for").

**The elaborator will not help you here, by design.** `elabBookPolicy` (`Meta.lean:513-521`)
resolves neither operand: the subject may be a layer name, and the pattern is a module-name
*prefix* that need not exist in this environment -- Decision 4's own example is
`book_policy laws never_imports Mathlib` inside a Mathlib-free package where `Mathlib` resolves
to nothing. The `POLICY-ADMIT` fixture (`books/tests/manifest/run.sh:447-458`) records that a
`book_policy` whose subject is not a member "elaborates green and is not even warned about" --
and records it as a **BOUNDARY, not a defence**.

The vacuous-policy refusal now lands certifier-side (`BookCert.Writer.checkPolicies`,
`books/lean/BookCert/Writer.lean:194-230`, with its own probe fixture
`books/tests/manifest/fixtures/probes/PolicyVacuous.lean`). This is the grounding instance for
`standards/forgery-probe-discipline.md`: a gate predicate shipped without a forgery probe is a
reviewable defect, and this is what one costs when it ships without one. Also recorded as B7 in
`domain/known-gap-register.md`.

**Authoring rule, operationally**: for each `book_policy` row, name the module or layer it
constrains, find which book's members include it, and put the row in **that** book's module. Then
verify the certificate's `policies[]` rows carry **non-empty** `checked_modules` -- an empty array
is the signature of a row that checked nothing.

## Related

- `domain/layer-vocabulary-and-matrix.md` -- what a layer licenses, and the gate it switches.
- `domain/book-toml-v2.md` -- the judgments half, and what is computed instead of authored.
- `patterns/authoring-workflow.md` -- the end-to-end checklist this document's rules sit inside.
- `standards/forgery-probe-discipline.md` -- the probe family, and why the subject-placement
  defect is its grounding instance.
