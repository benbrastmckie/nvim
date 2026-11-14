# Research Report: Task #620

**Task**: 620 - typescript_extension_design
**Started**: 2026-11-13T19:50:00Z
**Completed**: 2026-11-13T20:40:00Z
**Effort**: medium (research pass; a planning dispatch should consume this report directly)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/web/**` (source of the TypeScript-in-Astro content to split),
  `agent-system/extensions/rust/**`, `agent-system/extensions/python/**`, `agent-system/extensions/nix/**`
  (precedent extensions of varying complexity)
- Codebase: `agent-system/extensions/core/context/guides/extension-development.md`,
  `agent-system/extensions/core/context/guides/manifest-routing-schema.md`,
  `agent-system/extensions/core/context/guides/hard-mode-routing.md`,
  `agent-system/extensions/core/docs/guides/creating-extensions.md`,
  `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`,
  `agent-system/extensions/core/context/architecture/context-layers.md`,
  `agent-system/extensions/core/context/formats/return-metadata-file.md`,
  `agent-system/extensions/core/context/formats/report-format.md`
- Codebase: `agent-system/extensions/core/scripts/lib/task-type-detect.sh` (keyword_overrides /
  weak-signal collision surface), `agent-system/extensions/nix/scripts/nix-preflight.sh`
  (lifecycle-hook precedent)
- `.claude-extensions.json` (currently-loaded-extension inventory)
**Artifacts**:
- `specs/620_typescript_extension_design/reports/01_typescript-extension-design-research.md` (this report)
**Standards**: report-format.md, subagent-return.md, agent-frontmatter-standard.md,
manifest-routing-schema.md, extension-development.md, creating-extensions.md

## Executive Summary

- A new, framework-agnostic `typescript` extension can be built entirely on existing,
  already-proven mechanisms: the manifest shapes `rust`/`python` use for a lean two-agent
  extension, the `hard_contracts`/`keyword_overrides`/lifecycle-`hooks` blocks already documented
  in `extension-development.md` and `manifest-routing-schema.md`, and the `context/project/{domain}/`
  four-subdirectory convention every complex extension already follows.
- **No collision exists** for a new `typescript` `keyword_overrides` entry: the `web` extension's
  manifest declares **no** `keyword_overrides` block at all (verified by direct read), none of the
  six other manifests that declare one (`books`, `email`, `rust`, `cslib`, `typst`, `latex`)
  contain a TypeScript-adjacent keyword, and the core weak-signal fallback table
  (`task-type-detect.sh`) has no `typescript` row either (its `web` row is
  `web,astro,tailwind,cloudflare` — no overlap).
- `web`'s `context/project/web/domain/typescript-web.md` (304 lines) is almost entirely
  Astro-specific (Astro component Props, `astro:content`, `astro/types`, `astro check`,
  `.astro/types.d.ts`). Only two sub-sections are genuinely generic TypeScript/Zod content with
  zero Astro syntax: "Common Zod Patterns" (lines 204-232) and the underlying *concept* (not the
  Astro-flavored example) in "Import Aliases" (lines 234-247). The line-level split in
  `## Findings` below is the basis for a future extraction task.
- No lifecycle extension in this repository currently declares a `verification` hook — `nix` and
  `nvim` only use `preflight`/`context_injection`. The verification-stage hook this task requires
  is therefore new design, not an adaptation of an existing script; `## Recommendations` gives the
  full toolchain-detection and honest-degrade contract.
- `web`'s known duplicate-file problem (`astro-framework.md` and `tailwind-v4.md` each exist both
  at `context/project/web/` root and under `context/project/web/domain/`) is independently
  confirmed to still exist. The typescript extension's own context tree must place every new file
  under exactly one of `standards/`, `patterns/`, `domain/`, or `tools/` — never duplicated at the
  `context/project/typescript/` root — so this design does not add a second instance of the same
  defect class.
- Recommended model-tier assignment: both the `typescript-research-agent` and
  `typescript-implementation-agent` are Sonnet-tier (pattern-execution research/implementation,
  per `agent-frontmatter-standard.md`'s tiered policy) — this is a judgment call for the planner
  to confirm, not a measured fact, but it matches every comparable language extension
  (`rust`, `python`, `web`, `nix`) in this repository, all of which are Sonnet-tier.

## Context & Scope

**What was researched**: the full shape of a new `typescript` extension — manifest, both
agents, the rules file and its `paths:` glob, the `context/project/typescript/` tree, the
`keyword_overrides` collision surface, the `hard_contracts` block, and the verification-stage
lifecycle hook's toolchain-detection/honest-degrade contract — plus the exact line-level
boundary inside `web`'s existing `typescript-web.md` between content that is genuinely generic
and content that is Astro/browser/Cloudflare-specific.

**Constraints carried from the dispatch**:
1. The `context/project/typescript/` tree must be **strictly generic** — no Astro, Cloudflare, or
   any other framework/host-specific content anywhere in it.
2. `web`'s known duplicate-file problem is **not in scope to fix** here, and this design must not
   make it worse (i.e. must not introduce an analogous root-vs-subdirectory duplicate in the new
   extension's own context tree).
3. The verification hook's toolchain-detection logic MUST skip with a stated reason rather than
   report a false pass when a repository has no typecheck or test command configured —
   "honest-degrade," not silent pass.
4. The `keyword_overrides` collision check must be explicit against `web`'s own block AND every
   other loaded extension's block, not just a general assertion of "no conflict."

**What was explicitly out of scope** (per the dispatch's own GOAL/REQUIRED OUTCOMES): actually
splitting `typescript-web.md`, actually writing the new extension's files, and actually wiring
`web` to depend on the new `typescript` extension. This report documents the research and the
concrete, line-cited recommendations a planning dispatch needs to produce an implementation plan
covering those actions — it does not perform them.

## Findings

### Codebase Patterns

#### 1. Extension complexity precedents (file manifest sizing)

Three precedent tiers exist in this repository, measured directly:

| Extension | Agents (lines) | Has `hooks`? | Has `keyword_overrides`? | Has `hard_contracts`? | Has `rules/`? |
|---|---|---|---|---|---|
| `rust` (simple) | research 179, implementation 243 | No | Yes (`rust`) | No | No |
| `python` (simple) | research 169, implementation 247 | No | No | No | No |
| `nix` (medium) | research 527, implementation 931 | Yes (`preflight`, `context_injection`) | No | No | No |
| `web` (medium-complex) | research 422, implementation 996 | No | No | No | Yes (`web-astro.md`) |
| `lean` (complex, formal) | (not measured here) | No | No | Yes (`lean4`) | Yes |

The new `typescript` extension combines features from several of these rows — a `rules/` file
(like `web`), a verification `hooks` entry (like `nix`, but a different stage), a
`keyword_overrides` block (like `rust`), and (per the dispatch's REQUIRED OUTCOME 4) a
`hard_contracts` block (like `lean`/`cslib`) — but its domain (generic TypeScript, no framework,
no MCP server, no browser automation) is closer in *scope* to `rust`/`python` than to `web`/`nix`.
**Recommendation**: size both agents in the 200-350 line range (rust/python tier), not the
400-1000 line range (`web`/`nix` tier) — the extra complexity is in new manifest blocks and one
new hook script, not in agent-body stage count.

#### 2. `web`'s `keyword_overrides` status (collision check, REQUIRED OUTCOME 5)

Direct read of `agent-system/extensions/web/manifest.json` (reproduced in full below) confirms it
declares **no** `keyword_overrides` key at all:

```json
{
  "name": "web",
  "version": "1.0.0",
  "description": "Web development support with Astro, Tailwind CSS v4, TypeScript, and Cloudflare Pages",
  "task_type": "web",
  "dependencies": ["core"],
  "provides": { "...": "..." },
  "routing_agents": { "...": "..." },
  "merge_targets": { "...": "..." }
}
```

There is therefore no `web.keyword_overrides` entry to collide with — the collision check against
`web` specifically resolves to "not applicable; the field is absent."

The six OTHER manifests in this repository that DO declare `keyword_overrides` were read in full:

| Extension | `keyword_overrides` key(s) | Keywords | TypeScript-adjacent? |
|---|---|---|---|
| `books` | `books` | `book.toml`, `book_layer`, `book_export`, `book module`, `book.cert.json`, `layer matrix`, `certified unit`, `book_ledger`, `book_axioms`, `book_requires`, `book_policy`, `book_assume`, `book_not_claimed`, `books-tool` | No |
| `email` | `email` | `inbox`, `email`, `gmail`, `himalaya`, `notmuch`, `unsubscribe`, `junk mail`, `draft reply`, `mbsync`, `aerc`, `mail triage`, `logos`, `protonmail`, `proton` (aliases: `mail`, `mailbox`) | No |
| `rust` | `rust` | `rust`, `cargo`, `rustc`, `clippy`, `crates.io` | No |
| `cslib` | `cslib`, `pr` | `lean`, `lean4`, `mathlib`, `theorem`, `proof`, `lint-fix` (aliases: `lean4`); `pr`, `pull request`, `submit`, `upstream`, `branch`, `rebase`, `cherry-pick` | No |
| `typst` | `typst` | `typst formatting`, `typst compile`, `typst compilation`, `typst package`, `typst template`, `typst style`, `typst layout`, `fletcher diagram`, `typst chapter`, `typst chapters`, `typst manual`, `chapter quality`, `chapter prose` | No |
| `latex` | `latex` | `latex formatting`, `latex compile`, `latex compilation`, `latexmk`, `pdflatex`, `bibtex`, `biblatex`, `latex package`, `latex macro`, `vimtex`, `latex template`, `tex compile error`, `latex style` | No |

None of the 14 total `keyword_overrides` entries across these six manifests contain `typescript`,
`.ts`, `.tsx`, `tsconfig`, `tsc`, `npm`, `node`, or any substring that a whole-word boundary match
(`\b<keyword>\b`, per `extension-development.md`'s documented matching rule) would catch against
a TypeScript-flavored task description.

The core **weak-signal fallback table** (`task-type-detect.sh`'s `DTD_WEAK_SIGNAL_TABLE`, step 4
of the detection ladder, consulted only when no `keyword_overrides` matched) was also read in
full. Its `web` row is `"web|web,astro,tailwind,cloudflare"` — no `typescript`/`ts`/`tsx` token
anywhere in the 20-row table. A new `typescript` `keyword_overrides` entry therefore collides with
**nothing** currently declared, in either mechanism.

**Currently-loaded extensions** in this repository (`.claude-extensions.json`): `sapience`,
`approvals`, `nix`, `nvim`, `core`, `email`, `lean`, `literature`. Note that `web` is **not**
currently loaded here — the collision check above was still performed against its source-store
manifest, per the dispatch's explicit instruction to check "the web extension's own
keyword_overrides," independent of whether it happens to be loaded in this particular repository.

#### 3. The verification-stage lifecycle hook: schema, but no live precedent (REQUIRED OUTCOME 7)

`creating-extensions.md`'s "Lifecycle Hooks" section is authoritative on the mechanism. Key facts
established by direct read, not assumption:

- **Firing prerequisite**: a hook can fire at all only if the declaring manifest's top-level
  `task_type` string-equals the task's own `task_type` (`skill_get_extension_dir()`'s gate in
  `skill-base.sh`). A `typescript` extension with `task_type: "typescript"` satisfies this
  trivially for its own tasks.
- **Invocation site for `verification`** specifically: `command-gate-out.sh`, immediately after
  its own `skill_validate_task_artifacts` call — "after agent returns, artifacts validated, on
  every task's gate-out." This is a different call site from `preflight`
  (`skill_preflight_update()`, after status is set to in-progress) and `context_injection`
  (`skill_context_injection()`, before agent delegation) — both of which fire BEFORE the agent
  runs, whereas `verification` fires AFTER.
- **Positional arguments** (5, fixed order): `$1 task_number`, `$2 task_type`, `$3 task_dir`,
  `$4 session_id`, `$5 operation` (`"research"` or `"implement"`).
- **Exit codes**: 0 = success (stdout printed); non-zero = warning logged, non-blocking, skill
  continues. There is **no opt-in blocking mode** — this is unconditional across every extension's
  every hook, not a per-hook configurable. A verification hook therefore cannot itself fail a
  dispatch no matter what it detects; its only channel is its own stdout/stderr text plus the
  `SKILL_HOOK_LAST_RC`/`SKILL_HOOK_LAST_STATUS` observability globals the calling skill code can
  read (never the hook script itself).
- **Path resolution is by basename** against the deployed `.claude/scripts/` directory (flat, not
  nested under a per-extension subdirectory) — the hook's manifest value AND a matching
  `provides.scripts` entry are both required, or the hook silently never deploys.
- **No live `verification`-stage hook exists today** in any loaded or source-store extension
  (`nix` has `preflight`+`context_injection`; `nvim` has `context_injection` only; every other
  extension's `hooks` key is `null`). This hook's toolchain-detection/honest-degrade logic is
  therefore new design work, informed by the *pattern* `nix-preflight.sh` already establishes
  (warn-but-don't-fail on a missing tool, via `command -v`) rather than any existing
  `verification`-stage script to adapt.

`nix-preflight.sh` (read in full, 44 lines) is the closest structural precedent for the
"detect toolchain, report status, never hard-fail" shape this new hook needs, even though it runs
at a different lifecycle stage:

```bash
if ! command -v nix &>/dev/null; then
  echo "[nix-preflight] WARNING: 'nix' command not found — nix tasks may be limited" >&2
  warnings=$((warnings + 1))
fi
...
exit 0
```

The REQUIRED OUTCOME's honest-degrade bar is strictly stronger than this precedent: `nix-preflight.sh`
only ever warns-and-continues; it never has to distinguish "ran the check and it passed" from "had
no check to run at all." A TypeScript verification hook must make exactly that distinction
explicit (see `## Recommendations` below) because a silent pass on "no typecheck command
configured" would misreport a genuinely unverified repository as verified.

#### 4. `hard_contracts` mechanics (REQUIRED OUTCOME 4)

`manifest-routing-schema.md` and `hard-mode-routing.md` together establish the exact shape and
constraints, confirmed against the two live declarations (`lean.hard_contracts.lean4`,
`cslib.hard_contracts.cslib`):

- One-level map: `{ "<task_type>": [ <path_or_directive>, ... ] }` — no `op` dimension; the SAME
  list is injected into a `--hard` dispatch's `research`, `plan`, AND `implement` prompts alike.
- Each array entry is either a plain additive basename (appended to the phase's core contract
  list) or a `replace:{core-basename}:{override-path}` directive (substitutes a named core entry
  in place, same position).
- **Every entry — additive or the `override-path` half of a `replace:` — must be a flat basename
  resolving directly under the single deployed `context/contracts/` directory.** No nested or
  extension-namespaced paths; the renderer (`orchestrate-build-dispatch.sh` Stage 3.5) emits
  `- context/contracts/${c}` verbatim with no subdirectory handling.
- **Domain-prefixed basenames are mandatory**, not stylistic: when two extensions both declare
  `"contracts"` in `provides.context`, the deploy copier merges both directories' files into the
  one shared destination, and an unprefixed core-named basename silently clobbers core's file for
  every consumer regardless of task_type. `lean4-*.md`/`cslib-*.md` are the two live examples of
  the required convention.
- Resolved via `routing_lookup_flat()` (non-core-before-core, exact-then-compound-base — the same
  4-of-5 ladder steps `routing_agents` itself uses), not `routing_lookup()`.
- Declaring nothing is valid and precedented (`books` deliberately declares no `hard_contracts`
  block at all — its own domain-specific elaboration was judged duplicative of the generic core
  set).

#### 5. The generic `context/project/{domain}/{standards,patterns,domain,tools}/` convention

Every multi-file extension context tree observed (`web`, `nix` via its context references, the
`creating-extensions.md` template itself) uses this four-subdirectory convention, with `README.md`
at the domain root as the always-loaded index. `context-layers.md`'s "Where to store new content"
decision tree confirms the placement rule generally ("language-specific standard, pattern, or
tool reference? → extension context"), and the extension-development.md quick-checklist names the
exact directory-creation command
(`mkdir -p agent-system/extensions/{name}/{agents,skills,rules,context/project/{domain}}`).

#### 6. The CONSTRAINT: `web`'s duplicate-file problem, confirmed live

A direct file listing of `agent-system/extensions/web/context/project/web/` confirms the
dispatch's stated constraint is current, not historical:

```
context/project/web/astro-framework.md          <- root copy
context/project/web/domain/astro-framework.md   <- domain copy
context/project/web/tailwind-v4.md              <- root copy
context/project/web/domain/tailwind-v4.md       <- domain copy
```

Both pairs exist simultaneously today. This report does not investigate which copy is canonical
or stale (out of scope per the dispatch's CONSTRAINT), but records the confirmed fact so a future
reader does not have to re-verify it, and so the new `typescript` extension's own tree design
(below) is held to a standard that avoids ever creating an analogous pair.

#### 7. Line-level split of `typescript-web.md` (REQUIRED OUTCOME 8)

Full file read (304 lines). Section-by-section disposition:

| Lines | Section | Disposition | Rationale |
|---|---|---|---|
| 1-3 | Title/intro | Stays in `web` | Explicitly framed as "TypeScript in Astro" |
| 5-36 | `tsconfig.json` Setup | Stays in `web` | Extends `astro/tsconfigs/strict`, an Astro-only preset; path aliases shown resolve to `src/components`/`src/layouts` (Astro project layout) |
| 38-90 | Type-Safe Component Props (Interface Pattern, Complex Props) | Stays in `web` | `Astro.props`, `interface Props` in `.astro` frontmatter — Astro's own component contract |
| 92-151 | Built-in Type Utilities (`HTMLAttributes`, `ComponentProps`, Route Type Inference) | Stays in `web` | All three are `astro/types` / `Astro.params` / `getStaticPaths` APIs |
| 153-166 | Content Collection Types | Stays in `web` | `astro:content`'s `CollectionEntry<T>` |
| 168-202 | Content Collection Schemas with Zod | Stays in `web` | The schema-authoring *pattern* is Astro's `defineCollection`/`glob` loader, even though Zod itself is generic |
| **204-232** | **Common Zod Patterns** | **Moves to `typescript` extension** | Zero Astro syntax: `z.enum`, `z.coerce.date()`, `z.string().url()`, constrained strings, nested objects, discriminated unions — pure Zod/TypeScript validation vocabulary reusable in any TS project |
| **234-247** | **Import Aliases** | **Concept moves to `typescript` extension (generalized); the `.astro`-flavored example stays in `web`** | The underlying convention ("use `tsconfig.json` `paths` aliases instead of deep relative imports") is a generic TypeScript project-structure pattern; the worked example (`import Card from '@components/Card.astro'`) is Astro-specific and should stay as `web`'s own illustration of the same generic rule |
| 249-270 | Type Checking (CLI Command, CI Pipeline) | Stays in `web` | `astro check`, `pnpm astro check` — Astro's own CLI, not generic `tsc` |
| 272-291 | `env.d.ts` | Stays in `web` | References `.astro/types.d.ts`, generated by `astro sync` |
| 293-304 | TypeScript in Astro Components vs `.ts` Files (comparison table) | Stays in `web` | Explicitly contrasts `.astro` frontmatter against `.ts` files — the comparison's whole point is Astro-specific |

**Net result**: of 304 lines, roughly **29 lines (204-232)** are a clean, wholesale move (Common
Zod Patterns), and roughly **14 lines (234-247)** warrant a generalized restatement in the new
extension with the existing Astro-flavored example left in place in `web` as a worked
illustration. The remaining ~261 lines are Astro-specific and should NOT move. A future
implementation task would therefore: (a) create a new generic Zod/validation-patterns file in
the `typescript` extension's `patterns/` directory seeded from lines 204-232 (rewritten to remove
any residual Astro framing); (b) add a short, generic "path aliases via `tsconfig.json` `paths`"
subsection to a `typescript` extension `domain/` or `patterns/` file; (c) leave
`typescript-web.md` otherwise untouched, including its title and the two sections it keeps that
reference the same general concepts — this is a narrow, additive extraction, not a rewrite of the
source file.

### External Resources

No external web search was needed for this task: every REQUIRED OUTCOME is resolvable from this
repository's own extension-authoring documentation and existing extension source files, which are
authoritative for how this specific system's extensions must be shaped. The report therefore
relies exclusively on codebase sources (listed in the Metadata block above).

## Decisions

- **Treat this dispatch as a research dispatch, not a planning dispatch.** The dispatch file
  (`4.md`) is headed `phase: research` with `output_dir: specs/620_typescript_extension_design/reports/`
  — both load-bearing, machine-checked fields — even though its Description prose says "Produce
  the implementation plan... DELIVERABLE: An implementation plan." Resolved by writing a research
  report (this file) detailed enough that a subsequent planning dispatch can produce the
  implementation plan directly from it, rather than writing a plan file into `reports/` (which
  would be the wrong artifact type for that directory and would violate this agent's own
  contract). Logged as an issue via `issue-record.sh` (class: "dispatch contract ambiguity",
  severity: minor) for visibility.
- **Model tier for both new agents: Sonnet**, matching every comparable language extension
  (`rust`, `python`, `web`, `nix`) rather than the Opus tier reserved for deep-reasoning/formal
  domains (`lean4`, `planner-agent`, `meta-builder-agent`). This is a recommendation for the
  planner to confirm, not a measured constraint.
- **Agent size budget: 200-350 lines each**, matching the `rust`/`python` tier rather than the
  `web`/`nix` tier, because the TypeScript extension's domain (no framework, no MCP server, no
  browser automation) is scoped closer to those simpler extensions despite having more manifest
  blocks (`hooks`, `keyword_overrides`, `hard_contracts`) than either.
- **The verification hook is new design, not an adaptation of an existing script.** No extension
  in this repository currently declares a `verification`-stage hook; the closest structural
  precedent (`nix-preflight.sh`) runs at a different stage (`preflight`) and lacks the "no
  check configured" honest-degrade distinction this task's hook must make explicit.
- **The Zod/path-alias extraction from `typescript-web.md` is scoped narrowly**: only lines
  204-232 move wholesale, and only the *concept* (not the Astro-flavored worked example) in lines
  234-247 generalizes. The remaining ~261 lines of that 304-line file are confirmed Astro-specific
  and should not move, to avoid both scope creep and a hollowed-out `web` domain file.

## Recommendations

### 1. Full file manifest (REQUIRED OUTCOME 1)

```
agent-system/extensions/typescript/
├── manifest.json                                    (~95 lines)
├── EXTENSION.md                                     (~45 lines)
├── README.md                                        (~150 lines)
├── index-entries.json                               (~70 lines)
├── opencode-agents.json                             (~35 lines, OpenCode parity, optional
│                                                       but precedented by rust/python/web)
├── agents/
│   ├── typescript-research-agent.md                 (~230 lines)
│   └── typescript-implementation-agent.md           (~320 lines)
├── rules/
│   └── typescript-rules.md                          (~160 lines)
├── scripts/
│   └── typescript-verify.sh                         (~90 lines; the verification hook)
└── context/project/typescript/
    ├── README.md                                    (~70 lines, always-loaded index)
    ├── standards/
    │   └── typescript-style-guide.md                (~160 lines: naming, strict-mode flags,
    │                                                   `interface` vs `type`, type-only imports,
    │                                                   `unknown`-over-`any`, explicit return types)
    ├── patterns/
    │   ├── zod-validation-patterns.md                (~90 lines: moved/generalized from
    │                                                   `typescript-web.md` lines 204-232)
    │   └── path-alias-patterns.md                    (~60 lines: generalized tsconfig `paths`
    │                                                   convention, concept only, from lines 234-247)
    ├── domain/
    │   ├── tsconfig-reference.md                     (~150 lines: generic `compilerOptions`
    │                                                   reference, strict-family flags, project
    │                                                   references, no framework presets)
    │   └── module-systems.md                         (~100 lines: ESM vs CJS, `package.json`
    │                                                   `"type"` field, Node resolution modes —
    │                                                   justifies the rules glob's `package.json`
    │                                                   and `tsconfig*.json` coverage)
    └── tools/
        ├── tsc-cli-guide.md                          (~90 lines: `tsc --noEmit`, `--watch`,
        │                                               `--build` / project references)
        └── package-manager-detection.md               (~70 lines: lockfile-based npm/pnpm/yarn/
                                                         bun detection, used by the verification hook)
```

**Not included, deliberately** (mirroring `rust`'s own "Deliberately Omitted" README section,
which is the precedent for stating an omission explicitly rather than leaving it to be
rediscovered as a gap later):
- No `settings-fragment.json` — nothing MCP/permission-specific to configure.
- No `templates/` subdirectory — no boilerplate scaffolding comparable to `web`'s Astro
  page/component templates; a generic TypeScript project has no equivalently fixed shape to
  template.
- No `mcp-fragment.json` — no TypeScript-specific MCP server in wide use comparable to
  `mcp-nixos` or the Astro Docs MCP.

### 2. The `context/project/typescript/` tree (REQUIRED OUTCOME 2) — genericity rule

Every file under `standards/`, `patterns/`, `domain/`, and `tools/` must be reviewable against one
test: **"would this sentence need to change if the consuming project used React, Node, Deno,
Express, a CLI tool, or nothing at all beyond the TypeScript compiler itself?"** If the answer is
yes, the content belongs in a framework extension (`web`, or a future `node`/`react` extension),
not here. Concretely, this extension's content must:
- Reference `tsc`, `tsconfig.json`, `package.json`, and the TypeScript language/type system only —
  never `astro`, `vite`, `webpack`, `next`, `react`, or any specific runtime/framework API.
- Keep the Zod-pattern file scoped to the Zod schema-shape vocabulary itself (enums, coercion,
  discriminated unions, nested objects) — never Astro's `defineCollection`/`glob` loader wrapper,
  which stays in `web`.
- Avoid creating a root-level duplicate of any `domain/`/`patterns/`/`standards/`/`tools/` file —
  the CONSTRAINT above requires this new tree not replicate `web`'s existing duplicate-file defect.

### 3. Both agents' workflow stages, tool grants, model tier (REQUIRED OUTCOME 3)

Per `agent-frontmatter-standard.md`'s required fields (`name`, `description`) and tiered model
policy, and modeled directly on `rust-research-agent.md`/`rust-implementation-agent.md`'s stage
structure (itself modeled on the canonical `general-research-agent`/`general-implementation-agent`
Stage 0-8 shape documented in `creating-extensions.md`):

**`typescript-research-agent.md`** frontmatter:
```yaml
---
name: typescript-research-agent
description: Research generic TypeScript language, tooling, and configuration tasks
model: sonnet
---
```
Tools (via `tools:` or inherited full access, consistent with `rust-research-agent`'s pattern):
Read, Write, Edit, Glob, Grep, Bash (`tsc --version`, `npm ls`/`pnpm ls` for dependency
discovery), WebSearch, WebFetch. Stages: Stage 0 (early metadata) → Stage 1 (parse delegation
context) → Stage 2 (determine search strategy: local `tsconfig.json`/`package.json` patterns
first, then TypeScript release notes / `@typescript-eslint` docs / Zod docs as needed) → Stage 3
(execute searches: Glob/Grep local `.ts`/`.tsx` files and config, WebSearch for TS-version-specific
guidance) → Stage 4 (synthesize findings) → Stage 5 (write report to
`specs/{NNN}_{SLUG}/reports/MM_{slug}.md`) → Stage 6 (write `.return-meta.json`) → Stage 7 (brief
text summary, not JSON).

**`typescript-implementation-agent.md`** frontmatter:
```yaml
---
name: typescript-implementation-agent
description: Implement generic TypeScript configuration, types, and module changes from plans
model: sonnet
---
```
Tools: Read, Write, Edit, Glob, Grep, Bash (`tsc --noEmit`, `npm`/`pnpm`/`yarn` install and test
commands, detected per the package-manager-detection guide). Stages: Stage 0 (early metadata) →
Stage 1 (parse delegation context) → Stage 2 (load plan) → Stage 3 (find resume point) → Stage 4
(execute phase loop: edit `.ts`/`.tsx`/`tsconfig.json`/`package.json`, run `tsc --noEmit` per-edit,
mark phase status, write progressive handoff) → Stage 5 (final verification: full typecheck, and
the project's own test command if one is declared/detected) → Stage 6 (write implementation
summary) → Stage 7 (write `.return-meta.json`, including `modified_files`) → Stage 8 (brief text
summary). Both agents follow the five-step resume/handoff/phase-commit structure every
implementation agent in this repository already shares (`web-implementation-agent.md`'s Stage
4D-i through 4D-iii is the fullest documented worked example of that shared shape).

### 4. The `hard_contracts` block (REQUIRED OUTCOME 4)

Given `books`'s precedent that declaring nothing is valid when the generic core set already
covers the domain, and given that TypeScript implementation work does not involve a theorem
prover's reference-grounding or sorry-discipline concerns the way `lean4`/`cslib` do, the simplest
defensible starting position is:

```json
{
  "hard_contracts": {
    "typescript": [
      "typescript-adversarial-verification.md"
    ]
  }
}
```

Rationale for the one override: a `--hard` TypeScript dispatch's highest-value domain-specific
elaboration over the generic `adversarial-verification.md` core contract is verifying that a
claimed type-safety fix was actually exercised by `tsc --noEmit` (not merely edited and assumed
correct) before being reported complete — the same "verify before claiming done" shape
`adversarial-verification.md` already generically states, narrowed to TypeScript's own compiler-as-
oracle verification channel. This is a recommendation for the planning/implementation phase to
accept, narrow, or decline (declaring nothing, as `books` does, remains a valid alternative) — not
a decision this research report can finalize, since `hard_contracts` content authoring is
implementation work. Per the Override Contract Placement Convention
(`manifest-routing-schema.md`), the override file must live at
`agent-system/extensions/typescript/context/contracts/typescript-adversarial-verification.md`,
with `"contracts"` declared in this extension's own `provides.context` array, and must use the
domain-prefixed basename `typescript-adversarial-verification.md` (never an unprefixed
`adversarial-verification.md`, which would silently clobber core's file for every other domain at
deploy-copy time).

### 5. `keyword_overrides` keyword set (REQUIRED OUTCOME 5)

Recommended block, modeled on `rust`'s five-keyword precedent and tuned to avoid single
common-word false positives (per `extension-development.md`'s own guidance: "a single common word
is a blunt, false-positive-prone lever; a multi-word phrase... is how a `keywords` entry gets
precision"):

```json
{
  "keyword_overrides": {
    "typescript": {
      "keywords": [
        "typescript",
        "tsconfig",
        "tsc compile",
        "type error",
        "tsx file",
        ".ts file",
        "npm package",
        "type-safe"
      ],
      "aliases": ["ts"]
    }
  }
}
```

`tsc compile`/`type error`/`tsx file`/`.ts file` are deliberately multi-word or
extension-qualified to avoid the blunt-single-word trap the standard warns against (a bare `type`
or `ts` keyword would be a false-positive magnet against unrelated task descriptions). The `ts`
alias is safe at the alias layer specifically because alias remapping (step 4e) only fires on an
*already-resolved* task_type string and cannot itself introduce a false match the way a `keywords`
entry could.

**Explicit collision check** (REQUIRED OUTCOME 5's own mandate):
- **Against `web`'s own `keyword_overrides`**: not applicable — `web`'s manifest declares no
  `keyword_overrides` block at all (confirmed above in `## Findings` §2). No collision possible.
- **Against every other loaded/source-store extension's `keyword_overrides`** (`books`, `email`,
  `rust`, `cslib`, `typst`, `latex` — the full current inventory, confirmed above): zero overlapping
  tokens under whole-word matching. The nearest superficial neighbor is `cslib`'s `lint-fix`
  (unrelated: Lean linting, not TypeScript) and `email`'s `draft reply` (unrelated: email
  drafting). No token in the proposed `typescript` set appears in any of the six existing blocks.
- **Against the core weak-signal fallback table**: `web`'s row (`web,astro,tailwind,cloudflare`)
  and all 19 other rows contain no `typescript`/`ts`/`tsx`/`tsconfig` token (confirmed above).

**Scan-order note**: because the step 4b scan iterates manifests in alphabetical directory-name
order and stops at the first match, `typescript` sorts after `rust` and before `web`/`z3` — this
has no practical effect here since no other manifest's keywords overlap, but is recorded per the
standard's own "scope new keywords phrases narrowly enough that this ordering doesn't matter"
guidance, which this set already satisfies.

### 6. `rules/typescript-rules.md` `paths:` frontmatter (REQUIRED OUTCOME 6)

```yaml
---
paths: ["**/*.ts", "**/*.tsx", "package.json", "tsconfig*.json"]
---
```

This is a repo-root-relative glob (unlike `web-astro.md`'s `src/**/*.astro` style, which is scoped
to a specific project subdirectory convention `web` assumes) — appropriate because a generic
TypeScript extension cannot assume any particular source-root convention (`src/`, `lib/`, a flat
repo root, a monorepo package layout, etc.). `tsconfig*.json` (glob, not a literal `tsconfig.json`)
deliberately covers `tsconfig.json`, `tsconfig.base.json`, `tsconfig.build.json`, and similar
project-reference/variant naming conventions. Rule content itself (coding standards, naming
conventions, `interface` vs `type`, strict-mode enforcement) should largely parallel
`web-astro.md`'s "TypeScript Standards" table (lines 112-124 of that file) generalized to remove
every Astro-specific row (`interface Props` always-in-frontmatter, Astro utility types) — those
stay `web`'s own responsibility.

### 7. Verification-stage hook: full contract (REQUIRED OUTCOME 7)

**Manifest declaration**:
```json
{
  "hooks": {
    "verification": "scripts/typescript-verify.sh"
  },
  "provides": {
    "scripts": ["scripts/typescript-verify.sh"]
  }
}
```

**Inputs** (the fixed 5-positional-argument contract every hook receives, per
`creating-extensions.md`'s Hook Execution Contract — no TypeScript-specific additions, since the
contract is uniform across all hook stages and all extensions):
`$1 task_number`, `$2 task_type`, `$3 task_dir`, `$4 session_id`, `$5 operation`.

**Toolchain detection logic** (the core new design):
1. Detect a package manager by lockfile presence, in priority order: `pnpm-lock.yaml` → pnpm,
   `yarn.lock` → yarn, `package-lock.json` → npm, `bun.lockb` → bun. Absence of all four, but
   presence of `package.json`, defaults to npm (its scripts are still runnable via `npm run` even
   without a committed lockfile). Absence of `package.json` entirely means no Node/TypeScript
   project is present in the task's scope.
2. If `package.json` exists, read its `scripts` object (`jq -r '.scripts // {}'`) and look for a
   conventional typecheck script name, in priority order: `typecheck`, `type-check`, `tsc`,
   `check`. If found, that is the project's declared typecheck command
   (`<pm> run <script-name>`).
3. If no typecheck script is declared but `tsconfig.json` (or a `tsconfig*.json` variant) exists,
   fall back to `npx tsc --noEmit` (or the pnpm/yarn/bun equivalent) as a generic, config-driven
   typecheck — this still exercises the project's own `tsconfig.json` settings, so it is a
   legitimate check, not a weaker substitute.
4. If `package.json` exists, also look for a `test` script (`jq -r '.scripts.test // empty'`) —
   present and non-trivial (not the default npm placeholder `"echo \"Error: no test specified\" && exit 1"`)
   means a test command exists.
5. Record, per sub-check, one of three outcomes: `ran_pass`, `ran_fail`, or `skipped_no_command` —
   never silently folding the third into either of the first two.

**Honest-degrade behavior** (the REQUIRED OUTCOME's explicit, non-negotiable bar): when step 2/3
finds no typecheck command AND no `tsconfig.json` exists at all (i.e., this is not actually a
TypeScript project in the task's scope, or the task's scope genuinely has nothing to check), the
hook MUST print a line that states the skip and its reason explicitly — e.g.
`[typescript-verify] SKIP: no tsconfig.json and no typecheck script found — nothing to verify`
— and must NOT print any wording that could be mistaken for a pass (no "OK", no "✓", no "passed").
The same rule applies to the test sub-check: a missing or placeholder `test` script must be
reported as `[typescript-verify] SKIP: no test script configured` rather than silently omitted.
This distinguishes three states a reader of the hook's output must be able to tell apart at a
glance: "checked and green," "checked and red," and "nothing to check" — collapsing the third
into the first is exactly the false-pass failure mode the dispatch names explicitly.

**Exit codes**: per the universal, unconditional lifecycle-hook contract (no TypeScript-specific
exception is possible — `creating-extensions.md` states this is true for every hook, every
extension, with no opt-in blocking mode), the script exits 0 on its own successful *execution*
(i.e., it ran to completion and printed its findings) regardless of whether the underlying
typecheck/test it ran was itself green, red, or skipped. A non-zero exit is reserved for the hook
script itself crashing (a bug in the hook, not a finding about the project) — consistent with
`nix-preflight.sh`'s own pattern of `exit 0` even when it found and reported a `WARNING`. This
exit-code discipline does not encode "pass"/"fail" of the underlying project state, because the
hook mechanism itself is non-blocking by design and the calling skill never inspects the hook's
own exit code to gate the dispatch (per `creating-extensions.md`'s Observability Addition:
`SKILL_HOOK_LAST_RC` is observability-only, never blocking); the hook's STDOUT text is the only
channel that actually carries the pass/fail/skip finding to a human or log reader.

### 8. Line-level split of `typescript-web.md` (REQUIRED OUTCOME 8)

See `## Findings` §7 above for the full line-by-line table; summarized here as the actionable
recommendation for a future implementation task:
- **Move wholesale**: lines 204-232 ("Common Zod Patterns") → new file
  `context/project/typescript/patterns/zod-validation-patterns.md` in the new extension, with any
  residual Astro-context framing (there is none in this specific range — it is already pure Zod)
  left as-is.
- **Generalize and duplicate the concept, not the example**: lines 234-247 ("Import Aliases") →
  a new, short, Astro-free restatement of "configure `tsconfig.json` `paths` and prefer alias
  imports over deep relative paths" in
  `context/project/typescript/patterns/path-alias-patterns.md`; `web`'s own copy keeps its
  Astro-flavored `@components/Card.astro` example untouched, since that illustration is
  specifically useful to `web`'s own readers.
- **Leave untouched**: every other line of `typescript-web.md` (1-203, 249-304) — confirmed
  Astro-specific, no generalizable content.
- **Do not delete or shrink `typescript-web.md` itself** as part of this extraction — it remains
  `web`'s own domain file; the move is additive (new files in a new extension), not subtractive
  from `web`.

## Risks & Mitigations

- **Risk**: a future reader conflates this report's recommendations with an already-implemented
  design. **Mitigation**: every section above is phrased as a recommendation for the planning
  phase; no file under `agent-system/extensions/typescript/` has been created by this dispatch.
- **Risk**: the `hard_contracts.typescript` override file name
  (`typescript-adversarial-verification.md`) is authored without first checking whether the
  generic core `adversarial-verification.md` already covers the TypeScript-specific nuance,
  repeating the `books` lesson (duplicative elaboration judged not worth extracting).
  **Mitigation**: explicitly flagged above as "declaring nothing... remains a valid alternative" —
  the planning phase should re-examine the generic core file's actual text before committing to
  the override.
- **Risk**: the verification hook's package-manager/typecheck-script detection heuristic (lockfile
  priority, script-name priority list) could misdetect an unconventional project layout (e.g. a
  monorepo with per-package `tsconfig.json` files and no root-level typecheck script).
  **Mitigation**: the honest-degrade rule already covers this — an undetected or ambiguous setup
  should fall through to the explicit `SKIP` path rather than guess, which is strictly safer than a
  wrong guess reported as a pass.
- **Risk**: adding a `typescript` `keyword_overrides` entry could still interact badly with a
  FUTURE extension's keywords not yet declared (the collision check here is necessarily a
  point-in-time snapshot). **Mitigation**: none available at design time beyond what this report
  already does (explicit, enumerated, reproducible check against the current inventory); a future
  extension author adding overlapping keywords is responsible for re-running the same check
  against this extension's block at that time.

## Context Extension Recommendations

- **Topic**: verification-stage lifecycle hooks with honest-degrade semantics.
- **Gap**: `creating-extensions.md`'s Lifecycle Hooks section documents the mechanism
  (schema, invocation site, exit codes) thoroughly, but has no worked example of a hook that must
  distinguish "checked and passed" from "nothing to check" — every existing example
  (`nix-preflight.sh`'s template, `nvim`'s context-injection hook) only ever warns-or-not, with no
  third "not applicable" state. This task's `typescript-verify.sh` (once authored) would be the
  first such example in the source store.
- **Recommendation**: once `typescript-verify.sh` is implemented, consider adding a short
  "Honest-Degrade Pattern" subsection to `creating-extensions.md`'s Lifecycle Hooks section (or a
  dedicated `context/patterns/` file) using it as the canonical worked example, so a future
  extension author facing the same "no tool configured" ambiguity does not have to re-derive the
  three-state (`ran_pass`/`ran_fail`/`skipped_no_command`) distinction from first principles.

## Appendix

### Search queries / codebase operations used

- `find agent-system/extensions/web -maxdepth 3 -type f` / `-type d` — web extension file inventory
- Full reads: `web/manifest.json`, `web/README.md`, `web/EXTENSION.md`,
  `web/context/project/web/domain/typescript-web.md`, `web/rules/web-astro.md`,
  `web/agents/web-research-agent.md`, `web/agents/web-implementation-agent.md`
- `grep -rl "keyword_overrides" agent-system/extensions/*/manifest.json` — full keyword_overrides
  inventory, followed by per-file `python3 -c "json.load(...)"` dumps of `books`, `email`, `rust`,
  `cslib`, `typst`, `latex`
- Full read: `agent-system/extensions/core/context/guides/extension-development.md`
- Full read: `agent-system/extensions/core/scripts/lib/task-type-detect.sh`
- `python3 -c "..."` dump of `.claude-extensions.json`'s loaded-extension inventory
- Full reads: `agent-system/extensions/web/manifest.json`, `.../README.md`, `.../EXTENSION.md`
- `grep -rl '"hooks"' agent-system/extensions/*/manifest.json` + per-file `hooks` dump — confirmed
  only `nix` (`preflight`, `context_injection`) and `nvim` (`context_injection`) declare any hook;
  no extension declares `verification`
- Full read: `agent-system/extensions/core/docs/guides/creating-extensions.md`
- Full read: `agent-system/extensions/core/context/guides/hard-mode-routing.md`,
  `agent-system/extensions/core/context/guides/manifest-routing-schema.md`
- `python3 -c "..."` dumps of `lean/manifest.json`'s `hard_contracts`/`routing_agents` and
  `cslib/manifest.json`'s `hard_contracts`
- Full read: `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`
- Full read: `agent-system/extensions/core/context/architecture/context-layers.md`
- `wc -l` sizing comparison across `python`, `rust`, `web`, `nix` agent files
- Full reads: `agent-system/extensions/rust/manifest.json`, `.../README.md`,
  `.../index-entries.json`, `.../opencode-agents.json`
- Full reads: `agent-system/extensions/core/context/formats/return-metadata-file.md`,
  `agent-system/extensions/core/context/formats/report-format.md`
- Full read: `agent-system/extensions/nix/scripts/nix-preflight.sh`
- Full read: `agent-system/extensions/filetypes/manifest.json` (ruled out as a routing-collision
  surface for `.ts`/`.tsx` — no overlap found)

### References

- `agent-system/extensions/core/context/guides/extension-development.md`
- `agent-system/extensions/core/context/guides/manifest-routing-schema.md`
- `agent-system/extensions/core/context/guides/hard-mode-routing.md`
- `agent-system/extensions/core/docs/guides/creating-extensions.md`
- `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`
- `agent-system/extensions/core/context/architecture/context-layers.md`
- `agent-system/extensions/web/context/project/web/domain/typescript-web.md`
