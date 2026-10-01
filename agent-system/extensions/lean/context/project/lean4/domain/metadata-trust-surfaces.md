# Metadata Trust Surfaces in Lean 4

What a Lean 4 environment extension can and cannot be trusted to record, measured on
**toolchain v4.31.0**. Every path below is relative to
`~/.elan/toolchains/leanprover--lean4---v4.31.0/src/lean/` and was checked by reading the cited
line.

Read this before designing anything that records facts *about* Lean code in Lean code — an export
ledger, a provenance record, a per-declaration attribute whose rows a downstream consumer trusts.
The short version: an environment extension is a convenient place to **write** such facts and a
weak place to **trust** them, and the reasons are structural rather than incidental.

## 1. Extension entries are invisible to every kernel, replay and export check

The kernel type-checks declarations. It does not see environment extension state at all: extension
entries are not terms, carry no types, and pass through no checker. Nothing in `Lean.addDecl`'s
path validates them, and `#print axioms` on a declaration says nothing about the extension rows
recorded alongside it.

So a row is exactly as trustworthy as the code that wrote it, and "the build was green" is not
evidence about any row. A consumer that re-derives the fact it needs — from the constant itself,
via `ConstantInfo`, `collectAxioms` or a cone walk — has a check; a consumer that reads a row has a
report.

`mkModuleData` (`Lean/Environment.lean:1825`) is what writes the rows into the `.olean`, by calling
the private `computeExtEntries` (`Lean/Environment.lean:1804`), which calls each extension's own
`exportEntriesFn`. That export function is the only place a writer can filter its own rows — and it
is also, for the same reason, the thing an attacker wants to replace. See §2.

## 2. `persistentEnvExtensionsRef` and `lintersRef` are public `IO.Ref`s

Both registries are public mutable state, writable from ordinary elaboration-time code.

| Registry | Path | Holds |
|---|---|---|
| `Lean.persistentEnvExtensionsRef` | `Lean/Environment.lean:1674` | `IO.Ref (Array (PersistentEnvExtension EnvExtensionEntry EnvExtensionEntry EnvExtensionState))` |
| `Lean.Elab.Command.lintersRef` | `Lean/Elab/Command.lean:106` | `IO.Ref (Array Linter)` |

Three measured consequences.

**Making an extension handle non-public does not protect its state.** A `private` handle is
unreachable by name from an importer, which does close the direct `ext.addEntry` route — the
observed failure is core's `Unknown identifier`. But the extension is still *registered*, under its
`name`, in `persistentEnvExtensionsRef`. Any code that can read that ref can find it by name and
`unsafeCast` it back to its concrete type:

```lean
run_cmd do
  let exts ← Lean.persistentEnvExtensionsRef.get
  let some ext := exts.find? (fun e => e.name == `Some.ext) | throwError "not registered"
  let typed : Lean.PersistentEnvExtension Lean.Name Lean.Name Lean.NameSet := unsafeCast ext
  Lean.modifyEnv fun env => typed.addEntry env `aConstantThisModuleDoesNotDeclare
```

**That bypass needs no `unsafe def`, no `meta` import and no `import Lean`.** Measured: the above
elaborates in a `module` file whose only relevant import is a plain (non-`meta`) import of the
module declaring the extension. `unsafeCast` is admitted because a `run_cmd` body is elaborated at
comptime; the same `unsafeCast` inside an ordinary `def` is *not* admitted, and fails with
`may not access declaration ... imported as 'meta'` and `Failed to find LCNF signature`. So
"it would need an `unsafe` declaration" and "the `.olean` header would show a `meta` import" are
both false as traces of this attack.

**A linter cannot defend itself.** `addLinter` (`Lean/Elab/Command.lean:109`) only pushes onto
`lintersRef`, and `runLinters` (`Lean/Elab/Command.lean:242`) iterates whatever the ref holds with
**no global option gate** — the only option in that path is `Elab.async`
(`Lean/Elab/Command.lean:334`), which selects sync versus async execution, not whether linters run.
A single `lintersRef.set #[]` therefore silences every linter in the process. Anything that must
refuse belongs in an attribute handler or a command elaborator, not in a `Linter`.

What *does* raise the cost of both: refusing the constructs that reach the refs. A registered
`@[command_elab]` for the ten execution command kinds (§5) removes the elaboration-time foothold in
whatever scope the refusal covers, because every route to `lintersRef.set` or
`persistentEnvExtensionsRef.get` runs through one of them. The two mechanisms compose; neither
alone is enough.

## 3. The module system's `meta`-import flag does not gate use of a `meta` declaration

Under the module system, `meta import X` marks an import as supplying comptime code, and the flag
is recorded per-import in the `.olean` header. It is tempting to read a module's `meta` imports as
the list of modules whose metaprogramming it can run.

Measured: it is not. A declaration that is *already* `meta` at its definition site needs only a
**plain** `import` at the use site. A `module` file with `import SomeProvider` — no `meta` — reads
and writes `SomeProvider`'s `meta`-declared extension handles with no error, and the module's own
`meta_imports` is `[]`.

What the flag does gate is the use of comptime IR from a module that did not declare it `meta`,
which is a different question. For audit purposes: **an empty `meta_imports` is not evidence that a
module ran no metaprogramming.**

## 4. `_native.*` axioms are minted per use, and `bv_decide` is path-dependent

A tactic that discharges a goal by compiled evaluation records its trust in the axiom set, with a
**per-use** name rather than one shared axiom. The names look like
`<Namespace>.<theorem>._native.bv_decide.ax_1_26` — so the axiom set of a module using the native
path grows by one entry per such use, and an allow-list keyed on axiom *names* must be regenerated
whenever a proof is re-elaborated, while one keyed on the `_native.` prefix is stable.

`bv_decide` is the case to be careful with, because it is **path-dependent**: a `bv_decide` that
takes the native path mints a `_native.bv_decide.ax_*` axiom, and one that does not take it mints
nothing at all. Whether a given call takes it is not visible in the source. The only reliable
statement is the one read off the axiom set after elaboration — never "this file uses `bv_decide`,
so it has a native axiom", and never its converse.

There is a separate, purely mechanical trap for `module` files: a file that reaches `bv_decide`
without `Lean` otherwise in scope needs a non-`meta` `import Std.Tactic.BVDecide`.

## 5. Verified API locations

Everything below was read at the cited line on v4.31.0.

### Reading a constant's real content

| API | Path | Answers |
|---|---|---|
| `ConstantInfo.isUnsafe` | `Lean/Declaration.lean:452` | is the declaration `unsafe`? |
| `Lean.Compiler.getImplementedBy?` | `Lean/Compiler/ImplementedByAttr.lean:67` | is its compiled content a different constant? |
| `Lean.getExternAttrData?` | `Lean/Compiler/ExternAttr.lean:75` | is its compiled content a foreign symbol? |
| `Lean.collectAxioms` | `Lean/Util/CollectAxioms.lean:149` | which axioms does its proof reach? |

All three of the first group were measured readable for an **imported** constant as well as a local
one, so a check built on them does not depend on locality. They are also the three questions
`collectAxioms` cannot answer: a declaration can have an empty axiom set and still run something
else entirely.

### Extension machinery

| API | Path | Note |
|---|---|---|
| `PersistentEnvExtension.getModuleEntries` | `Lean/Environment.lean:1638` | takes `level := OLeanLevel.exported`; see the warning below |
| `EnvExtensionEntry` | `Lean/Environment.lean:104` | opaque; `unsafeCast` is how both the writer and the forger get a typed view |
| `Lean.persistentEnvExtensionsRef` | `Lean/Environment.lean:1674` | §2 |
| `computeExtEntries` | `Lean/Environment.lean:1804` | private; calls each `exportEntriesFn` |
| `mkModuleData` | `Lean/Environment.lean:1825` | writes the rows into the `.olean` |

**`getModuleEntries`' `level` parameter does not degrade gracefully.** Its docstring says the level
"is limited to the maximum level actually imported: `exported` on the cmdline", which reads as a
silent clamp. Measured: asking for `OLeanLevel.private` from a command elaborator under a plain
`lake env lean` run **did not return** — killed at 90 s, and again at 28 min, on a four-module
fixture whose exported-level read finishes in well under a second. Levels above the import are not
a cheap request. Read a higher level off disk instead, with `readModuleDataParts` over the
`.olean`, `.olean.server` and `.olean.private` parts, or from a harness that genuinely imports at
that level.

A corollary for level-aware export functions: `exportEntriesFnEx` returns all three levels at once
(`OLeanEntries`, `Lean/Environment.lean:1538`), and the asymmetry between them is a design
decision with teeth. If a *checker* imports at `private` and refuses on what it finds there, then
filtering a row out of `private` does not harden the checker — it blinds it, and silently turns a
shipped refusal into a pass. Filter the levels a consumer reads; keep the level a checker reads.

### Command kinds for a syntax-level refusal

A refusing `@[command_elab K]` that `throwError`s in the cases it rejects and
`throwUnsupportedSyntax`es otherwise was measured working on both legs: the refusal reports at the
construct's own position, and the fall-through reaches core's own elaborator so an admitted
construct runs exactly as it would unregistered. A wrong kind name is a silent hole — it registers
an elaborator nothing dispatches to — so confirm each one against the source rather than guessing.

| Construct | Kind | Path |
|---|---|---|
| `run_cmd` | `Lean.runCmd` | `Init/Notation.lean:734` |
| `run_elab` | `Lean.runElab` | `Init/Notation.lean:740` |
| `run_meta` | `Lean.runMeta` | `Init/Notation.lean:748` |
| `#eval` | `Lean.Parser.Command.eval` | `Lean/Parser/Command.lean:586` |
| `#eval!` | `Lean.Parser.Command.evalBang` | `Lean/Parser/Command.lean:588` |
| `initialize`, `builtin_initialize` | `Lean.Parser.Command.initialize` | `Lean/Parser/Command.lean:860` |
| `macro_rules` | `Lean.Parser.Command.macro_rules` | `Lean/Parser/Syntax.lean:102` |
| `macro` | `Lean.Parser.Command.macro` | `Lean/Parser/Syntax.lean:119` |
| `elab_rules` | `Lean.Parser.Command.elab_rules` | `Lean/Parser/Syntax.lean:122` |
| `elab` | `Lean.Parser.Command.elab` | `Lean/Parser/Syntax.lean:127` |

`builtin_initialize` shares `initialize`'s kind: the two keywords are alternatives of one
`initializeKeyword` parser (`Lean/Parser/Command.lean:859`).

Two things such a gate does **not** reach. `set_option` has no per-option command kind, so
`set_option debug.*` — including `debug.skipKernelTC` — is not addressable this way; only kernel
replay catches it. And a construct in a scope the gate's own predicate admits is admitted, by
construction: the gate narrows where elaboration-time code may be mounted, and never closes it.

## 6. Practical consequences

- **Refuse in an attribute handler or a command elaborator.** Those run where the module under
  inspection cannot reach them. A `Linter` reports; a registry-based check can be cleared.
- **An attribute handler with `applicationTime := .afterTypeChecking`** has the constant in the
  environment, so all of §5's first group is answerable there. That is the cheapest place to put a
  per-declaration refusal.
- **Prefer re-derivation to row-reading** wherever the cost allows, and where it does not, say in
  the artifact which rows are reports rather than checks.
- **Treat an empty `meta_imports` and a clean linter run as non-evidence.** The first does not mean
  no metaprogramming ran (§3); the second may mean the linter was cleared (§2), or — if a
  provenance filter removed exactly the rows a flag would have fired on — that the flag became
  structurally unreachable rather than that nothing was wrong.
- **Write down which level each reader uses**, and never change an export function's level
  asymmetry without checking every reader against it.
