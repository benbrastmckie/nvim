# Comparator Integration: Clean-Room Runner Design Record

This file records the design decisions behind
`agent-system/extensions/lean/scripts/lean-comparator-run.sh`, a wrapper CLI around the upstream
`leanprover/comparator` judge (Apache-2.0, github.com/leanprover/comparator). It exists so a
future maintainer -- in particular whoever takes on the later, separate decision of promoting
Comparator from an advisory check to a hard completion gate -- does not have to re-clone and
re-read the upstream repository from scratch.

## What Comparator Is

Comparator is a trustworthy judge for Lean proofs from untrusted sources, built by Lean FRO with
AIMO feedback. Given a trusted `Challenge.lean` (statements, bodies may be `sorry`), an untrusted
`Solution.lean`, and a JSON config naming `challenge_module`, `solution_module`, `theorem_names`,
`permitted_axioms` (and optionally `definition_names` and `external_kernels`), it:

1. builds Challenge with `lake` inside a `landrun` sandbox, then runs `lean4export` on the
   `.olean`
2. repeats build-sandboxed and export-sandboxed for Solution
3. verifies every declaration used in the STATEMENT of each named theorem is identical between
   the Challenge and Solution environments
4. verifies the bodies of the named theorems use no axioms outside `permitted_axioms`
5. replays the Solution environment into the Lean kernel (optionally also external kernels)

It deliberately never loads `.olean` files -- they are mmapped into the address space and
dereferenced, and are therefore an attack surface.

## Clean-Room Decision

**Decision**: materialise the checking environment as a fresh `git worktree add` of the target
project at the exact commit to be checked, taken BEFORE the runner is ever invoked with an
untrusted Solution, with `.lake/` populated by `lake exe cache get` run in that same fresh
worktree BEFORE the Solution module is written into it.

This satisfies both of Comparator's relevant preconditions simultaneously by construction:
precondition 1 (imports/lakefile controlled and trusted) and precondition 2 (the Solution file
has not previously been compiled in this checking environment, "as that might compromise your
Challenge file to make it seem like you are looking for a different proof than you actually
are").

### What "trusted" means for the reused `.lake`

The `.lake/` directory populated via `lake exe cache get` is trusted to exactly the same degree
the operator already trusts every ordinary `lake build` of the target project: it is the
project's own published build artifacts, fetched over the project's normal cache-server
pipeline. This is **not** a stronger trust boundary than the project's existing supply chain --
it is the same one. The upstream README states this acceptance criterion explicitly, and this
runner adopts it verbatim rather than inventing a stricter (and more expensive) alternative:

> "if you trust the cache to not be modified as to, e.g. contain different definitions from the
> one you would expect"

If that trust does not hold for a given project (a compromised or unverified cache server), the
clean-room guarantee this runner provides does not hold either -- this is an explicit,
acknowledged limitation, not an oversight.

### Alternatives evaluated and rejected

- **Scratch copy without a prebuilt `.lake`**: forces a full in-sandbox rebuild from source on
  every run, compounding constraint C4 (cost), and satisfies precondition 2 no better than the
  cache route does -- a scratch copy is "has never been compiled" regardless of whether `.lake`
  is prepopulated. No advantage, large cost disadvantage. Rejected.
- **`git clone --depth 1`**: does not share the object store with the main checkout, so it is
  slower to create and discard per run than a `git worktree add`, for no additional isolation
  benefit (a worktree already gives an independent working directory and an independent
  `.lake/`). Rejected in favour of `git worktree add`.

### Fallback if the worktree route proves unworkable

If Phase 3's worktree approach proves unworkable against a real target project (e.g. the target
project's `.lake` cache is unavailable and a from-source rebuild is unavoidable), the documented
fallback is a scratch copy with an explicit loud notice that the C4 cost is higher. Any commit
that switches to this fallback must amend this design record in the same commit rather than
leaving it describing a route the code no longer takes.

## Sandbox Invocation and Guard Nesting

The upstream README mandates this exact wrapper form around every Comparator invocation:

```
systemd-run --property=RestrictAddressFamilies=~AF_UNIX --user --pty -E PATH="$PATH" \
  --working-directory <workdir> -- bash -c 'lake-build-guard.sh build --dir <workdir> --no-share -- env <comparator> config.json'
```

**Nesting order is significant and is NOT interchangeable**: the README's `systemd-run
--property=RestrictAddressFamilies=~AF_UNIX ...` wrapper is the OUTER layer (a security boundary
-- landrun-escape mitigation, per the README's own stated grounds that `.olean` files are mmapped
and dereferenced and are therefore an attack surface), and
`agent-system/extensions/core/scripts/lake-build-guard.sh build -- env <comparator> config.json`
is the INNER layer (concurrency/memory-pressure serialisation against ordinary agent builds of
the same project). These serve different, non-substitutable purposes; do not collapse them into
one `systemd-run` invocation, and never pass the guard's own `--memory-bound` here -- stacking
two `systemd-run --user` scopes adds complexity with no stated benefit, and the guard's own
`--memory-bound` uses a *different* `systemd-run --user --scope ...` invocation serving a
different purpose than the README's mandatory wrapper.

### `--no-share` is a correctness requirement, not a performance choice

`lake-build-guard.sh`'s result-sharing (REPLAY) mechanism keys a `scope_key` on a hash of the
wrapped command's **argument vector** -- here, `env <comparator-binary> config.json`, i.e. the
`config.json` **path**, not its content -- combined with a tree fingerprint that covers
`*.lean`/lakefile/`lean-toolchain` but explicitly **excludes** `config.json`. Two Comparator runs
against the identical Challenge/Solution files but a **different `config.json` body at the same
path** (a tightened `permitted_axioms` list, a different `theorem_names` selection) are
indistinguishable to the guard, and a stale REPLAY would silently hand back the wrong verdict.
`--no-share` MUST always be passed to the guard invocation at this call site. This is a
deliberate correction to `lean-sorry-census.sh`'s own precedent, which omits `--no-share` --
that omission is safe there only because its wrapped command is always the bare `build`
subcommand with nothing but the project tree determining output; it must NOT be copied here.

Read `lake-build-guard.sh`'s own contract (subcommands, exit-code band, `--dir`, `--no-share`)
before modifying this call site -- it is reused as-is and is never modified by this task.

## Verdict Vocabulary

Comparator itself exposes only a binary exit code: every failure path surfaces as an uncaught
`IO.userError`, which Lean's runtime reports to stderr as `uncaught exception: <message>` with
process exit code 1 (confirmed against every `test.json` in upstream's `tests/projects/`
fixture tree, which uniformly expects `exit_code: 1` for every failure category and `exit_code:
0` only for a true pass). There is no structured output -- the wrapper owns 100% of verdict
classification via stderr/stdout substring matching against the exact strings below, in priority
order (most specific first).

| Verdict | Meaning | Exit code | Upstream source |
|---------|---------|-----------|------------------|
| `verified` | stdout `Your solution is okay!` printed, exit 0 | 0 | `Comparator/Compare.lean` (`compareIt`, final line) |
| `statement_mismatch` | stderr `Challenge and solution theorem statement do not match: '<name>'` (`reason_detail=statement`), OR stderr `Challenge and solution constant kind don't match: '<name>'` (`reason_detail=kind`), OR stderr `Const does not match between challenge and target '<name>'` (`reason_detail=const_closure`) | 65 | `Comparator/Compare.lean` (`compareAt`, `Compare.loop`) |
| `axiom_violation` | stderr `Illegal axiom detected: '<name>'` | 66 | `Comparator/Axioms.lean` (`Axioms.loop`, transitive closure walk) |
| `kernel_rejected` | stdout `Lean default kernel rejects the solution`, or stdout `<kernelName> kernel rejected the solution` | 67 | `Comparator/Compare.lean` (kernel replay) |
| `definition_hole_needs_human` | Comparator exited 0 (i.e. classified `verified`) AND `definition_names` was non-empty in the config; carries `underlying_verdict: verified` | 68 | wrapper-added annotation, not a Comparator failure mode |
| `comparator_unavailable` | a required binary (`comparator`, `landrun`, `lean4export`, `nanoda_bin`) could not be resolved, or the sandbox wrapper (`systemd-run`) is unusable | 69 | wrapper-only |
| `timeout` | the run exceeded `--timeout` | 70 | wrapper-only |
| `config_error` | stderr `Const not found in challenge: '<name>'` or `Const not found in solution: '<name>'` -- an authoring error (a name in `theorem_names`/`definition_names` absent from one side), not a security finding | 71 | `Comparator/Compare.lean` |
| `unclassified_failure` | a non-zero (or unexpectedly bare-0) exit whose captured output matches NONE of the strings above -- a 9th, INTERNAL escape-hatch value, distinct from the 8 named categories the design settles on. Never silently folded into `verified` or `comparator_unavailable`: a checker that can only ever say "pass" is not a checker. | 72 | wrapper-only (fail-closed fallthrough) |

Usage errors (bad CLI arguments) exit 64, matching `lean-sorry-census.sh`. Exit codes 75-79 are
reserved by `lake-build-guard.sh` and MUST NOT be reused by this script.

**`Const does not match between challenge and target` note**: this single string covers two
distinct upstream call sites (a definition-hole `ConstantVal`/safety mismatch in `compareAt`,
and a transitive-closure walk mismatch in `Compare.loop`) and cannot, by itself, distinguish "the
hole itself doesn't match" from "something the hole/theorem transitively depends on doesn't
match". Both are folded into `statement_mismatch` with `reason_detail=const_closure` rather than
given a separate top-level verdict, since upstream provides no further textual distinction to
key on.

**Definition holes require additional (potentially human) verification.** Comparator returning
exit 0 on a config with non-empty `definition_names` still requires review beyond the
kernel/statement/axiom guarantees Comparator itself establishes. The upstream README's own
concrete gaming example: `def ChallengeSolution : Prop := sorry` in the Challenge is answered
with `def ChallengeSolution : Prop := RiemannHypothesis` in the Solution and closed by `rfl` --
Comparator's statement/axiom/kernel checks all pass, because nothing in them evaluates whether
the hole's *filled value* is a legitimate answer versus an unrelated true (or merely
plausible-looking) proposition. `definition_hole_needs_human` is therefore emitted as its own
top-level verdict (never silently folded into `verified`), carrying `underlying_verdict:
verified` so the guarantees Comparator did establish remain visible.

**Fail-closed classification.** A non-zero exit matching none of the above arms MUST emit a
loud, unclassified failure that is neither `verified` nor `comparator_unavailable`, carrying the
raw stderr. A checker that can only ever say "pass" is not a checker.

## Env Var / Binary Resolution and the C3 Version-Coupling Caveat

`COMPARATOR_LANDRUN`, `COMPARATOR_LEAN4EXPORT`, and `COMPARATOR_NANODA` are Comparator's OWN
env-var override names (from its README and `Main.lean`'s `M.run`), carried through unchanged --
not invented by this repo. `COMPARATOR_BIN` (this repo's own name, no upstream precedent since
upstream has no need to override its own binary) resolves the `comparator` binary itself. Each
falls back to a bare `PATH` lookup when unset.

**Comparator's own toolchain is `leanprover/lean4:v4.34.0-rc2`**, and its `lakefile.toml` pulls
`lean4export` at `rev = "master"` built against that toolchain. `lean4export` must instead match
the Lean version of the TARGET project being checked, not Comparator's own. Consequently:
`COMPARATOR_LEAN4EXPORT` MUST NEVER default to a path inside a Comparator checkout (e.g. a
`lean4export` binary produced as a side effect of building Comparator itself) -- it resolves via
`PATH` or the explicit override only. A `lean4export` binary built against the wrong Lean version
could silently mis-export a target project rather than failing loudly, which would be worse than
`comparator_unavailable`.

A missing required binary is never a skipped check that reads as a pass: it is a
`comparator_unavailable` verdict naming BOTH the missing binary and the environment variable that
would override it.

## Gate Strength: Advisory Only (Binding)

This is the natural terminal gate for
`agent-system/extensions/lean/context/project/lean4/standards/proof-debt-policy.md`'s zero-debt
completion requirement, which today is enforced only by text-heuristic greps in
`lean-implementation-agent.md`'s Final Verification Stage (a name-existence grep for plan
compliance, a single-line `axiom` grep, a single-line vacuous-definition grep, and an unsandboxed
`lake build` that never replays into the kernel). Comparator upgrades each of those from a grep
heuristic to a kernel-backed guarantee.

**Binding decision (already made by the operator; do not relitigate in this task or its
descendants without a new, separate decision)**: Comparator integration starts ADVISORY ONLY. A
Comparator rejection records its finding and surfaces it prominently, but MUST NOT set
`verification_passed` false, MUST NOT downgrade status to partial, and MUST NOT block completion.
Promotion to a hard gate is a separate, later decision to be taken on evidence from real runs --
this runner script does not wire itself into any gate, and no later phase of this same task does
either.

## Cost (C4)

Two sandboxed full builds, plus two exports, plus a kernel replay: on a Mathlib-dependent project
this is minutes to tens of minutes. This runner is opt-in and standalone, scoped to named
theorems, and is never wired into a per-iteration implementation loop. A `--timeout` bounds any
single run; expiry emits the `timeout` verdict rather than hanging indefinitely.

## References

- Upstream: https://github.com/leanprover/comparator (Apache-2.0, default branch `master`, as
  measured 2026-08-30/2026-09-07).
- `agent-system/extensions/core/scripts/lake-build-guard.sh` -- the shared build-serialisation
  guard reused (never modified) by this integration.
- `agent-system/extensions/lean/scripts/lean-sorry-census.sh` -- the sibling script whose
  dirname-relative-sibling-with-env-override guard-resolution pattern this runner generalises
  from one binary to four.
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` -- Final Verification Stage,
  the four text-heuristic gates Comparator's guarantees are relative to.
- `agent-system/extensions/lean/context/project/lean4/standards/proof-debt-policy.md` -- the
  zero-debt completion policy this integration is the eventual terminal gate for.
