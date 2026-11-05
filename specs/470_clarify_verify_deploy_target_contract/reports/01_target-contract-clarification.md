# Research Report: Task #470

**Task**: 470 - Clarify verify-deploy.sh TARGET contract versus its invocation-directory claim
**Started**: 2026-11-05T04:00:00Z
**Completed**: 2026-11-05T04:30:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**: - Codebase (`agent-system/extensions/core/scripts/verify-deploy.sh`,
  `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`,
  `agent-system/extensions/core/scripts/lib/redeploy-remedy-lib.sh`,
  `agent-system/extensions/core/scripts/tests/`)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The script's current header (lines 4-9) makes a true claim about the **invocation-CWD axis**
  ("resolves TARGET from an explicit argument or `$(pwd)` ... runs correctly from either tree
  with no override") that a reader plausibly misreads as a claim about the **TARGET-argument
  axis** — exactly what happened in the task-468 citation this task is responding to.
- Confirmed mechanically (line numbers below): `TARGET` must point at a repo root holding a
  deployed `.claude/` (gate0 hard-requires `$TARGET/.claude`, else `exit 2`), and must
  additionally hold `agent-system/extensions` for any source-store-only gate (3, 4, 6, 7, 12,
  and the ~15 others guarded the same way) to run rather than `[SKIP]`. In this repository those
  two conditions coincide only at the repo root — never at `agent-system/extensions/core` itself,
  which has no `.claude/` subdirectory.
- No test in the repo pins the exact gate0 stderr text ("no deploy tree at ..."), so extending
  that message is safe. No other file duplicates the header's TARGET-axis prose, so a single
  authority (the script header) plus the existing one-line pointer in
  `regeneration-is-manual-only.md` is sufficient — no second full copy is warranted.
- Recommended changes are additive/clarifying only, confined to: the header block, the usage
  line's accompanying prose, and gate0's stderr emission. No gate's pass/fail logic changes.

## Context & Scope

Scoped to `agent-system/extensions/core/scripts/verify-deploy.sh` (the source-store copy; the
deployed `.claude/scripts/verify-deploy.sh` must never be hand-edited per
`rules/source-store-deploy-boundary.md`) and, conditionally,
`agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`. The task is
diagnostics-and-documentation only: outcome 5 explicitly forbids any gate pass/fail behavior
change, and limits the one executable change in scope to gate0's error text.

Concurrent territory: tasks #444, #414, #445, #449 (all `not_started`) also declare
`verify-deploy.sh`; a sibling task (the extensions-README-table lint gate) declares a dependency
on this task because both touch the header/argument-parsing region. This task's edits should
stay narrowly inside the header comment block (lines ~1-200) and the gate0 block (lines ~483-489)
to minimize collision surface with those siblings' likely edit regions (gate-id validation,
gate-registry wiring, verdict-extraction anchoring).

## Findings

### Codebase Patterns

**Current header claim (lines 4-9 of `verify-deploy.sh`)**:
```
# INVOCATION CONTRACT: this script carries no deploy-root-guard.sh guard and sits outside the
# "Root-Resolution Guard for Core Scripts" opt-in contract (see
# context/patterns/regeneration-is-manual-only.md) entirely -- it needs no such guard because it
# resolves its TARGET from an explicit argument or `$(pwd)` (see the TARGET assignment below),
# never from `BASH_SOURCE`-relative `../..`, so it runs correctly from either tree with no
# override.
```
This paragraph is entirely about *where the script may be invoked from* (its own CWD, or lack
of a `BASH_SOURCE`-relative root computation) — it says nothing about what the `TARGET`
argument's value must structurally satisfy. That silence is exactly what let the task-468 plan
read "runs correctly from either tree" as "TARGET may be either tree."

**Confirmed mechanism** (`agent-system/extensions/core/scripts/verify-deploy.sh`):
- Line 32-33 (usage line): `verify-deploy.sh [--quiet] [--findings] [--skip-slow]
  [--skip-unchanged] [--jobs N|auto] [--minimal-init DIR] [TARGET_REPO]` — the `[TARGET_REPO]`
  placeholder carries no inline contract today.
- Line 474: `TARGET="${TARGET:-$(pwd)}"` — the invocation-CWD default, confirmed correct and
  independent of the TARGET-argument contract.
- Lines 483-489 (gate0, the hard precondition):
  ```
  CLAUDE_DIR="$TARGET/.claude"
  if [ ! -d "$CLAUDE_DIR" ]; then
    echo "ERROR: no deploy tree at $CLAUDE_DIR -- nothing to verify." >&2
    echo "Run: bash deploy-headless.sh $TARGET" >&2
    echo "$(redeploy_remedy_fragment)" >&2
    [ "$FINDINGS" = "true" ] && echo "FINDING gate0 verify-deploy could not run: no deploy tree at $CLAUDE_DIR"
    exit 2
  fi
  ```
  This is the exact failure the task-468 citation hit: `agent-system/extensions/core` has no
  `.claude/` subdirectory, so this branch fires unconditionally for any source-directory TARGET.
- Lines 516, 739, 856, 921, 952, 1040, 1134, 1172, 1209, 1243, 1282, 1383, 1452, 1486, 1520,
  1574, 1668, 1700, 1738, 1766 (~20 sites): every source-store-only gate guards on
  `[ ! -d "$TARGET/agent-system/extensions" ]` and prints `[SKIP] ... is a deploy consumer, not
  the source store ...` (see gate3's comment at line 732-734: "Only meaningful in the
  source-store repo. A deploy consumer has no agent-system/extensions directory, and the gate
  correctly errors there -- that is not a deploy failure."). This is the second half of the
  contract: even a TARGET that clears gate0 (holds `.claude/`) will SKIP every source-store gate
  unless it ALSO holds `agent-system/extensions`.
- In this repository, the only directory satisfying both conditions simultaneously is the repo
  root (`/home/benjamin/.config/nvim`), which is both the deploy consumer (has `.claude/`) and
  the agent-system source store (has `agent-system/extensions/`). `agent-system/extensions/core`
  satisfies neither — it has no `.claude/` (fails gate0 before gate selection is even consulted)
  and is a subdirectory of, not identical to, `agent-system/extensions`.

**No existing authority duplicates this contract.** Searched the full repo for the header's own
phrasing ("resolves its TARGET", "runs correctly from either tree") — it occurs nowhere but the
header itself. `regeneration-is-manual-only.md`'s "Root-Resolution Guard for Core Scripts"
section (lines 850-888) is about an **orthogonal** mechanism: scripts that compute their own
repo root via `"$(cd "${SCRIPT_DIR}/../.." && pwd)"` (a `BASH_SOURCE`-relative, no-argument
resolution, used by scripts like `check-extension-docs.sh` and `sync-manifest-scripts.sh` that
take no explicit TARGET). `verify-deploy.sh` is exempted from that section with one sentence
(line 888): *"`verify-deploy.sh` carries no such guard at all and sits outside this contract
entirely -- see its own header for why."* That sentence is accurate and is itself already a
pointer, not a duplicate — it correctly sends a reader who lands in this section back to the
header for the (different) TARGET-argument contract. It does not currently distinguish, even in
one clause, that the reason is a *different kind of contract* (an explicit argument's required
shape) rather than simply "no guard needed" — a reader skimming only this section, without
following the pointer, could still come away thinking TARGET is unconstrained.

**Gate-selection interaction** (confirmed via header's own "Gate selection" and "Zero-check-
under-filter" prose, lines ~172-186): `--only-gate 3,4 <source_dir>` cannot reach the
zero-check-under-filter diagnostic (exit 2, "every gate selected ... skipped or was deferred")
because gate0's `.claude/` check fires FIRST, before gate selection is even parsed/applied. This
means the actual failure mode a task-468-style caller hits is the plain "no deploy tree" message,
not the more gate-selection-aware "skipped or deferred" message — reinforcing that outcome 3
(naming the convention in gate0's error, which fires first and is what a source-dir caller
actually sees) is the right fix site, not the zero-check-under-filter path.

**Test safety check**: grepped every file under
`agent-system/extensions/core/scripts/tests/` for the literal strings `no deploy tree`,
`CLAUDE_DIR`, and `ERROR: no deploy` — no hit. No test pins gate0's exact stderr wording, so
extending it (adding a line) carries no test-breakage risk. `redeploy-remedy-lib.sh`'s own
suite (`test-redeploy-remedy-lib.sh`) pins constraints on `redeploy_remedy_fragment`'s output
(contains `deploy-headless.sh`, no `^WARN:` line, no trailing newline, no task-number
reference) but that function is appended verbatim by gate0 today and this task does not touch
it — any new line must be inserted as its own `echo ... >&2`, before or after the existing
`redeploy_remedy_fragment` line, never concatenated into it.

### External Resources

Not applicable — this is a pure in-repo documentation/diagnostics clarification; no external
tooling or library behavior is involved.

## Recommendations

1. **Header (outcome 1)**: Immediately after the existing INVOCATION CONTRACT paragraph (which
   is correct and should be kept, not deleted, per the task description), add a new paragraph
   stating the TARGET-argument contract explicitly, e.g.:
   > "TARGET_REPO CONTRACT (a separate axis from the invocation-directory claim above): this
   > positional argument, when given, must be a repository that already holds a deployed
   > `.claude/` tree (gate0 requires `$TARGET/.claude` to exist, else exit 2) — it is never the
   > `agent-system/extensions/<name>` source-store directory itself, which has no `.claude/`
   > subdirectory. Every source-store-only gate (3, 4, 6, 7, 12, and others, each guarded on
   > `$TARGET/agent-system/extensions`) additionally SKIPs unless TARGET also holds
   > `agent-system/extensions` — so TARGET must simultaneously be a deploy consumer AND the
   > source store for those gates to run at all. In this repository that is only the repo root."

2. **Usage line (outcome 2)**: Add a short explanatory line directly under the `# Usage:` block
   (mirroring the existing "Minimal-init hatch" explanatory-subsection pattern already used for
   other flags in this same header), naming the concrete failure mode: `--only-gate 3,4
   <source_dir>` cannot work because `<source_dir>` has no `.claude/`; the repo root is the
   correct `TARGET_REPO` for exercising source-store gates.

3. **gate0 error text (outcome 3)**: Insert one new stderr line between the existing "no deploy
   tree" line and the "Run: bash deploy-headless.sh" line (or immediately after both, before
   `redeploy_remedy_fragment`'s line), e.g.:
   ```
   echo "ERROR: no deploy tree at $CLAUDE_DIR -- nothing to verify." >&2
   echo "TARGET must be a repository root holding a deployed .claude/ tree -- never the agent-system source-store directory itself." >&2
   echo "Run: bash deploy-headless.sh $TARGET" >&2
   ```
   This is the literal "only executable change in scope" (outcome 5) — a pure `echo ... >&2`
   addition with no change to exit code, counters, or any gate's logic. The `[ "$FINDINGS" =
   "true" ]` FINDING line may optionally gain the same clarifying clause for consistency, but is
   not required by outcome 3 (which speaks only of "the gate0 error," i.e. the stderr a human/
   agent actually reads).

4. **regeneration-is-manual-only.md (outcome 4) — decision: header alone suffices, with the
   existing pointer left in place and only lightly strengthened.** The "Root-Resolution Guard for
   Core Scripts" section documents a structurally different mechanism (own-location,
   no-argument root resolution) than this task's TARGET-argument contract, and no other file in
   the repo duplicates the header's TARGET-axis language — confirmed by the Findings section's
   repo-wide search above. The one existing sentence that touches `verify-deploy.sh` in that
   section already defers to the header ("see its own header for why"), which is the correct
   "pointer, not a second partial copy" shape this task's own outcome 4 asks for. Recommend
   widening that single sentence by one clause so it names *which* contract the header holds
   (not just "no guard needed"), e.g. changing line 888 from:
   > "`verify-deploy.sh` carries no such guard at all and sits outside this contract entirely --
   > see its own header for why."

   to:

   > "`verify-deploy.sh` carries no such guard at all and sits outside this contract entirely --
   > it resolves TARGET from an explicit argument (not this section's own-location mechanism),
   > and that argument's required shape is a separate contract documented in its own header."

   This keeps the single authority in the script header (where a planner invoking the script
   directly will read it) while giving a reader who lands in `regeneration-is-manual-only.md`
   first enough signal to follow the pointer rather than assume "no guard" means "no
   constraint." No duplicate prose should be added to `regeneration-is-manual-only.md` beyond
   this one-clause widening.

5. **No behavioral change (outcome 5)**: confirmed achievable — every recommended edit above is
   either a comment/header change or a pure `echo ... >&2` addition before the existing `exit 2`.
   No gate's `pass()`/`fail()`/`warn()` call sites, counters, or `[SKIP]` guards are touched.

## Decisions

- The TARGET-argument contract belongs solely in `verify-deploy.sh`'s own header (its usage
  block and gate0 error text are extensions of that same single authority, not separate
  authorities) — not duplicated as new prose in `regeneration-is-manual-only.md`. That file
  gets only a one-clause strengthening of its existing pointer sentence, per outcome 4's "one
  authority plus pointers, never two partial copies" instruction.
- The existing INVOCATION CONTRACT paragraph (the `#441`-landed CWD-resolution claim) is correct
  on its own axis and must be retained, not deleted — the new TARGET-argument paragraph is
  added alongside it, not a replacement.
- The only executable (non-comment) line to change is gate0's stderr emission (adding one `echo
  ... >&2` line); the `FINDING gate0 ...` line, exit code, and every other gate's logic are left
  untouched.

## Risks & Mitigations

- **Risk**: a sibling task (#444, #414, #445, #449, and the dependent extensions-README-table
  task) edits the same header/argument-parsing region concurrently. **Mitigation**: keep this
  task's diff narrowly scoped to (a) the header comment block, (b) the usage-line explanatory
  comment immediately below it, and (c) gate0's stderr block at lines 483-489 — re-read the file
  immediately before editing/committing per the dispatch's concurrency note, and stage only this
  task's own hunks.
- **Risk**: a new header paragraph could balloon into restating the whole per-gate SKIP
  mechanism (20+ sites). **Mitigation**: the recommended paragraph names representative gate ids
  (3, 4, 6, 7, 12, "and others") and points at the existing per-gate `[SKIP]` comment pattern
  (e.g. gate3's own comment at lines 732-734) rather than enumerating every site.
- **Risk**: touching `redeploy_remedy_fragment`'s call site could violate that library's own
  "no trailing newline / contains no task-number reference" contract if the new line is
  concatenated into the same `echo`. **Mitigation**: recommendation 3 above inserts a fully
  separate `echo ... >&2` line, never modifying the `redeploy_remedy_fragment` call or its
  output string.

## Context Extension Recommendations

- **Topic**: TARGET-argument vs. invocation-CWD axis for scripts taking an explicit repo-root
  argument.
- **Gap**: `regeneration-is-manual-only.md`'s Root-Resolution Guard section documents the
  own-location resolution axis exhaustively, but no context file currently names the *general
  pattern* "a script's explicit TARGET/REPO_ROOT argument has its own required-shape contract,
  independent of where the script itself is invoked from" — a pattern that could recur for other
  scripts that accept an explicit target argument (e.g. `check-consumer-freshness.sh`,
  `deploy-headless.sh`).
- **Recommendation**: not a blocking gap for this small task (the header-only fix is self-
  contained and sufficient); worth a future standalone note only if a second script is found
  making the same invocation-CWD/TARGET-argument conflation.

## Appendix

- Search queries/commands used: `grep -n "TARGET=\|CLAUDE_DIR=\|no deploy tree\|gate0\|agent-system/extensions\"" verify-deploy.sh`;
  `grep -rln "no deploy tree" agent-system/extensions/core`; `grep -rln "no deploy tree" <repo>`;
  `grep -n "Root-Resolution Guard for Core Scripts" regeneration-is-manual-only.md`;
  `grep -rln "verify-deploy.sh" scripts/tests/`; `grep -n "resolves its TARGET\|runs correctly
  from either tree\|verify-deploy" regeneration-is-manual-only.md`.
- Files read: `agent-system/extensions/core/scripts/verify-deploy.sh` (lines 1-220, 470-530,
  730-745), `agent-system/extensions/core/scripts/lib/redeploy-remedy-lib.sh` (full),
  `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (lines 850-980),
  `agent-system/extensions/core/context/patterns/ci-deploy-tree-bootstrap.md` (excerpt).
- Task state read from `specs/state.json` (`project_number: 470`) and `specs/TODO.md` (task
  #470 entry) for the full description and REQUIRED OUTCOMES list.
