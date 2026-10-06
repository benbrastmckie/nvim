# Layer Vocabulary and the May-Import Matrix

A `book_layer` line states one fact about one module: which layer it sits at. The layer is what
licenses and forbids that module's imports, and -- separately -- what decides whether the module
may contain an execution construct at all.

**Normative sources**: Decision 2 (`books/book-convention/02-layer-vocabulary.md`, layer
vocabulary) and Decision 3 (`books/book-convention/03-layer-import-matrix.md`, the import matrix).
**Implementation**: `books/lean/Books/Meta.lean`, which is the only writer of the Lean-side
facts. Gap claims defer to `domain/known-gap-register.md`.

## The twelve values

`books/lean/Books/Meta.lean:113-115` (`layerNames`) is the closed list: Decision 2's **eight
layers** plus **four opt-in split tiers**.

```
interface  laws  extraction  impl  instances  refinement  challenge  evidence
impl.defs  impl.proofs  instances.defs  instances.proofs
```

`book_layer` refuses anything else: `book_layer: `{l}` is not a layer`
(`Meta.lean:469-470`). A module may state **at most one** layer --
`book_layer: this module already states a layer` -- and a **book module states none**, because it
names a book: `book_layer: this module names a book, so it is a book module and states no layer`.

**Live usage, measured 2026-10-03** over the Logos/Verification tree at git `7281c81`, excluding
`.lake/`, counting anchored `^book_layer ` lines (one per module):

| Layer | Modules | | Layer | Modules |
|---|---|---|---|---|
| `refinement` | 46 | | `evidence` | 7 |
| `impl` | 36 | | `extraction` | 3 |
| `interface` | 24 | | `impl.proofs` | 1 |
| `challenge` | 23 | | `impl.defs` | 1 |
| `laws` | 20 | | `instances.defs` | **0** |
| `instances` | 14 | | `instances.proofs` | **0** |

Total **175** layered modules tree-wide, **139** of them in the four real book-bearing packages
(`interface/`, `components/rle_codec/`, `components/distsys/`, `components/framed_channel/`).
**Ten of the twelve values are live**; `instances.defs` and `instances.proofs` are declared in
the vocabulary and **unused on the real tree**, which Decision 2's own `Validated by` marker
records as not exercised.

### Tier stripping

`baseLayer` (`Meta.lean:118-121`) strips an opt-in split tier down to its base layer:

```lean
meta def baseLayer : Name → Name
  | .str p s => if s == "defs" || s == "proofs" then p else .str p s
  | n => n
```

So `impl.defs` and `impl.proofs` both reduce to `impl`; `instances.defs` and `instances.proofs`
both reduce to `instances`. **Both the matrix and the restricted/unrestricted split are decided on
the base layer**, with one deliberate exception noted in the `challenge` row below.

## The may-import matrix

Decision 3 replaces a total order with a matrix. `mayImport row col`
(`Meta.lean:137-152`) answers: may a module at layer `row` import a module at layer `col`?
Transcribed from the implementation:

| Row | May import |
|---|---|
| `interface` | `interface` |
| `laws` | `interface`, `laws` |
| `extraction` | `extraction` |
| `impl` | `interface`, `laws`, `extraction`, `impl` |
| `instances` | `interface`, `laws`, `extraction`, `impl`, `instances` |
| `refinement` | everything **except** `challenge` and `evidence` |
| `challenge` | `interface`, `extraction`, `challenge`; `impl` **unless the imported module declares `impl.proofs`**; `refinement` **only when the imported module declares plain `refinement`** |
| `evidence` | everything **except** `challenge` |

Three properties of that table are worth stating separately, because each is a question a
diagnosis turns on.

**`challenge` and `evidence` are terminal.** No row may import `challenge` except `challenge`
itself, and none may import `evidence` except `evidence` itself. Read off the table: `challenge`
appears in only the `challenge` row's admitted set, and `evidence` only in `evidence`'s.

**The `challenge` row is the only row that reads the *unstripped* column layer.** Its `defs` cells
follow the matrix legend -- "the column layer's `.defs` tier when the book splits it, else the
whole layer" -- decided per imported module. So an import declaring `impl.defs` is admitted, one
declaring `impl.proofs` is refused, and one declaring plain `impl` is **admitted, because a module
that is not split *is* the whole layer**. `refinement` admits no split, so its cell is the whole
layer. This is what makes the legend checkable at all rather than a convention.

**The `*` cells are admitted unconditionally here.** `impl` and `instances` importing
`extraction` carry a bridge-package condition in Decision 3's legend. `mayImport` does not encode
it. That condition is one of the two universal rules below.

### Where the matrix is enforced -- twice, over two different objects

| Point | Reads | Scope |
|---|---|---|
| **Elaboration**, by `book_layer` (`Meta.lean:480-487`) | `env.header.imports` -- the module's **DIRECT** imports, with `Init` skipped because it is implicit in every module, carries no layer, and appears twice in every real header | direct imports only |
| **Certification**, by the certifier | the **computed import graph** | the whole transitive closure |

The elaboration check is cheap and local, and it is only as trustworthy as the provider the
module compiled against. The certification check is the **record of truth**
(`books/schema/book-cert-v2.md`, "The refusal set"), and a matrix violation read off the computed
graph refuses the book outright. Decision 3 assigns the transitive relation to certification
deliberately, where the whole graph is in hand.

A direct-import refusal reads: ``a `{l}` module may not import `{imp.module}` (layer `{il}`)``.

### The two universal rules that stand OUTSIDE the matrix

`Meta.lean:92-99` records both, and records that `book_layer` enforces neither:

1. **Mathlib/Aeneas confinement.** A module outside `refinement` or `extraction` may not import
   Mathlib or Aeneas-generated code. This is also the condition on the matrix's `*` cells.
2. **Terminal layers** -- enforced by the matrix cells themselves, so this one *is* reached by
   `book_layer`; it is listed as universal because Decision 3 states it as a rule about the graph
   rather than as a cell.

**Why `book_layer` cannot enforce confinement, stated as a reason and not an omission.** Two
things are true at once: whether a package is a **bridge package is not a layer fact**, and
confinement is a claim about which **packages a module's import closure reaches**, not about the
layers of its direct imports. `book_layer` has neither piece of information at elaboration time.
The rule belongs to the certifier's pass over the computed graph. `Meta.lean:92-99` calls this
"a division of labour, not an omission", and the `books/README.md` agreement report classifies
the corresponding regex rule (exclusion 4) as the one rule of nine that is **deliberately not
reproduced** by the matrix.

Measured consequence: Decision 3's marker records the confinement rule and the `*` bridge-only
cells as **not exercised -- no checker implements them** (see
`domain/known-gap-register.md`, Part A).

## The restricted/unrestricted split, and the execution-construct gate

This is a layer consequence as load-bearing as the matrix, and it is decided by the same
`book_layer` line.

| Restricted | Unrestricted |
|---|---|
| `interface`, `laws`, `refinement`, `challenge` | `extraction`, `impl`, `instances`, `evidence` |

`.defs`/`.proofs` tiers inherit through `baseLayer` (`restrictedLayer`, `Meta.lean:367-371`).

**The gate refuses ten core command kinds in a restricted layer** and falls through to core
everywhere else (`gateExecutionConstruct`, `Meta.lean:587-598`, with one
`@[command_elab]` registration per kind at `:614-641`):

```
run_cmd  run_elab  run_meta  #eval  #eval!  initialize  elab  elab_rules  macro  macro_rules
```

Every kind name is confirmed against the pinned v4.31.0 source, with the source line cited in a
comment block at `Meta.lean:599-612`, "because a wrong kind name registers an elaborator nothing
ever dispatches to, which is a silent hole". `builtin_initialize` is the **same** command kind as
`initialize`.

The refusal text names the rule rather than the symptom: ``run_cmd` is refused in a `laws`
module: the restricted layers (`interface`, `laws`, `refinement`, `challenge`) admit no execution
construct, because elaboration-time code in them can rewrite the metadata a certificate is
computed from.`

**The gate is fail-closed.** A module that states **no** layer is refused
(`Meta.lean:591-592`): ``run_cmd`: this module states no `book_layer`, and the trust-scope gate
is fail-closed.` That single branch is what makes "`book_layer` comes first" **one rule rather
than two** -- a construct written above the `book_layer` line reads an empty layer row and hits
the same refusal. The `GATE-FIRST` and `LayerLate.lean` fixtures in
`books/tests/manifest/` pin exactly this.

There is **no `set_option` off-switch and no `register_option`**, deliberately: a switch readable
from the module under inspection is not a defence. The one exemption is the provider's own module
name, for its four `meta initialize` lines, and that exemption's cost is stated in the source --
it is keyed on a module *name*, so a module managing to call itself `Books.Meta` inherits it.

**Recorded residual**: `set_option debug.*` has no command kind of its own, and its one dangerous
value (`debug.skipKernelTC`) is reachable only by kernel replay. Named in `Meta.lean:610-612`
rather than implied away.

### The trust-scope refusal at the attribute handler

`isUnsafe`, `@[implemented_by]` and `@[extern]` **refuse** at the `@[book_export]` handler in a
restricted layer (`Meta.lean:435`): ``@[book_export]` on `{decl}`, which {why}: a
restricted-layer export may not override its own compiled content. The kernel sees the
declaration; `@[extern]`, `@[implemented_by]` and `unsafe` are what runs.`

The same three ship a **second** time as a `Linter` over every declaration, and that leg is
**advisory and cannot be otherwise**: `Lean.Elab.Command.lintersRef` is a clearable public
`IO.Ref` and `runLinters` has no option gate. The gate above is what closes the silencing path
inside a restricted module -- clearing the ref needs `initialize`, `run_cmd`, `#eval` or another
gated kind -- so the residual is a module at an *unrestricted* layer clearing the ref for the rest
of its process. The `TRUST-SILENCE` fixture records that residual rather than claiming it closed.

## The five provider defences, with refuses versus reports

`Meta.lean:50-88` enumerates these so a reader can tell from the list alone which refuse and
which only report. **These are landed, not in flight** -- a claim to the contrary is in
`domain/known-gap-register.md`, B13.

| # | Mechanism | Refuses or reports |
|---|---|---|
| 1 | Non-public extension handles | **refuses** the direct-`addEntry` forgery at elaboration, by name resolution. Does **not** refuse the same write through `Lean.persistentEnvExtensionsRef`, a public `IO.Ref` from which `unsafeCast` recovers the typed handle |
| 2 | The execution-construct gate | **refuses** ten kinds in a restricted layer; fail-closed on no layer |
| 3 | Mutual exclusion of `book`, `book_layer`, `@[book_export]` | **refuses**, in all three directions, each guard naming itself |
| 4 | The writer-side provenance filter (`filterForeignRows`) | **filters** -- it does not refuse. Drops rows for constants declared elsewhere at the `exported` and `server` levels and deliberately **keeps them at `private`**, because the certifier reads at `private` and refusing there is its job |
| 5 | The trust-scope checks | **refuses** at the attribute handler in a restricted layer; the `Linter` twin only **reports** |

The residual the provider does not reach: the `persistentEnvExtensionsRef` bypass mounted at an
unrestricted layer, and the omission of genuine rows, which nothing in Lean refuses. Both are the
certifier's. **No `book_trust_scope` command exists or is planned.**

## Mutual exclusion, and the shape it refuses

`book`, `book_layer` and `@[book_export]` are mutually exclusive in one module, by three guards
-- one in `elabBook` (`Meta.lean:454-465`), one in `elabBookLayer` (`:467-479`) and one in the
attribute handler (`:425`) -- **each naming which of the three fired**, so a diagnosis does not depend on
reading the note that explains them.

The shape the rule refuses is a **denial, not an elevation** (`Meta.lean:549-560`). A forged
`book` command in a code module made that module a book module, which under Decision 1 is a
member of no book -- so the module dropped out of its own book's membership and **took its source
hash and its `checkSorries` coverage with it, with nothing refused anywhere**. The `EXCLUDE`,
`ForgeBook`, `ForgeBookReverse` and `ForgePlain` fixtures pin all three directions; see
`standards/forgery-probe-discipline.md`.

## Related

- `standards/metadata-split.md` -- what a code module may contain beside its `book_layer` line,
  and the `book_policy` subject-placement rule.
- `domain/gate-tiers.md` -- which tier runs the matrix check, which runs the regex layer lint, and
  why a green `lake build` is not evidence that a tagging phase is correct.
- `domain/known-gap-register.md` -- B4 (vacuous regex passes), B5 (the stale agreement report),
  B6 (the gate's non-enumerable domain).
