# Research Report: Enforce State-Write Convention Over the Python Channel

**Task**: 419 - Extend the state-writer boundary lint to the Python/ad hoc JSON re-serialization channel
**Started**: 2026-11-05
**Completed**: 2026-11-05
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh`, `scripts/state-write.sh`, `scripts/tests/test-lint-state-writer-boundary.sh`, `context/patterns/task-lock.md`, `hooks/guard-destructive-git.sh`, `hooks/validate-no-task-references.sh`, `scripts/lib/task-reference-patterns.sh`, `scripts/verify-deploy.sh`, `scripts/gate-registry.data`, literature extension's three Python JSON writers, `specs/archive/411_refactor_verify_deploy_gate_framework/issues.jsonl`
- Live measurement: `grep -nE` pattern prototyping against the full source store, direct timing of the existing lint
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The originating incident (`iss_1792068891206_SuioJu`) was an **ad hoc, in-session** Python
  `json.dump` attempt against `specs/state.json` during implementation work -- it never landed as
  a tracked file under `agent-system/extensions/`. This is the decisive fact for the
  content-lint-vs-write-time-guard question below.
- The minimum required extension is small and safe: a single new candidate-pattern limb,
  `open\([^)]*state\.json`, plus one new `classify_line` branch that checks for a write-capable
  mode token (`w`, `a`, `r+`, `w+`, `a+`, `x`). This single mechanism covers both named shapes
  (`json.dump(obj, open(path, 'w'))` and the `with open(path,'w') as f:` idiom) without any
  cross-line logic, and generalizes to archive/vault-root targets for free (same `state\.json`
  substring test the jq channel already uses).
- **Measured**, not assumed: this addition introduces **zero new candidate matches** anywhere in
  the live source store today (verified by diffing grep results under the old and new patterns).
  No new `EXCLUDED_FILES` entries are needed. The three literature-extension Python JSON writers
  named in the dispatch do not match at all, confirmed directly.
- Decision on the required question: **a content lint alone is not sufficient.** The lint can only
  ever see code already committed to a `.md`/`.sh` file under the scanned tree; the actual incident
  was a live Bash-tool Python invocation that never took that form. A companion **write-time Bash
  PreToolUse hook**, mirroring `guard-destructive-git.sh`'s trigger surface (not
  `validate-no-task-references.sh`'s Write/Edit surface) and sharing one pattern library with the
  lint (mirroring `task-reference-patterns.sh`'s dual-consumer structure), is also warranted and
  recommended as part of this task's plan.
- Current gate 12 runtime is **4.8s measured** against a 30s timeout -- ample margin for the added
  pattern, which adds negligible regex-engine cost.

## Context & Scope

Task 419 extends `scripts/lint/lint-state-writer-boundary.sh` (registered as gate 12) to detect a
Python/interpreter re-serialization write to `specs/state.json` (or its archive/vault-root
counterparts), alongside the jq-shaped channel the lint already covers. The prose standard
(`context/patterns/task-lock.md`'s State-Write Convention section) already names this exact hazard;
this task closes the *mechanical* enforcement gap and adds a pointer from the prose to the gate.

Research scope: (1) design a minimal, correctly-scoped lint extension and verify it against the
live tree and the named control cases; (2) settle, with evidence, whether a content lint alone is
sufficient or a write-time guard is also warranted; (3) specify the test additions needed,
including a reproduction fixture for the actual corruption; (4) locate the exact `task-lock.md`
edit point; (5) confirm gate 12's timeout margin.

Explicitly out of scope (per dispatch): the three already-complete layers (state-write.sh itself,
the prose standard, the jq-channel lint/gate) are not re-implemented. The known-unrelated
pre-existing gate failures (gate 3, gate 20, three gate-8 suites) are not addressed here.

## Findings

### Codebase Patterns

**The existing lint's two-layer model, read closely.** `lint-state-writer-boundary.sh` is a
single deliberately-broad `CANDIDATE_PATTERN` (`grep -nE`) followed by a `classify_line()`
function that narrows each candidate line to `VIOLATION` or `EXEMPT: <reason>`, plus a short,
individually-reasoned `EXCLUDED_FILES` allowlist (Layer 2, whole-file). Every existing branch is
single-line: `/dev/null` redirect = read-only; `state.json >`/`*.tmp` = staged write; a bare `mv`
onto a `state.json` target is a violation only when its *source* looks like a staging path. The
file's own header states the limitation candidly: variable-indirected paths and writes assembled
across distant lines are invisible to any regex. This is the model to extend, not replace.

**The actual incident was never a file in the scanned tree.** `issues.jsonl` entry
`iss_1792068891206_SuioJu` (class `near-miss`, from task 411's implementation phase) records: "Attempted
to append one new entry to task 411's own file_scope in specs/state.json via Python's json.dump
(default ensure_ascii=True) ... Caught before any commit (diff inspected immediately) and reverted
from a pre-edit backup." This was a live, ad hoc Bash-tool Python invocation during implementation
work -- not a checked-in script under `agent-system/extensions/`. `lint-state-writer-boundary.sh`'s
default scan root is `agent-system/extensions`; even a perfect Python-channel extension scanning
that tree would not have seen this specific incident, because the risky code never existed as a
file there. It would, however, catch a *future* recurrence if that same shape were ever copy-pasted
into a tracked helper script -- exactly the role the existing jq-channel lint already plays for its
own channel.

**Zero live matches, confirmed by direct measurement, not assumption.** The proposed candidate
addition is:

```
open\([^)]*state\.json
```

Diffing `grep -lE` results under the old `CANDIDATE_PATTERN` and under this new limb alone across
every `.md`/`.sh` file in `agent-system/extensions` shows **zero files matching only the new
pattern** -- every file that matches the combined pattern already matched the old one (the current
17-file candidate set, each already classified EXEMPT or already in `EXCLUDED_FILES`). No new
allowlist entries are required for the live tree. This was checked by file content, not inferred:
`lean-challenge-snapshot.sh`'s `read_task_status()` opens a *variable* path (`state_path`, bound
via `sys.argv`) with no mode argument (defaults to read) -- no match, and correctly so (it is a
read, and even if it matched it would classify EXEMPT by the mode check). `test-lean-challenge-snapshot.sh`'s
`set_status()` test helper assigns a literal `'$repo/specs/state.json'` string on its own line
(shell-interpolated to a throwaway fixture repo under a test's own `$WORKDIR`) and then opens the
*variable* `path` on separate lines -- the literal and the `open()` call never share a line, so
this is the same documented cross-line limitation already accepted for the jq channel, and this
file is structurally identical in spirit to the existing isolated-temp-root exemptions already
reasoned about for `test-session-registry.sh`/`test-task-lock-liveness.sh` (never the real
`specs/state.json`). The three literature-extension Python JSON writers named in the dispatch
(`literature-search.sh`, `literature-repair-combining.sh`, `literature-combining-audit.sh`) write
to `manifest.json` and ad hoc result envelopes, never a `state.json`-named path; confirmed directly
by grep, they do not match the new pattern at all (no allowlist marker needed -- they are exempt
by content, exactly as the dispatch requires).

**Mode detection is the key narrowing step, and it must include `r+`.** The dispatch's inclusion of
`json.load` alongside `json.dump`/`json.dumps` in the "flag a ... write path" language is explained
by the classic in-place JSON rewrite idiom:

```python
with open(path, "r+") as f:
    data = json.load(f)
    f.seek(0)
    json.dump(data, f)
```

Here the *same* `open()` call (mode `r+`) backs both the read and the write; `json.load` is part of
the write path in this idiom even though it is nominally a read call. The mode check must therefore
treat `w`, `a`, `r+`, `w+`, `a+`, and `x` as write-capable, and must leave bare/no-mode and plain
`r`/`rb` as exempt (read-only).

**Verified, correct classification across every named shape** (prototyped and run against literal
fixture lines before writing this report):

| Line | Candidate match? | Verdict |
|---|---|---|
| `json.dump(obj, open('specs/state.json', 'w'))` | yes | VIOLATION |
| `with open('specs/state.json', 'w') as f:` | yes | VIOLATION |
| `with open("specs/archive/state.json", "a") as f:` | yes | VIOLATION |
| `with open(f"{vault_root}/state.json", 'r+') as f:` | yes | VIOLATION |
| `with open('specs/state.json') as f:` (no mode -> default read) | yes | EXEMPT (read-only) |
| `with open('specs/state.json', 'r') as f:` | yes | EXEMPT (read-only) |
| `with open(path) as f:` (indirected, cross-line) | no | not matched (documented limitation, unchanged) |
| `print(json.dumps(envelope, indent=2, ensure_ascii=False))` (literature) | no | not matched |
| `json.dump(manifest, f, ensure_ascii=False, indent=2, sort_keys=True)` (literature) | no | not matched |

The archive and vault-root targets fall out "for free": the check is keyed on the `state\.json`
substring exactly as the existing jq-channel check is, with no special-casing for the path prefix.

### External Resources

Not applicable -- this is a pure codebase-pattern extension; no external library or API research
was needed.

## Decisions

- **Extend, do not replace, the existing two-layer model.** The new Python shape is added as one
  more `CANDIDATE_PATTERN` alternative plus one new `classify_line()` branch, consistent with the
  dispatch's explicit instruction to work within the existing model rather than bolt on a third
  mechanism.
- **Key detection on `open(` + the `state\.json` substring on one line**, not on a bare
  `json\.dump\(`/`json\.dumps\(`/`json\.load\(` token. A bare-token approach would false-positive on
  every legitimate JSON writer in the tree (the literature scripts, the `state-write.sh` test
  fixtures that round-trip arbitrary scratch JSON, `lean-challenge-snapshot.sh`'s own manifest
  writer) and require a large new allowlist for files that have nothing to do with `state.json`.
  Keying on the same-line `state.json` literal, exactly as the jq channel already does, keeps the
  false-positive rate at the measured zero and needs no new allowlist entries.
- **Mode check must include `r+`/`w+`/`a+`/`x` alongside `w`/`a`**, to cover the in-place
  `json.load`-then-`seek(0)`-then-`json.dump` idiom explicitly named by the dispatch's inclusion of
  `json.load` in the "write path" language.
- **The write must be flagged regardless of `ensure_ascii`.** The recommended check is mode-based
  (write-capable open on a `state.json` target), not escaping-based, so it fires identically whether
  or not `ensure_ascii=False` is present -- satisfying the dispatch's explicit requirement that
  fixing only the escaping half would leave the unsynchronized-read-modify-write half of the hazard
  untouched.
- **A content lint alone is not sufficient; a write-time guard is also warranted.** The originating
  incident was an ad hoc, uncommitted Python invocation that never existed as a scannable file. A
  content lint over the source store can only stop a *future copy-paste recurrence into a tracked
  file* -- it provably cannot have stopped, and cannot stop a repeat of, the actual incident shape.
  Recommendation: add a new PreToolUse **Bash** hook (not a Write/Edit hook) that inspects
  `tool_input.command` for the same write-capable-`open()`-on-`state.json` shape before the command
  runs, exactly mirroring `guard-destructive-git.sh`'s trigger surface and blocking convention (exit
  2 + stderr, never `permissionDecision: deny`, which is documented-buggy for allow-listed Bash
  calls). The dispatch names `validate-no-task-references.sh` as the structural precedent for
  "a blocking write-time gate paired with a repo-wide lint over one shared pattern library" --
  that pairing *structure* is right (extract the shared regex/mode-check logic into one new library,
  e.g. `scripts/lib/state-writer-boundary-patterns-lib.sh`, consumed by both the lint and the new
  hook, mirroring `task-reference-patterns.sh`'s dual-consumer role for
  `check-task-references.sh`/`validate-no-task-references.sh`) -- but the hook's own *trigger
  surface* should be `Bash` (matching where this specific hazard actually manifests: a live
  interpreter invocation), not `Write|Edit` (which `validate-no-task-references.sh` uses because
  *its* hazard is authored file content). Register the new hook alongside
  `guard-destructive-git.sh`/`validate-task-creation-audit.sh` in the existing `"matcher": "Bash"`
  array of `agent-system/extensions/core/merge-sources/settings-hooks.json`.
- **Recommended plan phasing**: Phase 1 -- lint extension, pattern-library extraction, and the full
  test suite described below (this closes the dispatch's REQUIRED DIRECTION outright and is
  sufficient to ship on its own if the plan phase judges the hook out of scope for this task).
  Phase 2 -- the write-time Bash hook built on the same shared library, plus its own hook test and
  settings registration. Both phases are recommended within this task given the whole-file blast
  radius already measured once; the plan phase should make the final call on whether Phase 2 is
  folded into this task or spun out, but should not silently drop it without the user or a future
  task picking it up, since the lint alone is evidenced-insufficient against the incident that
  raised this task.
- **Remedy message**: extend the lint's existing bottom-of-run `Fix:` block (currently two lines,
  fires for any violation count) to explicitly name `--arg`/`--argjson` passthrough, rather than
  adding a second, shape-specific message -- the existing message already fires uniformly across
  both channels, so one shared addition satisfies the "point the author at the sanctioned call"
  requirement for both shapes with no branching logic:
  ```
  echo "Fix: route the write through scripts/state-write.sh (see its header for the contract)."
  echo "      Pass data in via --arg/--argjson rather than hand-building JSON in Python or jq;"
  echo "      the acquire -> stage -> transform -> validate -> mv -> release sequence is the"
  echo "      only sanctioned write path, regardless of ensure_ascii or escaping choices."
  echo "Edit the source store under agent-system/extensions/ -- .claude/ is a generated artifact."
  ```
- **`task-lock.md` pointer edit, confined to the State-Write Convention section**: add one sentence
  immediately after the existing sentence that names the three forbidden write shapes (around the
  "not a direct `acquire_scope_mutex` call from a new script" sentence, `context/patterns/task-lock.md`
  lines ~802-808), naming `lint-state-writer-boundary.sh` and gate 12 as the mechanical enforcer of
  both the jq- and Python-shaped forms of this rule. No other section of the file should be touched.

## Recommendations

1. **Lint code change** (`agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh`):
   - Append `|open\([^)]*state\.json` to `CANDIDATE_PATTERN`.
   - In `classify_line()`, add a new branch before the final catch-all, using a named mode-pattern
     variable to avoid bracket-escaping pitfalls inline (validated form):
     ```bash
     # Python interpreter re-serialization channel: a write-capable open() call whose path
     # literal contains "state.json" (live, archive, or vault-root alike -- same substring test
     # the jq channel already uses). Catches json.dump(obj, open(path, 'w')) and the
     # with open(path, 'w') as f: idiom's own open() line; the with-idiom's SECOND line
     # (json.dump(obj, f)) carries neither token and is left to the documented cross-line
     # limitation above, exactly as a variable-indirected jq filter already is.
     if [[ "$text" =~ open\([^\)]*state\.json ]]; then
         local py_mode_write_re="['\"](w|a|r\+|w\+|a\+|x)['\"]"
         if [[ "$text" =~ $py_mode_write_re ]]; then
             printf 'VIOLATION\n'
             return 0
         fi
         printf 'EXEMPT: Python open() on a state.json target has no write-capable mode (read-only)\n'
         return 0
     fi
     ```
   - Extend the bottom `Fix:` echo block as shown in Decisions above.
   - No `EXCLUDED_FILES` additions are needed for the live tree (measured: zero new matches).

2. **Test additions** (`agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh`):
   add cases covering, at minimum:
   - `json.dump(obj, open('specs/state.json', 'w'))` -> flagged.
   - `json.dump(obj, open('specs/state.json', 'w', encoding='utf-8'))` with `ensure_ascii=False`
     elsewhere on the same or a describable line -> still flagged (proves the ensure_ascii
     requirement).
   - The `with open(path, 'w') as f:` / `json.dump(obj, f)` two-line idiom -> the first line
     flagged.
   - `with open('specs/archive/state.json', 'a') as f:` and
     `with open(f"{vault_root}/state.json", 'r+') as f:` -> both flagged (archive and vault-root
     coverage).
   - A correct `state-write.sh '...' --session-id "$SESSION_ID"` call -> NOT flagged (already
     covered by the existing Case 2, no change needed).
   - Each of the three literature scripts, run directly against their real paths (not a synthetic
     copy) -> NOT flagged, satisfying "each literature-extension Python JSON writer is NOT flagged"
     against the real files rather than by construction alone.
   - A new **Case 7 reproduction fixture**, distinct in kind from the shape-matching cases above
     (it demonstrates the hazard is real, not merely that the regex matches): build a scratch JSON
     state file with 3+ synthetic project entries, at least two carrying non-ASCII content (e.g. an
     em dash or arrow) in fields *other* than the one being modified; run a `python3` one-liner that
     `json.load`s it, appends one trivial entry to one project's `file_scope`, and `json.dump`s it
     back with default `ensure_ascii`; assert the resulting diff touches the untouched projects'
     non-ASCII fields (now `\uXXXX`-escaped) in addition to the one intentionally-changed entry --
     i.e. assert the diff is NOT scoped to one project's one field. This is what makes the remedy
     message's "whole-file diff" claim evidenced.

3. **New shared pattern library and write-time hook** (recommended, Phase 2):
   - Extract the `open\([^)]*state\.json` candidate test and the write-mode check into a small
     shared library (e.g. `agent-system/extensions/core/scripts/lib/state-writer-boundary-patterns-lib.sh`),
     sourced by both the lint and the new hook, mirroring `task-reference-patterns.sh`'s role.
   - New hook `agent-system/extensions/core/hooks/validate-no-python-state-write.sh`: `PreToolUse`,
     matcher `Bash`, reading `INPUT=$(cat)`, `COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')`
     (same idiom as `guard-destructive-git.sh`), applying the shared library's check against
     `$COMMAND`, blocking via `exit 2` + stderr naming `state-write.sh` on a match, failing OPEN
     (exit 0) if the shared library cannot be sourced.
   - Register it in `agent-system/extensions/core/merge-sources/settings-hooks.json`'s existing
     `"matcher": "Bash"` hooks array, alongside `guard-destructive-git.sh` and
     `validate-task-creation-audit.sh`.
   - New hook test mirroring `test-validate-no-task-references.sh`'s structure (both-polarity:
     a synthetic `python3 -c "..."` command string containing the violation shape is blocked;
     an equivalent `state-write.sh` invocation is allowed).

4. **`task-lock.md` edit**: one sentence inserted within the existing State-Write Convention
   paragraph (lines ~802-808), naming `lint-state-writer-boundary.sh` and gate 12 as the mechanical
   enforcer of the convention stated in that paragraph. No other section touched.

5. **Verification invocation for the final phase**: `verify-deploy.sh`'s `TARGET` must simultaneously
   hold a deployed `.claude/` tree AND `agent-system/extensions` for gate 12 (and the other
   source-store-only gates) to run rather than `[SKIP]`; a bare, no-argument invocation defaults
   `TARGET` to `$(pwd)` and silently skips those gates if run from the wrong directory. Use an
   explicit TARGET naming the repo root, with no `--only-gate` filter (full battery):
   ```
   bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim
   ```
   This repo root already satisfies both conditions (it holds both the deployed `.claude/` and the
   `agent-system/extensions` source store), so this single invocation is sufficient; no
   `--minimal-init` or alternate TARGET is needed.

## Risks & Mitigations

- **Risk**: a future legitimate Python reader of `state.json` (e.g. a debugging helper opening it
  read-only) could be miscoded with an accidental write-capable mode and get flagged. **Mitigation**:
  this is the *intended* behavior -- any write-capable `open()` on a `state.json` target outside
  `state-write.sh` is exactly the hazard this lint exists to catch; the fix is to route the write
  through `state-write.sh`, not to weaken the check.
- **Risk**: the mode-check regex could, in principle, false-positive on a quoted string that
  happens to contain a bare `'w'`/`'a'` token elsewhere on a long line unrelated to the `open()`
  call's actual mode argument (e.g. a comment or an unrelated string literal sharing the line).
  **Mitigation**: measured against the full live tree, this does not occur today (zero new
  matches); if it ever does, the existing `EXCLUDED_FILES` allowlist mechanism (Layer 2,
  individually-reasoned) is the sanctioned escape hatch, exactly as used for the jq channel's own
  edge cases.
- **Risk**: scope creep from the write-time hook recommendation turning a "lint extension" task into
  a larger hook-plus-library task. **Mitigation**: the lint extension alone (Recommendations 1-2)
  fully satisfies the dispatch's REQUIRED DIRECTION and can ship independently; Recommendation 3 is
  presented as a separately phased, evidence-justified addition, not a blocking dependency of
  Recommendations 1-2.
- **Risk**: the always-"allow" `matcher: Write` / `state.json`-named stub already present in
  `agent-system/extensions/core/root-files/settings.json` (not sourced from
  `merge-sources/settings-hooks.json`, and not found anywhere else in the extension tree) might be
  mistaken for existing coverage of this hazard. **Mitigation**: noted here for awareness only --
  it unconditionally returns `permissionDecision: allow` regardless of match, so it currently
  enforces nothing and is unrelated to either this task's Python channel or the recommended Bash
  hook; it is out of scope to diagnose or fix here.

## Context Extension Recommendations

- **Topic**: write-time hook trigger-surface selection (Bash-command-string hooks vs.
  Write/Edit-payload hooks) as a reusable *decision pattern*, not just a one-off choice for this
  task.
- **Gap**: `context/patterns/` has no file documenting that a hazard's trigger surface (where the
  risky action actually executes -- a Bash tool call vs. an authored file) determines which of the
  two existing hook archetypes (`guard-destructive-git.sh`'s Bash-command-string inspection vs.
  `validate-no-task-references.sh`'s Write/Edit-payload-with-Edit-reconstruction inspection) is the
  correct model to copy. This task needed to work that reasoning out from scratch by reading both
  hooks' headers and the originating incident log.
- **Recommendation**: a short new file, e.g.
  `context/patterns/hook-trigger-surface-selection.md`, stating the rule (match the hook's
  `PreToolUse` matcher to where the hazard's bytes actually originate: a live interpreter
  invocation -> `Bash`; authored file content -> `Write|Edit` with the Edit-reconstruction
  caveat) with these two hooks as the worked examples, would save a future task the same
  from-scratch derivation.

## Appendix

- Search/verification commands used (all read-only; no live file was modified):
  - `grep -n "State-Write Convention" -A 30 agent-system/extensions/core/context/patterns/task-lock.md`
  - `grep -n "gate12_run" -A 15 agent-system/extensions/core/scripts/verify-deploy.sh`
  - `time bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh --quiet`
    (measured 4.826s real against a 30s gate timeout)
  - `grep -rnE "open\([^)]*state\.json" agent-system/extensions --include="*.sh" --include="*.md" --include="*.py"`
    (zero matches in the live tree today)
  - `comm -13` diff between `grep -lE` under the old `CANDIDATE_PATTERN` and under the new
    `open\([^)]*state\.json` limb alone across every `.md`/`.sh` file under `agent-system/extensions`
    (zero files matching only the new limb)
  - Prototype classification script run against 10 literal fixture lines spanning both the
    required shapes and the literature-extension control cases (table reproduced under Findings)
  - `grep "SuioJu" specs/archive/411_refactor_verify_deploy_gate_framework/issues.jsonl` (full text
    of the originating near-miss entry)
- Key files read in full or in relevant part: `lint-state-writer-boundary.sh`,
  `test-lint-state-writer-boundary.sh`, `state-write.sh` (header), `task-lock.md` (State-Write
  Convention section, lines ~800-830), `guard-destructive-git.sh` (header),
  `validate-no-task-references.sh` (header), `gate-registry.data` (gate 12 row), `verify-deploy.sh`
  (gate12_run, TARGET contract comments), `merge-sources/settings-hooks.json` (PreToolUse Bash
  matcher array), `literature-search.sh`/`literature-repair-combining.sh`/`literature-combining-audit.sh`
  (their json.dump/dumps call sites), `lean-challenge-snapshot.sh` (`read_task_status`, manifest
  write), `test-lean-challenge-snapshot.sh` (`make_repo`/`set_status` fixture helpers).
