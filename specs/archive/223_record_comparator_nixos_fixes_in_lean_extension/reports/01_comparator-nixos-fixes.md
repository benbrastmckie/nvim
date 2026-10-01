# Research Report: Task #36

**Task**: 36 - Record comparator nixos fixes in lean extension
**Started**: 2026-09-17T07:40:00Z
**Completed**: 2026-09-17T07:49:00Z
**Effort**: small (documentation + script hardening; no new tool provisioning)
**Dependencies**: None
**Sources/Inputs**: - Codebase: `~/.config/nvim/agent-system/extensions/lean/{context/project/lean4/domain/comparator-integration.md, context/project/lean4/tools/comparator-guide.md, scripts/lean-comparator-run.sh, scripts/tests/test-lean-comparator-run.sh}`; `framed_channel/{recheck-comparator.sh, recheck-revs.sh, comparator-configs.sh, recheck/{README.md,landrun-shim.sh}, recheck-kernel.sh}`; `specs/032_independent_certification_comparator_and_kernel_replay/{reports/01_independent-certification-research.md, summaries/01_independent-certification-summary.md}`
**Artifacts**: - specs/036_record_comparator_nixos_fixes_in_lean_extension/reports/01_comparator-nixos-fixes.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The reference implementation (`framed_channel/recheck-comparator.sh` + `recheck-revs.sh` +
  `comparator-configs.sh`, task 32) already demonstrates all four NixOS fixes working for real on
  this host. This task is a **transcription task**: pull the working mechanics out of
  `framed_channel/` and generalize them into the lean extension's already-existing (but
  currently non-working on this host) `lean-comparator-run.sh`, `comparator-integration.md`, and
  `comparator-guide.md`.
- Of the four fixes, **two are entirely missing** from `lean-comparator-run.sh` today (PATH
  ordering, TMPDIR/git-library grants via a `COMPARATOR_LANDRUN` shim), and **two are already
  effectively present** but under-explained (the `lake env` invocation form arrives for free
  through `lake-build-guard.sh`'s subcommand allowlist, and the design record already names the
  `lake: Permission denied` failure but never diagnoses it).
- The lean4export panic on an out-of-Challenge `permitted_axioms` entry, the `lake update
  --keep-toolchain` pitfall, and the batched-Lean4Lean earlyoom incident are **documentation-only**
  additions — they concern callers of this runner (how to construct a flagged-row config, how to
  pin a tools package, how to run kernel replay), not code paths inside
  `lean-comparator-run.sh` itself.
- `test-lean-comparator-run.sh` today stubs `comparator`/`landrun`/`lake` and has **no case at
  all** for PATH-ordering or the landrun-shim mechanism; both fixes need new regression cases
  (stub-based, following the suite's existing house style) rather than a real-binary run, since
  `landrun`, `lean4export`, and `nanoda_bin` remain absent on this host per
  `comparator-integration.md`'s "Binary Provisioning Status" section.

## Context & Scope

Task 36 asks to record, in the lean extension's **source store**
(`~/.config/nvim/agent-system/extensions/lean`, confirmed to be the git-tracked working copy of
`github.com:benbrastmckie/nvim.git` — never `.claude/`, which is a disposable deploy artifact per
`context/patterns/source-store-deploy-boundary.md`), the four Comparator-on-NixOS fixes
discovered while certifying `framed_channel` in task 32, plus four additional documentation-only
findings (lean4export panic, `lake update --keep-toolchain`, batched-Lean4Lean memory blow-up,
outer-landrun hardening). Three files are named as edit targets:

- `context/project/lean4/domain/comparator-integration.md` (the design record)
- `context/project/lean4/tools/comparator-guide.md` (the operator-facing trust-model companion)
- `scripts/lean-comparator-run.sh` (the wrapper CLI), with
  `scripts/tests/test-lean-comparator-run.sh` updated to cover the new behavior

The task also says "so a Comparator run works on this host" and "Redeploy .claude/ afterwards" —
i.e. this is implementation-shaped (code + docs), not research-only, even though it is
`task_type: meta` and routed through the standard research -> plan -> implement lifecycle. This
report is the research phase; it maps every fix to its exact source location, its exact target
location, and what in the target is missing versus already-latent.

Constraints observed: no Comparator/landrun/lean4export/nanoda binaries are installed on this
host except `comparator` and `landrun` (per `comparator-integration.md`'s "Binary Provisioning
Status" section, last measured 2026-09-07) — `lean4export` and `nanoda_bin` remain absent. A full
live acceptance run of `lean-comparator-run.sh` against a real target project is therefore not
achievable end-to-end on this host today; the framed_channel reference scripts prove the fixes
work in principle (they were run for real during task 32, with `lean4export` and `lean4lean`
built locally as a pinned tools package under `framed_channel/recheck/`), and the generalization
work for task 36 should follow that same pattern (a local/pinned or PATH-resolved `lean4export`)
rather than assuming it is pre-installed.

## Findings

### Codebase Patterns

**Fix 1 — PATH ordering (pinned toolchain bin/ before the elan shim).**

- Root cause (from `specs/032.../reports/01_independent-certification-research.md:19-23` and
  confirmed live in `comparator-integration.md:217-226`): `lake` resolved via a bare `PATH` lookup
  inside the sandbox is the **elan shim** on this NixOS/elan host, and `landrun` cannot execute
  it — this is the exact, previously-undiagnosed `lake: Permission denied (os error 13)` failure
  `comparator-integration.md`'s "Binary Provisioning Status" section records but explicitly leaves
  unexplained ("diagnosing the exact grant Comparator's own `Main.lean` would need is Comparator's
  own internal concern, not this wrapper's" — that framing is now supersedable: the grant Comparator
  needs is not the fix; the fix is never handing it the shim at all).
- Reference fix (`framed_channel/recheck-comparator.sh`'s `confined()`, line 184):
  `-E "PATH=$RECHECK_TOOLCHAIN_BIN:$git_dir:$PATH"` — the pinned toolchain's own `bin/` (resolved
  via `lean --print-prefix` in `recheck-revs.sh`'s `recheck_tool_paths()`, line 58-60) is placed
  **first**, ahead of git's dirname and the inherited `PATH`.
- Current state in `lean-comparator-run.sh`: `run_sandboxed()`'s `env_flags` (line 463) is
  `-E "PATH=$PATH"` — the caller's raw `PATH`, unmodified. There is no toolchain-bin resolution
  anywhere in the script. **This fix is entirely absent** and needs: (a) a way to resolve the
  *target project's* pinned toolchain bin/ dir (the equivalent of `recheck_tool_paths`'s
  `lean --print-prefix`, run inside `$WORKDIR` so it resolves the worktree's own
  `lean-toolchain`, not the caller's), and (b) prepending it to the `PATH=` value passed via
  `-E` into `systemd-run`.

**Fix 2 — `lake env comparator config.json` invocation form.**

- Reference (`framed_channel/recheck-comparator.sh`'s `run_room()`, line 238):
  `confined "$room" "$pkg" -- lake env comparator "$cfg"` — a direct, single-hop
  `lake env comparator <config>` inside the sandbox, matching the upstream README's mandated form
  verbatim (`comparator-integration.md:81-83`).
- Current state in `lean-comparator-run.sh`: **this already resolves to the same form**, though
  indirectly and only on the guard-present branch. `run_sandboxed()` (line 444) builds
  `inner_argv=("$GUARD_BIN" build --dir "$WORKDIR" --no-share -- env "$COMPARATOR_PATH"
  config.json)`. `lake-build-guard.sh`'s `build` subcommand (core/scripts/lake-build-guard.sh,
  confirmed at lines 186/782/876/898) validates `lake_args[0]` (here `env`) against a hardcoded
  allowlist that includes `env`, then dispatches as `lake "${lake_args[@]}"` — i.e. the guard
  itself prepends `lake`, so the final command the guard executes is
  `lake env "$COMPARATOR_PATH" config.json`, matching the reference exactly. The fallback branch
  (guard absent, line 447) is written directly as `inner_argv=(lake env "$COMPARATOR_PATH"
  config.json)`. **Both branches are already correct in shape.** What is missing is not the
  invocation form itself but the *diagnosis* that connects it to Fix 1: `lake env` still resolves
  `lake` via `PATH`, so Fix 1's PATH-ordering is a precondition for Fix 2 to actually reach a
  working `lake`, not an independent, unrelated change. The design record should state this
  dependency explicitly rather than leaving four fixes looking like four independent, unordered
  bullet points.

**Fix 3 — TMPDIR inside the writable `.lake` directory (bv_decide SAT files).**

- Root cause: `bv_decide` (used by `framed_channel/lean/FramedChannel/Model/Crc8.lean`, and by any
  target project using `bv_decide`) writes SAT problem/proof files to `TMPDIR` (default `/tmp`),
  which Comparator's own internal `landrun` invocation makes read-only (confirmed by the captured
  landrun argument log in `specs/032.../reports/01_independent-certification-research.md:115-117`:
  "No `TMPDIR` is passed, and no write access outside `.lake`").
- Reference fix (`framed_channel/recheck/landrun-shim.sh`, lines 20-24 and 31-32):
  `tmp="$PWD/.lake/tmp"; mkdir -p "$tmp"; extra=(--env "TMPDIR=$tmp")` — a directory inside the
  already-writable `.lake` (`--rwx <project>/.lake` is one of Comparator's own fixed grants, so no
  *new* write access is introduced, only a new environment variable pointing an existing grant at
  a directory `bv_decide` will actually use).
- Mechanism this depends on: `COMPARATOR_LANDRUN` (Comparator's own override env var, already
  named and carried through unchanged in `lean-comparator-run.sh`'s header comment and
  `run_sandboxed()`'s `env_flags`) is pointed at a **shim script** that execs the real `landrun`
  with Comparator's own argument vector **plus** these extra grants — never at `landrun` itself.
  This is the entire point of the shim indirection: Comparator constructs its own landrun argv
  internally and there is no other way to inject additional grants into it.
- Current state in `lean-comparator-run.sh`: **no shim exists**. `COMPARATOR_LANDRUN` is resolved
  in `resolve_binary` (line 662) as a bare `landrun` PATH lookup and forwarded via `env_flags`
  (line 463) as `-E "COMPARATOR_LANDRUN=$LANDRUN_PATH"` — i.e. it points Comparator directly at
  the real `landrun` binary, with no extra grants. **This fix is entirely absent**; it requires:
  (a) a new sibling script (e.g. `scripts/lean-comparator-landrun-shim.sh`, modeled directly on
  `framed_channel/recheck/landrun-shim.sh`), (b) wiring `run_sandboxed()` (or `clean_room_setup`)
  to set `TMPDIR=$WORKDIR/.lake/tmp` (`mkdir -p` it) and export `COMPARATOR_LANDRUN` to the new
  shim's path instead of directly to `$LANDRUN_PATH`, and (c) the shim itself resolving the real
  `landrun` (e.g. via its own `LEAN_COMPARATOR_RUN_REAL_LANDRUN` override, mirroring this script's
  own `LEAN_COMPARATOR_RUN_GUARD_BIN` test-seam convention) so the shim is unit-testable without
  a real `landrun` on PATH.

**Fix 4 — `--rox` grant on git's nix-store shared libraries.**

- Root cause: Comparator's own internal `landrun` invocation grants `--rox <which git>` (execute
  permission on the `git` binary itself) but not the shared libraries `git` dynamically links
  against from the nix store, so `git` fails to start inside the sandbox. Lake interprets a
  failed `git remote get-url origin` as "the package's URL changed" and **deletes**
  `.lake/packages/<dep>`, then tries to re-clone it — a network operation that also cannot succeed
  inside the sandbox, and a destructive one against a linked-in dependency tree if the room's
  `.lake/packages` is ever a symlink to a shared location rather than a private copy.
- Reference fix (`framed_channel/recheck/landrun-shim.sh`, lines 25-27):
  `git_bin="$(realpath "$(command -v git)")"; for lib in $(ldd "$git_bin" | grep -oE
  '/[^ ]+\.so[^ ]*' | LC_ALL=C sort -u); do extra+=(--rox "$lib"); done` — read+execute (never
  write) on every immutable nix-store library `ldd` reports for `git`.
- This lives in the **same shim** as Fix 3 (`landrun-shim.sh` adds both `TMPDIR` and the git
  `--rox` grants in one pass) — Fix 3 and Fix 4 are naturally a single implementation unit, not
  two separate ones, and should be introduced to `lean-comparator-run.sh` together.
- `recheck-comparator.sh`'s `run_room()` additionally demonstrates a **pre-flight probe**
  (lines 221-235, bridge-only in that script, but the pattern generalizes): before invoking
  Comparator for real, run `git -C <pkg> remote get-url origin` under the exact same sandbox
  grants and abort with a clear NOT-RUN/error if it fails — "so Lake cannot delete them". This is
  a worthwhile defensive addition for `lean-comparator-run.sh` too, since the clean-room worktree
  it creates (`clean_room_setup`) runs `lake exe cache get`, which itself needs a working `git`
  inside the sandbox for any dependency Lake decides to touch.

### Documentation-only findings (no code path in `lean-comparator-run.sh`)

**lean4export panics on a Challenge-absent `permitted_axioms` entry.**

- Exact behavior (`specs/032.../reports/01_independent-certification-research.md:32-39,138`):
  adding a flagged theorem's native `bv_decide` helper axiom (e.g.
  `FramedChannel.Crc8.crc8_step_linear._native.bv_decide.ax_1_26`) to `permitted_axioms` makes
  lean4export **panic** while exporting the **Challenge** side (`Constant ... not found in
  environment`, exit 134) — because Comparator exports the permitted-axioms list from the
  Challenge environment too, and the Challenge (statement-only, bodies `:= sorry`) never declares
  that axiom at all.
- Working handling, proven both by a mutation test and by the crc8 flagged row in task 32:
  **permit only the trusted axioms** (never the row's own native helper), and require the run to
  produce exactly `Illegal axiom detected: '<helper>'` (an `axiom_violation` verdict in
  `lean-comparator-run.sh`'s own vocabulary, exit 66) as the **expected, passing** outcome for
  that config — not a failure of the harness. A companion mutation test
  (`specs/032.../reports/01_independent-certification-research.md:140-141`) confirms Comparator
  checks statement equality *before* axiom membership, so an `axiom_violation` verdict on a
  flagged row still proves the statement matches the Challenge; it does not, by itself, prove
  kernel acceptance of that row (a separate kernel-replay stage, e.g. Lean4Lean, covers that).
- `comparator-configs.sh` (lines 26-38, 123-146) is the reference for deriving this shape
  automatically: for each `flagged` policy row it emits a config permitting only the `trusted`
  axioms, plus a sibling `.expect` file naming the specific helper axiom(s) that row's own
  `axioms.txt` record depends on — read by `recheck-comparator.sh`'s classification, not
  hand-maintained.
- Target for this finding: `comparator-integration.md`'s Verdict Vocabulary section (the
  `axiom_violation` row, line 128) and a new subsection analogous to "Binary Provisioning Status"
  documenting the panic and its handling; `comparator-guide.md` should gain a short pointer too,
  since an operator constructing `permitted_axioms` by hand is exactly who would hit this.

**`lake update` silently rewrites `lean-toolchain` unless `--keep-toolchain`.**

- Exact behavior (`specs/032.../reports/01_independent-certification-research.md:176-182`,
  `framed_channel/recheck/README.md`'s "Building" section): in a tools package that requires
  `lean4export` (whose own upstream `lean-toolchain` names a newer Lean than the target project),
  a plain `lake update` adopts lean4export's toolchain into the tools package's own
  `lean-toolchain`, installs it, and every subsequent build produces binaries for the **wrong**
  Lean version — silently, with no error at update time. The fix is `lake update
  --keep-toolchain`; the defense is a coherence check (`recheck-revs.sh` items 1 and 5) comparing
  `lean-toolchain` files and grepping each built binary for `lean --githash` of the *target*
  project's Lean, catching drift even if `--keep-toolchain` was forgotten once and then corrected.
- This applies to any tools package a lean-extension user or agent sets up to pin `lean4export`
  (and, if kernel replay is added later, `lean4lean`) for use with `lean-comparator-run.sh`'s
  `COMPARATOR_LEAN4EXPORT` override — it is a provisioning/maintenance note, not a runner code
  path. Target: `comparator-integration.md`'s "Env Var / Binary Resolution and the C3
  Version-Coupling Caveat" section (which already discusses `lean4export` version coupling but
  not this specific pitfall), and/or a new short subsection.

**Batched Lean4Lean runs can exceed 19 GB and trigger earlyoom; run one module per process.**

- Exact behavior (`specs/032.../summaries/01_independent-certification-summary.md:101-102,178-179`):
  a batched (whole-package, single-process) Lean4Lean bridge run reached 19 GB RSS and was killed
  by `earlyoom` — which, as an observed side effect in the same incident, also sent SIGTERM to an
  unrelated `lean` process running concurrently. The fix, applied throughout
  `framed_channel/recheck-kernel.sh`, is one module per process: discover modules recursively and
  invoke `lake env lean4lean <Mod>` (or `leanchecker`) once per module in a fresh process, never
  batched.
- This is out of scope for `lean-comparator-run.sh` itself — Comparator's own kernel replay is a
  single in-process step internal to the `comparator` binary, not something this wrapper batches
  or could batch differently — but it is directly relevant to anyone extending the lean extension
  with a Lean4Lean/leanchecker kernel-replay runner alongside this Comparator runner (a natural
  next step, per task 32's own follow-ups list, though not itself in task 36's scope). Record it
  in `comparator-integration.md` as a caveat for any future sibling kernel-replay script, framed
  explicitly as "not applicable to this script's own single Comparator invocation, but load-bearing
  for anything that later wraps Lean4Lean/leanchecker the same way."

**Outer landrun/systemd-run around `lake env` and Comparator itself.**

- `lean-comparator-run.sh` already implements exactly this: the README's mandated
  `systemd-run --property=RestrictAddressFamilies=~AF_UNIX --user --pty ...` wrapper is already
  the outer layer around `lake-build-guard.sh` (or the ungated fallback), which is already
  documented at length in `comparator-integration.md`'s "Sandbox Invocation and Guard Nesting"
  section. `framed_channel/recheck-comparator.sh`'s `confined()` additionally adds a **second,
  explicit outer `landrun`** around the whole `lake env comparator` invocation (its own comment,
  lines 34-39: "The OUTER landrun is a hardening this script adds, not a deviation... every
  process of the run -- including `lake env` and Comparator itself, which run outside Comparator's
  own sandbox -- can write only inside its room (and /dev), and cannot reach the network"). This
  is a **stricter** posture than `lean-comparator-run.sh` currently takes: today, `lake exe cache
  get` (in `clean_room_setup`) and `lake env comparator config.json` (in `run_sandboxed`) run
  under `systemd-run`'s AF_UNIX restriction only, not under an additional landrun confining
  filesystem writes to the worktree. Recording this as a documented, deliberate design choice (add
  the outer landrun, or explicitly decide not to and say why) is part of this task's scope per the
  dispatch description; the reference implementation's own rationale (never trust `lake`/Lake
  package management with more than the room it's confined to) transfers directly.

### External Resources

- Upstream Comparator (`github.com/leanprover/comparator`, Apache-2.0): already fully documented
  in `comparator-integration.md`; no new upstream research was needed for this task — every fix
  is a wrapper/environment-level workaround for how upstream's own hardcoded `landrun` invocation
  and PATH assumptions interact with this specific NixOS/elan host, not a change to Comparator's
  behavior or contract.
- `landrun --help` (Landlock sandboxing): `--ro`/`--rw`/`--rox`/`--rwx` grant vocabulary,
  confirmed via `comparator-integration.md:222-223` and used identically in the reference shim.

### Recommendations

1. **`lean-comparator-run.sh`**: add toolchain-bin PATH resolution (Fix 1) inside
   `clean_room_setup` or a new helper, resolving against `$WORKDIR` (the just-created clean-room
   worktree) so it reflects the *target* project's pinned toolchain, not the caller's own
   environment — mirroring `recheck_tool_paths`'s `lean --print-prefix` pattern but scoped per-run
   rather than sourced once. Thread the resolved bin dir into `run_sandboxed()`'s `PATH=` value,
   ahead of the inherited `PATH`.
2. **`lean-comparator-run.sh`**: add a new landrun-shim script (Fixes 3+4 together, one
   implementation unit) as a source-store sibling, and repoint `COMPARATOR_LANDRUN` at it instead
   of the raw resolved `landrun` binary. Give the shim its own override env var for the real
   `landrun` path (test seam), following the `LEAN_COMPARATOR_RUN_GUARD_BIN` naming convention
   already established in this file (e.g. `LEAN_COMPARATOR_RUN_REAL_LANDRUN`).
3. **`lean-comparator-run.sh`**: set `TMPDIR` for the sandboxed run to a directory inside
   `$WORKDIR/.lake` (created ahead of time), and export it into the shim's environment (or have
   the shim derive it from `$PWD/.lake/tmp` exactly as the reference does, since the shim already
   runs with `--working-directory "$WORKDIR"` from `systemd-run`).
4. **`lean-comparator-run.sh`**: consider a git-remote pre-flight probe (reference:
   `recheck-comparator.sh`'s bridge pre-flight) before the main sandboxed run, to fail loudly
   (`comparator_unavailable`, naming the affected package) rather than letting Lake silently
   delete a dependency directory that then cannot be re-cloned inside the sandbox.
5. **`comparator-integration.md`**: replace the unresolved "Binary Provisioning Status" `lake:
   Permission denied` paragraph with the diagnosed root cause and the fix (Fix 1 + Fix 2's
   dependency relationship — Fix 2's invocation form only works once Fix 1 makes `lake` resolve to
   something `landrun` can execute), add a new subsection for the landrun-shim mechanism (Fixes 3
   and 4), add the lean4export panic / `axiom_violation`-as-expected-pass handling to the Verdict
   Vocabulary section, and add the `lake update --keep-toolchain` and batched-Lean4Lean-earlyoom
   caveats as documentation-only notes (the former under version coupling, the latter as a
   forward-looking caveat for any future kernel-replay sibling script).
6. **`comparator-guide.md`**: this file is explicitly the operator-facing "what a green result
   means" companion and deliberately omits implementation detail (see its own "See Also"
   section). The NixOS fixes themselves belong in `comparator-integration.md`; `comparator-guide.md`
   only needs a short addition if the flagged-axiom handling changes what a `verified` vs
   `axiom_violation` verdict means for an operator constructing `permitted_axioms` by hand — a
   one- or two-sentence pointer to the new subsection in the design record is sufficient; no
   restructuring of this file is needed.
7. **`test-lean-comparator-run.sh`**: add stub-based cases for (a) PATH ordering — a stub `lake`
   at a "toolchain bin" path plus an unrelated non-executable "elan shim" stand-in earlier in
   `PATH`, asserting the resolved invocation uses the toolchain-bin one; (b) the landrun shim —
   assert `COMPARATOR_LANDRUN` is pointed at the new shim script rather than the raw `landrun`
   path, and that the shim's own logged argv (following this suite's existing pattern of proving
   guard routing via a stub's logged argv, Cases G1-G3) includes the `TMPDIR` override and at
   least one `--rox` grant when a stub `git`/`ldd` pair is present. These follow the suite's own
   documented house style (stub binaries, real `git worktree`/`systemd-run`, assertions on logged
   argv rather than reading the source) rather than requiring the still-absent real
   `landrun`/`lean4export`/`nanoda_bin` binaries.

## Decisions

- **Scope boundary for `lean-comparator-run.sh` changes**: implement Fixes 1, 3, and 4 as new
  code (PATH resolution + landrun shim); treat Fix 2 as already-correct-but-undocumented (no code
  change, only a design-record clarification of its dependency on Fix 1). This avoids introducing
  a redundant, competing invocation path when the existing guard/fallback branches already produce
  the right command line.
- **lean4export panic and `lake update --keep-toolchain` and batched-Lean4Lean-earlyoom**: treat
  as documentation-only additions to `comparator-integration.md` (and a pointer in
  `comparator-guide.md` for the first). No corresponding code change belongs in
  `lean-comparator-run.sh` itself for any of the three — the first is caller-config guidance for
  constructing `permitted_axioms`/flagged rows, the second is tools-package provisioning guidance
  independent of this runner, and the third is explicitly out of scope for a single-process
  Comparator invocation and is recorded as forward-looking guidance for a not-yet-built sibling
  kernel-replay script.
- **Outer landrun hardening**: recommend adding it to `lean-comparator-run.sh` as a documented,
  deliberate hardening (matching the reference implementation's own framing that it is "a
  hardening this script adds, not a deviation"), rather than treating the plan phase as free to
  omit it — the dispatch description explicitly lists it among the four fixes plus the extra
  documentation items ("an outer landrun around lake env and Comparator itself"), so leaving it
  undocumented/unimplemented would leave the task's own description only partially addressed.

## Risks & Mitigations

- **No real `landrun`/`lean4export`/`nanoda_bin` on this host** (confirmed unavailable per
  `comparator-integration.md`'s Binary Provisioning Status section): a full live acceptance run of
  the updated `lean-comparator-run.sh` against a real target project cannot be demonstrated
  end-to-end during the implementation phase. Mitigation: follow the existing test suite's
  established pattern of stub-binary regression coverage (proving argv construction and shim
  wiring, not real sandbox enforcement), and be explicit in the implementation summary about which
  acceptance criteria are thereby deferred — the existing test suite already does this for Cases
  E1/E2, so the convention is established and should be reused, not re-litigated.
- **PATH-resolution helper scoping**: resolving the toolchain bin dir against `$WORKDIR` (the
  clean-room worktree) rather than the caller's `--project-root` is important — the worktree is
  guaranteed to have `lean-toolchain` checked out (per `clean_room_setup`'s existing defensive
  copy at line 339-343), and resolving too early (before the worktree exists) would either fail or
  silently resolve the wrong project's toolchain. Mitigation: place the PATH-ordering resolution
  after `clean_room_setup` completes, immediately before `run_sandboxed()`.
- **Shim/guard interaction**: the new landrun shim and the existing `lake-build-guard.sh`
  nesting are orthogonal (one wraps `landrun`, the other wraps `lake`) but both run inside the
  same `systemd-run` invocation; introducing the shim must not change `--no-share`'s correctness
  argument (the guard's `scope_key` still hashes the argument vector and excludes `config.json`'s
  content) since the shim is invoked *by Comparator itself* via `COMPARATOR_LANDRUN`, not by the
  guard. No interaction is expected, but this should be confirmed by re-reading the guard's own
  contract (as `comparator-integration.md` already instructs) before this task's implementation
  phase touches `run_sandboxed()`.

## Context Extension Recommendations

none — this task's own deliverable *is* the context extension (updating
`comparator-integration.md` and `comparator-guide.md`); there is no separate undocumented-topic
gap outside the task's own scope to flag.

## Appendix

- Search/read queries used: direct file reads of the three named target files, the reference
  `framed_channel/{recheck-comparator.sh,recheck-revs.sh,comparator-configs.sh,recheck/{README.md,landrun-shim.sh},recheck-kernel.sh}`
  scripts, `lake-build-guard.sh`'s subcommand-allowlist section, and the task 32 research report
  and summary. No web search was needed — every fix is already fully evidenced in this
  repository's own artifacts from task 32's live runs.
- Confirmed the lean extension's source-store location is
  `/home/benjamin/.config/nvim/agent-system/extensions/lean` (a git working copy of
  `git@github.com:benbrastmckie/nvim.git`), distinct from this repository's own `.claude/` deploy
  tree, per the task description's own parenthetical and `.claude/rules/source-store-deploy-boundary.md`.
