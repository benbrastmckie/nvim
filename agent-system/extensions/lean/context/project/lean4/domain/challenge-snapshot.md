# Challenge Statement Snapshot: Design Record

This file records the design decisions behind
`agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`, which establishes the trusted
Challenge module that Comparator integration requires but that this system has never produced
(the "no Challenge exists today" constraint recorded in
`comparator-integration.md`). It exists so a future maintainer — in particular whoever wires the
Comparator compare step or promotes it to a hard gate — does not have to re-derive the
R1-vs-R2 decision or the immutability mechanism from scratch.

## What a Challenge Is, and Why This System Has None

`lean-comparator-run.sh` compares an untrusted `Solution.lean` against a trusted `Challenge.lean`
naming the exact intended theorem statements (bodies optionally `sorry`). It never synthesises
`Challenge.lean` content itself — both `--challenge-module` and `--solution-module` must already
exist as committed `.lean` source in the target project's git tree at the checked-out commit.

Before this task, this system's plans record goal *identifiers* only
(`- **Goals**: ... proves \`comm\` ...`), never the *statement*. `lean-implementation-agent.md`'s
own compliance check is a name-existence grep over the roots resolved by `lean-src-roots.sh`,
not a statement check — a same-named, weakened restatement passes it silently. Nothing upstream of that check has ever
recorded what the theorem was supposed to say. This gap is closed by fixing the intended
statement *before* the implementation agent runs, and by making it immutable thereafter — a
Challenge the agent can rewrite certifies nothing.

## R1-vs-R2 Decision

**Decision: R1 (plan-declared statements) is the primary Challenge source. R2 (git-baseline
extraction) is a logged, loudly-degraded fallback for legacy plans only — never silent, never
primary.**

| | R1 (plan-declared) | R2 (git-baseline extraction) |
|---|---|---|
| Greenfield theorem (no existing declaration) | Works — the plan is written before any code exists | **Cannot work** — nothing to extract. This is the case this task exists to close, and most proof tasks in this system start exactly here: a goal identifier with no existing partial declaration. |
| Cost to shared format | Touches `plan-format.md`, but additively and gated on `task_type: lean`/`lean4` | None to `plan-format.md` |
| Fidelity to planner intent | Exact — the planner writes the literal signature | Only as good as whatever declaration already happens to sit in the tree; a plan that *changes* an existing signature (e.g. generalising a hypothesis) would extract the **old**, wrong statement |
| Mechanism complexity | A markdown section + fenced-block extraction — the same class of text parsing as the existing `**Goals**:` backtick regex | A git-history walk plus a declaration-boundary extractor from raw Lean source (harder: brace/`:=`-balanced parsing, multi-line signatures, `@[...]` attribute prefixes, `noncomputable`/`private`/`protected` modifiers) |
| Requires import-context reconstruction | Planner supplies imports directly in the fenced block | Extractor must also lift the source file's own `import` lines, or the extracted signature may not type-check standalone |

R1 wins because **R2 structurally cannot serve the greenfield case at all** — a plan proposing a
theorem that does not yet exist has nothing in the tree to extract. A route that only sometimes
produces a Challenge is not a foundation the Comparator compare step can build a uniform
`--compare` flag on top of. R2 is retained only so a lean plan authored *before* this feature
existed (no `## Lean Challenge Statements` section) is not simply unable to produce a Challenge —
but R2 is used only when every named identifier already resolves to a real declaration in the
tree at the plan's approval commit; any identifier resolvable by neither route is a hard failure,
never a silently incomplete Challenge (see "Fail-loud on partial resolution" below).

## Where the Challenge Is Stored, and What Stops Regeneration

**Storage**: the authoritative artifact is a **git commit in the target project's own
repository** — the same mechanism `lean-comparator-run.sh --commit REF` already assumes when it
`git worktree add --detach`s a checked-out commit. `lean-challenge-snapshot.sh` writes the
assembled module (e.g. `Challenge.lean`) at the target project's root, `git add`s it, and commits
it as an isolated commit. A pointer to that commit — never a copy of its content treated as
authoritative — is recorded in a manifest at `specs/{NNN}_{SLUG}/challenge/manifest.json` (see
schema below). The specs-side manifest is a pointer, not the trust boundary: the trust boundary
is that `git show <SHA>:<path>` (and therefore `lean-comparator-run.sh --commit <SHA>`) always
retrieves exactly the bytes committed at that SHA regardless of what the working tree or `HEAD`
looks like afterward.

**What stops regeneration**, at two independent layers:

1. **Process-level status gate**: the script reads the task's status from `specs/state.json`
   before writing or overwriting a manifest. Any status past `planned` (`implementing`,
   `pr_ready`, `completed`, ...) is refused with exit `73`, naming the task, its current status,
   and the fact that a Challenge must predate implementation to certify anything. This is a loud
   refusal, not a silent no-op.
2. **Mechanism-level SHA pin**: even a `--force`-bypassed regeneration cannot retroactively change
   what an *already-recorded* SHA points to. `git show <original-SHA>:<path>` returns the
   original bytes forever, independent of any later commit. `content_sha256` (a hash of the
   assembled module computed independently of git) is recorded alongside the commit SHA as a
   second, git-independent immutability witness — one that still lets a caller detect tampering
   even if the target project's own repository were somehow rewritten.

`--force` past `planned` still succeeds (an operator override is sometimes genuinely needed) but
prints an incident-shaped warning naming the task, its status, and the fact that any previously
recorded manifest SHA is now stale for callers still holding it — never a quiet success. See
Phase 4's test cases for the exact assertion.

### Fail-loud on partial resolution

Any `theorem_names` identifier resolvable by neither R1 nor R2 is a hard `71` (`config_error`)
failure naming the specific missing identifier. The script never emits a partial Challenge
omitting an unresolvable name — Comparator would silently accept that as "no theorem named here
to check," which is exactly the failure mode this task exists to prevent.

## Manifest Schema

`specs/{NNN}_{SLUG}/challenge/manifest.json`, read verbatim by the Comparator compare step:

```json
{
  "schema_version": 1,
  "task_number": 154,
  "plan_path": "specs/154_.../plans/01_....md",
  "project_root": "/absolute/path/to/target/project",
  "challenge_module": "Challenge",
  "challenge_path": "Challenge.lean",
  "theorem_names": ["comm", "assoc"],
  "route": "plan-declared",
  "commit": "<40-char SHA>",
  "content_sha256": "<64-hex-char sha256 of the assembled module>",
  "created_at": "2026-09-07T00:00:00Z"
}
```

`route` is `"plan-declared"` (R1) or `"git-baseline"` (R2) — the manifest records which mechanism
actually produced the Challenge, not merely which was attempted.

## Exit-Code Vocabulary

Deliberately aligned with `lean-comparator-run.sh`'s own codes where the meanings correspond —
the two tools share an operator-facing vocabulary rather than inventing a second one:

| Code | Meaning | Mirrors |
|------|---------|---------|
| `0` | OK | Comparator's own `verified`/pass exit |
| `64` | Usage error | `lean-comparator-run.sh`'s own `64` usage error |
| `65` | Statement drift detected (`--check` mode only) | Comparator's `statement_mismatch` verdict |
| `71` | Config error — identifier-set mismatch between `## Lean Challenge Statements` and `**Goals**:`, or an identifier resolvable by neither R1 nor R2 | Comparator's `config_error` verdict |
| `73` | Snapshot refused — status-gate refusal (regeneration attempted past `planned`, or an existing manifest without `--force`) | (new to this tool; no Comparator analogue — Comparator has no notion of a status gate) |

## Gate Strength: Advisory Only

**This tool's `--check` verdict, like `lean-comparator-run.sh`'s own verdict, is ADVISORY ONLY.**
A drift finding (exit `65`) MUST NOT be interpreted by any caller as grounds to set
`verification_passed` false, downgrade a task's status to `partial`, or block completion.
Promotion to a hard gate is a separate, later decision to be taken on evidence from real runs —
the same operator decision already recorded, unchanged, for `lean-comparator-run.sh` in
`comparator-integration.md`. Nothing produced by this task wires the snapshot or any drift
verdict into a completion gate.

## Demonstrated Behaviour

Recorded here rather than asserted. The demonstration ran against a `git clone --no-hardlinks`
scratch copy of a real, operator-owned Lean project (Apache-2.0-licensed research library, ~700
tracked `.lean` files, `leanprover/lean4:v4.33.0-rc1`), targeting two real, already-proved
theorems (`embedFormula_neg`, `embedFormula_and`) from its conservative-extension metatheory —
never a synthetic fixture. The scratch clone was deleted afterward; the operator's live
repository was confirmed byte-for-byte unaffected (`git status --porcelain` and `git log -1`
identical before and after). See the task summary's Phase 8 section for the literal commands.

**Environment measured at demonstration time** (differs from the shared background's 2026-09-07
measurement): `landrun` and `comparator` ARE present (`~/.nix-profile/bin/`); `lean4export` and
`nanoda_bin` remain absent.

- **Comparator-acceptable Challenge**: `lean-challenge-snapshot.sh` produced
  `theorem_names: embedFormula_and,embedFormula_neg` and a Challenge module containing exactly
  those two declarations, bodies forced to `sorry` — the same shape as the vendored
  `tests/fixtures/comparator/simple_match/Challenge.lean` fixture (a small, standalone file with
  only the named declarations). The module was committed into the scratch clone
  (`git commit --allow-empty`-backed) and the resulting commit SHA was independently confirmed
  retrievable: `git show <SHA>:Challenge.lean` returned exactly the assembled bytes, and their
  `sha256sum` matched the manifest's recorded `content_sha256`. **SKIPPED, named explicitly**: the
  end-to-end sandboxed `comparator` run (build/export/kernel-replay) and the "resolvable as a
  `lean_lib` target" sub-check that depends on it — both require `lean4export`, absent on this
  host, and synthesizing the `lakefile.toml`/`Solution.lean` machinery `lean-comparator-run.sh`
  needs is explicitly the downstream compare-step task's concern (see Non-Goals), not this task's.
- **Statement drift, both directions**: the real, already-honest `embedFormula_neg` declaration
  was weakened in the scratch clone's working tree by adding a vacuous hypothesis
  (`(h : True)`); `--check` exited `65`, naming `embedFormula_neg` only — `embedFormula_and` was
  correctly NOT flagged. The original declaration was then restored verbatim; `--check` exited
  `0` (no drift).
- **Immutability**: the scratch task was advanced from `planned` to `implementing`; re-running
  the snapshot exited `73`, naming the task and its status, with the working tree unchanged
  (`git status --porcelain` showed only the deliberate `state.json` status edit). `--force`
  then succeeded, printing the incident warning naming the task and status, and producing a
  SECOND commit SHA — yet `git show <ORIGINAL-SHA>:Challenge.lean` still returned exactly the
  original bytes, and their `sha256sum` still matched the original manifest's `content_sha256`,
  confirming the bypass could not retroactively change what the original SHA points to.

## Alternatives Evaluated and Rejected

- **Amending the shared `**Goals**:` bullet block to carry statements inline**: rejected because
  `**Goals**:` bullets are prose consumed by every task type's plan-format contract, including
  non-lean ones. A change there is not additive and cannot be proven to leave non-lean plans
  untouched. A new, independently-gated section (mirroring the existing
  `## Planned Strategic Sorries` precedent, itself gated on `plan_metadata.skeleton`) leaves the
  shared bullet format completely unmodified.
- **R2 as the primary route with R1 as an enhancement**: rejected because R2 cannot serve the
  greenfield case under any framing — making it primary would mean most proof tasks (which start
  from nothing) simply have no Challenge, defeating the task's purpose.
- **Filesystem-permission-based immutability (e.g. `chmod`-ing the manifest read-only)**:
  rejected — trivially bypassed by anyone with write access to the filesystem, and provides no
  guarantee once the file has been copied or the permission changed. Git content-addressing is
  the mechanism `lean-comparator-run.sh` already trusts; reusing it costs nothing new and is
  strictly stronger.
