# Anchor-Pointer Convention

**Created**: 2026-11-05
**Purpose**: Define the collapsed-block shape used when a markdown block restated across
multiple files is pointed at one durable anchor instead of being copy-pasted
**Audience**: Anyone editing markdown under `agent-system/extensions/**`

---

## What a Collapsed Block Looks Like

A collapsed block replaces a multi-line restatement with a **one-line reference** naming the
anchor's path and the exact section heading that owns the content, plus whatever the collapsing
file's own content genuinely varies (a value, a name, a per-file parameter) kept inline:

```
### Stage 0: Initialize Early Metadata

**CRITICAL**: Create metadata file BEFORE any substantive work. See
`context/patterns/early-metadata-pattern.md` § "Stage 0: Initial Metadata Creation" for the full
procedure and JSON shape. Use `agent_type: "nix-implementation-agent"` and
`delegation_path: ["orchestrator", "implement", "nix-implementation-agent"]`.
```

The reference names the anchor by repo-relative path (resolved from the extension root, matching
how this corpus already cites other standards/patterns files) and the heading text verbatim, so a
reader or a lint can locate the owning section without re-deriving it. A block legitimately
anchored by **two** different documents (e.g. the general procedure in one pattern file, a
narrower sub-obligation in a format file's own section) names both pointers rather than forcing
an artificial single anchor.

## The Two Hard Exclusion Classes

Not every restated block is a collapse candidate. Two classes are excluded on sight, before any
anchor search:

1. **Gate-required restatement.** A lint or gate performs a literal-presence check against the
   file's own text (not against a pointer) — collapsing the block would make the gate's own check
   fail, because the gate reads the file directly rather than following a reference. Recognize
   this class by reading the live fragment/predicate set out of the enforcing script at the time
   of the collapse, never from a hardcoded list in this document: `lint-agent-contracts.sh`'s
   `*_FRAGMENT` variables and `lint-postflight-boundary.sh`'s literal heading predicate are the
   two known enforcers today, and either may grow a new predicate later.
2. **Deliberate inlining.** An extension's own documentation states that a body of content is
   carried inline, adapted per destination file, rather than referenced by pointer (the email
   extension's safety-invariant content is the known case as of this writing). Recognize this
   class by checking whether the destination extension's own `CLAUDE.md` pointer section
   documents that convention for the content in question.

A block in either class is not collapsed, however many files restate it.

## The Claim-Retention Obligation

Collapsing a block is not just a line-count exercise — it must not lose a claim a reader could
previously verify in place. Every collapse records a **ledger entry** naming:

- the file collapsed and the block removed from it,
- every verifiable claim that block made (not a paraphrase of the whole block — the individual
  facts a reader could have checked), and
- the anchor section that retains each named claim, confirmed by re-reading that anchor at
  collapse time (not assumed from an earlier measurement pass).

A collapse with no ledger entry, or a ledger entry whose claims are not re-confirmed against the
anchor's current text, is incomplete. The ledger lives in the consolidation task's own plan
artifact, not in this standard, since this standard is permanent and the ledger is per-collapse
provenance.

## The Regression Lint

A collapsed block's defining risk is silent regression: a future edit reintroduces the restated
text in a file that already carries the pointer, or in a new file that never needed it in the
first place, quietly re-growing the duplication this convention removed. `lint/lint-anchor-
pointer-collapse.sh` guards against the first case: it reads a permanent registry
(`lint/collapsed-blocks/registry.tsv`) naming, per already-collapsed file, the exact block text
that must not reappear there, and fails if it does. Adding a newly collapsed file is a **data
edit** to that registry (append a row and a block-text file), never a change to the lint's own
code — see that script's own header for the registry format and the deliberate per-file scope
(it does not scan the whole corpus for every not-yet-migrated instance of the same text, since a
block mid-migration legitimately still exists in files no phase has reached yet).
