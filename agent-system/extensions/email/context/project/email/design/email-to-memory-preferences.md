# Design: Email-to-Memory Preference Contribution

**Task**: 821 (design) -> 822 (implementation, queued, depends on 821)
**Status**: Design complete. No production code in this document; `email-preferences.md`'s
static classifier rule table is untouched by this design.
**Research input**: `specs/821_email_to_memory_contribution_architecture/reports/01_team-research.md`
(4-teammate team research; skeleton converged, 8 gaps identified: G1-G8)

## Purpose

Route **confirmed** `skill-email-cleanup` decisions (junk vs keep) into the memory vault as
**sender/domain-aggregated preference memories** that evolve over time (CREATE once, then
UPDATE/EXTEND) — never one memory per message. This document resolves the eight load-bearing
gaps (G1-G8) the research phase identified in the convergent skeleton, verifies the identity key
against real mail, and hands 822 an explicit scope recommendation.

### Convergent Skeleton (from research, unchanged)

- **Capture point**: an opt-in harvest step inside `skill-email-cleanup`, firing after Stage 6
  (Verify), on verified confirmed actions only.
- **Aggregation unit**: the sender/domain identity (Phase 2 below), keyed off the `--all` mode
  Stage 2.5 bucket in bulk sweeps, or the approved manifest's `sender` field in default mode.
- **Storage**: vault memories via `skill-learn` CREATE/UPDATE/EXTEND, under a reserved topic
  namespace `email/preferences/{key}`.
- **Gate**: reuse `skill-todo`'s harvest -> dedup -> tiered `AskUserQuestion` -> batch-regen
  *logic* (not its `state.json` substrate), one consolidated non-silent prompt.

---

## 1. Capture Point, Harvest Trigger, and Evidentiary Rules (G1, C1, C2)

### 1.1 Capture point (cites `skill-email-cleanup/SKILL.md`)

The harvest fires **after Stage 6 (Verify)**, never earlier:

- **Default mode**, Stage 6 (`SKILL.md:178-181`): "Diff the wrapper's own execution-state output
  (never re-derived) against the approved manifest to confirm which IDs were actually mutated."
  The harvest reads exactly this diff's *executed* set — not the Stage 2 candidate manifest
  (`proposed_action`, unconfirmed) and not the Stage 3/4 approved-but-not-yet-executed manifest
  (which can still fail at Stage 5 Execute or be skipped by a wrapper-level refusal).
- **`--all` mode**, Stage 6 (`SKILL.md:398-402`): "diff the per-split execution-state files
  (never re-derived) against the approved manifest across ALL splits and report totals —
  executed, failed ..., skipped ..., and expired-unexecuted residual." The harvest reads only
  the *executed* totals; failed/skipped/expired IDs contribute no evidence.

Only a Message-ID that the wrapper itself confirms as `executed` (via its own state-file diff,
per wrapper-contracts.md §4) is preference-worthy evidence. This is deliberate: it makes the
harvest immune to approval-without-execution (expired manifest, wrapper refusal, individual ID
failure) — an approved-but-unexecuted action asserts nothing about what actually happened to the
message.

### 1.2 Harvest unit

- **`--all` mode**: the Stage 2.5 bucket grouping (`bulk-bucket-review.md`: domain key,
  full-address for freemail/shared domains, `min()` confidence rollup) is the harvest
  *trigger/start key* — one candidate per bucket touched, cross-referenced against the Stage 6
  executed diff so only actually-executed members of the bucket count as evidence.
- **Default mode**: no bucket exists (50-cap linear flow), so the key is derived post-hoc,
  per executed Message-ID, from the approved manifest's `sender` field (normalized per Phase 2),
  then grouped by the Phase 2 key across all executed IDs in that Stage 6 pass.
- Never one candidate per message — the memory-write decision always operates on the
  post-normalization group, never a single raw manifest line.

### 1.3 Rejected alternatives (recorded with rationale)

- **`hooks: {}` lifecycle slot**: verified `.claude/extensions/memory/manifest.json` declares
  `"hooks": {}` (schema-ready, empty) and `.claude/extensions/email/manifest.json` has no
  `hooks` key at all (absent, not even declared empty) — neither extension has ever exercised
  this slot; its failure-isolation contract is unproven in this repo. Rejected as a starting
  dependency for a design meant to ship soon; revisit only if a second hook consumer emerges.
- **Deferred `/todo`-substrate harvest**: `.claude/scripts/memory-harvest.sh` reads
  `.active_projects[] | select(.project_number == $task) | .memory_candidates` from
  `specs/state.json` (verified by reading the script) — it is keyed on `project_number`.
  `/email` is direct-execution with no task directory and no `project_number`; this substrate
  literally does not exist for it. Rejected, not merely deprioritized.

### 1.4 Evidentiary threshold (G1/C1)

A running **per-action tally** (Phase 3's `{delete_count, archive_count, keep_count,
last_seen}`) is read back on every harvest pass. A memory is CREATEd or its dominant action
STRENGTHENED only when either:

- **Uniform action across the batch/bucket** for that identity key in this Stage-6 pass (the
  common case in `--all` mode: a bucket approved-and-executed as one action satisfies this
  trivially), OR
- **Rolling N>=3 confirms at >=80% consistency**: across this pass's tally update, the
  post-update dominant action's count is >=3 and represents >=80% of that key's total confirmed
  count. This is evaluated **after** applying this pass's increments to the stored tally, so a
  single default-mode confirm can cross the threshold on, say, its 3rd/4th visit — the harvest
  step is therefore stateful and must read the existing memory (if any) before deciding whether
  to write.

A single isolated confirm below both bars is *recorded* (the tally increments — see Phase 4
EXTEND path) but does not on its own justify presenting the sender as a strong preference in any
future gate/read-back surfacing; it simply accumulates toward the threshold.

### 1.5 Mixed-sender handling (C2)

First-class branch, not an edge case: when a would-be identity key's confirmed actions in this
pass are heterogeneous with no uniform majority (the canonical example: a `github.com` bucket
where security-alert subjects are kept and marketing-digest subjects are junked), the harvest
either:

- **Splits** by a subject/category token into distinct memory keys (e.g.
  `email/preferences/github.com` vs a finer split if the manifest data supports one), or
- **Declines to aggregate** that portion this pass (leaves it as unresolved tally noise) rather
  than averaging into a false scalar.

The **review partition** (Stage 2.5 bucket, optimized for human bulk-approval ergonomics) and
the **memory partition** (Phase 2's normalized identity, optimized for durable preference
identity) are explicitly not required to be identical. One review bucket may fan out into
multiple memory-write candidates.

---

## 2. Identity Key Normalization + Real-Sample Verification (G2)

### 2.1 Manifest ground truth

`wrapper-contracts.md:43-47`/§3 confirms the manifest schema is
`{message_id, sender, subject, date, proposed_action, reason, confidence}` — `sender` is a
**bare, unnormalized string** with no contract for case, display-name wrapping, plus-addressing,
DMARC rewriting, or List-Id (there is **no `List-Id` field in the manifest schema at all** — see
§2.3 below).

### 2.2 Normalization rule (final)

```
key = normalize(sender):
  1. Extract the bare address from "Display Name <addr>" or bare "addr" forms
     (regex: [A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+)
  2. Lowercase the entire address
  3. Strip a plus-addressing tag from the local-part: "local+tag@domain" -> "local@domain"
  4. Primary key = "local-part@domain"
  5. Domain-rollup fallback: for NON-freemail/non-shared domains only, a caller MAY roll up to
     "@domain" (mirrors bulk-bucket-review.md's own freemail carve-out: gmail.com, yahoo.com,
     outlook.com, proton.me, and other shared/freemail domains are NEVER rolled up — each full
     address is its own key on those domains).
  6. List-Id preference: NOT IMPLEMENTABLE from the current manifest schema (§2.3) — deferred,
     documented as a residual limitation, not a design decision made "on paper only."
  7. DMARC-rewritten-forwarder caveat: documented in §2.4 with a real observed example.
```

### 2.3 Real-sample verification (performed during design, not deferred)

**Method**: `email-classify --account gmail --manifest-dir <scratch> --emit-tagged
"tag:proposed-delete or tag:proposed-archive or tag:proposed-unsure or tag:proposed-keep"`.
This is genuinely read-only (wrapper-contracts.md §10a: "No `notmuch tag` call anywhere in this
mode... idempotent and side-effect-free"), run against the account's existing `+proposed-*`
tags from prior classify passes (2,656 already-tagged messages present in the index at time of
verification). Output: 2,128 tagged messages re-emitted, **751 unique sender strings**.

Findings against each of the four edge classes named in the plan:

| Edge class | Observed? | Evidence |
|---|---|---|
| **Freemail vs corporate domains** | Yes | `gmail.com` alone spans 337 messages across many *distinct* real addresses (`benbrastmckie@gmail.com`, `99nicky@gmail.com`, `siyasiya@gmail.com`, `bengoldhaber@gmail.com`, `marielkgoddu@gmail.com`, ...). Domain-rollup on `gmail.com` would have silently merged unrelated humans — confirms the freemail carve-out (step 5) is load-bearing, not defensive-only. |
| **Plus-addressing** | Yes | 20 of 2,128 messages carry a `+tag` in the local-part, e.g. `invoice+statements+acct_1RszBH2StuRr0lbX@stripe.com`, `invoice+statements@mail.anthropic.com`, `nextplayso+should-you-join@substack.com`, `hello+nicky-and-ben-oct-2026@withjoy.com`. Notably these are **sender-side** tags (services encoding context into their own From address, not classic recipient-side tagging) — stripping collapses e.g. all Stripe invoice mail to `invoice@stripe.com`, which is the *correct* aggregation for a sender preference (the account-ID suffix is noise for "should I keep Stripe invoices"). |
| **List-Id vs From** | **Not present in sample** (structural, not sampling luck) | The manifest schema (`wrapper-contracts.md` §3) has no `List-Id` field — `email-classify` never captures it. "Prefer List-Id over From for lists" is therefore **not implementable today** without a wrapper-contract change (out of scope; the wrapper is frozen). Documented as a hard limitation, not a soft preference. |
| **DMARC-rewritten forwarders** | Yes | Gmail's automatic DMARC-compliance rewrite for mailing lists is directly visible: `"'Marta Bieńkiewicz' via guaranteed-safe-ai" <guaranteed-safe-ai@googlegroups.com>`, `Charith Premawardhana via Groupmuse <mail@groupmuse.com>`, `"Devin Caglayan via DocuSign" <dse_NA3@docusign.net>`. The stored key resolves to the **relay/list address** (e.g. `guaranteed-safe-ai@googlegroups.com`), not the original individual poster — for mailing-list traffic this is actually the *desired* aggregation (one preference per list, not per poster), but it means a corporate domain enforcing strict DMARC (`p=reject`) whose mail is relayed through a third party will key by the relay, not the origin domain. |

**Case-sensitivity** (bonus finding, not one of the four named classes but directly load-bearing
for step 2): the same real address recurs with inconsistent capitalization across messages,
e.g. `CorrAdmin1@spi-global.com` appears repeatedly in mixed case. Confirms the lowercase step
is necessary on real data, not merely defensive boilerplate.

### 2.4 Residual edge cases (documented, not resolved further)

- **List-Id unavailability** (§2.3): 822 must key uniformly off `From` (post-normalization);
  a future wrapper-contract change to capture `List-Id` is a prerequisite for the "prefer
  List-Id" refinement — out of 821/822 scope, noted as a limitation.
- **DMARC-relay keying**: accepted as correct-by-default for mailing-list traffic (aggregates by
  list identity, matching "one evolving memory per sender/domain"); flagged as a known
  divergence from "identity of the original human sender" for anyone who later wants
  per-poster granularity within a list.

### 2.5 Verification outcome

The normalization rule in §2.2 is **verified against real mail, not asserted on paper** — three
of four edge classes were directly observed with concrete examples; the fourth (List-Id) was
conclusively shown to be a schema-level gap rather than an untested hypothesis. This satisfies
the plan's Phase 2 verification requirement without invoking the provisional-unverified
fallback (Rollback/Contingency); the key ships as **verified**, not provisional.

---

## 3. Memory Schema, Tally Model, and Topic Namespace (G5, G7, Conflict-2 synthesis)

### 3.1 Reserved topic namespace

`email/preferences/{key}` where `{key}` is the Phase 2 normalized identity (§2.5), further
prefixed by account per the 822-scope recommendation (§5.5): `email/preferences/{account}/{key}`
e.g. `email/preferences/gmail/stripe.com` or `email/preferences/gmail/benbrastmckie-gmail-com`
(hashed local-part per §3.3).

### 3.2 Per-action tally (stored in the memory **body**, not frontmatter)

```
{delete_count, archive_count, keep_count, last_seen}
```

Stored as a small structured block in the markdown body (not frontmatter — frontmatter stays
flat per the existing convention: `title, created, tags, topic, source, modified, keywords,
summary, retrieval_count, last_retrieved`, verified via `memory/README.md:151-160` and by
inspecting a live memory file's frontmatter). The **dominant action is derived**, never a stored
scalar: `dominant = argmax(delete_count, archive_count, keep_count)`, ties broken by whichever
action has the more recent per-action `last_seen` (a per-action `last_seen` sub-field, not a
single scalar, is required to break ties correctly — see body template below).

This is the report's key mechanical synthesis: a contradicting confirm increments the *opposite*
counter, which can shift the derived dominant action without any bespoke decay/EWMA math and
without a new skill-learn API verb (Phase 4 §4.3).

### 3.3 Redaction decision (G5)

**Chosen**: `domain` stays plaintext; `local-part` is replaced by a stable, non-reversible hash
(`sha256(local-part)[:12]`) in the stored key, title, and body — plaintext addresses are never
written into the vault.

**Rationale**: `memory-retrieve.sh` (verified by reading the script) scores corpus-wide by
keyword overlap plus a topic/category bonus (lines 74-102) with **no namespace filter at all**
— before Phase 5's G4 fix ships, a plaintext email address in a preference memory's title/body
is exactly the kind of >4-char, non-stopword token that would pass the keyword filter and could
surface in an unrelated task's `<memory-context>`. Even after the G4 fix, hashing is
defense-in-depth: debugging only needs *consistency* (same input -> same hash, so a dominant
sender is recognizable across visits and the derived dominant-action trend is auditable), not
*reversibility* — an operator who genuinely needs the real address can cross-reference the
email extension's own notmuch tags/manifests, which retain it. Freemail/shared domains
therefore get `domain + hash(local-part)`; non-freemail domain-rollup keys (§2.2 step 5) need
no hash since they never carried a local-part.

### 3.4 `category: preference` frontmatter field (G7)

**Add now**, schema-additive and non-breaking. Verified via `grep -rl "^category:"
.memory/10-Memories/*.md` (0 of 19 existing memory files have this field — the `category` seen
in `memory-index.json` entries is a derived index-level field synthesized from `tags`, never a
real frontmatter field on any `.md` file today). This design is the first real use of a
frontmatter `category:` field. `index.md`/`/distill` should recognize `category:` when present
(preferring it over the tags-derived heuristic) and continue to fall back to the existing
tags-derivation when absent — never required, never breaking for the other 19 memories.

### 3.5 Memory body template

```markdown
---
title: "Email preference: {domain-or-hash-key}"
created: {today}
tags: [email, preference, {domain}]
topic: "email/preferences/{account}/{key}"
source: "skill-email-cleanup harvest"
modified: {today}
keywords: [{domain}, email, preference]
summary: "Confirmed-decision tally for {domain-or-hash-key}: {dominant_action} ({dominant_count}/{total})"
retrieval_count: 0
last_retrieved:
category: preference
---

# Email preference: {domain-or-hash-key}

**Tally**: delete={delete_count} (last: {delete_last_seen}), archive={archive_count}
(last: {archive_last_seen}), keep={keep_count} (last: {keep_last_seen})
**Dominant action** (derived): {dominant_action}
**Evidence**: junked {delete_count + archive_count}, kept {keep_count}

## History

- {date}: +{action} (n={n_this_round}, scope={inbox|archive})

## Connections
<!-- Add links to related memories using [[MEM-filename]] syntax -->
```

Schema fields map 1:1 to what Phase 4's operations read/write (verified below).

---

## 4. Deterministic Dedup + Operation Mapping (G3)

### 4.1 Exact-key dedup short-circuit

Before the existing fuzzy keyword-overlap path (`skill-learn/SKILL.md`'s "Classification
Thresholds" section: >60% overlap=HIGH/UPDATE, 30-60%=MEDIUM/EXTEND, <30%=LOW/CREATE), the
harvest runs an **exact topic-key lookup**:

```bash
jq --arg k "email/preferences/${ACCOUNT}/${KEY}" \
  '.entries[] | select(.topic == $k)' .memory/memory-index.json
```

A hit short-circuits straight to UPDATE/EXTEND (§4.3) without ever computing keyword overlap.
This is a **sanctioned, explicitly documented deviation** from skill-learn's fuzzy 60%/30%
contract — the reserved `email/preferences/*` namespace opts out of fuzzy classification because
the identity key (Phase 2) is already a deterministic, verified normalization; re-deriving it
via keyword overlap would be strictly worse (fuzzier) than the key itself.

### 4.2 Fuzzy path retained as near-miss suggestion only

When no exact key matches, the existing fuzzy search still runs as a **suggestion**, e.g.
flagging `email/preferences/gmail/mail.foo.com` as a near-miss of an existing
`email/preferences/gmail/foo.com` entry — presented to the human at gate time (§5.4), never
auto-applied. Absent an exact match, the default action is CREATE.

### 4.3 Operation mapping

| Trigger | Operation | Tally effect |
|---|---|---|
| No exact-key match (first sighting) | **CREATE** | Initialize the tally: the confirmed action's counter = this round's count, other two = 0, `last_seen` set for that action only. |
| Exact-key match; this round's dominant action == stored dominant action | **EXTEND** | Append a dated `## History` line; bump the matching counter; update that action's `last_seen`. Existing content is never rewritten. |
| Exact-key match; this round's dominant action != stored dominant action | **UPDATE** | Increment the *opposite* counter (never overwrite/reset the matching one) — this can flip the *derived* dominant action per §3.2's tie-break rule; move the prior summary line to `## History` marked `(superseded)`. |

Contradiction handling is **tally arithmetic**, matching Conflict 2's resolution: no bespoke
decay/EWMA engine, no new skill-learn API verb — UPDATE/EXTEND/CREATE as they already exist,
applied to a body-level counter block instead of full-content replacement.

### 4.4 Batch index regeneration

Reuse skill-todo's batch-regen *logic* (`skill-todo/SKILL.md` harvest stages): **one**
`memory-index.json` regeneration after the entire harvest round (all buckets in one `--all`
sweep, or the single confirm set in one default-mode Stage 6 pass), not a regen per individual
CREATE/UPDATE/EXTEND call — matches how skill-todo already batches its own memory-harvest index
update rather than writing the index file once per candidate.

---

## 5. Retrieval/Distill Guardrails, Feedback-Loop Caps, Gate, and Scope Decisions (G4, G6)

### 5.1 G4 (part a) — `/distill` zero-retrieval exemption

`skill-distill/SKILL.md`'s Scoring Engine "Component 2: Zero-Retrieval Penalty" (verified) and
the Purge Sub-Mode's "Purge Candidate Identification" OR-condition (verified) compute purge
candidates as: `retrieval_count==0 AND days_since_created > 30`. **Chosen mechanism**: add a
topic-prefix exemption to that
condition — `retrieval_count==0 AND days_since_created > 30 AND NOT topic starts_with
"email/preferences/"`. Rejected alternative: making email-side reads increment
`retrieval_count`. Rationale: `memory-retrieve.sh` is invoked only by the research/plan/
implement-phase preflight (verified: no other caller exists in this repo); teaching
`skill-email-cleanup` to independently mutate `memory-index.json`'s `retrieval_count` on every
lookup introduces a second uncoordinated writer to that file for a benefit (staleness signal
accuracy) fully achievable with a one-line filter-scope addition to the existing purge query.

### 5.2 G4 (part b) — cross-contamination fix in `memory-retrieve.sh`

Verified: the scoring block (`memory-retrieve.sh:74-102`) has no namespace/task-type filter; the
`>4-char` stopword filter (line 54, 60) does not drop proper nouns (`github`, `google`,
`notifications` all pass). **Chosen mechanism**: add a pre-filter step before scoring —

```
map(select(
  ((.topic // "") | startswith("email/preferences/")) and ($tt != "email")
  | not
))
```

Since the research/plan/implement phases never invoke this script with `task_type == "email"`
(the email extension is direct-execution, not task-typed — confirmed no `email` task type
exists in the core routing table), this is effectively an **unconditional exclusion** from the
general auto-retrieval path today, while leaving the door open for a deliberate future
email-side reader to pass `task_type="email"` explicitly and see its own namespace.

### 5.3 G6 — feedback-loop guardrails

A stored preference may **only ever contribute as a surfaced tally** in the gate/bucket-review
prompt (e.g. "junked 14, kept 2 — no matching custom rule"), never by auto-setting
`proposed_action` or silently raising `confidence` past what `classify_one()`'s deterministic
rule table already computes (`wrapper-contracts.md` §5c, frozen constants). The vault stays
strictly advisory relative to the frozen classifier — this is what prevents automation bias from
entrenching an early mistake into a self-reinforcing loop. Reversal mechanism: Phase 4's tally
already accepts contradicting confirms via the UPDATE path (§4.3), so a wrong preference
self-corrects through ordinary continued use; no new "weaken/contradict" primitive is required
for correctness (a revocation/edit UX is a UX nicety, recommended for 822 scope in §5.5, not a
correctness requirement).

### 5.4 Gate behavior

One consolidated, **never-silent** `AskUserQuestion` prompt, adjacent to the just-approved
action (immediately following Stage 2.5 bucket approval in `--all` mode, or immediately
following Stage 6 Verify in default mode) — reusing skill-todo's harvest -> dedup -> tiered-gate
-> batch-regen **logic**, not its `state.json` substrate (§1.3):

- **Tier 1** (pre-selected): buckets/keys meeting the evidentiary threshold (§1.4) outright this
  round.
- **Tier 2** (shown, not pre-selected): keys newly crossing the rolling-N threshold this round.
- Fuzzy near-miss suggestions (§4.2) surfaced as a labeled option, not auto-selected.

Independent of the `--clean` flag: `--clean` only suppresses *auto-retrieval* for the
research/plan/implement-phase preflight (per CLAUDE.md's Memory Extension section); it has no
relationship to this harvest-side *write* gate, which always runs when the evidentiary threshold
is met, `--clean` or not.

### 5.5 Scope decision — fold into 822 (not 823/824)

**Recommendation**: fold revocation/edit UX, cross-account scoping, archive-scope isolation, and
a minimal success-signal phase **into 822's scope**, rather than spawning a separate follow-up task
(measurement/audit split) at this time. 822 is already queued and depends on 821
(`specs/state.json`: `project_number: 822`, `task_type: meta`, `dependencies: [821]`,
`status: not_started`) — the same batch this task belongs to. Rationale: each item below is
individually small (roughly one `AskUserQuestion` branch, one key-prefix decision, one flag
check, one log line) and tightly coupled to the write path 822 already builds; splitting into a
separate task would add coordination overhead (a new dependency edge, a second review pass) with
no corresponding benefit, unlike the *read-back* engine (§6, genuinely a second consumer/loop
closure — that one remains a real follow-up-task candidate) or the cross-client generalization note
(§7, explicitly speculative, not spawn-worthy today).

**Concrete additions recommended for 822's implementation plan**:

- **Cross-account key scoping**: prefix the stored key by account —
  `email/preferences/{gmail|logos}/{key}` — never collapse across accounts by default; gmail and
  logos are distinct mail identities that may have divergent sender behavior for what looks like
  "the same" domain.
- **Archive-scope isolation**: tag archive-scope-sourced confirms distinctly (a separate tally
  sub-section in the same memory, e.g. `### Archive-scope tally`, not a separate memory — this
  preserves the "one evolving memory per sender/domain" invariant while preventing a burst of
  old archive-triage confirms from silently dominating a sender's current-inbox dominant action).
- **Revocation/edit UX**: an explicit, user-invoked "forget this preference" action reusing the
  existing tombstone pattern (`skill-distill/SKILL.md`'s Purge Sub-Mode "Tombstone Application"
  subsection, shared by the Merge Sub-Mode's own "Tombstone Application" subsection -- verified)
  or a tally reset — never automatic, distinct from `/distill --purge`.
- **Minimal success signal**: log a per-round agreement rate (confirmed action == memory's
  pre-round derived dominant action, when a memory existed prior to the round) as a harvest log
  line — no new dashboard; enough visibility for a future audit to detect drift.

---

## 6. Future: Read-Back Contract (Not in 822's Scope) (G8/D1)

The loop as scoped through 822 is **one-directional** (write-only): the vault becomes a
preference *log*, not a preference *engine*, without a consumer. This section specs a named
contract so 822's write schema stays lookup-ready, seeding a future follow-up task:

```
email_preference_lookup(account, normalized_key)
  -> { dominant_action, confidence_tier, tally: {delete_count, archive_count, keep_count},
       last_seen } | null
```

**Intended future consumers** (not implemented by 822):

1. A new rule tier in `email-classify`'s classification, inserted between the `CUSTOM_*` rules
   and `NEWSLETTER_KEYWORDS` (wrapper-contracts.md §5c's tier table) — reading the vault at
   classify time to *advise*, subject to the same G6 cap (§5.3): it may only ever inform, never
   silently raise confidence past the frozen rule table's own output. This would require a
   wrapper-contract change (the wrapper is frozen) or a pre/post-processing layer outside the
   wrapper binary itself — out of scope to design further here.
2. A Stage 2.5 bucket-review advisory annotation ("this bucket has a stored vault preference:
   archive x14, delete x2 -> lean archive") shown alongside the bucket, purely informational,
   requiring no wrapper change since it only touches the skill's own presentation layer.

Filed as the seed for a future follow-up task. Not implemented in 822.

---

## 7. Deferred Design Notes (D4/D5) — Document, Do Not Adopt

- **Generalizing the confirmed-decision -> preference harvest pattern beyond email** (fix-it
  triage, task-abandonment reasons, PR-review nits): the pattern is plausible but should only be
  extracted once a **second real client** justifies it — email stays "the first client." Do not
  speculatively generalize the `email/preferences/{key}` namespace or harvest logic now.
- **Notmuch-ruleset export** (flag only, do not adopt): would strengthen loop-closure but
  changes the human-gated safety posture this entire design protects — a preference memory
  silently becoming an executable notmuch rule bypasses the review gate. Any future exploration
  of this must re-litigate the safety model from scratch, not extend this design.
- **Local-model training-data use of preference memories** (flag only, do not adopt): raises
  consent/redaction questions beyond this task's scope; the §3.3 hashing decision was made for
  in-repo leakage prevention, not for training-data-safe anonymization, and should not be
  mistaken for the latter.

## 8. `email-preferences.md` Remains a Distinct, Parallel Layer

`.claude/extensions/email/context/project/email/email-preferences.md` is a **historical harvest
document** recording the prior-art static classifier rule table (custom domain-delete rules,
keyword-fallback tiers) — the live compiled constants it describes
(`CUSTOM_KEEP_SENDERS`/`CUSTOM_DELETE_DOMAINS`/`NEWSLETTER_KEYWORDS`/`NOTIFICATION_DOMAINS`) live
in the frozen `~/.dotfiles/modules/home/email/agent-tools.nix` wrapper (wrapper-contracts.md
§5c). The vault preference layer designed here is **parallel and agent-visible**, never
auto-written into that compiled table. Any future promotion of a vault-derived preference into
the classifier's hardcoded rules is a distinct, separately human-reviewed action (e.g. a
deliberate "promote to custom rule" step a human runs manually against the `.dotfiles` repo) —
never automatic, and out of scope for both 821 and 822.

---

## Summary: G1-G8 Resolution Index

| Gap | Resolved in | One-line resolution |
|---|---|---|
| G1 (evidentiary threshold) | §1.4 | Uniform-batch OR rolling N>=3 at >=80%, evaluated against the stored tally. |
| G2 (identity key + verification) | §2 | `lower(local@domain)`, plus-tag stripped, freemail never rolled up; verified against 2,128 real tagged messages. |
| G3 (deterministic dedup) | §4.1-4.3 | Exact `topic==` short-circuit before fuzzy; CREATE/EXTEND/UPDATE mapped to tally arithmetic. |
| G4 (namespace segregation, distill exemption, cross-contamination) | §5.1-5.2 | Purge-filter topic-prefix exemption; `memory-retrieve.sh` topic-prefix pre-filter. |
| G5 (redaction) | §3.3 | Domain plaintext, local-part hashed (`sha256[:12]`). |
| G6 (feedback-loop guardrails) | §5.3 | Advisory-only surfacing, capped below the frozen classifier's own confidence; tally itself is the reversal mechanism. |
| G7 (`category: preference` field) | §3.4 | Added now, schema-additive, first real use of the field. |
| G8 (read-back contract) | §6 | Named `email_preference_lookup` contract, seeded for a future follow-up task, not implemented in 822. |

## Non-Goals Reaffirmed

No production code was written for this document. `email-preferences.md`'s static rule table is
untouched. The frozen wrapper (`~/.dotfiles/modules/home/email/agent-tools.nix`) was read
read-only for verification and was not modified. The one live-mail interaction performed during
design (§2.3) was a verified read-only `--emit-tagged` call — no `notmuch tag`, no maildir
mutation, no `--execute` invocation of any wrapper.
