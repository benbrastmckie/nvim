# The Gate Collision Ledger

Six independent collisions between the books convention and a component's **pre-existing,
independently-designed gate**. This document exists so the next books integration **reads the
ledger instead of rediscovering it** at ten minutes per gate run.

**Primary sources**:
`specs/178_optimize_books_gate_feedback_loop/reports/01_gate-feedback-loop-seed.md` (325 lines)
and `specs/121_bring_framed_channel_into_book_graph/summaries/02_framed-channel-book-family-summary.md`.
**Read the measured-once caveat at the end before quoting any figure here.**

## The measured cost

One implement dispatch, bringing ten unit books, two support books and a composite into the book
graph at once -- **662 export rows over 78 member modules across two Lake packages**:

| Window | Duration | Content |
|---|---|---|
| 17:02 -> 17:35 | **33 min** | Phases 8, 9, 10, 11, 13 -- five phases doing the task's stated work, three commits |
| 17:35 -> 18:50 | **75 min** | Phase 12 alone: "regenerate the certificate and recheck, and run the full gate" |
| 18:50 -> 19:09 | 19 min | Close-out |

Total **127 minutes**, **262 tool calls**, 461,334 subagent tokens. **Phase 12 is 59% of the
dispatch** -- and that 75 minutes was **not spent on the work being gated**. It was spent
discovering the six collisions below.

Figures are from phase-commit timestamps, which the seed report names as authoritative: the
agent's self-reported `started_at` fields were inconsistent with file mtimes and "should not be
used". The 19-minute close-out was inflated by a user-requested retrospective and **is not a
baseline**.

**Five of the six collisions were discoverable only by running the full gate** -- four
`full-gate.sh --yes` runs plus two `--recheck` runs, **each failing on something different**.
**Not one of the six was predicted by any phase.**

## The six rows

### Collision 1 -- twelve `book_policy` rows certified `"holds"` with `checked_modules: []`

| | |
|---|---|
| **Symptom** | A deliberately violated probe certified **clean at zero refusals**. Twelve policy rows reported as passes |
| **Root cause** | The policy subject was not a member of the certifying book. The composite's five members contained no `Composition.*` module, so all twelve rows resolved to nothing. `BookCert.Writer.checkPolicies` resolves a subject against the certified book's **own member rows** |
| **Fix** | Move the rows to `Book.{Channel,StuffedChannel,Receiver}` -- the books that own the subjects. The identical probe is then refused twice by name and all twelve hold with non-empty `checked_modules` |
| **Cheapest catcher** | `checkPolicies` itself (Lean) -- **now landed** as the `policy-vacuous` refusal (`specs/179_refuse_vacuous_book_policy/`, completed) |
| **Severity** | A **trust defect, not a cost problem.** Nothing in the certificate, the log or `DEPENDS.md` distinguished "checked and held" from "checked nothing" |

**Three independent sources specified it the same wrong way**: the task description, the plan, and
**Decision 4's own worked example in `books/book-convention.md`**. It was caught **only** because
the plan carried an explicit verification line -- "prove the assertions are live, not vacuous by
construction" -- which the dispatch's own retrospective calls "the single highest-value line in
the plan". See `standards/metadata-split.md` for the rule and
`standards/forgery-probe-discipline.md` for why this is that document's grounding instance.

### Collision 2 -- 44 `Books.Meta` violations after five green phases

| | |
|---|---|
| **Symptom** | 44 layer violations surfaced at the family's **first** `full-gate.sh` run, after five tagging phases that all reported green on `lake build` |
| **Root cause** | **Both** `LAYER_ALLOW_RULES` refuse `Books.Meta` -- the import **without which `book_layer` does not exist**. The rules predate books and had no opinion about the provider |
| **Fix** | Admit the provider to both allow-lists (`BOOKS_PROVIDER_RE='Books\.Meta'` in `interface/scripts/layer-rules.sh`, now present in both rules' import-halves) |
| **Cheapest catcher** | **`layer-lint.sh` -- which already exists and is fast.** Nothing in the books tagging workflow invokes it |

This row and the next are the clearest optimization target in the whole ledger: both are catchable
by a tier that already exists. See `domain/gate-tiers.md`.

### Collision 3 -- exclusion 6 refused the composite's import of its own `evidence` member

| | |
|---|---|
| **Symptom** | `full-gate.sh` refused the composite book module's import of its own `evidence`-layer member |
| **Root cause** | **Decision 5 *requires* that import** (a book module's direct code-module imports are its membership declaration). **Three of the nine rules have no concept of a book module** |
| **Fix** | An **exemption-field mechanism** added to the rule format: an optional fourth `;`-separated field, an extended regex over the repo-root-relative path, exempting a matching file from **that** rule. Visible today as `${BOOK_MODULE_RE}` on exclusion 6 in `interface/scripts/layer-rules.sh` |
| **Cheapest catcher** | `layer-lint.sh` |

The dispatch flagged this as **its least-confident edit** and said so explicitly: "these are not
bugs in the rules; they are a missing abstraction". A book module holds no declarations, only
imports and `book*` commands, so **its imports are membership, not dependency**. The alternative
-- keep exclusion 6 intact and make the `evidence` module a non-member -- leaves the one
`evidence`-layer module outside every book. **The change is reversible in one line**; settle the
right shape with the repository owner during planning, not inside implementation.

### Collision 4 -- the execution gate refused a generated `lean/.hashgen/Gen.lean`

| | |
|---|---|
| **Symptom** | Gate run **2 of 4** refused a file nothing in the repository lists |
| **Root cause** | The gate's domain is "**every module whose import closure contains `Books.Meta`**", and that set is **not enumerable**. `Gen.lean` is written, `#eval`'d and deleted inside one shell function; nothing lists it, `lake build` cannot reveal it, and it became gate-visible only because the registry it mirrors now imports the provider |
| **Fix** | Site-specific (the generated file's layer and position). The general fix does not exist |
| **Cheapest catcher** | **an import-closure lister -- does not exist.** Called "the single most useful missing tool" by the dispatch that hit it |

Recorded as `domain/known-gap-register.md` B6, and as a checklist caution in
`patterns/authoring-workflow.md`.

### Collision 5 -- a stale `set_option warn.sorry false` broke `check.sh`'s sorry count

| | |
|---|---|
| **Symptom** | The `check.sh` stage of the gate failed on the sorry count |
| **Root cause** | **Two gates disagree about the same warning.** `certify.sh` once failed on the Challenge modules' expected sorry notice; `check.sh` **counts** that notice and fails when it is **absent**. The workaround silenced it at the source -- **correct when written** -- and became a gate failure the moment `certify.sh` was fixed |
| **Fix** | Remove the stale `set_option` |
| **Cheapest catcher** | **an expiry annotation on the workaround -- does not exist** |

**This is the self-inflicted row, and it is the most generalizable.** Twenty-three comment blocks
recorded **why** the workaround existed and **not when it would stop being needed**. A
`-- DELETE WHEN: certify.sh no longer builds with --wfail` line would have made the collision
**self-retiring**. The seed report's recommendation 8 generalizes it: require a workaround on
shared tooling to record an **expiry condition**, not just a justification.

### Collision 6 -- `require books` broke the Comparator clean rooms, two independent ways

| | |
|---|---|
| **Symptom** | A generic **Lake configuration error** on `--recheck` run 1, then **`permission denied (error code: 13)` from inside a sandbox** on run 2. Both diagnosed by reading room logs |
| **Root cause** | `scripts/recheck-comparator.sh` stages its clean rooms from the **digested file list**. A local-path `require` is reachable in a room only if (a) its sources are digested **and** (b) its path matches a hand-written per-config regex **and** (c) it has a landrun read-write grant in **two separate places**. The interface package satisfied all three; `books/lean` satisfied **none** |
| **Fix** | Stage the package in all three places |
| **Cheapest catcher** | **a lakefile-vs-room staging check -- does not exist** |

**Nothing connects "I added a `require`" to "three places in the recheck script need editing."**

## The adjacent finding this ledger exists to pre-empt

Adding **one** local-path `require` obliged **six edits across three files**, none referenced from
the lakefile and none checked by anything until the gate ran:

| File | Edits | What |
|---|---|---|
| `certificate-identity.sh` | 1 | digest the package |
| `recheck-comparator.sh` | 4 | two room patterns, one landrun grant, one `RECHECK_EXTRA_RWX` |
| `layer-rules.sh` | 2 | admit the provider to both allow-lists |

The discovery path for **all six** was a failing gate. A dedicated checklist for this -- proposed
for this corpus under the name "local-path-require-obligations" -- is a **named follow-up and is
not content here, and no such document exists yet**: this ledger records the cost and the shape,
and the checklist, when it lands, carries the procedure. The structural alternative the seed report prefers: make the rooms stage every
local-path `require` automatically by **reading the component's lakefiles** rather than
hand-written path regexes plus grant lists, since each such require needs exactly three derivable
things (staged sources, a resolvable relative path, a read-write grant in both landrun layers).
Its stated fallback if that is too invasive: **fail loudly with a named diagnosis** when a
lakefile declares a local-path require the room has not staged, instead of surfacing a generic
Lake error from inside a sandbox.

## Reading the ledger before an integration

Four of the six rows reduce to two checks that cost almost nothing:

1. **Before tagging**: does the component's rule set (`interface/scripts/layer-rules.sh`, or the
   component's own) admit `Books.Meta`, and does any rule's file-half reach a **book module**?
   Collisions 2 and 3.
2. **After every tagging phase**: run `interface/scripts/layer-lint.sh` over the component's
   package roots. Collisions 2 and 3 again, and the only thing that reaches them before a
   ten-minute gate.
3. **Before adding any local-path `require`**: the three derivable things above, in all three
   files. Collision 6.
4. **For every gate predicate you ship**: a forgery probe. Collision 1, and
   `standards/forgery-probe-discipline.md`.

Collisions 4 and 5 are not reachable this way today; they are gaps, recorded as such.

## What the architecture got right, and must be preserved

The source retrospective is as specific about what worked as about what did not, and three items
are preservation constraints on any future pre-gate tier:

- **Warning-driven convergence** -- the single best-functioning mechanism in the pipeline. Any
  pre-gate tier **must not bypass it**. See `patterns/warning-driven-convergence.md`.
- **`certify.sh --check` earned its keep in the first 90 seconds.** See `tools/certify-guide.md`.
- **`interface/tests/layer/run.sh` extracts the rule block verbatim via `sed` + `eval`**, so the
  self-test exercises the **real** rules rather than a copy. When `layer-rules.sh` was amended,
  the self-test validated the new regexes for free, and adding eight cases was one edit to a
  declarative array. The seed report names this as the pattern a pre-gate tier should follow, for
  a stated reason: **a pre-gate tier that reimplements the rules becomes a third source of truth
  and a new class of false green.**

## The measured-once caveat

Every quantitative claim in this document comes from **one implement dispatch on one component
family**. Its source says so in its own Executive Summary:

> **This report is a seed, not a diagnosis.** Every quantitative claim below is from a single
> dispatch on a single component family. The diagnostics phase must establish whether these costs
> reproduce before any optimization is designed.

**That diagnostics phase has not run.** `specs/178_optimize_books_gate_feedback_loop/` is NOT
STARTED, and `specs/176_measure_framed_channel_book_family_cost/` -- which would measure a second
instance -- is NOT STARTED. The seed report's own mitigation is to **instrument a second family**
(`components/rle_codec/` is the only other `layer-lint.sh` consumer) and record **per-tier
latency** rather than reusing its wall-clock figures.

Treat the six **collisions** as real (they are recorded failures with recorded fixes, and four of
the fixes are visible in the tree today). Treat the **costs** as measured once.

## Related

- `domain/gate-tiers.md` -- what each tier checks, and the cheapest-catcher table.
- `standards/forgery-probe-discipline.md` -- collision 1 generalized into a rule.
- `patterns/warning-driven-convergence.md` -- the mechanism to preserve.
- `domain/known-gap-register.md` -- B6 and the live register entries behind the caveat.
