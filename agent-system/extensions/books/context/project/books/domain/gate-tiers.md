# Gate Tiers: What Each One Checks, and What It Does NOT

The finding this document exists to make, stated before anything else:

> **There is today no verification tier between `lake build` and the full gate.** `lake build` is
> the fast check a developer or an agent actually runs, and it invokes neither the layer lint, nor
> the certifier, nor the Comparator rooms. The next tier up is a fail-closed full gate at roughly
> ten minutes per run. Nothing exists in between.

The measurement that forced it: **44 layer violations sat undetected across five tagging phases
that ALL reported green on `lake build`**, and surfaced only at a component family's first
`full-gate.sh` run.

**Primary source**: `specs/178_optimize_books_gate_feedback_loop/reports/01_gate-feedback-loop-seed.md`
(325 lines) and
`specs/121_bring_framed_channel_into_book_graph/summaries/02_framed-channel-book-family-summary.md`.
**Measured-once caveat**: see the closing section -- it is not optional reading.

## Correction: this is two disjoint chains, not one

A reader may have seen the pipeline written as a chain:

```
lake build -> layer-lint.sh -> certify.sh -> full-gate.sh -> full-gate.sh --recheck
```

**That is wrong in one load-bearing place, measured 2026-10-03.** `grep -n certif full-gate.sh`
returns **two lines, both comments** (`:19`, `:186`), neither invoking the certifier. What exists
is two chains that do not meet:

```
chain A (the component gate):  lake build -> [component check.sh] -> layer-lint.sh
                               full-gate.sh --> check.sh --> ... --> --recheck
chain B (the books certifier): lake build -> certify.sh
```

`layer-lint.sh` is **inside** chain A, called by each component's `check.sh`. `certify.sh` is in
neither chain's automation: **nothing mechanical catches a book whose certificate has stopped
matching its sources.** Closing that is `specs/189_wire_certifier_into_full_gate/`, NOT STARTED.

## Tier by tier

### `lake build`

| | |
|---|---|
| **Cost** | seconds to minutes; the tier a developer or agent actually runs |
| **Checks** | the modules compile. The **elaboration-time matrix check** over each module's **DIRECT** imports (`book_layer`, `books/lean/Books/Meta.lean:480-487`). The **fail-closed execution-construct gate** (ten command kinds in a restricted layer, plus any construct in a module stating no layer). The **mutual-exclusion guard** and the **trust-scope refusals** at the `@[book_export]` handler. `#book_ledger`, if a module invokes it |
| **Does NOT check** | the **computed import graph** -- so no transitive matrix violation, and no cross-package membership question. `interface/scripts/layer-lint.sh`'s nine regex rules. The certifier: no ledger, no identity, no axiom audit against `book_axioms`, no `sorry` census outside a `challenge` module, no policy assertion. The Comparator rooms. **Whether a tagging phase would be accepted by the gate** |
| **Cheapest catcher for** | a direct-import matrix violation; an execution construct in a restricted layer; a layer stated after a construct; a forged post-hoc `@[book_export]` |

The trap is precise: `lake build` **does** run a matrix check, which makes a green build feel
like layer evidence. It is evidence about **direct imports only**, under the rules of **one** of
the two rule sets that govern the tree.

### `interface/scripts/layer-lint.sh`

| | |
|---|---|
| **Cost** | sub-second to seconds. **No build, no network, no Lean toolchain** (`bash >= 4.4`, coreutils, awk) |
| **Checks** | the **nine** regex rules in `interface/scripts/layer-rules.sh` -- seven `LAYER_RULES` exclusions and two `LAYER_ALLOW_RULES` allow-only rules -- over every `.lean` **source** under each named package root, pruning `.lake/`. Plus one guard of its own: a file with `import` lines from whose header **none were parsed** is a `[FAIL]` (`layer-lint.sh:50-55`) |
| **Does NOT check** | the **computed graph** -- it reads sources, never built `.olean` headers. Anything about `book_layer`, the ledger, identities or axioms. Any file **no rule's file-half reaches** (see vacuous passes below) |
| **Cheapest catcher for** | collisions 2 and 3 of `patterns/gate-collision-ledger.md` -- the two highest-cost rows in the ledger, **both catchable by a tier that already exists and is fast** |
| **Call sites** | `components/framed_channel/check.sh:468`, `components/distsys/check.sh:195`, `components/rle_codec/check.sh:125`. Every book-bearing package is in its domain **via a gate**, and **nothing in the books tagging workflow invokes it directly** |

**Fresh measurement, 2026-10-03** (read-only; no build, no network, writes nothing):

```
bash interface/scripts/layer-lint.sh interface components/framed_channel components/rle_codec components/distsys
-> [ok] layer import rule (179 modules, 733 imports, 7 exclusion rules, 2 allow-only rules;
        queue models derived: RingBuffer VecQueue; package roots: ...)
   rc=0
```

### `books/scripts/certify.sh`

| | |
|---|---|
| **Cost** | minutes per book, more on a cold tree. `--check` alone is ~90 seconds for a thirteen-book family |
| **Checks** | the **per-export ledger**; the `reverify` pass; **computed `depends`**; the three identities; the **matrix over the computed graph** (the record of truth); policy assertions; the **axiom audit** against `book_axioms`; the `sorry` census; the version check as a **ledger diff**; then the docs stage |
| **Does NOT check** | the regex layer rules. The Comparator rooms. Import **minimality**: the `lake shake` stage is **advisory**, reports `SKIPPED`, and **never propagates its rc** -- `lake shake` refuses non-`module` packages on the pin. Anything about a book it did not discover |
| **Cheapest catcher for** | a transitive matrix violation; an undeclared axiom; a `sorry` outside `challenge`; a stale `certified` identity; a vacuous `book_policy`; a cross-package `missing-source` |
| **Not in any gate** | nothing runs it automatically -- Decision 10's marker records "any gate or CI job" as **not exercised** |

`tools/certify-guide.md` is how to run it, and what its output does and does not warrant.

### `full-gate.sh`

| | |
|---|---|
| **Cost** | roughly **ten minutes** per run on the prebuilt route; far more on the from-source fallback |
| **What it is** | a **route resolver and consent-gating launcher** around a component's `check.sh` (framed_channel's is **1,669 lines**, measured 2026-10-03; distsys's 285, rle_codec's 154). It resolves the per-system route from `nix/aeneas-pin.json`, probes costs with `nix build --dry-run`, asks `[y/N]` before every demanding step (`--yes` accepts all), verifies the Lean toolchain release asset against its pin, then runs `check.sh` in the resolved shell |
| **Checks** | whatever that component's `check.sh` checks -- including the layer lint, the `sorry` count, the SPDX header check and the extraction audit |
| **Does NOT check** | **the certifier. It contains no certifier reference at all.** Its pre-check modes (`--core-only`, `--committed-extraction`) end `INCOMPLETE` (exit 3) **by design and are never the verification claim**; only exit 0 from a real gate run is |
| **Cheapest catcher for** | a component-specific gate collision -- which, measured, is how **five of six** collisions in `patterns/gate-collision-ledger.md` were found |

### `full-gate.sh --recheck`

| | |
|---|---|
| **Cost** | the gate plus the independent legs; **prebuilt route only** |
| **Checks** | the independent recheck legs: a kernel-in-Lean replay (Lean4Lean, leanchecker) and, **on Linux only**, Comparator's sandboxed statement-and-proof comparison in fresh rooms |
| **Does NOT check** | per `docs/trust-model.md`: Comparator does not establish **that the approved statement says the right thing** (a human judgment, recorded separately), nor the sandbox's own correctness, nor independence from the kernel that built the project. Lean4Lean does not establish **which axioms were used** or anything about imports. leanchecker is a **same-kernel** replay and establishes **no independence** |
| **Cheapest catcher for** | collision 6 -- a local-path `require` breaking the clean rooms. Nothing cheaper reaches it |

## The cheapest catcher, by error class

| Error class | Cheapest tier that catches it |
|---|---|
| Direct-import matrix violation; construct in a restricted layer | `lake build` |
| A regex layer rule broken (including `Books.Meta` absent from an allow-list) | `layer-lint.sh` |
| A book module's membership import refused by an exclusion rule | `layer-lint.sh` |
| Transitive matrix violation; undeclared axiom; `sorry` outside `challenge`; vacuous policy | `certify.sh` |
| A stale `certified` identity | `certify.sh` (its own `--check`, or the version check) |
| A module the execution gate reaches that nothing lists | **an import-closure lister -- does not exist** (`domain/known-gap-register.md` B6) |
| A workaround that became wrong silently | **an expiry annotation on the workaround -- does not exist** |
| A local-path `require` unstaged in a clean room | **a lakefile-vs-room staging check -- does not exist**; today, `--recheck` |
| A certificate that stopped matching its sources | **nothing mechanical** (`domain/known-gap-register.md` B2) |

Four of nine rows name a tier that does not exist. That is the shape of the gap, not a list of
complaints.

## A tier can pass VACUOUSLY, and must be reported as vacuous

`interface/scripts/layer-lint.sh` applies each rule's **file-half** regex before its import-half.
A file **no rule's file-half reaches** is scanned and passes -- and passes because no rule applies
to it, not because it satisfied one.

**The lint does not label this.** Its success line prints
`($N modules, $M imports, 7 exclusion rules, 2 allow-only rules; ...)` -- counts from which
vacuity is **inferable**, never labelled. So:

> **Reporting a vacuous pass as vacuous is a requirement this corpus states, not a behaviour the
> lint implements.** State which it is whenever you record a lint result.

`books/README.md`'s "Axis 2 -- per module" section does name the vacuous-pass domain explicitly,
and at the time of that report measured **10 of 116** files as reached by no rule's file-half:
`components/rle_codec/lean/` (2 files -- no rule's file-half names that package, because both
allow-only rules are scoped to framed_channel's own tree by design, "so that adding a sibling
package needs no edit to the rule file -- the cost is that a sibling is governed by nothing") and
`components/framed_channel/tests/ladder/` (8 files). `components/distsys/` was outside every
rule's file-half **and** outside that invocation's package roots entirely.

The lint does carry one narrower, real guard: the silent-import-parser `[FAIL]` at
`layer-lint.sh:50-55`. That is a different thing from a vacuity label, and it is the only
automatic protection in this area. Recorded as `domain/known-gap-register.md` B4.

## The motivating measurement, in full

From `specs/121_bring_framed_channel_into_book_graph/`, via the seed report:

- Phases 5 and 6 tagged **101 modules** and the declarations behind **662 export rows**, and
  **reported green on `lake build`**.
- `lake build` never runs `interface/scripts/layer-lint.sh`, so **44 `Books.Meta` violations sat
  undetected for five phases** and surfaced only at the family's first `full-gate.sh` run. Both
  allow-only rules refused `Books.Meta` -- **the import without which `book_layer` does not exist
  at all**. The rules predated books and had no opinion about the provider.
- One implement dispatch spent **75 of its 127 minutes in a single phase** (59%; 262 tool calls),
  while the five phases doing the task's stated work took **33 minutes between them**.
- **Five of six** collisions were discoverable **only by running the ten-minute fail-closed full
  gate**: four `full-gate.sh --yes` runs plus two `--recheck` runs, **each failing on something
  different**.

The operational conclusion the seed report draws, carried here unchanged: **run
`interface/scripts/layer-lint.sh` at the end of any tagging phase.** It already exists, it is
fast, and either it or an import-closure lister "would have saved two of that dispatch's four gate
runs -- roughly 20-25 minutes, and more on a family tagged from scratch."

Also recorded by the same dispatch: when `book_layer impl` was **itself** refused by the matrix,
no layer was recorded, so the execution gate then reported "this module states no `book_layer`"
for **every subsequent `#eval`** -- roughly **100 messages diagnosing a consequence**. The real
error was line 1. Diagnosis quality amplifies the cost of a missing tier.

## The measured-once caveat

Every quantitative claim above about **cost** comes from **one implement dispatch on one component
family**. The source report says so of itself, in its own Executive Summary:

> **This report is a seed, not a diagnosis.** Every quantitative claim below is from a single
> dispatch on a single component family. The diagnostics phase must establish whether these costs
> reproduce before any optimization is designed.

**That diagnostics phase has not run** (`specs/178_optimize_books_gate_feedback_loop/`, NOT
STARTED; `specs/176_measure_framed_channel_book_family_cost/`, NOT STARTED). Read the figures as
**measured once**, not as measured. The structural claims -- which tier invokes which check, and
that `full-gate.sh` carries no certifier reference -- are re-measured 2026-10-03 and are not
subject to that caveat.

## Related

- `patterns/gate-collision-ledger.md` -- the six collisions, with symptom, root cause and fix.
- `patterns/authoring-workflow.md` -- the checklist that makes the layer-lint step mandatory.
- `tools/certify-guide.md` -- operating the certifier tier.
- `domain/known-gap-register.md` -- B1, B2, B3, B4, B6.
