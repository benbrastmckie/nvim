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

### Outer Landrun Hardening (Deliberate Addition, Not a README Deviation)

The README's mandated wrapper above confines only what happens INSIDE Comparator's own internal
sandbox (its internal `lake build`, via `COMPARATOR_LANDRUN`). The top-level `lake env`
invocation and Comparator's own process -- and any Lake package-management operation that runs
before Comparator's internal sandbox ever starts -- run OUTSIDE that sandbox entirely. This
runner adds a THIRD layer: a `landrun` invocation wrapping the whole `systemd-run` payload
(`--best-effort --rox / --rw /dev --rwx <clean-room worktree>`), confining the entire run --
including Lake's own package management -- to the clean-room worktree plus `/dev`, with no
network access. The rationale is explicit and narrow: never trust Lake package management with
more room than the clean-room worktree needs, since Lake operations that shell out to `git` (see
the pre-flight probe below) happen before Comparator's own sandbox is even constructed. Like
Comparator's own internal call, `--best-effort` is used deliberately: strict mode demands the
newest Landlock ABI the installed `landrun` knows and refuses to start below it, which not every
host's kernel reaches. `landrun` drops every environment variable not explicitly named via its
own `--env` flag, so every variable this runner's own `systemd-run -E` flags set (`PATH`, `HOME`,
`TMPDIR`, `COMPARATOR_LANDRUN`, `COMPARATOR_LEAN4EXPORT`, the shim's own env-var seams) must be
re-listed on this outer `landrun` call too, or the wrapped process would not see it. This layer's
absence is handled the same way a missing `lake-build-guard.sh` already is: a loud warning, then
a degraded-but-proceeding run -- never a silent skip.

### Git-Remote Pre-Flight Probe

Before the main sandboxed run, this runner probes `git -C <pkg> remote get-url origin` for every
linked dependency package under the clean-room worktree's `.lake/packages/`, under the SAME
sandbox grants (outer landrun plus the resolved `git`) the main run itself would use. Lake treats
a linked package whose remote it cannot read as MOVED and deletes `.lake/packages/<dep>` to
re-clone it -- inside a network-denied sandbox, that re-clone then also fails, permanently losing
a dependency Lake cannot get back. Failing loudly here (`comparator_unavailable`, naming the
affected package) before the main run starts is cheaper than losing the dependency mid-run.

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

### `lean4export` Panics on a Challenge-Absent `permitted_axioms` Entry

The `axiom_violation` row above assumes `lean4export` completes normally and Comparator's own
`Axioms.loop` walk reports the illegal axiom as ordinary stderr output. A DIFFERENT failure mode
exists one step earlier: if `permitted_axioms` names an axiom that is absent from the Challenge
side's environment entirely (as opposed to present-but-outside-the-whitelist), `lean4export`
itself panics while exporting the Challenge side -- `Constant ... not found in environment`, exit
134 (SIGABRT) -- rather than Comparator ever reaching its own axiom-closure check. This is a
`lean4export` crash, not a `comparator_unavailable` or `axiom_violation` verdict from this
wrapper's own classification arms, since the crash happens inside Comparator's own build/export
pipeline before Comparator's stdout/stderr carries any of the strings `classify_verdict()`
matches on.

**The working handling**: permit only the TRUSTED axioms in `permitted_axioms` (never a
speculative superset naming an axiom that might not exist in the Challenge environment), and
treat the exact `Illegal axiom detected: '<helper-axiom-name>'` rejection as that configuration's
EXPECTED PASS rather than a failure to fix. This still proves the Challenge and Solution
statements match (Comparator checks statement equality before it ever reaches axiom-closure
checking), even though it does not additionally prove kernel acceptance for that specific
configuration -- the two guarantees are separable, and a statement-match-only result is still
useful evidence, correctly labeled as such rather than silently upgraded to a full `verified`.

### `lake update --keep-toolchain` Pitfall

In a package that pins a specific tool version (the C3 version-coupling concern this integration
already tracks for `lean4export`), a plain `lake update` silently REWRITES `lean-toolchain` to
whatever newer toolchain the updated tool itself declares -- there is no warning, and every later
build in that package then silently targets the wrong Lean version. The defense is twofold: pass
`--keep-toolchain` to every `lake update` invocation in a tool-pinning package, and, as a
belt-and-suspenders coherence check, compare `lean-toolchain` files across the package and its
pinned tool, and grep each built binary's own `lean --githash` against the target project's
expected commit.

### Batched Lean4Lean/leanchecker Runs Can Exhaust Memory

Not applicable to this runner's own single in-process Comparator invocation (which this
integration does not change), but load-bearing for any FUTURE kernel-replay sibling script that
might batch multiple modules through Lean4Lean or `leanchecker` in one process: a batched
whole-package run reached 19 GB RSS and was killed by `earlyoom`, which ALSO SIGTERM'd an
unrelated concurrent `lean` process on the same host -- a batched run's memory pressure is not
contained to itself. The defense is running one module per process, never batching a
whole-package kernel replay into a single long-lived process.

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

## Binary Provisioning Status (as measured 2026-09-07, mid-implementation)

At the start of this integration's implementation, `landrun`, `lean4export`, `nanoda_bin`, and
`comparator` were ALL absent on this host. By the time the regression suite and acceptance
evidence were assembled (same day), real `comparator` (nix store path confirms build commit
`2312244a`, matching this integration's vendored fixtures) and real `landrun` (v0.1.17) had
become available via the user's home-manager profile -- the sibling `~/.dotfiles/` provisioning
task appears to have partially landed. `lean4export` and `nanoda_bin` remain absent.

**Diagnosed root cause (supersedes the "Comparator's own internal concern" framing below this
paragraph carried until this integration's NixOS-host fixes landed)**: invoking the real
`comparator` binary directly against the vendored `simple_match` fixture (bypassing this runner)
failed with `error: command failed: 'lake' / Permission denied (os error 13)` before ever
reaching the lean4export-dependent export step. This is NOT a missing grant in Comparator's own
`Main.lean` -- it is a bare `PATH` lookup inside the sandbox resolving the top-level elan
dispatcher shim (a shell script, `~/.elan/bin/lake` or the nixpkgs-elan equivalent), which landrun
denies executing: a shell script has no ELF interpreter of its own for landrun's `-ldd` grant
discovery to find, so the exec of the wrapper itself is denied before Lake ever starts. The fix
is PATH ordering, not a wider sandbox grant: put the pinned toolchain's own `bin/` directory
(resolved via `lean --print-prefix` inside the checking environment, never the caller's ambient
toolchain) first on the `PATH` handed into the sandbox. On THIS host, the toolchain's own `lake`
is itself a nixpkgs-elan wrapper script (renamed to `lake.orig`, with `lake` a bash wrapper that
runs `dirname` and execs `lake.orig` with `LEAN_CC` preset) -- the same problem one level deeper
-- so the fix additionally unwraps to a private directory (outside every sandboxed room, so
nothing confined can write to it) holding one symlink to the real `lake.orig` binary, placed
first on PATH ahead of the toolchain's own (still-wrapped) `bin/`.

**The fixes are ordered, not independent.** `lake env comparator config.json` (the invocation
form itself) needs no code change -- `run_sandboxed()`'s guard and fallback branches already
produce that exact command line. What was missing is the diagnosis that this invocation only
ever reaches a WORKING `lake` once the PATH-ordering fix above lands; without it, `lake env`
itself fails at the same `lake: Permission denied` step, regardless of which command line invokes
it. This is a SEPARATE blocker from `lean4export`'s absence -- provisioning `lean4export` alone
would not resolve it. `lean4export`/`nanoda_bin` provisioning remains tracked by the sibling
`~/.dotfiles/` effort; the PATH-ordering/unwrap/landrun-shim/pre-flight fixes below are this
integration's own scope and require no external provisioning.

### The Landrun-Shim Mechanism (Fixes 3+4)

Comparator builds its OWN internal `landrun` argument vector for its internal `lake build` call
and exposes exactly one injection point into it: the `COMPARATOR_LANDRUN` env var, which
Comparator execs in place of a bare `landrun` PATH lookup. `lean-comparator-run.sh` therefore
points `COMPARATOR_LANDRUN` at
`agent-system/extensions/lean/scripts/lean-comparator-landrun-shim.sh`, never at the real
`landrun` binary directly -- the shim execs the real `landrun` (resolved separately and forwarded
via `LEAN_COMPARATOR_RUN_REAL_LANDRUN`) with Comparator's own arguments unchanged and in order,
plus the extra grants Comparator's own internal sandbox omits but this NixOS host's build needs:

- **`TMPDIR` inside `.lake`**: `bv_decide` writes SAT files to `/tmp`, which the outer sandbox
  (this runner's own landrun layer, see below) makes read-only. The shim points `TMPDIR` at
  `$PWD/.lake/tmp` instead -- a directory the outer sandbox already grants read-write on, so this
  introduces no NEW write access, only a redirection of where a write Comparator's internal build
  already needs lands.
- **git shared-library `--rox` grants**: Comparator's sandbox grants execute on the `git` binary
  itself but not on its `ldd`-reported shared-library closure, so `git` cannot actually run inside
  the sandbox without them. This matters because Lake treats a linked dependency package whose
  remote `git` cannot read as MOVED and deletes `.lake/packages/<dep>` to re-clone it -- inside a
  sandbox that denies network access, that re-clone then also fails, permanently losing the
  dependency. See the pre-flight probe below, which catches this before it happens.
- **ELF-interpreter `--rox` grant**: on NixOS, the pinned toolchain's `lake` (or, post-unwrap,
  `lake.orig`) requests `nix-ld` as its ELF interpreter, which landrun's own `-ldd` grant
  auto-discovery does not find (it walks `lake`'s `DT_NEEDED` shared libraries, not its
  interpreter). Without this grant the exec of `lake` itself is denied before Lake starts, the
  same class of failure as the elan-wrapper problem above but one layer further in. Guarded on
  `readelf` being present -- its absence only skips this one grant, never a hard failure.

`COMPARATOR_LANDRUN` is therefore the ONLY injection point into Comparator's own internal
sandbox argv; there is no way to add these grants except by wrapping whatever binary
`COMPARATOR_LANDRUN` resolves to.

**Demonstrated for real regardless**: this runner's `comparator_unavailable` verdict was
exercised against the genuinely-missing `lean4export` binary using the actual, unmodified runner
script and the now-present real `comparator`/`landrun` -- verdict `comparator_unavailable`,
message names `lean4export` and `COMPARATOR_LEAN4EXPORT`, exit 69. This is the one acceptance
demonstration in this integration's acceptance criteria achievable against fully real binaries on
this host today.

## References

- Upstream: https://github.com/leanprover/comparator (Apache-2.0, default branch `master`, as
  measured 2026-08-30/2026-09-07).
- `agent-system/extensions/core/scripts/lake-build-guard.sh` -- the shared build-serialisation
  guard reused (never modified) by this integration.
- `agent-system/extensions/lean/scripts/lean-sorry-census.sh` -- the sibling script whose
  dirname-relative-sibling-with-env-override guard-resolution pattern this runner generalises
  from one binary to four.
- `agent-system/extensions/lean/scripts/lean-comparator-landrun-shim.sh` -- the landrun shim
  carrying the TMPDIR/git-library/ELF-interpreter grants documented above.
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` -- Final Verification Stage,
  the four text-heuristic gates Comparator's guarantees are relative to.
- `agent-system/extensions/lean/context/project/lean4/standards/proof-debt-policy.md` -- the
  zero-debt completion policy this integration is the eventual terminal gate for.
- A sibling repository's `framed_channel/scripts/recheck-comparator.sh`,
  `framed_channel/scripts/comparator-configs.sh`, `framed_channel/scripts/lib/recheck-revs.sh`,
  and `framed_channel/recheck/landrun-shim.sh` -- the reference implementation this integration's
  NixOS-host fixes (PATH ordering, elan-wrapper unwrapping, the landrun shim, the outer landrun
  layer, and the git-remote pre-flight probe) transcribe from, re-read live at implementation
  time rather than trusted from any prior written description.
