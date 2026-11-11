# Research Report: Task #488

**Task**: 488 - MCP write-tool grant ownership scope
**Started**: 2026-11-06T00:00:00Z
**Completed**: 2026-11-06T00:00:00Z
**Effort**: small (one standards edit + no functional code change expected)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
- Codebase: `agent-system/extensions/sapience/` (manifest.json, settings-fragment.json, EXTENSION.md, README.md, context/project/sapience/domain/review-gate-boundary.md)
- Codebase: `agent-system/extensions/nix/settings-fragment.json` (comparison precedent)
- Machine config: `~/.dotfiles/config/claude/settings.json`, `~/.dotfiles/modules/home/services/sapience.nix`, deployed `~/.claude/settings.json`, `~/.claude.json` (user-scope `mcpServers`)
**Artifacts**:
- This report: `specs/488_mcp_write_tool_grant_ownership_scope/reports/01_mcp-ownership-scope-verdict.md`
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- The sapience extension's `settings-fragment.json` grants four MCP write tools
  (`sapience_remember`, `sapience_wrapup`, `sapience_handoff`, `sapience_adddoc`) at this
  repository's project scope, while the sapience server itself is registered at **user** scope
  (`~/.claude.json`'s top-level `mcpServers`). Read literally,
  `context/patterns/mcp-server-ownership.md`'s "Grant permissions at the same scope where the
  server is registered" rule calls this a scope mismatch: a user-scope registration should be
  granted in user-scope `~/.claude/settings.json`.
- That rule was written without an exception for a settings file an extension cannot durably
  edit. `~/.claude/settings.json`'s `permissions` key is one of the enforced keys
  `home.activation.claudeSettings` resets from `~/.dotfiles/config/claude/settings.json` on
  every `home-manager switch` — confirmed directly: the deployed file and the dotfiles source
  are byte-for-byte identical in their `permissions.allow` list. A hand-edit from this repo, or
  from any extension's deploy pipeline, would be silently reverted at the next switch.
- `~/.dotfiles/config/claude/settings.json` already grants seven **read-only**
  `mcp__sapience__*` tools (`sapience`, `sapience_search`, `sapience_briefing`,
  `sapience_context`, `sapience_ask`, `sapience_outstanding`, `sapience_papers`) at user scope.
  The four **mutating** tools are conspicuously absent from that list — not an oversight the
  extension is patching around, but a deliberate narrower default the dotfiles maintainer chose,
  which the extension's own project-scope grant deliberately widens for exactly one repository.
- **Verdict**: the repository-scoped placement is correct and should NOT move to
  `~/.dotfiles`. Moving it there would grant unattended, unreviewed vault-write access to every
  project on the machine — a strictly worse security posture for a destructive/mutating
  personal-vault capability than the current one-repo blast radius. The fix is to amend
  `mcp-server-ownership.md` itself with an explicit carve-out naming this pattern, rather than
  move the grant. This report recommends the carve-out's exact text (see Recommendations).
- Disclosure (part b of the task) is **already present** at the two most load-bearing
  surfaces — `EXTENSION.md` (merges into `.claude/CLAUDE.md`, ambient to every dispatch) and
  `context/project/sapience/domain/review-gate-boundary.md` (detailed tradeoff narrative). The
  actual gap is that the canonical standard itself, `mcp-server-ownership.md` — the document a
  future extension author actually consults before writing a new grant — says nothing about this
  case, so the sapience placement currently reads as an undocumented violation when checked only
  against that central doc.

## Context & Scope

Researched whether the sapience extension's project-scoped grant of four sapience MCP write
tools is a standards violation or a legitimate, undocumented exception, per the dispatch's
instruction to decide (not assume) two things: (a) whether `mcp-server-ownership.md` should be
amended to carve out the nix-enforced-settings case, or the grant should move to `~/.dotfiles`
and the extension stop granting it; (b) whether the repo-scoped write-tool grant needs
additional operator-visible disclosure. Scope was bounded to reading the standard, the sapience
extension's existing files, the home-manager module and dotfiles settings source that owns the
sapience server's registration, and one comparison extension (`nix`) that has a structurally
similar (but risk-different) grant shape, to check whether sapience is a one-off or part of a
recognized pattern.

## Findings

### Codebase Patterns

**Registration vs. permission axes (`mcp-server-ownership.md`).** The standard's governing rule
is: *"User-scope registration → grant in user scope, in `~/.claude/settings.json`... Project-scope
registration → grant in the owning extension's `settings-fragment.json`."* Sapience is
registered at user scope (confirmed: `sapience` is a top-level key in `~/.claude.json`'s
`mcpServers`, alongside `playwright` and `nixos`), so by the letter of the rule its grant belongs
in user-scope `~/.claude/settings.json`. The document already contains one explicit **carve-out**
to its own default (wildcard-over-enumeration) for safe/unsafe tool splits — the playwright
`browser_evaluate`/`browser_file_upload`/`browser_run_code_unsafe` tier is deliberately left
ungranted anywhere so it keeps prompting — but that carve-out still grants the safe tier at the
*same* scope as registration (user scope). It has no precedent for granting a tier at a
*narrower* scope than registration. That is the specific gap this task's finding identifies.

**The enforced-settings constraint is real and already load-bearing elsewhere in this repo.**
`~/.dotfiles/config/claude/settings.json` carries its own explanatory `_NOTE` field: on
`home-manager switch`, keys listed in `modules/home/core/dotfiles.nix` as enforced
(`_NOTE`, `env`, `hooks`, `model`, `permissions`, `statusLine`) are forced back to the dotfiles
values, and every other key keeps whatever the live file has. `permissions` is in that enforced
list. Directly diffing the deployed `~/.claude/settings.json` against the dotfiles source
confirms the `permissions.allow` arrays are identical, including the exact same seven
`mcp__sapience__*` read-only entries — there is no drift to exploit, and no mechanism by which an
extension deploy (which only ever writes into *this repository's* `.claude/`) could reach that
file at all, durably or otherwise. `modules/home/services/sapience.nix` states explicitly in its
own header comment why these entries sit in `config/claude/settings.json` rather than being
written by a vendor installer: `hooks` and `permissions` are enforced keys, so anything written
elsewhere would be reverted on the next switch.

**The four write tools are deliberately absent from the user-scope grant, not merely
unmigrated.** `~/.dotfiles/config/claude/settings.json`'s allow-list enumerates seven
`mcp__sapience__*` tools, all read/query-shaped (`sapience`, `sapience_search`,
`sapience_briefing`, `sapience_context`, `sapience_ask`, `sapience_outstanding`,
`sapience_papers`). `sapience_remember`, `sapience_wrapup`, `sapience_handoff`, and
`sapience_adddoc` — all four mutating tools — are absent. This machine-wide list was authored and
is maintained by the same person who authored this extension; its omission pattern already
functions as a tier split, structurally identical in shape (if not in stated rationale) to the
playwright safe/unsafe carve-out already in the standard: a safe tier granted broadly, a
higher-risk tier withheld from the broad grant.

**What makes the sapience write tools higher-risk than an ordinary mutating tool.** Per
`context/project/sapience/domain/review-gate-boundary.md`: the sapience MCP write-tool path
writes straight to the user's **hosted, cross-project, cross-session** personal knowledge vault
with **no staging and no review step** — confirmed from each tool's own description string in
`mcp.py` (`sapience_wrapup`'s description states each note "is saved to the user's persistent
cross-session memory"). This is unlike the transcript-extraction path (`sapience sync` /
`review` / `coverage`), which this machine's `config.json` gates with `auto_approve: false`, so
nothing reaches the vault without a human approving it first. The MCP write-tool path has no
equivalent gate. Granting these four tools machine-wide, unattended, would mean **every**
autonomous dispatch in **every** project on this machine could write permanently to the user's
personal/professional vault without review — a materially larger blast radius than granting them
in the one repository whose own lifecycle (`[IMPLEMENTING]` → `[COMPLETED]` postflight, 3-8
distilled notes per completed task, documented in `EXTENSION.md`) was deliberately designed
around bounding how often and from what source the write happens.

**A structurally similar but risk-different precedent already exists, undiscussed: the `nix`
extension.** `agent-system/extensions/nix/settings-fragment.json` grants
`mcp__nixos__nix` and `mcp__nixos__nix_versions` at project scope, for a server (`nixos`)
registered via a home-manager activation block — the same "project-scope grant for a
user-scope-registered, externally-owned server" shape as sapience. The difference: both tools are
read-only queries, and both are *also already present* in `~/.dotfiles/config/claude/settings.json`'s
user-scope grant. `mcp-server-ownership.md`'s own "Known gaps" section calls this out as a
deliberate retention ("**Do not** delete those two grants") but frames it purely as a
registration-naming migration record, not as an instance of the scope question this task raises —
because for `nix` there is no gap to close (the user-scope grant already exists), so the
project-scope copy is harmless duplication, not a load-bearing fix. This confirms the sapience
case is not sui generis in its *shape*, but it is the first instance where the project-scope
grant is the *only* grant for a risk-bearing tool tier, which is what makes it worth a standards
amendment rather than a one-off footnote.

**Disclosure already exists at the extension layer.** Three files already state this tradeoff in
detail: `EXTENSION.md` ("`settings-fragment.json` grants the four MCP write tools... at this
repo's project scope -- repository-scoped, not machine-wide; see
`domain/review-gate-boundary.md`"), which merges into `.claude/CLAUDE.md` and is therefore
ambient context for every dispatch including subagents; `README.md`'s "Repository-scoped, not
machine-wide" paragraph; and `review-gate-boundary.md`'s "The Permission Grant's
Repository-Scoped Tradeoff" section, which already names `mcp-server-ownership.md`'s canonical
rule by file path and states explicitly that the project-scoped grant is a deliberate exception
to it. What is missing is the mirror-image pointer: `mcp-server-ownership.md` itself says nothing
back, so a reader who starts from the standard (rather than from the sapience extension's own
docs) has no way to discover that this case is a sanctioned exception rather than an
unaddressed violation.

### External Resources

Not applicable — this is a self-contained repository-configuration question with no external
documentation dependency (the behavior of Claude Code's settings-merge precedence and MCP
registration/permission axes is already fully documented in-repo per the Codebase Patterns
findings above).

## Recommendations

1. **Amend `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`'s "Permission"
   section** with a new subsection, sibling to the existing "Carve-out: safe/unsafe tool splits
   require enumeration" subsection, naming the pattern explicitly. Suggested content (for the
   plan phase to adapt into the file's own voice and cross-link conventions):

   > **Carve-out: narrower-than-registration grants for an externally-owned, enforced user-scope
   > settings file.** The "grant at the same scope as registration" rule assumes the matching
   > user-scope settings file is one this repository's own deploy pipeline can durably write. It
   > is not always: a user-scope settings file an outside system (e.g. a home-manager
   > activation block) resets from its own source on every rebuild cannot be durably edited by
   > an extension's deploy — any such edit is silently reverted. When that owning system has
   > already drawn a safe/unsafe line for the registered server (granting a read/query tier
   > broadly and withholding a mutating tier), an extension MAY grant the withheld tier at this
   > repository's own project scope instead, bounding unattended access to exactly the
   > repositories that opt in, rather than attempting (and failing) to widen the externally-owned
   > grant. This differs from the safe/unsafe carve-out above: that one leaves the unsafe tier
   > permanently prompting everywhere; this one grants it, deliberately, in one repository only.
   > Requirements: (1) explicit, enumerated tool names, never a wildcard, so a newly added tool on
   > the server does not silently inherit the narrow grant; (2) the extension's own docs must
   > state the tradeoff and link back to this section; (3) do not attempt to "fix" the apparent
   > mismatch by hand-editing the enforced file — that edit does not survive the next rebuild. See
   > the sapience extension's `settings-fragment.json` and
   > `context/project/sapience/domain/review-gate-boundary.md` for the worked example: four
   > `mcp__sapience__*` write tools granted at project scope in the one repository where
   > unattended vault writes were deliberately decided to be acceptable, while the user-scope
   > dotfiles grant deliberately withholds them from every other project.

2. **Do not move the sapience grant to `~/.dotfiles`.** Moving it would grant unattended,
   unreviewed personal-vault write access to every project on the machine, which is a strictly
   worse security posture than the current one-repository blast radius — this is a case where
   the narrower-scope placement is the more secure choice, not merely the only choice the
   extension can durably make. State this explicitly in the amended standard (point 1) so a
   future reader does not independently "fix" it toward the wider grant.

3. **No new disclosure surface is needed on the extension side.** `EXTENSION.md`, `README.md`,
   and `review-gate-boundary.md` already state the tradeoff in full; the implementation phase's
   only required change there is adding the back-link to the new `mcp-server-ownership.md`
   subsection (once it exists) so the two sides of the pointer are symmetric, per
   `review-gate-boundary.md`'s existing style of naming the standard by file path.

4. **Implementation-phase mechanics** (for the plan phase to sequence): edit
   `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` at the source store
   path (never the deployed `.claude/` copy — see `rules/source-store-deploy-boundary.md`); add
   the cross-link in `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md`;
   redeploy via `timeout 540 bash .claude/scripts/deploy-headless.sh` (Bash tool timeout raised to
   600000ms); verify `verify-deploy.sh` is green afterward. No change to
   `agent-system/extensions/sapience/settings-fragment.json` itself is required — its content is
   already correct under the verdict this report reaches; only the standard that judges it needs
   to change.

## Decisions

- **The sapience extension's project-scoped write-tool grant is correct as-is and is not a
  standards violation.** It is an undocumented-but-legitimate exception to
  `mcp-server-ownership.md`'s general scope-matching rule, and the fix is to document the
  exception in the standard, not to change the grant's placement.
- **The grant must not move to `~/.dotfiles`.** A machine-wide grant for unreviewed personal-vault
  write tools is a worse security posture than the current repository-scoped one; "matching the
  registration scope" is not an unconditional good when the wider scope increases the blast
  radius of an unreviewed, destructive capability.
- **Explicit enumeration (not a wildcard) is a requirement of this carve-out, not an incidental
  detail.** A future new sapience write tool must not be silently granted at project scope
  without a deliberate decision to add it.
- **No additional operator-visible disclosure is needed at the extension layer.** The existing
  `EXTENSION.md`/`README.md`/`review-gate-boundary.md` disclosure already satisfies part (b) of
  the task; the only disclosure gap is the standard's own silence, addressed by recommendation 1.

## Risks & Mitigations

- **Risk**: a future reader skims only `mcp-server-ownership.md`'s existing rule, concludes the
  sapience grant is broken, and "fixes" it by moving the four tools to `~/.dotfiles`.
  **Mitigation**: the new carve-out subsection explicitly names this as the wrong fix and states
  why (recommendation 2), not merely documenting the current state neutrally.
- **Risk**: the carve-out is phrased broadly enough that any extension can use it to justify an
  arbitrary narrow-scope grant, eroding the general "same scope as registration" rule.
  **Mitigation**: the carve-out's three stated requirements (externally-enforced file,
  pre-existing safe/unsafe split by the owning system, explicit enumeration) narrow it to the
  sapience shape specifically; it does not apply to a server with no pre-existing tier split, nor
  to one whose user-scope file the repo's own deploy could durably edit.
- **Risk**: redeploy after the standard edit could surface unrelated staleness in `core`/`lean`
  (the dispatch's own `<deploy-freshness-context>` already flags both as stale relative to the
  source store before this task's edit). **Mitigation**: the implementation phase's redeploy step
  will pick up all pending source-store changes for every extension, not just this one edit;
  `verify-deploy.sh` going green afterward is the acceptance gate regardless of which extensions'
  changes it is validating.

## Context Extension Recommendations

- **Topic**: cross-repository settings ownership (nix-enforced `~/.claude/settings.json` vs.
  repo-owned `.claude/settings.local.json`).
- **Gap**: `mcp-server-ownership.md` documents the registration/permission split thoroughly but,
  before this task, had no language acknowledging that a user-scope settings file can itself be
  externally owned and un-editable by this repo's own tooling — an assumption the rest of the
  document's "grant at the same scope as registration" rule silently depends on.
- **Recommendation**: the carve-out in Recommendation 1 above closes this specific gap. No
  further context file is needed; the amendment belongs in the existing standard rather than a
  new document, since it is a refinement of that document's own central rule, not a new topic.

## Appendix

### Search queries / commands used

- Read `.claude-extensions.json` for the sapience and nix extensions' `source_dir` and merge
  targets.
- Read `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` in full (443
  lines) — confirmed no mention of `dotfiles`, `sapience`, or `nix-enforced` anywhere in the
  file via `grep`.
- Read `agent-system/extensions/sapience/manifest.json`, `settings-fragment.json`,
  `EXTENSION.md`, `README.md`, `context/project/sapience/domain/review-gate-boundary.md`.
- Read `~/.dotfiles/config/claude/settings.json`, diffed conceptually against deployed
  `~/.claude/settings.json` (both printed in full; `permissions.allow` lists identical).
- Read `~/.dotfiles/modules/home/services/sapience.nix` header comment for the enforced-keys
  rationale.
- Read `~/.claude.json` top-level `mcpServers` keys (`playwright`, `nixos`, `sapience`) to
  confirm sapience's registration scope is user, not project or local.
- Read `agent-system/extensions/nix/settings-fragment.json` as a comparison precedent.

### References

- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md`
- `agent-system/extensions/sapience/EXTENSION.md`
- `agent-system/extensions/sapience/README.md`
- `agent-system/extensions/sapience/settings-fragment.json`
- `agent-system/extensions/nix/settings-fragment.json`
- `~/.dotfiles/config/claude/settings.json`
- `~/.dotfiles/modules/home/services/sapience.nix`
- `.claude/rules/source-store-deploy-boundary.md`
