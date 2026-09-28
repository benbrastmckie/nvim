# Decidability Provenance: What May Be Cited, and What May Not

This note records the provenance of the MSO-translation decidability argument that circulates in
this project's decision-layer documentation, and fixes the vocabulary in which certificate claims
about it must be stated. It exists because the argument is routinely *recalled* rather than
*cited*, and because two distinct notions travel under one name in the source literature.

**Nothing in this note establishes decidability of anything.** It records what a held source
licenses a citation to, and what it does not.

## 1. The citation licence

The argument in question translates the object language into monadic second-order logic over an
omega-branching tree and appeals to Rabin's theorem. That appeal is now backed by a held source
rather than a recollection:

> Wolfgang Thomas, "Languages, Automata, and Logic", *Handbook of Formal Languages* Vol. 3
> (1997), ch. 6 "Automata on Infinite Trees".

Three results in that chapter carry the citation:

| Result | Location | Statement |
|--------|----------|-----------|
| Rabin Tree Theorem | §6.3, Thm. 6.20 | "The theory S2S is decidable." |
| Countable branching | §6.3, the sentence immediately after Thm. 6.20 | the decidability of S2S "extends to tree models with arbitrary finite and even countable branching (such trees are easily embedded in the binary tree)" |
| Rabin Basis Theorem | §6.2, Thm. 6.18 | for Rabin-chain tree automata emptiness is decidable, and any nonempty `T_ω(A)` "contains a regular tree (whose generating automaton `B` is obtained effectively from `A`)" |

The chapter carries a self-contained proof of the Rabin Tree Theorem in §6.1-6.2, so the citation
does not bottom out in a further recollection. Cite by theorem number and section. Never cite by
markdown line number: the stored conversion's line numbering is invalidated by re-conversion.

**Corpus id**: `thomas_1997_languages_automata`, `provenance_fidelity: verified_conversion`, source
PDF present. There is a *second* Thomas 1997 document in the corpus, id `thomas_1997`
("Ehrenfeucht-Fraïssé Games, the Composition Method, and the Monadic Theory of Ordinal Words"),
which has no source PDF and carries a `no_source_pdf` hazard. That hazard does not attach to the
chapter cited here. Match corpus ids whole; never by the author-year stem.

**Conversion caveat**: the stored markdown drops `fi`/`fl` ligatures systematically ("finite" reads
"nite", "definable" reads "denable") and renders citation keys with a trailing bracket only
("Rab69]"). This is cosmetic and uniform; the passages above were re-extracted from the PDF
independently rather than read off the markdown alone.

### What the licence does NOT cover

**The conclusion is not citable as established.** Of the argument's five steps, only the appeal to
Rabin's theorem is now sourced. The remaining steps — the translation into MSO, the frame-class
match, the transfer back, and the treatment of the stability modal — are *uncompiled*: no Lean
declaration discharges them and no held source states them for this language. Writing "validity is
decidable by Rabin's theorem" asserts the conclusion. Writing "the MSO route appeals to Thomas
1997, §6.3 Thm. 6.20, which is held; the remaining steps of that route are not discharged here"
asserts the licence. Only the second is sanctioned.

## 2. The frame-class assumption

The MSO route assumes the integer-time frame class is *exactly* the integers — duration group `D`
the integers, and histories exactly the bi-infinite walks of a digraph — rather than a wider class
of discrete orders.

For the **modal-only** language this holds and is machine-checked: the frame-class predicate at the
integer-time tag is `IsRegular ∧ IsZTime` (`Semantics/FrameClassValidity.lean`, `FrameClass.Sat`),
histories are exactly the step paths (`Semantics/IntNormalForm.lean`), and the carrier
normalization from the integer-time tag to the integer carrier is discharged sorry-free
(`validZTime_iff_validInt`, `Semantics/IntTransfer.lean`).

For the language **with the stability modal** it is not yet landed. The generic truth-transport
machinery is stated over the modal-only formula type, so the carrier normalization has no
counterpart at the larger language. Until that generalization lands, an argument that quietly
reuses the integer-carrier normalization at the larger language is assuming its own premise.

Two residues are worth naming, because they are easy to mistake for discharged: the frame
conditions the MSO argument needs on *infinite* carriers are landed as free only on **finite**
carriers (the saturation lemma's signature carries a finiteness instance), so on the infinite
carriers the argument actually builds they remain uncompiled.

## 3. Finite MODEL versus finite PRESENTATION

These are different claims, and conflating them is how a refuted hypothesis gets treated as an open
one. The source literature invites the conflation: Thomas's own text calls the finite-*presentation*
result "the finite model property".

- A **finite model certificate** — a finite structure satisfying the formula — is **refuted** for
  this language at integer time. `Probe476.fmp_false`
  (`specs/archive/476_box_faithful_small_model_theorem/evidence/fmp-hypothesis-is-false.lean`,
  compile-checked by `scripts/check-evidence-probes.sh`) exhibits a formula satisfiable in the
  integer-carrier shift-set frame and satisfiable in *no* finite presentation at any history and
  time, for **every** candidate list. This refutes the finite model property itself, not merely one
  candidate-generation scheme.

- A **finite presentation certificate** — a finite generating automaton for an *infinite* regular
  model — remains available. That is exactly what Thomas Thm. 6.18 supplies: a nonempty
  Rabin-chain tree-automaton language contains a regular tree whose generating automaton is
  obtained effectively, and, as the chapter puts it, "such regular models originate from finite
  graphs (the generating automata)". This shape is compatible with the refutation above, which
  kills finite *models* only, and it is the shape the project's existing decision-layer device
  already respects: it presents finite generators of infinite regular models rather than searching
  finite models.

**Consequence for certificate design.** The held literature names a shape to aim at; it does not
hand over a finiteness argument. Any certificate construction must supply its own. A design
premised on inheriting finiteness from the MSO route inherits nothing.

## 4. No complexity bound is inherited

In either direction, and this should be stated rather than left to be assumed:

- The MSO-to-automaton conversion is **not elementarily bounded**. Thomas, same chapter (§3):
  the time complexity of any algorithm converting MSO formulas — "even FO[S,<]-formulas" — to
  equivalent finite automata "cannot be bounded by an elementary function" (attributed there to
  Meyer and Stockmeyer).
- The held corroborating source on branching-time logics calls the complexity of the tree-route
  procedure "unclear" in so many words.
- No lower bound for *this* language is held at all.

So the MSO route yields no complexity bound, and nothing a Lean `Decidable` instance could be
constructed from. A decision procedure and a constructible certificate are different deliverables;
the route supplies at most the former, and only modulo the uncompiled steps in §1.
