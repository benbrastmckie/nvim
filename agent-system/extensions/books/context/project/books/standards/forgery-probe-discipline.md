# Forgery-Probe Discipline

**Every gate predicate gets a forgery probe. A gate predicate shipped without one is a REVIEWABLE
DEFECT, not a gap to be noted.**

That is the rule. The rest of this document is the grounding instance that justifies its
severity, the landed probe family to generalize from, and the pattern each probe pair
instantiates.

**Primary sources**: `books/tests/manifest/run.sh` (521 lines) and
`books/tests/manifest/fixtures/probes/` (**twenty** fixtures, measured 2026-10-03). Gap claims
defer to `domain/known-gap-register.md`.

## Why a predicate without a probe is a defect, not a gap

A gate predicate has two failure modes, and only one of them is visible:

- It **refuses something it should admit.** Loud. Someone's build breaks and they come looking.
- It **admits something it should refuse** -- or, worse, **runs against nothing and reports a
  pass.** Silent. Nobody comes looking, and the artifact carries a green claim.

A test that exercises the refusing direction catches the first. **Only a forgery probe catches the
second**, because the second requires constructing the thing the predicate is supposed to stop and
observing that it is stopped.

So the asymmetry is not about coverage percentages. A predicate with no probe is a predicate whose
**only** verified behaviour is the one that was never in doubt.

## The grounding instance

Twelve `book_policy` rows certified as `"outcome": "holds"` with `"checked_modules": []`. **A
deliberately violated probe certified clean at zero refusals.**

The predicate existed. `BookCert.Writer.checkPolicies`
(`books/lean/BookCert/Writer.lean:194-230`) resolved each policy subject against the certified
book's own member rows, exactly as designed. The composite's five members contained no module the
twelve rows named, so every row resolved to the **empty set** and was checked against **nothing**
-- and an assertion checked against nothing holds.

Three things make this the right grounding instance for the rule:

1. **Nothing in the artifact distinguished the two cases.** Not the certificate, not the run log,
   not `DEPENDS.md`. "Checked and held" and "checked nothing" were the same output.
2. **Three independent sources specified the placement the same wrong way** -- a task description,
   its plan, and **Decision 4's own worked example in `books/book-convention.md`**. There was no
   correct reading available to copy.
3. **It was caught only because a human-authored plan carried an explicit verification line** --
   "prove the assertions are live, not vacuous by construction". The dispatch's own retrospective
   calls that "the single highest-value line in the plan". **A line in a plan is not a
   mechanism**: the next plan may not carry it.

What landed afterwards is the mechanism: the `policy-vacuous` refusal, plus its probe fixture
`books/tests/manifest/fixtures/probes/PolicyVacuous.lean`, and the `checked_modules` **non-empty**
invariant that `books/schema/book-cert-v2.md` now states for every written certificate. The
`outcome` vocabulary deliberately stays at **two** words with no third word for "checked nothing",
**because** the refusal makes a vacuous row unreachable -- see
`standards/metadata-split.md` and `patterns/gate-collision-ledger.md` collision 1.

**The lesson is the ordering.** The predicate shipped first and the probe second, and the gap
between them is where the false green lived.

## The landed probe family: twenty fixtures

Measured 2026-10-03 in `books/tests/manifest/fixtures/probes/`. **Generalize from this family,
not from a four-case `FORGE-A..D` framing** -- the family on disk is substantially richer, and
`FORGE-E` alone (the direct-handle injection) is a case a four-row framing omits.

| Fixture | What it constructs | Expected |
|---|---|---|
| `AttrImported` | a post-hoc `@[book_export]` on an **imported** constant | refused at elaboration |
| `ForgeBook` | a forged `book` command in a **code** module | refused |
| `ForgeBookReverse` | the same, with the `book` command **first**, so the other guard fires | refused -- **both directions measured** |
| `ForgeBookExport` | `@[book_export]` in a **book** module (the third leg of mutual exclusion) | refused at the attribute handler |
| `ForgePlain` | the **direct-handle** forgery: a `module` file with a plain (non-`meta`) `import Books.Meta` naming the extension and calling `addEntry` | refused by handle visibility |
| `HijackRunCmd` | the `persistentEnvExtensionsRef` hijack, mounted at a **restricted** layer | refused |
| `HijackUnrestricted` | the **same** hijack at an **unrestricted** layer | **lands** -- "the honest statement of what the gate does not cover" |
| `GateFallThrough` | an execution construct at an **unrestricted** layer | **runs**, exactly as with no gate registered |
| `LayerLate` | a construct written **above** the `book_layer` line | refused by the fail-closed branch |
| `TrustScopeExport` | `@[book_export]` on a declaration overriding its own compiled content | refused at the handler |
| `TrustScopeImplBy` | the `@[implemented_by]` leg, **measured separately** because the predicates are separate | refused |
| `TrustScopeAdmit` | the **same `unsafe` export at an unrestricted layer** | **builds green** |
| `TrustScopeLint` | an **untagged** restricted-layer `unsafe def` | **warned** by the advisory linter; build succeeds |
| `SilenceLinter` | clearing the linter registry in a restricted layer | refused **by the gate, not by the linter** |
| `PolicyVacuous` | a `book_policy` whose subject is not a member | elaboration **ADMITS** -- recorded as a **BOUNDARY, not a defence** |
| `CodeModuleFact` | a `book_*` fact command in a code module | **warns and succeeds** |
| `BadAnchor` | a `book_assume` with an unresolvable anchor | fails **where the author wrote it** |
| `OwnBookRequires` | `book_requires` naming an export of a module this book module imports **directly** | refused |
| `WfLedger` | `#book_ledger` over the well-formed book (non-`module` tier) | the ledger's own output asserted |
| `FgLedger` | `#book_ledger` over the forge fixtures | two assertions against the output |

The suite that drives them carries **twenty-seven cases** (`BUILD`, `WF`, `TIERS`, `UNASSIGNED`,
`DOUBLE`, `MATRIX-C`, `MATRIX-E`, `DIVERGE`, `XBOOK`, `LEDGER`, `FORGE-A` through `FORGE-E`,
`GATE-REFUSE`, `GATE-ADMIT`, `GATE-FIRST`, `GATE-RESIDUAL`, `EXCLUDE`, `TRUST-REFUSE`,
`TRUST-ADMIT`, `TRUST-LINT`, `TRUST-SILENCE`, `WARN`, `POLICY-ADMIT`, `MANIFEST`), and its own
header states the discipline that makes the suite trustworthy:

> **No copy of the provider's rules lives here.** Every case drives the real `lake build`, the
> real `lean` elaborator and the real `books-tool` executable, so a rule that drifts in
> `books/lean/Books/Meta.lean` or `books/tool/` drifts here too.

That is the same principle `interface/tests/layer/run.sh` applies by extracting the rule block
verbatim via `sed` + `eval`. **A probe suite that reimplements the predicate is testing the copy.**

## The pattern each pair instantiates: a refusal probe AND a complementary admit probe

Read the table above in pairs rather than as a list:

| Refusal probe | Complementary admit probe | What the pair establishes |
|---|---|---|
| `HijackRunCmd` (restricted) | `HijackUnrestricted` (unrestricted) | the refusal is keyed on the **layer**, and the residual is stated rather than implied |
| `TrustScopeExport` / `TrustScopeImplBy` | `TrustScopeAdmit` | likewise -- the rule is about the layer, not the construct |
| `GATE-REFUSE` | `GATE-ADMIT`, `GateFallThrough` | an admitted construct runs **exactly as with no gate registered** |
| `ForgeBook` | `ForgeBookReverse` | both guard directions fire; neither is one-sided |
| `MATRIX-E` (elaboration) | `MATRIX-C` (certification) | the same violation is refused at both points, with the messages compared |

**Why the admit half is not optional.** A probe suite of refusals alone cannot distinguish "the
predicate refuses correctly" from "the predicate refuses everything" -- or, worse, from "the
predicate never runs and the fixture failed for an unrelated reason". The admit probe is what
makes **a probe that silently never runs itself detectable**: if the refusal probe passes and the
admit probe *also* fails, the predicate is over-firing or the harness is broken, and either way
the suite says so.

`GATE-RESIDUAL` and `PolicyVacuous` are a third category worth naming separately: **probes that
pin a documented non-defence.** `GATE-RESIDUAL` constructs the hijack the gate does **not** cover
and asserts that it lands, so that "only the certifier's attribution refuses it" is a measured
statement rather than a comment. A residual with a probe cannot quietly become a defence, or
quietly widen, without the suite noticing.

## Applying the rule

When you add or change a gate predicate -- in Lean, in a shell gate, in a lint:

1. **Name what the predicate is supposed to stop**, concretely enough to construct.
2. **Construct it** as a fixture, in the smallest package that reproduces the condition. Fixture
   packages use library roots **distinct from `Books`** (see `tools/tooling-inventory.md` for why).
3. **Add the complementary admit case** -- the same construct in the condition where it should be
   permitted. If no such condition exists, say so in the fixture, because a predicate with no
   admitting condition is a different shape of rule.
4. **Drive the real implementation**, never a copy of its logic.
5. **If the predicate has a documented residual, probe the residual too**, asserting that it
   lands.
6. **Assert on the message, not only the exit code**, where the message is what a diagnosis
   depends on -- the mutual-exclusion guards each name which of the three fired precisely so a
   diagnosis does not require reading the source.

A predicate that cannot satisfy step 1 is not yet a gate predicate. A predicate that satisfies
step 1 and ships without steps 2-4 is the reviewable defect this document names.

## What this rule does not reach

Three predicates in this system have no probe and cannot easily get one. They are recorded, not
excused:

- **The execution-construct gate's domain.** The gate is probed; the question "which modules does
  it govern?" is not answerable by any script, so the *domain* is unprobed
  (`domain/known-gap-register.md` B6).
- **The four `reserved_passes`.** Unimplemented, so there is nothing to probe. Decision 16's
  marker records "every reserved pass" as not exercised.
- **A vacuous regex-lint pass.** The lint carries a narrower silent-parser `[FAIL]` guard
  (`interface/scripts/layer-lint.sh:50-55`) but no probe for "this rule reached no file", and
  "report a vacuous pass as vacuous" is a requirement this corpus states rather than a behaviour
  the lint implements (`domain/known-gap-register.md` B4). By this document's own rule, that is a
  reviewable defect in the lint, and naming it is the point.

## Related

- `standards/metadata-split.md` -- the `book_policy` subject-placement rule this document grounds.
- `patterns/gate-collision-ledger.md` -- collision 1, with the full timeline and cost.
- `domain/layer-vocabulary-and-matrix.md` -- the five provider defences, with refuses versus
  reports per mechanism.
- `tools/tooling-inventory.md` -- the four test suites and the fixture-root rule.
