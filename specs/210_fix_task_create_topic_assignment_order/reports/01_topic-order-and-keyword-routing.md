# Research Report: Fix /task create topic assignment order, and task-type keyword false positives

**Task**: 210 - Fix /task create: topic assignment order and registration, and task-type keyword false positives
**Started**: 2026-09-22
**Completed**: 2026-09-22
**Effort**: Medium (two related but separable defect clusters in one source file + one pattern doc
  + one extension manifest + doc updates + new fixture tests)
**Dependencies**: Task 209 (state.json dependency, not content-related to this research)
**Sources/Inputs**: Codebase read (commands/task.md, scripts/manage-topics.sh,
  context/patterns/topic-assignment-pattern.md, context/standards/interactive-selection.md,
  context/guides/extension-development.md, context/guides/manifest-routing-schema.md, all
  extension manifest.json `keyword_overrides` blocks, commands/review.md, commands/fix-it.md,
  agents/meta-builder-agent.md, skills/skill-spawn/SKILL.md, skills/skill-fix-it/SKILL.md,
  skills/skill-project-overview/SKILL.md, skills/skill-todo/SKILL.md, scripts/tests/ conventions)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Defect cluster A (topic order/registration/zero-topics)** is entirely and only in Create Task
  Mode of `agent-system/extensions/core/commands/task.md`. Every other topic-assigning caller
  (Expand, Recover, Review follow-ups in `task.md` itself, plus `/spawn`, `/fix-it`, `/review`,
  `/meta`, `/project-overview`, `/todo` backfill) already calls `manage-topics.sh set`/`add`
  **after** the state write. Create Mode is the sole outlier, confirming the dispatch's "editing
  slip" read.
- `manage-topics.sh set TASK_NUM TOPIC` already does both jobs atomically in one call (sets the
  task's `topic` field AND appends to `active_topics`, idempotently) — see
  `scripts/manage-topics.sh:163-173`. The minimal, most-consistent fix for (a)+(b) is simply
  **moving** Create Mode's existing `manage-topics.sh set` call (task.md:216) from step 4.5 to
  immediately after step 6's state write, matching the pattern every other caller already uses.
  No change to step 6's jq filter, `manage-topics.sh`, or its exit-code contract is needed.
- **Defect (c) (zero-topics picker)**: `topic-assignment-pattern.md` Mode A Step 1 builds
  `options = existing_topics + ["New topic..."]`. On a fresh repo (`active_topics == []`), that
  produces exactly one option, below `AskUserQuestion`'s 2-4 option floor. Confirmed no existing
  code path guards this case.
- **Template schema bug**: `topic-assignment-pattern.md`'s Mode A Step 2/Step 3 JSON blocks use a
  `"type": "select"` / `"type": "freeText"` shape that does not exist in the tool's real schema.
  The real schema (documented at `context/standards/interactive-selection.md` and used correctly
  elsewhere in `task.md` itself) is `{question, header, multiSelect, options: [{label,
  description}]}` — a single-question schema with no separate free-text type; free text is
  handled by an option whose selection triggers a natural-language follow-up turn, not a second
  tool schema.
- Also found (not previously flagged): `task.md`'s own inline AskUserQuestion examples in
  Recover Mode (line ~353-361), Expand Mode (line ~442-450), and Review Mode (line ~822-830) all
  have `header`/`multiSelect` correct but still pass `options` as **bare strings**
  (`["<existing-topic-1>", ...]`) instead of `{label, description}` objects — the same schema
  defect (c)'s fix must also close in the doc it points readers to. These are illustrative,
  not currently causing hard failures, but worth flagging so the plan phase decides whether to
  fix them alongside the pattern-doc rewrite (dispatch scoped work item (b) explicitly to
  `topic-assignment-pattern.md`, so this may be an intentional out-of-scope call, but the plan
  should make that explicit rather than silently missing it).
- **Defect cluster B (task-type keyword false positives)**: confirmed all three named defects.
  4a's bare "agent"/"command"/"skill" match, 4d's bare "proof"/"lean" match, and the literature
  manifest's `keyword_overrides.meta.keywords` (mapping "literature"/"zotero"/"bibliography"/
  "citation" to task_type `meta`) are all real and reproducible against the described
  descriptions. Of all 8 non-core manifests with `keyword_overrides`, **literature is the only
  one whose key does not equal its own task_type** — every other manifest (cslib, email, latex,
  rust, typst) uses `keyword_overrides.<own-task-type>.keywords`. Literature is also the only
  extension with `routing_exempt: true` among the keyword_overrides set (literature has no
  task_type of its own — it provides no `.routing.{research,plan,implement}` block — so mapping
  its keywords to *any* task_type, `meta` or otherwise, is a category error, not just a wrong
  target).
- The step-4 keyword table exists in exactly **one** place in the deployed/source tree
  (`commands/task.md`). It is NOT duplicated verbatim elsewhere, but two other files carry
  independent, drifted **prose summaries** of the same logic that would need updating if the
  detection rule changes: `commands/fix-it.md:47` (research-task language detection) and
  `agents/meta-builder-agent.md:275-276` (meta's own task_type=meta heuristic for *its own*
  task-creation calls — but the dispatch's MUST NOT explicitly forbids changing this one).
  `commands/review.md` uses a wholly different, unaffected mechanism (file-extension-based
  majority voting over the files touched by a review finding, not description-text keyword
  matching), so it is not a duplicate of the table and does not need updating for this defect.
  `skill-spawn/SKILL.md` inherits `task_type` from the parent task rather than re-detecting it,
  so it is also unaffected.
- No fixture test infrastructure exists today for either defect area (no
  `scripts/tests/test-manage-topics.sh`, no `scripts/tests/test-*task-type*.sh` or
  `test-*keyword*.sh`). `test-routing-resolution.sh` is a good structural precedent
  (table-driven, mktemp workdir, PASSED/FAILED counters per
  `context/standards/shell-script-testing.md`) but tests a completely different subsystem
  (extension routing ladder, not `/task`'s prose-described step-4 detection or step-4.5 topic
  flow). Because `task.md` step 4/4.5 logic is currently **prose interpreted by the agent**, not
  a standalone shell function, a literal "fixture test" per the ACCEPTANCE criteria implies
  extracting the detection rule (and/or the topic-order sequence) into a small, sourceable shell
  script or function — mirroring how `manifest-routing-lib.sh` centralized the routing ladder
  that used to be prose-duplicated across consumers. This extraction decision belongs to the
  plan phase; recommending it here as the only way to satisfy "no non-zero exit from
  manage-topics.sh" and "runs the detection rule on: ..." as literal, automatable assertions
  rather than manual transcript inspection.

## Context & Scope

Two previously-separate tasks were absorbed into this one (task 211's text follows verbatim in
the dispatch). Both concern `/task` create-mode correctness: topic assignment order/registration/
zero-topics UX, and task_type keyword-match false positives. The file surface is small and
disjoint from this cycle's concurrent siblings (242/243/245/227 territory does not touch
`commands/task.md`, `scripts/manage-topics.sh`, `context/patterns/topic-assignment-pattern.md`,
or `extensions/literature/manifest.json`).

## Findings

### Codebase Patterns

**Topic order defect (a) — confirmed, root cause and fix location**:
- `commands/task.md` step 4.5 (task.md:209-217) calls
  `bash .claude/scripts/manage-topics.sh set "$next_num" "$topic"` **before** step 6
  (task.md:224-254) writes the task into `active_projects`.
- `manage-topics.sh set` (scripts/manage-topics.sh:140-174) validates task existence via jq
  against `active_projects` (line 154-156) and exits 4 if absent (line 158-161) — so as currently
  sequenced in Create Mode, this call always fails (task doesn't exist yet at that point in the
  flow).
- Comparison confirmed: Expand Mode calls `manage-topics.sh set` at task.md:462, *after* "each
  subtask entry is written to state.json" per its own comment (task.md:461). Review Mode
  (follow-up task creation) calls it at task.md:868-870, explicitly "After state.json write."
  Recover Mode calls `manage-topics.sh add` (not `set`, since the task already exists in the
  moved blob) at task.md:384, after the two-step archive-to-active `state-write.sh` move
  completes at task.md:370-380.

**Topic registration defect (b) — confirmed, and simpler fix than reordering + editing step 6**:
- Step 6's jq filter (task.md:237-254) sets `"topic": (if ($topic == "" | not) then $topic else
  null end)` on the new entry but never touches `.active_topics`.
- `manage-topics.sh set`'s jq body (scripts/manage-topics.sh:164-173) does BOTH: sets
  `.topic` on the matched task AND does the idempotent `active_topics` append in the same
  `state-write.sh` call. So defects (a) and (b) share one fix: **move the existing
  `manage-topics.sh set` call from step 4.5 to immediately after step 6**, rather than a) moving
  it AND b) separately teaching step 6's jq filter to append to `active_topics` (which would
  duplicate logic `manage-topics.sh` already owns, and would be the only topic-registering call
  site in the whole system that inlines the `active_topics` jq instead of delegating to
  `manage-topics.sh` — `topic-assignment-pattern.md`'s own stated purpose is "Commands should
  call `manage-topics.sh` for state.json operations... This document and `manage-topics.sh`
  replace all inline implementations").
- This reordering is consistent with the "use it everywhere" requirement: it makes Create Mode
  structurally identical to Expand/Recover/Review Mode's already-correct pattern, rather than
  introducing a second, divergent mechanism.
- Minor note: after the move, step 6's jq `topic` assignment becomes redundant with what
  `manage-topics.sh set` will do a few lines later (it re-sets the same field). This redundancy
  is harmless (idempotent, same value) but the plan should decide whether to also strip the now-
  redundant `"topic": ...` clause from step 6's jq object for cleanliness, or leave it as
  defensive belt-and-suspenders (both are defensible; leaving it means `state.json` briefly has
  the topic set correctly even if the following `manage-topics.sh set` call somehow fails non-
  fatally, though today nothing catches that failure — see below).
- Caveat: unlike Expand/Review, which guard the `manage-topics.sh set` call with
  `|| echo "Warning: ... (non-fatal)" >&2`, Create Mode's dispatch snippet at task.md:216
  currently has no such guard. Since Create Mode's whole point is that topic assignment is
  *mandatory* (not advisory), the plan should decide whether Create Mode's post-move call should
  be a hard failure (task creation aborts / rolls back if `manage-topics.sh set` fails) rather
  than the soft "non-fatal" pattern every other caller uses — this is a genuine behavioral
  decision, not just a copy-paste of the Expand-Mode idiom.

**Zero-topics picker defect (c) — confirmed**:
- `topic-assignment-pattern.md` Mode A Step 1 (lines 57-69): `options = existing_topics +
  ["New topic..."]`. No length check. On a fresh repo, `existing_topics` is empty, so `options`
  has exactly one entry — below the 2-4 option range the dispatch says `AskUserQuestion` requires.
- No existing caller in the codebase currently guards this. It is a first-task problem: any fresh
  repo's very first `/task` invocation hits it.
- The dispatch offers two remediation shapes: (i) synthesize 1-2 suggested topic names from the
  description text plus "New topic...", or (ii) skip the multi-option picker and go straight to
  a free-text prompt when there are zero existing topics. Tradeoff: (i) requires a naming
  heuristic (risk of a low-quality guess) and still needs a fallback if it can only produce one
  candidate (1 suggestion + "New topic..." = 2 options, satisfying the floor; 0 suggestions still
  under-shoots). (ii) is simpler and deterministic — recommend (ii) as the primary path,
  reserving a "1-2 suggested names" enhancement only if the plan phase wants richer UX; both
  satisfy the "no Skip/Defer" and "mandatory" constraints as long as free-text re-prompts on
  empty input (already specified in Step 3 of the pattern doc for the non-zero-topics case).

**AskUserQuestion schema mismatch — confirmed, and precisely characterized**:
- Real schema, confirmed via `context/standards/interactive-selection.md` (the standards doc) and
  cross-checked against every *correct* usage already in `task.md` itself (Recover/Expand/Review
  fallback pickers): `{question: string, header: "1-3 words Title Case", multiSelect: boolean,
  options: [{label: string, description: string}]}`. There is no `type` field and no separate
  `"freeText"` question type — free text is obtained by making one option (e.g. "New topic...")
  trigger a natural-language follow-up in the next turn, not a distinct tool invocation shape.
- `topic-assignment-pattern.md` Mode A Step 2 (lines 71-79) uses `{"question": ..., "type":
  "select", "options": [...]}` — missing `header`/`multiSelect`, wrong `type` field, and
  `options` as bare strings instead of `{label, description}` objects. Step 3 (lines 81-90) uses
  `{"question": ..., "type": "freeText"}`, which has no counterpart in the real schema at all —
  the doc's own prose ("show a follow-up free-text question") is the correct behavior, but the
  JSON block models it as if it were a second machine-invokable schema variant, which the tool
  does not have.
- Same file's "sync backfill" template (lines 109-115) and "batch variant" prose inherit the same
  `type: select` defect since they're described as copies of Steps 1-3.
- As noted in Executive Summary, `task.md`'s own three inline illustrative pickers (Recover:
  353-361, Expand: 442-450, Review: 822-830) already have `header`/`multiSelect` right but still
  use bare-string `options` rather than `{label, description}` — a narrower version of the same
  defect, in the file the dispatch does NOT name for this fix. Flagging for plan-phase scoping
  decision rather than silently leaving it inconsistent with the rewritten pattern doc.

**Task-type keyword false positives (defect cluster B) — all three confirmed**:
- **4a** (task.md:127-128): `"meta", "agent", "command", "skill"` anywhere in the description,
  unconditionally, first rule checked → `meta`. Reproduced against both cited descriptions
  ("research and revise the AI agent objectives... training models... agent harnesses" contains
  bare "agent" three times) and against this task's own absorbed acceptance case ("Update
  skill-orchestrate's dispatch to pass --lit" — contains no 4a keyword as a bare word, actually;
  it would fall through to general or another row, not 4a — worth flagging: **this acceptance
  case, "Update skill-orchestrate's dispatch to pass --lit" expected `meta`, does not obviously
  match ANY current keyword in 4a's bare list** ("skill-orchestrate" is not "skill" as a whole
  word per `\b<keyword>\b` boundary semantics — `skill-orchestrate` does contain `skill` as a
  prefix followed by a hyphen, and `\bskill\b` with default word-boundary semantics in most regex
  engines treats `-` as a non-word character, so `\bskill\b` WOULD match inside
  "skill-orchestrate" at the "skill" substring boundary). Confirmed this is intentional under the
  *current* whole-word matching semantics (hyphen counts as a boundary), so 4a's existing bare
  "skill" keyword already correctly resolves this acceptance case today — but if the chosen fix
  narrows 4a to phrase-level signals like "SKILL.md", "a named skill or agent" (Option 1's
  wording in the dispatch), the plan must explicitly re-verify this exact case still resolves to
  `meta`, since "skill-orchestrate" contains neither ".claude/", "agent system", "slash command",
  nor "SKILL.md" as phrases. This is a real tension between fixing the two false-positive cases
  and preserving this true-positive case, and belongs in the plan's rule definition, not glossed
  over.
- **4d** (task.md:162): `"lean", "lean4", "mathlib", "theorem", "proof", "lemma", "axiom",
  "proposition", "corollary", "derivation"` → `lean4`, evaluated after 4a/4b/4c. Reproduced against
  both cited descriptions ("Why Lean over Rocq..." matches bare "lean"; "the Logos proof theory"
  matches bare "proof"). Also reproduced the 4th acceptance case, "Prove soundness lemma in
  Metalogic/Soundness.lean" — matches "lemma" (and "lean" via the `.lean` file extension, though
  extension matching isn't itself a listed 4d keyword) → correctly resolves `lean4` today, and
  must continue to after the fix.
- **4c literature manifest** (`extensions/literature/manifest.json`):
  `keyword_overrides.meta.keywords = ["literature", "zotero", "bibliography", "citation"]`.
  Confirmed present, confirmed matched by step 4b's scan (which iterates ALL manifests'
  `keyword_overrides` regardless of `routing_exempt`). Reproduced the cited case: a lean4
  formalization description containing the word "literature" (e.g., discussing a paper) would
  resolve to `meta` at step 4b, before step 4d (which would otherwise correctly catch
  "theorem"/"lemma"/etc.) ever runs — 4b short-circuits on first match per task.md:149 ("If
  `matched` is non-empty → task_type = `matched`, skip to step 4e").
  - Literature is the **only** manifest among the 6 non-core extensions with
    `keyword_overrides` whose key doesn't equal its own task_type: cslib→cslib, email→email,
    latex→latex, rust→rust, typst→typst, but literature→**meta** (not "literature"). This is
    exactly the mismatch `extension-development.md`'s own doc describes as a hard rule
    ("`keyword_overrides` keys ARE task types") without literature actually following it.
  - Deeper issue beyond a wrong key: literature has `routing_exempt: true` and provides **no**
    `.routing.{research,plan,implement}` block at all (confirmed via `jq` read of the manifest —
    only `dependencies`, `description`, `keyword_overrides`, `merge_targets`, `name`, `provides`,
    `routing_exempt`, `version` keys exist). Per CLAUDE.md's own "Literature Extension" section,
    literature has no Task-Type Routing table (unlike email/nix) — `/literature` and `/cite` are
    direct-execution skills, not part of the research/plan/implement task-type dispatch table.
    So mapping literature's keywords to task_type `"literature"` (the naive "fix the key" reading
    of work item (a)) would create a task_type with no routing entry anywhere, which
    `command-route-skill.sh`/`command-route-agent.sh` would then fail to resolve at dispatch
    time — a worse failure mode than today's wrong-but-resolvable `meta` mapping. **Recommend
    removing the `keyword_overrides` block from the literature manifest entirely** (not
    remapping it) as the correct fix, since literature descriptions should route by their actual
    content (a lean4 paper mentioning "literature" should still resolve `lean4`; a business
    strategy doc mentioning "literature review" should resolve `general`) rather than by the
    presence of literature-adjacent vocabulary. `--lit` (literature injection) is already a
    fully independent, per-invocation flag orthogonal to `task_type` (per CLAUDE.md's Literature
    Mode section), so no task_type is needed to "turn on" literature handling — this confirms
    removal doesn't lose any real capability.
  - `extension-development.md`'s "Worked examples" line (~118-119) currently cites literature
    alongside email/cslib/latex/typst as a correct usage example of `keyword_overrides` — this
    citation becomes wrong once literature's block is removed and must be updated (drop
    literature from that list, or replace with a corrected example if the plan instead chooses
    to keep a narrower literature-specific mapping).

**Duplicate-table sweep (WORK item b's "grep for it" instruction) — result: no verbatim
duplicates, two prose summaries that need corresponding updates, one explicitly out of scope**:
- `commands/fix-it.md:47` — a one-line prose restatement of the SAME false-positive-prone rule
  ("meta keywords (.claude, command, agent, etc.) -> meta... content keywords (theorem, proof,
  lemma, etc.) -> lean4") used for QUESTION:-tag research-task language detection. This is
  independent prose, not a shared function call, so it will silently drift from whatever the
  plan changes in `task.md` step 4 unless explicitly updated in the same pass. No fixture test
  currently exercises it either.
- `agents/meta-builder-agent.md:275-276` — meta's own simplified task_type=meta heuristic,
  used when `/meta` creates tasks for its own proposed system changes. The dispatch's MUST NOT
  explicitly forbids touching this ("Do not change how `/meta` sets task_type directly"),
  confirmed present and unambiguous — do not include this file in the implementation's edit set.
- `commands/review.md` — uses a **file-extension-based majority-vote** table (task.md:520-557
  region: `*.lua`→general, `*.md`/`*.json`/`.claude/**`→meta, `*.tex`→latex, `*.typ`→typst,
  other→general), keyed on which files a review finding touches, not on description-text keyword
  matching. This is a structurally different mechanism, immune to the "keyword in passing" false-
  positive class described in this task. No change needed here for this defect.
- `skills/skill-spawn/SKILL.md` — reads `task_type="$TASK_TYPE"` (inherited from the blocked
  parent task via `command-gate-in.sh`), never re-detects from description text. No change
  needed.

### External Resources

Not applicable — this is a pure codebase-logic defect with no external library/API surface;
`AskUserQuestion`'s real schema was confirmed from this repo's own already-correct usages and its
own documented standard (`interactive-selection.md`), not from external documentation (the tool
schema is not independently web-documented in a form more authoritative than the repo's existing
correct call sites).

### Recommendations

1. **Order/registration fix**: in `commands/task.md` Create Task Mode, delete the
   `manage-topics.sh set` call currently at step 4.5 (task.md:214-217) and add an equivalent call
   immediately after step 6's `state-write.sh` (currently ending at task.md:254), guarded
   consistently with the rest of the flow. Decide explicitly (plan-phase decision, flagged above)
   whether failure here should be fatal to task creation, given topic assignment is documented as
   mandatory elsewhere in the system.
2. **Zero-topics picker**: in `topic-assignment-pattern.md` Mode A Step 1, add a length check on
   `existing_topics`; when empty, skip the multi-option picker and go straight to the free-text
   prompt (Step 3's shape), reusing its existing empty-input re-prompt rule. Update the "no Skip"
   guarantee language to explicitly cover this branch.
3. **Schema rewrite**: rewrite `topic-assignment-pattern.md`'s Mode A Step 2/Step 3 JSON blocks
   (and the sync-backfill variant) to the real `{question, header, multiSelect, options:
   [{label, description}]}` shape, folding the free-text branch into prose ("if the user picks
   'New topic...', the next turn asks for free-text input") rather than a second JSON schema.
   Decide in the plan whether to also fix `task.md`'s three bare-string-options illustrative
   pickers (Recover/Expand/Review) for consistency with the corrected pattern doc, since they'll
   otherwise be the only remaining non-conformant examples in the codebase.
4. **Literature manifest**: remove `keyword_overrides` from
   `agent-system/extensions/literature/manifest.json` entirely (not remap it), since literature
   has no task_type of its own and `--lit` already covers literature-context injection
   independent of task_type. Update `extension-development.md`'s worked-examples citation
   accordingly.
5. **4a/4d keyword narrowing**: define the exact narrowed rule against ALL FOUR acceptance cases
   simultaneously (the two Verification false positives expecting `general`, the Sep 3
   lean4-with-"literature" case expecting `lean4`, "Update skill-orchestrate's dispatch to pass
   --lit" expecting `meta`, and "Prove soundness lemma in Metalogic/Soundness.lean" expecting
   `lean4`) — this research confirms the tension called out in Findings (narrowing 4a risks
   breaking the skill-orchestrate case) and recommends the plan phase resolve it with either a
   still-includes-"skill"-as-bare-word narrowing, or an explicit multi-word-phrase set that's
   verified to still catch "skill-orchestrate" (e.g. keeping single-word "skill"/"agent"/"command"
   but requiring the description to ALSO contain an agent-system-specific noun like "task",
   "dispatch", "orchestrate", ".claude" as Option 3 (content scoring) would naturally provide —
   scoring may be the more robust option precisely because it doesn't need to special-case
   "skill-orchestrate" against a narrowed phrase list).
6. **Fixture tests**: since `task.md` step 4/4.5 is prose interpreted by the dispatched agent
   (not a standalone script today), extract the detection rule into a small sourceable shell
   script/function (e.g. `scripts/lib/task-type-detect.sh`, mirroring how
   `scripts/lib/manifest-routing-lib.sh` centralized the previously-prose-duplicated routing
   ladder) so `scripts/tests/test-task-type-detect.sh` can assert the four acceptance cases
   mechanically. Similarly, a `scripts/tests/test-manage-topics-create-order.sh` (or extending
   an existing harness) using the `test-init-specs.sh`-style mktemp scratch-repo pattern can
   assert: (i) create-mode topic assignment on a state with zero topics leaves task.topic and
   active_topics both set with no non-zero `manage-topics.sh` exit, and (ii) same on a state with
   existing topics. Follow `context/standards/shell-script-testing.md` conventions
   (pass()/fail()/info(), PASSED/FAILED counters, mktemp -d, exit 0/1/2).

## Decisions

- Treat defect (a)+(b) as a single fix (move the call), not two (move + separately teach step 6's
  jq to touch `active_topics`) — `manage-topics.sh set` already does both atomically, and
  duplicating its `active_topics` logic inline in step 6 would violate the pattern doc's own
  stated purpose of eliminating inline topic jq.
- Recommend removing (not remapping) the literature manifest's `keyword_overrides` block, since
  literature has no task_type of its own to remap to, and `--lit` already provides the relevant
  capability independent of task_type.
- Recommend the zero-topics picker go straight to free-text (dispatch's option (ii)) rather than
  synthesizing suggested names from the description (option (i)), for determinism and to avoid a
  new heuristic-quality risk surface.

## Risks & Mitigations

- **Risk**: narrowing 4a's keyword list could silently break the "skill-orchestrate" acceptance
  case (a true positive today via whole-word "skill" matching). **Mitigation**: the plan must
  explicitly re-run all 4 acceptance cases (not just the 2-3 headline false-positive cases) against
  any candidate narrowed rule before implementation; this research flags the tension so it isn't
  discovered only at ACCEPTANCE-test time.
- **Risk**: making Create Mode's post-move `manage-topics.sh set` call fatal (rather than the
  "non-fatal" idiom used elsewhere) changes task-creation failure behavior in a way other modes
  don't have. **Mitigation**: explicit plan-phase decision, documented rationale either way (topic
  assignment being genuinely mandatory is a legitimate reason to diverge from the soft-failure
  idiom used by non-mandatory paths like Expand/Review).
- **Risk**: extracting step 4/4.5 logic into a shell script is itself new surface area (new file,
  new test, new maintenance point) beyond a pure "move a line" fix. **Mitigation**: this is the
  only way to satisfy the ACCEPTANCE criteria's literal "fixture test... All pass from the
  deployed copy" requirement without hand-transcribing prose into a test; flagged as a
  recommendation, not a mandate, so the plan phase can choose a lighter-weight verification
  approach if it disagrees (e.g., an integration-style test that greps the deployed `task.md` text
  for the exact keyword lists, if full extraction is judged out of scope for this task).

## Context Extension Recommendations

- **Topic**: `extension-development.md`'s `keyword_overrides` worked-examples list.
  **Gap**: cites literature as a correct-usage example; it is currently the one manifest that
  violates the "keys ARE task types" rule the same doc documents. **Recommendation**: update the
  worked-examples line once literature's manifest is fixed (either drop it from the list, if the
  block is removed entirely, or correct the citation if a narrower literature-specific mapping is
  kept instead).
- **Topic**: fixture-test coverage for `/task` create-mode topic flow and task_type detection.
  **Gap**: no `scripts/tests/test-manage-topics*.sh` or `test-task-type-detect*.sh` exists today,
  despite `manage-topics.sh` and the step-4 detection table being load-bearing, frequently-touched
  logic. **Recommendation**: the plan phase's fixture-test work item is also an opportunity to
  close this general coverage gap, not just satisfy this task's specific ACCEPTANCE line.

## Appendix

- Files read in full or in relevant part: `commands/task.md`, `scripts/manage-topics.sh`,
  `context/patterns/topic-assignment-pattern.md`, `context/standards/interactive-selection.md`,
  `context/guides/extension-development.md` (lines 80-130),
  `context/guides/manifest-routing-schema.md` (lines 100-160), `commands/review.md` (topic and
  task_type sections), `commands/fix-it.md` (grep), `agents/meta-builder-agent.md` (grep + lines
  around 275), `skills/skill-spawn/SKILL.md`, `skills/skill-fix-it/SKILL.md`,
  `skills/skill-project-overview/SKILL.md`, `skills/skill-todo/SKILL.md`, all 8 extension
  `manifest.json` files' `keyword_overrides` blocks, `scripts/tests/test-routing-resolution.sh`
  and `scripts/tests/test-init-specs.sh` (structural precedent only).
- Confirmed via `jq`: task 210's live state.json entry (`project_number: 210`, `status:
  researching`, `task_type: meta`, `topic: core-agent-system`, `file_scope` matches the four
  files named in the dispatch).
- Confirmed via `jq` sweep: cslib/email/latex/rust/typst `keyword_overrides` keys all equal their
  own `.name`/task_type; literature is the sole exception (`meta`).
