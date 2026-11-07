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
