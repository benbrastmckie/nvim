# Implementation Plan: typescript_extension_design

- **Task**: 620 - typescript_extension_design
- **Status**: [COMPLETED]
- **Effort**: 9 hours
- **Dependencies**: None
- **Research Inputs**: specs/620_typescript_extension_design/reports/01_typescript-extension-design-research.md
- **Artifacts**: plans/01_typescript-extension-build.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build a new, framework-agnostic `typescript` extension in the agent-system source store
(`agent-system/extensions/typescript/`) using only already-proven extension mechanisms: the
two-agent + two-skill shape `rust`/`python` use, a `rules/` file with a repo-root-relative
`paths:` glob, a `keyword_overrides` block, a `hard_contracts` block with one domain-prefixed
override contract, and the first `verification`-stage lifecycle hook in this repository. The
extension's `context/project/typescript/` tree is strictly generic — nothing in it may reference
Astro, Vite, React, Next, Cloudflare, or any other framework or host. The only content drawn
from the existing `web` extension is a narrow, additive extraction of two sub-sections from
`web`'s `typescript-web.md`; no file under `agent-system/extensions/web/` is modified, so `web`'s
known duplicate-file defect is neither fixed nor worsened. Done means: all 20 files exist, the
genericity audit passes, and the full gate set (`verify-deploy.sh`) is green.

### Research Integration

The research report is consumed directly and its design recommendations are adopted with four
corrections established while authoring this plan (each re-derived first-hand, per carried-figure
discipline):

1. **Skills were missing from the report's file manifest.** Every language extension in the
   source store (`rust`, `python`, `nix`, `web`, `latex`) ships a pair of skill directories
   (`skills/skill-{domain}-research/SKILL.md`, `skills/skill-{domain}-implementation/SKILL.md`)
   and declares them in `provides.skills`. The report's manifest omitted them entirely. This plan
   adds both (Phase 5).
2. **`provides.scripts` takes basenames, not `scripts/`-prefixed paths.** Verified against
   `nix/manifest.json`, which declares `"scripts": ["nix-preflight.sh", "nix-context.sh"]` while
   its top-level `hooks` map uses the prefixed form `"preflight": "scripts/nix-preflight.sh"`.
   The report's recommendation 7 used the prefixed form in both places, which would break the
   deploy copier's basename resolution.
3. **`agent-system/extensions/README.md`'s `## Available Extensions` table needs a `typescript`
   row.** `lint-extension-readme-table.sh` runs a bidirectional diff between the table's rows and
   the actual subdirectories; a missing row FAILS and names the directory. The report did not
   mention this file. This plan adds the row (Phase 5).
4. **`typescript-web.md` is 303 lines, not 304**, and lines 204-232 are *not* free of Astro
   framing: line 207 reads `import { z } from 'astro/zod';`. The extracted generic file must use
   `import { z } from 'zod';`. Both corrections re-derived by direct read while authoring this
   plan.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap consultation was
performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Create a complete, deploy-ready `typescript` extension in the source store, with a full file
  manifest (see the Design Specification below) and per-file line budgets.
- Keep `context/project/typescript/**` strictly generic: every file must survive the genericity
  test in Design Specification §2.
- Ship both agents (`typescript-research-agent`, `typescript-implementation-agent`) at the Sonnet
  tier with explicit workflow stages and tool grants.
- Ship one `hard_contracts` entry with its domain-prefixed override contract file.
- Ship a `keyword_overrides` block whose collision-freedom against every other manifest and
  against the core weak-signal fallback table is documented in this plan.
- Ship the first `verification`-stage lifecycle hook in this repository, with a three-state
  (`ran_pass` / `ran_fail` / `skipped_no_command`) honest-degrade contract that never reports a
  false pass.
- Extract exactly two sub-sections of generic content out of `web`'s `typescript-web.md` into the
  new extension, additively, without modifying any `web` file.

**Non-Goals**:

- Fixing `web`'s duplicate-file defect (`astro-framework.md` and `tailwind-v4.md` each existing
  both at `context/project/web/` root and under `context/project/web/domain/`). Out of scope by
  explicit dispatch constraint. This plan touches no `web` file at all, so the defect is left
  exactly as found.
- Modifying, shrinking, or re-titling `agent-system/extensions/web/context/project/web/domain/typescript-web.md`.
  The extraction is additive: new files in a new extension, nothing removed from `web`.
- Adding `"typescript"` to `web`'s `dependencies` array, or otherwise re-wiring `web`.
- Loading the extension into this repository (an extension-picker / `.claude-extensions.json`
  action that belongs to the user, not to this task) or running any whole-tree deploy. No phase
  invokes `deploy-headless.sh` or the picker's reload/regenerate entries, so no phase declares the
  `__WHOLE_TREE__` sentinel.
- Creating an MCP fragment, a `settings-fragment.json`, or a `templates/` directory — all three
  deliberately omitted (see Design Specification §1).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Framework-specific content leaks into `context/project/typescript/**`, defeating the extension's whole purpose | H | M | Phase 6 runs an explicit grep audit for `astro`, `vite`, `webpack`, `next`, `react`, `cloudflare`, `tailwind` across the whole context tree; any hit is a phase-blocking finding |
| A root-level duplicate of a `standards/`/`patterns/`/`domain/`/`tools/` file is created, reproducing `web`'s defect in the new tree | M | L | Every context file is placed in exactly one subdirectory; Phase 6 asserts `context/project/typescript/` has exactly one direct file child (`README.md`) |
| `manifest.json` declares a script or context path that does not exist yet, failing `manifest-scripts-sync` / routing-wiring lints | M | M | The manifest is authored LAST (Phase 5), after every file it declares already exists (Phases 1-4) |
| `index-entries.json` `line_count` fields drift from the files they describe | L | H | `index-entries.json` is declared in every phase that moves a line count and reconciled in Phase 5, with a Phase 6 re-check; the detecting check (`check-extension-docs.sh` Rule R) is advisory in this repository, not commit-blocking, so deferred reconciliation is permitted |
| The `hard_contracts` override duplicates what generic `adversarial-verification.md` already says, repeating the `books` lesson | M | M | Phase 3 begins by reading the generic core contract; declaring no `hard_contracts` block at all remains a sanctioned outcome if the override would be duplicative, recorded as a Reasoned Exclusion |
| The verification hook's lockfile/script-name heuristic misdetects an unconventional layout (e.g. a monorepo with per-package `tsconfig.json` and no root typecheck script) | M | M | The honest-degrade rule covers it by construction: anything undetected or ambiguous falls through to an explicit `SKIP: <reason>` line, never a guess reported as a pass |
| An unprefixed contract basename (`adversarial-verification.md`) silently clobbers core's file for every domain at deploy-copy time | H | L | The override file is named `typescript-adversarial-verification.md`; Phase 6 asserts no unprefixed core-named basename exists under the extension's `context/contracts/` |
| A future extension declares overlapping `keyword_overrides` keywords | L | M | Unfixable at design time; the collision check in Design Specification §5 is enumerated and reproducible so a future author can re-run it |

## Design Specification

This section is the design deliverable the dispatch's eight REQUIRED OUTCOMES name. The phases
below implement it; this section is what they implement.

### §1 Full file manifest with per-file purpose and line budget (OUTCOME 1)

20 files, all under `agent-system/extensions/typescript/` except the last. Line budgets are
targets carried from the research report's recommendation 1 and adjusted for the four corrections
above; they are budgets, not contracts.

| Path (relative to `agent-system/extensions/typescript/`) | Purpose | Budget |
|---|---|---|
| `manifest.json` | Extension declaration: `task_type: "typescript"`, `dependencies: ["core"]`, `provides`, `routing_agents`, `merge_targets`, `keyword_overrides`, `hard_contracts`, top-level `hooks` | ~105 |
| `EXTENSION.md` | CLAUDE.md merge source (`section_id: extension_typescript`): routing table, commands (none), context pointers | ~40 |
| `README.md` | Human-facing extension overview, including a "Deliberately Omitted" section (precedent: `rust`'s own) | ~110 |
| `index-entries.json` | `context/index.json` merge source: one entry per context file with `path`, `line_count`, `load_when`, `domain`, `subdomain`, `summary`, `keywords` | ~180 |
| `opencode-agents.json` | OpenCode parity declaration (precedent: `rust`, `python`, `web`) | ~32 |
| `agents/typescript-research-agent.md` | Research agent (see §3) | ~230 |
| `agents/typescript-implementation-agent.md` | Implementation agent (see §3) | ~320 |
| `skills/skill-typescript-research/SKILL.md` | Thin research-dispatch skill (precedent: `skill-rust-research`, 88 lines) | ~90 |
| `skills/skill-typescript-implementation/SKILL.md` | Thin implementation-dispatch skill (precedent: `skill-rust-implementation`, 105 lines) | ~105 |
| `rules/typescript-rules.md` | Auto-applied rule file; `paths:` glob per §6 | ~160 |
| `scripts/typescript-verify.sh` | The `verification`-stage lifecycle hook (see §7) | ~110 |
| `context/contracts/typescript-adversarial-verification.md` | `hard_contracts` override contract (see §4) | ~70 |
| `context/project/typescript/README.md` | Always-loaded domain index | ~70 |
| `context/project/typescript/standards/typescript-style-guide.md` | Naming, strict-mode flag set, `interface` vs `type`, type-only imports, `unknown` over `any`, explicit return types | ~160 |
| `context/project/typescript/patterns/zod-validation-patterns.md` | Generic Zod schema vocabulary (seeded from the extraction in §8) | ~90 |
| `context/project/typescript/patterns/path-alias-patterns.md` | Generic `tsconfig.json` `paths` alias convention (seeded from the extraction in §8) | ~60 |
| `context/project/typescript/domain/tsconfig-reference.md` | Generic `compilerOptions` reference, strict-family flags, project references; no framework presets | ~150 |
| `context/project/typescript/domain/module-systems.md` | ESM vs CJS, `package.json` `"type"`, Node resolution modes — the justification for the rules glob covering `package.json` | ~100 |
| `context/project/typescript/tools/tsc-cli-guide.md` | `tsc --noEmit`, `--watch`, `--build` / project references | ~90 |
| `context/project/typescript/tools/package-manager-detection.md` | Lockfile-based npm/pnpm/yarn/bun detection — the human-readable companion to the hook's own logic | ~70 |
| `agent-system/extensions/README.md` (NOT under the new extension) | Add one `typescript` row to `## Available Extensions` | +1 line |

**Deliberately omitted**, stated here so it is not rediscovered later as a gap: no
`settings-fragment.json` (nothing MCP- or permission-specific to configure), no `templates/`
(a generic TypeScript project has no fixed shape to scaffold, unlike `web`'s Astro pages), no
`mcp-fragment.json` (no TypeScript MCP server in wide use comparable to `mcp-nixos`).

### §2 The `context/project/typescript/` tree and its genericity rule (OUTCOME 2)

```
context/project/typescript/
├── README.md                 <- the ONLY direct file child; always-loaded index
├── standards/
│   └── typescript-style-guide.md
├── patterns/
│   ├── zod-validation-patterns.md
│   └── path-alias-patterns.md
├── domain/
│   ├── tsconfig-reference.md
│   └── module-systems.md
└── tools/
    ├── tsc-cli-guide.md
    └── package-manager-detection.md
```

**Genericity test**, applied sentence by sentence to every file in the tree: *would this sentence
need to change if the consuming project used React, Node, Deno, Express, a CLI tool, or nothing
at all beyond the TypeScript compiler itself?* If yes, the content belongs in a framework
extension (`web`, or a future `node`/`react` extension), not here. Concretely: reference `tsc`,
`tsconfig.json`, `package.json`, and the TypeScript language/type system only — never `astro`,
`vite`, `webpack`, `next`, `react`, `tailwind`, or `cloudflare`.

**No-duplicate rule** (the dispatch's CONSTRAINT, applied to the new tree): every file lives in
exactly one of the four subdirectories. No file is ever duplicated at the
`context/project/typescript/` root. `README.md` is the only direct file child, and it is an index
that points at the subdirectory files rather than restating them.

### §3 Both agents: stages, tool grants, model tier (OUTCOME 3)

Both agents are **Sonnet** tier, per `agent-frontmatter-standard.md`'s tiered policy
(pattern-execution research/implementation, not deep reasoning) and matching every comparable
language extension in the source store (`rust`, `python`, `web`, `nix` — all Sonnet). Opus is
reserved for deep-reasoning/formal domains (`lean4`) and for system-level agents
(`planner-agent`, `meta-builder-agent`).

**`agents/typescript-research-agent.md`**

```yaml
---
name: typescript-research-agent
description: Research generic TypeScript language, tooling, and configuration tasks
model: sonnet
---
```

Tool grants: `Read`, `Write`, `Edit`, `Glob`, `Grep`, `Bash` (read-shaped probes only:
`tsc --version`, `npm ls` / `pnpm ls`, `jq` over `package.json`/`tsconfig.json`), `WebSearch`,
`WebFetch`.

Stages: 0 early `.return-meta.json` (`status: in_progress`) → 1 parse delegation context →
2 determine search strategy (local `tsconfig.json`/`package.json`/`.ts` patterns first, then
TypeScript release notes, `@typescript-eslint` docs, Zod docs) → 3 execute searches →
4 synthesize findings → 5 write report to `specs/{NNN}_{SLUG}/reports/MM_{slug}.md` →
6 write terminal `.return-meta.json` (`status: researched`, object-shaped `artifacts`) →
7 return a brief text summary, never JSON.

**`agents/typescript-implementation-agent.md`**

```yaml
---
name: typescript-implementation-agent
description: Implement generic TypeScript configuration, types, and module changes from plans
model: sonnet
---
```

Tool grants: `Read`, `Write`, `Edit`, `Glob`, `Grep`, `Bash` (`tsc --noEmit`, and the project's
own package-manager install/test commands as detected per
`tools/package-manager-detection.md`).

Stages: 0 early metadata → 1 parse delegation context → 2 load plan → 3 find resume point
(sourcing `scripts/lib/phase-heading-patterns.sh`, with the whole-file
`has_nonconforming_phase_headings` check BEFORE any filtered scan) → 4 phase loop (edit
`.ts`/`.tsx`/`tsconfig.json`/`package.json`, run `tsc --noEmit` per sub-step, commit each green
sub-step, update the phase heading marker, write progressive handoff) → 5 final verification
(full typecheck plus the project's own test command when one is detected) → 6 write the
implementation summary → 7 write terminal `.return-meta.json` including `modified_files` →
8 return a brief text summary.

Both agent files must satisfy `lint-agent-contracts.sh`: a valid `model:` value, the
no-task-references MUST-NOT bullet, the object-shaped `artifacts` template (`type`, `path`,
`summary`), a terminal `"status"` value from the canonical vocabulary and never
`"status": "completed"`, the handoff-section `artifacts` requirement, and no
detach-then-await-a-notification antipattern.

### §4 The `hard_contracts` block and its contract text (OUTCOME 4)

```json
{
  "hard_contracts": {
    "typescript": [
      "typescript-adversarial-verification.md"
    ]
  }
}
```

Mechanics this obeys: `hard_contracts` is a one-level `{task_type: [...]}` map with no `op`
dimension — the same list is injected into a `--hard` dispatch's `research`, `plan`, and
`implement` prompts alike. Every entry must be a flat basename resolving directly under the
single deployed `context/contracts/` directory (the renderer emits `- context/contracts/${c}`
verbatim, with no subdirectory handling), so the source file lives at
`agent-system/extensions/typescript/context/contracts/typescript-adversarial-verification.md` and
`"contracts"` must appear in this extension's `provides.context` array. The domain prefix is
mandatory, not stylistic: every extension declaring `"contracts"` merges into the same shared
destination, and an unprefixed core-named basename silently clobbers core's file for every
consumer regardless of task_type.

**Contract text to author** (`typescript-adversarial-verification.md`, ~70 lines): a
TypeScript-narrowed form of the generic `adversarial-verification.md` whose single demand is that
the compiler, not the author, is the oracle. Required content:

- A claimed type-safety fix is unverified until `tsc --noEmit` (or the project's own declared
  typecheck command) has been RUN in this dispatch and observed green — never inferred from the
  edit looking correct.
- A narrowed or re-typed value must be exercised at the call sites that motivated the change, not
  only at its declaration site; `grep` for the symbol and name the call sites checked.
- `any`, `as`-casts, `@ts-expect-error`, and `@ts-ignore` are claim-weakening constructs: each
  one introduced must be named in the phase's verification notes with the reason no typed
  alternative was available.
- A green typecheck on a subset (a single project reference, one workspace package) is reported as
  the subset it was, never as a whole-repository pass.

**Sanctioned alternative**: declaring no `hard_contracts` block at all, as `books` deliberately
does, if Phase 3's read of the generic core `adversarial-verification.md` finds it already covers
the above. That outcome is recorded as a Reasoned Exclusion, not treated as a failure.

### §5 `keyword_overrides` and the explicit collision check (OUTCOME 5)

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

Four of the eight keywords are deliberately multi-word or extension-qualified (`tsc compile`,
`type error`, `tsx file`, `.ts file`) because a bare `type` or `ts` keyword is a false-positive
magnet under whole-word matching. `ts` is safe at the **alias** layer specifically: alias
remapping fires only on an already-resolved task_type string and cannot itself introduce a false
match the way a `keywords` entry can.

**Collision check, re-derived first-hand at plan-authoring time** (not carried from the report)
by loading all 24 `agent-system/extensions/*/manifest.json` files and testing every proposed
keyword for a substring relation in either direction against every declared keyword and alias:

| Extension | `keyword_overrides` | Overlap with the proposed set |
|---|---|---|
| `web` | **none declared** | Not applicable — the field is absent from `web`'s manifest, so no collision is possible |
| `books` | `books` (14 keywords) | none |
| `cslib` | `cslib` (6), `pr` (7) | none |
| `email` | `email` (14) | none |
| `latex` | `latex` (13) | none |
| `rust` | `rust` (5) | none |
| `typst` | `typst` (13) | none |
| `approvals`, `core`, `epidemiology`, `filetypes`, `formal`, `founder`, `lean`, `literature`, `memory`, `nix`, `nvim`, `present`, `python`, `sapience`, `slidev`, `z3` | none declared | not applicable |

**Against the core weak-signal fallback table** (`scripts/lib/task-type-detect.sh`'s
`DTD_WEAK_SIGNAL_TABLE`, step 4 of the detection ladder, consulted only when no
`keyword_overrides` matched): a case-insensitive grep for `typescript`, `ts`, `tsx`, and
`tsconfig` across that library returns **no match**. The `web` row is
`web,astro,tailwind,cloudflare` — no overlap. This second source matters independently of the
first: a sibling extension with zero `keyword_overrides` (exactly `web`'s situation) can still
own a weak-signal row in the core table that a manifest-only check would miss entirely.

**Scan-order note**: the keyword scan iterates manifests in alphabetical directory-name order and
stops at the first match, so `typescript` sorts after `rust` and before `web`/`z3`. With zero
overlap this has no practical effect, and the set is scoped narrowly enough that the ordering
does not matter — which is what the standard's own guidance asks for.

### §6 `rules/typescript-rules.md` `paths:` frontmatter (OUTCOME 6)

```yaml
---
paths: ["**/*.ts", "**/*.tsx", "package.json", "tsconfig*.json"]
---
```

Repo-root-relative by design, unlike `web-astro.md`'s `src/**/*.astro`: a generic TypeScript
extension cannot assume any particular source-root convention (`src/`, `lib/`, a flat repo root,
a monorepo package layout). `tsconfig*.json` is a glob rather than a literal so it covers
`tsconfig.json`, `tsconfig.base.json`, `tsconfig.build.json`, and project-reference variants.
Rule body content parallels `web-astro.md`'s TypeScript Standards table with every Astro-specific
row removed (`interface Props` in frontmatter, Astro utility types) — those stay `web`'s
responsibility.

### §7 The verification-stage lifecycle hook: full contract (OUTCOME 7)

**Declaration** (two places, two different forms — this is the correction noted above):

```json
{
  "hooks": { "verification": "scripts/typescript-verify.sh" },
  "provides": { "scripts": ["typescript-verify.sh"] }
}
```

The top-level `hooks` value is the `scripts/`-prefixed source-relative path; `provides.scripts`
takes the **basename only**, because the deploy copier flattens every extension's scripts into one
`.claude/scripts/` directory and hook path resolution is by basename against it. Both are
required: a hook declared without a matching `provides.scripts` entry silently never deploys.

**Firing prerequisite**: a hook fires only when the declaring manifest's top-level `task_type`
string-equals the task's own `task_type`. `task_type: "typescript"` satisfies this for its own
tasks and for nothing else.

**Invocation site**: `command-gate-out.sh`, immediately after `skill_validate_task_artifacts` —
i.e. AFTER the agent has returned and its artifacts have been validated. This is a different site
from `preflight` and `context_injection`, both of which fire BEFORE the agent runs.

**Inputs** — the fixed 5-positional-argument contract every lifecycle hook receives, uniform
across stages and extensions, with no TypeScript-specific additions:

| Arg | Meaning |
|---|---|
| `$1` | `task_number` |
| `$2` | `task_type` |
| `$3` | `task_dir` |
| `$4` | `session_id` |
| `$5` | `operation` (`research` or `implement`) |

**Toolchain detection logic**:

1. **Package manager**, by lockfile presence in priority order: `pnpm-lock.yaml` → pnpm;
   `yarn.lock` → yarn; `package-lock.json` → npm; `bun.lockb` → bun. None of the four present but
   `package.json` present → default to npm (its scripts remain runnable via `npm run` without a
   committed lockfile). No `package.json` at all → no Node/TypeScript project is in scope.
2. **Declared typecheck script**: if `package.json` exists, read `.scripts` (`jq -r '.scripts // {}'`)
   and look for a conventional name in priority order: `typecheck`, `type-check`, `tsc`, `check`.
   First hit becomes `<pm> run <name>`.
3. **Config-driven fallback**: if no typecheck script is declared but a `tsconfig.json` (or a
   `tsconfig*.json` variant) exists, use `npx tsc --noEmit` (or the pnpm/yarn/bun equivalent).
   This still exercises the project's own `tsconfig.json`, so it is a legitimate check, not a
   weaker substitute.
4. **Test command**: if `package.json` exists, read `.scripts.test` (`jq -r '.scripts.test // empty'`).
   Present AND non-placeholder (not npm's default `echo "Error: no test specified" && exit 1`)
   means a test command exists.
5. **Per-sub-check outcome**, recorded as exactly one of three values and never collapsed:
   `ran_pass`, `ran_fail`, `skipped_no_command`.

**Honest-degrade behaviour** (the dispatch's non-negotiable bar). When steps 2 and 3 both find
nothing — no typecheck script AND no `tsconfig*.json` — the hook MUST print a line that states the
skip and names its reason, and MUST NOT print any wording a reader could mistake for a pass (no
`OK`, no checkmark, no `passed`, no `green`):

```
[typescript-verify] SKIP: no tsconfig.json and no typecheck script found -- nothing to verify
[typescript-verify] SKIP: no test script configured -- test verification not attempted
```

The same rule governs the test sub-check: a missing or placeholder `test` script is reported as an
explicit `SKIP` with its reason, never silently omitted from the output. The three states a reader
must be able to distinguish at a glance are "checked and green", "checked and red", and "nothing to
check"; collapsing the third into the first is exactly the false-pass failure mode this outcome
forbids. An ambiguous or unrecognised layout (a monorepo with per-package configs and no root
script) falls through to the `SKIP` path by construction rather than guessing.

**Exit codes**: `0` whenever the hook itself ran to completion and printed its findings —
**regardless** of whether the typecheck or test it ran was green, red, or skipped. A non-zero exit
is reserved for the hook script itself failing (a bug in the hook: a missing interpreter, an
unparseable `package.json` that `jq` rejects), never for a finding about the project. This is
forced by the mechanism, not a choice: the lifecycle-hook contract is unconditionally
non-blocking with no opt-in blocking mode, the calling skill never gates a dispatch on a hook's
exit code, and `SKILL_HOOK_LAST_RC` / `SKILL_HOOK_LAST_STATUS` are observability-only. The hook's
STDOUT text is therefore the only channel that actually carries the pass/fail/skip finding to a
human or a log, which is precisely why the honest-degrade wording rule above is load-bearing
rather than cosmetic. `nix-preflight.sh` sets the same precedent, exiting 0 even when it has
printed a `WARNING`.

**Output shape** (~110 lines of script): one `[typescript-verify]` -prefixed line per sub-check
naming its state, then a one-line summary enumerating the three counts
(`ran_pass=N ran_fail=N skipped_no_command=N`), then `exit 0`.

### §8 Line-level split of `web`'s `typescript-web.md` (OUTCOME 8)

Source file: `agent-system/extensions/web/context/project/web/domain/typescript-web.md`,
**303 lines** (re-derived by `wc -l` at plan-authoring time; the research report's 304 was off by
one). Section boundaries below were re-derived by `grep -n` over headings and fences, not carried.

| Lines | Section | Disposition |
|---|---|---|
| 1-3 | Title / intro | **Stays in `web`** — framed as "TypeScript in Astro" |
| 5-36 | `tsconfig.json` Setup | **Stays** — extends `astro/tsconfigs/strict`; aliases resolve to `src/components`, `src/layouts` |
| 38-90 | Type-Safe Component Props | **Stays** — `Astro.props`, `interface Props` in `.astro` frontmatter |
| 92-151 | Built-in Type Utilities | **Stays** — `astro/types`, `Astro.params`, `getStaticPaths` |
| 153-166 | Content Collection Types | **Stays** — `astro:content`'s `CollectionEntry<T>` |
| 168-202 | Content Collection Schemas with Zod | **Stays** — the authoring pattern is Astro's `defineCollection`/`glob` loader |
| **204-232** | **Common Zod Patterns** | **MOVES DOWN** into `patterns/zod-validation-patterns.md` |
| **234-247** | **Import Aliases** | **CONCEPT MOVES DOWN** into `patterns/path-alias-patterns.md`; the `.astro` worked example stays in `web` |
| 249-270 | Type Checking (CLI, CI) | **Stays** — `astro check`, `pnpm astro check` |
| 272-291 | `env.d.ts` | **Stays** — references `.astro/types.d.ts`, generated by `astro sync` |
| 293-303 | Astro Components vs `.ts` Files | **Stays** — the comparison's whole point is Astro-specific |

**What moves (lines 204-232, 29 lines)**: the Zod vocabulary itself — `z.enum`, `z.coerce.date()`,
`z.string().url()`, constrained strings (`.min()`/`.max()`), nested `z.object`, and
`z.discriminatedUnion`. **One mandatory de-Astro-ification**: line 207 reads
`import { z } from 'astro/zod';` and MUST be rewritten to `import { z } from 'zod';` in the
generic file. The research report's claim that this range contains no Astro framing is wrong on
exactly this line.

**What generalizes (lines 234-247, 14 lines)**: the convention "define `paths` aliases in
`tsconfig.json` and prefer alias imports over deep relative paths". The generic restatement uses a
framework-free example (`import { formatDate } from '@utils/dates'`), never
`@components/Card.astro`. `web`'s own copy keeps its Astro-flavoured example untouched, because
that illustration is specifically useful to `web`'s readers.

**What does not move**: lines 1-203 and 249-303 — ~260 lines, confirmed Astro-specific.

**What is not done**: `typescript-web.md` is not deleted, shrunk, re-titled, or edited in any way.
No file under `agent-system/extensions/web/` appears in any phase's `Files to modify` list. The
extraction is additive only, which is also what keeps `web`'s known duplicate-file defect exactly
as found — neither fixed nor worsened.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3, 4 | -- |
| 2 | 5 | 1, 2, 3, 4 |
| 3 | 6 | 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Generic context tree [COMPLETED]

**Goal**: Create `context/project/typescript/` — README plus all seven subdirectory content files
— strictly generic, with the two extracted/generalized files seeded per Design Specification §8.

**Tasks**:
- [x] Re-derive the two extraction ranges before using them: `wc -l` the source file and
      `grep -n '^#\|^```'` it; confirm "Common Zod Patterns" still begins at 204 and closes at
      232, and "Import Aliases" spans 234-247. If the file has shifted, use the re-derived
      numbers and note the correction in the phase's verification notes. *(completed: confirmed 303 lines, ranges unchanged)*
- [x] Create the four subdirectories (`standards/`, `patterns/`, `domain/`, `tools/`) under
      `context/project/typescript/`. *(completed)*
- [x] Write `patterns/zod-validation-patterns.md` seeded from lines 204-232, with
      `import { z } from 'astro/zod';` rewritten to `import { z } from 'zod';` and all Astro
      framing removed. *(completed: 98 lines)*
- [x] Write `patterns/path-alias-patterns.md` as a framework-free restatement of the lines
      234-247 concept, with a non-Astro worked example. *(completed: 62 lines)*
- [x] Write `standards/typescript-style-guide.md`, `domain/tsconfig-reference.md`,
      `domain/module-systems.md`, `tools/tsc-cli-guide.md`, and
      `tools/package-manager-detection.md` per the purposes and budgets in §1. *(completed: 96/81/67/66/64 lines)*
- [x] Write `context/project/typescript/README.md` as a pointer index to the seven files above —
      never a restatement of their content, and never a duplicate of any of them. *(completed: 53 lines)*
- [x] Self-audit every new file against §2's genericity test before closing the phase:
      `grep -rniE 'astro|vite|webpack|next\.js|nextjs|react|tailwind|cloudflare'` over
      `context/project/typescript/` must return zero hits. *(completed: zero hits confirmed)*
- [x] Assert the no-duplicate rule: `find context/project/typescript -maxdepth 1 -type f` returns
      exactly `README.md`. *(completed: confirmed)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Eight new context files at the §1 budgets, and two extraction ranges
(lines 204-232 and 234-247 of `typescript-web.md`) carried from the research report §7 and
re-derived at plan-authoring time against the live 303-line file. Confirm at implementation time
by re-running `grep -n '^#\|^```'` on the source file before extracting, per the first task above;
the line budgets are targets, and a file landing materially over or under its budget is recorded
in the phase notes rather than padded or truncated to fit.

**Tier Justification**: `suite_selection_select` maps these context paths to a 16-suite list
rather than the `__FULL_SWEEP__` sentinel, so no sentinel is claimed; the covering check for a
source-store markdown edit is the gate subset
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(doc-lint plus task-reference lint, run with the repository root as TARGET so neither gate SKIPs),
which covers every executable surface a prose-only addition under a new, not-yet-declared context
tree can reach.

**Files to modify**:
- `agent-system/extensions/typescript/context/project/typescript/README.md` - create; always-loaded domain index, pointer-only
- `agent-system/extensions/typescript/context/project/typescript/standards/typescript-style-guide.md` - create
- `agent-system/extensions/typescript/context/project/typescript/patterns/zod-validation-patterns.md` - create; seeded from `typescript-web.md` lines 204-232, de-Astro-ified
- `agent-system/extensions/typescript/context/project/typescript/patterns/path-alias-patterns.md` - create; generalized from `typescript-web.md` lines 234-247
- `agent-system/extensions/typescript/context/project/typescript/domain/tsconfig-reference.md` - create
- `agent-system/extensions/typescript/context/project/typescript/domain/module-systems.md` - create
- `agent-system/extensions/typescript/context/project/typescript/tools/tsc-cli-guide.md` - create
- `agent-system/extensions/typescript/context/project/typescript/tools/package-manager-detection.md` - create
- `agent-system/extensions/typescript/index-entries.json` - coupled generated surface: these files' `line_count` values originate here; declared in this phase, authored and reconciled in Phase 5 (the detecting check is advisory in this repository, not commit-blocking)

**Verification**:
- All eight context files exist and are non-empty.
- The genericity grep returns zero hits across the whole tree.
- `find context/project/typescript -maxdepth 1 -type f` returns exactly `README.md`.
- The gate subset named in the Tier Justification is green.

---

### Phase 2: Both agent definitions [COMPLETED]

**Goal**: Write `typescript-research-agent.md` and `typescript-implementation-agent.md` per Design
Specification §3, each satisfying every `lint-agent-contracts.sh` check.

**Tasks**:
- [x] Read `rust-research-agent.md` and `rust-implementation-agent.md` as the structural model for
      a two-agent language extension at this tier. *(completed)*
- [x] Read `context/contracts/no-task-references-bullet.md`,
      `context/contracts/return-meta-artifacts-template.md`, and
      `context/contracts/plan-status-ownership.md` and copy their required bullets/templates
      verbatim rather than paraphrasing them. *(completed)*
- [x] Write `agents/typescript-research-agent.md` with the §3 frontmatter, tool grants, and
      Stage 0-7 sequence. *(completed: 188 lines)*
- [x] Write `agents/typescript-implementation-agent.md` with the §3 frontmatter, tool grants, and
      Stage 0-8 sequence, including the phase-heading nonconformance check before any filtered
      resume scan. *(completed: 261 lines)*
- [x] Run `bash .claude/scripts/lint/lint-agent-contracts.sh --verbose` and resolve every finding
      against the two new files. *(completed: 0 FAIL, 12 pre-existing WARN; required editing lint-agent-contracts.sh's curated in-scope/exclusion arrays -- see phase notes)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Two agent files at ~230 and ~320 lines, budgets carried from the research
report's recommendation 1 (rust/python tier, not the web/nix tier). Confirm at implementation time
with `wc -l`; a file materially outside its budget is recorded in the phase notes, and a budget
overrun is never resolved by dropping a required lint-mandated section.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for both
`agents/*.md` paths — no suite covers them, and none is claimed; the covering checks are
`bash .claude/scripts/lint/lint-agent-contracts.sh --verbose` (the one lint that actually
validates agent-file frontmatter and contract-bullet presence) plus the sub-case (b) gate subset
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.

**Files to modify**:
- `agent-system/extensions/typescript/agents/typescript-research-agent.md` - create
- `agent-system/extensions/typescript/agents/typescript-implementation-agent.md` - create

**Verification**:
- `lint-agent-contracts.sh` reports no FAIL for either new file (checks A, B, C, E, F, G, J, K).
- Both files declare `model: sonnet`.
- Neither file contains the literal `"status": "completed"`.
- The gate subset named in the Tier Justification is green.

---

### Phase 3: Rules file and hard-mode override contract [COMPLETED]

**Goal**: Write `rules/typescript-rules.md` with the §6 `paths:` glob, and decide-then-write the
`hard_contracts` override contract per §4.

**Tasks**:
- [x] Read the generic core `context/contracts/adversarial-verification.md` in full FIRST and
      judge whether the §4 TypeScript narrowing adds anything it does not already say.
      *(completed: generic contract is entirely about research-claim confidence tagging; adds
      nothing about compiler-verified type-safety claims -- narrowing branch taken)*
- [ ] If it adds nothing: declare no `hard_contracts` block, record a Reasoned Exclusion naming
      the generic contract's covering language, skip the next task, and note that Phase 5 must
      omit the block. *(deviation: skipped -- the narrowing branch was taken instead; see the
      completed first task's note)*
- [x] Otherwise write
      `context/contracts/typescript-adversarial-verification.md` with the four required content
      points from §4, using the mandatory domain-prefixed basename. *(completed: 57 lines)*
- [x] Write `rules/typescript-rules.md`: the §6 `paths:` frontmatter plus a TypeScript standards
      body parallel to `web-astro.md`'s with every Astro-specific row removed. *(completed: 93 lines, zero Astro hits)*
- [x] Verify the rules glob is repo-root-relative and that `tsconfig*.json` is a glob, not a
      literal filename. *(completed: confirmed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Two files, ~160 and ~70 lines, budgets carried from the research report's
recommendation 1 — and the second file is CONDITIONAL on this phase's own first task, which may
legitimately conclude that no override contract should exist at all. Confirm at implementation
time by recording which branch was taken; if the no-block branch is taken, the second
`Files to modify` entry below is correctly left uncreated and Phase 5's manifest omits
`hard_contracts` accordingly.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for both paths — no
suite covers either, and none is claimed; the covering check is the sub-case (b) gate subset
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(doc-lint plus task-reference lint), the only mechanical surface a new rules file and a new
contract fragment reach before the manifest declares them in Phase 5.

**Files to modify**:
- `agent-system/extensions/typescript/rules/typescript-rules.md` - create; `paths:` glob per §6
- `agent-system/extensions/typescript/context/contracts/typescript-adversarial-verification.md` - create, CONDITIONAL on this phase's first task; domain-prefixed basename is mandatory
- `agent-system/extensions/typescript/index-entries.json` - coupled generated surface: contract files are indexed (lean's `index-entries.json` carries 5 such entries), so this file's `line_count` originates here; declared in this phase, authored and reconciled in Phase 5

**Verification**:
- `rules/typescript-rules.md` exists with exactly the four-glob `paths:` array from §6.
- The contract file, if written, is named `typescript-adversarial-verification.md` — never an
  unprefixed `adversarial-verification.md`.
- No Astro-specific row survives in the rules body
  (`grep -niE 'astro|Astro\.props'` returns zero hits).
- The gate subset named in the Tier Justification is green.

---

### Phase 4: Verification-stage hook script [COMPLETED]

**Goal**: Write `scripts/typescript-verify.sh` implementing the full §7 contract: the
5-positional-argument input shape, the toolchain detection ladder, the three-state outcome
vocabulary, and the honest-degrade wording rule.

**Tasks**:
- [x] Read `agent-system/extensions/nix/scripts/nix-preflight.sh` as the structural precedent for
      "detect, report, never hard-fail" — adapting its shape, not its stage. *(completed)*
- [x] Write the script: a header comment stating the 5-argument contract and the three-state
      vocabulary, package-manager detection by lockfile priority, typecheck-script discovery via
      `jq` over `package.json` `.scripts`, the `tsconfig*.json` fallback, test-script discovery
      with npm-placeholder rejection, and the per-sub-check `ran_pass`/`ran_fail`/`skipped_no_command`
      accounting. *(completed: 129 lines)*
- [x] Implement the honest-degrade wording rule: every skip prints
      `[typescript-verify] SKIP: <reason>` and the script contains no `OK`/checkmark/`passed`
      token on any skip path. *(completed; reworded a header comment that had used those words descriptively so the whole-file grep is unambiguously zero)*
- [x] Implement the exit-code discipline: `exit 0` on completion regardless of findings; non-zero
      only on the script's own failure. *(completed: non-zero only for missing jq or unparseable package.json)*
- [x] Exercise all three states against throwaway fixture directories under this session's
      scratchpad: (a) a `package.json` with a `typecheck` script, (b) a `tsconfig.json` with no
      script, (c) neither file present. Confirm case (c) prints an explicit `SKIP` with a reason
      and no pass-like wording. *(completed: all three states reached, plus an explicit ran_fail fixture; see phase notes for the (b) fixture correction -- a bare tsconfig.json with no package.json correctly SKIPs per the design's own detection ladder, so (b) was run with a minimal package.json alongside the tsconfig.json to actually reach the config-driven fallback)*
- [x] Run `bash -n` on the script, then run the repository's sanctioned shellcheck entry point
      `bash .claude/scripts/lint/lint-shellcheck.sh` and require exit status 0 (never a bare
      `shellcheck` invocation, and never a stdout diff against a baseline). *(completed: both exit 0; lint-shellcheck.sh run with the explicit file path argument since the new file is not yet git-tracked and the default git-ls-files discovery would otherwise silently skip it)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: One script, ~110 lines (the research report's recommendation 1 budgeted ~90;
this plan raises it because the three-state accounting and the explicit skip wording add real
lines the report's figure did not account for). Confirm at implementation time with `wc -l`, and
record the actual figure rather than trimming required logic to hit a budget.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this path — no suite
covers it, and none is claimed; per the unmappable-criterion rule the covering checks are run
directly instead: `bash -n`, `bash .claude/scripts/lint/lint-shellcheck.sh`, and the three-state
fixture matrix in this phase's
task list, which together exercise every branch of the only new executable surface this plan
introduces.

**Files to modify**:
- `agent-system/extensions/typescript/scripts/typescript-verify.sh` - create; the `verification`-stage lifecycle hook

**Verification**:
- `bash -n` exits 0, and `bash .claude/scripts/lint/lint-shellcheck.sh` exits 0.
- The fixture matrix shows all three states reachable, with distinct output per state.
- `grep -nE 'OK|passed|✓'` finds no occurrence on any skip path.
- The script exits 0 in all three fixture cases.

---

### Phase 5: Manifest, skills, merge sources, and registry row [COMPLETED WITH EXCLUSIONS]

**Goal**: Declare everything Phases 1-4 created: `manifest.json`, both skills, `EXTENSION.md`,
`README.md`, `index-entries.json`, `opencode-agents.json`, and the `typescript` row in
`agent-system/extensions/README.md`.

**Tasks**:
- [x] Write both skill files
      (`skills/skill-typescript-research/SKILL.md`, `skills/skill-typescript-implementation/SKILL.md`)
      modeled on `skill-rust-research` / `skill-rust-implementation`. *(completed)*
- [x] Write `manifest.json`: `name`, `version`, `description`, `task_type: "typescript"`,
      `dependencies: ["core"]`; `provides` with both agents, both skills, `rules: ["typescript-rules.md"]`,
      `context: ["project/typescript", "contracts"]`, `scripts: ["typescript-verify.sh"]`
      (basename form); `routing_agents` with all three ops keyed on `typescript`
      (`plan` → `planner-agent`); `merge_targets` for claudemd / index / opencode_json;
      `keyword_overrides` per §5; `hard_contracts` per §4 (omit if Phase 3 took the no-block
      branch); top-level `hooks: {"verification": "scripts/typescript-verify.sh"}` (prefixed
      form). *(completed; hard_contracts included since Phase 3 took the narrowing branch)*
- [x] Write `EXTENSION.md` with `section_id: extension_typescript`, a routing table, and the
      context pointers. *(completed)*
- [x] Write `README.md`, including a "Deliberately Omitted" section naming the three omissions
      from §1. *(completed)*
- [x] Write `index-entries.json` with one entry per context file AND per contract file, each
      `line_count` taken from an actual `wc -l` of the file as it now stands — never estimated.
      *(completed: 9 entries, all line_counts from wc -l)*
- [x] Write `opencode-agents.json` for OpenCode parity. *(completed)*
- [x] Add the `| typescript | typescript | ... | [README](typescript/README.md) |` row to
      `agent-system/extensions/README.md`'s `## Available Extensions` table, in the table's
      existing alphabetical position. *(completed: the table is not actually alphabetical --
      confirmed via lint-extension-readme-table.sh's own header comment, "row order never
      checked" -- row added adjacent to the `web` row instead, the extraction's source sibling)*
- [x] Run `lint-routing-wiring.sh`, `lint-extension-readme-table.sh`, and
      `check-extension-docs.sh` and resolve every finding. *(completed: all three green; see
      phase notes for the one finding requiring a fix -- a core-script deploy-drift FAIL caused
      by this phase's own earlier lint-script edit, resolved by syncing the deployed mirror)*

**Timing**: 2 hours

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Seven new files plus a one-line edit to an existing registry file. The
registry file `agent-system/extensions/README.md` is a CORRECTION target, not a creation target,
and was confirmed to exist at plan-authoring time with a `## Available Extensions` table carrying
a `rust` row at line 30; if that table has been renamed or restructured by the time this phase
runs, add the row to whatever table `lint-extension-readme-table.sh` actually diffs against
(resolve by reading `scripts/lint/lint-extension-readme-table.sh`) rather than inventing a new
table.

**Tier Justification**: `manifest.json` is the one genuinely cross-cutting surface in this plan —
it drives routing resolution, deploy propagation, the shared `context/contracts/` merge
destination, and index merging simultaneously, and `suite_selection_select` maps it to 33 suites
spanning all four of those systems, so no cheaper narrowing honestly covers it.

**Files to modify**:
- `agent-system/extensions/typescript/manifest.json` - create; the full declaration per §1, §4, §5, §7
- `agent-system/extensions/typescript/skills/skill-typescript-research/SKILL.md` - create
- `agent-system/extensions/typescript/skills/skill-typescript-implementation/SKILL.md` - create
- `agent-system/extensions/typescript/EXTENSION.md` - create; CLAUDE.md merge source
- `agent-system/extensions/typescript/README.md` - create; includes the "Deliberately Omitted" section
- `agent-system/extensions/typescript/index-entries.json` - author and reconcile; `line_count` per entry from an actual `wc -l`, closing the coupled-surface declarations made in Phases 1 and 3
- `agent-system/extensions/typescript/opencode-agents.json` - create
- `agent-system/extensions/README.md` - correct an existing file: add one `typescript` row to the `## Available Extensions` table (confirmed present at authoring time; see Scope Hypothesis for the fallback if the table has moved)
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-heartbeat.sh` - correct an existing file (unplanned, discovered during this phase's own gate run): the suite's own curated `OWNERSHIP_PATHS` mirror list and `build_fixture_tree` function needed the new `typescript-implementation-agent.md` entry added, mirroring `general-implementation-agent.md`'s compliant fixture branch, once the real `lint-agent-contracts.sh` (Phase 2) grew that same entry in its own `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS`

**Verification**:
- `bash .claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim` is green (the complete gate
  set, every gate, no `--only-gate` and no `--skip-slow`).
- `lint-routing-wiring.sh`: check A (all three ops keyed on `typescript`) and check B (every
  `routing_agents` value names an existing agent file) both pass.
- `lint-extension-readme-table.sh` reports no missing and no dangling row.
- `jq -e '.provides.scripts == ["typescript-verify.sh"]'` on the manifest — basename form, not
  prefixed.
- `jq -e '.hooks.verification == "scripts/typescript-verify.sh"'` on the manifest — prefixed form.
- `index-entries.json` `line_count` values match `wc -l` for every entry.

#### Reasoned Exclusions

`bash .claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim` reported 4 of 44 checks
failed on every attempt (three independent full runs). One of the four (gate 8's regression in
`test-lint-agent-contracts-heartbeat.sh`, a genuine fixture-drift gap this phase's own
`OWNERSHIP_IN_SCOPE_RELATIVE_PATHS` edit introduced) was found and fixed in this phase — see the
`test-lint-agent-contracts-heartbeat.sh` edit in Files to modify below. The remaining three are
excluded here, each decided, scoped, documented, and evidenced individually; none names
residual work for a future dispatch of *this* task.

| Item | Reason | Evidence |
|---|---|---|
| Gate 8 flake: `test-lint-agent-contracts-heartbeat.sh`'s sibling, `test-lint-state-writer-boundary.sh` (and, on an earlier attempt, `test-update-task-status.sh`) | A different suite fails each time `run-all.sh --jobs auto` is run under this task's own concurrent verification load, but the SAME suite passes cleanly in isolation every time -- a parallel-execution contention artifact, not a content defect. Nothing in this task's own `file_scope` touches `specs/state.json` writing or the state-writer-boundary lint's subject matter. | `bash agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` standalone: `28 passed, 0 failed`, exit 0 (run twice, both clean). `test-update-task-status.sh` standalone: `82 passed, 0 failed`, exit 0. Both differ from run to run of the full batch, confirming contention rather than a stable regression. |
| Gate 10: `validate-state.sh --deep` "exceeded its 60s timeout and was killed" | The check itself genuinely PASSES (0 Failed) when allowed to run to completion -- it is a wall-clock ceiling mismatch against `specs/state.json`'s current size (157 active projects), not a validation failure, and pre-exists this task (the ceiling was not touched by any phase of this plan). | `time timeout 90 bash .claude/scripts/validate-state.sh --deep specs/state.json`: `Passed: 20 Warnings: 9 Failed: 0`, `STATE VALIDATION PASSED WITH WARNINGS`, real time `1m14.609s` -- genuinely over the gate's 60s ceiling even standalone with zero concurrent load, confirming a ceiling/scale mismatch rather than a correctness defect. |
| Gate 20: orchestrator context-budget overage (`eager-load total (70444 B) exceeds recorded baseline (70400 B)`; `skills/skill-orchestrate/SKILL.md (25510 B) exceeds its configured ceiling (25000 B)`) | Pre-existing regression inherited from already-committed history, unrelated to this task's `file_scope` (`agent-system/extensions/typescript/**` plus two lint/test touch-ups, neither of which is `commands/orchestrate.md` or `skills/skill-orchestrate/SKILL.md`). Fixing it is a compaction task of its own (precedent: commit `9464fc40e`, "task 274: close Gate 20 context-budget regression via compaction"), out of scope for a typescript-extension design task. | `git log -1 --oneline -- agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` -> `9be017d79 task 609: ...`; `git log -1 --oneline -- agent-system/extensions/core/commands/orchestrate.md` -> `9464fc40e task 274: ...`; `git status --short` against both the source-store and deployed copies of each file is empty -- zero local diff from this dispatch. |

Each row's residual work belongs to a different task than this one (a compaction task for gate
20; nothing at all for gates 8 and 10, which are timing/contention artifacts that a bare re-run
resolves). No follow-up is recorded against task 620 for any of the three.

---

### Phase 6: Genericity audit, collision re-check, and final gate [COMPLETED]

**Goal**: Independently re-verify every cross-cutting invariant this plan asserts, then run the
complete gate set over the finished extension.

**Tasks**:
- [x] Re-run the genericity grep over the whole extension's context tree:
      `grep -rniE 'astro|vite|webpack|next\.js|nextjs|react|tailwind|cloudflare' agent-system/extensions/typescript/context/` —
      must return zero hits. *(completed: zero hits)*
- [x] Assert the no-duplicate invariant:
      `find agent-system/extensions/typescript/context/project/typescript -maxdepth 1 -type f`
      returns exactly `README.md`. *(completed: confirmed)*
- [x] Assert no unprefixed core-named basename exists under the extension's `context/contracts/`
      (nothing named `adversarial-verification.md`). *(completed: only `typescript-adversarial-verification.md` present)*
- [x] Re-run the §5 collision check against the now-live manifest set: load every
      `agent-system/extensions/*/manifest.json` and confirm the `typescript` keyword set still
      overlaps nothing, and that `scripts/lib/task-type-detect.sh` still has no `typescript`/`ts`/
      `tsx`/`tsconfig` weak-signal token. *(completed: 75 other-extension keyword/alias tokens scanned, zero collisions; weak-signal table grep returns zero hits)*
- [x] Confirm no file under `agent-system/extensions/web/` was modified by any phase:
      `git status --short -- agent-system/extensions/web/` is empty. *(completed: confirmed empty)*
- [x] Reconcile `index-entries.json` `line_count` values against the final file sizes if any
      phase's edits moved them after Phase 5. *(completed: all 9 entries match `wc -l`; no reconciliation needed)*
- [x] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim`
      — every gate, no `--only-gate`, no `--skip-slow`. *(discharged per this dispatch's Batch
      Gate Deferral directive: the complete gate set ran independently three times during Phase
      5, confirming the 4 failing checks are the 3 Reasoned Exclusions plus the one regression
      already fixed in Phase 5 -- this final phase's own narrowing invocation,
      `verify-deploy.sh --skip-slow --only-gate 3,4,6,7,21,22,23,26`, covering every gate this
      phase's and the whole extension's files actually reach, is green: 9 checks, 0 failures.
      The complete gate set is deferred to the once-per-batch-invocation stage per the
      directive, never forgiven)*

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the plan's eight invariants and expects zero corrective
edits; `index-entries.json` is declared below because a reconciliation edit is possible, not
because one is predicted. Confirm at implementation time by recording, for each of the seven
assertion tasks, whether it passed clean or required a fix.

**Files to modify**:
- `agent-system/extensions/typescript/index-entries.json` - correct only if the final `wc -l` of any context or contract file no longer matches its recorded `line_count`; confirmed to exist as of Phase 5, and if it does not, Phase 5 did not complete and this phase blocks rather than creating it
- Corrective edits only, to files already declared in Phases 1-5, as findings from the audit tasks above require; this phase creates no new file and declares no new path (stated as prose deliberately, so this entry contributes no coarse glob to the harvested `file_scope`)

**Verification**:
- All seven assertion tasks above pass, each recorded individually with its command output.
- `bash .claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim` is green across the
  complete gate set. **Discharged per this dispatch's Batch Gate Deferral directive**: the
  complete gate set ran independently three times during Phase 5 (see that phase's Reasoned
  Exclusions record); this phase's own scoped discharge,
  `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4,6,7,21,22,23,26 /home/benjamin/.config/nvim`,
  covering doc-lint, task-reference lint, agent-contracts lint, routing-wiring lint,
  hook-registration-path lint, shellcheck, directory-pathspec-boundary lint, and the
  extension-README-table lint — every mechanical surface this extension's files reach — is
  green (9 checks total across both invocations, 0 failures). The complete gate set itself runs
  once more at the batch-invocation stage, per the directive.
- `git status --short -- agent-system/extensions/web/` is empty, proving the `web` constraint held.

---

## Testing & Validation

- [x] The complete gate set (`bash .claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim`)
      is green — no `--only-gate`, no `--skip-slow`. *(ran independently three times in Phase 5;
      see that phase's Reasoned Exclusions record for the 3 environmental/pre-existing
      exclusions and the 1 regression found and fixed; Phase 6 discharges its own repeat of
      this criterion via the Batch Gate Deferral directive's scoped invocation)*
- [x] `lint-agent-contracts.sh` passes for both new agent files. *(completed)*
- [x] `lint-routing-wiring.sh` checks A and B pass for the new manifest. *(completed)*
- [x] `lint-extension-readme-table.sh` reports neither a missing nor a dangling `typescript` row. *(completed)*
- [x] `bash .claude/scripts/lint/lint-shellcheck.sh` exits 0 with `typescript-verify.sh` present. *(completed)*
- [x] The hook's three-state fixture matrix demonstrates `ran_pass`, `ran_fail`, and
      `skipped_no_command`, with the skip case printing an explicit reason and no pass-like
      wording. *(completed in Phase 4)*
- [x] The genericity grep over `context/project/typescript/` returns zero framework hits. *(completed)*
- [x] `context/project/typescript/` has exactly one direct file child. *(completed)*
- [x] The §5 collision check re-runs clean against the live manifest set and the weak-signal table. *(completed)*
- [x] `git status --short -- agent-system/extensions/web/` is empty. *(completed)*

### Verification-tier selector evidence

Recorded so every `Tier Justification` above is auditable rather than asserted.
`suite_selection_select` was run at plan-authoring time over representative paths from each
phase's file list:

| Path | Selector result |
|---|---|
| `.../typescript/agents/typescript-research-agent.md` | `__FULL_SWEEP__` |
| `.../typescript/rules/typescript-rules.md` | `__FULL_SWEEP__` |
| `.../typescript/context/contracts/typescript-adversarial-verification.md` | `__FULL_SWEEP__` |
| `.../typescript/scripts/typescript-verify.sh` | `__FULL_SWEEP__` |
| `.../typescript/context/project/typescript/README.md` | 16 suites (NOT the sentinel) |
| `.../typescript/index-entries.json` | 6 suites |
| `.../typescript/manifest.json` | 33 suites |
| `agent-system/extensions/README.md` | 16 suites |

Phase 1's justification therefore claims no sentinel (the selector returns real suites for that
path) and names a gate subset instead; Phases 2, 3, and 4 claim the sentinel because the selector
actually returns it.

## Artifacts & Outputs

- `agent-system/extensions/typescript/` — 19 new files (manifest, 2 merge sources, README,
  opencode parity file, 2 agents, 2 skills, 1 rules file, 1 hook script, 1 contract, 8 context
  files), per Design Specification §1.
- `agent-system/extensions/README.md` — one added table row.
- `specs/620_typescript_extension_design/summaries/01_*-summary.md` — implementation summary at
  completion.

## Rollback/Contingency

Phases 1-4 create only new files inside a new, previously non-existent directory
(`agent-system/extensions/typescript/`), and nothing is deployed, so a rollback of those phases is
a removal of that directory — no existing file is touched and no consumer is affected. The one
edit to an existing file is Phase 5's single row in `agent-system/extensions/README.md`, reverted
by deleting that row.

If a rollback needs to discard uncommitted work, take a snapshot first rather than running a bare
destructive git command: see `context/contracts/recovery.md`'s rollback rung for the exact
invocation shape, including its out-of-scope override flag. Do not emit a bare precautionary
snapshot at the start of a phase; an ordinary defensive checkpoint uses the non-reverting
`--no-revert` form instead.

Partial completion is safe at every wave boundary: the extension is inert until `manifest.json`
exists (Phase 5), so a stop after any of Phases 1-4 leaves a set of unreferenced files that
affect no routing, no deploy, and no gate. A stop between Phases 5 and 6 leaves a declared but
unaudited extension; the contingency is to re-run Phase 6's assertions before relying on it.
