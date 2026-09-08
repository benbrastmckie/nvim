# Research Report: Task #156

- **Task**: 156 - Surface a Comparator doctor mode and document what a green result does and does not certify
- **Started**: 2026-09-08T01:50:00Z
- **Completed**: 2026-09-08T01:55:00Z
- **Effort**: ~1 session (research only)
- **Dependencies**: 155 (compare flag threaded through lean-implementation-agent) — completed
- **Sources/Inputs**:
  - Codebase: `agent-system/extensions/lean/**` (commands, skills, agents, context, manifest,
    index-entries.json, scripts)
  - Live host probing: `which`/`ldd`/`readlink -f` against real `comparator`/`landrun` binaries
    now present on this host
  - Upstream `leanprover/comparator` README (fetched verbatim, see Appendix)
  - Upstream `leanprover/lean4export` repo and its `lean-toolchain` file (fetched verbatim)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md,
  no-task-references-in-deliverables.md

## Executive Summary

- The doctor mode's binary-presence/override-var logic already has a proven pattern to copy:
  `lean-comparator-run.sh`'s `resolve_binary()`, using the exact same four env vars
  (`COMPARATOR_BIN`, `COMPARATOR_LANDRUN`, `COMPARATOR_LEAN4EXPORT`, `COMPARATOR_NANODA`).
- **The C3 version-match check cannot be a binary `--version` query**: `lean4export` has no
  version/help flag (confirmed against upstream), and a real, currently-installed Comparator
  binary on this host is statically linked with no dynamically-linked path back to an elan
  toolchain (confirmed via `ldd`) — so introspecting the binary itself is a dead end for both
  tools actually available today.
- The only sound, generalizable check is a **bounded directory walk-up from the resolved
  binary's path looking for a sibling `lean-toolchain` file** (the artifact of a `git clone` +
  `lake build` install, which is how a niche, non-nixpkgs-packaged tool like `lean4export` is
  realistically installed) — compare its content against the target project's own
  `lean-toolchain`. When no such file is discoverable, the doctor MUST report an explicit
  "unknown / cannot verify" finding, never a silent pass.
- Task 156's own `file_scope` in `specs/state.json` does **not** list a new script file — the
  doctor mode should be implemented as inline bash inside `skill-lean-version/SKILL.md` (a new
  `doctor` mode alongside `check`/`upgrade`/`rollback`), not a new standalone script, consistent
  with how the existing three modes are built.
- Fetched the upstream Comparator README's exact six numbered assumptions, its exact
  what-a-pass-certifies wording, and its exact landrun/TCB sentence — all reproduced verbatim
  below so `comparator-guide.md` can cite them without paraphrase drift.
- `check-extension-docs.sh` Rule R requires the new `index-entries.json` entry's `line_count` to
  exactly equal `wc -l` of `comparator-guide.md` at commit time; Rule T requires `domain: project`,
  no `description`/`tags` keys, and `load_when` keys restricted to
  `agents`/`commands`/`task_types`/`always`.

## Context & Scope

Task 156 is the fourth of a four-task Comparator integration sequence (153-156, created together
per `ac4754a38`). Task 155 (already `[COMPLETED]`) built `lean-comparator-run.sh`, the clean-room
worktree runner, the verdict vocabulary, the `--compare` gate in
`lean-implementation-agent.md`'s Final Verification Stage, and the design record
`comparator-integration.md`. Task 156's own scope is narrower and purely
documentation/operator-tooling: a `/lean doctor`-style presence+version-match probe, and the
trust-model document that states plainly what a green Comparator result does and does not mean.
No proof work, no new gate strength decision, no changes to the already-advisory `--compare` gate.

`specs/state.json`'s `file_scope` for task 156 enumerates exactly nine files, none of which is a
new script under `scripts/`:

```
commands/lean.md
skills/skill-lean-version/SKILL.md
context/project/lean4/tools/comparator-guide.md   (new)
context/project/lean4/standards/proof-debt-policy.md
context/project/lean4/README.md
EXTENSION.md
README.md
index-entries.json
manifest.json
```

This is a strong design signal (file_scope is descriptive/anticipated, not filesystem-enforced —
see `state-management.md` — but nine files were pre-declared under this task and it tracks the
dispatch's own instructions closely), and matches (a)-(d) of the dispatch's WORK section exactly.

## Findings

### Codebase Patterns

**Binary resolution already has a reusable pattern.** `lean-comparator-run.sh` defines
`resolve_binary(override_var, path_name)`, which checks the named override env var first, falls
back to a bare `command -v` PATH lookup. The four names it uses are Comparator's own env vars,
carried through unchanged:

| Binary | Override var |
|---|---|
| `comparator` | `COMPARATOR_BIN` (this repo's own name — Comparator itself has none) |
| `landrun` | `COMPARATOR_LANDRUN` |
| `lean4export` | `COMPARATOR_LEAN4EXPORT` |
| `nanoda_bin` | `COMPARATOR_NANODA` |

The doctor mode should reuse these exact four names (dispatch: "reports which are present and
via which env var each may be overridden") rather than inventing new ones — an operator already
using `--compare` has these names in muscle memory.

**`commands/lean.md` / `skills/skill-lean-version/SKILL.md` structure.** Both files already
implement a three-mode dispatch (`check`/`upgrade`/`rollback`) as sequential inline bash blocks
inside one skill, with `SKILL.md` doing the real work and `commands/lean.md` being the
user-facing STEP-by-STEP mirror. A `doctor` mode is a natural fourth arm of the same
`case "$mode"` dispatch — no new skill, no new command, no new agent. `skill-lean-version`'s
`allowed-tools` (`Bash, Read, Write, Edit, AskUserQuestion`) already covers everything a doctor
probe needs (no new permission grant required).

**`proof-debt-policy.md`'s zero-debt gate is grep-only today**, exactly as the dispatch states:
sorry count, `^axiom ` grep, and (per `lean-implementation-agent.md`) a single-line
vacuous-definition grep plus an unsandboxed `lake build`. The policy file has no mention of
Comparator at all yet — the WORK item (c) update is a clean addition, not a rewrite, and must be
careful to state the greps remain the *operative* (enforced) gate while `--compare` is *advisory
only* (per `comparator-integration.md`'s already-binding decision, restated in this task's
dispatch).

**`context/project/lean4/README.md`** is an 18-line index with a "Key Files" bullet list; adding
one bullet for `tools/comparator-guide.md` (and, if useful, one line under a new "For Comparator
usage" sub-heading similar to "For Research"/"For Implementation") is the minimal-diff addition.

**`index-entries.json` schema (Rule T)**: every entry needs `path`, `domain` (`project`),
`subdomain` (`lean`), `summary`, `line_count`, and `keywords`; `load_when` may only use
`agents`/`commands`/`task_types`/`always`. Existing `tools/*.md` entries model
`load_when: {agents: [...], task_types: ["lean4"]}`. `comparator-guide.md` is documentation a
human operator and `lean-implementation-agent` (when `compare_flag` is set) would both want; the
existing convention supports `agents: ["lean-implementation-agent"]`, `task_types: ["lean4"]`.

**`check-extension-docs.sh` Rule R** (`check_line_count_accuracy`) fails the deploy on ANY
mismatch between a declared `line_count` and the file's actual `wc -l` at deploy time — including
a **missing** `line_count` key. The dispatch's own acceptance criterion ("A fresh deploy passes
check-extension-docs.sh with the new entries registered") is directly this rule. The safe
sequence is: write `comparator-guide.md` first, then run
`bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` (also run
automatically by `deploy-headless.sh` before every deploy) rather than hand-computing the line
count.

### The C3 version-match check: what actually works (new finding this session)

The dispatch is explicit that "a doctor that only reports presence and not version match will
pass on a setup that cannot work," and requires demonstrating (not merely asserting) a real
mismatch state. Two candidate techniques were evaluated and one is eliminated by direct evidence
gathered this session:

1. **`lean4export --version` / `--help`** — eliminated. Fetched upstream `leanprover/lean4export`
   directly: it documents only `lake env <path-to-lean4export-binary> <lean-file>+` invocation,
   with no version or help flag of any kind. There is no way to ask the binary what Lean version
   it was built against.

2. **Dynamic-link introspection (`ldd`) against an elan toolchain path** — eliminated for the
   realistic installation route. Comparator and `landrun` are now genuinely installed on this
   host (via the operator's home-manager/nix profile, matching `comparator-integration.md`'s own
   note that this landed mid-session). Running `ldd` against the real, currently-installed
   `comparator` binary (`/nix/store/9mfki6ycvs75172hn3hikyrz0is1plwn-comparator-0.1.0-2312244a/bin/comparator`)
   shows it links only against glibc/libc/libm/libpthread/libdl/librt — **no** reference to any
   `~/.elan/toolchains/.../lib/lean` path. A Lean-built binary packaged this way (statically
   linking the Lean runtime) carries no externally-inspectable toolchain fingerprint. Since
   `lean4export` is a similarly small, standalone Lean-built CLI, the same elimination almost
   certainly applies to it too, and nothing in this system should assume otherwise.

3. **Bounded directory walk-up for a sibling `lean-toolchain` file — the one technique that
   survives.** `lean4export` is a niche AIMO-adjacent tool, unlike `landrun` (confirmed in
   nixpkgs at 0.1.15); it is not evidently nixpkgs-packaged, so the realistic install path is
   `git clone leanprover/lean4export && lake build`, with the operator adding the resulting
   `<checkout>/.lake/build/bin/` (or a symlink to `.../lean4export`) to `PATH` or setting
   `COMPARATOR_LEAN4EXPORT` to it directly. In that layout, the checkout's own `lean-toolchain`
   file (confirmed live at `leanprover/lean4export/master/lean-toolchain` =
   `leanprover/lean4:v4.34.0-rc2` as of this session — not a hypothetical) sits a small, fixed
   number of directory levels above the binary. A doctor can `readlink -f` the resolved binary,
   then walk up a bounded number of parent directories (e.g. 5) looking for `lean-toolchain`,
   and diff its trimmed content against the target project's own `lean-toolchain`.

   This yields exactly the three states the acceptance criteria ask for, and all three are
   mechanically demonstrable with fixtures (no real `lean4export` binary required — the walk-up
   logic only needs *a* file at *a* resolvable path, real or stubbed):
   - **matched**: a stub binary placed under `<fixture>/.lake/build/bin/lean4export` with
     `<fixture>/lean-toolchain` containing the same string as the target project's
     `lean-toolchain`.
   - **missing**: `COMPARATOR_LEAN4EXPORT` unset and no `lean4export` on `PATH` → the existing
     presence check alone reports this; no walk-up is attempted.
   - **present but mismatched**: the same stub layout as above, but `<fixture>/lean-toolchain`
     content differs from the target project's `lean-toolchain`. This is the state the dispatch
     says "must be demonstrated, not assumed" — it is fully constructible without any real
     upstream binaries.
   - A necessary fourth outcome that is not one of the three named states but must not be
     conflated with "matched": **no `lean-toolchain` discoverable within the walk-up bound**
     (e.g. `lean4export` resolved to a bare nix-store path, or a hand-copied binary with no
     adjacent checkout). The doctor must report this as an explicit "version unknown — cannot
     verify; confirm manually that lean4export at `<path>` was built against
     `<target-toolchain>`" finding — never silently treated as a pass. This is what keeps the
     check honest given finding (1)/(2) above: absence of a discoverable `lean-toolchain` is
     itself informative, not an error to suppress.

**Recommendation**: implement the version-match arm of the doctor exactly this way; do not
attempt binary introspection (`ldd`, `strings`, `file`) as a primary mechanism — evidence
gathered this session shows it does not work against the binaries the operator will actually run.

### External Resources — Comparator's own six assumptions, verbatim (for `comparator-guide.md`)

Fetched directly from `https://raw.githubusercontent.com/leanprover/comparator/master/README.md`
this session (previously only assumptions 2 and "landrun works correctly" were paraphrased in
this repo's `comparator-integration.md`; the full six were not yet transcribed anywhere in this
extension):

1. **Trusted imports**: "The transitive closure of imports of `Challenge.lean` as well as
   `lakefile.toml`/`lakefile.lean` are controlled by you or trustworthy."
2. **No prior compilation**: "You have not previously tried to compile the `Solution` file or any
   other potentially adversarial files (as that might compromise your `Challenge` file to make it
   seem like you are looking for a different proof than you actually are)"
3. **Binaries available**: "You have the `landrun` and `lean4export` binary in `PATH`"
4. **Landrun correctness**: "`landrun` works correctly on your system and `Solution.lean` does
   not exploit any bugs in `landrun` that allow a process to escape its sandbox"
5. **Kernel correctness**: "The Lean kernel is correct (with `external_kernels` this can be
   reduced to 'At least one of the Lean kernel or the `external_kernels` is correct')"
6. **Privilege level**: "You are not running this under a privileged user"

What a pass certifies, verbatim: theorems "Prove the same statement as provided in `Challenge`",
"Use no more axioms than listed in `permitted_axioms`", "Be accepted by the Lean kernel."

Definition-hole caveat, verbatim: "all definition hole solutions **must** always be checked with
an additional (potentially human) verifier" — with the RiemannHypothesis gaming example already
recorded in this repo's `comparator-integration.md`.

TCB statement, verbatim: "The Trusted Code Base of Landrun naturally includes the operating
system and hardware it is running on, plus its sandboxing mechanism."

Version-coupling statement, verbatim (confirms C3 exactly as the dispatch states it): "lean4export,
at a version that is compatible with whatever Lean version your project is targeting, present in
`PATH`."

Task 156's dispatch names assumptions 2 and 4 as the two "live concerns here" — this matches: 2
(no-prior-compile) is violated by the implementation agent's own continuous-compile workflow
(mitigated only by the clean-room worktree design in `comparator-integration.md`), and 4 (landrun
correctness) is a live host-dependent claim this system cannot independently verify.

### Recommendations

1. **Doctor mode location**: add `doctor` as a fourth mode in `skill-lean-version/SKILL.md`'s
   `case "$mode"` dispatch and mirror it in `commands/lean.md` as `STEP 3D`. No new script, no
   new skill, no manifest routing change (task type / routing tables are untouched — this is a
   command-mode addition only).
2. **Doctor output**: for each of `comparator`, `landrun`, `lean4export`, and optionally
   `nanoda_bin`: presence (yes/no + resolved path), which override env var was checked, and (for
   `lean4export` only) the version-match verdict (`matched` / `mismatched` / `unknown — cannot
   verify` / not applicable because `lean4export` itself is absent). Use the exact four env var
   names from `lean-comparator-run.sh`.
3. **Version-match mechanism**: bounded (5-level) directory walk-up from the resolved
   `lean4export` path for a sibling `lean-toolchain` file, diffed against the target project's
   own `lean-toolchain`. Never treat "no file found" as a pass.
4. **`comparator-guide.md` structure**: lead with what a green result certifies (the three
   upstream-quoted guarantees), then an explicit "What this does NOT certify" section (Challenge
   correctness, definition holes + RiemannHypothesis example, the six assumptions with 2 and 4
   flagged live), then the TCB statement, then a short pointer to `comparator-integration.md` for
   implementation detail (avoid duplicating the clean-room/verdict-vocabulary content already
   there — this is the *trust-model* document, that one is the *design record*).
5. **`proof-debt-policy.md` update**: add a subsection (e.g. under "Completion Gates") stating
   Comparator exists, is advisory-only via `--compare`, and that the three greps remain the
   *operative* zero-debt gate today — phrase it so a reader cannot conclude the hard gate already
   exists.
6. **Extension surface**: after writing `comparator-guide.md`, run
   `generate-context-line-counts.sh --write` before hand-editing `line_count` in
   `index-entries.json`; add the `doctor` mode to `EXTENSION.md`'s and `README.md`'s command
   tables; `manifest.json` needs no new `scripts`/`skills`/`commands` entries under this
   recommendation (no new files are introduced) but should still be checked against
   `check-extension-docs.sh` for any other schema drift once `comparator-guide.md` is registered.
7. **No task-number references**: none of `commands/lean.md`, `SKILL.md`, `comparator-guide.md`,
   `proof-debt-policy.md`, `README.md`/`EXTENSION.md`, `manifest.json`, or `index-entries.json`
   may mention task numbers — all live outside `specs/**`, consistent with
   `no-task-references-in-deliverables.md`. `comparator-integration.md` already models the
   correct style (cites files and upstream URLs, never a task number).

## Decisions

- No new script file for the doctor mode — implement inline in `skill-lean-version/SKILL.md`,
  consistent with `file_scope` and the existing check/upgrade/rollback pattern.
- The C3 version-match check uses a bounded directory walk-up for a sibling `lean-toolchain`
  file, not binary introspection — binary introspection was tested against real binaries this
  session and does not work.
- `comparator-guide.md` is the trust-model document; `comparator-integration.md` remains the
  design record. Keep the two non-overlapping (cross-reference rather than duplicate).

## Risks & Mitigations

- **Risk**: hand-typing `line_count` in `index-entries.json` drifts from the file the moment
  either is edited again. **Mitigation**: always run
  `generate-context-line-counts.sh --write` (or let `deploy-headless.sh` do it) as the last step
  before considering the extension-surface update done.
- **Risk**: the "unknown — cannot verify" version-match outcome could be miscoded as a pass by a
  future maintainer skimming the doctor output. **Mitigation**: comparator-guide.md and the
  doctor's own output copy should use distinct, unmistakable wording (never "OK"/"pass" for the
  unknown case) — recommend the literal string `UNKNOWN (cannot verify)` as a doctor state label.
- **Risk**: overclaiming in `comparator-guide.md` (stating Comparator certifies more than the
  three upstream-quoted guarantees). **Mitigation**: quote upstream verbatim (as reproduced
  above) rather than paraphrasing, and keep the "what this does NOT certify" section as the
  document's structural centerpiece per the dispatch's own instruction that this is "the
  important half of the task."

## Context Extension Recommendations

- **Topic**: Comparator trust model (operator-facing, not implementation-facing).
- **Gap**: `context/project/lean4/tools/` has no file addressing what a Comparator result means
  to a human reader; `comparator-integration.md` is a design record for maintainers extending the
  runner, not a trust-model explainer.
- **Recommendation**: this task's own deliverable (b), `tools/comparator-guide.md`, closes this
  gap — no further extension recommended beyond this task's scope.

## Appendix

### Search queries / fetches used

- `WebFetch https://raw.githubusercontent.com/leanprover/comparator/master/README.md` — six
  assumptions, certification wording, TCB statement, version-coupling statement (all quoted
  above).
- `WebFetch https://raw.githubusercontent.com/leanprover/lean4export/master/lean-toolchain` —
  confirmed content `leanprover/lean4:v4.34.0-rc2`.
- `WebFetch https://github.com/leanprover/lean4export` — confirmed no `--version`/`--help` flag
  exists.
- Live host commands: `which comparator landrun lean4export nanoda_bin lean lake elan`,
  `ldd $(which comparator)`, `readlink -f $(which comparator)`, `ls ~/.elan/toolchains`.

### Key files read

- `agent-system/extensions/lean/scripts/lean-comparator-run.sh` (binary resolution, env vars,
  guard nesting)
- `agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md` (design
  record, gate-strength decision, provisioning status)
- `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md` (C1
  resolution, not directly in scope but adjacent)
- `agent-system/extensions/lean/context/project/lean4/standards/proof-debt-policy.md`
- `agent-system/extensions/lean/commands/lean.md`, `skills/skill-lean-version/SKILL.md`
- `agent-system/extensions/lean/context/project/lean4/README.md`
- `agent-system/extensions/lean/EXTENSION.md`, `README.md`, `manifest.json`, `index-entries.json`
- `agent-system/extensions/core/scripts/check-extension-docs.sh` (Rule R, Rule T)
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` (existing `--compare` gate,
  line ~299)
