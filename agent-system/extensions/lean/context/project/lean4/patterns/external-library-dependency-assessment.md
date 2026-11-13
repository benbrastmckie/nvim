# Assessing an External Lean Library as a Candidate Dependency

A checklist for the question "should this project `require` (or continue not to `require`) an
external Lean library, or a fork of one?" — harvested from one assessment that had to invent
each item below under time pressure, after a prior inventory's inherited figures turned out to
be wrong in ways that changed the answer. Each item names the failure mode it guards against
and the measurement that replaces it.

## 1. Read upstream claims through `git show`, never through a fork worktree

If the candidate is a fork, do not read a cloned fork's worktree and assume what you see there
is also what upstream has. A worktree can carry local modifications, placement differences, or
drift that silently gets attributed to upstream.

**Do this instead**:
```
git -C <fork-checkout> show upstream/main:<path/to/file.lean>
```
This reads upstream's content directly out of its own ref, with no risk of a fork-local edit
leaking into the claim. One misattribution this caught: a lemma a prior inventory placed
upstream was, when read this way, found fork-only — the fork worktree's copy had been read and
mistaken for the upstream original.

**Checklist item**: for every claim of the form "X exists upstream" or "X's upstream form is Y",
re-derive it with `git show upstream/main:<path>`, not by opening the fork checkout's file.

## 2. Measure the commit divergence in BOTH directions

`git rev-list --count` in one direction alone answers "how far ahead is the fork", and silently
hides "how far ahead is upstream". A fork description that reports only the first number can
read as pure progress when it is actually a two-way divergence.

**Do this instead**:
```
git -C <fork-checkout> rev-list --left-right --count upstream/main...HEAD
```
Read the output as `<behind> <ahead>` (left = upstream-only commits, right = fork-only commits).
One assessment's fork was described as "4717 commits ahead"; measured this way, it was also 235
commits BEHIND upstream — a lag the one-directional framing never surfaced, and one that matters
for merge cost and for whether the fork has missed upstream fixes.

**Checklist item**: never trust a single-direction commit count as a divergence measurement.
Always run the two-way form and report both numbers together.

## 3. Compare `lean-toolchain` BEFORE comparing Mathlib revisions

A Mathlib-revision comparison in isolation can invert the real cost ordering between two
candidates, because the Lean toolchain each candidate targets determines whether its Mathlib
revision is even reachable from the current project without a toolchain bump of its own.

**Do this instead**: read and compare `lean-toolchain` (a one-line file) across the project and
every candidate BEFORE measuring Mathlib commit distance:
```
cat <project>/lean-toolchain
git -C <candidate-checkout> show upstream/main:lean-toolchain
```
One assessment found a fork's `lean-toolchain` MATCHED the project's current toolchain while
upstream's did NOT — meaning the "ahead" candidate by raw commit count was actually the cheaper
one to adopt, because adopting upstream would have forced a toolchain bump the fork does not
require. Measuring Mathlib revisions first, without this check, would have reported the
opposite cost ordering.

**Checklist item**: toolchain comparison is a precondition for interpreting a Mathlib-revision
comparison, not an independent, lower-priority fact to check afterward.

## 4. Verify a build cache post-dates its sources before trusting `#print axioms`

`#print axioms` reports the axiom profile recorded in a build's `.olean` artifacts. If those
artifacts are stale relative to the source files they claim to represent, the reported axiom
profile may describe code that differs from what is now on disk.

**Do this instead**: before running or trusting any `#print axioms` output against an existing
build cache, confirm every relevant source file's mtime precedes the `.olean` mtimes:
```
stat -c '%y' <checkout>/.lake/build/lib/lean/<Pkg>/<Module>.olean
stat -c '%y' <checkout>/<Pkg>/<Module>.lean
```
Also check the last commit touching the relevant tree against the oleans' timestamps, as a
second, independent confirmation. Only once every source precedes its olean is the axiom-profile
reading a measurement rather than a guess about which code it describes.

**Checklist item**: a cache-freshness check is a precondition for trusting `#print axioms`
against a build cache you did not just produce yourself in this session.

## 5. Compute the IMPORT CLOSURE of the target modules, not the repository's line count

A candidate library's total line count (or file count) answers "how big is this repository",
not "how much of it would this project actually pull in". The two numbers can differ by an
order of magnitude, because a `require` only pulls in the transitive import closure of the
modules the project actually references — not the whole repository.

**Do this instead**: enumerate the specific modules the project would need, then compute their
transitive import closure (a script walking each module's `import` statements to a fixed point,
counting the union of modules reached and their total line count) rather than reporting the
repository's `wc -l` or `cloc` total.

One assessment's honest number for a specific feature area was **29x smaller** than the
repository-wide line count (a transitive closure of 51 modules / 8,526 lines against a
repository total of 244,339 lines) — and the closure, unlike the repository total, excluded an
entire unrelated subsystem the project would never import.

**Checklist item**: never report a candidate's "size" as its repository-wide line count when the
actual question is the cost of importing a specific feature area. Compute and report the import
closure instead.

## Composing the checklist

These five items are independent measurements, not a strict pipeline — run whichever apply to
the specific dependency question at hand — but items 1-2 (how the candidate's own state is read)
are cheapest to get wrong first and worth doing before items 3-5 (cost-ordering comparisons that
build on an accurate picture of the candidate). None of the five require write access to the
candidate's repository or to the importing project; every command above is read-only.

## See Also

- `context/project/lean4/domain/metadata-trust-surfaces.md` — the `proof_wanted` trust-surface
  subsection covers a related but distinct question: once a dependency decision has been made,
  what a target module's own `sorry`/axiom metadata can and cannot be trusted to mean.
- `context/project/lean4/patterns/dependency-tracing.md` — the import-closure technique in
  item 5 above is the same mechanical tool this file's Shape 1-4 probes use for a different
  question (whether a declaration depends on another), applied here to modules rather than
  constants.
