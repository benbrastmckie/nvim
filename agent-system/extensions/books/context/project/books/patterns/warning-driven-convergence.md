# Warning-Driven Convergence

**Drive the declaration off the compiler's own warning stream, not off a human reading the
source.** The warning names the exact missing item, so the authority is the tool, and the
termination condition is a run with zero such warnings. **No line is guessed.**

Measured instance: **179 `book_requires` lines generated with zero guesses**, converging to zero
warnings on the next run.

**Primary source**:
`specs/121_bring_framed_channel_into_book_graph/summaries/02_framed-channel-book-family-summary.md`,
which calls this "the best-designed thing I touched". Gap claims defer to
`domain/known-gap-register.md`.

## The loop

```bash
# 1. Run the certifier and capture its output.
bash books/scripts/certify.sh --no-build components/framed_channel 2>&1 | tee /tmp/certify.log

# 2. Extract every undeclared dependency the warnings name, and emit the lines.
grep -oP "book \`X\` depends on \`\K[^\`]+" /tmp/certify.log \
  | sort -u \
  | sed 's/^/book_requires /'

# 3. Paste the output into the book module. Re-run step 1.
# 4. Terminate when step 2 produces nothing.
```

Substitute the real book name for `X`, or drop the book-name anchor and filter afterwards when
converging several books in one pass.

## Why the warning stream is the correct oracle

The warning is `book-requires-undeclared`
(`books/lean/BookCert/Depends.lean:302-308`), and its text is the whole reason the loop works:

```
book `<ourBook>` depends on `<n>` at statement level but `<bookModule>` declares no
`book_requires <n>`; completeness of these lines is marked INFERENCE in the design record, so this
is reported and never refused
```

Three properties make it an oracle rather than a hint:

1. **It names the exact missing export** -- a fully-qualified constant name, not a module, not a
   category. The `sed` substitution is total: there is nothing to decide.
2. **It is computed from the statement cone**, not from the source text. The certifier already
   knows the complete set; the warning is that set, minus what the book module declares. A human
   reading the source is **strictly less informed** than the warning.
3. **It is a warning, never a refusal.** Completeness of these lines is marked INFERENCE in the
   design record, so an incomplete set does not fail the run. That is what makes the loop
   *iterable*: each pass is green, and each pass shrinks the gap.

There is a **companion warning** for the other direction, on the same code path --
`book-requires-superfluous` (`books/lean/BookCert/Depends.lean:296-300`): a declared
`book_requires` line whose dependence the certifier does **not** see at statement level is
reported as possibly stale or proof-level ("the line may be stale or the dependence may be
proof-level, which `book_requires` does not cover"). Converging on **both** warnings being empty
is the real termination condition -- the `grep | sed` loop only closes the undeclared half.

## The termination condition, and what it does and does not establish

**Terminate when a run reports zero `book-requires-undeclared` warnings.**

What that establishes: every statement-level cross-book dependence the certifier computes is
declared. Resolution is checked **transitively against statement cones**, so naming a constant
whose declaring module is in the closure is **correct and sufficient** -- you do not need to find
the "right" module.

What it does **not** establish: that no line is **redundant** (the stale-line warning covers
that), and that the set is complete at **proof** level (`book_requires` does not cover proof-level
dependence at all, which the warning text states).

Measured follow-on: **`components/framed_channel/` now carries 193 `book_requires` lines**,
measured 2026-10-03 -- the **179 are the loop's output**, not the current count. Tree-wide the
anchored census is **356** lines over 22 files. A figure quoted as "179 lines in framed_channel"
is quoting the loop, not the tree.

## The second instance in the evidence base: axiom convergence

The same pattern, same repository, different predicate. `[REFUSE] axiom-outside-book-axioms`
names **both the axiom and the reaching declaration**
(`books/lean/BookCert/Reverify.lean:319`):

```
`<name>` depends on axiom `<a>`, which is not in this book's `book_axioms` set
```

The measured run: a composite book was **refused eight times**, and each refusal identified
exactly which axiom to declare and which registry banks reached it. The outcome was **two**
`bv_decide` native helper axioms added to `book_axioms` -- not eight guesses, and not a
trial-and-error search. The source retrospective reads: "That is Decision 12's
never-more-trusted-than-its-least-trusted-part doing real work, not ceremony."

**The difference from the `book_requires` loop matters.** This one is a **refusal**, so each pass
is red and the loop is driven by failures rather than by warnings. The convergence property is the
same (the message names the exact item), but you cannot batch it the same way: a refusal stops the
run at the first book that fails, so the loop is per-book rather than tree-wide.

## Generalizing the pattern

A predicate is a **convergence oracle** when all three hold:

| Property | Why it is required |
|---|---|
| The message **names the exact missing or offending item**, machine-extractably | otherwise the loop needs a human decision per iteration, and it is not a loop |
| The item set is **computed**, not parsed from the thing being fixed | otherwise the oracle is no better informed than the author |
| The pass is **repeatable at low cost** | otherwise convergence costs more than reading the source |

`book-requires-undeclared` satisfies all three and is cheap under `--no-build`.
`axiom-outside-book-axioms` satisfies the first two; the third is the constraint.

**Two predicates that are explicitly NOT oracles**, and must not be driven this way:

- **`book_policy` placement.** A misplaced row produced **no message at all** before the
  `policy-vacuous` refusal landed, and the elaborator still resolves neither operand by design.
  There is nothing to grep. See `standards/metadata-split.md`.
- **The execution-construct gate's domain.** The gate refuses a module when it reaches it, but
  **nothing enumerates the set** ("every module whose import closure contains `Books.Meta`"), so
  there is no stream to converge against -- only a sequence of gate runs.
  `domain/known-gap-register.md` B6.

## What would remove the loop entirely

A **`--emit-requires`** (or `--fix`) mode on the certifier. It already computes the exact
`book_requires` set and prints it as warnings; the `grep | sed` pipeline is pure overhead that the
tool could eliminate. **Named and unbuilt** -- recommendation 4 of
`specs/178_optimize_books_gate_feedback_loop/reports/01_gate-feedback-loop-seed.md`, described
there as "low risk, removes an entire manual loop".

Until it lands, the loop above is the mechanism. And one constraint on anything built in this
area, from the same report: **any pre-gate tier must not bypass the warning-driven convergence
loop, which is the single best-functioning mechanism in the pipeline.** A tier that suppresses
the warnings to produce a quieter green output would remove the oracle.

## Closing the other half: `book-requires-superfluous`

The `grep | sed` loop above only adds. Converging the **stale** half needs the companion warning,
and it cannot be automated the same way, because the fix is a judgment rather than a substitution:

```bash
# Extract the lines the certifier reports as possibly stale or proof-level.
grep -oP 'declares no `book_requires \K[^`]+|reaches `\K[^`]+' /tmp/certify.log | sort -u
```

For each name the stale-line warning raises, there are **two** correct outcomes and you have to
decide which:

- **The dependence is genuinely gone** (an interface changed, a member moved) -- delete the line.
- **The dependence is proof-level only** -- keep the line or delete it, knowing that
  `book_requires` **does not cover proof-level dependence at all**, so the line is documentation
  rather than a checked claim. The warning text says exactly this.

Neither outcome is derivable from the warning, which is why this half is not a loop. Do it once,
deliberately, after the additive loop has terminated -- not interleaved with it.

## Recording the result

Whatever the loop produces, record the **termination evidence**, not the intent: the command run,
the date, and the warning count on the final pass (`0`). A `book_requires` block whose provenance
is "generated by the loop on <date>, zero warnings on re-run" is checkable by re-running one
command. A block whose provenance is "reviewed the imports" is not.

This is the same measured-not-inherited rule `patterns/authoring-workflow.md` states for every
figure in a build/test record.

## Related

- `standards/metadata-split.md` -- `book_requires` and its three elaboration-time checks.
- `domain/status-and-trust-vocabularies.md` -- the axiom rule the second instance enforces.
- `tools/certify-guide.md` -- running the certifier cheaply enough to iterate (`--no-build`).
- `patterns/gate-collision-ledger.md` -- what the convergence loop is listed alongside as
  preserve-under-any-optimization.
