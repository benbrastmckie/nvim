# Plan-Authoring Gate Collisions

A checklist for a Lean plan author to run through before writing a verification criterion, not
after one fails. Every condition below shares one failure mode: a phase's verification step turns
out to be unmeetable as written, through no fault of the implementation work that phase did. Some
conditions concern gate MECHANICS — which generated surface a gate actually checks, and what
shape of target argument a gate script takes. Others concern the SEARCH SPACE a sweep or lint
criterion ranges over. All of them are facts a plan can and should enumerate in advance, because
each one determines a concrete thing the plan must schedule as its own phase work (a regeneration
step, a file-scope entry, an allowlist extension, a rename) rather than discover mid-phase.

## Condition 1 — A Lean Line-Count Change Trips Two Generated Surfaces

Any change to Lean source line counts — including a pure docstring or comment addition that adds
no declaration — trips two independent generated surfaces, and one of them carries two distinct
trigger conditions of its own:

- **Surface (a): the module-inventory blocks** in `README.md` and
  `FormalSystem/Metalogic/README.md`, regenerated via `scripts/check-module-invariants.sh
  --emit-inventory` and verified via `--emit-inventory --check`.
- **Surface (b): `typst/generated/status.typ`'s `formalsystem-line-count`**, regenerated via
  `scripts/typst-sync-check.sh --fix` and checked by `scripts/typst-sync-check.sh
  --counts-only`. This surface has two distinct trigger conditions, not two surfaces: the
  inventory-block check inside the same script, and its line-count-staleness check (Check 2).
  Either one drifting is a finding on the same surface.

**The asymmetry is the load-bearing fact, not merely that both exist.** Surface (b) is enforced
by `.githooks/pre-commit`, so drift there BLOCKS the commit of the very phase that caused it — it
cannot be deferred. Surface (a) is checked by a later verification step, so it may legitimately be
scheduled into a plan's final reconciliation phase. A plan that schedules only surface (a), or
that schedules surface (b) late alongside (a), will have its first qualifying phase commit
refused.

Three further mechanical facts change what a plan author must do:

- The hook fires only when the staged set touches a `.lean` path. A prose-only phase is a fast
  no-op and needs no regeneration step.
- The hook is BLOCKING, not auto-regenerating. The regeneration is an explicit plan step with its
  own staged file (`typst/generated/status.typ`), never something that happens underneath the
  commit.
- CI runs the full `typst-sync-check.sh` Check 2 as the unbypassable backstop. `--no-verify`
  defers the collision to CI rather than avoiding it.

**Plan-authoring consequence**: a plan that adds or removes Lean lines pre-authorizes the
`--fix` run and carries `typst/generated/status.typ` in its own file scope, in the same phase as
the line-count change — not deferred to a reconciliation phase, because surface (b) cannot wait.

See `context/formats/plan-format.md`'s "Coupled-generated-surface declaration obligation" for the
repo-agnostic statement of this same rule, with this condition as this repository's instance of
it.

## Condition 2 — `verify-deploy.sh`'s Target Argument Is a Deploy-Tree Root

State the correct shape positively: the target argument is a repository root that holds a
deployed `.claude/` tree — and, for a source-store-adjacent invocation, one that holds the
`agent-system/extensions` source store simultaneously — never an extension subdirectory. Passing
a `source_dir` (an extension's own directory under `agent-system/extensions/<ext>`) cannot work:
that directory has no `.claude/` subdirectory of its own, so gate 0 exits before any gate is even
selected. See the core plan-authoring format's `## Verification Tiers` section, sub-case (b), for
the authoritative target-shape contract behind this rule; this file states the consequence rather
than re-deriving it.

**The corollary a plan author needs**: because the gate set runs against the WHOLE deploy tree,
a red gate there may be entirely pre-existing and unrelated to the plan's own edits. A
verification criterion invoking `verify-deploy.sh` must therefore be phrased to distinguish
findings that name the plan's own touched files from the tree's standing baseline — never as a
bare "the gate passes," which conflates the two.

## Condition 3 — A Sweep Asserting "Matches Nothing" Can Be Unsatisfiable by Construction

A plan-authored sweep that asserts "matches nothing" over a path set which deliberately retains
refuted or pinned historical bodies is unsatisfiable BY CONSTRUCTION. The author's intent in such
a criterion is always "my new declaration is absent." The sweep as written instead asks "no
declaration of this shape exists anywhere in these paths" — and in a repository whose evidence
apparatus retains refuted candidates by design, the second question has a permanent, intended
answer of "some exist."

There are two independent failure reasons here, with different remedies, and a criterion that
fixes only one is still unsatisfiable for the other:

- **(a) Retained refuted bodies.** A repository's refutation-probe paths hold declarations the
  evidence record keeps deliberately — pinning a refuted candidate's body is how the record
  preserves what was ruled out. Any sweep ranging over `FormalSystem/`, `Tests/` and
  `specs/evidence/` must EXCLUDE the refutation-probe paths, or it will match bodies the record
  intentionally keeps.
- **(b) Prefix capture.** A `^def` anchor on a short name also matches every sibling name sharing
  that prefix — for example `^def ladderIndex` matches not only `ladderIndex` itself but also
  `ladderIndexRes` and `ladderIndexJnt`, even when the exact name the author cared about is
  genuinely absent. The remedy is different from (a): assert the absence of the SPECIFIC NEW
  declaration name, never a shared prefix.

**The remedy is confirmed, not merely proposed**: an exact-name sweep over a set of genuinely new
declaration names, checked on the same tree in the same phase that measured the prefix-capture
failure, found none of those names present — the exact-name form is satisfiable exactly as
written. Prefer it over a prefix-anchored sweep whenever the paths being ranged over retain any
refuted or pinned historical body.

## Condition 4 — A Repo-Wide Lint Criterion Is a Baseline Delta, Not an Absolute Zero

A phase criterion that invokes a repo-wide lint, sweep, or grep MUST be stated as a delta against
the baseline, never as an absolute zero or an absolute exit 0 — UNLESS the author has confirmed
the baseline is in fact clean AND that the criterion will still hold when it is checked. A
baseline is a moving quantity: hard-coding one is wrong the moment it moves, in either direction.

State the satisfiable forms a plan author may use, in preference order:

1. **Scope the criterion to the files the task touches** ("every file this phase modifies passes
   the lint individually") — both meetable and the thing actually being asserted.
2. **State it as a delta** ("the repo-wide count does not increase relative to the pre-task
   commit"), naming how the baseline is captured.
3. **If an absolute repo-wide zero genuinely is the intent**, the plan must FIRST schedule the
   cleanup that makes it true, as an explicit in-scope step — the same discipline Condition 1's
   generated-surface regeneration requires: a plan must schedule the step that produces the state
   its own criterion later reads, not assume that state exists.

**The implementer-side corollary**, since authoring discipline alone cannot close this: a gate
whose only failures are pre-existing and outside the task's file scope is a recorded PASS for that
phase, with the enumerated pre-existing findings and the evidence that each touched file passes
individually. It is not a blocker, and it is not grounds to edit an out-of-scope file to force the
absolute count to zero.

**Worked example.** `FormalSystem/Examples/TemporalStructures.lean`'s `int_domain_universal`
closes with a `trivial` body because its goal reduces to `True` — a legitimate proof, not debt. A
vacuous-definition grep built to flag exactly that body shape will always match it. This is the
sharper reason the remedy is a baseline delta or a touched-files scope rather than "clean up the
baseline first": a legitimate `trivial` closing a real goal is simultaneously a FALSE POSITIVE
for the underlying pattern, so the pattern itself cannot distinguish debt from a correct one-line
proof — there is no baseline state in which an absolute-zero version of this particular lint
could ever hold.

## Condition 5 — `check-metalogic-cycles.sh` Assertion B Asserts Equality and Fails on Surplus

This is the most dangerous of the gate-surface conditions below, because it fails on work that is
correct. Assertion B in `scripts/check-metalogic-cycles.sh` asserts that the library-wide upward
import set EQUALS a frozen allowlist (`_SRC`, `_SRC_OPEN` and the `ALLOWLIST` set built from them)
— equality, not containment — so it fails on SURPLUS as well as on deficit. A new layer-0 file
importing a layer-2 `FormalSystem.Theorems.*` module for a legitimate discharge arm produces
surplus upward edges and fails the gate even though the import is intended and correct. State the
mechanism this way rather than citing the allowlist's current size as a fact to copy: if a plan
wants to name a concrete count at all, read it live from the script's own header comment at
authoring time, since a stale copy elsewhere in the repository has already been observed to
disagree with that header.

**Plan-authoring consequence**: a plan introducing ANY new upward import must extend the
allowlist IN THE SAME PHASE as the import, and must carry `scripts/check-metalogic-cycles.sh` in
its file scope.

## Condition 6 — C26 Forbids Non-Trailing Underscores in `def`/`abbrev` Names, and `theorem` Is Exempt

`check-module-invariants.sh` C26 flags any live `def` or `abbrev` whose last name component
carries a non-trailing underscore. `theorem` is EXEMPT from C26 — which is exactly why
snake_case theorem names are common in this repository and mislead by analogy when a plan reaches
for the same convention on a `def`. The repository's actual precedent for derivation-term `def`s
is lowerCamelCase: `MinusLanguage/AxiomDischarge.lean`'s `dischargePropK`, `dischargeModalT`,
`dischargeAxiom`; `Theorems/TemporalDerived.lean` follows the same convention.

**Plan-authoring consequence**: a plan that says "promote probe N rather than re-deriving it"
must state whether the promotion is verbatim, and must mandate the `def` renames explicitly when
it is not — a verbatim promotion of a probe's own snake_case `def` names will fail C26 on arrival.

## Condition 7 — The `longFile` 1500-Line Ceiling, and Its Narrow Baselining Window

The package-level `longFile` lint ceiling is 1500 lines. Per
`docs/development/LEAN_STYLE_GUIDE.md`, a file crossing that ceiling is BASELINED, not split, via
`set_option linter.style.longFile N` placed directly after the module docstring; `longFile 0`
turns the linter off rather than recording a ceiling and is rejected for that reason, not a
shortcut.

**The trap is the acceptance window, and it is not a flat `N - 200 <= lines < N` margin.** The
linter computes `candidate = max(defValue, (lines / 100) * 100 + 200)` from the file's CURRENT
line count (`defValue` is `linter.style.longFileDefValue`, 1500 by default), and accepts a
declared baseline `N` without warning only when `N == candidate` or `N + 100 == candidate` —
exactly the two values `{candidate - 100, candidate}`. Any other declared `N` produces "This file
is {lines} lines long. The current limit is {N}, but it is expected to be {candidate}." Two
reproductions, read from the pinned toolchain's own Mathlib checkout
(`Mathlib/Tactic/Linter/Style.lean` at the revision the originating repository's
`lake-manifest.json` pins for `leanprover/lean4:v4.33.0-rc1`), confirm the arithmetic rather than
deriving it: 2967 lines against a declared baseline of 3400 yields `candidate = 3100` (the
message names 3100, not 3400); 3200 lines against a declared baseline of 3200 yields `candidate =
3400` (the message names 3400, never 3300, even though 3300 is also a member of the
accepted-if-declared set for that `candidate`). The linter's own internals can drift with a
toolchain bump, so a plan author on a different pin re-reads the source rather than trusting this
arithmetic.

**Plan-authoring consequence**: because `candidate` is a function of the file's CURRENT length,
not of any eventual target length, the baseline is bumped INCREMENTALLY as the file grows across
phases — a single early bump to the final expected value is itself a new warning, since that
value will not equal the smaller `candidate` the linter computes for a shorter intermediate
length. Each phase that moves the file's line count therefore owns its own re-tightening to that
phase's own `candidate`, scheduled as named phase work rather than discovered when the gate
fails.

## Condition 8 — The `show` Tactic Is Linted, and CI Builds With `--wfail`

The `show` tactic is linted in this repository (the linter's own guidance: `show` should only be
used to indicate intermediate goal states for readability), and CI builds with `--wfail`, so a
lint WARNING is a CI FAILURE, not a note. Using `show` to exploit a definitional equality — an
ordinary and otherwise idiomatic move — fails CI under this configuration; the remedy is a named
`rfl` lemma instead of an inline `show`.

**The general point this makes a planning condition rather than a style note**: under `--wfail`,
ANY linter category is a hard gate, including categories such as `unusedVariables` that read as
merely cosmetic elsewhere. A plan must treat "warning" and "error" as the same thing when judging
whether a phase is green.

## Condition 9 — C5's Module-Path Regex Cannot Tell a Declaration Name From a Module Path

`check-module-invariants.sh` C5's module-path regex matches any dotted, all-capitalized name
shape, including a DECLARATION NAME that happens to look like a module path component — it
cannot distinguish the two syntactically. The remedy is a permanent, documented exemption entry
in `scripts/module-invariants-allowlist.txt`, not a rename: that file is a permanent-exemption
list, not a debt ledger, and already carries exactly this kind of entry for existing
declarations whose names collide with the module-path shape.

**Plan-authoring consequence**: a plan introducing a declaration whose name looks like a module
path component pre-authorizes the companion allowlist entry and carries
`scripts/module-invariants-allowlist.txt` in its own file scope.

**A companion checklist of further bare-gate conditions worth enumerating in the same pass**,
each one a `check-module-invariants.sh` finding observed to surface unannounced on a bare run:

- **C15**: every theorem-index row needs a `Paper:` line in the declaration's own doc comment.
  A batch of new declarations lacking one will all fail together.
- **C33**: after adding or removing files, `lake exe mk_all --lib FormalSystem` must be re-run to
  regenerate the library root; a plan adding files carries this step explicitly.
- **`FAIL INV`**: the module-inventory blocks (Condition 1's surface (a)) go stale the same way a
  line-count change makes them stale — a file added, removed, or renamed under `FormalSystem/`
  without a matching `--emit-inventory` run reports as a stale generated block.
