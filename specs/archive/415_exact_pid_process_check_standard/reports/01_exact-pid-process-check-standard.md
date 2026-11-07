# Research Report: Exact-PID Process Check Standard

**Task**: 415 - Record exact-pid process checking as a parallelism-safety suite-authoring standard, replacing broad process-name matching
**Started**: 2026-11-05
**Completed**: 2026-11-05
**Effort**: small (doc subsection + corpus audit; no code defects found to fix)
**Dependencies**: Sequenced after the verdict-extraction enforcement work (specs/414_enforce_verdict_extraction_contract), which also edits `context/standards/shell-script-testing.md`. Rebase onto its landed edit.
**Sources/Inputs**: Codebase (agent-system/extensions/core source store, scripts/tests/**, scripts/*.sh), specs/archive/411_refactor_verify_deploy_gate_framework/issues.jsonl, specs/414_enforce_verdict_extraction_contract/ (lint precedent), context/patterns/bounded-build-waiter.md
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The origin defect is real and precisely as described: `test-gate-registry-resolution.sh` case13
  once used a `pgrep -f "sleep 30"`-style leftover-process check that collided with a concurrent
  sibling suite's identically-shaped fixture. It was fixed in-task (task 411,
  `iss_1792068891184_VXuGxJ`) by capturing the stalled descendant's own pid at spawn and checking
  that exact pid's liveness via `kill -0` — the fix is live in the current source at
  `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh:195-227`.
- `context/standards/shell-script-testing.md` genuinely has no process-check guidance anywhere —
  confirmed by a full-document grep for `pgrep`/`pkill`/exact-pid terms before this task's edit.
  The fix exists in code; the rule does not exist in the standard. This is the gap the dispatch
  names, and it is real.
- **Corpus audit result: zero live violations in the suite battery.** A full-corpus grep for
  `pgrep -f`, `pkill -f`, `pgrep -af`/`-fa`, and `ps aux|grep` / `ps -ef|grep` across
  `agent-system/extensions/core/scripts/tests/*.sh` and `agent-system/extensions/core/scripts/*.sh`
  returns ~20 textual hits in 6 files; every hit is either (a) the already-fixed case13 (now a
  comment explaining the fix, not a live check), (b) a comment in `lake-build-guard.sh` /
  `test-lake-build-guard.sh` documenting the *same* anti-pattern for a different reason
  (self-match avoidance), (c) a fixture command string fed to `test-validate-bounded-waiter.sh`,
  which tests a *different, already-existing* lint (`validate-bounded-waiter.sh`, enforcing
  `context/patterns/bounded-build-waiter.md` Rule 2 on dispatched agents' own Bash commands — not
  on suite source), or (d) a classification-matcher test fixture in
  `test-claude-refresh-matcher.sh`. No suite currently performs a name-based leftover-process
  check. The audit's own search commands are recorded below so a future reader can re-run it.
- A mechanical lint is **declined** (prose-only recommendation), on the evidence this audit
  produced: of ~20 textual hits, 0 are violations and most would require a per-file allowlist
  entry to stay green — exactly the high-exemption-ratio condition the dispatch instructed this
  research to watch for and decline a lint on. A narrower, line-shape-based lint (analogous to
  `lint-state-writer-boundary.sh`) is technically buildable but has no current violating target
  to prove detection against without an artificially seeded fixture, and the exemption list would
  already cover more files than any plausible future violation count. Recommendation: prose
  subsection only, revisit a lint only if a second live occurrence is ever found.
- Recommended placement: a new subsection inside the existing
  `## Suite runtime: \`--jobs\`, \`--timings\`, and gate selection` section, immediately after its
  closing bullet list (after line 536, before `### Mapping a touched file to its suite`) — this
  is where an author already reads about `LOAD_SENSITIVE_BASENAMES` and the parallel pool, per
  the dispatch's own placement instruction.

## Context & Scope

Researched: (1) the origin issue-log entry and the fix it already produced in code; (2) whether
`context/standards/shell-script-testing.md` truly lacks process-check guidance; (3) whether any
other suite in the battery currently performs a name-based process check that needs fixing as
part of this task; (4) whether a sibling agent-layer discipline already exists that this task's
standard should relate to or distinguish itself from; (5) whether a mechanical lint is cheap to
add in the same family as the sibling verdict-extraction-anchoring lint (task
`specs/414_enforce_verdict_extraction_contract`).

Out of scope per the dispatch: writing the subsection and performing any code fix is the
implementation phase's job, not this report's. This report establishes the audit evidence,
placement, and the lint-vs-prose decision so the plan/implement phases do not have to re-derive
them.

## Findings

### Codebase Patterns

**The already-fixed origin case** (`agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh:195-227`,
case13): spawns `sleep 30 &` inside the function under test, writes `$!` (the exact pid) to a
dedicated pidfile, and after the bounded call returns, checks `kill -0 "$stalled_pid13"` against
that exact captured pid — never a name/pattern match. The case's own comment (lines 219-225)
already states the rationale in almost exactly the dispatch's own words: a broad `pgrep -f
"sleep 30"` pattern would misattribute a concurrent sibling suite's own unrelated `sleep 30` as a
leftover. This is the canonical shape to cite verbatim in the new standard subsection — it is
already proven, already in the corpus, and needs no new code to demonstrate.

**The standard's gap, verified directly**: `grep -n "pgrep\|pkill\|exact.pid\|exact pid" context/standards/shell-script-testing.md`
returns nothing before this task. The document's existing parallelism material — the `## Suite
runtime: \`--jobs\`, \`--timings\`, and gate selection` section (lines 452-536) covering
`--jobs`, `LOAD_SENSITIVE_BASENAMES`, and the `## Gate-level parallelism-safety audit (Phase 7)`
section (lines 779-825) covering fixed-path resource collisions across gates — never once
discusses process *identity* checks. The Phase 7 section's own method (reading every gate body
for a fixed-path write/lock/socket collision) is the closest existing analogue in spirit (asking
"could two concurrent workers collide on the same identifier") but covers a structurally
different hazard (shared file paths, not process names) and does not generalize to cover this
rule by reference.

**Corpus audit (full search commands and result)**:

```bash
cd agent-system/extensions/core
grep -rn "pgrep -f\|pgrep[[:space:]]*-[a-z]*f" scripts/tests/ scripts/*.sh
grep -rn "pkill -f\|pkill[[:space:]]*-[a-z]*f" scripts/tests/ scripts/*.sh
grep -rn "ps aux.*grep\|ps -ef.*grep\|ps ax.*grep" scripts/tests/ scripts/*.sh
grep -rln "pgrep\b\|pkill\b" scripts/tests/ scripts/*.sh
```

Result: hits in exactly 6 files, all non-violating:

| File | Nature of hit |
|---|---|
| `scripts/tests/test-gate-registry-resolution.sh` | case13, already fixed; remaining text is the explanatory comment, not a live check |
| `scripts/tests/test-validate-bounded-waiter.sh` | Fixture command *strings* fed to `validate-bounded-waiter.sh` (a hook under test), proving that OTHER hook correctly flags/allows `pgrep -f` / `ps aux\|grep` patterns in **agents'** Bash commands. This suite does not itself perform a leftover-process check. |
| `scripts/tests/test-lake-build-guard.sh` | Tests that `lake-build-guard.sh --help` documents the `pgrep -f` self-match pitfall, and that `cmd_status` does not reintroduce a `pgrep -f`/`pgrep lean` scan internally. Testing the subject's absence of the pattern, not using it. |
| `scripts/lake-build-guard.sh` | Production script; comments *instructing against* `pgrep -f` self-match, consistent with (not a violation of) the rule. |
| `scripts/orchestrate-build-dispatch.sh`, `scripts/dispatch-strand-probe.sh` | Comments citing `bounded-build-waiter.md`'s "never `ps \| grep`/`pgrep -f`" rule. Consistent, not violations. |
| `scripts/tests/test-claude-refresh-matcher.sh` | Fixture string classifying a legacy `ps aux \| grep` poll shape for a matcher under test; not a leftover-process check performed by the suite itself. |

Zero occurrences outside `agent-system/extensions/core/scripts/**` were searched for per the
dispatch's instruction to record the boundary rather than silently widen it: the dispatch's own
file-footprint (`agent-system/extensions/core/**`) and the sibling-sequencing note both scope
this task to core's own suites; other extensions' suite corpora were not audited and this report
does not claim coverage of them.

**Conclusion**: the audit finds no suite in the current battery requiring a fix. The "audit the
existing suites and fix any remaining occurrences" directive produces a count of **zero** to fix,
which is itself the required, re-runnable result (not a bare unverified "no occurrences found" —
the search commands above are the re-run recipe).

### External Resources

Not applicable — this is a pure codebase-convention task; no external library or web research
was needed or performed.

### Adjacent, Already-Codified Discipline (same mechanism, different layer)

`context/patterns/bounded-build-waiter.md` (created 2026-09-21) already states, as Rule 2,
"Writer liveness by captured PID, never by name. ... Never use `ps \| grep`, `pgrep -f`, or any
process-name-matching test — the polling shell's own argv can contain the same text as the
command it is searching for, producing a self-match that never resolves." That rule is enforced
mechanically today via a hook, `validate-bounded-waiter.sh` (regression-covered by
`test-validate-bounded-waiter.sh`, the suite the audit above found fixture strings in).

This is the **same underlying mechanism** (name-based process matching is unsafe under
concurrency) stated for a **different actor and a different hazard**: `bounded-build-waiter.md`
governs a *dispatched agent's own Bash wait command* against *self-match* (the waiting shell's
own argv contains the search pattern). This task's standard governs a *test suite's leftover/
liveness check* against *sibling-suite collision* (a concurrent, unrelated process legitimately
sharing the same name). They are siblings, not duplicates — the same discipline for a different
reason, applied by a different actor, enforced (if at all) by a different mechanism. The new
subsection should cross-link `bounded-build-waiter.md` for consistency (the standards doc
currently has zero cross-references to it) but must not present the two as one rule, mirroring
the dispatch's own warning (in its ORIGIN section) against conflating adjacent-but-distinct
entries.

### Mechanical Enforcement Feasibility

The sibling lint family (`agent-system/extensions/core/scripts/lint/lint-verdict-extraction-anchoring.sh`,
from `specs/414_enforce_verdict_extraction_contract`, and `lint-state-writer-boundary.sh`) both
follow the same shape: a regex-only, line-oriented content lint over `.sh`/`.md` text, with an
explicit, individually-reasoned file-level allowlist for legitimate occurrences of the
anti-pattern's literal text (`lint-state-writer-boundary.sh`'s header names this directly as
"Layer 2: file-level allowlist" and documents its own known limitations as a content-shape lint,
not a semantic one).

Applying that template here: a lint matching `pgrep\s+-[a-z]*f` / `pkill\s+-[a-z]*f` /
`ps\s+(aux|-ef)\s*\|\s*grep` inside `scripts/tests/**` and flat `scripts/*.sh` would need an
allowlist entry for at least `test-validate-bounded-waiter.sh`, `test-lake-build-guard.sh`,
`test-claude-refresh-matcher.sh`, `lake-build-guard.sh`, `orchestrate-build-dispatch.sh`, and
`dispatch-strand-probe.sh` — 6 of the 6 files the audit found anything in, i.e. **100% of current
hits would need an exemption**, with zero current hits to prove the lint actually catches
anything without an artificially seeded fixture. This is precisely the condition the dispatch's
"Treat this as a research question with a real possible answer of 'prose only'" framing
anticipated. Recommendation: **decline the mechanical lint now.** Prose-only guidance, backed by
the already-fixed case13 as a worked example, is the right scope for this task. If a second live
violation is ever found in a future audit, revisit with that occurrence as the lint's first real
catch (rather than a synthetic fixture), which also resolves today's zero-current-target problem.

## Decisions

- **Scope the standard's new subsection to `context/standards/shell-script-testing.md`'s
  `## Suite runtime: \`--jobs\`, \`--timings\`, and gate selection` section**, inserted
  immediately after its closing bullet list (after the `--class`/`--tag`/`--cost-class` bullet,
  before `### Mapping a touched file to its suite`) rather than near the Phase 7 gate-collision
  audit section — the dispatch's placement instruction names the `--jobs`/serialized-set
  discussion specifically, and that is the material an author already reads when authoring a
  leftover-process check for a suite (not the separate gate-grain fixed-path-collision audit).
- **Use `test-gate-registry-resolution.sh` case13 as the worked example** cited by name and line
  range, since it is a real, already-landed fix rather than a hypothetical.
- **State the serialized-set non-substitution point explicitly** (per the dispatch): add a
  one-sentence note that `LOAD_SENSITIVE_BASENAMES` addresses load-sensitivity, not check
  precision, and using it to avoid fixing an imprecise check both slows the pool and leaves the
  bug in place — this directly parallels the existing "load-sensitive" category prose at lines
  661-664 (`a suite belongs in known-failures.txt under this category only if it is ALSO
  known-failing, which is a different condition from being merely excluded from the parallel
  pool`), so the new subsection should echo that document's existing voice rather than introduce
  new terminology for the same kind of distinction.
- **Decline a mechanical lint** (see Mechanical Enforcement Feasibility above); record the
  decision and its evidence in the implementation's own artifacts so the question is not reopened
  from scratch, per the dispatch's verification bullet.
- **No code fix is needed** — the audit's zero-violation result means the implementation phase's
  "audit and fix" step has nothing further to do beyond recording the same zero-count result
  (with the search commands) that this report already establishes; re-deriving it live at
  implementation time is still correct practice (do not simply cite this report's number without
  re-running the search), per this codebase's own stated "re-run, don't cite frozen numbers"
  convention (seen verbatim at shell-script-testing.md:582).
- **Cross-link `context/patterns/bounded-build-waiter.md`** from the new subsection, stated as a
  related-but-distinct discipline (different actor, different hazard), not folded into one rule.

## Recommendations

1. Add a new subsection titled e.g. `### Process checks under the parallel pool: exact pid, never
   process-name matching` inside `## Suite runtime: \`--jobs\`, \`--timings\`, and gate
   selection`, stating:
   - The rule: a suite's leftover/liveness check on a process it spawned MUST check the exact
     captured pid (`pid=$!` at spawn, `kill -0 "$pid"` to test liveness), never `pgrep -f`,
     `pkill -f`, or `ps | grep` against a name/command-line pattern.
   - The mechanism-level reason (sibling collision under the parallel pool), not just "it caused
     an incident once" — stated in terms of the host-vs-suite distinction (a name match tests the
     whole host's process table, not this suite's own spawned process).
   - The strictly-worse kill case: a name-based `pkill -f` inside a suite can terminate a
     sibling's in-flight work — name this as the adjacent, worse failure mode explicitly.
   - The canonical shape, citing `test-gate-registry-resolution.sh` case13 by name and line range
     as the concrete, already-proven example.
   - The `LOAD_SENSITIVE_BASENAMES` non-substitution point.
   - A cross-link to `context/patterns/bounded-build-waiter.md` as the sibling agent-layer
     discipline (same mechanism, different actor/hazard — do not merge).
2. Record the audit as a stated count with files named (the table above), reusing this report's
   search commands verbatim so a future reader can re-run them — do not restate only "no
   occurrences found."
3. Decline a mechanical lint; record why (the 100%-exemption-rate finding above) directly in the
   plan/summary artifact, not only in this report, so the "declined, with reasoning recorded"
   verification bullet is satisfied by an artifact that survives past this report's own lifecycle.
4. Add `pid`, `process-check`, and `parallelism-safety` to
   `agent-system/extensions/core/index-entries.json`'s `shell-script-testing.md` entry's
   `keywords`/`topics` arrays once the subsection lands (current entry carries only `topics:
   ["quality"]` and a keyword set with no process/pid/parallelism terms — see Context Extension
   Recommendations).
5. Final phase: declare the complete gate set with an explicit source-store `TARGET`, per the
   dispatch's verification bullet (the bare form silently skips source-store-only gates) — this
   is a plan/implement-phase action item, flagged here so it is not dropped.

## Risks & Mitigations

- **Risk**: a future suite author still reaches for `pgrep -f` out of habit even after this
  subsection lands, since nothing mechanical stops them today. **Mitigation**: the prose is
  explicit and copy-pasteable (the canonical `pid=$!` / `kill -0` shape), and the decision to
  decline a lint is recorded with its reasoning so a later task can revisit it cheaply if a second
  real violation appears — the lint's non-existence is a recorded, reasoned choice, not an
  oversight.
- **Risk**: placing the new subsection inside the `--jobs` section could visually conflate
  "opt-in parallel scheduling" with "process-identity correctness," which are different axes.
  **Mitigation**: give the subsection its own `###` heading (not folded into the existing bullet
  list) so it reads as an adjacent, separately-headed topic reachable from the same section, per
  the dispatch's own "reachable from... not appended as an orphan section" verification bullet.
- **Risk**: sequencing collision with the verdict-extraction task (`specs/414_...`), which also
  edits this same file. **Mitigation**: already named by the dispatch's own Sequencing Note;
  the implement phase must re-read the file immediately before editing (per the Territory
  contract) and rebase onto whatever `414` has already landed rather than reverting it.

## Context Extension Recommendations

- **Topic**: process-identity / pid-based liveness checking as a parallelism-safety concern.
- **Gap**: `agent-system/extensions/core/index-entries.json`'s entry for
  `standards/shell-script-testing.md` carries `topics: ["quality"]` only and a `keywords` array
  with no `process`, `pid`, or `parallelism` term, so a future keyword-based context-discovery
  query for "process check" or "pid" would not surface this standard even after the new
  subsection lands.
- **Recommendation**: when the implementation phase adds the subsection, also update that
  index-entries.json entry's `keywords` (add `pid`, `process-check`) and `topics` (add
  `parallelism-safety` or similar) so discovery reaches the new material. This is a small,
  same-task-scope addition, not a new follow-up task.

## Appendix

- Search queries used:
  - `grep -n "LOAD_SENSITIVE_BASENAMES\|--jobs\|parallel" context/standards/shell-script-testing.md`
  - `grep -rn "pgrep -f\|pgrep[[:space:]]*-[a-z]*f" scripts/tests/ scripts/*.sh`
  - `grep -rn "pkill -f\|pkill[[:space:]]*-[a-z]*f" scripts/tests/ scripts/*.sh`
  - `grep -rn "ps aux.*grep\|ps -ef.*grep\|ps ax.*grep" scripts/tests/ scripts/*.sh`
  - `grep -rln "pgrep\b\|pkill\b" scripts/tests/ scripts/*.sh`
  - `grep "VXuGxJ" specs/archive/411_refactor_verify_deploy_gate_framework/issues.jsonl`
  - `grep -rl "verdict-extraction" specs/ agent-system/`
- References:
  - `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh:195-227` (the
    fixed case)
  - `agent-system/extensions/core/context/standards/shell-script-testing.md:452-536` (insertion
    point), `:779-825` (adjacent Phase 7 audit, not the insertion point), `:654-660` (the "once
    mis-attributed to ambient load" note the dispatch references as the doc's only adjacent
    content)
  - `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` (sibling discipline)
  - `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` (lint-shape
    precedent and its own documented Layer 1/Layer 2 limitation)
  - `specs/archive/411_refactor_verify_deploy_gate_framework/issues.jsonl` entry
    `iss_1792068891184_VXuGxJ` (origin)
  - `specs/414_enforce_verdict_extraction_contract/` (sibling lint-family task, sequencing
    dependency)
