# The Source-Sentence Translation Contract

The cross-repository contract between a ModelChecker-style source language and the
until/since-primitive `Formula` of a BimodalLogic-style Lean development: the operator surface, the
elimination table, the four rows that are not the obvious operator, the order-structure caveat on
`next`/`prev`, the box-clause discrepancy, and the mechanical channel that connects the theorem to
running code.

Read this before touching either side of that boundary. Every fact below was established by
executing both pipelines and comparing, not by reading either one.

## Why the translation is the interesting part

The source repository states an argument in a language with a deliberately redundant operator set,
and eliminates the defined operators into the six primitives before anything else runs. Everything
downstream — encoder, solver, decoder, re-checker — consumes the *translated* formula. That puts the
elimination inside the trust base while leaving it covered by no theorem: a defect in it means every
later stage rigorously certifies a countermodel to a **different argument than the user wrote**, and
a round trip between two consumers of the translated formula cannot detect it, because both read the
same already-translated formula.

This is counter-intuitive, and worth stating plainly: the encoder is where the intricate window
arithmetic lives, and the translation is nonetheless the weaker link, precisely because it is
upstream of everything that checks anything.

## The operator surface

Nine primitive operators, eight defined, plus atoms — eighteen constructors in the Lean reference
(`FormalSystem/SourceLanguage/Sentence.lean`'s `Sentence`):

```
A, B ::= pᵢ | ⊥ | ¬A | A ∧ B | A ∨ B | □A | GA | HA | U(g, e) | S(g, e)      -- primitive
       | A → B | A ↔ B | ⊤ | ◇A | FA | PA | ○A | ●A                          -- defined
```

All seventeen operators are constructors in the reference on purpose. The source repository's own
translation sees only the nine primitives, because its expansion pass rewrites the defined ones
first — so the defined operators are exactly the part its translation never covers, and exactly the
part a reference must cover to be one.

**`U`/`S` are guard-first on both sides.** Argument 1 is the guard, argument 2 the event, in the
source repository's operator and formula modules and in `Formula.untl`/`Formula.snce`. The
elimination of these two is therefore positional identity, with no swap. An earlier event-first
convention on the source side has been normalized away; do not design around a swap.

## The elimination table

`A`, `B`, `g`, `e` abbreviate the translation of the corresponding sub-sentence.

| Source surface | Kind | `Formula` image |
|---|---|---|
| `\bot` | primitive | `Formula.bot` |
| `p` | atom | `Formula.atom a` — base name only; a fresh-indexed atom is rejected at the wire, both sides |
| `\neg A` | primitive | `(tr A).neg` |
| `\wedge A B` | primitive | `(tr A).and (tr B)` |
| `\vee A B` | primitive | `(tr A).or (tr B)` |
| `\Box A` | primitive | `(tr A).box` |
| `\Future A` (`G`) | primitive | `(tr A).allFuture` |
| `\Past A` (`H`) | primitive | `(tr A).allPast` |
| `\Until g e` | primitive | `Formula.untl (tr g) (tr e)` — positional identity, guard first |
| `\Since g e` | primitive | `Formula.snce (tr g) (tr e)` — positional identity, guard first |
| `\rightarrow A B` | defined | `((tr A).neg).or (tr B)` — **not** `Formula.imp` |
| `\leftrightarrow A B` | defined | `(((tr A).neg).or (tr B)).and (((tr B).neg).or (tr A))` |
| `\top` | defined | `Formula.bot.neg` (`= Formula.top`) |
| `\Diamond A` | defined | `(tr A).diamond` |
| `\future A` (`F`) | defined | `((tr A).neg.allFuture).neg` — **not** `Formula.someFuture` |
| `\past A` (`P`) | defined | `((tr A).neg.allPast).neg` — **not** `Formula.somePast` |
| `\next A` | defined | `Formula.next (tr A)` (`= Formula.untl Formula.bot (tr A)`) |
| `\prev A` | defined | `Formula.prev (tr A)` (`= Formula.snce Formula.bot (tr A)`) |

## The three rows a careful implementer still gets wrong

**`\rightarrow` is not `Formula.imp`.** The source repository routes it through `¬A ∨ B`, and
`Formula.or φ ψ` is `φ.neg.imp ψ`, so the image has a **doubly negated antecedent**:
`((A → ⊥) → ⊥) → B`. `Formula.imp A B` is semantically equivalent and is a *different formula*. The
consequence is not cosmetic: a different formula has a different subformula closure, and the
subformula closure is the **certificate label domain**. An implementation that writes the obvious
rule produces a reference that disagrees with the source repository on every conditional, while
every truth-preservation test it runs still passes.

**`\future`/`\past` are not `Formula.someFuture`/`Formula.somePast`.** The source repository defines
them as `¬G¬` and `¬H¬`, whose images are a top-level `imp`; the `Formula` abbreviations are a
top-level `untl`/`snce`. Different constructors, so no association or abbreviation choice could make
them equal.

The Lean reference records all three as inequalities proved, not as comments: `tr_cond_ne`,
`tr_someFut_ne`, `tr_somePast_ne`. A sibling precedent for the same phenomenon in a different
translation is `FormalSystem/MinusLanguage/Translation.lean`'s `tr_someFuture_ne`.

**Range invariant.** No `Formula.imp` in the range of the elimination is the image of a source-level
implication. `imp` occurs there only inside the encodings of `neg`, `and`, `or`, `top` and the two
universal tenses.

## The elimination is lossy, so the channel is one-directional

It is **not injective**, and the Lean reference proves that (`tr_not_injective`) rather than
assuming the opposite. Each defined operator is sent onto the abbreviation it stands for, so
`tr (A → B) = tr (¬A ∨ B)`, `tr ⊤ = tr (¬⊥)`, `tr (◇A) = tr (¬□¬A)`, and likewise for the
existential tenses. Discarding what distinguishes an abbreviation from its expansion is what an
elimination is *for*.

Two consequences. A translated formula does not determine the sentence it came from, so no inverse
pass exists to check and conformance comparison runs forward only. And an injectivity result for a
primitive-to-primitive, same-name translation (which `FormalSystem/MinusLanguage/Translation.lean` does have)
does not transfer to an elimination; expecting it to is a natural mistake to plan into a task and a
false statement to try to prove.

## `next`/`prev`: state the covering form, derive the successor form

`Formula.next φ` is `Formula.untl Formula.bot φ`. Its guard is unsatisfiable, so unconditionally it
says "`φ` holds at some `s` later than `t` with nothing strictly in between" — exactly
`∃ s, t ⋖ s ∧ …`. That is the **theorem** (`next_iff_covBy`, `prev_iff_covBy`), and it needs no
assumption on the order.

The source repository's reference evaluator reads `\next` as `t + 1`, which is `Order.succ`. That is
a **corollary** (`next_iff_succ`, `prev_iff_pred`) under `[SuccOrder]` and `[NoMaxOrder]`.

Get this backwards and the reference is silently false: on a dense carrier `next φ` is
unsatisfiable, so a module asserting the successor reading unconditionally asserts something false.
State only the covering form and the reference is true but does not visibly certify what the source
repository computes. State both, in that dependency order, and say in the module docstring that the
source repository's integer-time instantiation is what makes the corollary the operative reading
there.

A finite integer test window cannot distinguish the two readings, so no differential test on the
source side can find this. It is one of the concrete things a theorem buys over a passing property
test.

## The box clause coincides only modulo shift-closure

The Lean `TruthAt` box clause quantifies over every world history at the **same** time. The source
repository's reference evaluators quantify over every history **and every position**, which on the
Lean side is `□△φ` (`Semantics.Truth.box_always_iff`). The two coincide because the certificate
framework's history family is closed under time shift (`FormalSystem/Semantics/ShiftSet.lean`,
`FormalSystem/Semantics/TruthTransport.lean`'s `timeShift_preserves_truth`) — but they are **not the
same clause**.

Use `TruthAt`'s own clause on the Lean side and record the discrepancy in the module docstring. The
failure mode this prevents is a future reader treating the difference as a defect and "fixing" the
Lean side to match a Python evaluator that is only extensionally equivalent under a frame property.

## The mechanical channel

Documented in `BimodalTools/README.md` beside the `Formula` wire format and the certificate
protocol:

- **`Sentence.toJson` / `pSentence`** (`BimodalTools/SentenceExport.lean`) — the source-side
  extension of the existing tag vocabulary. One tag per constructor, spelled as the constructor is;
  `child` for the unary operators, `left`/`right` for the binary Boolean ones, and **named**
  `guard`/`event` for `untl`/`snce`, so the wire is order-free even though the constructor is not.
  Unknown fields are skipped.
- **`lake exe translate_sentence`** — one source-sentence JSON object on stdin, one translated
  formula JSON object on stdout; `{"error": "..."}` on failure, distinguishable because a formula
  object carries `tag` and no `error`.
- **`Tests/fixtures/sentence-translation-fixtures.jsonl`** — the shared artifact. Fields: `surface`, `kind`
  (`primitive` / `defined` / `asymmetry` / `nesting`), `sentence`, `formula`. The Lean side pins it
  in `Tests/BimodalToolsTest/SentenceCodecTest.lean`; the source repository asserts its own
  translation reproduces each line's `formula`.

**Compare parsed JSON, never bytes.** `Formula.toJson` emits `", "` and `": "` separators, which
Python's `json.dumps` defaults happen to match. Nothing guarantees it and neither side promises byte
stability; a byte comparison tests the separator convention, not the translation.

**Fixture coverage that is worth keeping.** One atomic instance of every operator; `\top`, which the
source repository's own corpus excludes because of a known defect in its defined-operator expansion
pass (the Lean side covers it unconditionally, which turns that exclusion into a visible mechanical
diff); at least one `Until`/`Since` instance whose operand swap changes the image, so an
argument-order regression cannot hide behind interchangeable operands; and a nested
`\future`/`\Future` pair plus a nested conditional, the two families that do not push through.

## Scope: what a green channel does and does not mean

It means the two implementations agree with each other **and** with a theorem about the encoding —
which is a real upgrade over agreement-with-itself, and the reason the work is worth doing even
where the source side already has differential tests with machine-checked negative controls.

It does **not** mean:

- that the source repository's code is verified. The theorem certifies the encoding. Nothing about
  that repository's memoization, its identity-keyed caches or its expansion pass is inside the
  theorem's scope; the fixture channel is the only link to running code.
- that the source repository may delete its own verification obligation for its translation.
  Delegation — relocating the translation into a callable verified pass — is structurally infeasible:
  the translation runs at evaluation time inside every primitive operator's own truth predicate, not
  only at export, and the Lean side exposes no callable verified elimination to relocate into, since
  its defined connectives are already definition-level abbreviations over six primitives. The
  deliverable is an independent verified reference to validate against, and the obligation stays
  where it is.

Say this in module docstrings rather than leaving it to be inferred. Over-claiming here — writing
that the theorem discharges the obligation, or that the row can come out of the trust-pipeline
document — is the specific failure this section exists to prevent.

## Where the Lean side lives

| Concern | File |
|---|---|
| `Sentence`, `tr`, the push-through equations, the three `≠` results, `tr_not_injective` | `FormalSystem/SourceLanguage/Sentence.lean` |
| `Sat`, `sat_iff`, the four `next`/`prev` results | `FormalSystem/SourceLanguage/SentenceTruth.lean` |
| The elimination table, the caveats, the not-formalized table | `FormalSystem/SourceLanguage/README.md` |
| The codec and the translation entry point | `BimodalTools/SentenceExport.lean` |
| The executable root | `BimodalTools/TranslateSentenceMain.lean` |
| Row-by-row `#guard`s on the table | `Tests/BimodalTest/Syntax/SentenceTranslationTest.lean` |
| The fixture-file acceptance rows | `Tests/BimodalToolsTest/SentenceCodecTest.lean` |
| The shared fixture list | `Tests/fixtures/sentence-translation-fixtures.jsonl` |

A new file in `FormalSystem/SourceLanguage/` needs a row in `LANGUAGE_FILE_LAYERS`
(`scripts/measure-refactor-partitions.py`) — 0 for a syntax file, 1 for a semantic module — or
`check-metalogic-cycles.sh` fails, and the root aggregator must be regenerated with
`lake exe mk_all --lib FormalSystem`.
