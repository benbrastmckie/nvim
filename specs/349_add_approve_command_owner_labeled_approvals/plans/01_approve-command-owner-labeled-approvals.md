# Implementation Plan: Task #349

- **Task**: 349 - Add an /approve command to the agent system so a specification approval is given by answering one interactive question instead of a terminal round-trip
- **Status**: [IMPLEMENTING]
- **Effort**: 16.5 hours
- **Dependencies**: None outstanding. The cross-repository mechanism dependency (`owner_labeled_agent_assisted_approvals`, cited by slug) is SATISFIED; the in-repository investigation `askuserquestion_unreachable_in_subagents` is SATISFIED and its finding is a settled constraint, not an open question.
- **Research Inputs**: `specs/349_add_approve_command_owner_labeled_approvals/reports/01_approve-command-owner-labeled-approvals.md`
- **Artifacts**: plans/01_approve-command-owner-labeled-approvals.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build a new, opt-in `approvals` extension in the agent-system source store whose single command
`/approve <component>` drives a consumer repository's `components/<component>/approve.sh` through
the owner-labeled confirmation channel: run `--review`, persist the review at a predictable
tracked path, classify its diffs mechanically, present an essentials-only summary with a
two-tier confidence label per item, ask the owner through `AskUserQuestion` in the root session,
and record with the owner as approver and the command as `assisted_by`. The whole flow runs
inside a direct-execution skill because `AskUserQuestion` is categorically withheld from every
dispatched subagent on this harness — a settled measurement, not an assumption to re-test. Done
means: the placement and design rulings are recorded as durable files, three refusal cases each
have an executable test, a dry run shows the full flow without recording, and no code path
exists by which the command records itself as the approver.

### Research Integration

The research report settled four of the five rulings this task owes, each on cited evidence
rather than preference, and this plan adopts them as decided:

- **Placement**: a new extension, not `books` (whose own charter disclaims component
  certificates and scopes itself to the `book.toml`/`book.cert.json` metadata layer) and not
  `core` (which loads in every deployment, including repositories with no `components/`
  directory at all). Name: `approvals`, after the mechanism's own vocabulary
  (`approvals.yaml`, `approve.sh`, `check-approvals.sh`), avoiding "certify" which `books`
  already owns for a different artifact.
- **Confidence vocabulary**: exactly two tiers, `MEASURED` / `INFERENCE`, derived from and
  citing the `books/convention/09-trust-unit-is-the-export.md` (Decision 9) and
  `books/lean/BookCert/Depends.lean` precedent in the consumer repository. The task
  description's citation path `docs/book-convention.md` is stale; the convention is now split
  into `books/convention/01..19-*.md`.
- **Artifact naming**: compose the two schemes already in this repository rather than invent a
  third — the no-task date-keyed review identity (`review-{DATE}[-{suffix}].md`) and the
  zero-padded `MM_` instance-sequence convention.
- **Interaction design**: a bulk triage gate with option-availability gating, then a per-item
  step-through, reconciling the four-option cap with the step-through walk and its two escapes.

Re-derived at plan-authoring time rather than carried: `verify-deploy.sh` aggregates 21 gates
(`gate_selected 1..21`); `--only-gate 3,4` is doc-lint plus task-reference lint; the consumer
repository's `specs/.gitignore` managed block contains only `**/`-prefixed dotfile/dot-directory
patterns plus `/tmp/`, none of which matches `specs/certificates/`; `components/` in the
consumer repository holds four components and only `framed_channel` has an `approve.sh`;
`approve.sh`'s `--via-prompt` path greps `^Question:` and `^Answer:` out of `## Notes` and
refuses when either is absent; `check_routing_block` fails any extension declaring skills or
agents without a `routing_agents` block unless it declares `routing_exempt: true`
(`literature` and `slidev` are the precedents).

### Prior Plan Reference

No prior plan. This is the first plan for this task.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, and no roadmap context was loaded. No roadmap
phases are included.

## Goals & Non-Goals

**Goals**:
- A new `approvals` extension in the source store, auto-discovered by the picker, loadable only
  where it is useful.
- `/approve <component> [component-flags] [--task N] [--dry-run]` implemented as a
  direct-execution skill that never delegates any part of its prompting flow.
- The owner recorded as approver, the command recorded as `assisted_by`, with the question and
  answer verbatim in the review file's `## Notes`.
- Five rulings recorded as durable, citable files: placement, artifact naming (including the
  explicit no-task key), tracked-directory policy, confidence vocabulary, and one coherent
  interaction design covering both the option cap and the step-through walk.
- Three refusal cases with executable tests, plus a structural test that no self-approval path
  exists.

**Non-Goals**:
- Changing `approve.sh` or `check-approvals.sh` in the consumer repository. Their contract is
  consumed verbatim; the review file's location is this command's `--out` argument and nothing
  more is asked of them.
- Any approval-policy question about which specifications deserve scrutiny.
- Re-measuring whether `AskUserQuestion` is reachable from a dispatched subagent. It is not;
  build against the constraint.
- Generalizing `--core-only`/`--aeneas` into a universal flag vocabulary. They are one
  component's own bridge-scope flags and are forwarded verbatim, not interpreted.
- Changing the generated `specs/.gitignore` managed block's pattern list (see Risks).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing `runtime_specs_ignore_block()`'s generated output to add a `specs/certificates/` negation cascades into a byte-identical pinning assertion against the markdown standards block and leaves every already-synced consumer's `.gitignore` drifted | H | M | Do NOT touch the generated block. Nothing in it matches `specs/certificates/` (re-derived above), so the ruling is a durable record plus a mechanical guard: a header comment in the lib and a test case asserting no generated pattern matches a `specs/certificates/**` path |
| A new agent, command, or context file that is never added to its manifest's `provides.*` array silently never deploys, with no check anywhere in the lifecycle catching it | H | M | Phase 8 runs `sync-manifest-scripts.sh --check` for scripts and hand-verifies every `provides.agents`/`commands`/`context`/`skills` entry against disk; the structural test asserts each authored file appears in the manifest |
| A future component's `approve.sh` diverges from the review-file grammar the classifier parses (`## Evidence: <item>`, the `diff_since` sentinels, the `## Decisions` fenced block) | M | M | The classifier fails loud on an unrecognized `## Decisions`/`## Notes`/`## Evidence:` shape rather than guessing; it never treats an unparseable item as mechanical |
| The "mechanical-only" bulk class quietly widens to admit judgment calls, laundering an INFERENCE as a MEASURED fact | H | M | The MEASURED bar is narrow by construction: an empty diff against the commit that recorded the last approval, or a diff with zero non-boilerplate added/removed lines under an enumerated closed list. Anything unrecognized defaults to the step-through, never to the bulk gate |
| Refusal case (c) is bypassed by a caller that does not set whatever flag the guard checks | H | M | Two independent predicates, neither satisfiable by the other: the guard refuses without an answer file carrying both a non-empty `Question:` and `Answer:` line, and the skill body independently stops when its own delegation context carries `orchestrator_mode: true`. `approve.sh`'s own `--via-prompt` Notes check is a third, external backstop |
| `/approve` is authored in this repository but exercised only in a consumer repository, so no end-to-end run is available here | M | H | Tests are structural and fixture-driven (the model already in `test-askuserquestion-rehome.sh`, which documents in its own header what a shell fixture can and cannot prove). The plan does not claim an end-to-end verification it cannot perform; the dry-run path is the live check the owner runs in the consumer repository |
| Concurrent sibling dispatch on this shared working tree touches the same files | M | M | Per the dispatch territory block: re-read before editing, stage only this task's own hunks with an explicit file list, never a directory or glob add, never `git-snapshot.sh` in reverting mode |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |
| 7 | 7 | 6 |
| 8 | 8 | 7 |
| 9 | 9 | 8 |

Phases within the same wave can execute in parallel. This plan is a strict sequential chain:
each phase's artifact is the input the next one is written against (the rulings decide the
paths the scripts compute, the scripts decide the interfaces the skill calls, and the skill
decides the surfaces the tests assert).

---

### Phase 1: Record the Placement Ruling and Create the Extension Skeleton [COMPLETED]

**Goal**: The placement ruling exists as a durable, citable file with its reason, and the
`approvals` extension is a well-formed, auto-discoverable extension skeleton before any command,
skill, or script file is authored.

**Tasks**:
- [x] Create `agent-system/extensions/approvals/` with `commands/`, `skills/skill-approve/`,
      `scripts/tests/`, and `context/project/approvals/{standards,patterns}/`. *(completed)*
- [x] Write `manifest.json`: `name: approvals`, `version: 1.0.0`, `dependencies: ["core"]`,
      `routing_exempt: true` (it declares a skill and no routing — modeled on `literature`),
      `provides.commands: ["approve.md"]`, `provides.skills: ["skill-approve"]`,
      `provides.context: ["project/approvals"]`, `provides.agents: []`, `provides.scripts: []`
      (populated in later phases), `merge_targets.claudemd` -> `EXTENSION.md` with
      `section_id: extension_approvals`, `merge_targets.index` -> `index-entries.json`. Omit
      `task_type` (no routing) and omit `mcp_servers` (inert).
- [x] Write `EXTENSION.md` (hard limit 60 lines, enforced by doc-lint Rule U): what `/approve`
      is, the one command, the direct-execution skill, and the pointers to the rulings. *(completed)*
- [x] Write `README.md` from `.claude/templates/extension-readme-template.md`, simple-extension
      shape. Include the **placement ruling with its reason**: `books` disclaims component
      certificates and owns the `book.toml`/`book.cert.json` metadata layer, whose certificate
      boundary is a different artifact from the component release certificate this command
      drives; `core` loads in every deployment including repositories with no `components/`
      directory, so a command meaningful only in a repository shaped like the verification
      consumer does not belong there. Cite the two `books` files and the loading asymmetry by
      filename, never by task number. *(completed)*
- [x] Write `context/project/approvals/README.md`: the context index and loading strategy. *(completed)*
- [x] Write `index-entries.json` with one entry per context file authored so far, each carrying
      `path`, `domain`, `subdomain`, `topics`, `keywords`, `summary`, `line_count`, `load_when`
      (`commands: ["/approve"]`). Generate `line_count` with
      `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`
      rather than by hand. *(completed: ran via deployed .claude/scripts/ copy per the script's own guard; line_count=23)*
- [x] Add an `approvals` row to `agent-system/extensions/README.md`'s Available Extensions
      table (task type `-`, since it is routing-exempt). *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: Markdown and JSON only, with no executable surface, so the covering
check is `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`
plus `bash .claude/scripts/verify-deploy.sh --only-gate 3,4`; `suite_selection_select` returns
`__FULL_SWEEP__` for these paths, so no shell suite covers them and none is claimed.

**Scope Hypothesis**: This phase asserts six authored files and one edited file. Confirm at
implementation time with `find agent-system/extensions/approvals -type f | sort` and a
`git status --short` review before staging; the count is a hypothesis about this phase's own
output, not a measured fact.

**Files to modify**:
- `agent-system/extensions/approvals/manifest.json` - new, routing-exempt manifest
- `agent-system/extensions/approvals/EXTENSION.md` - new, <= 60 lines
- `agent-system/extensions/approvals/README.md` - new, carries the placement ruling and reason
- `agent-system/extensions/approvals/index-entries.json` - new, index entries with real line counts
- `agent-system/extensions/approvals/context/project/approvals/README.md` - new, context index
- `agent-system/extensions/README.md` - add the `approvals` row

**Verification**:
- `jq empty` passes on `manifest.json` and `index-entries.json`.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports
  no FAIL for `approvals` (Rules A/H/Q/R/T/U and the README-vs-manifest check all clean).
- `wc -l agent-system/extensions/approvals/EXTENSION.md` is <= 60.
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` exits 0.
- `grep -n "books\|core" agent-system/extensions/approvals/README.md` shows the placement reason
  present and citing files, with no task-number reference anywhere in the file.

---

### Phase 2: Record the Artifact-Path, No-Task-Key, and Tracked-Directory Rulings [COMPLETED]

**Goal**: The persisted-artifact convention is a decided, written ruling — including the no-task
key stated explicitly rather than falling out of the task-keyed case — and the
deliberately-tracked status of `specs/certificates/` is recorded with the reason it needs no
pattern change today.

**Tasks**:
- [x] Write `context/project/approvals/standards/approval-artifact-convention.md` ruling: *(completed)*
      - The review is a persisted artifact under `specs/certificates/<component>/` in the
        **consumer** repository (the repository being approved), never under `${TMPDIR}`.
      - Task-keyed form: `task-{N}-{II}.md`, `{N}` unpadded per the placeholder table in
        `artifact-formats.md`, `{II}` a 2-digit zero-padded instance counter.
      - **No-task key, stated explicitly as its own form**: `adhoc-{DATE}-{II}.md`
        (`{DATE}` = `YYYYMMDD`), mirroring the no-task date-keyed review identity already in
        use in this repository. A taskless cycle is never expressed by an empty segment, a
        literal `000`, or a borrowed task number.
      - `{II}` rule: one more than the count of existing files matching the same key stem in
        that component directory, zero-padded to two digits. Two taskless cycles on the same
        date therefore get `01` and `02` and cannot collide; a second cycle for the same task
        cannot overwrite the first.
      - Two sidecars share the stem: `<stem>.classification.json` (the classifier's output) and
        `<stem>.presented.json` (exactly what was shown to the owner). Both are durable
        provenance in the same tracked directory.
      - The task number is taken from an explicit `--task N` only. The command never infers or
        guesses one; absent the flag it uses the no-task key.
      - **Tracked-directory ruling**: `specs/certificates/` is a durable, consumer-repo-owned,
        always-tracked directory and is deliberately NOT a member of the ephemeral
        orchestrator-runtime-file class. No pattern in the generated managed block matches it
        today (re-derived: the block holds only `**/`-prefixed dotfile/dot-directory patterns
        plus a root-scoped `/tmp/`), so the requirement is a durable record against future
        drift, not a functional fix. The generated block's pattern list MUST NOT be edited to
        add a negation: its output is pinned byte-for-byte to a fenced block in
        `orchestrator-runtime-files.md` and is rendered into every consumer's
        `specs/.gitignore`, so a cosmetic addition there cascades. The mechanical guard is the
        test case in Phase 7 instead.
- [x] Add one sentence to the **file header comment** of *(completed)*
      `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` naming
      `specs/certificates/` alongside the existing durable-provenance exclusions
      (`.orchestrator-handoff.json`, the bare `.return-meta.json`), explicitly in the header
      prose and explicitly NOT in `runtime_specs_ignore_block()`'s emitted lines.
- [x] Add the new context file to `index-entries.json` and re-run
      `generate-context-line-counts.sh --write`. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: One new markdown ruling plus a comment-only edit to a sourced shell lib
whose emitted output is untouched, so the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-runtime-file-tracking.sh`
(which pins that lib's generated block) together with
`bash .claude/scripts/verify-deploy.sh --only-gate 3,4`.

**Scope Hypothesis**: This phase asserts that no pattern in the generated managed block matches
`specs/certificates/`. Confirm at implementation time by seeding a scratch repository with
`runtime_specs_ignore_block()`'s output and running `git check-ignore -v specs/certificates/x.md`
(expected: no match, exit 1) before writing the ruling as fact.

**Files to modify**:
- `agent-system/extensions/approvals/context/project/approvals/standards/approval-artifact-convention.md` - new, the naming, no-task-key, sidecar, and tracked-directory rulings
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` - header comment only, naming `specs/certificates/` as durable and out of class
- `agent-system/extensions/approvals/index-entries.json` - add the new context entry

**Verification**:
- `git diff -- agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` touches only
  comment lines; `runtime_specs_ignore_block`'s emitted lines are byte-identical to before.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-runtime-file-tracking.sh`
  exits 0 (the pinning assertion still holds).
- The ruling file contains both key forms verbatim and an explicit sentence naming the no-task
  key, confirmed by grep for `adhoc-` and `task-`.
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` exits 0.

---

### Phase 3: Record the Confidence Vocabulary and the Interaction Design Ruling [COMPLETED]

**Goal**: The owner-facing summary contract and one coherent interaction design exist as written
rulings that the option cap and the step-through walk both satisfy, with no contradiction
between them.

**Tasks**:
- [x] Write `context/project/approvals/standards/confidence-vocabulary.md`: *(completed)*
      - Exactly two values, `MEASURED` and `INFERENCE`. No third tier, no numeric or graded
        scale.
      - `MEASURED`: the claim is the direct output of a mechanical check the command itself ran
        — the diff against the commit that recorded the last approval is literally empty, or
        the declaration-name delta computed from the diff's own added/removed header lines.
      - `INFERENCE`: the agent read a hunk and judged it non-semantic without an independent
        mechanical check, or there is no diff evidence at all.
      - Cite the precedent by file and decision name: `books/convention/09-trust-unit-is-the-export.md`
        (Decision 9, "the completeness direction is marked INFERENCE for cost on the real
        composite; the cone walk is measured") and `books/lean/BookCert/Depends.lean`, both in
        the verification consumer repository. State explicitly that this vocabulary is derived
        from that precedent rather than parallel to it, and note that the convention is split
        into `books/convention/01..19-*.md` (the older single-file citation path is stale).
      - **Summary contract**: per item the owner sees the item id, its class, the measured
        declaration delta by name, a recommendation, a confidence value, and the artifact path —
        and nothing else. The full classified diff is never shown inline; it is at the artifact
        path. Every discrepancy is named explicitly, never averaged into a verdict: a rollup
        over several items takes `min()` over confidence, never a mean, and any item whose
        declaration set changed or whose record disagrees with the tree is listed by name in a
        Discrepancies block at the head of the question.
- [x] Write `context/project/approvals/patterns/approve-interaction-design.md` as ONE ruling *(completed)*
      covering both the option cap and the step-through walk:
      - **Hard rule**: at most four options per question, and items are never packed into
        options. Item count changes the number of questions, never the number of options.
      - **Stage A, bulk triage gate**: one question, three options — `Approve all N
        mechanical-only items` / `Step through every item` / `Decline all`. The bulk option is
        **offered only when** the classifier mechanically cleared at least one item
        (option-availability gating: an unsafe option does not exist as a choice rather than
        being offered and then filtered). Its correctness rests on a MEASURED fact; an item the
        classifier cannot mechanically clear is excluded from the bulk count and falls through
        to Stage B.
      - **Stage B, step-through walk**: one question per remaining item, exactly four options —
        `Approve` / `Decline` / `Discuss this item` / `Decide later`.
      - **Escape 1 (conversational)** is `Discuss this item`: the skill leaves the structured
        prompt, discusses that item's diff, classification, recommendation, and confidence in
        ordinary prose in the root session, then re-issues the identical question when the owner
        signals they are ready. The item is undecided until an `Approve` or `Decline` is given.
        This works only because the skill runs in the root session.
      - **Escape 2 (open the files)** consumes no option at all: it is a property of the
        persisted, predictable, tracked artifact path, not of any menu. The skill prints the
        artifact and sidecar paths before Stage A and carries the path in every per-item
        question, so the owner can open them unmediated at any point, whether or not a question
        is pending.
      - **Decide later** leaves the item's Decisions line at `no` and names it as undecided in
        the final report.
      - **Rejected alternative, recorded with its reason**: batching by module family. A family
        batch re-introduces exactly the averaging the summary contract forbids — one decision
        standing for several items whose discrepancies differ — and buys nothing, because the
        option cap constrains options per question, not questions per run.
- [x] Add both context files to `index-entries.json`; re-run
      `generate-context-line-counts.sh --write`. *(completed)*

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: Two new pure-guidance markdown files with no executable surface, for
which `suite_selection_select` returns `__FULL_SWEEP__` and no shell suite exists, so the honest
covering check is `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` plus the diff
read-through the `local` row prescribes.

**Files to modify**:
- `agent-system/extensions/approvals/context/project/approvals/standards/confidence-vocabulary.md` - new, two-tier vocabulary and the summary contract
- `agent-system/extensions/approvals/context/project/approvals/patterns/approve-interaction-design.md` - new, one ruling covering the option cap, the step-through walk, and both escapes
- `agent-system/extensions/approvals/index-entries.json` - add the two new context entries

**Verification**:
- `grep -c "MEASURED\|INFERENCE" confidence-vocabulary.md` is non-zero and the file contains no
  third tier name and no numeric scale.
- The citation strings `09-trust-unit-is-the-export.md` and `BookCert/Depends.lean` both appear.
- `approve-interaction-design.md` states the four-option cap, both stages, both escapes, and the
  rejected family-batching alternative; a read-through confirms Stage A uses three options and
  Stage B exactly four, with no option reserved for Escape 2.
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` exits 0.

---

### Phase 4: Path and Key Resolver (`approve-paths.sh`) [COMPLETED]

**Goal**: A testable script that resolves the component and computes the keyed artifact path per
the Phase 2 ruling, including the no-task case and non-colliding instance numbering.

**Tasks**:
- [x] Write `scripts/approve-paths.sh` with `set -uo pipefail` and the repository's test-fixture *(completed)*
      conventions, exposing:
      - `--component NAME`: resolve `components/NAME/approve.sh` relative to
        `git rev-parse --show-toplevel`; exit non-zero with a named message when the directory
        or the script is absent (this is the clear refusal the generalization requires).
      - `--task N` (optional) and `--date YYYYMMDD` (optional, defaults to today, injectable for
        tests): emit the stem — `task-{N}-{II}` when `--task` is given, `adhoc-{DATE}-{II}`
        otherwise.
      - `--instance-of STEM`: compute `{II}` as one more than the count of existing files
        matching that stem in `specs/certificates/<component>/`, zero-padded to two digits;
        refuse rather than wrap past `99`.
      - `--emit-paths`: print the review path, the classification sidecar path, and the
        presented sidecar path, one per line, and create the component directory with
        `mkdir -p`.
      - Refuse an explicit caller-supplied `--out`: the review location is this command's
        business, never the user's.
- [x] `chmod +x` the script and add it to `provides.scripts` via
      `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write`. *(completed: ran via deployed .claude/scripts/ copy)*

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: One new self-contained shell script with no caller yet, covered by its
own suite run directly —
`bash agent-system/extensions/approvals/scripts/tests/test-approve-paths.sh` is authored in
Phase 7, so the in-phase check is `bash -n` plus `shellcheck` plus the hand-run scenario matrix
named below.

**Files to modify**:
- `agent-system/extensions/approvals/scripts/approve-paths.sh` - new, component resolution and keyed path computation
- `agent-system/extensions/approvals/manifest.json` - `provides.scripts` entry (via sync-manifest-scripts.sh)

**Verification**:
- `bash -n` clean; `shellcheck` reports no error-level finding.
- Hand-run matrix in a scratch directory: a missing component refuses with a named message; a
  present component with `--task 7` yields `task-7-01`, and a second call after creating that
  file yields `task-7-02`; with no `--task` yields `adhoc-{today}-01`, and a second call yields
  `adhoc-{today}-02`; a caller-supplied `--out` is refused.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` reports no
  undeclared script.

---

### Phase 5: Diff Classifier (`approve-classify.sh`) [NOT STARTED]

**Goal**: A testable script that turns a generated review file into a classification JSON
carrying, per item, the evidence kind, the measured declaration delta, the class, the
recommendation, and the confidence value.

**Tasks**:
- [ ] Write `scripts/approve-classify.sh` reading a review file and emitting JSON on stdout:
      one record per item found in the `## Decisions` fenced block (`no  selection ...` and
      `no  spec  MODULE ...` lines), joined to its `## Evidence: <item>` section.
- [ ] Per item, record the evidence kind from the `diff_since` sentinel actually present:
      `identical` (`(no diff is available since commit ...)` — the reviewed files are
      byte-identical to the commit that recorded the last approval), `diff` (a fenced `diff`
      block), `never-approved` (`(never approved: review the full text)`), or
      `uncommitted-approval` (`(the last approval is not committed; ...)`).
- [ ] Compute the **declaration delta** mechanically from the diff's own added and removed
      lines: declaration-header lines (`theorem`, `lemma`, `def`, `abbrev`, `axiom`,
      `structure`, `instance`, `class`, `inductive`, `opaque`, `example`, and the
      `noncomputable`/`private`/`protected` prefixed forms) yield `decl_added`,
      `decl_removed`, and `decl_restated` (same name on both sides with a changed statement) —
      the names, not a count alone. This is the "was a claim added, removed, or restated" check
      at declaration level, and it is MEASURED.
- [ ] Classify: `mechanical` only when the evidence kind is `identical`, or when every added and
      removed line falls inside a closed, enumerated boilerplate list (blank, line comment,
      block-comment interior, licence header, module docstring, attribute-only line) AND the
      declaration delta is empty. Everything else is `declaration-level`; an item with no diff
      evidence at all (`never-approved`, `uncommitted-approval`) is `needs-full-text`. Anything
      unrecognized classifies as `declaration-level`, never as `mechanical`.
- [ ] Attach the recommendation (`approve` / `decline` / `read-full-text`) and the confidence
      (`MEASURED` for an `identical` evidence kind or a declaration delta read off the diff;
      `INFERENCE` for a boilerplate judgment or an absent diff), per the Phase 3 vocabulary.
- [ ] Fail loud, with the offending heading named, on an unrecognized `## Decisions`,
      `## Notes`, or `## Evidence:` shape rather than guessing or treating the item as
      mechanical.
- [ ] `chmod +x`; re-run `sync-manifest-scripts.sh --write`.

**Timing**: 2 hours

**Depends on**: 4

**Verification Tier**: local

**Tier Justification**: One new self-contained shell script whose only consumers are authored
later, covered by `bash -n`, `shellcheck`, and a hand-run against fixture review files; its
regression suite (`test-approve-classify.sh`) lands in Phase 7 and is the durable covering check
from then on.

**Scope Hypothesis**: This phase asserts that the four `diff_since` sentinel strings above are
the complete set the generating script emits. Confirm at implementation time by reading
`diff_since` in the consumer repository's `components/framed_channel/approve.sh` and enumerating
its branches before relying on the list; treat any fifth branch as a loud-fail case.

**Files to modify**:
- `agent-system/extensions/approvals/scripts/approve-classify.sh` - new, review-file parser and classifier
- `agent-system/extensions/approvals/manifest.json` - `provides.scripts` entry

**Verification**:
- `bash -n` clean; `shellcheck` reports no error-level finding.
- Hand-run against four hand-built fixture review files (one per evidence kind): JSON parses
  under `jq empty`; the `identical` fixture classifies `mechanical`/`MEASURED`; a fixture whose
  diff adds a `theorem` line reports that name in `decl_added` and classifies
  `declaration-level`; a comment-only diff classifies `mechanical`/`INFERENCE`; a malformed
  `## Decisions` block exits non-zero with the heading named.
- `sync-manifest-scripts.sh --check` clean.

---

### Phase 6: Refusal Guard (`approve-guard.sh`) [NOT STARTED]

**Goal**: Every refusal case the command owes is a named, non-zero-exiting, independently
testable predicate, and no predicate is satisfiable by another's value.

**Tasks**:
- [ ] Write `scripts/approve-guard.sh` with four independent subcommands, each refusing with its
      own named message and a non-zero exit:
      - `--check-freshness --classification FILE`: compare the review-time tree state captured
        in the classification sidecar (the component `HEAD` and each item's recorded digest)
        against the current tree; refuse when anything moved. This is this command's own named
        **stale-review** refusal, in front of the record step; it does not re-implement or
        reinterpret the generating script's own digest re-check, which remains the external
        backstop.
      - `--check-surfaced --classification FILE --presented FILE`: refuse when any item whose
        class is `declaration-level` or whose declaration delta is non-empty is absent from the
        presented sidecar's named discrepancy list. This is the **unsurfaced declaration-level
        change** refusal, and it runs before the record step, not after.
      - `--check-human --answer-file FILE`: refuse unless the file carries both a non-empty
        `Question:` line and a non-empty `Answer:` line that the skill wrote from an actual
        answer. This is the **no human attached** refusal; it is satisfiable only by a real
        answer, never by a flag, an environment variable, or an assumption.
      - `--check-labels --approver S --assisted-by S`: refuse when the approver string ends in
        `(agent)`, or when the assisted-by string does not. Two independent predicates, matching
        the external checker's own precedent of independent predicates for independent facts.
- [ ] State in the script header that a non-zero exit from the component's own `--record` is
      propagated verbatim by the caller and never retried through a different channel.
- [ ] `chmod +x`; re-run `sync-manifest-scripts.sh --write`.

**Timing**: 2 hours

**Depends on**: 5

**Verification Tier**: local

**Tier Justification**: One new self-contained shell script with no caller yet; covered by
`bash -n`, `shellcheck`, and a hand-run of each of the four predicates in both directions, with
`test-approve-refusals.sh` landing in Phase 7 as the durable covering suite.

**Files to modify**:
- `agent-system/extensions/approvals/scripts/approve-guard.sh` - new, the four refusal predicates
- `agent-system/extensions/approvals/manifest.json` - `provides.scripts` entry

**Verification**:
- `bash -n` clean; `shellcheck` reports no error-level finding.
- Hand-run both directions per predicate: a moved tree refuses and an unmoved one passes; an
  unsurfaced declaration-level item refuses and a surfaced one passes; an answer file missing
  either line refuses and a complete one passes; an `(agent)`-suffixed approver refuses, a
  non-`(agent)` assisted-by refuses, and the correct pairing passes.
- `sync-manifest-scripts.sh --check` clean.

---

### Phase 7: The Command and the Direct-Execution Skill [NOT STARTED]

**Goal**: `/approve <component>` exists end to end as a direct-execution skill in the root
session that asks the owner, records the owner as approver with itself as `assisted_by`, and has
a dry-run that shows the whole flow without recording.

**Tasks**:
- [ ] Write `commands/approve.md` (frontmatter `description`, `argument-hint`), documenting
      `/approve <component> [component-flags...] [--task N] [--dry-run]`: trailing flags are
      forwarded verbatim to the component's `--review` (covering `--core-only`/`--aeneas`
      without hardcoding them), `--out` is refused, and the command is Layer 1 direct execution
      delegating to `skill-approve`.
- [ ] Write `skills/skill-approve/SKILL.md` with frontmatter
      `allowed-tools: AskUserQuestion, Bash, Edit, Read, Write` — deliberately **no `Agent`**,
      and **no `agent:` field** — plus an explicit, prominent statement of why: the prompting
      tool is categorically withheld from every dispatched subagent on this harness, so any
      delegation of this flow makes the prompt unraisable. Copy the pre-delegation-interview
      pattern already proven in `skill-meta`, minus the delegation.
- [ ] Stage order in the skill body:
      1. Resolve paths and refuse an absent component (`approve-paths.sh`).
      2. Stop immediately when the delegation context carries `orchestrator_mode: true` — an
         autonomous cycle must never answer this prompt on the owner's behalf — reporting the
         refusal rather than weakening the channel.
      3. Run the component's `approve.sh --review` with `--out` set to the resolved review path;
         propagate any non-zero exit verbatim.
      4. Classify (`approve-classify.sh`) and write the classification sidecar.
      5. Build the essentials-only summary per the Phase 3 contract: Discrepancies block naming
         every item by name, then per item the id, class, declaration delta, recommendation, and
         confidence, and the artifact paths. `min()` over confidence for any rollup, never a
         mean.
      6. Print the artifact and sidecar paths (Escape 2 is live from here on).
      7. On `--dry-run`: print the summary and the exact `--record` command that would run, then
         stop. Write no presented sidecar, call no prompt, record nothing.
      8. Otherwise run Stage A (bulk gate, offered only when at least one item is mechanically
         cleared) and Stage B (per-item walk, four options), per the Phase 3 ruling, writing the
         presented sidecar as it goes.
      9. Run `--check-surfaced`, `--check-freshness`, `--check-human`, and `--check-labels`;
         any refusal stops the run with nothing recorded.
      10. Flip the approved items' `no` to `yes` in the review file's `## Decisions` block,
          editing nothing else on those lines, and write the question and the answer **verbatim**
          as `Question:` / `Answer:` lines under `## Notes`.
      11. Record with `--record <review> --approver "<owner> <email>" --via-prompt
          --assisted-by "<agent name> (agent) <email>"`. The approver is the owner, resolved
          from the repository's own git identity and never suffixed `(agent)`; the assistant is
          this command. Never pass `--agent`. Propagate a non-zero exit verbatim and never
          retry through another channel.
      12. Report: what was recorded, what was declined, what was left undecided, and the
          artifact paths.
- [ ] State explicitly in the skill body that there is no fallback that records as an agent: if
      the prompt cannot be raised, the command stops and reports.
- [ ] Add the command and skill to `provides.commands` / `provides.skills` (already declared in
      Phase 1 — verify against disk rather than assuming).

**Timing**: 2 hours

**Depends on**: 6

**Verification Tier**: interface

**Tier Justification**: This phase is the first caller of all three scripts' argument surfaces,
so the covering check is the three scripts plus this skill read together — `bash -n` on each
script, a dry-run walk-through against a fixture review file, and
`REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` for Rule D
and Rule E (every referenced script declared, no subagent target to resolve).

**Files to modify**:
- `agent-system/extensions/approvals/commands/approve.md` - new, the command surface
- `agent-system/extensions/approvals/skills/skill-approve/SKILL.md` - new, the direct-execution flow
- `agent-system/extensions/approvals/manifest.json` - verify commands/skills declarations against disk

**Verification**:
- `grep -n "allowed-tools" skills/skill-approve/SKILL.md` shows `AskUserQuestion` present and
  `Agent` absent; no `agent:` frontmatter field exists.
- No line in either file contains both `--record` and `--agent`.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports
  no FAIL for `approvals` (Rule E: every script the docs reference is declared).
- A dry-run walk-through against a fixture review file produces the summary and the would-be
  `--record` command, writes no presented sidecar, and records nothing.
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` exits 0.

---

### Phase 8: Tests for Every Refusal Case and the No-Self-Approval Structure [NOT STARTED]

**Goal**: Each of the three refusal cases has an executable test, the path and classifier
contracts have regression suites, and the no-self-approval and no-delegation properties are
asserted structurally rather than left as comments.

**Tasks**:
- [ ] Write `scripts/tests/test-approve-paths.sh`: component resolution and refusal; the
      task-keyed stem; the **no-task** stem; instance increment for both forms; no collision
      between two same-date taskless cycles; no overwrite of an earlier cycle; refusal of a
      caller-supplied `--out`; and the **tracked-directory assertion** — seed a scratch
      repository with `runtime_specs_ignore_block()`'s output and assert
      `git check-ignore specs/certificates/x.md` does not match, resolving the lib from the
      source store first and the deployed tree second, with a loud `[SKIP]` if neither is
      present.
- [ ] Write `scripts/tests/test-approve-classify.sh`: one fixture review file per evidence kind;
      the declaration delta reported by name for added, removed, and restated claims; the
      `mechanical` class reached only under the narrow bar; `MEASURED` versus `INFERENCE`
      assigned per the vocabulary; and a loud non-zero exit on a malformed review shape.
- [ ] Write `scripts/tests/test-approve-refusals.sh`, one named case per refusal the acceptance
      criteria require: **stale review** (a moved tree refuses, nothing recorded); **unsurfaced
      declaration-level change** (a classification carrying a declaration-level item absent from
      the presented list refuses, and refuses *before* any record step); **no human attached**
      (an absent answer file, one missing `Question:`, and one missing `Answer:` each refuse);
      plus the label pairing in both directions.
- [ ] Write `scripts/tests/test-approve-structural.sh`: the skill declares `AskUserQuestion` and
      does not declare `Agent`; it has no `agent:` frontmatter field; no line in the skill or
      command pairs `--record` with `--agent`; the skill contains the explicit
      no-agent-fallback statement and the `orchestrator_mode` stop; every authored file under the
      extension appears in `manifest.json`'s `provides.*`. Carry the same honesty header
      `test-askuserquestion-rehome.sh` uses: a shell fixture protects the structure, it does not
      re-verify the harness fact, and a green run is not a harness re-verification.
- [ ] Follow the repository's suite conventions in all four: `set -uo pipefail`, `SCRIPT_DIR` /
      git-worktree-first `REPO_ROOT` resolution so each works from both the source store and a
      deployed copy, `pass()`/`fail()`/`info()` with `PASSED`/`FAILED` counters, exit 0 on
      all-pass, 1 on any fail, 2 on an environment error. `chmod +x` each.
- [ ] Re-run `sync-manifest-scripts.sh --write` to declare all four suites in
      `provides.scripts` (a suite runs locally without a manifest entry, which is exactly what
      makes a missing entry invisible at authoring time).

**Timing**: 2 hours

**Depends on**: 7

**Verification Tier**: local

**Tier Justification**: Four new test suites with no production consumer, covered exactly by
running them — `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-approve-paths.sh,test-approve-classify.sh,test-approve-refusals.sh,test-approve-structural.sh`.

**Scope Hypothesis**: This phase asserts four suites covering three refusal cases plus the
structural properties. Confirm at implementation time that each acceptance-criterion refusal maps
to at least one named `pass()`/`fail()` case by grepping the suites for the three refusal names
before closing the phase.

**Files to modify**:
- `agent-system/extensions/approvals/scripts/tests/test-approve-paths.sh` - new
- `agent-system/extensions/approvals/scripts/tests/test-approve-classify.sh` - new
- `agent-system/extensions/approvals/scripts/tests/test-approve-refusals.sh` - new
- `agent-system/extensions/approvals/scripts/tests/test-approve-structural.sh` - new
- `agent-system/extensions/approvals/manifest.json` - `provides.scripts` entries for all four suites

**Verification**:
- Each suite run directly exits 0, and `run-all.sh` discovers all four (zero discovered suites is
  a harness failure, so confirm the count rather than only the exit code).
- Each of the three refusal cases is grep-findable by name in `test-approve-refusals.sh`.
- `sync-manifest-scripts.sh --check` clean.

---

### Phase 9: Wire, Deploy, and Run the Full Gate Set [NOT STARTED]

**Goal**: The extension is fully declared, the deployed tree is consistent, and the complete gate
set passes.

**Tasks**:
- [ ] Re-run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`
      and `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check`.
- [ ] Hand-verify every authored file against `manifest.json`'s `provides.agents`, `commands`,
      `skills`, `context`, and `scripts` arrays — there is no automated check for the first four
      categories at authoring time, and an undeclared file silently never deploys.
- [ ] Load the extension once in this repository (picker or `deploy-headless.sh`) so the
      deployed-tree checks have something to inspect, confirm `.claude/commands/approve.md`,
      `.claude/skills/skill-approve/SKILL.md`, `.claude/scripts/approve-*.sh`, and
      `.claude/context/project/approvals/` all appear, and confirm the `extension_approvals`
      section is merged into `.claude/CLAUDE.md`. Re-read `.claude-extensions.json` immediately
      before and after, per the territory block, since a sibling dispatch shares this tree.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (all 21 gates,
      unnarrowed — no `--only-gate`, no `--only`, no `--skip-slow`).
- [ ] Record issues and wins as they arise via `issue-record.sh`, per the dispatch's Issue Log
      section.

**Timing**: 1.5 hours

**Depends on**: 8

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/approvals/manifest.json` - final declarations
- `agent-system/extensions/approvals/index-entries.json` - final line counts
- `.claude-extensions.json` - extension load record (written by the loader, not by hand)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 with every one of its 21 gates run — the
  complete aggregator, not a hand-picked subset. Gate 3 (doc-lint), Gate 4 (task-reference
  lint), Gate 6 (agent-contracts lint), Gate 7 (routing-wiring lint), Gate 8 (the full shell
  suite runner), and Gates 12-21 (the lint and budget gates) all included.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` (no `--only`) exits 0 and
  discovers a non-zero suite count including the four new suites.
- `grep -rn "task [0-9]" agent-system/extensions/approvals/` returns nothing: no deliverable
  cites a task number.

## Testing & Validation

- [ ] All four new suites pass standalone and under `run-all.sh` with no `--only`.
- [ ] Refusal case 1, stale review: a moved tree refuses before recording; a non-zero exit from
      the component's own `--record` is propagated verbatim and never retried through another
      channel.
- [ ] Refusal case 2, unsurfaced declaration-level change: refuses before the record step.
- [ ] Refusal case 3, no human attached: refuses on an absent or incomplete answer file, and the
      skill independently stops under `orchestrator_mode: true`.
- [ ] No self-approval path: asserted structurally (no `Agent` tool, no `agent:` field, no line
      pairing `--record` with `--agent`, label predicates in both directions).
- [ ] Dry run shows the full flow — summary, would-be record command, artifact paths — and
      records nothing.
- [ ] Artifact keying: a second cycle for the same task does not overwrite the first; two
      taskless cycles on the same date do not collide; the no-task key is explicit.
- [ ] `specs/certificates/` is not matched by the generated managed `.gitignore` block, asserted
      mechanically, with the generated block itself unchanged.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0, unnarrowed.

## Artifacts & Outputs

- `agent-system/extensions/approvals/` — the new extension: `manifest.json`, `EXTENSION.md`,
  `README.md` (carrying the placement ruling), `index-entries.json`, `commands/approve.md`,
  `skills/skill-approve/SKILL.md`, three scripts, four test suites, and four context files.
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` — header comment recording
  `specs/certificates/` as durable and out of the ephemeral-runtime-file class.
- `agent-system/extensions/README.md` — the `approvals` row.
- `specs/349_add_approve_command_owner_labeled_approvals/summaries/01_*-summary.md` — the
  implementation summary.
- In a consumer repository at run time (not produced by this task): the persisted review and its
  two sidecars under `specs/certificates/<component>/`.

## Rollback/Contingency

Every phase is additive within one new extension directory plus two comment-or-row edits to
existing files, so the ordinary recovery is to fix forward. If a genuine rollback of uncommitted
work becomes necessary, take a snapshot first per `context/contracts/recovery.md`'s rollback rung
(including its out-of-scope override flag for a deliberate whole-tree case) and only then run the
reverting command — never a bare precautionary `git-snapshot.sh` as a start-of-phase default, and
never a destructive git operation on a dirty tree without that snapshot. Under the concurrent
sibling dispatch named in this dispatch's territory block, a whole-tree revert would also discard
the sibling's in-flight work: scope any rollback to this task's own files, and stop and report
rather than reverting if a foreign modification is present. To abandon the work entirely, remove
`agent-system/extensions/approvals/` and revert the two single-line edits; unload the extension
through the picker so the deployed copies are removed and the `CLAUDE.md` section and index
entries are cleaned.
