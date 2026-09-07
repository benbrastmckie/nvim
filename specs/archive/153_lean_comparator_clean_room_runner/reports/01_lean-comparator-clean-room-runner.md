# Research Report: Task #153

**Task**: 153 - lean_comparator_clean_room_runner
**Started**: 2026-09-07T15:00:00Z
**Completed**: 2026-09-07T15:46:00Z
**Effort**: research
**Dependencies**: None (upstream provisioning of landrun/lean4export/comparator binaries tracked in a sibling ~/.dotfiles/ task, outside this repo)
**Sources/Inputs**: - Codebase (agent-system/extensions/lean/**, agent-system/extensions/core/scripts/lake-build-guard.sh), upstream `leanprover/comparator` repo cloned via `gh repo clone` (README.md, Main.lean, Comparator/{Axioms,Compare,Util}.lean, runtests.lean, scripts/fake-landrun.sh, tests/projects/*)
**Artifacts**: - This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The upstream `leanprover/comparator` README (cloned and read in full) gives the exact
  invocation form, the six numbered guarantees, the config.json schema, and the definition-hole
  gaming example verbatim — the dispatch's background section is a faithful paraphrase, and the
  planner should cite the README directly rather than re-derive any of this.
- Comparator's own Lean source (`Comparator/Compare.lean`, `Comparator/Axioms.lean`) exposes the
  exact `throw`/`IO.userError` message strings the wrapper must pattern-match on stderr to
  classify a failure into the dispatch's named verdict buckets (statement_mismatch vs
  axiom_violation vs kernel_rejected). These strings are recorded verbatim below — this is the
  single most load-bearing finding for phase (e) VERDICT.
- **Novel correctness risk found, not in the dispatch background**: `lake-build-guard.sh`'s
  result-sharing (REPLAY) mechanism keys on a `scope_key` hashed from the **lake argument
  vector only** (`env <comparator-binary> <config.json>` — the config.json *path*, not its
  *content*) plus a tree fingerprint that covers `*.lean`/lakefile/lean-toolchain but NOT
  `config.json`. Two Comparator runs against the same Challenge/Solution files but a
  **different `config.json` body at the same path** (e.g. a tightened `permitted_axioms` list,
  or a different `theorem_names` selection) are indistinguishable to the guard and a stale
  REPLAY would silently hand back the wrong verdict. `--no-share` on the guard invocation is
  therefore not merely a performance nicety here — it is a correctness requirement for this
  call site specifically, unlike `lean-sorry-census.sh`'s cross-check use of the guard.
- Comparator's own `tests/projects/` fixture tree (14 named fixtures, Apache-2.0, catalogued in
  full below) does not contain a fixture that isolates a pure same-kind statement weakening
  (all of `simple_mismatch`/`simple_axiom_issue`/`simple_kind_mismatch` conflate a
  theorem-vs-axiom **kind** mismatch with the statement difference). A clean
  `statement_mismatch` acceptance demo needs one small custom fixture (same declaration kind,
  weakened/different statement) rather than reuse of `simple_mismatch` verbatim.
  `def_hole_axiom_issue`, by contrast, is an excellent ready-made fixture for the
  transitively-hidden-axiom acceptance criterion and should be reused as-is.
- Recommended clean-room approach (evaluated with reasoning, not left implicit): the
  README's own blessed route — fresh clone/worktree + `lake exe cache get` (or a locally
  cached `.lake`) trusted only insofar as its provenance is a build the operator performed
  from the SAME commit before ever touching the untrusted Solution — over an ad hoc scratch
  copy. Reasoning and caveats below in Findings > Clean-Room Decision.

## Context & Scope

Researched the design space for `agent-system/extensions/lean/scripts/lean-comparator-run.sh`,
a wrapper CLI around the upstream `leanprover/comparator` tool that will let
`lean-implementation-agent`'s Final Verification Stage (currently four grep-based heuristics)
call out to a kernel-backed, sandboxed judge for named theorems. This is research only — no
code was written. Scope covers: the four constraints named in the dispatch (C1 no-challenge,
C2 clean-room, C3 version coupling, C4 cost), the exact invocation/config contract, the
`lake-build-guard.sh` integration contract, and the test-fixture landscape to reuse.

## Findings

### Codebase Patterns

**`lake-build-guard.sh` contract** (`agent-system/extensions/core/scripts/lake-build-guard.sh`,
906 lines, read in full):
- Three subcommands: `status` (exit 0 clear / 10 in-flight), `preflight` (memory-pressure
  probe, exit 0/11), `build` (the guarded wrapper, exit codes 75–79 reserved for guard-specific
  failures, otherwise passes through the wrapped `lake` command's own exit code).
- `build` mode validates `lake_args[0]` against a hardcoded subcommand allowlist
  (`LAKE_SUBCOMMANDS`) BEFORE dispatch; `env` **is** on that allowlist, so
  `lake-build-guard.sh build -- env <comparator-binary> <config.json>` is a legal invocation
  shape — the guard does not know or care that the wrapped `lake env` call happens to run
  Comparator rather than a bare project executable.
- Locking is per-project (`<project-root>/.lake/build-guard.lock`), resolved by walking up from
  `--dir` (default `$PWD`) to the nearest `lakefile.lean`/`lakefile.toml`. This is exactly the
  granularity the dispatch's cost-control point (d) wants: a Comparator run and an ordinary
  `lean-implementation-agent` build of the SAME project contend for the SAME lock.
  `LAKE_BUILD_GUARD_LAKE_BIN` is a test seam; production resolution is via `PATH`.
- Result-sharing (REPLAY) requires: `state=complete`, matching post-build fingerprint, matching
  `scope_key` (hash of the argument vector — **not** of any file content named as an argument),
  age under 900s default, and `--no-share` not passed. See Executive Summary for why this is a
  correctness hazard, not just a caching nicety, for a Comparator call site specifically:
  `config.json`'s path is a constant argument across differently-configured runs, and
  `config.json` itself is excluded from `collect_fingerprint_files()` (which only walks
  `*.lean` plus `lakefile.lean`/`lakefile.toml`/`lake-manifest.json`/`lean-toolchain`).
  **Recommendation for the plan**: the runner must always pass `--no-share` to the guard, or
  else fold a hash of `config.json`'s content into the invocation's argv (e.g. as a synthetic
  trailing argument) so the scope_key changes with the config. `--no-share` is the simpler,
  safer default given Comparator runs are infrequent/opt-in per constraint C4 anyway — the
  performance case for sharing barely exists here.
  - `--memory-bound` on the guard uses its own `systemd-run --user --scope ...` wrapper. The
    README's mandated wrapper is a *different* `systemd-run --property=RestrictAddressFamilies=
    ~AF_UNIX --user --pty ...` invocation serving a different purpose (landrun-escape
    mitigation, not memory bounding). These compose by nesting (outer = README's mandatory
    wrapper, inner = `lake-build-guard.sh build -- env ...` invoked via `bash -c`), and the
    plan should NOT pass `--memory-bound` to the inner guard call — there is no stated need for
    it here, and stacking two `systemd-run --user` scopes adds complexity with no named benefit.
- `have_systemd_run()` in the guard probes with one real invocation
  (`systemd-run --user --scope --quiet --collect -- true`), not just `command -v`, because
  presence of the binary does not imply user-scope cgroup delegation — this same probe pattern
  is directly reusable for the runner's own "is systemd-run actually usable here" check before
  attempting the README's mandatory wrapper.
- Degrade-loudly convention: every missing capability (`flock`, `systemd-run`, `lake`) produces
  a visible `lake-build-guard: ...` stderr line and a fallback, never silent skip. The dispatch's
  `comparator_unavailable` verdict requirement is the same discipline applied to Comparator's own
  three external binaries.

**`lean-sorry-census.sh` conventions** (`agent-system/extensions/lean/scripts/`, 235 lines):
- Guard integration precedent to copy: resolve the guard binary via an overridable env var
  defaulting to a `dirname`-relative sibling path (`LEAN_SORRY_CENSUS_GUARD_BIN` ->
  `$(dirname "${BASH_SOURCE[0]}")/lake-build-guard.sh`), because the two scripts ship from
  different source-store extensions (`lean/` vs `core/`) but land as literal siblings only
  post-deploy in `.claude/scripts/`. The new runner needs the identical pattern (call it
  `LEAN_COMPARATOR_RUN_GUARD_BIN` or similar) and MUST NOT assume the guard is deployed
  (degrade to an ungated invocation with a loud warning, matching the census script's
  three-way branch: guard present / guard absent+lake present / lake absent).
  - **Correction to the sibling script's own precedent**: `lean-sorry-census.sh`'s guard call
    passes no `--no-share`, which is fine there because its wrapped command is always the same
    bare `build` with nothing but the project tree determining output. The new runner must NOT
    copy that omission — see the scope_key/config.json hazard above.
- `COMPARATOR_LANDRUN`/`COMPARATOR_LEAN4EXPORT`/`COMPARATOR_NANODA` are Comparator's OWN env-var
  override names (from its README), not something this repo invents — the dispatch's (b) naming
  them is just carrying the upstream contract through.
- Exit-code convention: 64 for usage errors (`lean-sorry-census.sh`), 75-79 reserved band for
  `lake-build-guard.sh`. The new runner should pick its own non-overlapping band for its
  verdict-category exit codes (see Decisions below) rather than colliding with either.

**`lean-implementation-agent.md` Final Verification Stage** (read in full, lines ~225-330):
  confirms the dispatch's framing exactly — step 1 sorry census, step 2 single-line vacuous-def
  grep (explicitly flagged in-file as not covering multi-line cases), step 3 `grep "^axiom "`
  (a single textual form), step 4 `lake build` via the guard (elaboration only, unsandboxed,
  and does not replay into the kernel), step 5 a plan-compliance name-existence grep. All five
  gaps the dispatch calls out are visible directly in this file's own committed script blocks,
  not inferred.

**`proof-debt-policy.md`** (`agent-system/extensions/lean/context/project/lean4/standards/`):
  zero-debt completion gate (zero sorries, no new axioms, build passes) is enforced today by
  exactly the greps Comparator's steps 3-4-5 would strengthen. Confirms the dispatch's framing
  that Comparator is the natural terminal gate for this policy — but per the dispatch's
  **binding, already-made GATE STRENGTH DECISION**, this task must NOT wire Comparator as a
  hard gate; that promotion is explicitly deferred to a separate future decision.

**`plan-format.md`** (`agent-system/extensions/core/context/formats/`): confirms C1 precisely —
  `## Goals & Non-Goals` is bullets naming goal identifiers (backtick-quoted names, per the
  Final Verification Stage's own `grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`'` extraction), never
  full theorem statements. There is no existing plan-format field that could carry a trusted
  Challenge statement. Whatever produces the Challenge.lean file(s) for a Comparator run is
  necessarily a NEW artifact this task's later phases (or a sibling task) must define — this
  script's own scope is just the runner given a Challenge/Solution/config already materialized;
  it does not itself solve C1's "who writes Challenge.lean" question, and should not try to.

**`shell-script-testing.md`** (`agent-system/extensions/core/context/standards/`): location
  rule is scope-based — a narrow single-script suite belongs at
  `scripts/tests/test-<script-under-test>.sh`, matching the dispatch's named test path
  `scripts/tests/test-lean-comparator-run.sh`. Helper-naming convention (`pass()`/`fail()`/
  `info()`, `PASSED`/`FAILED` counters, `mktemp -d` + `trap EXIT` cleanup, exit 0/1) is already
  followed by both `test-lean-sorry-census.sh` and core's own suites — the new test should match
  it. `test-lean-sorry-census.sh`'s own header additionally documents an anti-vacuous-test
  discipline (assert the tool's output actually differs from a naive/degraded implementation on
  the same fixture) worth carrying into the new suite's guard-routing and fake-landrun fixtures.

**Extension wiring**: `agent-system/extensions/lean/manifest.json`'s `provides.scripts` array
  currently lists only `lean-sorry-census.sh` and its test. The new script and test will need
  entries added here at implementation time (not research/this task's job to edit, but the
  planner should include it as an explicit phase step — a script left off this list is not
  deployed to `.claude/scripts/` and therefore invisible to the agent).

### External Resources

**Upstream `leanprover/comparator`** (Apache-2.0, cloned via `gh repo clone leanprover/comparator`
into the scratchpad and read in full — README.md, `Main.lean`, `Comparator/{Axioms,Compare,
Util}.lean`, `runtests.lean`, `scripts/fake-landrun.sh`, `lakefile.toml`, `lean-toolchain`,
and all 20 `tests/projects/*` fixture pairs):

- **Exact invocation shape** (confirmed against `runtests.lean`'s own test harness, not just the
  README prose): from a directory containing `Challenge.lean`, `Solution.lean`, `config.json`,
  a `lakefile.toml` declaring both as `lean_lib` targets, and a copied `lean-toolchain`, the
  command is `lake env <path-to-comparator-binary> config.json`. `runtests.lean` builds the
  default lakefile it generates itself:
  ```toml
  name = "comparatortest"
  version = "0.1.0"
  [[lean_lib]]
  name = "Solution"
  [[lean_lib]]
  name = "Challenge"
  ```
  This is the exact synthesized-lakefile shape phase (c) CONFIG SYNTHESIS should reuse when the
  target project doesn't already define `Challenge`/`Solution` as lake_lib targets.

- **Config schema** (from `Main.lean`'s `structure Config`, which has `deriving
  Lean.FromJson`): `challenge_module: String`, `solution_module: String`,
  `theorem_names: Array String`, `definition_names: Option (Array String)` (defaults empty),
  `permitted_axioms: Array String`, `enable_nanoda?: Option Bool`,
  `external_kernels?: Option (Std.TreeMap String (Array String))`. `enable_nanoda: true` and a
  non-empty `external_kernels` are mutually exclusive (Comparator throws if both are set).

- **Env var resolution order** (from `M.run` in `Main.lean`): `COMPARATOR_LEAN4EXPORT` overrides
  a bare `lean4export` PATH lookup; `COMPARATOR_LANDRUN` overrides `landrun`; `COMPARATOR_NANODA`
  overrides the external-kernel command's `[0]` element specifically when that kernel's name
  contains `"noda"` (a documented-as-temporary heuristic), or supplies `nanoda_bin` when
  `enable_nanoda: true` and no explicit external kernel list is given. This exactly matches
  dispatch item (b)'s three override vars.

- **The six numbered guarantees and their six preconditions** (README, quoted structurally in
  the dispatch, verified verbatim in the clone): precondition 2 is the clean-room requirement
  (C2); the blessed mitigation — "if you have obtained a fully pre-built `.lake` directory
  through other means and without compromising your checking environment, `Solution.lean` will
  not be rebuilt" — is stated as its own paragraph, separate from the six preconditions, and is
  the basis for the Clean-Room Decision below. The README separately blesses
  `lake exe cache get` as an acceptable pre-step "if you trust the cache to not be modified as
  to, e.g. contain different definitions from the one you would expect" — this is the exact
  "trust" framing the dispatch's (a) asks to be stated explicitly, not assumed.

- **Verdict message strings** (from `Comparator/Compare.lean` and `Comparator/Axioms.lean`,
  read in full — this is the concrete mechanism for phase (e) VERDICT classification):
  - Statement mismatch: `"Challenge and solution theorem statement do not match: '<name>'"`
    (thrown in `compareAt` when both sides are `.thmInfo`/`.axiomInfo` of the same kind but the
    `ConstantVal` differs) — this is the clean same-kind case.
  - Declaration-kind mismatch: `"Challenge and solution constant kind don't match: '<name>'"`
    (thrown when one side is a theorem and the other an axiom, etc.) — a DIFFERENT message from
    the statement-mismatch one; the dispatch's `statement_mismatch` bucket should probably
    absorb this too (both are "the Solution didn't prove what Challenge asked"), but the
    plan/implementation phase should decide explicitly whether to fold it in or keep it
    separate, since it is textually distinguishable.
  - Definition-hole mismatch: `"Const does not match between challenge and target '<name>'"`
    (thrown both for a definition-hole ConstantVal/safety mismatch in `compareAt`, and — via a
    different call site — for a transitive-closure walk mismatch in `Compare.loop`; the SAME
    string covers two different code paths, so pattern-matching this string alone cannot
    distinguish "the hole itself doesn't match" from "something the hole/theorem transitively
    depends on doesn't match").
  - Missing-constant setup errors: `"Const not found in challenge: '<name>'"` /
    `"Const not found in solution: '<name>'"` — occurs when `theorem_names`/`definition_names`
    in `config.json` names something absent from one side (a config/authoring error, not really
    a security verdict). The dispatch's seven named categories have no explicit slot for this;
    flagging as an open question for the plan (candidates: fold into `statement_mismatch`,
    or add an eighth `config_error` category).
  - Axiom violation: `"Illegal axiom detected: '<name>'"` (thrown in `Axioms.loop`, walking the
    full transitive closure of used constants from every theorem/definition target — this is
    exactly the TRANSITIVE check the dispatch's acceptance criteria requires, confirmed by
    reading the traversal code, not just the README's prose claim).
  - Kernel rejection (builtin): stdout line `"Lean default kernel rejects the solution"` is
    printed unconditionally BEFORE the exception propagates; the thrown message itself is
    `e.toString` of whatever the Lean kernel's own replay exception says (not a fixed string —
    the wrapper should match on the stdout marker line, not the exception text, for this
    category).
  - Kernel rejection (external, e.g. nanoda): stdout line `"<kernelName> kernel rejected the
    solution"`, thrown message `"<kernelName> exited with <code>"`.
  - Success: stdout line `"Your solution is okay!"` printed only at the very end of
    `compareIt`, after both sandboxed builds, both exports, `verifyMatch` (statement + axiom
    checks), and the kernel replay all succeed. This is the single authoritative "verified"
    signal; exit code 0 alone is necessary but the stdout line is the stronger positive check
    (an exit-0 with early-return semantics anywhere in the pipeline would be a Comparator bug,
    but matching the final line costs nothing and is worth doing defensively).
  - **All failure paths surface as an uncaught `IO.userError`, which Lean's runtime reports to
    stderr as `uncaught exception: <message>` with process exit code 1** — confirmed against
    every `test.json` in the fixture tree, which uniformly expects `exit_code: 1` for every
    failure category and `exit_code: 0` only for a true pass. This means **Comparator itself
    exposes only a binary exit code**; ALL of the finer-grained verdict categories the dispatch
    requires (statement_mismatch vs axiom_violation vs kernel_rejected vs definition_hole) must
    be recovered by the wrapper via **stderr message-string matching**, not from any structured
    exit-code contract Comparator provides. This is the single most important design fact for
    phase (e): there is no JSON/structured output from Comparator to parse; the runner owns 100%
    of the classification logic against captured stderr/stdout text.

- **`scripts/fake-landrun.sh`** (read in full, ~45 lines): an argument-swallowing shim that
  execs its trailing command unsandboxed after discarding recognized landrun flags
  (`--ro`/`--rox`/`--rw`/`--rwx`/`--bind-tcp`/`--connect-tcp`/`--log-level`/`--env` as
  value-taking, everything else single-token), printing a loud
  `"WARNING: THIS IS NOT REAL LANDRUN! UNSAFELY RUNNING exec $*"` to stderr before exec-ing.
  Exactly the shape needed for `test-lean-comparator-run.sh`'s `COMPARATOR_LANDRUN` override in
  a dev/CI environment lacking real `landrun` — reuse verbatim (it's a tiny, generically useful,
  Apache-2.0 file; copying it into `agent-system/extensions/lean/scripts/tests/fixtures/` or
  similar, with attribution, is simpler than reimplementing it).

- **`tests/projects/` fixture catalogue** (all 20 directories enumerated and every
  Challenge.lean/Solution.lean/config.json/test.json read): each fixture is a directory with
  `Challenge.lean`, `Solution.lean`, `config.json` (the Comparator config), and `test.json`
  (`{"exit_code": N}`, the upstream test runner's own expected-exit-code oracle format — a
  precedent the new `test-lean-comparator-run.sh` can borrow directly for its own fixture
  oracle, if it wants a data-driven table rather than one function per case). Categorized by
  what each demonstrates:
  - **Pass (`exit_code: 0`)**: `simple_match`, `simple_nanoda`, `simple_multi_nanoda`,
    `simple_nanoda_compat`, `def_hole`, `numeric_namespace`, `theorem_hole_issue`.
  - **Kind/statement mismatch (`exit_code: 1`)**: `simple_mismatch`, `simple_axiom_issue`,
    `simple_kind_mismatch`, `simple_nanoda_mismatch` — all four conflate a theorem-vs-axiom kind
    mismatch with the statement difference (Solution declares the target as `axiom ... := ...`
    instead of a theorem with a matching statement). **None of the fixtures isolate a pure
    same-kind weakened-statement case** — this is a genuine gap relative to the dispatch's
    acceptance criterion ("a Solution weakened the statement"), and the plan should budget for
    one small custom fixture, e.g.:
    ```lean
    -- Challenge.lean
    theorem comm (n m : Nat) : n + m = m + n := sorry
    -- Solution.lean (same kind, added hypothesis => strictly weaker statement)
    theorem comm (n m : Nat) (h : n = m) : n + m = m + n := by omega
    ```
    which hits `"Challenge and solution theorem statement do not match"` without touching the
    kind-mismatch code path at all.
  - **Definition-hole gaming/mismatch (`exit_code: 1`)**: `def_hole_axiom_issue` (hides
    `sorryAx` inside the hole body behind a term that β-reduces away the hole reference — the
    code comment in the fixture itself explains the exact gaming mechanism; this is the
    dispatch's required TRANSITIVE axiom_violation demonstration, ready-made, no authoring
    needed), `def_hole_kind_mismatch` (hole filled with `axiom` instead of `def`),
    `def_hole_type_mismatch` (hole filled with a different type, `Int` vs `Nat`, even though
    the dependent theorem body is still `sorry`).
  - **Kernel/export-layer attacks (`exit_code: 1`)**: `olean_issue` (unsafe `unsafeCast`-based
    construction), `char_ofnat_issue`, `opaque_value` (an `opaque` value backed by a `False`
    axiom, laundered through to look proved), `primitive_issue` (redefines a kernel-special
    primitive like `Nat.gcd`), `proj_trick` (same structure name, different field layout, "never
    compared" per its own code comment), `quot_mismatch`.
  - License is Apache-2.0 (confirmed via `gh api repos/leanprover/comparator` and the repo's own
    `LICENSE` file) — reuse of specific fixture files with attribution is unproblematic, and the
    dispatch's own instruction to "reuse that shape rather than inventing fixtures" is
    well-founded: most of the coverage the acceptance criteria ask for already exists upstream
    and only the pure-statement-weakening case needs a new fixture.

- **Version/toolchain facts** (from the clone's own `lean-toolchain` and `lakefile.toml`):
  Comparator's own toolchain is `leanprover/lean4:v4.34.0-rc2` (matches the dispatch's stated
  fact) and its `lakefile.toml` requires `lean4export` at `rev = "master"` from the `leanprover`
  scope — i.e., Comparator's own build pulls whatever `lean4export` `master` currently is,
  built against Comparator's OWN toolchain. This directly substantiates C3: a `lean4export`
  binary built as part of Comparator's own `lake build` is compiled against v4.34.0-rc2 and is
  NOT guaranteed compatible with export from a DIFFERENT target project on a different Lean
  version. The runner's `COMPARATOR_LEAN4EXPORT` resolution must therefore default to a
  version resolved against the TARGET PROJECT's own `lean-toolchain` (a separate `lean4export`
  build the target project's own lake workspace would need to produce, or a version-matched
  binary supplied out of band) rather than any `lean4export` binary that ships bundled with a
  Comparator checkout.

### Recommendations

1. **Clean-Room Decision (phase a)**: recommend the README's blessed
   clone-plus-pre-built-`.lake` route over an ad hoc scratch copy, with the trust chain stated
   explicitly as: (i) a fresh `git worktree add` (or clone) of the target project at the exact
   commit the operator intends to check, taken BEFORE the runner is ever invoked with an
   untrusted Solution — this satisfies precondition 1 (imports/lakefile controlled/trusted) and
   precondition 2 (no prior Solution compile in this checkout) simultaneously by construction;
   (ii) `.lake/` populated via `lake exe cache get` run in that SAME fresh worktree before the
   Solution file is ever written into it — "trusted" here means specifically: the cache is
   Mathlib's (or the project's) own published build artifacts, fetched over the project's
   normal cache-server pipeline, under the same trust assumption the operator already extends
   to every ordinary `lake build` of that project; this is NOT a stronger trust boundary than
   the project's existing supply chain, which the README explicitly acknowledges as the
   accepted risk ("if you trust the cache to not be modified..."). A plain scratch copy without
   `lake exe cache get` would force a full Mathlib-dependent rebuild from source inside the
   sandbox on every run, which is both far more expensive (compounding C4) and does not, by
   itself, better satisfy precondition 2 than the cache route does — so scratch-copy-without-
   cache has no advantage and a large cost disadvantage. Worktree over `git clone --depth 1`:
   a worktree shares the object store with the main checkout (cheap, fast to create/discard per
   run) while still giving an isolated working directory and `.lake/`.
2. Runner invocation nests the README's mandatory `systemd-run --property=
   RestrictAddressFamilies=~AF_UNIX --user --pty -E PATH="$PATH" --working-directory $(pwd) --
   bash -c '...'` wrapper AROUND `lake-build-guard.sh build -- env <comparator> <config.json>`
   (not the reverse), with `--no-share` always passed to the guard invocation for the
   scope_key/config.json-content reason above, and no `--memory-bound`.
3. `COMPARATOR_LANDRUN`/`COMPARATOR_LEAN4EXPORT`/`COMPARATOR_NANODA` resolve via the same
   dirname-relative-sibling-with-env-override pattern `lean-sorry-census.sh` already uses for
   the guard binary, generalized to three binaries instead of one; a missing binary produces
   `comparator_unavailable` naming both the binary and its override var, per the dispatch.
4. Verdict classification is stderr/stdout substring matching against the exact strings
   catalogued above, in priority order (check the more specific "Illegal axiom detected" /
   kernel-rejection stdout markers before falling back to a generic "some IO.userError fired"
   catch-all), since Comparator itself provides no structured output.
5. `definition_hole_needs_human` should be a WRAPPER-ADDED annotation on an otherwise-`verified`
   result whenever `config.json`'s `definition_names` is non-empty, not a distinct Comparator
   failure mode — Comparator returning exit 0 on a definition-hole config still requires the
   README's mandated additional human/automated review per its own gaming example; the plan
   should decide whether this is a modifier field alongside `verified` or a verdict value that
   replaces it (recommend: modifier field, since the underlying kernel/statement/axiom
   guarantees ARE still meaningful and shouldn't be hidden behind a different top-level verdict
   name).

## Decisions

- Recommend nesting order: README's `systemd-run` security wrapper is OUTER,
  `lake-build-guard.sh build -- env ...` is INNER — not the reverse, and not a flat
  `lake-build-guard.sh --memory-bound` in place of the README wrapper (they serve different,
  non-substitutable purposes: security-boundary vs concurrency/memory).
- Recommend `--no-share` always passed to the inner guard invocation (correctness requirement,
  not a performance choice) given the scope_key/config.json-content gap found above.
- Recommend clean-room = fresh worktree + `lake exe cache get`, not a scratch copy without a
  prebuilt `.lake` — stated with its trust chain, per phase (a)'s explicit requirement.
- Recommend the transitively-hidden-axiom acceptance demo reuse `def_hole_axiom_issue` verbatim
  (Apache-2.0, attributed) rather than authoring a new fixture; recommend one new custom
  fixture for the pure statement-weakening `statement_mismatch` demo, since no upstream fixture
  isolates that case cleanly.
- Left open for the plan phase (not resolved here): whether `"Challenge and solution constant
  kind don't match"` folds into `statement_mismatch` or gets its own bucket, and whether the
  `"Const not found in challenge/solution"` setup-error case gets an eighth verdict category or
  folds into `statement_mismatch` as well.

## Risks & Mitigations

- **Risk**: silently reusing a stale Comparator verdict via `lake-build-guard.sh`'s REPLAY path
  when only `config.json`'s content (not the argv or the fingerprinted tree) changed between
  runs. **Mitigation**: always pass `--no-share`, documented above.
- **Risk**: a `lean4export` binary resolved from a Comparator checkout's own build (toolchain
  v4.34.0-rc2) silently succeeding or silently mis-exporting against a different target
  project's Lean version, producing a false verdict rather than a loud failure. **Mitigation**:
  runner should not default `COMPARATOR_LEAN4EXPORT` to any path under a Comparator checkout;
  require it resolved via PATH or the explicit override, and the plan should consider an
  explicit version-compatibility sanity check (e.g. comparing `lean --version` inside the
  target project against whatever `lean4export --version`, if it has one, reports) as a
  hardening follow-up, though this is not requested by the dispatch's acceptance criteria and
  should not block phase 1.
- **Risk**: cost blowup from running Comparator on every implementation iteration rather than
  opt-in at final verification. **Mitigation**: constraint C4 and the dispatch's ADVISORY-ONLY
  gate strength decision already scope this out of the current task — the runner is a standalone
  script, not wired into the implementation agent's per-iteration loop, and that wiring is
  explicitly a separate, later, harder decision.
- **Risk**: this task's own test suite cannot exercise a REAL comparator+lean4export+landrun
  end-to-end pass/fail on this machine today (all three binaries confirmed missing per the
  dispatch's environment section, and provisioning is a sibling ~/.dotfiles/ task not yet
  landed). **Mitigation**: the dispatch already anticipates this — test what can be tested with
  `fake-landrun.sh` substituted for `landrun` (this does NOT stub `comparator` or `lean4export`
  themselves, so a full `test-lean-comparator-run.sh` run still needs those two built locally;
  if that build is itself infeasible in the implementation phase's environment/time budget,
  the implementation agent should report exactly which acceptance criteria are deferred to the
  sibling task's landing, rather than claiming a pass it cannot support — this report flags the
  risk now so the plan phase can decide whether to budget time for building `comparator` +
  `lean4export` locally (feasible in principle: `lake`/`lean`/`elan` are present, and neither
  depends on Mathlib) as an explicit phase step, versus deferring end-to-end acceptance
  entirely).

## Context Extension Recommendations

- **Topic**: Comparator integration (this whole subsystem).
- **Gap**: no existing file under `agent-system/extensions/lean/context/` mentions Comparator at
  all (confirmed via `index-entries.json` and a repo-wide grep) — this is entirely new domain
  knowledge for the extension.
- **Recommendation**: once the runner lands, add a
  `agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md` (or
  similar) capturing the invocation contract, the verdict-string table from this report, the
  clean-room trust chain, and the version-coupling caveat, so a future maintainer (or the
  eventual hard-gate promotion task) does not have to re-clone and re-read the upstream repo
  from scratch. Not created in this research pass — deferred to the implementation phase per
  the standard "don't write context docs during research" discipline, but flagged here since
  the gap is unusually complete (zero prior coverage).

## Appendix

- Search queries / commands used: `gh api repos/leanprover/comparator`,
  `gh repo clone leanprover/comparator` (into the session scratchpad), full reads of the
  clone's `README.md`, `Main.lean`, `Comparator/Compare.lean`, `Comparator/Axioms.lean`,
  `runtests.lean`, `scripts/fake-landrun.sh`, `lakefile.toml`, `lean-toolchain`, and every
  `tests/projects/*/{Challenge.lean,Solution.lean,config.json,test.json}` (20 fixture
  directories); local reads of `agent-system/extensions/core/scripts/lake-build-guard.sh` (full,
  906 lines), `agent-system/extensions/lean/scripts/lean-sorry-census.sh` (full, 235 lines) and
  its test header, `agent-system/extensions/lean/agents/lean-implementation-agent.md`'s Final
  Verification Stage section, `agent-system/extensions/lean/context/project/lean4/standards/
  proof-debt-policy.md`, `agent-system/extensions/core/context/formats/plan-format.md`'s
  Goals & Non-Goals section, `agent-system/extensions/core/context/standards/
  shell-script-testing.md`, and `agent-system/extensions/lean/manifest.json`.
- References: https://github.com/leanprover/comparator (Apache-2.0, default branch `master`,
  last push 2026-08-30, confirmed via `gh api`); https://github.com/Zouuup/landrun (referenced
  by Comparator's README, not independently cloned this pass); https://github.com/leanprover/
  lean4export (referenced by Comparator's README and `lakefile.toml`, not independently cloned
  this pass — its own version-compatibility story with a target project's Lean version was not
  independently verified beyond the dispatch's own C3 framing, since doing so would require a
  target project to test against, which is exactly what this task does not yet have).
