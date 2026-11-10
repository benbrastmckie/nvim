#!/usr/bin/env bash
# verify-deploy.sh - Check that a deployed .claude/ tree actually reflects its source store.
#
# INVOCATION CONTRACT: this script carries no deploy-root-guard.sh guard and sits outside the
# "Root-Resolution Guard for Core Scripts" opt-in contract (see
# context/patterns/regeneration-is-manual-only.md) entirely -- it needs no such guard because it
# resolves its TARGET from an explicit argument or `$(pwd)` (see the TARGET assignment below),
# never from `BASH_SOURCE`-relative `../..`, so it runs correctly from either tree with no
# override. It deliberately invokes the DEPLOYED copies of its own sub-check scripts (e.g.
# `.claude/scripts/check-extension-docs.sh`) regardless of where it itself was invoked from,
# because its purpose is comparing the deployed tree against the source store -- running a
# sub-check's source-store copy instead would make that comparison meaningless.
#
# TARGET_REPO CONTRACT: a SEPARATE axis from the paragraph above. That paragraph is about where
# THIS SCRIPT may be invoked FROM (either tree, no override). This paragraph is about what the
# TARGET argument itself must BE. The two are easy to conflate because the paragraph above's
# "runs correctly from either tree" sentence is true about invocation directory but reads, at a
# glance, like a claim about the TARGET value -- it is not. TARGET,
# when given explicitly (or defaulted from `$(pwd)`; see the TARGET assignment below), MUST be a
# repository that already holds a DEPLOYED `.claude/` tree: gate0 hard-requires `$TARGET/.claude`
# to exist and `exit 2`s with "no deploy tree" when it does not. TARGET is therefore NEVER an
# `agent-system/extensions/<name>` source-store directory -- a source-store directory has no
# `.claude/` subdirectory of its own, so passing one as TARGET always fails at gate0 before any
# gate selection is even consulted. Separately, every source-store-only gate (3, 4, 6, 7, 12 and
# others, each individually guarded on `$TARGET/agent-system/extensions`) additionally `[SKIP]`s
# unless TARGET *also* holds `agent-system/extensions` alongside its deployed `.claude/`. Put the
# two requirements together: TARGET must be simultaneously a deploy CONSUMER (has `.claude/`) AND
# the SOURCE STORE (has `agent-system/extensions`) for a source-store-only gate to actually run
# rather than SKIP -- in this repository, that is only the repo root, never a source-store
# subdirectory passed in its place.
#
# This is the first of the two gates that any claim about deployed behavior has to clear. It
# answers "is the deploy tree current and are its hooks registered?" -- it does NOT answer "have
# events actually flowed?", which requires real command invocations over time. Do not report a
# passing run here as end-to-end verification.
#
# Restated precisely for this script's one automated consumer: this script's PASS claims only
# that the deploy tree matches its source store and that hooks are registered. It does NOT claim
# the redeployed machinery has been exercised -- that would require the second gate (real command
# invocations) described above, which this script cannot and does not perform.
#
# Callers: the inter-cycle redeploy checkpoint (`skill-orchestrate` Stage MT-3 step 7) is an
# automated consumer of this script's exit code AND, via --findings below, of its findings set.
# See context/patterns/batch-orchestration-guardrails.md's `### The Inter-Cycle Redeploy
# Checkpoint` subsection for the full contract this script is one half of (the other half being
# scripts/deploy-headless.sh).
#
# The checks are deliberately mechanical and independently reproducible; each prints the command
# it stands for, so a reader can re-run any single line by hand rather than trusting this script.
#
# Usage:
#   verify-deploy.sh [--quiet] [--findings] [--skip-slow] [--skip-unchanged] [--jobs N|auto] [--minimal-init DIR] [TARGET_REPO]
#
# TARGET_REPO placeholder (see TARGET_REPO CONTRACT above):
#   TARGET_REPO is a repository root, not a directory to be checked -- it must already hold a
#   deployed `.claude/` tree (gate0 requires it, else `exit 2`), and, for any source-store-only
#   gate to run instead of `[SKIP]`, must also hold `agent-system/extensions`. Concretely, this
#   means `--only-gate 3,4 <source_dir>` (passing a source-store directory such as
#   `agent-system/extensions/core` as TARGET_REPO) CANNOT work: `<source_dir>` has no `.claude/`,
#   and gate0 exits 2 before gate selection is even consulted, regardless of `--only-gate`. The
#   repo root is the correct TARGET_REPO for exercising source-store gates, because it is the
#   only directory that is simultaneously the deploy consumer and the source store.
#
# Minimal-init hatch (--minimal-init DIR, additive-only):
#   Opt-in escape hatch for CI/container environments with no user nvim config: this script's two
#   nvim-backed gates (gate5 verify_all, gate13 find_orphans) run under `nvim --headless --clean
#   --cmd "set rtp+=DIR"` instead of the default plain `nvim --headless` (which loads init.lua and
#   pays the full lazy.nvim plugin bootstrap). DIR is the nvim CONFIG directory, not necessarily
#   $TARGET (they coincide in CI, where the checkout IS the nvim config repo, but differ for a
#   consumer repo) -- always explicit, never derived. Default OFF: absent this flag, both gates'
#   behavior is byte-for-byte unchanged (plain `nvim --headless`, same as before this flag
#   existed). Confirmed safe by a direct probe (manager.load/resync_all/verify_all/find_orphans
#   all succeed under --clean with only rtp set) before this flag was added -- the extension
#   manager has no plugin dependency. See deploy-headless.sh's header for its own matching flag,
#   which this script's flag is designed to be threaded through from.
#
# Exit codes:
#   0  all checks passed
#   1  one or more checks failed
#   2  cannot run (target missing, no deploy tree to inspect, an invalid --only-gate argument, OR
#      an --only-gate selection whose every named gate SKIPped or was deferred, leaving 0 checks
#      run -- see "Gate selection" below) -- an automated gate MUST treat this the same as exit 1
#      (failure), never as a pass: a checkpoint that cannot establish the redeploy landed is in
#      the same position as one that established it did not, and a selection that attested to
#      nothing is in that same position too.
#
# Slow-gate selection (--skip-slow):
#   Skips gate 8 (the shell test suite runner, tests/run-all.sh) ONLY. Gate 8 was measured at
#   117.9s of the ~2.8min total run, so --skip-slow drops the inline cost to roughly 50-70s while
#   every other gate still runs. This is purely additive: with --skip-slow absent, default-mode
#   behavior, findings, and exit codes are byte-for-byte unchanged. A skipped gate 8 never
#   increments CHECKS or FAILURES and never contributes a finding line. This is the flag
#   scripts/deploy-headless.sh now passes on its own inline, non-optional invocation of this
#   script -- see context/patterns/regeneration-is-manual-only.md's
#   `### deploy-headless.sh's Inline Verification and Exit Code 3` subsection for the full
#   fast/full split and exit-code contract.
#
# Input-scoped gate invalidation (--skip-unchanged, additive-only, defaults off):
#   Consults a per-gate, content-addressed cache (lib/gate-cache-lib.sh) BEFORE dispatching each
#   gate. A gate whose declared input_corpus AND own implementation (invoke-function body, every
#   script/Lua-module it references, the whole scripts/lib/ directory, its own registry row, and
#   the source-store-vs-deployed target-mode discriminator -- see that library's header for the
#   full five-component digest) are byte-identical to the state recorded the last time that gate
#   finished GREEN is never dispatched at all: it is REMOVED from the gate id set before either
#   dispatch path runs (gate_registry_exclude_ids), not merely silenced inside its own body the
#   way --only-gate's gate_selected() guard works -- the whole point is to avoid paying the
#   gate's own cost, including gate 8's run-all.sh battery, not just its narrative output. Each
#   skip emits `[SKIP-CACHED] gateN (<name>) -- inputs unchanged since <timestamp>` (quiet-gated,
#   matching every other [SKIP] line's convention) naming a short digest prefix, and increments
#   SKIPPED_CACHED, a counter dedicated to this state and never conflated with CHECKS/FAILURES --
#   a cache-skipped gate is neither a pass nor a fail, it simply did not run this time. The
#   summary line gains a skip-count clause ONLY when SKIPPED_CACHED is non-zero, so the default
#   (flag-absent) path's output stays byte-identical to a pre-"--skip-unchanged" build; this is
#   the SAME additive-only contract --skip-slow and --findings above already establish, extended
#   to a third independent flag.
#
#   A gate that WAS dispatched (cache miss, or --skip-unchanged absent entirely) and finished
#   with zero findings and zero failures writes a fresh green entry keyed by its CURRENT
#   composite key, overwriting whatever was there before (including migrating a stale lower
#   format_version forward automatically, since a write always stamps the current
#   GATE_CACHE_FORMAT_VERSION). A gate that failed, warned, timed out, or skipped for its own
#   internal source-store-only guard writes NOTHING and INVALIDATES (deletes) any existing entry
#   for that id instead -- see gate_cache_entry_invalidate's header for why this is explicit
#   policy rather than a side effect to rely on implicitly. Cacheability is determined from two
#   new indexed arrays, GATE_RAN_LIST and GATE_DIRTY_LIST (appended to by pass()/fail()/warn(),
#   reconciled across concurrent batches via the EXACT same mechanism FINDINGS_LIST already uses
#   -- see gate_registry_exec_concurrent_batch's own header for why a naive sequential `source
#   state.$id` would silently drop every id's contribution but the last), never by diffing the
#   global CHECKS/FAILURES counters directly, since those are indistinguishable sums across
#   however many gates ran concurrently in the same wave.
#
#   The cache store lives at `<TARGET>/specs/.gate-cache/gate<N>.json` -- deliberately NOT under
#   `.claude/**`, which `deploy-headless.sh` regenerates immediately before every invocation of
#   this script that matters, so a cache placed there would always read back empty on exactly the
#   runs this flag exists to speed up. See gate-cache-lib.sh's own header for the full
#   rejected-location rationale and the atomic write-then-rename contract that makes a
#   partially-written entry an impossible read, not merely an unlikely one.
#
#   Fail-open, never a false pass: any sentinel key, unreadable/corrupted entry, or
#   format_version mismatch degrades to a cache MISS (the gate runs for real), never to a
#   fabricated hit. This flag changes WHICH gates run; it never changes what a gate that DOES run
#   concludes, and it never substitutes for the full sweep as a plan's closure criterion -- that
#   remains --skip-unchanged-absent, full-battery verify-deploy.sh, unconditionally.
#
# Gate 8 concurrency (VERIFY_DEPLOY_GATE8_JOBS, additive-only):
#   When gate 8 runs (--skip-slow absent), it requests run-all.sh's opt-in --jobs parallelism
#   instead of the sequential default. VERIFY_DEPLOY_GATE8_JOBS defaults to 'auto' (nproc capped
#   at run-all.sh's JOBS_CAP of 4); set it to '1' to force fully sequential Gate 8 on a nproc=1,
#   memory-pressured, or heavily-loaded CI/interactive host -- that override, with no code
#   change, IS the rollback for this feature. An invalid value surfaces through run-all.sh's own
#   exit-2 validation; Gate 8's remedy text names the variable when that happens. run-all.sh's
#   nested-invocation guard (RUN_ALL_NESTED) still forces sequential execution when this script
#   is itself reached from inside another run-all.sh suite, regardless of this setting.
#
# Gate-level concurrency (--jobs N|auto, additive-but-defaulted):
#   Runs independent gates CONCURRENTLY instead of strictly in series, via
#   lib/gate-registry-lib.sh's gate_registry_exec_concurrent_batch -- a direct port of
#   tests/run-all.sh's own proven worker-slot-pool shape (longest-first scheduling, per-id
#   output captured to its own file then emitted in DECLARATION order regardless of completion
#   order, a hard wave-barrier for any gate that declares a dependency on another), extended with
#   the capture-then-reconcile protocol gate_registry_exec_bounded (Phase 6) already established.
#   `--jobs 1` is the explicit, byte-identical opt-out: it takes the EXACT pre-Phase-7 sequential
#   code path below (same per-gate mktemp/exec_bounded/cat sequence, unchanged), never the
#   concurrent scheduler at all. `--jobs auto` (also this flag's DEFAULT, absent --jobs entirely)
#   resolves to nproc capped at 4 (JOBS_CAP, matching run-all.sh's own cap and its own rejected-
#   alternatives rationale for why a fixed cap rather than a bare nproc -- see that script's
#   header; not re-litigated here). `--jobs N` (plain positive integer) requests that cap
#   directly, uncapped by JOBS_CAP (mirrors run-all.sh's own `--jobs N` vs `--jobs auto`
#   asymmetry). Gate 8 (registry `serialized=true`) always runs alone, before the rest of the
#   pool, regardless of worker count -- the one gate that itself spawns further nested processes
#   (run-all.sh's own pool), an ambient-load precaution ported from run-all.sh's
#   LOAD_SENSITIVE_BASENAMES precedent, not a resource-collision requirement (a live audit of
#   every one of the 26 real gates' function bodies for a fixed-path write, lock, or socket
#   outside its own mktemp-scoped fixture found none -- see
#   context/standards/shell-script-testing.md's gate-level parallelism-safety audit record).
#   Text output and the final PASS/FAIL line are deterministic and byte-identical regardless of
#   worker count: CHECKS/FAILURES are pure sums, FINDINGS_LIST's eventual printed set is already
#   `sort -u`'d downstream, and per-gate narrative output is always emitted in ascending gate-id
#   order, never completion order. Nested-invocation guard: VERIFY_DEPLOY_NESTED=1, exported for
#   the remainder of this process once set, forces --jobs to 1 regardless of what was
#   requested -- mirrors RUN_ALL_NESTED's own contract line-for-line, for the identical reason
#   (a gate that itself shells out to this same script, e.g. via Gate 8 -> run-all.sh -> a suite
#   that invokes verify-deploy.sh again, must never multiply worker counts across nesting
#   levels).
#
# Findings mode (--findings, additive-only):
#   Emits a normalized, one-per-line, machine-diffable findings set across all eighteen gates
#   (gate0 through gate17) plus a gate0 "could not run" sentinel, printed to stdout after the
#   final narrative PASS/FAIL line (including on a passing run, where an empty set is a valid,
#   meaningful result). Every BLOCKING finding line begins with the literal token `FINDING `
#   followed by a gate label (`gate0`..`gate17`); the automated consumer is expected to invoke
#   `verify-deploy.sh --findings --quiet`, filter with `grep '^FINDING ' | sort -u`, and diff two
#   such captures rather than compare exit codes alone -- see the Checkpoint subsection above for
#   why exit-code-only comparison masks a newly-introduced finding hiding inside an
#   already-failing gate. This mode is purely additive: with --findings absent, default-mode
#   narrative output and exit codes are byte-for-byte unchanged.
#
#   A SEPARATE, NON-BLOCKING CHANNEL: a `warn_advisory()`-level notice (gate16's
#   routing_hard/routing_agents_hard absence guard, and gate8's all-expected branch) begins with
#   the literal token `WARN-FINDING ` instead -- deliberately NOT matched by the `^FINDING ` consumer filter above,
#   so it never escalates into the blocking findings set that filter feeds a batch-gate consumer.
#   It is still printed under --findings (visible to a human reader or a future severity-aware
#   reader) and still drives every one of `warn()`'s other effects (the `[WARN]` stderr
#   narrative, the CHECKS increment, and GATE_DIRTY_LIST's cache-ineligibility side effect) --
#   only its escalation into the BLOCKING channel changes. An ordinary `warn()` call (e.g.
#   gate20's per-file budget-ceiling check) still emits a plain `FINDING ` line and stays
#   batch-attributable, exactly as before -- the two functions are kept deliberately separate so
#   that intention stays explicit at each call site. See `warn_advisory()`'s own header comment
#   below for the full rationale and why this is not the gate-silencing a declared-manifest-key
#   deletion would be.
#
# Gate selection (--only-gate N[,M,...], additive-only):
#   Runs only the named gate(s) (1-<max>, <max> derived from the live gate registry rather than a
#   hardcoded literal -- see the --only-gate case branch below) instead of the full battery.
#   Absent this flag, GATES_FILTER is empty and every gate runs -- byte-for-byte the same as
#   before this flag existed. A caller that only needs to exercise one gate (e.g. a test suite
#   targeting gate 20) can pay for that one gate instead of the full set; see
#   context/standards/shell-script-testing.md for the intended test-fast-path use and the
#   standing rule that at least one full-battery invocation must remain somewhere in the suite.
#   gate0 (argument/target validation, before any gate runs) is never filterable -- it always
#   runs. An invalid gate id (non-numeric or outside 1-<max>) exits 2 and, under --findings,
#   emits a `FINDING gate0` line.
#
#   Zero-check-under-filter (additive-only, unreachable with --only-gate absent): if every gate
#   named by --only-gate SKIPped (its own source-store-only guard, e.g. gate 3) or was deferred
#   (--skip-slow's gate 8), the run reaches CHECKS=0. This is reported the same way as the
#   invalid-gate-id case above -- exit 2, a stderr message, and (under --findings) a `FINDING
#   gate0` line -- rather than falling through to the ordinary PASS branch and printing
#   "PASS -- 0 check(s), 0 failure(s)", exit 0, which would attest to a check that never ran. The
#   message says "skipped or deferred" rather than naming one cause, distinguishing it from the
#   invalid-gate-id error, which fires earlier (at argument parsing, before any gate runs).
#
# Cost-class selection (--max-cost {free|moderate|slow}, additive-only):
#   Selects every gate whose scripts/gate-registry.data cost_class is at or below the named
#   class (ordered free < moderate < slow), without naming gate ids -- "everything under N
#   seconds" without a gate roster to maintain by hand. Absent this flag, MAX_COST is empty and
#   this is a complete no-op: GATES_FILTER is exactly what --only-gate set it to (or empty for
#   "all gates"), byte-for-byte the same as before this flag existed. Combinable with --only-gate:
#   the two selections intersect (flag order on the command line does not matter) -- "only these
#   gates, but also respect the cost ceiling". An intersection (or a bare --max-cost match set)
#   that resolves to zero gates drives the same zero-check-under-filter exit-2 path described
#   above, reported via the `$MAX_COST`-aware `$_VD_SELECTION_DESC` wording rather than always
#   crediting --only-gate. An invalid class name (anything other than free/moderate/slow) exits 2
#   and, under --findings, emits a `FINDING gate0` line, mirroring --only-gate's own invalid-id
#   handling.

set -uo pipefail

# Own-directory resolution, added for the sole purpose of locating the sibling redeploy-remedy
# helper -- NOT a repo-root computation. Per context/patterns/regeneration-is-manual-only.md's
# "Redeploy-Remedy Emission Sites" subsection, Decision 1(d): this MUST NOT be widened into
# "${_VD_SCRIPT_DIR}/../.." (which would newly incur regeneration-is-manual-only.md's
# Root-Resolution Guard obligation for no benefit this script needs -- it already resolves its
# own TARGET independently, further below).
_VD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Degrade-safe guarded source (same subsection, Decision 1(c)): a missing lib falls back to a
# no-op fragment rather than a source-time failure.
_RR_LIB="${_VD_SCRIPT_DIR}/lib/redeploy-remedy-lib.sh"
# shellcheck source=lib/redeploy-remedy-lib.sh
[ -f "$_RR_LIB" ] && . "$_RR_LIB"
declare -F redeploy_remedy_fragment >/dev/null 2>&1 || redeploy_remedy_fragment() { printf '%s' ""; }

# Same degrade-safe guarded-source shape as _RR_LIB immediately above: the anchored,
# SGR-stripping verdict-line extraction helper every gate's FINDINGS_LIST population now uses
# instead of an unanchored `grep -F '[TOKEN]'` (see
# context/standards/shell-script-testing.md's "Verdict-line extraction contract" section for the
# full producer/consumer contract this helper implements).
_GVEL_LIB="${_VD_SCRIPT_DIR}/lib/gate-verdict-extract-lib.sh"
# shellcheck source=lib/gate-verdict-extract-lib.sh
[ -f "$_GVEL_LIB" ] && . "$_GVEL_LIB"
declare -F verify_deploy_extract_verdict_lines >/dev/null 2>&1 || verify_deploy_extract_verdict_lines() { :; }

# Same degrade-safe guarded-source shape: the declarative gate registry interpreter (gates 1-8
# migrated so far; see gate-registry.data and lib/gate-registry-lib.sh's own headers for the full
# contract). A missing lib degrades to an empty gate_registry_ids (the migrated-gate loop below
# then simply iterates zero times, matching this script's degrade-safe posture elsewhere -- a
# missing lib never aborts this script, it only means the loop's own gates silently do not run,
# same severity class as a missing redeploy-remedy-lib.sh degrading to an empty remedy fragment).
_GREG_LIB="${_VD_SCRIPT_DIR}/lib/gate-registry-lib.sh"
# shellcheck source=lib/gate-registry-lib.sh
[ -f "$_GREG_LIB" ] && . "$_GREG_LIB"
# Captured BEFORE any of the degrade-safe stub assignments below install a same-named no-op --
# this is the one reliable "did the real lib actually source" signal, since after the stub lines
# run, `declare -F` is unconditionally true either way (real function or stub). Gates the
# shared-corpus wiring further down: with no real lib, GATE_SHARED_CORPUS_FILE/_ROOT are simply
# never exported, so every lint's own common_shared_corpus_available check reports "not
# available" and each takes its pre-existing standalone enumeration path -- never a silently
# empty-but-"available" corpus, which is the one unsafe degrade this signal exists to prevent.
declare -F gate_registry_shared_corpus_build >/dev/null 2>&1 && _VD_GREG_LIB_LOADED=true || _VD_GREG_LIB_LOADED=false
declare -F gate_registry_ids >/dev/null 2>&1 || gate_registry_ids() { :; }
declare -F gate_registry_load >/dev/null 2>&1 || gate_registry_load() { :; }
declare -F gate_registry_field >/dev/null 2>&1 || gate_registry_field() { :; }
declare -F gate_registry_max_id >/dev/null 2>&1 || gate_registry_max_id() { :; }
# A missing lib degrades gate_registry_exec_bounded to an unbounded direct call -- same
# degrade-safe posture as the other three: a gate still runs, it is just not timeout-bounded,
# never a hard script failure over an absent sourced lib.
declare -F gate_registry_exec_bounded >/dev/null 2>&1 || gate_registry_exec_bounded() { "$1"; return $?; }
# A missing lib degrades the concurrent batch scheduler to a silent no-op -- combined with the
# JOBS<=1 dispatch guard below (which is always reachable regardless of this degrade, since JOBS
# resolution happens independently of whether the lib loaded), the net effect of a missing lib
# is simply "gate-level concurrency is unavailable," never a hard script failure: the ordinary
# per-gate sequential loop (gate_registry_exec_bounded, degrade-safe on its own per the line
# above) still runs every gate either way.
declare -F gate_registry_exec_concurrent_batch >/dev/null 2>&1 || gate_registry_exec_concurrent_batch() { :; }
# gate_registry_exclude_ids: removes the given comma-separated ids from the loaded _GREG_IDS set
# BEFORE dispatch, so neither gate_registry_exec_concurrent_batch nor the sequential loop below
# ever invokes them -- the primitive --skip-unchanged needs to make a cache hit actually SKIP a
# gate's own cost, not merely silence its narrative output the way --only-gate's gate_selected()
# guard does. Degrades to a no-op with no real lib loaded, same posture as every other
# gate_registry_* stub above.
declare -F gate_registry_exclude_ids >/dev/null 2>&1 || gate_registry_exclude_ids() { :; }
gate_registry_load "${_VD_SCRIPT_DIR}/gate-registry.data"

# gate-cache-lib.sh: --skip-unchanged's own backing library (composite-key computation and the
# cache store). Same degrade-safe sourcing posture as gate-registry-lib.sh above -- a missing lib
# degrades every one of these to "always compute/read as a miss, never write," which combined
# with SKIP_UNCHANGED defaulting false means a missing lib is invisible unless --skip-unchanged
# is explicitly requested, in which case it simply never skips anything (falls back to a full
# run) rather than failing the script.
_GCACHE_LIB="${_VD_SCRIPT_DIR}/lib/gate-cache-lib.sh"
# shellcheck source=lib/gate-cache-lib.sh
[ -f "$_GCACHE_LIB" ] && . "$_GCACHE_LIB"
declare -F gate_cache_composite_key >/dev/null 2>&1 || { gate_cache_composite_key() { echo "CANNOT_COMPUTE"; }; GATE_CACHE_SENTINEL="CANNOT_COMPUTE"; }
declare -F gate_cache_entry_read >/dev/null 2>&1 || gate_cache_entry_read() { return 1; }
declare -F gate_cache_entry_write >/dev/null 2>&1 || gate_cache_entry_write() { return 1; }
declare -F gate_cache_entry_invalidate >/dev/null 2>&1 || gate_cache_entry_invalidate() { return 0; }

QUIET=false
FINDINGS=false
SKIP_SLOW=false
# SKIP_UNCHANGED: --skip-unchanged, defaulting off. See this file's header "Input-scoped gate
# invalidation (--skip-unchanged)" section for the full contract. Additive-only: with the flag
# absent, SKIP_UNCHANGED stays false and every line this flag's own code touches is a no-op --
# the default path's output is byte-identical to a pre-"--skip-unchanged" build.
SKIP_UNCHANGED=false
TARGET=""
MINIMAL_INIT_DIR=""
FINDINGS_LIST=()
# GATES_FILTER: empty = all gates (today's default behavior). Populated by --only-gate below with
# a comma-separated list of gate ids; gate_selected() (defined further down, alongside pass()/
# fail()/warn()) is the single predicate every gate's guard consults.
GATES_FILTER=""
# MAX_COST: empty = no cost-class ceiling (today's default behavior, unaffected by this flag's
# existence). Populated by --max-cost below with one of free/moderate/slow; resolved into
# GATES_FILTER (intersected with any --only-gate selection, order-independent) once argument
# parsing completes -- see the resolution block right after the while-loop below.
MAX_COST=""
# JOBS: gate-level concurrency worker cap. "auto" (the default, absent --jobs entirely) resolves
# below (after the while-loop, alongside the nested-invocation guard) to nproc capped at 4;
# "1" is the explicit, byte-identical sequential opt-out. See this file's header "Gate-level
# concurrency" section for the full contract.
JOBS="auto"

while [ $# -gt 0 ]; do
  case "$1" in
    --quiet) QUIET=true; shift ;;
    --findings) FINDINGS=true; shift ;;
    --skip-slow) SKIP_SLOW=true; shift ;;
    --skip-unchanged) SKIP_UNCHANGED=true; shift ;;
    --jobs)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        echo "ERROR: --jobs requires N or 'auto'" >&2
        [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: --jobs requires N or 'auto'"
        exit 2
      fi
      JOBS="$2"; shift 2
      ;;
    --only-gate)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        echo "ERROR: --only-gate requires a gate id (or comma-separated ids), e.g. --only-gate 20" >&2
        [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: --only-gate requires a gate id"
        exit 2
      fi
      # Validate every comma-separated token is a plain integer in 1-<max> before accepting any
      # of them -- a partially-valid list must refuse loudly, not silently run a subset. <max> is
      # derived from the live registry via gate_registry_max_id (single-sourced with
      # gate_registry_ids -- both read the same loaded _GREG_IDS, gate_registry_load has already
      # run above), so this bound cannot go stale again the next time a gate is added. Explicit
      # fallback: a missing/degraded registry library yields an empty gate_registry_max_id (its
      # own degrade-safe stub, line ~292 above), which must not silently reject or silently
      # accept every id -- fall back to the last-known literal bound (23) rather than leaving the
      # derived max at 0. This literal is reachable ONLY when lib/gate-registry-lib.sh itself is
      # absent, where no derivation of any kind is possible; it is therefore a last-known-good
      # constant for a missing-library degrade path, not a count that drifts with the registry,
      # and is deliberately left as-is rather than narrowed into a refusal (a behavioural change
      # to the degrade path, out of this task's scope).
      _only_gate_max_id="$(gate_registry_max_id)"
      [ -z "$_only_gate_max_id" ] 2>/dev/null && _only_gate_max_id=0
      [ "$_only_gate_max_id" -eq 0 ] 2>/dev/null && _only_gate_max_id=23
      IFS=',' read -r -a _only_gate_tokens <<< "$2"
      for _only_gate_tok in "${_only_gate_tokens[@]}"; do
        case "$_only_gate_tok" in
          ''|*[!0-9]*)
            echo "ERROR: --only-gate: invalid gate id '$_only_gate_tok' (must be a number 1-$_only_gate_max_id)" >&2
            [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: --only-gate invalid gate id '$_only_gate_tok'"
            exit 2
            ;;
        esac
        if [ "$_only_gate_tok" -lt 1 ] || [ "$_only_gate_tok" -gt "$_only_gate_max_id" ]; then
          echo "ERROR: --only-gate: gate id '$_only_gate_tok' is out of range (must be 1-$_only_gate_max_id)" >&2
          [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: --only-gate gate id '$_only_gate_tok' out of range"
          exit 2
        fi
      done
      unset _only_gate_tok _only_gate_max_id
      GATES_FILTER="$2"; shift 2
      ;;
    --max-cost)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        echo "ERROR: --max-cost requires a class argument (free, moderate, or slow), e.g. --max-cost moderate" >&2
        [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: --max-cost requires a class argument"
        exit 2
      fi
      case "$2" in
        free|moderate|slow) : ;;
        *)
          echo "ERROR: --max-cost: invalid class '$2' (must be free, moderate, or slow)" >&2
          [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: --max-cost invalid class '$2'"
          exit 2
          ;;
      esac
      MAX_COST="$2"; shift 2
      ;;
    --minimal-init)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        echo "ERROR: --minimal-init requires a DIR argument (the nvim config directory)" >&2
        [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: --minimal-init requires a DIR argument"
        exit 2
      fi
      MINIMAL_INIT_DIR="$2"; shift 2
      ;;
    -h|--help)
      sed -n '2,145p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "ERROR: unknown flag: $1" >&2
      [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: unknown flag: $1"
      exit 2
      ;;
    *)
      TARGET="$1"; shift ;;
  esac
done

# --jobs resolution ("auto" -> nproc capped; validate a plain integer; nested-invocation guard) --
# mirrors run-all.sh's own --jobs/RUN_ALL_NESTED resolution shape line-for-line (see this file's
# header "Gate-level concurrency" section for the full contract this implements).
JOBS_CAP=4
if [ "$JOBS" = "auto" ]; then
  if command -v nproc >/dev/null 2>&1; then
    JOBS="$(nproc)"
  else
    JOBS=1
  fi
  [ "$JOBS" -gt "$JOBS_CAP" ] && JOBS="$JOBS_CAP"
elif ! printf '%s' "$JOBS" | grep -qE '^[0-9]+$' || [ "$JOBS" -lt 1 ]; then
  echo "ERROR: --jobs: invalid value '$JOBS' (must be a positive integer or 'auto')" >&2
  [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: --jobs invalid value '$JOBS'"
  exit 2
fi

# Nested-invocation guard: a verify-deploy.sh launched FROM one of this run's own gates (Gate 8
# -> run-all.sh -> a suite that itself shells out to verify-deploy.sh again) must never multiply
# worker counts across nesting levels. If already nested, force sequential regardless of what
# --jobs requested; export for the remainder of this process either way so a further level of
# nesting also stays sequential. Mirrors RUN_ALL_NESTED's own contract exactly.
#
# Captured BEFORE the unconditional export below (which would otherwise make every subsequent
# read of VERIFY_DEPLOY_NESTED -- including gate8_run()'s specs/.gate-lock bracket, which runs
# much later in this same process -- report "1" even for a genuinely top-level invocation).
# Mirrors tests/run-all.sh's own RUN_ALL_WAS_NESTED_AT_ENTRY capture exactly, and for the same
# reason: gate8_run() needs to know whether THIS invocation was nested AT ENTRY, not whether
# VERIFY_DEPLOY_NESTED happens to be set by the time it runs.
VERIFY_DEPLOY_WAS_NESTED_AT_ENTRY="${VERIFY_DEPLOY_NESTED:-}"
if [ "${VERIFY_DEPLOY_NESTED:-}" = "1" ]; then
  JOBS=1
fi
export VERIFY_DEPLOY_NESTED=1

# --max-cost resolution (additive-only; unreachable with --max-cost absent, since MAX_COST is
# then empty and this block is a no-op leaving GATES_FILTER exactly as --only-gate set it, or
# empty for "all gates" -- byte-for-byte the same as before this flag existed). Resolves the
# requested cost-class ceiling against the registry's own cost_class field (gate-registry.data),
# ordered free < moderate < slow, selecting every gate at or below the requested class. When
# --only-gate was ALSO given, the two selections are intersected (order of the two flags on the
# command line does not matter) -- "only these gates, but also respect the cost ceiling" is the
# intuitive reading, not "either selection alone". An intersection that resolves to zero gates
# sets GATES_FILTER to the sentinel "0" (no real gate id is ever 0), which cleanly drives
# gate_selected() to reject every gate and the zero-check-under-filter branch below to fire,
# rather than silently falling back to GATES_FILTER="" (which means "all gates" -- the opposite
# of what an empty intersection should mean).
ONLY_GATE_ARG="$GATES_FILTER"
if [ -n "$MAX_COST" ]; then
  declare -A _VD_COST_RANK=([free]=0 [moderate]=1 [slow]=2)
  _vd_max_rank="${_VD_COST_RANK[$MAX_COST]}"
  _vd_cost_ids=""
  for _vd_id in $(gate_registry_ids); do
    _vd_id_class="$(gate_registry_field "$_vd_id" cost_class)"
    _vd_id_rank="${_VD_COST_RANK[$_vd_id_class]:-}"
    [ -z "$_vd_id_rank" ] && continue
    if [ "$_vd_id_rank" -le "$_vd_max_rank" ]; then
      _vd_cost_ids="${_vd_cost_ids:+$_vd_cost_ids,}$_vd_id"
    fi
  done
  if [ -n "$ONLY_GATE_ARG" ]; then
    _vd_intersection=""
    IFS=',' read -r -a _vd_only_tokens <<< "$ONLY_GATE_ARG"
    for _vd_tok in "${_vd_only_tokens[@]}"; do
      case ",${_vd_cost_ids}," in
        *",${_vd_tok},"*) _vd_intersection="${_vd_intersection:+$_vd_intersection,}$_vd_tok" ;;
      esac
    done
    GATES_FILTER="${_vd_intersection:-0}"
    unset _vd_only_tokens _vd_tok _vd_intersection
  else
    GATES_FILTER="${_vd_cost_ids:-0}"
  fi
  unset _vd_max_rank _vd_cost_ids _vd_id _vd_id_class _vd_id_rank _VD_COST_RANK
fi

# NVIM_ARGS: base nvim invocation for this script's two headless call sites (gate5 verify_all,
# gate13 find_orphans). Extended by --minimal-init to `--clean --cmd "set rtp+=DIR"` instead of
# the default plain `nvim --headless` (which loads init.lua and pays the full lazy.nvim plugin
# bootstrap). Absent --minimal-init this array is unchanged from before the flag existed, so
# default-mode behavior stays byte-for-byte identical. See deploy-headless.sh's header for the
# fuller rationale (DIR is the nvim config directory, not always $TARGET, always explicit).
declare -a NVIM_ARGS=(nvim --headless)
if [ -n "$MINIMAL_INIT_DIR" ]; then
  NVIM_ARGS+=(--clean --cmd "set rtp+=${MINIMAL_INIT_DIR}")
fi

TARGET="${TARGET:-$(pwd)}"

if [ ! -d "$TARGET" ]; then
  echo "ERROR: target is not a directory: $TARGET" >&2
  [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: target is not a directory: $TARGET"
  exit 2
fi
TARGET="$(cd "$TARGET" && pwd)"

CLAUDE_DIR="$TARGET/.claude"
if [ ! -d "$CLAUDE_DIR" ]; then
  echo "ERROR: no deploy tree at $CLAUDE_DIR -- nothing to verify." >&2
  echo "TARGET must be a repository root that already holds a deployed .claude/ tree -- never the agent-system/extensions source-store directory itself (which has no .claude/)." >&2
  echo "Run: bash deploy-headless.sh $TARGET" >&2
  echo "$(redeploy_remedy_fragment)" >&2
  [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: no deploy tree at $CLAUDE_DIR"
  exit 2
fi

if [ -n "$MINIMAL_INIT_DIR" ] && [ ! -d "$MINIMAL_INIT_DIR" ]; then
  echo "ERROR: --minimal-init directory does not exist: $MINIMAL_INIT_DIR" >&2
  [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: --minimal-init directory does not exist: $MINIMAL_INIT_DIR"
  exit 2
fi

# Phase 9 ("Shared Corpus Enumeration"): build the ONE master tracked-path corpus for this whole
# invocation, once, here -- before any gate runs -- rather than letting each of the six affected
# lints (lint-shellcheck.sh, lint-state-writer-boundary.sh, lint-scoped-commit-boundary.sh,
# lint-task-lookup-adoption.sh, lint-directory-pathspec-boundary.sh,
# lint-hook-registration-paths.sh) separately re-walk the same tree. Gated on
# _VD_GREG_LIB_LOADED (captured above, before the stub-assignment lines) rather than just
# re-checking `declare -F`: by the time we reach here every one of the six gate_registry_*
# functions is defined regardless (real or stub), so only the pre-stub flag distinguishes them.
# With no real lib, GATE_SHARED_CORPUS_FILE/_ROOT are simply never exported -- each affected
# lint's own common_shared_corpus_available check then reports unavailable and it takes its
# pre-existing standalone enumeration, identical to this script's every other degrade-safe path.
#
# Scoped to TARGET actually being the source store (TARGET/agent-system/extensions exists): a
# deploy-consumer TARGET has nothing for this corpus to cover anyway (every affected lint's own
# [SKIP] guard already short-circuits before reaching its FILES-collection code in that case), so
# building and exporting it there would be pure overhead with no consumer.
GATE_SHARED_CORPUS_FILE=""
GATE_SHARED_CORPUS_ROOT=""
if [ "${_VD_GREG_LIB_LOADED:-false}" = "true" ] && [ -d "$TARGET/agent-system/extensions" ]; then
  GATE_SHARED_CORPUS_FILE="$(gate_registry_shared_corpus_build "$TARGET")"
  GATE_SHARED_CORPUS_ROOT="$TARGET"
  export GATE_SHARED_CORPUS_FILE GATE_SHARED_CORPUS_ROOT
  trap '[ -n "${GATE_SHARED_CORPUS_FILE:-}" ] && rm -f "$GATE_SHARED_CORPUS_FILE"' EXIT
fi

# ORCHESTRATOR_BUDGET_GATE_MODE controls severity for gate20's two per-file ceiling sub-check
# (commands/orchestrate.md, skills/skill-orchestrate/SKILL.md against
# context/config/orchestrator-context-budget.json). Mirrors the SCHEMA_CONFORMANCE_GATE_MODE /
# STRICT_CORE_DEPLOY precedent (check-extension-docs.sh): one env-var default a maintainer flips
# in a follow-up commit, not a persisted auto-promotion counter. A first promotion attempt on
# 2026-10-01 was reverted same-day: a sibling commit (the `[HOLD]` status-marker change) grew
# commands/orchestrate.md to 21,328 B, 328 B over its own 21,000 B ceiling, just as
# skills/skill-orchestrate/SKILL.md and the eager-load total were brought under their ceilings by
# a deliberate duplication trim. Promotion to "hard" landed successfully later the same day
# (2026-10-01), once a restatement trim of commands/orchestrate.md's Options table rows
# (`--fast`/`--research`/`--plan`/`--implement`) and forced-phase Constraints bullet -- relocating
# duplicated detail behind pointers into docs/architecture/orchestrate-state-machine.md, the
# single authoritative long-form source -- brought the file to 19,024 B. Both per-file ceilings
# were clear at promotion time (commands/orchestrate.md 19,024 B / 21,000 B;
# skills/skill-orchestrate/SKILL.md 19,993 B / 20,000 B); neither ceiling_bytes nor
# eager_load.baseline_bytes in orchestrator-context-budget.json was moved to effect this
# promotion. Does NOT gate the eager-load regression check or the volatile-file check, both of
# which have their own fixed severity (see gate20 below).
ORCHESTRATOR_BUDGET_GATE_MODE="${ORCHESTRATOR_BUDGET_GATE_MODE:-hard}"

# VERIFY_DEPLOY_GATE8_JOBS controls Gate 8's concurrency request to run-all.sh's opt-in --jobs
# flag. Default 'auto' resolves to nproc capped at run-all.sh's own JOBS_CAP (4); see gate 8's
# call site below for the full precedence/rejected-alternatives record.
GATE8_JOBS="${VERIFY_DEPLOY_GATE8_JOBS:-auto}"

FAILURES=0
CHECKS=0
CURRENT_GATE="gate0"
# SKIPPED_CACHED: --skip-unchanged's own dedicated counter (never summed into CHECKS/FAILURES --
# a cache-skipped gate is neither a pass nor a fail, it simply did not run). GATE_RAN_LIST and
# GATE_DIRTY_LIST are per-gate bookkeeping for the SAME flag's write/invalidate decision: every
# pass()/fail()/warn() call appends $CURRENT_GATE to GATE_RAN_LIST (so "id present" means that
# gate registered at least one check and did NOT silently self-skip), and fail()/warn() ALSO
# append to GATE_DIRTY_LIST (so "id present" means that gate is not cache-write-eligible this
# run). Both are plain INDEXED arrays, reconciled across a concurrent batch via the exact same
# tail-append mechanism FINDINGS_LIST already relies on (gate_registry_exec_concurrent_batch's
# own header explains why this is required rather than cosmetic) -- an associative array would
# NOT reconcile correctly under that same mechanism, which is why these are not keyed maps.
# Neither array is read anywhere when SKIP_UNCHANGED is false; both are pure additive
# bookkeeping with zero effect on default-path output or exit codes.
SKIPPED_CACHED=0
GATE_RAN_LIST=()
GATE_DIRTY_LIST=()

say() { [ "$QUIET" = "true" ] || echo "$@"; }

pass() {
  CHECKS=$((CHECKS + 1))
  GATE_RAN_LIST+=("$CURRENT_GATE")
  say "  [PASS] $1"
}

# fail(): records a narrative failure (stderr, unchanged) AND, as a second consumer of the same
# single source, a findings-mode entry. The optional third argument overrides the finding text
# recorded for --findings (used where the narrative message embeds a numeric count that must not
# leak into the normalized finding, or where a caller extracts its own per-underlying-finding
# lines separately and passes "" here to suppress the default aggregate finding).
fail() {
  CHECKS=$((CHECKS + 1))
  FAILURES=$((FAILURES + 1))
  GATE_RAN_LIST+=("$CURRENT_GATE")
  GATE_DIRTY_LIST+=("$CURRENT_GATE")
  echo "  [FAIL] $1" >&2
  [ -n "${2:-}" ] && echo "         $2" >&2
  if [ $# -ge 3 ]; then
    [ -n "$3" ] && FINDINGS_LIST+=("FINDING $CURRENT_GATE $3")
  else
    FINDINGS_LIST+=("FINDING $CURRENT_GATE $1")
  fi
  return 0
}

# warn(): a WARN-level cousin of fail() for a gate whose notice must never flip the verifier's
# exit code, but should still be TRACKED on the ordinary `FINDING ` channel (e.g. gate20's
# per-file budget-ceiling check in its default ORCHESTRATOR_BUDGET_GATE_MODE=warn mode: the
# finding names a specific file a task's own modified_files can match, so it stays
# batch-attributable even though it never fails the run). Increments CHECKS but NEVER FAILURES.
# Echoes to stderr the same way fail() does, and appends to FINDINGS_LIST when FINDINGS mode is
# on. Appends to GATE_DIRTY_LIST UNCONDITIONALLY (not gated by $FINDINGS) -- that array is pure
# internal --skip-unchanged bookkeeping, never part of the public findings interface, so a warn
# must disqualify a gate from cache-write eligibility regardless of whether --findings was
# passed on this particular invocation.
#
# NOT the right function for a notice that must never escalate into the blocking findings
# channel at all (e.g. an unattributable, perpetually-recurring migration nudge) -- see
# warn_advisory() below for that case, and its header comment for why the two are kept separate
# rather than unified behind one severity parameter.
warn() {
  CHECKS=$((CHECKS + 1))
  GATE_RAN_LIST+=("$CURRENT_GATE")
  GATE_DIRTY_LIST+=("$CURRENT_GATE")
  echo "  [WARN] $1" >&2
  [ -n "${2:-}" ] && echo "         $2" >&2
  if [ "$FINDINGS" = "true" ]; then
    if [ $# -ge 3 ]; then
      [ -n "$3" ] && FINDINGS_LIST+=("FINDING $CURRENT_GATE $3")
    else
      FINDINGS_LIST+=("FINDING $CURRENT_GATE $1")
    fi
  fi
  return 0
}

# warn_advisory(): identical to warn() in every effect (the [WARN] stderr narrative, the CHECKS
# increment, and the GATE_DIRTY_LIST cache-ineligibility side effect) EXCEPT the findings-mode
# line prefix: "WARN-FINDING " instead of "FINDING ", a token the documented consumer filter
# `grep '^FINDING '` (deploy-baseline-lib.sh's deploy_findings_snapshot, reached from
# orchestrate-batch-gate.sh) does not match. Use this, never plain warn(), for a notice that must
# NEVER escalate into the batch-blocking findings channel -- gate16's
# routing_hard/routing_agents_hard absence guard (a reappearance of either retired key is
# unattributable to any one task, since it could land via any extension's manifest edit) and
# gate8's all-expected branch (a declared-expected test failure is visible but never
# batch-blocking) are the two call sites.
#
# Deliberately a SEPARATE function rather than a shared severity parameter on warn(): warn()'s
# other caller (gate20's per-file budget-ceiling check) relies on today's FINDING-based tracking
# to stay batch-attributable (the finding names a specific file a task's own modified_files can
# match), even though that WARN never fails the run either -- collapsing both callers onto one
# severity-parameterized function would make it too easy to flip gate20's attributability by
# accident while touching gate16 or gate8. Giving the non-escalating case its own name keeps the
# two intentions separable at every call site.
#
# This is NOT the gate-silencing the source-store boundary task's defect record forbids: that
# refers specifically to deleting a manifest declaration purely to stop a gate from noticing it,
# while the underlying behavior the declaration controlled stays live. gate16's absence case is
# the opposite: routing_agents_hard is retired as a genuinely completed migration -- the
# resolution code path (`command-route-agent.sh`'s former hard branch) is deleted too, not merely
# the manifest declaration that fed it -- so the `pass` line it now emits reports a real, durable
# absence, not a silenced symptom of a still-live mechanism. The WARN path above remains ready for
# the day either key regresses: `gate16_run()` keeps running, keeps emitting its `[WARN]` stderr
# narrative, its CHECKS increment, and its GATE_DIRTY_LIST cache-ineligibility side effect on a
# hit, unconditionally. Only the escalation of a deliberately non-blocking warning into the
# batch-blocking `^FINDING ` channel changes.
warn_advisory() {
  CHECKS=$((CHECKS + 1))
  GATE_RAN_LIST+=("$CURRENT_GATE")
  GATE_DIRTY_LIST+=("$CURRENT_GATE")
  echo "  [WARN] $1" >&2
  [ -n "${2:-}" ] && echo "         $2" >&2
  if [ "$FINDINGS" = "true" ]; then
    if [ $# -ge 3 ]; then
      [ -n "$3" ] && FINDINGS_LIST+=("WARN-FINDING $CURRENT_GATE $3")
    else
      FINDINGS_LIST+=("WARN-FINDING $CURRENT_GATE $1")
    fi
  fi
  return 0
}

# gate_selected N: returns 0 (selected) when GATES_FILTER is empty (default: all gates) or
# contains N as one of its comma-separated tokens; returns 1 otherwise. Every one of the 22
# guarded gate blocks below consults this single predicate -- gate0 itself is never guarded by it
# (see the --only-gate header doc above).
gate_selected() {
  local n="$1"
  [ -z "$GATES_FILTER" ] && return 0
  case ",${GATES_FILTER}," in
    *",${n},"*) return 0 ;;
    *) return 1 ;;
  esac
}


# ─────────────────────────────────────────────────────────────────────────────
# GATE FUNCTIONS 1-27 -- all migrated onto the declarative gate registry
# (scripts/gate-registry.data, scripts/lib/gate-registry-lib.sh). Each function body
# below is the UNMODIFIED original gate block (including its own internal
# `if gate_selected N; then ... fi` guard, now redundant with the registry's own
# selection check but kept verbatim for byte-identical output -- see this task's
# plan, Phase 4, for why a full generic-guard fold was judged unsafe for gates
# with non-uniform SKIP message shapes). Phase 4 migrated gates 1-8; Phase 5 completed
# the migration with gates 9-23, retiring the last inline copy-pasted blocks. The single
# `for _gate_id in $(gate_registry_ids); do "gate${_gate_id}_run"; done` loop near the end of
# this file (after every gateN_run definition) is the one call site that executes all of them,
# in ascending numeric order (gate_registry_ids sorts its ids), matching the pre-migration
# execution order byte-for-byte.

# ── 1. Core event-store and error-store files present ─────────────────────────
# Covers two store families: the passive-signal-capture stack (events.jsonl: append-only script,
# query script, both hooks, schema, format doc) and the error-tracking stack (errors.json:
# validated append/update writer, schema, format doc). A missing entry means the deploy predates
# that store's work or was a partial sync.
gate1_run() {
if gate_selected 1; then
say "1. Event-store and error-store files (ls .claude/{scripts,hooks,context}/...)"
CURRENT_GATE="gate1"
for rel in \
  scripts/events-append.sh \
  scripts/events-query.sh \
  hooks/events-log-artifact.sh \
  hooks/events-log-lifecycle.sh \
  context/schemas/events-schema.json \
  context/formats/events-format.md \
  scripts/errors-append.sh \
  context/schemas/errors-schema.json \
  context/formats/errors-format.md
do
  if [ -e "$CLAUDE_DIR/$rel" ]; then
    pass "$rel"
  else
    fail "$rel is missing" "run deploy-headless.sh to regenerate. $(redeploy_remedy_fragment)"
  fi
done
say ""

fi
}

# ── 2. Hook registrations in the deployed settings.json ──────────────────────
# The single most failure-prone part of a deploy: settings.json is install-once, so additions
# reach an existing repo only through merge-sources/settings-hooks.json. A tree can have every
# hook SCRIPT present and still register none of them.
gate2_run() {
if gate_selected 2; then
say "2. Hook registrations (jq '.hooks' .claude/settings.json)"
CURRENT_GATE="gate2"
SETTINGS="$CLAUDE_DIR/settings.json"
if [ ! -f "$SETTINGS" ]; then
  fail "settings.json is missing"
elif ! command -v jq >/dev/null 2>&1; then
  fail "jq unavailable; cannot inspect hook registrations"
elif ! jq empty "$SETTINGS" 2>/dev/null; then
  fail "settings.json is not valid JSON"
else
  for pair in "PostToolUse:events-log-artifact.sh" \
              "Stop:events-log-lifecycle.sh" \
              "SubagentStop:events-log-lifecycle.sh"
  do
    event="${pair%%:*}"
    script="${pair##*:}"
    n=$(jq --arg e "$event" --arg s "$script" \
      '[.hooks[$e][]?.hooks[]? | select(.command | test($s))] | length' "$SETTINGS" 2>/dev/null)
    n="${n:-0}"
    if [ "$n" -ge 1 ]; then
      pass "$event -> $script registered"
    else
      fail "$event -> $script NOT registered" \
           "add it to merge-sources/settings-hooks.json, not root-files/settings.json"
    fi
  done

  # Duplicate detection. Reported as a warning, never a failure: the merge is add-only and
  # cannot remove a pre-existing entry, so a duplicate is a manual-cleanup item rather than
  # something a regeneration could ever fix. Failing on it would make this script permanently
  # red on any tree that has ever accumulated one.
  dupes=$(jq -r '
    [.hooks | to_entries[] | .key as $e | .value[]?.hooks[]?.command
     | select(. != null) | "\($e)\t\(.)"]
    | group_by(.) | map(select(length > 1) | {cmd: .[0], n: length}) | .[]
    | "\(.cmd) x\(.n)"' "$SETTINGS" 2>/dev/null)
  if [ -n "$dupes" ]; then
    say ""
    say "  [WARN] duplicate hook command registrations (manual cleanup; no merge can remove these):"
    while IFS= read -r line; do
      [ -n "$line" ] && say "         $line"
    done <<< "$dupes"
  fi
fi
say ""

fi
}

# ── 3. Doc-lint gate ─────────────────────────────────────────────────────────
# Only meaningful in the source-store repo. A deploy consumer has no agent-system/extensions
# directory, and the gate correctly errors there -- that is not a deploy failure.
gate3_run() {
if gate_selected 3; then
say "3. Doc-lint (check-extension-docs.sh --quiet)"
CURRENT_GATE="gate3"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- doc-lint does not apply"
elif [ ! -x "$CLAUDE_DIR/scripts/check-extension-docs.sh" ] && [ ! -f "$CLAUDE_DIR/scripts/check-extension-docs.sh" ]; then
  fail "check-extension-docs.sh not deployed"
else
  # Capture rather than discard: check-extension-docs.sh's `[ext_name]`/`[project-wide]` headers
  # and its `FAIL:` lines are unconditional echo (they survive that script's own --quiet), so a
  # single --quiet capture is enough to extract per-finding detail below. This generalizes the
  # STRICT_CORE_DEPLOY re-invocation precedent already used later in this same gate, rather than
  # introducing a new mechanism.
  doc_lint_output=$(cd "$TARGET" && bash "$CLAUDE_DIR/scripts/check-extension-docs.sh" --quiet 2>&1)
  doc_lint_exit=$?
  if [ "$doc_lint_exit" -eq 0 ]; then
    pass "doc-lint reports no failures"
  else
    # Third arg "" suppresses the default aggregate finding -- the per-underlying-FAIL: lines
    # extracted below are the findings-mode representation of this failure, not this message.
    fail "doc-lint reported failures" \
         "re-run without --quiet for detail: bash .claude/scripts/check-extension-docs.sh" ""
    if [ "$FINDINGS" = "true" ]; then
      current_header="[unknown]"
      while IFS= read -r doc_lint_line; do
        case "$doc_lint_line" in
          "["*"]")
            current_header="$doc_lint_line"
            ;;
          "  FAIL: "*)
            # ADVISORY: lines are deliberately excluded (Decision 3) -- only this FAIL: case
            # matches; check-extension-docs.sh exits non-zero on FAIL only, never on ADVISORY.
            FINDINGS_LIST+=("FINDING gate3 ${current_header} ${doc_lint_line#  }")
            ;;
        esac
      done <<< "$doc_lint_output"
    fi
  fi

  # Reconstructed, not re-run: check-extension-docs.sh's advisory() unconditionally echoes
  # "  ADVISORY: $msg" and only ADDITIONALLY calls fail() (which echoes "  FAIL: $msg" with the
  # identical $msg) when STRICT_CORE_DEPLOY=1 -- advisory() itself is never conditioned on that
  # variable, and no other line in the script's output is mode-dependent. A strict pass's stdout
  # is therefore always exactly doc_lint_output (the pass just captured above) plus one extra
  # "  FAIL: $msg" line per "  ADVISORY: $msg" line doc_lint_output already contains, with
  # byte-identical $msg text. grep -c 'events-' over that reconstructed stream is provably the
  # same count a second full invocation would produce: the baseline matches already in
  # doc_lint_output, plus one more per matching advisory line (the line strict mode would
  # duplicate as a FAIL). Deriving it this way is not an approximation of the second pass; it
  # computes the identical number from the first pass's already-captured output, which is why no
  # second full-corpus invocation of check-extension-docs.sh is needed here at all.
  strict_baseline_hits=$(printf '%s\n' "$doc_lint_output" | grep -c 'events-')
  strict_advisory_hits=$(printf '%s\n' "$doc_lint_output" | grep '^  ADVISORY: ' | grep -c 'events-')
  strict_hits=$((strict_baseline_hits + strict_advisory_hits))
  if [ "${strict_hits:-0}" -eq 0 ]; then
    pass "STRICT_CORE_DEPLOY reports no undeployed event files"
  else
    # Finding text (3rd arg) omits the numeric count (Decision 4) -- the condition is boolean
    # ("the deploy tree is behind the source store"); magnitude drift inside an already-failing
    # check must not manufacture a spurious "new" finding for the pre/post comparison.
    fail "STRICT_CORE_DEPLOY still reports $strict_hits event-file line(s)" \
         "the deploy tree is behind the source store" \
         "STRICT_CORE_DEPLOY reports undeployed event file(s): the deploy tree is behind the source store"
  fi
fi

say ""

fi
}

# ── 4. Task-reference lint gate ───────────────────────────────────────────────
# This gate's SKIP guard used to mirror gate 3's (source-store-only) guard above, on the premise
# that it needed the same condition for the same reason. That premise is disproved:
# check-extension-docs.sh genuinely errors without an agent-system/extensions directory (gate 3's
# guard is correct and stays as-is), but check-task-references.sh carries no such dependency --
# it is repo-appropriate by construction (git ls-files repo-wide minus specs/**) and scans a
# deploy-consumer repo in full, finding real citation debt there if any exists. So this gate now
# runs unconditionally, taking the no-guard shape gates 1/2/14/16 already use. This disproof is
# scoped to gate 4 only: the remaining source-store-conditioned guards on the other gates are
# UNAUDITED by this change, not presumed removable by the same argument.
gate4_run() {
if gate_selected 4; then
say "4. Task-reference lint (check-task-references.sh --quiet)"
CURRENT_GATE="gate4"
if [ ! -x "$CLAUDE_DIR/scripts/check-task-references.sh" ] && [ ! -f "$CLAUDE_DIR/scripts/check-task-references.sh" ]; then
  fail "check-task-references.sh not deployed"
else
  # Leave this --quiet invocation verbatim (unlike gate 3, its per-finding `path:line:content`
  # detail is gated by that script's own info() and does NOT survive --quiet -- only the summary
  # counts and the final FAIL:/PASS: line do). Detail requires the WITHOUT-quiet re-invocation
  # below, done only when a finding-mode caller needs it and the gate already failed.
  if (cd "$TARGET" && bash "$CLAUDE_DIR/scripts/check-task-references.sh" --quiet >/dev/null 2>&1); then
    pass "task-reference lint reports no findings"
  else
    fail "task-reference lint reported findings" \
         "re-run without --quiet for detail: bash .claude/scripts/check-task-references.sh" ""
    if [ "$FINDINGS" = "true" ]; then
      task_ref_output=$(cd "$TARGET" && bash "$CLAUDE_DIR/scripts/check-task-references.sh" 2>&1)
      while IFS= read -r task_ref_line; do
        FINDINGS_LIST+=("FINDING gate4 ${task_ref_line#  }")
      done < <(printf '%s\n' "$task_ref_output" | grep -E '^  [^:]+:[0-9]+:')
    fi
  fi
fi

fi
}

# ── 5. Manifest-driven category parity + content-hash equality (verify.lua) ──────
# Extends gates 1-4 (which check specific known files/registrations) to full declared-vs-
# deployed parity plus content-hash equality across every provides.* category the manifest
# declares, driven by neotex.plugins.ai.shared.extensions.verify's manager.verify_all -- the
# same check the extension loader itself runs after a load. Only meaningful in the source-store
# repo (a deploy consumer has no agent-system/extensions/core/ source directory to diff against),
# mirroring gates 3-4's SKIP-if-not-source-store precedent.
gate5_run() {
if gate_selected 5; then
say "5. Manifest-driven category parity + content-hash equality (verify.lua)"
CURRENT_GATE="gate5"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- this gate compares against"
  say "         the source store and does not apply here"
elif ! command -v nvim >/dev/null 2>&1; then
  fail "nvim not found on PATH; cannot run the manifest-driven verification"
else
  verify_output=$(cd "$TARGET" && "${NVIM_ARGS[@]}" \
    -c "lua local ok1, ext_config = pcall(require, 'neotex.plugins.ai.shared.extensions.config'); local ok2, ext_init = pcall(require, 'neotex.plugins.ai.shared.extensions.init'); if not (ok1 and ok2) then print('VERIFY_ERROR require: ' .. tostring(ok1 and ext_init or ext_config)) else local manager = ext_init.create(ext_config.claude()); local pok, results = pcall(manager.verify_all, '${TARGET}'); if not pok then print('VERIFY_ERROR call: ' .. tostring(results)) else for _, v in ipairs(results) do if v.status ~= 'passed' then for _, err in ipairs(v.errors or {}) do print('VERIFY_FINDING ' .. v.extension .. ': ' .. err) end end end print('VERIFY_DONE count=' .. tostring(#results)) end end" \
    -c "qa!" 2>&1)

  if echo "$verify_output" | grep -q 'VERIFY_ERROR'; then
    verify_error_line=$(echo "$verify_output" | grep 'VERIFY_ERROR' | head -1)
    fail "manifest-driven verification could not run" "$verify_error_line" \
         "manifest-driven verification could not run: $verify_error_line"
  elif ! echo "$verify_output" | grep -q 'VERIFY_DONE'; then
    fail "manifest-driven verification produced no result" \
         "re-run: nvim --headless -c \"lua ...manager.verify_all(...)\"" \
         "manifest-driven verification produced no result"
  else
    # Unanchored (not '^VERIFY_FINDING '): nvim can prepend a terminal OSC7 cwd-reporting escape
    # sequence to its first stdout line with no newline separator, which would otherwise defeat a
    # start-of-line anchor. Mirrors deploy-headless.sh's own unanchored 'grep -o DEPLOY_COUNT=...'
    # extraction of the same headless-nvim-output family, for the same reason.
    verify_finding_count=$(echo "$verify_output" | grep -c 'VERIFY_FINDING ')
    if [ "$verify_finding_count" -eq 0 ]; then
      pass "declared-vs-deployed parity and content-hash equality (all loaded extensions)"
    else
      # Third arg "" suppresses the default aggregate finding -- the per-underlying-VERIFY_FINDING
      # lines extracted below are the findings-mode representation of this failure, mirroring
      # gate 3's doc-lint per-FAIL: line extraction. The loop below ALSO prints each finding to
      # the operator-visible stderr stream unconditionally (fail()'s own [FAIL]/hint lines are
      # not gated by --quiet either, so this is consistent with the rest of the gate's output),
      # independent of --findings -- see context/patterns/deploy-orphan-detection.md's fail-time
      # detail subsection for why: without this, "re-run for detail" was a false promise, since
      # the per-finding lines were previously appended to FINDINGS_LIST only.
      fail "manifest-driven verification reported $verify_finding_count finding(s)" \
           "see findings below" ""
      while IFS= read -r verify_finding_line; do
        # -o 'VERIFY_FINDING .*' extracts from the token onward regardless of what (if anything)
        # precedes it on the line -- same OSC7 robustness rationale as verify_finding_count above.
        # '#*VERIFY_FINDING ' (not '#VERIFY_FINDING ') strips everything up to and including the
        # token wherever it falls, not only at position 0.
        verify_finding_detail="${verify_finding_line#*VERIFY_FINDING }"
        echo "         - $verify_finding_detail" >&2
        if [ "$FINDINGS" = "true" ]; then
          FINDINGS_LIST+=("FINDING gate5 $verify_finding_detail")
        fi
      done < <(echo "$verify_output" | grep -o 'VERIFY_FINDING .*')
    fi
  fi
fi

say ""

fi
}

# ── 6. Agent contracts lint gate ──────────────────────────────────────────────
# Only meaningful in the source-store repo, mirroring gates 3-4's SKIP-if-not-source-store
# precedent -- a deploy consumer has no agent-system/extensions directory and the gate correctly
# skips there.
gate6_run() {
if gate_selected 6; then
say "6. Agent contracts lint (lint-agent-contracts.sh --verbose)"
CURRENT_GATE="gate6"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- agent contracts lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh" ]; then
  fail "lint-agent-contracts.sh not found in source store"
else
  agent_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh" --verbose 2>&1)
  agent_lint_status=$?
  if [ "$agent_lint_status" -eq 0 ]; then
    pass "agent contracts lint reports no failures"
  else
    fail "agent contracts lint reported failures" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r agent_lint_line; do
        FINDINGS_LIST+=("FINDING gate6 $agent_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[FAIL]' "$agent_lint_output")
    fi
  fi
fi

fi
}

# ── 7. Routing wiring lint gate ───────────────────────────────────────────────
# Only meaningful in the source-store repo, mirroring gates 3-4/6's SKIP-if-not-source-store
# precedent -- a deploy consumer has no agent-system/extensions directory and the gate correctly
# skips there.
gate7_run() {
if gate_selected 7; then
say "7. Routing wiring lint (lint-routing-wiring.sh --verbose)"
CURRENT_GATE="gate7"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- routing wiring lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh" ]; then
  fail "lint-routing-wiring.sh not found in source store"
else
  routing_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh" --verbose 2>&1)
  routing_lint_status=$?
  if [ "$routing_lint_status" -eq 0 ]; then
    pass "routing wiring lint reports no failures"
  else
    fail "routing wiring lint reported failures" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r routing_lint_line; do
        FINDINGS_LIST+=("FINDING gate7 $routing_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[FAIL]' "$routing_lint_output")
    fi
  fi
fi

fi
}

# ── 8. Shell test suite runner (run-all.sh) ───────────────────────────────────
# Only meaningful in the source-store repo, mirroring gates 3-4/6-7's SKIP-if-not-source-store
# precedent -- a deploy consumer has no agent-system/extensions directory and the gate correctly
# skips there.
#
# specs/.gate-lock bracket: only Gate 8's own run-all.sh invocation below is bracketed with the
# repo-scoped specs/.gate-lock mutex -- the other 22 gates are never serialized, and a
# --skip-slow or Gate-8-excluding --only-gate run touches the mutex not at all (both exit via a
# branch above this comment, before the bracket is ever reached). The bracket invokes the
# DEPLOYED task-lock.sh ($TARGET/.claude/scripts/task-lock.sh), matching gate 9/gate 10's
# deployed-sub-check pattern, because the SOURCE-STORE copy cannot be invoked (it sources
# deploy-root-guard.sh, which exits 1 for any scripts/ directory not under .claude/ or
# .opencode/) -- unlike gate 9/10, an ABSENT deployed copy here means skip coordination with a
# named `say` Note, never a gate failure (coordination is optional, verification is not).
# Acquisition is skipped (no mutex touched) when this verify-deploy.sh invocation is itself
# nested (VERIFY_DEPLOY_WAS_NESTED_AT_ENTRY, captured before this script's own unconditional
# VERIFY_DEPLOY_NESTED export, was already 1 at entry -- e.g. a suite under Gate 8's own
# run-all.sh that shells back out to verify-deploy.sh) or when an outer holder already exported
# GATE_MUTEX_HELD=1 (this gate runs as a guest). On a real acquisition, GATE_MUTEX_HELD=1 is
# exported so the child run-all.sh invocation below sees it inherited and performs no second
# acquire. On any other acquire failure this fails OPEN with the same shaped WARNING: line as
# tests/run-all.sh's own bracket (mirroring git-commit-scoped.sh's specs/.commit-lock posture);
# Gate 8's own verdict, FINDING lines, and summary output are unaffected by anything in this
# bracket. Release is explicit immediately after the run-all.sh capture, on both the success and
# failure path -- the general rule for this script's exit paths is still "gate-scoped rather than
# process-scoped", i.e. no script-wide EXIT trap. This ONE bracket is the deliberate, narrow
# exception: a backgrounded caller's process group can be torn down (SIGTERM/SIGHUP/SIGINT) while
# this bracket is mid-run-all.sh, which otherwise leaves specs/.gate-lock held by a provably dead
# pid until its 1800s staleness window elapses -- a 30-minute stall other sessions' gate batteries
# block on. To close that without reopening the process-scoped-EXIT-trap question, the bracket
# arms a SIGNAL-scoped trap (INT/TERM/HUP only, never EXIT) for exactly the window it owns the
# mutex: on receipt, _gate8_signal_cleanup releases the token, unconditionally disarms the same
# three signals (`trap - INT TERM HUP`), and re-raises the signal so the process still terminates
# with that signal's ordinary default disposition (never silently swallowing the kill). It is
# compatible with the gate-scoped design precisely because it is disarmed at the SAME explicit
# release point below on the ordinary path too, so it is never left armed across any other gate's
# exit path -- unlike a script-wide EXIT trap, which would fire on every gate's unrelated exit and
# have to re-derive whether this bracket even still owns the mutex. SIGKILL cannot be trapped by
# any shell script, so that one case is deliberately NOT covered by this trap and is left to the
# pre-existing GATE_MUTEX_STALE_SEC staleness self-heal (1800s default): a SIGKILL'd holder still
# leaves the mutex held, but only for a bounded 30-minute stall, never a permanent deadlock. A
# generic "reclaim if the recorded owner pid is confirmably dead" fast path was prototyped in
# task-lock.sh's acquire_named_mutex() as a SIGKILL backstop and reverted -- it is unsound for
# this and every other acquire_named_mutex() caller, because the pid recorded in
# $mutex_dir/owner is the short-lived `gate-acquire` CLI invocation's own pid (already, correctly,
# dead moments after a successful acquire), not this long-lived verify-deploy.sh process's pid;
# see that function's own header comment for the full account, including the concrete
# serialization-breaking test failure that caught it. See
# context/patterns/batch-orchestration-guardrails.md for the full contract.
#
# Expected-versus-NEW verdict (three-way branch, not two): the run-all.sh invocation below passes
# --fail-on-new, so $run_all_status is 0 whenever run-all.sh classified zero failures as NEW --
# including a run where one or more EXPECTED failures occurred (a basename match against the
# committed tests/known-failures.txt manifest; a missing/truncated manifest degrades to today's
# behavior, every failure classifies NEW). That alone cannot tell "zero failures" apart from
# "zero NEW failures", so a second signal -- the PRESENCE of run-all.sh's own
# "[run-all] Failing suites (" roster header, which it prints unconditionally whenever any suite
# failed -- discriminates the two. Presence is detected only, never the numeric tally, because a
# header's existence is the more stable contract; the degrade direction is deliberately safe (if
# the header ever disappeared, an all-expected run would read as PASS -- a visibility loss, never
# a missed NEW failure, since --fail-on-new independently guarantees a NEW failure yields a
# non-zero exit). The three branches:
#   - exit 0, no roster header      -> pass()          (clean: every discovered suite passed)
#   - exit 0, roster header present -> warn_advisory()  (all-expected: non-blocking but visible)
#   - exit non-zero                 -> fail()           (at least one NEW failure: unchanged)
# warn_advisory(), not pass() or plain warn(), for the all-expected branch: pass() would make
# this gate cache-write-eligible under --skip-unchanged, caching a warm PASS over a corpus that
# genuinely has failing suites, while warn()'s plain `FINDING ` line would still reach
# deploy_findings_snapshot's batch-blocking filter. warn_advisory() increments CHECKS (so a
# --only-gate 8 selection over an all-expected run still counts a check rather than tripping the
# zero-check-under-filter exit-2 branch), appends to GATE_DIRTY_LIST (preserving today's
# cache-invalidation behavior exactly), and emits `WARN-FINDING gate8 ...` rather than
# `FINDING gate8 ...`, a channel deploy_findings_snapshot's strict `grep '^FINDING '` does not
# match -- so an all-expected run contributes zero rows to that snapshot in any capture, and the
# NEW-failure fail() branch, its FINDINGS_LIST loop, and its verify_deploy_extract_verdict_lines
# '[FAIL]' anchored extraction are all unchanged. Known accepted residual: in a run containing at
# least one NEW failure, that unchanged extraction still folds every failing suite's line into
# FINDINGS_LIST, EXPECTED ones included -- unchanged from today, and out of scope here (closing it
# would need a second NEW-specific anchor emitted by run-all.sh, or a roster cross-reference
# inside this function). known-failures.txt is advisory and human-maintained (see its own header
# for the needs-owner convention); this gate now trusts its classification more directly than
# before, so a stale row understates NEW churn until the manifest is corrected.
_gate8_signal_cleanup() {
  local sig="$1"
  if [ "$GATE8_MUTEX_OWNED_HERE" = "true" ]; then
    bash "$GATE8_TASK_LOCK_SH" gate-release "$GATE8_MUTEX_TOKEN" >&2 || true
    GATE8_MUTEX_OWNED_HERE="false"
    unset GATE_MUTEX_HELD
  fi
  trap - INT TERM HUP
  kill -s "$sig" "$$"
}
gate8_run() {
if gate_selected 8; then
say "8. Shell test suite runner (tests/run-all.sh)"
CURRENT_GATE="gate8"
if [ "$SKIP_SLOW" = "true" ]; then
  say "  [SKIP] --skip-slow: shell test suite deferred (run without --skip-slow for the full gate)"
elif [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- run-all.sh does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/tests/run-all.sh" ]; then
  fail "tests/run-all.sh not found in source store"
else
  # Request run-all.sh's opt-in parallelism (default 'auto'; override via
  # VERIFY_DEPLOY_GATE8_JOBS, e.g. '1' on a nproc=1 or memory-pressured/heavily-loaded host).
  # VERIFY_DEPLOY_GATE8_JOBS always wins when set; the value is passed through verbatim and
  # validated by run-all.sh alone (single source of validation truth) -- no silent fallback here.
  # Rejected alternatives (do not re-propose): a bare hardcoded `4` (not host-adaptive; identical
  # to `auto` only on hosts with nproc >= 4); a conservative fixed `2` (leaves measured headroom
  # unused and still needs the same override); reusing a generic `JOBS` env name (too broad,
  # collides with unrelated tooling); gating on TTY-ness (implicit, untestable, surprising).
  # run-all.sh's own nested-invocation guard (RUN_ALL_NESTED) still forces JOBS=1 when this
  # verify-deploy.sh invocation is itself reached from inside another run-all.sh's suite,
  # regardless of what --jobs requests here -- unaffected by this change.
  # specs/.gate-lock acquire (see this function's header comment above for the full contract).
  GATE8_MUTEX_TOKEN=""
  GATE8_MUTEX_OWNED_HERE="false"
  GATE8_TASK_LOCK_SH="$TARGET/.claude/scripts/task-lock.sh"
  if [ "$VERIFY_DEPLOY_WAS_NESTED_AT_ENTRY" = "1" ]; then
    say "  Note: this verify-deploy.sh invocation is nested (VERIFY_DEPLOY_NESTED was already 1 at entry); specs/.gate-lock is not touched -- the outer invocation is responsible for holding it."
  elif [ -n "${GATE_MUTEX_HELD:-}" ]; then
    say "  Note: an outer holder already owns the specs/.gate-lock mutex (GATE_MUTEX_HELD=1 inherited); running as guest, no nested acquire."
  elif [ ! -f "$GATE8_TASK_LOCK_SH" ]; then
    say "  Note: deployed task-lock.sh not found at '$GATE8_TASK_LOCK_SH'; specs/.gate-lock coordination is skipped for this gate (fail-open: coordination is optional, verification is not)."
  else
    gate8_token=""
    if gate8_token=$(bash "$GATE8_TASK_LOCK_SH" gate-acquire "verify-deploy-gate8-$$"); then
      GATE8_MUTEX_TOKEN="$gate8_token"
      GATE8_MUTEX_OWNED_HERE="true"
      export GATE_MUTEX_HELD=1
      # Signal-scoped trap armed for exactly this bracket's duration -- see this function's
      # header comment above for the full rationale. Disarmed at the explicit release below on
      # the ordinary path, or by _gate8_signal_cleanup itself on the signal path.
      trap '_gate8_signal_cleanup INT' INT
      trap '_gate8_signal_cleanup TERM' TERM
      trap '_gate8_signal_cleanup HUP' HUP
    else
      echo "WARNING: failed to acquire specs/.gate-lock mutex (session=verify-deploy-gate8-$$); proceeding unserialized (non-blocking, fail-open). Worst case: contention with a sibling session's full gate-set battery persists for this run; verification itself is neither skipped nor altered by this mutex -- Gate 8's own verdict, FINDING lines, and summary output are unaffected. Mirrors git-commit-scoped.sh's specs/.commit-lock fail-open posture and its explicit refusal to cite an unreproduced result as settled." >&2
    fi
  fi

  run_all_output=$(cd "$TARGET" && bash "$TARGET/agent-system/extensions/core/scripts/tests/run-all.sh" --quiet --jobs "$GATE8_JOBS" --fail-on-new 2>&1)
  run_all_status=$?

  # Release on every path out of the bracket (success and failure alike) -- explicit, mirroring
  # the signal path's own release in _gate8_signal_cleanup. Disarm the signal-scoped trap here
  # too so it is never left armed across any gate that runs after this one.
  if [ "$GATE8_MUTEX_OWNED_HERE" = "true" ]; then
    bash "$GATE8_TASK_LOCK_SH" gate-release "$GATE8_MUTEX_TOKEN" >&2 || true
    GATE8_MUTEX_OWNED_HERE="false"
    unset GATE_MUTEX_HELD
    trap - INT TERM HUP
  fi

  # Expected-versus-NEW discriminator: --fail-on-new (above) makes $run_all_status reflect
  # run-all.sh's own EXPECTED/NEW accounting rather than a bare "any failure" exit code --
  # $run_all_status is 0 whenever no failure was classified NEW, including the case where one
  # or more EXPECTED failures occurred. That alone collapses "zero failures" and "zero NEW
  # failures" into the same exit code, so a second, independent signal is needed to tell them
  # apart: the PRESENCE of run-all.sh's own roster header ("[run-all] Failing suites ("), which
  # it prints unconditionally whenever any suite failed, EXPECTED or not. Detecting presence
  # only (never parsing the numeric tally) is deliberate -- see the header comment above
  # gate8_run() for the full degrade-direction rationale.
  run_all_had_failing_suites="false"
  case "$run_all_output" in
    *$'\n''[run-all] Failing suites ('*) run_all_had_failing_suites="true" ;;
    '[run-all] Failing suites ('*) run_all_had_failing_suites="true" ;;
  esac

  if [ "$run_all_status" -eq 0 ] && [ "$run_all_had_failing_suites" = "false" ]; then
    pass "run-all.sh: all discovered suites passed"
  elif [ "$run_all_status" -eq 0 ] && [ "$run_all_had_failing_suites" = "true" ]; then
    # All-expected outcome: --fail-on-new already certified zero NEW failures, so this is
    # non-blocking (never fail()/FAILURES) but still visible and trackable -- warn_advisory(),
    # not pass() (would make this gate cache-write-eligible under --skip-unchanged, caching a
    # warm PASS over a corpus that genuinely has failing suites) and not warn() (its plain
    # `FINDING ` line would still reach deploy_findings_snapshot's batch-blocking filter).
    run_all_tally_line="$(printf '%s\n' "$run_all_output" | grep -E '^\[run-all\] [0-9]+ passed, ' | tail -n1)"
    warn_advisory "run-all.sh: all failing suites are declared-expected (no NEW failure)" \
         "${run_all_tally_line:-see tests/known-failures.txt}; re-run for detail: bash agent-system/extensions/core/scripts/tests/run-all.sh" \
         "run-all.sh: all failing suites are declared-expected (no NEW failure) -- ${run_all_tally_line:-see tests/known-failures.txt}"
  else
    run_all_remedy="re-run for detail: bash agent-system/extensions/core/scripts/tests/run-all.sh"
    [ "$run_all_status" -eq 2 ] && run_all_remedy="$run_all_remedy (exit 2 may indicate an invalid VERIFY_DEPLOY_GATE8_JOBS value: '$GATE8_JOBS')"
    fail "run-all.sh reported failing or undiscoverable suites (exit $run_all_status)" \
         "$run_all_remedy" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r run_all_line; do
        FINDINGS_LIST+=("FINDING gate8 $run_all_line")
      done < <(verify_deploy_extract_verdict_lines '[FAIL]' "$run_all_output")
    fi
  fi
fi

say ""

fi
}

say "[verify-deploy] Target: $TARGET"
say ""

# ── 9. Postflight boundary lint gate ──────────────────────────────────────────
# Only meaningful in the source-store repo, mirroring gate 6's SKIP-if-not-source-store
# precedent -- a deploy consumer has no agent-system/extensions directory and the gate correctly
# skips there. UNLIKE gates 6-7, this gate invokes the DEPLOYED copy of the script
# ($TARGET/.claude/scripts/lint/lint-postflight-boundary.sh), not the source-store one: the
# script's own PROJECT_ROOT resolution (common_repo_root "$SCRIPT_DIR" 3) assumes a 3-levels-up
# depth that only lands on the repo root from the deployed path
# (.claude/scripts/lint -> .claude/scripts -> .claude -> repo root); invoking the source-store
# copy would resolve PROJECT_ROOT to agent-system/extensions instead and silently scan nothing.
# This also matches the script's own default scan targets ($PROJECT_ROOT/.claude/skills,
# $PROJECT_ROOT/.claude/extensions) -- it is designed to audit deployed content, not source.
gate9_run() {
if gate_selected 9; then
say "9. Postflight boundary lint (lint-postflight-boundary.sh, full corpus)"
CURRENT_GATE="gate9"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- postflight boundary lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh" ]; then
  fail "lint-postflight-boundary.sh not found in source store"
elif [ ! -f "$TARGET/.claude/scripts/lint/lint-postflight-boundary.sh" ]; then
  fail "lint-postflight-boundary.sh not found in deployed tree (run deploy-headless.sh first)" "$(redeploy_remedy_fragment)"
else
  postflight_lint_output=$(cd "$TARGET" && bash "$TARGET/.claude/scripts/lint/lint-postflight-boundary.sh" --verbose 2>&1)
  postflight_lint_status=$?
  if [ "$postflight_lint_status" -eq 0 ]; then
    pass "postflight boundary lint reports no failures (full corpus)"
  else
    fail "postflight boundary lint reported failures" \
         "re-run for detail: bash .claude/scripts/lint/lint-postflight-boundary.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r postflight_lint_line; do
        FINDINGS_LIST+=("FINDING gate9 $postflight_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[VIOLATION]' "$postflight_lint_output")
    fi
  fi
fi

# Anchor-pointer collapse regression lint rides this gate rather than claiming a new gate row
# (per context/standards/anchor-pointer-convention.md and this task's own no-new-gate-row
# default): both checks are full-corpus markdown-content-presence lints over the source-store
# repo, so no SKIP/invocation shape needs to differ from the gate's own existing posture.
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  : # Already reported SKIP above for this gate; nothing further to do here.
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-anchor-pointer-collapse.sh" ]; then
  fail "lint-anchor-pointer-collapse.sh not found in source store"
else
  anchor_collapse_lint_output=$(cd "$TARGET" && bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-anchor-pointer-collapse.sh" --verbose 2>&1)
  anchor_collapse_lint_status=$?
  if [ "$anchor_collapse_lint_status" -eq 0 ]; then
    pass "anchor-pointer collapse regression lint reports no reintroduced blocks"
  else
    fail "anchor-pointer collapse regression lint reported failures" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-anchor-pointer-collapse.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r anchor_collapse_lint_line; do
        FINDINGS_LIST+=("FINDING gate9 $anchor_collapse_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[VIOLATION]' "$anchor_collapse_lint_output")
    fi
  fi
fi

say ""

fi
}
# ── 10. specs/state.json schema validation (validate-state.sh --deep) ─────────
# Only meaningful in the source-store repo, mirroring gates 3-4/6-7/9's SKIP-if-not-source-store
# precedent -- a deploy consumer has no agent-system/extensions directory and the gate correctly
# skips there. Invokes the DEPLOYED copy (like gate 9), not the source-store one: validate-state.sh
# itself is argument-relative (no PROJECT_ROOT/deploy-root-guard.sh dependency), but its --deep
# TODO.md-sync check shells out to generate-todo.sh, which DOES require the deployed tree via
# deploy-root-guard.sh -- so running the source-store copy here would spuriously fail that one
# sub-check. Targets $TARGET/specs/state.json, the live state store, not a fixture.
gate10_run() {
if gate_selected 10; then
say "10. specs/state.json schema validation (validate-state.sh --deep)"
CURRENT_GATE="gate10"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- state schema validation does not apply"
elif [ ! -f "$TARGET/.claude/scripts/validate-state.sh" ]; then
  fail "validate-state.sh not found in deployed tree (run deploy-headless.sh first)" "$(redeploy_remedy_fragment)"
elif [ ! -f "$TARGET/specs/state.json" ]; then
  say "  [SKIP] no specs/state.json in $TARGET -- state schema validation does not apply"
else
  state_validate_output=$(cd "$TARGET" && bash "$TARGET/.claude/scripts/validate-state.sh" --deep "$TARGET/specs/state.json" 2>&1)
  state_validate_status=$?
  if [ "$state_validate_status" -eq 0 ]; then
    pass "validate-state.sh --deep: specs/state.json passes (no FAIL-level finding)"
  else
    fail "validate-state.sh --deep reported FAIL-level finding(s) against specs/state.json" \
         "re-run for detail: bash .claude/scripts/validate-state.sh --deep specs/state.json" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r state_validate_line; do
        FINDINGS_LIST+=("FINDING gate10 $state_validate_line")
      done < <(verify_deploy_extract_verdict_lines '[FAIL]' "$state_validate_output")
    fi
  fi
fi

say ""

fi
}
# ── 11. Contract compliance lint (lint-contract-compliance.sh --verbose) ──────
# Only meaningful in the source-store repo, mirroring gates 6-7's SKIP-if-not-source-store
# precedent -- a deploy consumer has no agent-system/extensions directory and the gate correctly
# skips there. Invokes the source-store copy directly (like gates 6-7): the script resolves its
# own REPO_ROOT via `git rev-parse --show-toplevel`, falling back to the `REPO_ROOT` env override
# set here, and always validates the source store (agent-system/extensions/core/**) regardless of
# which copy is invoked.
gate11_run() {
if gate_selected 11; then
say "11. Contract compliance lint (lint-contract-compliance.sh --verbose)"
CURRENT_GATE="gate11"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- contract compliance lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh" ]; then
  fail "lint-contract-compliance.sh not found in source store"
else
  contract_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh" --verbose 2>&1)
  contract_lint_status=$?
  if [ "$contract_lint_status" -eq 0 ]; then
    pass "contract compliance lint reports no failures"
  else
    fail "contract compliance lint reported failures" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r contract_lint_line; do
        FINDINGS_LIST+=("FINDING gate11 $contract_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[FAIL]' "$contract_lint_output")
    fi
  fi
fi

say ""

fi
}
# Gate 12: state-writer boundary lint (lint-state-writer-boundary.sh --verbose)
#
# Same source-store-vs-deploy-consumer [SKIP] posture as the sibling lint gates (6, 7, 9, 11):
# only the source store (agent-system/extensions/core/**) is validated, regardless of which copy
# (source store or deployed .claude/) invoked this script. Invokes the source-store copy
# directly, resolving REPO_ROOT the same way gate 11 does.
gate12_run() {
if gate_selected 12; then
say "12. State-writer boundary lint (lint-state-writer-boundary.sh --verbose)"
CURRENT_GATE="gate12"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- state-writer boundary lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh" ]; then
  fail "lint-state-writer-boundary.sh not found in source store"
else
  state_writer_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh" --verbose 2>&1)
  state_writer_lint_status=$?
  if [ "$state_writer_lint_status" -eq 0 ]; then
    pass "state-writer boundary lint reports no hand-rolled writes"
  else
    fail "state-writer boundary lint reported hand-rolled state.json writes" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r state_writer_lint_line; do
        FINDINGS_LIST+=("FINDING gate12 $state_writer_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[VIOLATION]' "$state_writer_lint_output")
    fi
  fi
fi

say ""

fi
}
# Gate 13: whole-tree orphan detection (find_orphans).
#
# The reverse direction from gate 5: gate 5 verifies declared -> deployed (is every declared
# entry present and hash-identical?); this gate verifies deployed -> declared (is every deployed
# file still declared by SOME active extension?). A file that loses its source-store owner is
# invisible to gate 5 forever, because the copy engine is additive-only by design and never
# deletes on its own. Modeled line-for-line on gate 5: same CURRENT_GATE assignment, same [SKIP]
# posture when the target is a deploy consumer rather than the source store, same headless-nvim
# invocation shape, same unanchored grep for the emitted token (OSC7 robustness). Detection only
# -- see context/patterns/deploy-orphan-detection.md for the full exclusion contract this gate
# enforces and the detect-never-delete decision it implements.
gate13_run() {
if gate_selected 13; then
say "13. Whole-tree orphan detection (find_orphans: deployed-but-undeclared files, ghost index rows)"
CURRENT_GATE="gate13"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- this gate compares against"
  say "         the source store and does not apply here"
elif ! command -v nvim >/dev/null 2>&1; then
  fail "nvim not found on PATH; cannot run whole-tree orphan detection"
else
  orphan_output=$(cd "$TARGET" && "${NVIM_ARGS[@]}" \
    -c "lua local ok1, ext_config = pcall(require, 'neotex.plugins.ai.shared.extensions.config'); local ok2, ext_init = pcall(require, 'neotex.plugins.ai.shared.extensions.init'); if not (ok1 and ok2) then print('ORPHAN_ERROR require: ' .. tostring(ok1 and ext_init or ext_config)) else local manager = ext_init.create(ext_config.claude()); local pok, result = pcall(manager.find_orphans, '${TARGET}'); if not pok then print('ORPHAN_ERROR call: ' .. tostring(result)) else for _, rel in ipairs(result.orphans) do print('ORPHAN_FINDING orphan file: ' .. rel) end for _, path in ipairs(result.ghost_index_entries) do print('ORPHAN_FINDING ghost index row: ' .. path) end print('ORPHAN_DONE checked=' .. tostring(result.checked)) end end" \
    -c "qa!" 2>&1)

  if echo "$orphan_output" | grep -q 'ORPHAN_ERROR'; then
    orphan_error_line=$(echo "$orphan_output" | grep 'ORPHAN_ERROR' | head -1)
    fail "whole-tree orphan detection could not run" "$orphan_error_line" \
         "whole-tree orphan detection could not run: $orphan_error_line"
  elif ! echo "$orphan_output" | grep -q 'ORPHAN_DONE'; then
    fail "whole-tree orphan detection produced no result" \
         "re-run: nvim --headless -c \"lua ...manager.find_orphans(...)\"" \
         "whole-tree orphan detection produced no result"
  else
    # Unanchored, same OSC7 rationale as gate 5's verify_finding_count above.
    orphan_finding_count=$(echo "$orphan_output" | grep -c 'ORPHAN_FINDING ')
    if [ "$orphan_finding_count" -eq 0 ]; then
      pass "no deployed-but-undeclared files or ghost context/index.json rows"
    else
      # Third arg "" suppresses the default aggregate finding -- the per-underlying-
      # ORPHAN_FINDING lines extracted below are the findings-mode representation, mirroring
      # gate 5's own suppress-and-extract pattern. The loop below ALSO prints each finding to the
      # operator-visible stderr stream unconditionally (fail()'s own [FAIL]/hint lines are not
      # gated by --quiet either), independent of --findings -- see
      # context/patterns/deploy-orphan-detection.md's fail-time detail subsection for why:
      # without this, "re-run without --quiet for detail" was a false promise, since the
      # per-finding lines were previously appended to FINDINGS_LIST only.
      fail "whole-tree orphan detection reported $orphan_finding_count finding(s)" \
           "see findings below; classify against context/patterns/deploy-orphan-detection.md's exclusion classes" ""
      while IFS= read -r orphan_finding_line; do
        orphan_finding_detail="${orphan_finding_line#*ORPHAN_FINDING }"
        echo "         - $orphan_finding_detail" >&2
        if [ "$FINDINGS" = "true" ]; then
          FINDINGS_LIST+=("FINDING gate13 $orphan_finding_detail")
        fi
      done < <(echo "$orphan_output" | grep -o 'ORPHAN_FINDING .*')
    fi
  fi
fi

say ""

fi
}
# Gate 14: orchestrator runtime-file tracking policy (check-runtime-file-tracking.sh).
#
# Runs on ANY target, not just the source store -- unlike gates 3/4/6/7/8/9/10 (which SKIP on a
# deploy consumer because they inspect agent-system/extensions), this gate's three checks
# (ignore coverage, no tracked ephemeral file, provenance not over-ignored) apply equally to
# every repo that has a .claude/ deploy tree, since check-runtime-file-tracking.sh itself is
# deployed by the core extension's manifest.json (provides.scripts) into every consumer. Invokes
# the DEPLOYED copy from $TARGET's own repo root, since the script's probes
# (specs/000_probe/...) are relative paths that must resolve against the target's own specs/
# tree, not the source-store repo running this aggregator.
#
# Fast, not deferred by --skip-slow: three `git check-ignore` sweeps over a handful of probe
# paths, nowhere near gate 8's tests/run-all.sh cost. --skip-slow continues to defer gate 8 only.
gate14_run() {
if gate_selected 14; then
say "14. Orchestrator runtime-file tracking policy (check-runtime-file-tracking.sh)"
CURRENT_GATE="gate14"
if [ ! -x "$CLAUDE_DIR/scripts/check-runtime-file-tracking.sh" ] && [ ! -f "$CLAUDE_DIR/scripts/check-runtime-file-tracking.sh" ]; then
  fail "check-runtime-file-tracking.sh not deployed"
else
  runtime_tracking_output=$(cd "$TARGET" && bash "$CLAUDE_DIR/scripts/check-runtime-file-tracking.sh" 2>&1)
  runtime_tracking_status=$?
  if [ "$runtime_tracking_status" -eq 0 ]; then
    pass "runtime-file tracking policy: all three checks passed"
  else
    fail "runtime-file tracking policy reported failures" \
         "re-run for detail: bash .claude/scripts/check-runtime-file-tracking.sh" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r runtime_tracking_line; do
        FINDINGS_LIST+=("FINDING gate14 ${runtime_tracking_line#*FAIL }")
      done < <(printf '%s\n' "$runtime_tracking_output" | sed -E 's/\x1b\[[0-9;]*m//g' | grep -E '^  FAIL ')
    fi
  fi
fi

say ""

fi
}
# ── 15. Lifecycle status-variable regression lint gate ────────────────────────
# Only meaningful in the source-store repo, mirroring gates 6-7/11-12's SKIP-if-not-source-store
# precedent -- a deploy consumer has no agent-system/extensions directory and the gate correctly
# skips there. Runs the SOURCE-STORE copy (REPO_ROOT="$TARGET" override), matching gates 6/7's
# convention rather than gate 9's deployed-tree convention: this lint's own default scan corpus
# is `agent-system/extensions/*/skills/*/SKILL.md` and `agent-system/extensions/*/context/
# patterns/*` -- source-store paths, not deployed ones -- so invoking the deployed copy would
# resolve REPO_ROOT to the wrong depth and silently scan nothing, exactly as gate 6/7's own
# precedent already documents for their scripts.
gate15_run() {
if gate_selected 15; then
say "15. Lifecycle status-variable lint (lint-lifecycle-status-var.sh --verbose)"
CURRENT_GATE="gate15"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- lifecycle status-variable lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-lifecycle-status-var.sh" ]; then
  fail "lint-lifecycle-status-var.sh not found in source store"
else
  lifecycle_status_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-lifecycle-status-var.sh" --verbose 2>&1)
  lifecycle_status_lint_status=$?
  if [ "$lifecycle_status_lint_status" -eq 0 ]; then
    pass "lifecycle status-variable lint reports no violations"
  else
    fail "lifecycle status-variable lint reported violations" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-lifecycle-status-var.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r lifecycle_status_lint_line; do
        FINDINGS_LIST+=("FINDING gate15 $lifecycle_status_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[VIOLATION]' "$lifecycle_status_lint_output")
    fi
  fi
fi

say ""

fi
}
# ── 16. routing_hard/routing_agents_hard absence guard (non-blocking) ─────────────────────────
# STANDING REGRESSION GUARD, not a migration-in-progress warning: both keys are fully retired.
# routing_hard was retired by the routing-ladder collapse; routing_agents_hard was retired by the
# routing_agents_hard -> hard_contracts migration (every --hard dispatch now resolves the SAME
# standard agent as base mode, with domain-specific behavioral differences injected via
# hard_contracts -- an unrelated manifest key that resolves the list of behavioral-contract files
# injected into a --hard dispatch's prompt, never a skill or agent name; see
# context/guides/manifest-routing-schema.md). No manifest declares either key today, and this
# gate's `pass` line confirms it. A manifest declaring either key again -- e.g. a new extension
# copy-pasting a stale template, or a reverted edit -- is a migration REGRESSION, not a pending
# follow-on. Gates are NOT renumbered to close the id this gate occupies: lint-gate-registry.sh
# Check E requires contiguous ids, so deleting this gate would force renumbering every gate from
# 17 onward across the full gate-id reference surface (verify-deploy.sh itself,
# test-verify-deploy-gate-selection.sh, the gate cache, and seven other files) for a gate that
# already costs nothing to keep -- it is the cheapest, fixture-selectable `warn_advisory` gate in
# the registry and the ONLY gate case (q)'s own regression-test infrastructure (see
# test-verify-deploy-gate-selection.sh's case r) uses to demonstrate the non-blocking WARN
# channel exists at all. Stays at `warn_advisory` level deliberately: a reappearance is a defect
# worth flagging loudly, but never one that should block a deploy on its own.
gate16_run() {
if gate_selected 16; then
say "16. routing_hard/routing_agents_hard absence guard"
CURRENT_GATE="gate16"
gate16_hits=0
for gate16_manifest in "$CLAUDE_DIR"/extensions/*/manifest.json; do
  [ -f "$gate16_manifest" ] || continue
  gate16_ext=$(jq -r '.name // empty' "$gate16_manifest" 2>/dev/null)
  gate16_declares=$(jq -r '(has("routing_hard") or has("routing_agents_hard"))' "$gate16_manifest" 2>/dev/null)
  if [ "$gate16_declares" = "true" ]; then
    gate16_hits=$((gate16_hits + 1))
    warn_advisory "${gate16_ext:-$gate16_manifest} still declares routing_hard/routing_agents_hard" \
         "both keys are retired -- this is a migration REGRESSION, not a pending follow-on; see context/guides/manifest-routing-schema.md"
  fi
done
if [ "$gate16_hits" -eq 0 ]; then
  pass "no extension manifest declares routing_hard/routing_agents_hard"
fi
unset gate16_manifest gate16_ext gate16_declares gate16_hits

say ""

fi
}
# Gate 17: scoped-commit boundary lint (lint-scoped-commit-boundary.sh --verbose)
#
# Same source-store-vs-deploy-consumer [SKIP] posture as the sibling lint gates (6, 7, 9, 11, 12):
# only the source store (agent-system/extensions/core/**) is validated, regardless of which copy
# (source store or deployed .claude/) invoked this script. Invokes the source-store copy
# directly, resolving REPO_ROOT the same way gate 12 does.
gate17_run() {
if gate_selected 17; then
say "17. Scoped-commit boundary lint (lint-scoped-commit-boundary.sh --verbose)"
CURRENT_GATE="gate17"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- scoped-commit boundary lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh" ]; then
  fail "lint-scoped-commit-boundary.sh not found in source store"
else
  scoped_commit_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh" --verbose 2>&1)
  scoped_commit_lint_status=$?
  if [ "$scoped_commit_lint_status" -eq 0 ]; then
    pass "scoped-commit boundary lint reports no hand-rolled bare git-commit call sites"
  else
    fail "scoped-commit boundary lint reported hand-rolled bare git-commit call sites" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r scoped_commit_lint_line; do
        FINDINGS_LIST+=("FINDING gate17 $scoped_commit_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[VIOLATION]' "$scoped_commit_lint_output")
    fi
  fi
fi

say ""

fi
}
# Gate 18: task-lookup adoption lint (lint-task-lookup-adoption.sh --verbose)
#
# Same source-store-vs-deploy-consumer [SKIP] posture as the sibling lint gates (6, 7, 9, 11, 12,
# 17): only the source store (agent-system/extensions/core/**) is validated, regardless of which
# copy (source store or deployed .claude/) invoked this script. Invokes the source-store copy
# directly, resolving REPO_ROOT the same way gate 12 does.
gate18_run() {
if gate_selected 18; then
say "18. Task-lookup adoption lint (lint-task-lookup-adoption.sh --verbose)"
CURRENT_GATE="gate18"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- task-lookup adoption lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh" ]; then
  fail "lint-task-lookup-adoption.sh not found in source store"
else
  task_lookup_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh" --verbose 2>&1)
  task_lookup_lint_status=$?
  if [ "$task_lookup_lint_status" -eq 0 ]; then
    pass "task-lookup adoption lint reports no hand-rolled full-record task-lookup shapes"
  else
    fail "task-lookup adoption lint reported hand-rolled full-record task-lookup shapes" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r task_lookup_lint_line; do
        FINDINGS_LIST+=("FINDING gate18 $task_lookup_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[VIOLATION]' "$task_lookup_lint_output")
    fi
  fi
fi

say ""

fi
}
# Gate 19: branch-gated section threshold lint (lint-branch-gated-sections.sh --verbose)
#
# Same source-store-vs-deploy-consumer [SKIP] posture as the sibling lint gates (6, 7, 9, 11, 12,
# 17, 18): only the source store (agent-system/extensions/core/**) is validated, regardless of
# which copy (source store or deployed .claude/) invoked this script. Invokes the source-store
# copy directly, resolving REPO_ROOT the same way gate 18 does.
gate19_run() {
if gate_selected 19; then
say "19. Branch-gated section threshold lint (lint-branch-gated-sections.sh --verbose)"
CURRENT_GATE="gate19"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- branch-gated section threshold lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-branch-gated-sections.sh" ]; then
  fail "lint-branch-gated-sections.sh not found in source store"
else
  branch_gated_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-branch-gated-sections.sh" --verbose 2>&1)
  branch_gated_lint_status=$?
  if [ "$branch_gated_lint_status" -eq 0 ]; then
    pass "branch-gated section threshold lint reports no marked-but-unextracted sections over threshold"
  else
    fail "branch-gated section threshold lint reported marked-but-unextracted sections over threshold" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-branch-gated-sections.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r branch_gated_lint_line; do
        FINDINGS_LIST+=("FINDING gate19 $branch_gated_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[VIOLATION]' "$branch_gated_lint_output")
    fi
  fi
fi

say ""

fi
}
# Gate 20: orchestrator context budget lock (measure-eager-context.sh --check + per-file ceilings)
#
# Same source-store-vs-deploy-consumer [SKIP] posture as the sibling lint gates (6, 7, 9, 11, 12,
# 17, 18, 19): only the source store (agent-system/extensions/core/**) is measured, regardless of
# which copy (source store or deployed .claude/) invoked this script -- matching
# measure-eager-context.sh's own "predict from source store, never read the deploy tree" policy.
#
# Three independent sub-checks, each with its own severity (see the ORCHESTRATOR_BUDGET_GATE_MODE
# comment above for the rationale):
#   A. volatile-file hits (measure-eager-context.sh --check's own exit code) -- unconditional
#      fail(), regardless of ORCHESTRATOR_BUDGET_GATE_MODE.
#   B. eager-load regression (live TOTAL vs. eager_load.baseline_bytes) -- fail() always; the
#      current measured value is comfortably under baseline, so this ships at fail() tier from
#      day one (research Decision 3).
#   C. per-file ceilings (commands/orchestrate.md, skills/skill-orchestrate/SKILL.md vs. their
#      configured ceiling_bytes) -- warn() in "warn" mode (the default), fail() in "hard" mode.
#
# NORMALIZED FINDING TEXT (hard constraint): every warn()/fail() call below passes a value-free
# 3rd argument -- no byte counts, no timestamps. This is load-bearing: the inter-cycle redeploy
# checkpoint (skill-orchestrate Stage MT-3 step 7) diffs --findings output across redeploys via
# deploy_findings_snapshot/deploy_baseline_new_findings, and a finding whose text embeds a live
# byte count would register as a "new finding" on every single redeploy even when nothing
# meaningfully changed -- spuriously tripping defer_reason:"deploy_checkpoint" for every
# remaining task in a batch. Live numbers are printed unconditionally via say() below instead, so
# drift direction stays visible without polluting --findings output.
gate20_run() {
if gate_selected 20; then
say "20. Orchestrator context budget lock (measure-eager-context.sh --check + per-file ceilings)"
CURRENT_GATE="gate20"
BUDGET_CONFIG="$TARGET/agent-system/extensions/core/context/config/orchestrator-context-budget.json"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- orchestrator context budget lock does not apply"
elif [ ! -f "$BUDGET_CONFIG" ]; then
  fail "orchestrator-context-budget.json not found in source store" \
       "expected at agent-system/extensions/core/context/config/orchestrator-context-budget.json"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/measure-eager-context.sh" ]; then
  fail "measure-eager-context.sh not found in source store"
elif ! command -v jq >/dev/null 2>&1; then
  fail "jq unavailable; cannot read orchestrator-context-budget.json"
else
  eager_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/measure-eager-context.sh" --check 2>&1)
  eager_status=$?

  # Sub-check A: volatile-file hits -- unconditional fail(), independent of gate mode.
  if [ "$eager_status" -ne 0 ]; then
    fail "measure-eager-context.sh --check reported volatile-file hit(s)" \
         "re-run for detail: bash agent-system/extensions/core/scripts/measure-eager-context.sh --check" \
         "orchestrator context budget: volatile-file hit in the eager-load set"
  else
    pass "measure-eager-context.sh --check: no volatile-file hits"
  fi

  eager_total=$(printf '%s\n' "$eager_output" | grep -oE '^TOTAL: [0-9]+ B' | grep -oE '[0-9]+')
  baseline_bytes=$(jq -r '.eager_load.baseline_bytes' "$BUDGET_CONFIG" 2>/dev/null)

  # Sub-check B: eager-load regression -- fail() always (current value is under baseline).
  if [ -z "$eager_total" ]; then
    fail "could not parse TOTAL line from measure-eager-context.sh --check output" \
         "" "orchestrator context budget: eager-load total unparseable"
  elif [ -z "$baseline_bytes" ] || [ "$baseline_bytes" = "null" ]; then
    fail "orchestrator-context-budget.json missing eager_load.baseline_bytes" \
         "" "orchestrator context budget: config missing eager_load.baseline_bytes"
  elif [ "$eager_total" -gt "$baseline_bytes" ]; then
    fail "eager-load total ($eager_total B) exceeds recorded baseline ($baseline_bytes B)" \
         "re-derive only if the growth is deliberate and reviewed" \
         "orchestrator context budget: eager-load total over baseline"
  else
    pass "eager-load total ($eager_total B) within baseline ($baseline_bytes B)"
  fi

  # Sub-check C: per-file ceilings -- severity from ORCHESTRATOR_BUDGET_GATE_MODE.
  budget_files=$(jq -r '.files | keys[]' "$BUDGET_CONFIG" 2>/dev/null)
  while IFS= read -r rel_path; do
    [ -n "$rel_path" ] || continue
    ceiling=$(jq -r --arg p "$rel_path" '.files[$p].ceiling_bytes' "$BUDGET_CONFIG" 2>/dev/null)
    file_path="$TARGET/agent-system/extensions/core/$rel_path"
    if [ ! -f "$file_path" ]; then
      fail "$rel_path not found in source store" "" "orchestrator context budget: $rel_path missing"
      continue
    fi
    actual_bytes=$(wc -c < "$file_path" | tr -d ' ')
    if [ "$actual_bytes" -gt "$ceiling" ]; then
      if [ "$ORCHESTRATOR_BUDGET_GATE_MODE" = "hard" ]; then
        fail "$rel_path ($actual_bytes B) exceeds its configured ceiling ($ceiling B)" \
             "ORCHESTRATOR_BUDGET_GATE_MODE=hard" \
             "orchestrator context budget: $rel_path over ceiling"
      else
        warn "$rel_path ($actual_bytes B) exceeds its configured ceiling ($ceiling B)" \
             "ORCHESTRATOR_BUDGET_GATE_MODE=warn (default) -- promote to hard once trimmed" \
             "orchestrator context budget: $rel_path over ceiling"
      fi
    else
      pass "$rel_path ($actual_bytes B) within ceiling ($ceiling B)"
    fi
  done <<< "$budget_files"

  # Live figures printed unconditionally so drift direction is visible without a byte count ever
  # entering --findings output (see the NORMALIZED FINDING TEXT comment above).
  say ""
  say "  orchestrator context budget (live):"
  say "    eager load: ${eager_total:-?} B / baseline ${baseline_bytes:-?} B (mode: $ORCHESTRATOR_BUDGET_GATE_MODE for per-file ceilings)"
  while IFS= read -r rel_path; do
    [ -n "$rel_path" ] || continue
    ceiling=$(jq -r --arg p "$rel_path" '.files[$p].ceiling_bytes' "$BUDGET_CONFIG" 2>/dev/null)
    file_path="$TARGET/agent-system/extensions/core/$rel_path"
    if [ -f "$file_path" ]; then
      actual_bytes=$(wc -c < "$file_path" | tr -d ' ')
      if [ "$actual_bytes" -gt "$ceiling" ]; then marker="OVER"; else marker="under"; fi
      say "    $rel_path: $actual_bytes B / ceiling $ceiling B ($marker)"
    fi
  done <<< "$budget_files"
fi

say ""
fi
}
# Gate 21: hook registration path lint (lint-hook-registration-paths.sh --verbose). Modeled
# line-for-line on gate 12 (lint-state-writer-boundary.sh): same [SKIP] posture when the target is
# a deploy consumer rather than the source store, same fail() on a missing lint script, same
# FINDINGS_LIST accumulation over [VIOLATION] lines.
gate21_run() {
if gate_selected 21; then
say "21. Hook registration path lint (lint-hook-registration-paths.sh --verbose)"
CURRENT_GATE="gate21"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- hook registration path lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh" ]; then
  fail "lint-hook-registration-paths.sh not found in source store"
else
  hook_reg_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh" --verbose 2>&1)
  hook_reg_lint_status=$?
  if [ "$hook_reg_lint_status" -eq 0 ]; then
    pass "hook registration path lint reports no CWD-relative, fragment-unreachable, or dead hook registrations"
  else
    fail "hook registration path lint reported one or more hook-registration violations" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r hook_reg_lint_line; do
        FINDINGS_LIST+=("FINDING gate21 $hook_reg_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[VIOLATION]' "$hook_reg_lint_output")
    fi
  fi
fi

say ""
fi
}
# Gate 22: shellcheck lint (lint-shellcheck.sh --verbose). Modeled line-for-line on gate 21
# (lint-hook-registration-paths.sh): same [SKIP] posture when the target is a deploy consumer
# rather than the source store, same fail() on a missing lint script, same FINDINGS_LIST
# accumulation over [VIOLATION] lines (lint-shellcheck.sh's own [VIOLATION] prefix is a verbatim
# copy of gate 21's scrape convention, so no new mechanism is needed here).
gate22_run() {
if gate_selected 22; then
say "22. Shellcheck lint (lint-shellcheck.sh --verbose)"
CURRENT_GATE="gate22"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- shellcheck lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-shellcheck.sh" ]; then
  fail "lint-shellcheck.sh not found in source store"
else
  shellcheck_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-shellcheck.sh" --verbose 2>&1)
  shellcheck_lint_status=$?
  if [ "$shellcheck_lint_status" -eq 0 ]; then
    pass "shellcheck lint reports no findings at -S warning"
  else
    fail "shellcheck lint reported one or more findings" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r shellcheck_lint_line; do
        FINDINGS_LIST+=("FINDING gate22 $shellcheck_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[VIOLATION]' "$shellcheck_lint_output")
    fi
  fi
fi

say ""
fi
}
# Gate 23: directory-pathspec boundary lint (lint-directory-pathspec-boundary.sh --verbose).
# Modeled line-for-line on gate 17 (lint-scoped-commit-boundary.sh), its sibling rule: same
# [SKIP] posture, same fail() on a missing lint script, same FINDINGS_LIST accumulation over
# [VIOLATION] lines. The [SKIP] guard is retained deliberately, unlike gate 4's de-guarding: this
# lint's default scan root IS $PROJECT_ROOT/agent-system/extensions and it exits 2 with
# "ERROR: default scan root not found" when that directory is absent, so unlike
# check-task-references.sh it genuinely cannot run in a deploy-consumer tree. Under --only-gate
# 23 alone against a deploy consumer, this gate SKIPs, CHECKS reaches 0, and the
# zero-check-under-filter condition below correctly exits 2 with "cannot attest" rather than
# printing "PASS -- 0 check(s)" -- the same already-correct behavior shared with gates
# 3/5/6/7/9/11/12/17/18/19/21/22; no special handling is needed here.
gate23_run() {
if gate_selected 23; then
say "23. Directory-pathspec boundary lint (lint-directory-pathspec-boundary.sh --verbose)"
CURRENT_GATE="gate23"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- directory-pathspec boundary lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh" ]; then
  fail "lint-directory-pathspec-boundary.sh not found in source store"
else
  dir_pathspec_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh" --verbose 2>&1)
  dir_pathspec_lint_status=$?
  if [ "$dir_pathspec_lint_status" -eq 0 ]; then
    pass "directory-pathspec boundary lint reports no bare shared-directory pathspec tokens"
  else
    fail "directory-pathspec boundary lint reported bare shared-directory pathspec token(s)" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r dir_pathspec_lint_line; do
        FINDINGS_LIST+=("FINDING gate23 $dir_pathspec_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[VIOLATION]' "$dir_pathspec_lint_output")
    fi
  fi
fi

say ""
fi
}

gate24_run() {
if gate_selected 24; then
say "24. Dead-command-recommendation lint (lint-dead-command-recommendations.sh)"
CURRENT_GATE="gate24"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- dead-command-recommendation lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh" ]; then
  fail "lint-dead-command-recommendations.sh not found in source store"
else
  dead_command_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh" --verbose 2>&1)
  dead_command_lint_status=$?
  if [ "$dead_command_lint_status" -eq 0 ]; then
    pass "dead-command-recommendation lint reports no actionable recommendation naming an undefined command"
  else
    fail "dead-command-recommendation lint reported a recommendation naming a command with no definition file" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r dead_command_lint_line; do
        FINDINGS_LIST+=("FINDING gate24 $dead_command_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[VIOLATION]' "$dead_command_lint_output")
    fi
  fi
fi

say ""
fi
}

gate25_run() {
if gate_selected 25; then
say "25. Verdict-extraction anchoring lint (lint-verdict-extraction-anchoring.sh)"
CURRENT_GATE="gate25"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- verdict-extraction anchoring lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-verdict-extraction-anchoring.sh" ]; then
  fail "lint-verdict-extraction-anchoring.sh not found in source store"
else
  verdict_extraction_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-verdict-extraction-anchoring.sh" --verbose 2>&1)
  verdict_extraction_lint_status=$?
  if [ "$verdict_extraction_lint_status" -eq 0 ]; then
    pass "verdict-extraction anchoring lint reports no unanchored or SGR-blind verdict-extraction sites"
  else
    fail "verdict-extraction anchoring lint reported an unanchored or SGR-blind verdict-extraction site" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-verdict-extraction-anchoring.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r verdict_extraction_lint_line; do
        FINDINGS_LIST+=("FINDING gate25 $verdict_extraction_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[VIOLATION]' "$verdict_extraction_lint_output")
    fi
  fi
fi

say ""
fi
}

gate26_run() {
if gate_selected 26; then
say "26. Extension README table lint (lint-extension-readme-table.sh)"
CURRENT_GATE="gate26"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- extension README table lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-extension-readme-table.sh" ]; then
  fail "lint-extension-readme-table.sh not found in source store"
else
  extension_readme_table_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-extension-readme-table.sh" --verbose 2>&1)
  extension_readme_table_lint_status=$?
  if [ "$extension_readme_table_lint_status" -eq 0 ]; then
    pass "extension README table lint reports no drift between the directory set and the Available Extensions table"
  else
    fail "extension README table lint reported drift between the extension directory set and the Available Extensions table" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-extension-readme-table.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r extension_readme_table_lint_line; do
        FINDINGS_LIST+=("FINDING gate26 $extension_readme_table_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[VIOLATION]' "$extension_readme_table_lint_output")
    fi
  fi
fi

say ""
fi
}

gate27_run() {
if gate_selected 27; then
say "27. Subject-resolution declaration lint (lint-subject-resolution-declaration.sh)"
CURRENT_GATE="gate27"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- subject-resolution declaration lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-subject-resolution-declaration.sh" ]; then
  fail "lint-subject-resolution-declaration.sh not found in source store"
else
  subject_resolution_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-subject-resolution-declaration.sh" --verbose 2>&1)
  subject_resolution_lint_status=$?
  if [ "$subject_resolution_lint_status" -eq 0 ]; then
    pass "subject-resolution declaration lint reports no undeclared or silently-ordered subject-resolution sites"
  else
    fail "subject-resolution declaration lint reported an undeclared or silently-ordered subject-resolution site" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-subject-resolution-declaration.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r subject_resolution_lint_line; do
        FINDINGS_LIST+=("FINDING gate27 $subject_resolution_lint_line")
      done < <(verify_deploy_extract_verdict_lines '[VIOLATION]' "$subject_resolution_lint_output")
    fi
  fi
fi

say ""
fi
}

# Per-gate bounded execution (Phase 6, "Uniform Bounded Timeouts Per Gate and Per Suite"): each
# gate's declared `timeout_s` (gate-registry.data) is now enforced via
# gate_registry_exec_bounded, which runs the gate's invoke function and, on a clean finish,
# reconciles its mutations to CHECKS/FAILURES/FINDINGS_LIST/CURRENT_GATE back into this process
# (see that function's header in lib/gate-registry-lib.sh for why reconciliation is necessary --
# a bounded/killable gate must run in a real subshell, which strands globals unless explicitly
# dumped and re-sourced). A timeout (rc=124) is translated HERE, not inside the thin interpreter,
# into the same CHECKS/FAILURES/FINDINGS_LIST shape every other failure uses, naming the gate id,
# its invoke function, and the exact bound exceeded -- a named, attributable failure, never a
# generic non-zero exit. The gate loop itself never aborts on a timeout; it always proceeds to
# the next gate id, so one stalled gate cannot stall the whole battery.
#
# Phase 7 ("Gate-Level Concurrency Scheduler"): at JOBS<=1 (the explicit --jobs 1 opt-out), this
# is the EXACT pre-Phase-7 sequential loop, unchanged -- every gate's four artifacts
# (out/err/state, plus rc via $?) come from its own direct gate_registry_exec_bounded call, same
# as always. At JOBS>1 (the default -- see this file's header "Gate-level concurrency" section),
# gate_registry_exec_concurrent_batch pre-computes every gate's four artifacts CONCURRENTLY into
# one shared GATES_OUTDIR, reconciling CHECKS/FAILURES/FINDINGS_LIST/CURRENT_GATE internally as
# each wave completes (see that function's own header for why -- a naive "source each gate's
# dump in sequence" loses every concurrently-forked gate's contribution except the last one
# sourced); this loop then only EMITS each gate's captured out/err and applies the 124-timeout
# translation, reading rc.$_gate_id instead of a fresh $? -- the emission order is ALWAYS
# ascending gate id (gate_registry_ids' own documented sort), so output and the final PASS/FAIL
# line are byte-identical regardless of worker count.
# ── --skip-unchanged: per-gate cache consult (additive-only; a complete no-op when the flag is
# absent, since SKIP_UNCHANGED is only ever true when the flag was passed) ─────────────────────
# Runs AFTER gate_registry_load and BEFORE either dispatch path, over the CURRENTLY loaded id
# set, filtered through gate_selected() (the SAME predicate --only-gate/--max-cost's own
# GATES_FILTER already drives every gate's internal guard with). Without this filter, a gate
# EXCLUDED by --only-gate/--max-cost but carrying a valid cache entry from some earlier,
# differently-scoped run would still announce [SKIP-CACHED] and consume consult-loop time for a
# gate that was never going to be dispatched in the first place regardless of cache state --
# confusing narrative output for zero behavioral effect. For each SELECTED id whose composite
# key is computable (not the sentinel) and matches a stored GREEN entry, emits the SKIP-CACHED
# line, counts it, and removes it from the dispatch set via gate_registry_exclude_ids -- so
# neither dispatch path below ever invokes it.
if [ "$SKIP_UNCHANGED" = "true" ]; then
  _vd_skip_ids=""
  for _vd_cache_id in $(gate_registry_ids); do
    gate_selected "$_vd_cache_id" || continue
    _vd_cache_key="$(gate_cache_composite_key "$_vd_cache_id" "$TARGET" "${_VD_SCRIPT_DIR}/gate-registry.data")"
    [ "$_vd_cache_key" = "$GATE_CACHE_SENTINEL" ] && continue
    if gate_cache_entry_read "$_vd_cache_id" "$TARGET"; then
      if [ "$GATE_CACHE_ENTRY_KEY" = "$_vd_cache_key" ]; then
        _vd_cache_name="$(gate_registry_field "$_vd_cache_id" name)"
        say "  [SKIP-CACHED] gate${_vd_cache_id} (${_vd_cache_name}) -- inputs unchanged since ${GATE_CACHE_ENTRY_TIMESTAMP} (${_vd_cache_key:0:12})"
        SKIPPED_CACHED=$((SKIPPED_CACHED + 1))
        _vd_skip_ids="${_vd_skip_ids:+${_vd_skip_ids},}${_vd_cache_id}"
      fi
    fi
  done
  [ -n "$_vd_skip_ids" ] && gate_registry_exclude_ids "$_vd_skip_ids"
  unset _vd_cache_id _vd_cache_key _vd_cache_name _vd_skip_ids
fi

GATES_OUTDIR=""
if [ "$JOBS" -gt 1 ]; then
  GATES_OUTDIR="$(mktemp -d)"
  gate_registry_exec_concurrent_batch "$JOBS" "$GATES_OUTDIR" CHECKS FAILURES FINDINGS_LIST CURRENT_GATE GATE_RAN_LIST GATE_DIRTY_LIST
fi

for _gate_id in $(gate_registry_ids); do
  _vd_gate_fn="$(gate_registry_field "$_gate_id" invoke)"
  _vd_gate_timeout="$(gate_registry_field "$_gate_id" timeout_s)"
  if [ "$JOBS" -gt 1 ]; then
    _vd_gate_out="$GATES_OUTDIR/out.$_gate_id"
    _vd_gate_err="$GATES_OUTDIR/err.$_gate_id"
    _vd_gate_state="$GATES_OUTDIR/state.$_gate_id"
    _vd_gate_rc="$(cat "$GATES_OUTDIR/rc.$_gate_id" 2>/dev/null || echo 1)"
  else
    _vd_gate_out="$(mktemp)"
    _vd_gate_err="$(mktemp)"
    _vd_gate_state="$(mktemp)"
    gate_registry_exec_bounded "$_vd_gate_fn" "$_vd_gate_timeout" "$_vd_gate_out" "$_vd_gate_err" "$_vd_gate_state" CHECKS FAILURES FINDINGS_LIST CURRENT_GATE GATE_RAN_LIST GATE_DIRTY_LIST
    _vd_gate_rc=$?
  fi
  cat "$_vd_gate_out"
  cat "$_vd_gate_err" >&2
  if [ "$_vd_gate_rc" -eq 124 ]; then
    CHECKS=$((CHECKS + 1))
    FAILURES=$((FAILURES + 1))
    CURRENT_GATE="gate${_gate_id}"
    echo "  [FAIL] gate${_gate_id} (${_vd_gate_fn}) exceeded its ${_vd_gate_timeout}s timeout and was killed" >&2
    FINDINGS_LIST+=("FINDING gate${_gate_id} TIMEOUT: gate${_gate_id} (${_vd_gate_fn}) exceeded its ${_vd_gate_timeout}s timeout and was killed")
  elif [ "$JOBS" -le 1 ] && [ -s "$_vd_gate_state" ]; then
    # At JOBS>1, gate_registry_exec_concurrent_batch already reconciled this id's state
    # internally (see its own header) -- sourcing state.$_gate_id here too would double-apply
    # it (CHECKS/FAILURES would be summed twice, FINDINGS_LIST would gain duplicate entries).
    # shellcheck disable=SC1090
    source "$_vd_gate_state"
  fi

  # ── --skip-unchanged: post-run cache write/invalidate (additive-only; a complete no-op when
  # the flag is absent) ─────────────────────────────────────────────────────────────────────────
  # This fires for every SELECTED id reaching this point -- which, after the pre-dispatch
  # consult above removed every cache-HIT id from the loaded set entirely, is exactly the set
  # of ids that was actually dispatched this run. A cache-hit id never appears in this loop at
  # all (gate_registry_ids no longer returns it), so its existing entry is correctly left
  # untouched either way.
  #
  # The leading `gate_selected` guard below is NOT redundant with that cache-hit exclusion --
  # it closes a distinct, previously real gap found live while building
  # tests/test-gate-cache-equivalence.sh (Phase 9): gate_registry_ids() still yields every id
  # NEITHER selected NOR cache-excluded (an id outside a `--only-gate`/`--max-cost` selection was
  # never consulted by the pre-dispatch loop above, since that loop itself only visits SELECTED
  # ids -- see its own `gate_selected "$_vd_cache_id" || continue` line). Such an id still
  # reaches THIS loop and still gets `"gate${_gate_id}_run"` called on it; the function no-ops
  # internally via its own `gate_selected` guard, so _vd_ran below stays false for it -- which,
  # absent this fix, fell into the "disqualified" else-branch and INVALIDATED (deleted) that
  # unselected id's perfectly valid existing cache entry, every single run. Confirmed by direct
  # reproduction: `verify-deploy.sh --skip-unchanged --only-gate 4` against a target carrying
  # warm entries for gates 1/2/5/6/7/9/10/11/12/13/15/17/18/19/21/22/23 silently deleted every
  # one of them. This is exactly the "typical incremental change" scenario the task's own GOAL
  # section describes (re-check one gate after a change) -- the one usage pattern that must not
  # degrade the cache store it is trying to preserve. Skipping the whole block for an unselected
  # id leaves its entry exactly as it was, which is the correct behavior: an id this invocation
  # was never asked about has no basis for either a fresh write or an invalidation.
  if [ "$SKIP_UNCHANGED" = "true" ] && gate_selected "$_gate_id"; then
    _vd_ran=false
    _vd_dirty=false
    for _vd_x in "${GATE_RAN_LIST[@]:-}"; do
      [ "$_vd_x" = "gate${_gate_id}" ] && { _vd_ran=true; break; }
    done
    for _vd_x in "${GATE_DIRTY_LIST[@]:-}"; do
      [ "$_vd_x" = "gate${_gate_id}" ] && { _vd_dirty=true; break; }
    done
    if [ "$_vd_gate_rc" != "124" ] && [ "$_vd_ran" = "true" ] && [ "$_vd_dirty" = "false" ]; then
      _vd_write_key="$(gate_cache_composite_key "$_gate_id" "$TARGET" "${_VD_SCRIPT_DIR}/gate-registry.data")"
      if [ "$_vd_write_key" != "$GATE_CACHE_SENTINEL" ]; then
        gate_cache_entry_write "$_gate_id" "$TARGET" "$_vd_write_key"
      fi
    else
      # Covers all three disqualifying cases in one branch: timed out (rc=124), failed or
      # warned (GATE_DIRTY_LIST), or self-skipped via the gate's own internal guard without
      # registering any check at all (never reached GATE_RAN_LIST) -- see this flag's header
      # doc above for why each of these must invalidate rather than merely skip the write.
      gate_cache_entry_invalidate "$_gate_id" "$TARGET"
    fi
    unset _vd_ran _vd_dirty _vd_x _vd_write_key
  fi
  [ "$JOBS" -le 1 ] && rm -f "$_vd_gate_out" "$_vd_gate_err" "$_vd_gate_state"
done
[ -n "$GATES_OUTDIR" ] && rm -rf "$GATES_OUTDIR"
unset _vd_gate_fn _vd_gate_timeout _vd_gate_out _vd_gate_err _vd_gate_state _vd_gate_rc GATES_OUTDIR

# Zero-check-under-filter detection (additive-only; unreachable with --only-gate and --max-cost
# both absent, since GATES_FILTER is then empty and this condition can never be true). A
# --only-gate and/or --max-cost selection whose every named/matched gate SKIPped (source-store-
# only guard) or was deferred (--skip-slow's gate 8) produces CHECKS=0: the run attested to
# nothing, yet without this branch it would fall straight into the PASS branch below and print
# "PASS -- 0 check(s), 0 failure(s)", exit 0 -- an exit-0 result indistinguishable from a real,
# checked pass. A deferred-only selection (e.g. --skip-slow --only-gate 8) is deliberately folded
# into this same branch rather than treated as a distinct case: gate 8 being deferred still means
# the run checked nothing, so it must not be mistaken for a genuine pass either. The wording below
# says "skipped or deferred" rather than naming one cause, so this result is also not mistaken for
# the separate invalid-gate-id/invalid-cost-class error (which exits 2 earlier, at argument
# parsing, before any gate runs). _VD_SELECTION_DESC names whichever of --only-gate/--max-cost (or
# both) actually produced the active GATES_FILTER, rather than always crediting --only-gate even
# when --max-cost alone drove the selection.
_VD_SELECTION_DESC="--only-gate $GATES_FILTER"
if [ -n "$MAX_COST" ]; then
  if [ -n "$ONLY_GATE_ARG" ]; then
    _VD_SELECTION_DESC="--only-gate $ONLY_GATE_ARG intersected with --max-cost $MAX_COST (resolved: $GATES_FILTER)"
  else
    _VD_SELECTION_DESC="--max-cost $MAX_COST (resolved: $GATES_FILTER)"
  fi
fi
# The SKIPPED_CACHED exemption below is additive-only: SKIPPED_CACHED is always 0 with
# --skip-unchanged absent, so this condition is byte-identical to before this flag existed in
# that case. With the flag present, a --only-gate/--max-cost selection whose every matched gate
# was legitimately CACHE-skipped (not its own internal guard, not --skip-slow's deferral) must
# fall through to the ordinary PASS branch below, carrying its own loud skip-count clause --
# that is a real, meaningful, attested result, not the "attested to nothing" hazard this
# zero-check guard otherwise exists to catch.
if [ -n "$GATES_FILTER" ] && [ "$CHECKS" -eq 0 ] && [ "$SKIPPED_CACHED" -eq 0 ]; then
  echo "[verify-deploy] cannot attest: every gate selected by $_VD_SELECTION_DESC skipped or was deferred -- 0 check(s) ran" >&2
  if [ "$FINDINGS" = "true" ]; then
    echo "FINDING gate0 verify-deploy could not run: every gate selected by $_VD_SELECTION_DESC skipped or was deferred -- 0 check(s) ran"
  fi
  exit 2
fi
# --skip-unchanged's summary clause: additive-only, appended to both the PASS and FAIL lines
# below ONLY when SKIPPED_CACHED is non-zero -- with the flag absent (SKIPPED_CACHED always 0),
# _VD_SKIP_CLAUSE stays empty and both lines are byte-identical to before this flag existed.
_VD_SKIP_CLAUSE=""
if [ "$SKIPPED_CACHED" -gt 0 ]; then
  _VD_SKIP_CLAUSE=" ($SKIPPED_CACHED gate(s) skipped -- cached, inputs unchanged)"
fi

# Standing corpus-size probe: one cheap line, immediately before the PASS/FAIL summary, reporting
# non-test script count/lines, test-suite count, and markdown file count/lines. No new gate row,
# no new check, no effect on CHECKS/FAILURES/FINDINGS_LIST -- this is additive-only output.
# Scoped to TARGET actually being the source store, matching every other source-store-only gate's
# own guard above: a deploy-consumer TARGET has no agent-system/extensions/** corpus to report on.
_VD_SCRIPT_INVENTORY="$TARGET/agent-system/extensions/core/scripts/script-inventory.sh"
if [ -d "$TARGET/agent-system/extensions" ] && [ -f "$_VD_SCRIPT_INVENTORY" ]; then
  _VD_CORPUS_LINE="$(bash "$_VD_SCRIPT_INVENTORY" --root "$TARGET" --size-line 2>/dev/null || true)"
  if [ -n "$_VD_CORPUS_LINE" ]; then
    echo "[verify-deploy] corpus: ${_VD_CORPUS_LINE#script-inventory: }"
  fi
fi
unset _VD_SCRIPT_INVENTORY _VD_CORPUS_LINE

if [ "$FAILURES" -eq 0 ]; then
  echo "[verify-deploy] PASS -- $CHECKS check(s), 0 failure(s)${_VD_SKIP_CLAUSE}"
  say ""
  say "NOTE: this verifies DEPLOYMENT only. Confirming that events actually flow requires real"
  say "command invocations afterwards -- inspect specs/events.jsonl for artifact_write,"
  say "subagent_stop, and session_stop lines postdating the deploy."
  if [ "$FINDINGS" = "true" ] && [ "${#FINDINGS_LIST[@]}" -gt 0 ]; then
    printf '%s\n' "${FINDINGS_LIST[@]}" | sort -u
  fi
  exit 0
fi

echo "[verify-deploy] FAIL -- $FAILURES of $CHECKS check(s) failed${_VD_SKIP_CLAUSE}" >&2
if [ "$FINDINGS" = "true" ] && [ "${#FINDINGS_LIST[@]}" -gt 0 ]; then
  printf '%s\n' "${FINDINGS_LIST[@]}" | sort -u
fi
exit 1
