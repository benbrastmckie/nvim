# Research Report: Task #129

**Task**: 129 - Empirically audit \b word-boundary grep patterns for compositional failure under the deployed grep
**Started**: 2026-09-26T00:00:00Z
**Completed**: 2026-09-26T00:00:00Z
**Effort**: ~3 hours (audit + empirical testing)
**Dependencies**: 88, 128, 261 (state.json); SEQUENCING note: depends on the adversarial-gate fix only to avoid a file-footprint collision on `skill-orchestrate/SKILL.md`, which this task does not touch.
**Sources/Inputs**: Live empirical grep/ugrep testing on the deployed host, source-store code search (`agent-system/extensions/**`), existing test suites, git history, `specs/state.json`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The dispatch's root-cause framing needs one precision correction, stated up front because
  the task itself warns that an imprecise version of this finding "is what would sink the audit
  itself"**: "the deployed grep is ugrep 7.8.4" is true only for a command an agent types
  directly into its own Bash-tool shell (a raw one-liner, or a multi-line snippet pasted in from
  an agent-instruction `.md` file). It is **not** true for a `\b` pattern living inside a `.sh`
  script or hook that is *executed* as a subprocess (`bash file.sh`, `./file.sh`, or Claude
  Code's own hook-runner spawn) — that subprocess resolves `grep` to GNU grep 3.12, which does
  **not** exhibit the compositional defect. This was verified empirically (not assumed) three
  independent ways: a clean `env -i bash -lc`, a nested `bash -c`, and literal execution of a
  `.sh` file containing the exact production pattern from the gate-failure bisection — all three
  print `grep (GNU grep) 3.12`, and the exact composed pattern that fails under ugrep **matches
  correctly** under GNU grep with `-i`.
- **Every one of the 8 files in this task's declared `file_scope` is a `.sh` script or hook**, so
  every `\b` site inside them runs under GNU grep in production. All were tested — via their own
  dedicated test suites where one exists, or via live full-repo execution otherwise — and **all
  are WORKING**. Zero repairs are required in `file_scope`.
- Widening the search to the full source store (`agent-system/extensions/**`, ~32 genuine
  grep-pattern `\b` call sites once LaTeX-macro and non-grep-engine false positives are excluded)
  found exactly two files carrying the *actually* ugrep-exposed shape (ad hoc/pasted commands
  documented in agent-instruction Markdown, not wrapped `.sh` files):
  `agent-system/extensions/lean/agents/lean-implementation-agent.md` and
  `lean-implementation-hard-agent.md`. Both use only single-`\b`/single-`\b...\b`-bracket shapes
  (never a chain of two or more `\b`-anchored subexpressions separated by wildcard runs), which
  the dispatch's own bisection evidence already showed is the *unaffected* shape. Re-verified
  directly against realistic Lean fixtures under the real deployed ugrep: all four sites MATCH
  the positive fixture and correctly NOMATCH a negative one.
- **The dispatch's "CONFIRMED INSTANCE"** (`lean-sorry-census.sh` double-counting `sorry` inside
  `set_option warn.sorry false in`) **is stale**. The source-store copy was already fixed by
  commit `232b05b7f` (regex switched from a bare `\bsorry\b` to a Python
  `(?<![.\w])sorry\b` negative-lookbehind form), and the sibling test suite already carries
  Fixtures A–E covering exactly this case, including an anti-vacuous-test guard. Running the
  suite now: **17/17 pass**. No code change is needed here; the action item is administrative
  (see Decisions).
- `literature-convert.sh`'s single `\b`-flagged line is a **false positive** of a naive substring
  search: `\\begin\{` contains the two characters `\`+`b` as a substring of `\begin`, not an
  actual word-boundary escape. There is no real `\b` construct in that file.
- No pattern anywhere in scope was rewritten. The one item flagged as genuinely stale
  (`lean-sorry-census.sh`'s upstream tracking) is a bookkeeping correction, not a regex change.
- A drafted guidance note (full text in Findings) is ready for the plan/implement phase to land
  under `agent-system/extensions/core/context/standards/`.

## Context & Scope

The task asked for an empirical, per-site audit of every `\b` word-boundary construct in a grep
pattern across the source store, explicitly forbidding fragment-only testing or generalizing one
site's result to another (the "BINDING CONSTRAINT" in the dispatch), because the underlying
defect is compositional: whether a given `\b` in a pattern works depends on what else is in the
pattern, not on the construct in isolation.

`file_scope` for this task (from `specs/state.json`) names 8 files:

```
agent-system/extensions/literature/scripts/literature-audit.sh
agent-system/extensions/literature/scripts/literature-convert.sh
agent-system/extensions/lean/scripts/lean-sorry-census.sh
agent-system/extensions/core/scripts/test-session-runtime-files.sh
agent-system/extensions/core/scripts/check-extension-docs.sh
agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh
agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh
agent-system/extensions/core/hooks/guard-destructive-git.sh
```

The task description's own scope note ("roughly 26 grep-adjacent `\b` sites ... spanning
literature scripts, lean scripts, core scripts, lint scripts, test harnesses, and hooks") is
broader than the declared `file_scope`, so this audit covers both: the 8 declared files in full,
and a repo-wide sweep of `agent-system/extensions/**` to locate every other genuine grep-pattern
`\b` site, so the "roughly 26" estimate is checked rather than assumed.

`skill-orchestrate/SKILL.md` — the adversarial-verification gate that surfaced the original
failure (event `evt_1788245094839_eybEyC`) — is explicitly out of scope (owned by a sibling task)
and was not touched.

## Findings

### 1. The deployed grep is invocation-context-dependent, not a single global fact

This is the load-bearing correction to the dispatch's framing, established empirically before
auditing individual sites (per the BINDING CONSTRAINT, reasoning about what "should" happen is
exactly the trap; only direct execution counts):

- `grep --version` typed at the top level of an agent's Bash-tool shell in this environment
  reports `ugrep 7.8.4 x86_64-pc-linux-gnu +sse2; -P:pcre2jit; ...`. Inspecting `type grep`
  shows this is a **shell function** (not the `grep` binary on `$PATH`) that `exec -a ugrep`'s
  the Claude Code binary itself, giving the model's own ad hoc `grep` commands ugrep's
  matching semantics.
- That function is **not exported** (`export -f` lists zero functions in this session), and
  `$BASH_ENV` is empty. Three independent checks all confirm a **child** bash process does not
  inherit it and resolves plain `grep` to `/run/current-system/sw/bin/grep` = GNU grep 3.12:
  `env -i bash -lc 'grep --version'`, a nested `bash -c 'grep --version'`, and literal execution
  of a `.sh` file (`bash /tmp/.../t.sh`) that itself calls `grep --version`.
- Directly reproducing the gate-failure bisection's exact production pattern (with `-i`, since
  the header text is mixed-case and the dispatch's lower-case fragments only reproduce as
  written under case-insensitive matching) against the literal header line confirms the split:

  | Invocation context | Engine | `\|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b[^|]*\|` (with `-i`) |
  |---|---|---|
  | Raw command typed at the agent's Bash-tool top level | ugrep 7.8.4 | **NOMATCH** (bug reproduced) |
  | Same pattern, run inside a `.sh` file via `bash file.sh` | GNU grep 3.12 | **MATCH** (correct) |

  Individual fragments (`\bclaim\b`, `\bsource\b[^|]*\bcounterexample\b`) MATCH under **both**
  engines with `-i` — confirming the defect is genuinely compositional and genuinely
  ugrep-specific, not a case-sensitivity artifact and not present in GNU grep at all.

**Consequence for scoping**: every file in this task's `file_scope`, and every `test-*.sh` /
`lint-*.sh` / hook in the broader "literature scripts, lean scripts, core scripts, lint scripts,
test harnesses, and hooks" categories the task description names, is a `.sh` file that is
*executed* (as a hook command, or as `bash path/to/file.sh` by an agent's Bash tool, or by
another script) — never sourced into the calling shell. All of them therefore run under GNU
grep 3.12 in production, immune to the defect that motivated this audit. The defect is real and
correctly attributed to ugrep; it is *not* uniformly "the deployed grep" for this file class.

### 2. `file_scope` audit (8 files) — every site WORKING

| File | `\b` site(s) | Test method | Result |
|---|---|---|---|
| `hooks/guard-destructive-git.sh` | `--hard\b` (git reset --hard detector); `(drop\|clear)\b` (git stash detector) | `extensions/core/scripts/tests/test-guard-destructive-git.sh` | **50/50 pass** |
| `scripts/check-extension-docs.sh` | `[A-Za-z0-9_-]+\.(sh\|sql)\b` (referenced-script scanner; trailing `\b` guards against `df.shape`/`wb.sheetnames`-style false positives) | Live run of the deployed `check-extension-docs.sh` against every real extension | **PASS: all extensions OK** (no false positives leaked through) |
| `scripts/lint/lint-postflight-boundary.sh` | `Agent\b` (alternation branch); `grep -r.*\\.(lua\|lean\|py)\b` (meta-pattern testing another script's text) | `extensions/core/scripts/tests/test-lint-postflight-boundary.sh` | **6/6 pass** |
| `scripts/test-session-runtime-files.sh` | `\$_seeded\b`; `\bexit\b`; `\breturn 1\b` | Ran the harness itself (it is a self-contained test harness, not a script under test) | **6/6 pass** |
| `scripts/tests/test-lake-build-guard.sh` | `[0-9]+(GB\|MB\|G\|M)\b` (asserts the guard script contains no hardcoded absolute byte constant) | Ran the harness itself | Case 12b (`\b` assertion): **PASS**. One unrelated failure (case 3, a stdout/stderr interleaving ordering issue in a command-substitution test, no `\b`/grep content) — pre-existing, out of this task's scope. |
| `extensions/literature/scripts/literature-audit.sh` | Four independent `\b(Definition\|Lemma\|Theorem\|Proposition\|Corollary\|Remark\|Example)\s+[0-9]+(\.[0-9]+)*\b` / `\bTheorem\s+[A-Z]\b` / `\bAxiom...\b` / `\bFigure...\b` extraction patterns (P1–P4), each a single `\b...\b` bracket around one alternation+number span | Built a realistic literature-markdown fixture (`Theorem 3.1`, `Definition 2.4`, `Lemma 5`, `Theorem A`, plus a `theoretically` false-positive probe) and ran the literal `grep -oE` lines under GNU grep | P1 correctly extracted `Theorem 3.1`, `Definition 2.4`, `Lemma 5`; P2 correctly extracted `Theorem A`; the `theoretically` false-positive probe correctly matched **zero** times |
| `extensions/lean/scripts/lean-sorry-census.sh` | Documented in the file's own header as the `\bsorry\b`-on-comment-stripped-text hazard; **current implementation does not use that construct at all** — see Finding 3 below | `extensions/lean/scripts/tests/test-lean-sorry-census.sh` | **17/17 pass**, including Fixtures A/B/D specifically covering `set_option warn.sorry false in` |
| `extensions/literature/scripts/literature-convert.sh` | (flagged by the initial broad search) | Manual inspection | **False positive** — see Finding 4 |

No pattern in `file_scope` needed a `-P` switch or a `\b` removal. Each row above is the recorded
empirical result the ACCEPTANCE criterion asks for; none of it is "reasoning about whether a
construct should work" — every row is a real run against real input under the real, in-context
deployed grep.

### 3. `lean-sorry-census.sh`'s "CONFIRMED INSTANCE" is already fixed — the dispatch text is stale

The dispatch carried forward a specific measurement ("41 reported = 23 real + 18 annotation
lines... repo-wide 45 = 27 + 18") attributed to "the cslib consumer repo's own task list, where
it is filed as a local defect and cannot be fixed." Reading the current source:

```python
sorry_re = re.compile(r'(?<![.\w])sorry\b')
```

This is **not** the naive `\bsorry\b` the dispatch describes as the culprit — it is a negative
lookbehind that explicitly excludes a `sorry` preceded by a word character *or a literal dot*,
which is exactly the `warn.sorry` case. Confirmed directly:

```python
>>> sorry_re.search('set_option warn.sorry false in')
None                                    # correctly excluded
>>> sorry_re.search('theorem foo : True := by sorry')
<match>                                  # correctly counted
```

`git log` on this file shows the fix commit directly: `232b05b7f "task 1003 phase 2: apply
regex fix and reconcile stale pattern references"`, dated 2026-08-10 — six weeks before this
task was dispatched. The sibling test suite already carries the exact fixture this task's
dispatch asked me to add:

```
Fixture A: own-line annotation
  set_option warn.sorry false in
  theorem foo : P := sorry
Expect exactly 1 (the real sorry only).
```

plus an anti-vacuous-test guard (asserting the naive per-line `\bsorry\b` count differs from the
tool's real count, so the fixture cannot pass by accident) and Fixtures B–E covering same-line
annotations, comment/string stripping, dotted-name generality, and an aggregate case. Running the
suite now: **17/17 pass, 0 fail.**

**Conclusion**: no code change or new fixture is needed in this repo's source store. What *is*
real is that the **cslib consumer repo has a stale deployed copy** of this script predating the
fix, and its own local task tracking the defect against that stale copy should be abandoned with
a pointer to commit `232b05b7f` and to this audit's confirmation — provided the consuming repo
re-deploys/re-syncs its extension copy to pick up the already-fixed source. That is a
coordination action, not a regex-portability action, and belongs to the consumer repo's own task
list rather than to this one's deliverables.

### 4. `literature-convert.sh` — false positive, no `\b` construct present

The line flagged by the initial broad `grep -rlE '\\b'` sweep is:

```
MATH_COUNT=$(grep -cE '\$\$|\\begin\{' "$OUTPUT_MD" 2>/dev/null)
```

`\\begin\{` is the literal string `\begin{` (a LaTeX environment opener), and the two characters
`\` followed by `b` happen to appear as a substring of `\begin` — matching the coarse regex
`\\b` used for the initial file-list sweep. This is not a word-boundary escape at all; there is
no compositional risk and nothing to test or repair here. (The same class of false positive
matched many `.md` files across the source store — `\begin`, `\bf`, `\boldsymbol`, `\bigl`,
`\bullet`, `\binom`, `\bibliography`, `\bottomrule`, `\bot` — all LaTeX/Typst macros, none of
them grep patterns; excluded from the audit below by the same reasoning, not individually
re-verified since they are not grep invocations at all.)

### 5. Broader source-store sweep beyond `file_scope` — confirms the "roughly 26" estimate and finds no repairs

Restricting to genuine `grep`/`egrep` invocations containing `\b` (excluding sed, Python `re`,
jq's regex, and literal English-word false positives like the string "backslash"), the full
`agent-system/extensions/**` tree contains approximately 32 such call sites, close to the
dispatch's "roughly 26" estimate once the four repeated P1–P4 literature-audit.sh call sites are
grouped by their 4 underlying pattern definitions rather than counted per call line. All were
either directly re-verified or covered transitively by a passing test suite:

- `extensions/core/scripts/lib/task-reference-patterns.sh` (`TASK_PATTERN`, `PHASE_PATTERN`,
  both single `\b(...)\b` brackets around one alternation) — exercised by
  `extensions/core/scripts/tests/test-validate-no-task-references.sh`: **31/31 pass**.
- `extensions/core/scripts/lib/task-type-detect.sh` (three sites: an alternation of two
  independent `\bword\b` branches joined by `|`, a single trailing `\.lean\b`, and a dynamic
  `\b${kw}\b` bracket) — exercised by
  `extensions/core/scripts/tests/test-task-type-detect.sh`: **10/10 pass**.
- `extensions/core/scripts/tests/test-census-count.sh` (`--pattern '\bTARGET\b'`, a single
  bracket, fed straight into `census-count.sh`'s own `grep -oE "$pattern"`, confirmed by reading
  that tool's source): **8/8 pass**.
- `extensions/core/scripts/tests/test-orchestrate-recover-message-findings.sh`
  (`grep -q "sess_930\b"`, single trailing `\b`): the specific assertion using this pattern
  ("never-clobber: the original file is untouched") **passed**; 2 unrelated failures elsewhere
  in the same suite (an `detected_defects`/acceptance-e2e assertion) are pre-existing and
  unrelated to `\b`/grep content.
- `extensions/lean/scripts/lean-comparator-run.sh` (`` lean_lib[[:space:]]+\`?${name}\b ``,
  single trailing `\b`) — exercised by
  `extensions/lean/scripts/tests/test-lean-comparator-run.sh`: **22/22 pass, 1 skip**
  (skip is an unrelated, pre-existing binary-availability deferral, not a `\b` finding).
- `extensions/literature/scripts/literature-chunk.sh` (`XREF_PATTERN`, an OR of two independent
  single-bracket `\b...\b` spans): this variable is **defined but never referenced anywhere else
  in the file** — dead code, not a live grep invocation, so there is nothing running in
  production to repair. Worth a one-line cleanup note for whoever next touches the file, but out
  of this audit's repair scope (no risk exists to mitigate).
- `extensions/lean/agents/lean-implementation-agent.md` (4 sites: three trailing single `\b`
  after a dynamic name, one `\b${replaced}\b` bracket) and
  `extensions/lean/agents/lean-implementation-hard-agent.md` (1 site, same trailing-`\b` shape)
  — these are the two files in the *actually* ugrep-exposed category (fenced ```bash blocks in
  agent-instruction Markdown meant to be pasted directly into the acting agent's own Bash tool,
  the same execution path as the already-owned gate). Verified directly against a synthetic Lean
  fixture (`Foo.lean` with `theorem foo_bar_baz`, `noncomputable def helper_widget`,
  `lemma old_name_helper`) under the real deployed ugrep at the top level of this session's Bash
  tool: all four shapes MATCH the intended positive line and correctly NOMATCH a
  substring/nonexistent negative (`old_name_helperx`, `nonexistent_name`). None of the four sites
  chains a second `\b`-anchored subexpression after an earlier one across a wildcard run — the
  one shape the bisection evidence shows is actually broken — so none is at risk despite running
  under the vulnerable engine.
- `extensions/core/context/standards/census-methodology.md` (doc examples showing
  `grep -oE '\bWIDGET\b'` as an illustrative "naive grep" baseline) and
  `extensions/core/context/guides/extension-development.md` /
  `extensions/core/context/patterns/system-defect-discrimination.md` (prose describing the `\b`
  construct generically, not literal invocations) — informational only, not live sites.
- Notably, `system-defect-discrimination.md` **already names this exact defect class** under a
  dedicated vocabulary entry, `HOOK_REGEX_BOUNDARY_DEFECT`, and records the gate failure itself
  as "an orchestration gate's `grep` matcher... whose unstated boundary assumption was a `\b`
  word-boundary anchor composed downstream of an earlier `\b`-anchored subexpression, separated
  by a `[^|]*` run — mis-evaluated by the deployed POSIX/DFA `-E` grep engine." This confirms the
  present audit's technical characterization matches the system's own existing defect taxonomy,
  and gives the guidance note below a vocabulary anchor to reference rather than reinvent.
- Roadmap/literature-search/literature-fidelity-audit `\b` occurrences are Python `re.compile`
  calls (a different regex engine entirely, with no such compositional defect) — out of the
  "grep pattern" scope by the dispatch's own framing, not re-verified as grep sites because they
  are not grep invocations.

**No site anywhere in the source store — in `file_scope` or beyond it — required a repair.**

## Decisions

- Treat "the deployed grep" as **invocation-context-dependent**, not a single fact, in all
  follow-on work: a `.sh` file executed as a subprocess runs GNU grep 3.12 (immune); a command an
  agent pastes directly into its own Bash tool (a raw one-liner, or a fenced ```bash block copied
  verbatim out of an agent-instruction `.md` file) runs ugrep 7.8.4 (compositionally unreliable
  for chained multi-`\b` patterns). This is the single correction that keeps the audit precise,
  per the dispatch's own warning.
- No pattern in `file_scope` or the broader sweep is rewritten. Nothing here contradicts the
  dispatch's list of currently-working high-stakes sites (`guard-destructive-git.sh`'s
  `--hard\b`/`(drop|clear)\b`, the sorry census, `literature-audit.sh`'s P1); this audit
  independently reconfirms all of them plus everything else in scope.
- `lean-sorry-census.sh`'s regression is closed; recommend the cslib consumer repo's local task
  be abandoned with a pointer to commit `232b05b7f` and this audit, once that repo has
  re-synced its extension copy (a redeploy/resync check, not a new fix).
- Recommend the plan/implement phase land the guidance note below under
  `agent-system/extensions/core/context/standards/` (suggested filename:
  `grep-word-boundary-portability.md`) and add it to `file_scope`, since it is a new file rather
  than an edit to a file already declared. No existing file under that directory currently
  covers this topic (checked via directory listing).

## Guidance Note (drafted text, ready to land verbatim)

> ## Word-Boundary (`\b`) Portability Across Deployed grep Contexts
>
> **The deployed `grep` is invocation-context-dependent, not a single fact.** In this
> environment, `.sh` scripts and hooks executed as a subprocess (`bash file.sh`, `./file.sh`, or
> the hook runner) resolve `grep` to GNU grep. A command typed or pasted directly into an agent's
> own Bash-tool shell — a raw one-liner, or a fenced ```bash block copied verbatim out of an
> agent-instruction Markdown file — runs under ugrep instead, exposed to the compositional defect
> below. Determine which context applies before assuming either engine.
>
> **ugrep's `-E` engine mis-evaluates `\b` compositionally, not by ignoring it.** A `\b` that
> appears downstream of an earlier `\b`-anchored subexpression, separated by a wildcard run (for
> example `[^|]*`), can silently fail to match even though every fragment matches fine in
> isolation and even though `-P` (PCRE2) on the identical unmodified pattern matches correctly.
> This is `HOOK_REGEX_BOUNDARY_DEFECT` in `system-defect-discrimination.md`. A single `\b`, or a
> single `\b...\b` bracket around one alternation/token (the shape `\bWORD\b` or
> `\b(A|B|C)\s+N\b`), is not known to be affected — only a *chain* of two or more independent
> `\b`-anchored subexpressions in one linear pattern is at risk.
>
> **Prefer delimiter-anchored alternatives where the surrounding pattern already bounds the
> token** — e.g. a pipe-delimited table cell (`\|[^|]*TOKEN[^|]*\|`) or a whitespace/quote-bounded
> field often does not need `\b` at all; the existing delimiter already prevents partial-word
> matches. Drop `\b` in favor of the delimiter where that is true, rather than adding more `\b`s
> to a pattern that already has one.
>
> **Where `\b` is genuinely needed and the pattern will run under ugrep** (an agent-facing ad hoc
> command, or a fenced code block in an agent-instruction Markdown file), switch that invocation
> to `-P` rather than `-E`/default BRE — PCRE2 evaluates the same pattern correctly.
>
> **Any new `\b` pattern must be executed against a real positive input AND a real negative input
> under the actual mechanism that will run it in production** — not reasoned about, not tested as
> a simplified stand-in, and not assumed safe by analogy to a working pattern elsewhere. A
> pattern that matches in isolation is not evidence it matches once composed with the rest of a
> real production pattern.

## Risks & Mitigations

- **Risk**: a future edit adds a *second* `\b`-anchored subexpression to an existing single-`\b`
  pattern inside an agent-instruction Markdown file (moving it into the at-risk shape) without
  re-testing. **Mitigation**: the guidance note's final bullet, plus flagging this specifically
  for `lean-implementation-agent.md`/`lean-implementation-hard-agent.md` maintainers going
  forward.
- **Risk**: the cslib consumer repo's stale copy of `lean-sorry-census.sh` continues to
  double-count `sorry` until it re-syncs. **Mitigation**: this is a deploy-freshness issue in a
  separate repo, out of this repo's remediation scope; the recommendation above names the exact
  commit to point its task at.

## Context Extension Recommendations

- **Topic**: grep-engine portability under this host's Nix-provisioned `grep` shim.
- **Gap**: no existing standards file documents that `grep` resolves differently depending on
  invocation context (interactive Bash-tool session vs. subprocess script execution), which is a
  prerequisite fact for correctly scoping *any* future `\b`/regex-portability audit in this repo.
- **Recommendation**: land the guidance note above under
  `agent-system/extensions/core/context/standards/grep-word-boundary-portability.md`.

## Appendix

### Search queries used

- `grep -rlE '\\b' agent-system/` (initial broad sweep, many false positives from LaTeX macros)
- Per-file `grep -nE '\\b' <file>` to extract exact matched lines
- `git log --oneline -- agent-system/extensions/lean/scripts/lean-sorry-census.sh`
- `git show --stat 232b05b7f`

### Commands run to establish the invocation-context finding

```
grep --version                                   # ugrep 7.8.4 (top-level Bash-tool shell)
type grep                                        # shell function, exec -a ugrep "$claude_bin" ...
export -f | wc -l                                # 0 (function not exported)
env -i bash -lc 'grep --version'                 # GNU grep 3.12
bash -c 'grep --version'                          # GNU grep 3.12
bash /tmp/.../t.sh   # (t.sh contains: grep --version)   # GNU grep 3.12
```

### Test suites run (all under the actual deployed engine for their invocation context)

```
test-guard-destructive-git.sh            50 passed, 0 failed
test-task-type-detect.sh                 10 passed, 0 failed
test-lint-postflight-boundary.sh          6 passed, 0 failed
test-validate-no-task-references.sh      31 passed, 0 failed
test-census-count.sh                      8 passed, 0 failed
test-lake-build-guard.sh                 46 passed, 1 failed (unrelated: case 3)
test-orchestrate-recover-message-findings.sh   21 passed, 2 failed (unrelated: acceptance e2e)
test-subagent-postflight-marker.sh       20 passed, 0 failed
test-session-runtime-files.sh             6 passed, 0 failed
test-lean-sorry-census.sh                17 passed, 0 failed
test-lean-comparator-run.sh              22 passed, 0 failed, 1 skipped (unrelated: binary availability)
check-extension-docs.sh (live, deployed) PASS: all extensions OK
```
