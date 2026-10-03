# Research Report: Task #326

**Task**: 326 - Add an advisory `--gate` verification tier at implement dispatch
**Started**: 2026-10-03
**Completed**: 2026-10-03
**Effort**: medium (one implement dispatch, ~6 phases)
**Dependencies**: None blocking. Sibling-in-flight: the books domain context corpus task
(owns `agent-system/extensions/books/context/project/books/**`) and the extension lifecycle
hook mechanism repair task (deliberately NOT a dependency).
**Sources/Inputs**:
- Codebase (source store): `agent-system/extensions/core/`, `agent-system/extensions/books/`,
  `agent-system/extensions/lean/`
- Codebase (consuming repository, live and reachable at `~/Projects/Logos/Verification`):
  `interface/scripts/layer-lint.sh`, `interface/scripts/layer-rules.sh`,
  `books/lean/lakefile.toml`, `books/lean/BookCert/Depends.lean`, `components/*/check.sh`
- Executed probes: four live `layer-lint.sh` invocations, one vacuity-detection prototype,
  one `Books.Meta` import-closure prototype (all timed)
**Artifacts**: - `specs/326_books_verification_tier_at_implement_dispatch/reports/01_gate-flag-verification-tier.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The consuming repository is reachable and everything was measured, not inferred.**
  `interface/scripts/layer-lint.sh` exists at `~/Projects/Logos/Verification/interface/scripts/layer-lint.sh`
  (72 lines, plus `layer-rules.sh` at 215 lines). It was executed four times during this
  research. The cheap-tier claim is confirmed empirically: **1.06 s** over 131 modules /
  564 imports for `interface components/framed_channel`, versus the ten-minute fail-closed
  `full-gate.sh`. The `Books.Meta` closure prototype runs in **0.53 s**. Combined gate cost is
  ~1.6 s.
- **The `--compare` threading surface has moved and was re-measured.** Every line number in the
  task description is stale. Corrected: `orchestrate-cycle-plan.sh` declaration **360** (not 348),
  parse **379** (not 367), forwarding **2342** (not 2771); `orchestrate-build-dispatch.sh`
  contract comment **33-34** (unchanged), declaration **134** (unchanged), parse **151**
  (unchanged), emission **427-428** (unchanged); `commands/orchestrate.md` flag row **46**
  (unchanged). Two sites the description omits were also found: `parse-command-args.sh` needs
  **three** edits (doc-comment block ~line 23, initializer line 91, detector line 136) **plus a
  fourth** — the `FOCUS_PROMPT` strip chain at line 169 — and the `export` list at line 183.
- **The gate binds in the books extension, not the lean one.** `books` task_type routes to
  `books-implementation-agent` / `skill-books-implementation` (books `manifest.json`
  `routing_agents`), never to `skill-lean-implementation`. `skill-lean-implementation`'s
  Stage 6b/6c is the *pattern* to copy, not the file to edit. The books agent already has a
  **Stage 5: Final Verification** (`books-implementation-agent.md:149`) — the exact structural
  twin of the lean agent's Final Verification Stage step 6, and the correct insertion point.
- **A new extension-local wrapper script is mechanically required, not a design preference.**
  `check-extension-docs.sh` **Rule E** (`check_referenced_scripts_declared`, lines 1062-1156)
  hard-fails on any bare `<name>.sh` token appearing in an extension's `commands/*.md`,
  `skills/*/SKILL.md`, `agents/*.md`, `README.md` or `EXTENSION.md` that is not declared in some
  extension's `provides.scripts`/`provides.hooks`. `layer-lint.sh` belongs to the consuming
  repository and can never be declared. `books-certify.sh` is the already-shipped precedent for
  exactly this constraint (its own header says so). So `--gate` needs
  `agent-system/extensions/books/scripts/books-gate.sh` — a resolve-and-run wrapper, declared in
  `provides.scripts`.
- **Three measured hazards in `layer-lint.sh` that a naive wrapper would get wrong**, all
  confirmed by execution: (1) a **vacuous pass is indistinguishable from a real pass** by exit
  code — `bash layer-lint.sh books` returns `[ok] ... (62 modules, 119 imports, ...)` exit 0
  while **0 of 9** rules' file-halves match anything under `books/`; (2) `layer-rules.sh`
  **`exit 1`s during sourcing** when no `BoundedQueueLaws` queue model is found under
  `components/framed_channel/lean/FramedChannel/Model` — so an `exit 1` is *not* necessarily a
  violation; (3) `exit 2` is a usage error (no args, or a named package root absent), distinct
  from both.
- **The `Books.Meta` invariant is simpler and stronger than the task description's gloss, and
  its live baseline is clean.** The description says "only book modules and the certifier import
  it publicly". Measured: **zero** live modules import it publicly — *including book modules*.
  `books/lean/BookCert/Depends.lean:23` states the real rule ("the provider is a private import
  of every code module and a member of no book") and both `Depends.lean:110` and
  `Certify.lean:531` skip it in the computed `depends`. Baseline: **0 violations across 214
  private import sites**, with the only two `public import Books.Meta` occurrences in the tree
  confined to `specs/archive/.../prototype/` — which the check **must** prune along with `.lake/`.

## Context & Scope

Researched: how to add an advisory-only `--gate` flag to `/orchestrate` that, at implement
dispatch only, runs the consuming repository's regex layer lint plus a `Books.Meta`
import-closure check, mirroring the existing `--compare` flag exactly and never blocking,
failing, or downgrading status.

In scope: the complete `--compare` threading surface (re-measured); the binding site in the books
extension's agent and skill; the real CLI/exit/output contract of
`interface/scripts/layer-lint.sh`; a mechanically defensible formulation of the `Books.Meta`
import-closure check; the extension-packaging constraints (`check-extension-docs.sh` Rules E and
Q, Rule U's 60-line `EXTENSION.md` ceiling, `run-all.sh` test discovery).

Out of scope, per the dispatch: re-deriving the mechanism decision (the `skill-base.sh`
`verification` lifecycle hook was investigated and rejected; three stacked defects, each
independently fatal). This research did **not** re-verify those three defects — it took the
dispatch's evidence as given, as instructed.

Territory respected: the sibling books-corpus task owns
`agent-system/extensions/books/context/project/books/**`. Nothing in this research proposes
writing there. Books-awareness reaches `--gate` through plain backticked pointers to that corpus
(`context/project/books/domain/gate-tiers.md`, `tools/certify-guide.md`), which is exactly the
contract the existing `books/context/project/books/README.md` navigation stub already sets up: a
missing file at one of those paths is expected, not a defect.

## Findings

### Codebase Patterns

#### The `--compare` threading surface, re-measured (every line number below is current)

| File | Site | Current line | Change needed for `--gate` |
|------|------|--------------|----------------------------|
| `core/scripts/parse-command-args.sh` | header doc-comment for `COMPARE_FLAG` | 22-25 | add a `GATE_FLAG` paragraph |
| " | initializer `COMPARE_FLAG="false"` | 91 | add `GATE_FLAG="false"` |
| " | detector `[[ "$remaining" =~ --compare ]]` | 135-137 | add a `--gate` detector |
| " | `FOCUS_PROMPT` strip chain `sed 's/--compare//g'` | 169 | **add `sed 's/--gate//g'`** (omitted from the task description; without it `--gate` leaks into focus text) |
| " | `export` list | 183 | add `GATE_FLAG` |
| `core/scripts/orchestrate-cycle-plan.sh` | header contract paragraph | 165-167 | add the parallel paragraph |
| " | usage heredoc | 335 | add `[--gate]` |
| " | declaration `compare_flag="false"` | **360** (desc. said 348) | add `gate_flag="false"` |
| " | parse `--compare) compare_flag="true"` | **379** (desc. said 367) | add `--gate)` arm |
| " | forwarding into `build_args` | **2342** (desc. said 2771) | add the implement-scoped guard line |
| `core/scripts/orchestrate-build-dispatch.sh` | usage comment | 22-23 | add `[--gate]` |
| " | contract comment for `--compare` | 33-36 | add the parallel block |
| " | usage heredoc | 106-107 | add `[--gate]` |
| " | declaration | 134 | add `gate_flag="false"` |
| " | parse arm | 151 | add `--gate)` arm |
| " | Identity-section emission | 427-429 | add `- gate_flag: true` |
| `core/commands/orchestrate.md` | Options table `--compare` row | **46** | add a `--gate` row |
| " | `--hard` composability row | 52 | add `--gate` to the composable list |
| `core/skills/skill-orchestrate/SKILL.md` | Setup field list | 32 | add `gate_flag` |
| " | Move 1 `$( ... && echo --compare )` | 82 | add the parallel line |
| `core/context/formats/return-metadata-file.md` | `### comparator (optional)` | 269-311 | add a sibling `### gate (optional)` section |
| `core/scripts/tests/test-orchestrate-build-dispatch.sh` | Group 9 (`--compare`) | 427-471 | add **Group 17** (next free) |
| `core/scripts/tests/test-orchestrate-cycle-plan.sh` | Group 12 (`--compare` forwarding) | 1982-2070 | add **Group 35** (next free) |

The implement-scoping guard is the whole mechanism that keeps the flag off research/plan
dispatches, and it is one line at `orchestrate-cycle-plan.sh:2342`:

```bash
[ "$compare_flag" = "true" ] && [ "$g" = "implement" ] && build_args+=(--compare)
```

`build_args` is composed at **exactly one** site (verified: the only occurrences are 2339-2397),
so there is no second forwarding path to keep in sync. `orchestrate-build-dispatch.sh` is itself
phase-agnostic — it records whatever it is told — and Group 9 of its suite asserts that
deliberately (line 468). The implement-only scoping is tested in the *cycle-plan* suite instead.

**Byte-identity invariant.** `orchestrate-build-dispatch.sh`'s emission is conditional precisely
so a no-flag dispatch file is byte-identical to one built before the flag existed. Group 9
asserts "differs from the no-flag dispatch file by exactly one added line" (line 450). `--gate`
must preserve this: one conditional line, nothing else.

#### The binding site: books, not lean

`agent-system/extensions/books/manifest.json` routes `books` and `books:certify` to
`books-implementation-agent` (base) and `books-implementation-hard-agent` (hard), via
`skill-books-implementation` / `skill-books-implementation-hard`. The `lean` extension is a
*dependency* of books, not the route.

The structural twin of the lean precedent:

| Lean precedent | Books counterpart |
|----------------|-------------------|
| `lean-implementation-agent.md:368-495` — Final Verification Stage step 6, "Comparator gate (advisory, opt-in — read `compare_flag` from the delegation context)" | `books-implementation-agent.md:149-152` — **Stage 5: Final Verification** (currently `lake build`, `books-tool validate`/`check`, the certify driver) |
| `skill-lean-implementation/SKILL.md:98-104` — `compare_flag` in the delegation-context JSON, "forwarded unchanged and defaults to `false` when absent" | `skill-books-implementation/SKILL.md:53-56` — Stage 4 "Prepare Delegation Context" |
| `skill-lean-implementation/SKILL.md:134` — the bullet in "The subagent will:" | same skill's Stage 5 bullet list |
| `skill-lean-implementation/SKILL.md:216-240` — **Stage 6c: Comparator Verdict Surface (Read from Metadata)** | a new stage between `skill-books-implementation/SKILL.md`'s Stage 6 (Parse Subagent Return) and Stage 7 |
| `lean-implementation-hard-agent.md:446-555` and `skill-lean-implementation-hard/SKILL.md:194,219,259` | `books-implementation-hard-agent.md` and `skill-books-implementation-hard/SKILL.md` |

Stage 6c is the exact template, including its closing asymmetry note — which exists to stop a
later editor folding the advisory branch into the status-downgrading one:

```
**Asymmetry note (deliberate, not an omission)**: unlike Stage 6b's `compliance_check == "failed"`
branch above, which sets `status="partial"`, this stage MUST NOT assign `status` on any
`comparator` verdict, however severe.
```

And the absent-block INFO path (`SKILL.md:229`), which the dispatch names as the precedent for a
missing gate block:

```bash
if [ "$comparator_ran" = "false" ] && [ -z "$comparator_verdict" ]; then
    echo "Stage 6c: INFO — no comparator block recorded (--compare not requested, or agent preflight stopped before invocation); proceeding"
```

**Postflight boundary.** `skill-books-implementation/SKILL.md:97-118` ("MUST NOT (Postflight
Boundary)") forbids the skill from running `lake build`/`books-tool` or grepping source after the
agent returns, per `postflight-tool-restrictions.md`. The gate therefore **must** run in the
agent and be *read* from metadata by the skill — identical to Stage 6b/6c. There is no choice
here, and it happens to be the right design anyway.

#### `interface/scripts/layer-lint.sh` — the measured contract

Invocation: `bash interface/scripts/layer-lint.sh PACKAGE_ROOT...`, at least one root required.
Each `PACKAGE_ROOT` is a directory **relative to the repository root**; `ROOT` is derived
internally as `$(dirname $BASH_SOURCE)/../..`, so the script is cwd-independent but
repository-anchored. No Lean toolchain, no network, no build (`layer-lint.sh:20`).

Exit codes (all four executed live):

| Exit | Meaning | Evidence |
|------|---------|----------|
| 0 | no violations; final line is `[ok] layer import rule (N modules, I imports, 7 exclusion rules, 2 allow-only rules; queue models derived: ...; package roots: ...)` | `interface components/framed_channel` → `[ok] ... (131 modules, 564 imports, ...)`, 1.06 s |
| 1 | one or more violations: `[FAIL] <detail>` lines, then `layer-lint.sh: N layer import violation(s)` | documented at `layer-lint.sh:21,60,68` |
| 1 | **OR** rule-set bootstrap failure — `layer-rules.sh` `exit 1`s *while being sourced* with `layer-rules.sh: no queue model found under components/framed_channel/lean/FramedChannel/Model ...` on **stderr** | `layer-rules.sh:48-51`; `.`-sourcing means that `exit` terminates `layer-lint.sh` itself |
| 2 | usage error — no arguments, or a named root does not exist | `nosuchdir` → `layer-lint.sh: no such package root: nosuchdir`, exit 2; no args → usage, exit 2 |

Known callers and their root sets (so the wrapper does not invent a convention):
`components/rle_codec/check.sh:125` → `interface components/rle_codec`;
`components/distsys/check.sh:195` → `interface components/distsys`;
`components/framed_channel/check.sh` → `interface components/framed_channel`
(`layer-lint.sh:10-12`). Live `components/` roots: `distsys`, `fault_tolerance`,
`framed_channel`, `rle_codec`.

#### The vacuous-pass problem, demonstrated

```
$ bash interface/scripts/layer-lint.sh books
[ok] layer import rule (62 modules, 119 imports, 7 exclusion rules, 2 allow-only rules; ...)
exit=0

$ bash interface/scripts/layer-lint.sh components/distsys
[ok] layer import rule (45 modules, 160 imports, 7 exclusion rules, 2 allow-only rules; ...)
exit=0
```

Both are **vacuous**. Every rule's file-half in `LAYER_RULES`/`LAYER_ALLOW_RULES`
(`layer-rules.sh:95-117`) names `^interface/lean/Interface/Spec/`,
`^components/framed_channel/...` or `^components/framed_channel/(lean|aeneas)/`. Nothing names
`books/`, `components/distsys/`, `components/rle_codec/` or `components/fault_tolerance/`. The
`[ok]` line reports module and import counts but never *rule applicability*, so neither the exit
code nor the output distinguishes "checked and clean" from "nothing was checked".

A working vacuity detector was prototyped against the real rule set (no copy of the rules), and
it is cheap:

```bash
ROOT="$(pwd)"
. interface/scripts/layer-rules.sh            # must be a SUBSHELL: can exit 1
files=$(cd "$ROOT" && find <roots> -name '*.lean' -not -path '*/.lake/*' | LC_ALL=C sort)
matched=0
for r in "${LAYER_RULES[@]}" "${LAYER_ALLOW_RULES[@]}"; do
  fh="${r%%;*}"                               # field 1 of the ';'-delimited rule = the file half
  printf '%s\n' "$files" | grep -qE "$fh" && matched=$((matched+1))
done
```

Measured: `books` → `rules_matched=0 of 9`; `interface components/framed_channel` →
`rules_matched=9 of 9`. This reuses `layer-rules.sh` as the record of truth, in the same spirit
as `interface/tests/layer/run.sh`, which extracts the `# >>> layer-rules` / `# <<< layer-rules`
block verbatim so the self-test can never drift from the rules the gates apply
(`layer-rules.sh:14-19`).

#### The `Books.Meta` import-closure check — real invariant, measured baseline

The provider: `books/lean/` package `books`, library root `Books`, single module `Books.Meta`.
Its `lakefile.toml` states the closure rule in its own header: *"There is deliberately NO
`require` here: the module builds against core Lean alone (it is a `module` file with
`public meta import Lean`)."* That is precisely why a `public import Books.Meta` is harmful —
it would propagate `Lean` into every consumer's public import closure.

`books/lean/BookCert/Depends.lean:23` gives the normative shape: *"`Books.Meta` — the provider is
a private import of every code module and a member of no book"*. Both the library
(`Depends.lean:110`) and the certifier (`Certify.lean:531`) skip it when computing `depends`:
`if imp.module == \`Books.Meta then continue`.

Measured baseline over the live tree (pruning `.lake/` and `specs/`), 0.53 s:

| Predicate | Measurement |
|-----------|-------------|
| `public import Books.Meta` (incl. `public meta import`) anywhere live | **0** |
| plain/private `import Books.Meta` sites | **214** files (221 raw matches before pruning) |
| `require` lines in `books/lean/lakefile.toml` | **0** |

The only two `public import Books.Meta` occurrences in the whole tree are
`specs/archive/.../prototype/Comp/Book.lean:2` and
`specs/archive/.../prototype/Books/Compose.lean:4`. **Pruning `specs/` is mandatory** or the gate
reports two false violations on its first run.

Spot-checked that a real book module uses the private form:
`interface/lean/Interface/Book/Codec.lean:3` is `import Books.Meta` (line 4 is
`public import Interface.Spec.Codec` — so the file does use `public import`, just not for the
provider). This refutes the "book modules import it publicly" reading and confirms the stronger,
simpler invariant.

So the check is two cheap predicates, both greppable with no build:

1. **No live `.lean` file carries `public import Books.Meta`** (or `public meta import
   Books.Meta`), pruning `.lake/` and `specs/`.
2. **The provider package declares no `require`** — `books/lean/lakefile.toml` has no
   `[[require]]` table and no `require` line.

#### Extension-packaging constraints that shape the implementation

- **Rule E** (`check-extension-docs.sh:1062-1156`) extracts every `[A-Za-z0-9_-]+\.(sh|sql)\b`
  token from each extension's `commands/*.md`, `skills/*/SKILL.md`, `agents/*.md`, `README.md`
  and `EXTENSION.md` (URLs stripped first) and fails on any name not declared in core's
  `provides.scripts`/`provides.hooks`, **any** extension's `provides.scripts`, or the
  extension's own `provides.hooks` — matching on exact string *or* basename. `scripts/**` and
  `context/**` are **not** scanned. Consequence: `layer-lint.sh` must never be named in those
  five doc locations; it may be named freely in a wrapper's header comment and in the books
  context corpus.
- **`books-certify.sh` is the shipped precedent for exactly this**, and says so in its own header
  (lines 5-19): *"This script is the ONE extension-local script declared in provides.scripts
  specifically to satisfy that constraint"*. Its shape: resolve `git rev-parse --show-toplevel`
  with a `pwd` fallback; locate the real driver; **exit 3** when the driver is absent, with an
  actionable three-line message; `exec` with verbatim argument forwarding.
- **Rule Q** (`check-extension-docs.sh:534-585`) fails on any file on disk under `scripts/` not
  named in `provides.scripts`, matched by **full relative path** (so `tests/test-books-gate.sh`,
  not a basename).
- **Rule U**: `EXTENSION.md` ≤ 60 lines. `books/EXTENSION.md` is at **52** — eight lines of
  headroom.
- **Test discovery is glob-based, no registry.** `run-all.sh` discovers
  `agent-system/extensions/*/scripts/tests/test-*.sh` (lines 12-13) and is the engine behind
  `verify-deploy.sh`'s Gate 8. Zero discovered suites is a loud harness failure, never a silent
  pass (line 30).
- `--compare` is **not** documented in `docs/architecture/orchestrate-state-machine.md` and
  **not** in `commands/orchestrate.md`'s `argument-hint`. Mirroring exactly means `--gate` needs
  neither.
- The in-session plan cache (`orchestrate-cycle-plan.sh:596-620,701-718`) is keyed on
  `dispatch_seq_counter` only, not on flags. A replay re-uses a composition whose dispatch file
  was already written with the flag baked in, so no cache-key change is needed — and this is the
  pre-existing `--compare` behaviour, unchanged.

### External Resources

None required. Every fact in this report came from the local source store or the local consuming
repository. No web search was performed, and none was needed: the normative contracts are all
on disk and all executable.

## Decisions

1. **`--gate` binds in the books extension's agent and skill, not the lean ones.** The lean
   Stage 6b/6c pair is the pattern; `books-implementation-agent.md` Stage 5 and
   `skill-books-implementation/SKILL.md` (new stage after Stage 6) are the edit targets, plus
   their `-hard` twins. Grounds: `books/manifest.json` routing; no books task ever reaches
   `skill-lean-implementation`.
2. **A new extension-local wrapper, `agent-system/extensions/books/scripts/books-gate.sh`, is
   required** and declared in books' `provides.scripts`, with a narrow fixture suite at
   `scripts/tests/test-books-gate.sh` also declared (Rule Q). Grounds: Rule E cannot be
   satisfied for `layer-lint.sh`, which the consuming repository owns. Modelled on
   `books-certify.sh`.
3. **The wrapper emits a single JSON object on stdout (`--json`) and always exits 0** in its
   advisory role. Grounds: the advisory-only constraint. Every finding travels as JSON fields for
   the agent to copy into `.return-meta.json`, exactly as `lean-comparator-run.sh --json` feeds
   the `comparator` block. A non-zero exit would invite a caller to treat it as a failure.
4. **The gate classifies four distinct outcomes, not two.** `layer-lint.sh` exit 1 is ambiguous,
   so the wrapper must disambiguate: `pass`, `pass_vacuous`, `violations`,
   `lint_unavailable` (script absent — the common case in any repository without the books
   tooling), and `rule_set_error` (the `layer-rules.sh` bootstrap `exit 1`, detected by matching
   `no queue model found` on stderr) / `usage_error` (exit 2). Grounds: measured exit-code
   behaviour above.
5. **A vacuous pass is reported as vacuous, never as a pass**, with `rules_matched` and
   `rules_total` carried in the JSON. Grounds: the demonstrated 0-of-9 result for `books` and
   `components/distsys`; the books-corpus task's own known-gap register already makes this a
   stated requirement.
6. **The import-closure check is the two predicates named above** (no live `public import
   Books.Meta`; no `require` in the provider lakefile), with `.lake/` **and `specs/`** pruned.
   Grounds: the measured 0/214/0 baseline and the two archived false positives.
7. **Package roots are derived, never hardcoded.** Default to `interface` plus every
   `components/*` directory containing a `lean/` subdirectory, intersected with the task's own
   touched `.lean` paths when the agent can determine them; always record the roots actually
   linted in the JSON. Grounds: the three known caller root-sets all follow
   `interface <component>`; hardcoding `framed_channel` would type a component name into the
   extension, which `layer-rules.sh:27-35` explicitly avoids doing even inside the consuming
   repository.
8. **`layer-rules.sh` is sourced in a subshell for vacuity detection, never in the wrapper's own
   shell.** Grounds: it `exit 1`s during sourcing when the queue-model derivation yields nothing,
   which would kill the wrapper outright.
9. **`gate_flag` is the dispatch-file and delegation-context field name**, emitted as
   `- gate_flag: true` and omitted entirely when false. The metadata block is `gate`, documented
   as a new `### gate (optional)` section in `return-metadata-file.md` with an explicit
   "Include if … `gate_flag == true`; omitted entirely otherwise" clause and the same binding
   advisory MUST-NOTs the `comparator` section carries.
10. **No files are written under `agent-system/extensions/books/context/project/books/`.**
    Books-awareness reaches the gate through plain backticked pointers to
    `context/project/books/domain/gate-tiers.md` and `context/project/books/tools/certify-guide.md`.
    Grounds: that directory is the concurrent sibling task's declared `file_scope`; the existing
    `README.md` navigation stub already licenses pointing at not-yet-written paths.

## Recommendations

### Suggested phase decomposition (each one agent run, ~100-500 lines)

**Phase 1 — core flag plumbing.** `parse-command-args.sh` (five edits: doc comment, initializer,
detector, **the `FOCUS_PROMPT` strip chain**, the `export` list), `orchestrate-cycle-plan.sh`
(header paragraph, usage heredoc, declaration at 360, parse arm at 379, the implement-scoped
forwarding line at 2342), `orchestrate-build-dispatch.sh` (usage comment, contract block,
usage heredoc, declaration at 134, parse arm at 151, conditional emission at 427-429).
Verification: the flag reaches an implement dispatch file as exactly one added line and never
reaches a research/plan dispatch.

**Phase 2 — core docs and the metadata contract.** `commands/orchestrate.md` Options row (after
line 46) and the `--hard` composability row at 52; `skills/skill-orchestrate/SKILL.md` lines 32
and 82; `context/formats/return-metadata-file.md` new `### gate (optional)` section modelled on
`### comparator (optional)` at 269-311, including the advisory MUST-NOTs restated in the schema
itself ("so a reader of this schema alone, without the design record, still gets it").

**Phase 3 — `books-gate.sh`.** The wrapper, modelled line-for-line on `books-certify.sh`'s
resolve-and-fail-loudly shape, with `--json`, `--root`, and repeatable `--package-root`.
Declared in `provides.scripts`. Suggested JSON shape:

```json
{
  "ran": true,
  "layer_lint": {
    "status": "pass|pass_vacuous|violations|lint_unavailable|rule_set_error|usage_error",
    "package_roots": ["interface", "components/framed_channel"],
    "modules": 131, "imports": 564,
    "rules_matched": 9, "rules_total": 9,
    "violations": [], "violation_count": 0,
    "detail": ""
  },
  "books_meta_closure": {
    "status": "pass|violations|provider_absent",
    "public_import_violations": [], "public_import_violation_count": 0,
    "private_import_sites": 214,
    "provider_require_lines": 0
  },
  "runtime_seconds": 2
}
```

**Phase 4 — `test-books-gate.sh`.** A narrow fixture suite, declared in `provides.scripts` as
`tests/test-books-gate.sh`. Minimum cases, each one a measured behaviour from this report:
lint script absent → `lint_unavailable`, exit 0; a fixture root no rule's file-half reaches →
`pass_vacuous` with `rules_matched: 0`; a planted `public import Books.Meta` → one violation; an
archived/`specs/`-pathed `public import Books.Meta` → **not** a violation; a `.lake/`-pathed one →
not a violation; a `layer-rules.sh` that `exit 1`s on source → `rule_set_error`, wrapper still
exits 0. **A forgery probe per predicate** is a reviewable obligation here, not a nice-to-have —
see `context/project/books/standards/forgery-probe-discipline.md` and the FORGE-A..D cases in
`books/tests/manifest/run.sh` that generalize it.

**Phase 5 — books agent and skill binding.** Add the gate step to
`books-implementation-agent.md` Stage 5 (gate condition as the step's literal first line, copying
the lean agent's own wording at 370-374) and to `books-implementation-hard-agent.md`; add
`gate_flag` to `skill-books-implementation/SKILL.md` Stage 4's delegation JSON plus the Stage 5
bullet list, and a new read-only surfacing stage after Stage 6 copied from Stage 6c including its
asymmetry note; same for `skill-books-implementation-hard/SKILL.md`. Books-awareness via plain
backticked pointers only.

**Phase 6 — core test coverage.** `test-orchestrate-build-dispatch.sh` **Group 17** modelled on
Group 9 (427-471), asserting the one-added-line byte-identity property and the SUT's deliberate
phase-agnosticism. `test-orchestrate-cycle-plan.sh` **Group 35** modelled on Group 12
(1982-2070), asserting forwarding for an implement candidate, non-forwarding for a plan
candidate, and `--gate --compare --hard` composition.

### Verification for the whole task

`bash .claude/scripts/check-extension-docs.sh` (Rules E, Q, U) and
`bash .claude/scripts/tests/run-all.sh` — but note both read the **deployed** `.claude/` tree, so
a source-store-only change needs a regeneration before those gates see it. Run the two new/edited
suites directly against the source store in the meantime.

### Redeploy sequencing (state this in the completion summary)

The consuming repository's deployed `.claude/` is stale for `core` and `formal`. Because this work
edits `core` (engine, command file, skill, metadata format) **and** the books extension, `--gate`
**does not exist at all** in a consuming repository until that repository regenerates its
`.claude/` through the loader picker. Enabling the books extension in a consuming repository's
`.claude-extensions.json` is the user's own action, not this task's work.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| **`--gate` is a dangerously generic flag name.** The codebase already uses "gate" for GATE IN/GATE OUT, `command-gate-in.sh`, `command-gate-out.sh`, `orchestrate-stage5-gates.sh`, `full-gate.sh`, and "gate" in the fail-closed sense. A reader may expect `--gate` to *block*. | The flag name is mandated by the task. Mitigate in prose: the Options row, the dispatch contract comment, the `### gate (optional)` schema section, and both agent steps each state "advisory only; never blocks, never fails a dispatch, never downgrades status" in their own text. Copy the lean agent's placement discipline (370-374, 480-486) — the MUST-NOTs sit *inside* the step, precisely so a later editor cannot fold it into the failure enumeration. |
| **`[[ "$remaining" =~ --gate ]]` is a substring regex.** A focus prompt containing the literal `--gate`, or a hypothetical future `--gate-strict`, would false-positive; and `sed 's/--gate//g'` would mangle `--gate-strict`. | Pre-existing hazard shared by every flag in `parse-command-args.sh`. Note it in the implementation summary; do not introduce a `--gate-*` sibling flag. |
| **`layer-lint.sh` exit 1 conflated with violations.** `layer-rules.sh` `exit 1`s during sourcing when no queue model is found — common in any repository lacking `components/framed_channel/lean/FramedChannel/Model`. | Decision 4: classify on stderr content (`no queue model found`) before treating exit 1 as violations; report `rule_set_error` distinctly. |
| **Vacuous pass read as a real pass** — the single highest-value failure mode, since the motivating measurement is 44 violations hiding behind green. | Decision 5: independent `rules_matched`/`rules_total` via a subshell source of the real rule set; `pass_vacuous` as a first-class status; never collapse it into `pass`. |
| **Two archived `public import Books.Meta` occurrences produce false violations.** | Decision 6: prune `specs/` as well as `.lake/`. Phase 4 asserts both exclusions directly. |
| **Rule E breaks the build if `layer-lint.sh` is named in a doc location.** | Never name it in `commands/*.md`, `skills/*/SKILL.md`, `agents/*.md`, `README.md` or `EXTENSION.md`. Name only `books-gate.sh` there. The wrapper's own header comment and the books context corpus may name it freely. |
| **Sibling territory collision** on `agent-system/extensions/books/**`. The concurrent books-corpus task's declared `file_scope` includes the whole `context/project/books/` directory. | This work touches no file under `context/project/books/`. It does touch `books/manifest.json`, `books/scripts/`, `books/agents/` and `books/skills/` — which that task's own description explicitly disclaims owning. Re-read every books file immediately before editing; stage only this work's own hunks; never a directory or glob `git add`. |
| **Rule U headroom**: `books/EXTENSION.md` is at 52 of 60 lines. | Prefer not to touch `EXTENSION.md` at all; if a mention is needed, keep it to one line. |
| **Over-reach into a hard gate.** The flag must add a tier, never relax one. | Nothing in the plan modifies `layer-lint.sh`, `layer-rules.sh`, `check.sh`, `certify.sh` or `full-gate.sh` — all of which live in the consuming repository and are out of this repository's edit scope entirely. The wrapper only *invokes*. Record promotion-to-hard-gate criteria in the implementation summary (N consecutive clean non-vacuous runs across M distinct package roots with zero `lint_unavailable`/`rule_set_error` outcomes, plus a measured p95 runtime), mirroring the lean agent's own promotion-criteria obligation at lines 492-495. |

## Context Extension Recommendations

- **Topic**: the advisory-flag pattern itself (`--compare`, now `--gate`) — a reusable
  seven-file threading recipe with a byte-identity invariant and an advisory-only contract
  restated at four separate layers.
  **Gap**: the recipe exists only as two concrete instances; nothing documents it as a pattern,
  so the next advisory flag re-derives the whole surface (as this research had to).
  **Recommendation**: a `context/patterns/advisory-dispatch-flag.md` in the **core** extension
  listing the seven threading sites, the one-added-line byte-identity rule, the
  implement-only scoping guard, and the "MUST-NOTs inside the step, not in a separate section"
  discipline. Out of scope here; worth a follow-up.
- **Topic**: `check-extension-docs.sh` Rule E's consequence for consuming-repository scripts.
  **Gap**: the constraint is discoverable only by reading `books-certify.sh`'s header or Rule E's
  implementation. It will recur for every extension that wraps a consuming-repo tool.
  **Recommendation**: a short subsection in `docs/guides/creating-extensions.md` naming the
  resolve-and-passthrough wrapper as the sanctioned answer, citing `books-certify.sh`.
- **Topic**: gate-tier knowledge (what each tier does and does not check; vacuous passes).
  **Gap**: none to open — this is already the concurrent books-corpus task's
  `domain/gate-tiers.md` and `tools/certify-guide.md`. The measurements in this report
  (1.06 s / 0.53 s / 0-of-9 vacuity / 0-of-214 closure baseline) are the kind of landed figure
  that document is meant to carry.

## Appendix

### Probes executed (all against `~/Projects/Logos/Verification`)

```
bash interface/scripts/layer-lint.sh interface components/framed_channel   # exit 0, 1.063s, 131 modules/564 imports
bash interface/scripts/layer-lint.sh components/distsys                    # exit 0, vacuous (45/160)
bash interface/scripts/layer-lint.sh books                                 # exit 0, vacuous (62/119)
bash interface/scripts/layer-lint.sh nosuchdir                             # exit 2
bash interface/scripts/layer-lint.sh                                       # exit 2
# vacuity prototype: books -> rules_matched=0 of 9; interface+framed_channel -> 9 of 9
# closure prototype: 0 public-import violations, 214 private sites, 0 provider require lines, 0.527s
```

### Key file:line anchors

Core (source store, `agent-system/extensions/core/`):
- `scripts/parse-command-args.sh:22-25,91,135-137,169,183`
- `scripts/orchestrate-cycle-plan.sh:165-167,335,360,379,2342`
- `scripts/orchestrate-build-dispatch.sh:22-23,33-36,106-107,134,151,427-429`
- `commands/orchestrate.md:46,52`
- `skills/skill-orchestrate/SKILL.md:32,82`
- `context/formats/return-metadata-file.md:269-311`
- `scripts/check-extension-docs.sh:58,534-585,1062-1156`
- `scripts/tests/test-orchestrate-build-dispatch.sh:427-471`
- `scripts/tests/test-orchestrate-cycle-plan.sh:1982-2070`
- `scripts/tests/run-all.sh:12-13,30`

Lean (pattern precedent, `agent-system/extensions/lean/`):
- `skills/skill-lean-implementation/SKILL.md:98-104,134,216-240`
- `agents/lean-implementation-agent.md:368-495`
- `agents/lean-implementation-hard-agent.md:446-555`
- `skills/skill-lean-implementation-hard/SKILL.md:194,219,259`

Books (edit targets, `agent-system/extensions/books/`):
- `manifest.json` (`provides.scripts`, `routing_agents`, `routing_agents_hard`)
- `scripts/books-certify.sh:5-19,37-68` (wrapper precedent)
- `agents/books-implementation-agent.md:35-50,67-74,149-152`
- `skills/skill-books-implementation/SKILL.md:53-56,58-59,80-81,97-118`
- `EXTENSION.md` (52 of 60 lines)
- `context/project/books/README.md` (pointer-tolerance contract)

Consuming repository (`~/Projects/Logos/Verification`, never edited by this work):
- `interface/scripts/layer-lint.sh:15-21,26,38,60,68,72`
- `interface/scripts/layer-rules.sh:14-19,27-51,95-117`
- `books/lean/lakefile.toml:9-12` (no `require`), `:40-46` (explicit globs)
- `books/lean/BookCert/Depends.lean:23,110`; `books/certifier/Certify.lean:531`
- `components/rle_codec/check.sh:125`; `components/distsys/check.sh:195`
