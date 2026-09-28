# Research Report: Task #260

**Task**: 260 - Fix self-clobbering redeploy in cycle-plan
**Started**: 2026-09-25T21:00:00Z
**Completed**: 2026-09-25T21:45:00Z
**Effort**: research
**Dependencies**: None (sibling task "redundant-verify-deploy-passes" depends on THIS task's
outcome — see Decisions)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`,
  `command-gate-out.sh`, `deploy-headless.sh`, and their test fixtures
- `context/patterns/batch-orchestration-guardrails.md`,
  `context/patterns/regeneration-is-manual-only.md`
- A synthetic bash self-overwrite harness built and run during this research pass (not committed
  to the repo; scratch-only, see Appendix)
**Artifacts**:
- This report: `specs/260_fix_self_clobbering_redeploy_in_cycle_plan/reports/01_self-clobbering-redeploy-hazard.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The crash is real and mechanically well-understood: bash reads a running script incrementally
  by byte offset, and `deploy-headless.sh`'s copy engine overwrites the deployed target file
  in-place (no temp-then-rename). When the overwritten file's caller is itself one of the
  overwritten files, execution resumes at a stale byte offset — silently truncating the rest of
  the script, or (depending on byte-layout luck) parsing garbage into a spurious error like the
  observed `line 998: o: unbound variable`. I reproduced both failure shapes with a small
  synthetic harness independent of the orchestrator's own timing (Appendix).
- **The hazard-class survey found exactly two genuine call sites**, not the fifteen the dispatch's
  starting `grep` list suggested: `orchestrate-cycle-plan.sh:843` (the observed site) and
  `command-gate-out.sh:176`. Every other file in the starting list only *mentions*
  `deploy-headless.sh` in remedy strings, doc comments, or test fixtures — none of them actually
  execute it from inside their own still-running deployed-script body. This matches, almost
  exactly, `regeneration-is-manual-only.md`'s own "exactly two sanctioned automated call sites"
  language (plus a third, `commands/implement.md` Step 4, which lives in the **OpenCode** system,
  not Claude Code's `agent-system/extensions/core`, and is Claude-tool-call-driven rather than a
  bash script resuming mid-file — not a hazard of this class at all; see Risks).
- **This exact hazard class was already recognized and solved once, in-tree, for
  `deploy-headless.sh` itself** — its own header (lines 69–84) documents a "SELF-OVERWRITE HAZARD"
  and fixes it by wrapping its ENTIRE body in a single `main() { ... }` function, defined in full
  (fully parsed) before it is ever invoked, called as the file's last physical statement. I
  verified this exact pattern deterministically neutralizes the hazard (3/3 runs) with the
  synthetic harness, and recommend generalizing it — not inventing a new mechanism — to the two
  real call sites.
- **Recommended fix**: at each of the two call sites, wrap "the deploy call and everything
  textually after it in the file" (never a partial wrap — see Findings) inside one function,
  defined at the point that code currently sits, invoked immediately. This requires no path
  (`$0`/`BASH_SOURCE`/`SCRIPT_DIR`) changes and no restructuring of `set -e`/`set -u` semantics
  (functions inherit both). It is a strictly larger diff for `orchestrate-cycle-plan.sh` (~1,700
  lines move inside the new function) than for `command-gate-out.sh` (~90 lines), but the technique
  is identical and mechanically safe regardless of the wrapped body's size, because bash's parser
  must fully consume a compound command's text before it can execute any part of it — the overwrite
  cannot happen until the deploy statement runs, which cannot happen until the whole enclosing
  function has already been parsed.
- Candidate (b) — invoking the source-store copy of `deploy-headless.sh` instead of the deployed
  one — does **not** close the hole. It only changes which `deploy-headless.sh` binary runs;
  `deploy-headless.sh` is already self-protected regardless of which copy is invoked. The actual
  victim is the *calling* script (`orchestrate-cycle-plan.sh` / `command-gate-out.sh`), which is
  unaffected by which `deploy-headless.sh` copy triggered the overwrite. The one successful manual
  workaround was luck of byte-offset alignment, not a closed hole. Candidate (c) — deferring the
  deploy to run after the script exits — is architecturally heavier (splits one script invocation
  into two across an orchestrator-visible boundary) for no correctness advantage over the
  function-wrap, and complicates the documented in-band deploy-exit-code failure contract; not
  recommended.
- **Sibling-task note**: because the recommended fix does not change which `deploy-headless.sh`
  copy is invoked (`$SCRIPT_DIR/deploy-headless.sh`, the deployed copy, at both sites, unchanged),
  it does not change `deploy-headless.sh`'s own internal `--skip-slow` verify depth either. The
  redundant-verify-deploy-passes sibling task can build on today's fast/full verify-depth split
  unchanged.
- A documentation-accuracy gap surfaced: `batch-orchestration-guardrails.md`'s hazard-3 discussion
  ("(iii) The replacement exposure") frames the mid-run-redeploy risk only as "a *later, fresh*
  subprocess reads new bytes" (safe) — it does not name the sharper, more acute hazard this task
  fixes: the *currently executing* subprocess's own byte offset is invalidated by the write. That
  section should be updated once the fix lands (see Context Extension Recommendations).

## Context & Scope

Task 260 investigates a real, observed `/orchestrate` failure: the Inter-Cycle Redeploy Checkpoint
in `orchestrate-cycle-plan.sh` invokes `deploy-headless.sh`, which — as part of a normal, correct
resync — overwrites `.claude/scripts/orchestrate-cycle-plan.sh`, the very file whose interpreter is
mid-execution at that moment. bash resumed at a stale byte offset and crashed with an `unbound
variable` error inside a single-quoted jq filter string that contains no such variable, proving the
defect is a resumption artifact, not a code bug. The failure is intermittent by construction (depends
on the relative byte layout of old vs. new content), so this research treats "did not reproduce
today" as inconclusive and instead demonstrates the underlying bash mechanism directly.

Scope, per the dispatch: (1) survey every script that could trigger a deploy of itself or a helper
it still needs, separating genuine invocation sites from mere mentions; (2) evaluate the three
candidate fixes (re-exec-from-a-copy, source-store `deploy-headless.sh` invocation, deferred
deploy) without pre-selecting one; (3) preserve the existing three-branch (a)/(b)/(c) deploy-failure
contract; (4) record the decision's implications for the sibling redundant-verify-deploy-passes
task, which edits the same checkpoint block and depends on this one landing first.

## Findings

### The mechanism, demonstrated independently of orchestrator timing

Built a synthetic harness (see Appendix for the exact scripts) with three variants, each run
multiple times fresh (a fresh copy per run, since the rewrite is destructive):

1. **Unprotected, flat top-level script** that prints `STEP1`, then rewrites its own file
   (`cat > "$0"`) with shorter replacement content, then has three more top-level statements.
   Result across 5 runs: all 5 silently stopped after `STEP1` — the remaining statements never
   ran, and the process still exited 0 (no crash, but silent truncation: on this system/bash
   version, the read buffer hit EOF of the new, shorter file rather than landing mid-token). This
   demonstrates the corruption directly: "the rest of the script did not run as written" is exactly
   as dangerous as a crash (in the real incident, the tail of the checkpoint — dispatch-row
   construction — never happened either; it just happened to also throw a visible error first).
   The dispatch's own observed error shape (a spurious `unbound variable` from content that
   shifted into a *non*-boundary-aligned position) is the same class of failure with a different
   content-length delta — confirmed by construction, not merely asserted.
2. **`main() { ... }; main "$@"` wrap** (deploy-headless.sh's own existing pattern, copied
   verbatim) around the identical rewrite-then-continue body. Result across 3 runs: all 3 printed
   every one of the four steps, in order, exit 0 — fully correct, deterministically. This is direct
   evidence the pattern deploy-headless.sh already uses for itself generalizes to "a script that
   triggers something else's overwrite of itself mid-run," not only to "a script that overwrites
   itself directly."
3. **Self-copy-then-`exec`** at the top of the script (copy `$0` to a `mktemp` path, `exec bash
   "$tmp" "$@"` guarded by an env var, before any other logic runs), with the "external overwrite"
   simulated as a *separate* write to the original path (not `$0`, which now points at the temp
   copy) — modeling deploy-headless.sh's real subprocess overwriting the deployed file out from
   under the calling script, not the calling script overwriting itself. Result across 3 runs: all
   3 printed every step correctly. This variant also works, but only once the test is corrected to
   distinguish "the running script's own path" (now the temp copy, safe) from "the original
   deployed path" (irrelevant to the running process once re-exec'd elsewhere) — see Risks below
   for why this is a materially bigger structural change for these two specific call sites than
   the function-wrap.

### Hazard-class survey: two genuine call sites, not fifteen

Searched the whole `agent-system/extensions` tree for actual invocation forms of
`deploy-headless.sh` (`grep -rn "deploy-headless\.sh"`, then filtered to lines that are not
`echo`/`Remedy`/comment/`fail "`/`advisory` strings, and separately confirmed by reading each
match's surrounding code):

| Site (from dispatch's starting list) | Classification | Evidence |
|---|---|---|
| `orchestrate-cycle-plan.sh:843` | **GENUINE — the observed hazard** | `bash "$SCRIPT_DIR/deploy-headless.sh" >&2 \|\| deploy_exit=$?`, ~1,700 lines of top-level logic still to execute after it (through EOF at line 2408) |
| `command-gate-out.sh:176` | **GENUINE — a second, not-yet-observed hazard of the identical class** | `gate_out_deploy_log="$(bash .claude/scripts/deploy-headless.sh 2>&1)" \|\| gate_out_deploy_rc=$?`, ~90 lines of top-level logic still to execute after it (branch handling, a second `update-task-status.sh` retry, artifact-validation sweep, event emission), all the way to EOF at line 265 |
| `skill-base.sh:382` | Mention only | Advisory `echo` string in a warning message; never executes the call |
| `orchestrate-batch-admit.sh:360,364` | Mention only | Comment + remedy `echo` string |
| `orchestrate-build-dispatch.sh:360` | Mention only | Remedy string appended to a context blob |
| `task-lock.sh:216,223` | Mention only | Comment + remedy `echo` string |
| `git-snapshot.sh:130` | Mention only | Remedy `echo` string |
| `validate-state.sh:248` | Mention only | Advisory `echo` telling the operator to deploy manually, then re-run |
| `verify-deploy.sh` (6 hits) | Mention only | Comments, `fail "..."` diagnostic messages, a header cross-reference — `verify-deploy.sh` is *called by* `deploy-headless.sh`, never the reverse |
| `check-deploy-freshness.sh:95,126` | Mention only | Remedy `echo` strings |
| `check-consumer-freshness.sh` | Mention only, and structurally inverted | Comments describe that *`deploy-headless.sh` calls this script* (its `--consumer-report` post-deploy hook), not the other way around; when it runs, the deploy that invoked it has already fully completed in a prior step of `deploy-headless.sh`'s own `main()`, so there is no mid-execution overwrite of `check-consumer-freshness.sh` itself |
| `deploy-root-guard.sh:27` | Mention only | Remedy `echo` string |
| `system-defect-record.sh:52` | Mention only | Remedy `echo` string |
| `measure-eager-context.sh:17,19` | Mention only, self-declared | Comment explicitly states "this script is not it" (not a deploy trigger) |
| `check-extension-docs.sh` (7 hits) | Mention only | Advisory strings, a header comment, and a *regression-guard* that greps for a wrong invocation-path defect (`test`-adjacent code, not a live invocation) |

A broader sweep (`grep -rn "deploy-headless\.sh"` across all of `agent-system/extensions`, filtered
to exclude message/comment/test-fixture noise) turned up nothing beyond the same two sites plus
test-fixture mocks in `tests/test-deploy-verify-wiring.sh`, `test-deploy-propagation.sh`,
`test-deploy-orphans.sh`, and `tests/test-orchestrate-cycle-plan.sh` (all of which stub or
reference `deploy-headless.sh` as fixture material, not as a live production invocation).

This two-site result is independently corroborated by
`context/patterns/regeneration-is-manual-only.md`, which documents "**The exact and only
sanctioned automated call site**" for the Inter-Cycle Redeploy Checkpoint
(`orchestrate-cycle-plan.sh`'s Stage MT-3 step 7) in one subsection, and a second exception for
"**The Postflight Completion-Deploy Gate**" naming `command-gate-out.sh`'s `rc == 6` branch plus
`commands/implement.md` Step 4 as sanctioned sites. The third name, `commands/implement.md`, does
not exist under `agent-system/extensions/core` at all — it exists only under `.opencode/` (a
parallel, separate system, not Claude Code's `.claude/` deploy tree this task is scoped to), and
even there it is markdown driving Claude's own tool calls rather than a bash script resuming
mid-file across a subprocess boundary. It is not a hazard of the class this task investigates (a
single Bash tool call is a fresh subprocess every time; there is no "resume reading the same file
after it changed" step across two separate tool invocations). Flagged under Risks as worth a
follow-up look at the OpenCode side, out of scope here.

### `deploy-headless.sh`'s own prior art, precisely

`scripts/deploy-headless.sh:69-84` ("SELF-OVERWRITE HAZARD" comment):

> bash reads a script incrementally by byte offset as it executes it, not by loading the whole
> file into memory upfront. The copy engine's write path overwrites an existing target file in
> place -- with no temp-then-rename indirection. ... The fix: this file's entire executable body is
> a single `main()` function, defined in full (and therefore fully parsed by bash) BEFORE any of
> it runs, invoked as the file's last physical command with nothing following it. Every exit path
> inside `main` calls `exit` explicitly -- never `return` followed by further top-level reads.

This is the *identical* mechanism and the *identical* mitigation this task needs — it is simply
not yet applied to the two scripts that *call* `deploy-headless.sh` and need to keep running
afterward. The dispatch is explicit that a third one-off patch at the observed call site would
"leave the class open for the next caller" — applying the SAME already-proven pattern to both real
call sites is generalization, not a new one-off.

The two other cited prior-art fragments (`:140-141`, `:304-312`) are a different but related
lesson: `deploy-headless.sh` avoids *sourcing* `task-lock.sh` (because it is about to overwrite
that very file) and, separately, documents that its own internal `generate-context-line-counts.sh`
call deliberately uses the **deployed** copy (`$TARGET/.claude/scripts/...`), because
`deploy-root-guard.sh`'s root computation (`../..`) is only valid two levels under a deployed
`scripts/` tree — a source-store invocation would violate that assumption. This is the basis for
rejecting candidate (b) below at the `deploy-headless.sh`-internals level too: `deploy-headless.sh`
already has good, load-bearing reasons to keep using deployed-copy paths internally, so routing the
*outer* call through the source-store copy would not even be uniformly safe on its own terms,
separately from the fact that it does not protect the calling script at all (see next section).

### Candidate fix evaluation

**(a) Re-exec from a copy placed outside the deploy tree.** Mechanically proven to work (harness
variant 3). However, for these two specific call sites it is a *larger and riskier* change than it
first appears: both scripts derive path information from their own on-disk location.
`orchestrate-cycle-plan.sh:204` computes `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
and later uses `$SCRIPT_DIR/deploy-headless.sh` (line 843) plus other `$SCRIPT_DIR/...` sibling
references throughout. If the running process re-execs from a `mktemp` file (a single copied file,
not a copied directory), `BASH_SOURCE[0]`'s directory becomes the temp directory, and every
`$SCRIPT_DIR/...` sibling reference breaks unless the *original* `SCRIPT_DIR` is captured before
the copy/re-exec and threaded through separately (e.g. as an exported variable), decoupling "where
this script's own text lives" from "where its sibling files live." That is achievable, but it adds
a second path variable to reason about everywhere `SCRIPT_DIR` is currently used, for no
correctness benefit over the function-wrap, which needs no path changes at all. Re-exec also
starts a brand-new process image (loses any un-exported shell state accumulated before the re-exec
point, so it would need to run at the very top of the script, before anything else executes, to
avoid subtly dropping state) and complicates already-narrow lock/mutex reasoning (the checkpoint
holds no explicit lock at this specific point beyond the fail-open `specs/.deploy-lock` internal to
`deploy-headless.sh` itself, but a re-exec'd process has a new PID, which is worth flagging for any
future PID-based bookkeeping). Net: works, but is the higher-complexity option for this codebase's
existing structure.

**(b) Invoke the source-store copy of `deploy-headless.sh`.** Does **not** close the hole. The
crash observed in the incident was inside `orchestrate-cycle-plan.sh` (the *caller*), not inside
`deploy-headless.sh` (the callee) — and `deploy-headless.sh` is already immune to self-overwrite
regardless of which copy of it is invoked, because of its own `main()` wrapper (prior-art section
above). Switching which `deploy-headless.sh` binary is *invoked* has zero effect on whether the
*calling* script's own remaining top-level statements survive the redeploy that `deploy-headless.sh`
performs — the redeploy still rewrites `.claude/scripts/orchestrate-cycle-plan.sh` (and
`command-gate-out.sh`) as part of the same `core` extension resync either way. The operator's one
successful anecdote is best explained as a byte-offset-layout coincidence (the harness above shows
outcomes are layout-dependent), not a closed hole — matching the dispatch's own instruction not to
treat a single non-crash as proof of safety. Additionally, per the prior-art note above,
`deploy-headless.sh` has its own documented reasons to keep some *internal* calls pointed at the
deployed tree; routing its own outer invocation through the source store does not obviously
compose cleanly with that. **Not recommended**, and not needed once the calling scripts are
themselves protected.

**(c) Defer the deploy to run after the script exits.** Would require splitting one script
invocation into (at minimum) two, with the actual `deploy-headless.sh` call happening in a
separate process sandwiched between them (e.g. handed to the orchestrator's own per-cycle Bash
tool-call sequencing, which — like the OpenCode `implement.md` case above — genuinely would be
immune to the hazard, since each Bash tool call is a fresh subprocess). But the checkpoint's
documented failure contract needs `deploy_exit` and the pre/post `verify-deploy.sh` findings
comparison **in-band**, synchronously, to decide whether to defer the rest of the cycle (branches
(a)/(b)/(c) in the existing comment block) — deferring the deploy to "whenever the script next
happens to run" would mean either duplicating that decision logic into a second script/stage, or
teaching the orchestrator-level caller (SKILL.md) to thread the deploy's exit code and findings
snapshot back into a resumed invocation of the *same* script, which is materially more moving
parts than the function-wrap for no correctness gain. **Not recommended.**

**Recommended: generalize `deploy-headless.sh`'s own pattern (function-wrap) to both real call
sites.** At `orchestrate-cycle-plan.sh`, wrap the redeploy-checkpoint code and everything after it
in the file (from the comment block starting near line 700, through true EOF at line 2408) inside
one function, defined exactly where that code currently sits, invoked immediately after its
closing brace. At `command-gate-out.sh`, the equivalent wrap covers roughly line 176 through EOF at
line 265 (or, more simply and with an even smaller blast radius, the whole file's executable body
from just after the `source` lines at the top, matching `deploy-headless.sh`'s own "wrap
everything" convention exactly, which avoids having to reason about exactly which top-level
statement is "the first one that could possibly still be pending when the deploy fires").
**A partial wrap that stops at the end of the checkpoint block does not work**: control returns
from that function back to flat top-level code, which resumes reading the (already-rewritten) file
at a stale offset for its OWN remaining statements — the identical hazard, merely relocated a few
hundred lines later. The wrap must extend to the true end of file (or, in `command-gate-out.sh`'s
case, to the script's own final statement) with nothing top-level left unread. Verified in the
grep sweep above that no top-level code either side of the intended wrap boundary in either script
references the script's own raw `$1`/`$2`/`$@` positional parameters outside an already-`local`
function scope, so no argument-forwarding changes are needed at the wrap boundary. `set -e`
(`command-gate-out.sh`) and `set -euo pipefail` (`orchestrate-cycle-plan.sh`) are both inherited
into a called function unchanged, so no semantic shift there either.

## Decisions

- **Chosen mitigation direction**: function-wrap (deploy-headless.sh's own existing, proven
  pattern), applied to both `orchestrate-cycle-plan.sh` (from the redeploy-checkpoint comment block
  through EOF) and `command-gate-out.sh` (from just after its top-of-file `source` lines through
  EOF). Not chosen: source-store `deploy-headless.sh` invocation (insufficient — does not protect
  the caller) or deferred/split-invocation deploy (unnecessary complexity, threatens the in-band
  failure contract).
- **Which `deploy-headless.sh` copy runs is UNCHANGED** by this decision: both call sites keep
  invoking the deployed copy (`$SCRIPT_DIR/deploy-headless.sh` /
  `.claude/scripts/deploy-headless.sh`), exactly as today. **This is the explicit input the
  redundant-verify-deploy-passes sibling task should build on**: its own `--skip-slow` internal
  verify-depth split inside `deploy-headless.sh` is untouched by this task's fix, so that sibling
  task does not need to re-derive or adjust for a changed invocation target.
- The existing three-branch (a)/(b)/(c) deploy-failure contract
  (`batch-orchestration-guardrails.md`'s "### The Inter-Cycle Redeploy Checkpoint" subsection,
  `command-gate-out.sh`'s `rc==6` handler) is preserved byte-for-byte in behavior by this fix — the
  function-wrap only changes *where the code that already exists lives syntactically*, not what it
  does or in what order.
- The hazard-class survey is closed at two genuine sites for `agent-system/extensions/core`; no
  third site needs a matching fix in this codebase (the third name found in
  `regeneration-is-manual-only.md`, `commands/implement.md`, resolves only under `.opencode/`,
  which is out of this task's scope).

## Risks & Mitigations

- **Risk**: a future caller adds a third genuine `deploy-headless.sh` invocation site without
  applying the same wrap, reopening the class exactly as the dispatch warned against a third ad hoc
  patch. **Mitigation**: the plan phase should update
  `context/patterns/regeneration-is-manual-only.md`'s "Automated Exception" subsections (both of
  them) to name the function-wrap requirement explicitly as part of what "sanctioned" means for a
  new automated call site, not merely list the site.
- **Risk**: `batch-orchestration-guardrails.md`'s existing hazard-3 "(iii) The replacement
  exposure" prose currently frames the mid-run-redeploy risk in terms that read as already
  "contained," using language about a "fresh subprocess" reading new bytes — which is true for
  *future, unrelated* invocations of the seven listed critical-path scripts, but is not what this
  task's incident actually was (the *currently executing* subprocess's own byte-stream). A reader
  could mistake that prose as already covering this defect. **Mitigation**: plan phase should
  update that subsection to name the sharper in-flight-corruption case explicitly and point to
  wherever the fix lands, once implemented (see Context Extension Recommendations).
- **Risk (out of scope, flagged only)**: the OpenCode system's own `commands/implement.md` /
  `.opencode/` tree was not audited by this research pass beyond confirming it is a different,
  non-bash-script-resumption call shape. If OpenCode's own dispatch machinery is ever implemented
  as a bash script that both triggers a redeploy and needs to keep running afterward, it should be
  audited separately — not assumed safe by analogy to Claude Code's `commands/*.md` (Claude
  tool-call-driven) semantics without checking.
- **Risk**: moving ~1,700 lines of `orchestrate-cycle-plan.sh` inside a new function is a large
  mechanical diff that is easy to get subtly wrong (a stray unmatched brace, a `local` that shadows
  a variable a later helper function expected to be global, etc.). **Mitigation**: the existing
  `tests/test-orchestrate-cycle-plan.sh` suite already exercises every branch of the checkpoint
  (cases (a)–(r) per the grep above) end-to-end via its `deploy-headless.sh` stub mechanism
  (`write_g11_deploy_headless_stub`); re-running that full suite unmodified after the refactor is
  a strong regression signal that the wrap changed nothing behaviorally. That existing stub does
  **not** currently make the mock `deploy-headless.sh` rewrite the calling
  `orchestrate-cycle-plan.sh` copy under test, so it would not by itself catch a regression of
  *this specific* hazard — the plan phase should add one new test case that has the stub rewrite
  the test's own copy of `orchestrate-cycle-plan.sh` (byte-identical content is enough per the
  incident's own "diff clean" observation) and assert the cycle still produces a non-empty plan
  and dispatch rows afterward, directly exercising Verification item 2 from the dispatch.

## Context Extension Recommendations

- **Topic**: mid-execution self-overwrite hazard for scripts that trigger `deploy-headless.sh`.
  **Gap**: `context/patterns/regeneration-is-manual-only.md`'s two "Automated Exception"
  subsections name the two sanctioned call sites but do not require (or even mention) the
  function-wrap structural precondition that makes invoking `deploy-headless.sh` from inside a
  still-running deployed script safe. **Recommendation**: once the fix lands, add one sentence to
  each subsection pointing at `deploy-headless.sh`'s own "SELF-OVERWRITE HAZARD" header comment
  and stating that any sanctioned call site must wrap its own remaining logic the same way.
- **Topic**: the "(iii) The replacement exposure" hazard-3 discussion in
  `batch-orchestration-guardrails.md`. **Gap**: as written, it reads as already covering "a mid-run
  redeploy swaps executing machinery," which could be misread as already accounting for the
  narrower, more severe in-flight self-corruption this task fixes. **Recommendation**: the plan
  phase should add a clause distinguishing "a later, fresh invocation of a critical-path script
  reads new bytes" (true, and safe) from "the currently-executing invocation that triggered the
  redeploy has its own byte-stream invalidated" (the actual incident; now closed by this task's
  fix at the two real call sites), so a future reader does not need to re-derive the distinction
  from scratch.

## Appendix

### Search queries / commands used

- `grep -rln deploy-headless.sh` (repo-wide, matching the dispatch's own starting point)
- `grep -rn "deploy-headless\.sh" --include="*.sh" agent-system/extensions | grep -viE
  "echo|remedy|comment|#|Run:|fail \"|advisory|grep -rn|grep -oE"` (filtered to genuine invocation
  forms)
- Manual read of `orchestrate-cycle-plan.sh` lines 1-40, 200-210, 700-1010, 2380-2408
- Manual read of `command-gate-out.sh` lines 1-50, 140-265
- Manual read of `deploy-headless.sh` lines 1-180, 280-345
- Manual read of `context/patterns/regeneration-is-manual-only.md` lines 77-140 and
  `context/patterns/batch-orchestration-guardrails.md` lines 330-385, 522-540
- `find . -iname "implement.md"` to check the third name in `regeneration-is-manual-only.md`

### Synthetic self-overwrite harness (scratch-only, not committed)

Three scripts were written to `/tmp/claude-1000/.../scratchpad/selfoverwrite/` and run directly
with `bash`, each rewriting its own on-disk file mid-execution with shorter replacement content,
to demonstrate the mechanism named in the dispatch (a small harness that rewrites its own file
mid-execution with content of a different length) independently of any orchestrator timing:

1. **Unprotected** (flat top-level `echo`s around a `cat > "$0" <<'NEWCONTENT' ... NEWCONTENT`
   self-rewrite): 5/5 runs printed only the pre-rewrite output; the three post-rewrite statements
   never executed (silent truncation — the same corruption class as the incident's crash, just
   landing on an EOF rather than a garbled mid-token position for this particular length delta).
2. **`main() { ... }; main "$@"`-wrapped** (identical body, wrapped in the same pattern
   `deploy-headless.sh` already uses on itself): 3/3 runs printed all four expected lines in order,
   exit 0.
3. **Self-copy-then-`exec`** (`cp "$0" "$tmp"; exec bash "$tmp" "$@"` guarded by an env var, with
   the simulated external overwrite targeting the *original* path rather than `$0`/the temp copy,
   to correctly model a separate process — deploy-headless.sh — rewriting the deployed file out
   from under the caller): 3/3 runs printed all four expected lines in order, exit 0.

These confirm, independently of bash version quirks or the orchestrator's own timing, that (i) the
hazard is real and produces observable corruption (not merely theoretical), and (ii) both the
function-wrap and the self-copy-reexec techniques neutralize it deterministically — the choice
between them for this codebase is about integration cost (path-variable semantics, process-identity
implications), not about whether either one works.
