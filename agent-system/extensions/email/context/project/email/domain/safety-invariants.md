# Safety Invariants (Operational Contract for `email`-Typed Work)

The non-negotiable operating rules for every `email` task, `/email` invocation, and
`email-implementation-agent` dispatch. Each invariant states the rule and names the domain file
carrying its full derivation; nothing here is optional or context-dependent.

## Role and Loading Model (read this before treating this file as inert)

This file is **on-demand reference material** — resolved only when something (a human auditor,
or an agent that chooses to `Read` it) decides it needs the full derivation of an invariant. It
is deliberately **not eager-loaded at any tier**: not a session-start `@`-import in a merged
`CLAUDE.md` fragment, and not read in full by any skill or agent body at its own invocation time
either. That is a decided, evidenced choice, not an oversight:

1. **The operationally load-bearing rules are already duplicated inline**, in prose short enough
   to cost nothing extra to load, in the four bodies that actually gate a mutation — each read
   in full by the harness at its own invocation time (Skill/Agent-tool tier, not session-start):
   `agents/email-implementation-agent.md`, `skills/skill-email-cleanup/SKILL.md`,
   `skills/skill-email-sync/SKILL.md`, `skills/skill-email-implementation/SKILL.md`. The coverage
   map below confirms, invariant by invariant, that every rule here has at least one inline
   counterpart in one of those four, or is enforced independently of any markdown (next point).
2. **Two mechanical layers hold with zero markdown loaded at all**: `hooks/mail-guard.sh` (a
   PreToolUse hook allowlisting the five wrapper binaries by name and denying raw
   `himalaya`/`msmtp`/`secret-tool`/Maildir-`rm` commands) and the nix-built wrapper binaries'
   own baked-in checks (hash verification, manifest-expiry/staleness refusal, the
   `MAX_BATCH_SIZE` cap, and `--account` enum validation). Both hold even in a session where no
   email markdown was ever read.
3. **Measured cost of the rejected alternative**: eager-loading this file alone would cost
   roughly 1.4k tokens on every session where the email extension is loaded; eager-loading all
   five domain files (this one plus `wrapper-contracts.md`, `index-architecture.md`,
   `staleness-detection.md`, `archive-mode-risk.md`) would cost roughly 13k tokens per session —
   paid whether or not that session ever touches an `email` task. Given point 1 and point 2
   already carry the enforcement, that recurring cost buys nothing.
4. **Editor's instruction**: if you change a rule, threshold, or constant in this file, you MUST
   also update its inline counterpart in whichever of the four consumer bodies the coverage map
   below names for that invariant — and vice versa. The two copies are allowed to exist because
   they are kept in sync by convention, not by a shared source; drift between them is the
   accepted cost of this decision (see the coverage map's Notes column for anything worth
   watching), not a defect to "fix" by deleting either copy.

### Enforcement-Coverage Map

Built by re-reading every section below against the four consumer bodies and the two mechanical
layers. Verdict: **full coverage** — every invariant has at least one inline consumer copy or one
independent mechanical layer; none is covered by neither.

| Invariant | Inline in consumer(s) | Mechanical layer | Notes |
|-----------|------------------------|-------------------|-------|
| Wrapper-Only | `email-implementation-agent.md` ("MAY invoke... ONLY" + MUST NEVER), `skill-email-cleanup` (intro + Five Wrapper Binaries table + MUST NOT), `skill-email-sync` (MUST NOT #2), `skill-email-implementation` (Stage 4 wrapper-only bullet) | `mail-guard.sh` `ALLOWED_BINARIES` allowlist + `DENY_PATTERNS` | Broadest coverage of the eleven; all four consumers plus the hook |
| Two-Layer Enforcement | `email-implementation-agent.md` ("Two-layer enforcement model" section) | `mail-guard.sh` header comment (layer 1) + the wrapper binaries themselves (layer 2) | The invariant is self-referential — it names the two mechanical layers it is itself enforced by |
| Propose-Review-Confirm-Execute | `email-implementation-agent.md` (Propose→review→confirm→execute stages), `skill-email-cleanup` (Stages 3-6 + MANDATORY INTERACTIVE REQUIREMENT), `skill-email-implementation` (Stage 4 bullet) | Wrapper recomputes the manifest hash on `--execute --confirm-manifest` and refuses on mismatch | `patterns/propose-review-confirm-execute.md` holds the full lifecycle prose |
| Delete Is Himalaya-Level Only | `email-implementation-agent.md` (MUST NEVER `rm` against Maildir), `skill-email-cleanup` (MUST NOT #2; Archive gate 4 reversible-then-hard two-phase), `skill-email-sync` (Trash/Archive landing + expunge irreversibility) | `mail-guard.sh` `DENY_PATTERNS` (`rm.*Mail`, `himalaya ... delete/move/expunge`) | |
| `$PATH` Precondition | All four consumers each carry their own precondition check (agent, `skill-email-cleanup`, `skill-email-sync` for `mbsync`, `skill-email-implementation` Stage 3a) | None — this is a consumer-side check only; no wrapper binary self-verifies its own `$PATH` presence | Only invariant with zero mechanical layer; coverage rests entirely on the four inline copies |
| Index-Freshness Gate | `skill-email-cleanup` only (Staleness Remediation section, Stage 1 census freshness line) | `email-census` itself computes the on-disk-vs-indexed divergence baked into its output | Not restated in the other three consumer bodies — narrower than most rows, but the wrapper's own computation is independent of any markdown |
| Default-Mode Cursor | `skill-email-cleanup` only (Stage 2 cursor rule) | `email-classify` tags every processed message with a durable `+proposed-*` notmuch tag | `mode=default`-specific; the agent/sync/implementation paths execute a plan rather than branching on this cursor themselves |
| Sub-50 Transparent Drain (`--all`) | `skill-email-cleanup` (Constants + `--all` mode pattern reference), `email-implementation-agent.md` (Constants), `skill-email-implementation` (Stage 4 Constants bullet) | Wrapper hard-refuses any `--execute` batch over `MAX_BATCH_SIZE` | Full `--all` mechanics live in `patterns/email-cleanup-all-mode.md`, referenced rather than re-inlined |
| Mtime-Preserve / Expiry-Stop | `skill-email-cleanup` (Constants + MUST DO #5), `email-implementation-agent.md` (Constants), `skill-email-implementation` (Stage 4 Constants bullet) | Wrapper refuses `--execute` on an expired manifest (`PLAN_EXPIRY_DAYS`) | |
| Archive Extra Gates (`--archive`) | `skill-email-cleanup` only (Archive Scope section + Pilot Gate section) | None beyond the standard confirm-manifest/batch-cap machinery — these gates are skill-side policy, not wrapper-enforced | Narrowest mechanical coverage of the eleven; enforcement is entirely inline in one consumer. Acceptable because `--archive` is a `skill-email-cleanup`-only scope flag — neither the agent nor the sync skill ever branches on it |
| Account Isolation, Folder-Scoped Only | `skill-email-cleanup` (Stage 0 account/`BASE_QUERY` table), `skill-email-sync` (channel derived from account) | Wrapper binaries validate `--account` as a live enum, rejecting an unknown value loudly | Not restated in the agent or `skill-email-implementation` bodies, which never branch on `--account` themselves |

## Wrapper-Only

Agents may invoke ONLY these five nix-built binaries by name: `email-census`, `email-classify`,
`email-archive-confirmed`, `email-delete-confirmed`, `email-unsubscribe-extract`. Raw
`himalaya` / `notmuch` / `msmtp` / `secret-tool` calls are prohibited.

Sanctioned NON-wrapper exceptions (index/sync only, never mail mutation):

- the group-scoped `mbsync` reconcile invoked by `/email --sync`, and
- the `email-reindex` operator helper (index-only `notmuch new --no-hooks`).

A raw `notmuch new` stays forbidden — it triggers `preNew = mbsync -a`.
See `wrapper-contracts.md` §1 (binaries, safety classes) and §13 (reindex).

## Two-Layer Enforcement

1. **`mail-guard.sh` PreToolUse hook** — social/technical layer 1, per-machine, may be
   gitignored. Allowlists the five wrapper binaries and denies raw destructive mail commands.
2. **The nix-built wrapper source itself** — layer 2, always present: hash check, staleness,
   batch cap, and state file are baked into the binaries.

Neither layer is sufficient alone. The guard allowlists the five binaries **by NAME only**, not
by account or flag; multi-account support was added as an `--account` flag on those same five
binaries rather than as new binary names, so the guard's allowlist is unaffected by the account
dimension and needed no change for it. See `wrapper-contracts.md` §8.

## Propose-Review-Confirm-Execute

Mutation binaries are dry-run by default; `--execute` requires `--confirm-manifest <sha256>`
over a human-reviewed, git-tracked manifest. The mandatory human review gate (per-message or
bucket) precedes every mutation, always. Full lifecycle:
`../patterns/propose-review-confirm-execute.md`; flag contract: `wrapper-contracts.md` §2;
approval provenance: §6.

## Delete Is Himalaya-Level Only

Delete is an IMAP/maildir-level Himalaya operation, never a raw filesystem `rm` against Maildir.
Move-to-Trash and `--expunge-trash` are independently human-gated hops with separate state
files. See `wrapper-contracts.md` §7 and the reversible-vs-hard boundary in
`archive-mode-risk.md`.

## `$PATH` Precondition

Agents must verify the wrapper binaries are on `$PATH` (nix/home-manager built) before invoking
any of them, and fail with an actionable message (`run home-manager switch`) rather than a raw
"command not found". See `wrapper-contracts.md` §9.

## Index-Freshness Gate

Classification reads notmuch and there is no auto-indexer, so `--all` runs a staleness gate
before claiming whole-mailbox coverage: it compares the `email-census` freshness line's on-disk
file count against a path-prefix post-filtered indexed-files count (a file-vs-file comparison
within a bounded tolerance, not strict equality) and reconciles with `email-reindex` when the
divergence exceeds tolerance. Never present a bucket approval as whole-folder coverage while the
line reads `[STALE]`. Full mechanism: `staleness-detection.md`; frozen facts:
`wrapper-contracts.md` §13.

## Default-Mode Cursor

Bare `/email` is bounded to 50 candidates per pass. The durable `+proposed-*` tags — expressed
ONLY as an `email-classify` QUERY exclusion, never as a wrapper flag — make successive runs step
forward instead of re-classifying the same newest 50. Pagination contract:
`wrapper-contracts.md` §10.

## Sub-50 Transparent Drain (`--all`)

The approved set is split caller-side into ≤50-lines-per-action sub-manifests
(`MAX_BATCH_SIZE=50` is FROZEN — never raised; the wrapper hard-refuses over cap and never
auto-chunks). After the single consolidated bucket approval the drain is mechanical and
progress-only, with idempotency via the wrapper's per-split `<manifest>.state.jsonl` only. Only
the read/tag-only classify sweep may run in the background; every review gate and every execute
call runs in the root session. See `wrapper-contracts.md` §4, §5, §5a and
`../patterns/bulk-bucket-review.md`.

## Mtime-Preserve / Expiry-Stop

Split sub-manifests carry the ORIGINAL approval mtime (`touch -r`); an expired split
(> `PLAN_EXPIRY_DAYS = 7`) STOPS the drain with a residual report — never a silent
re-timestamp, never a widened approval window. See `wrapper-contracts.md` §5b.

## Archive Extra Gates (`--archive`)

A second blast-radius-naming confirmation, a corroborated (rule-tier) confidence bar for bulk
deletes, reversible-then-hard two-phase deletes (`--expunge-trash` opt-in only), a bounded
per-account pilot gate before full scale (a Gmail pilot-ack never licenses a Logos archive-scope
run, or vice versa), and never auto-chaining `/email --sync` after a drain. These are ADDITIONS
on top of the standard gates, never replacements. Full rationale and per-account blast radius:
`archive-mode-risk.md`.

## Account Isolation, Folder-Scoped Only

The account (`--account <gmail|logos>` / `--logos`, default `gmail`) is resolved once per
invocation and threaded unchanged through every wrapper call; scoping is expressed exclusively
as `folder:` query tokens. An unknown `--account` value is rejected loudly, never coerced to
Gmail. Query forms, the deliberately-unused `tag:<account>` scheme, and per-account liveness:
`index-architecture.md`.
