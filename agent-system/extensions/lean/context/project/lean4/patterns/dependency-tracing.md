# Lean 4 Dependency-Tracing Recipe

How to mechanically answer "does declaration X depend on declaration (or set) Y?" in a Lean 4
environment, and why `#print axioms` cannot answer it. Harvested from one successful use (a task
that had to prove a decision procedure did not depend on a set of theorems whose hypotheses had
been refuted); the four probe shapes below are reusable templates, not a one-off script.

## The Load-Bearing Caveat: `#print axioms` Is Not a Dependency Tracer

`#print axioms <name>` answers "is this declaration SOUND?" (which foundational axioms does its
proof ultimately rest on), never "what does this declaration DEPEND ON?" (which other specific
declarations does it use). These are different questions, and the first one is usually the wrong
one to reach for.

**Concrete observation**: in the motivating case, THREE declarations at three different
dependency depths — a decision procedure, its own soundness theorem, and a vacuous theorem under
suspicion that the decision procedure was hypothesized to depend on — all reported the EXACT SAME
axiom set: `[propext, Classical.choice, Quot.sound]`. If the axiom check had been the only probe
run, it would have returned a confidently useless answer: identical axioms tell you nothing about
whether one declaration's proof term mentions another. State this caveat explicitly and early —
`#print axioms` is the first probe most people reach for, and it looks like it answers the
question without actually doing so.

## Four Probe Shapes

Each shape below is a self-contained `run_cmd`/`#print` script, runnable via `lake env lean
<probe-file>` against an existing build (see "Run Against Existing Oleans" below) — no access to
the originating repository is required to adapt these.

### Shape 1: Forward Transitive Closure (the primary tool)

Answers: "does entry point X reach any of these suspect declarations, directly or indirectly?"
Walks `Expr.getUsedConstants` over BOTH the type and the value of every reached declaration,
iterated to a fixed point from a named entry point, then intersects the resulting closure with a
suspect set.

```lean
import YourProject.SomeModule  -- import whatever module makes your targets/suspects visible

open Lean

namespace DepTrace

partial def collect (env : Environment) (visited : Std.HashSet Name) (n : Name) :
    Std.HashSet Name :=
  if visited.contains n then visited
  else
    let visited := visited.insert n
    match env.find? n with
    | none => visited
    | some ci =>
      let deps := (ci.type.getUsedConstants ++ (ci.value?.map Expr.getUsedConstants).getD #[])
      deps.foldl (fun acc d => collect env acc d) visited

def targets : List Name := [ `YourProject.entryPointOne, `YourProject.entryPointTwo ]
def suspects : List Name := [ `YourProject.suspectTheoremOne, `YourProject.suspectTheoremTwo ]

end DepTrace

open DepTrace in
run_cmd do
  let env ← Lean.getEnv
  -- existence check FIRST: a typo'd name would otherwise silently produce a vacuously clean
  -- result -- see the resolve-by-name note below.
  for s in suspects do
    if (env.find? s).isNone then
      logError m!"SUSPECT NOT FOUND IN ENV: {s}"
  for t in targets do
    if (env.find? t).isNone then
      logError m!"TARGET NOT FOUND IN ENV: {t}"
    else
      let cl := collect env {} t
      let hits := suspects.filter (fun s => cl.contains s)
      logInfo m!"{t}: closure = {cl.size} consts; hits = {hits}"
```

A non-trivial closure size (hundreds to thousands of constants, depending on the target) is
itself evidence the traversal is doing real work rather than terminating early on an empty or
malformed environment lookup.

### Shape 2: Module-Index Variant

Answers: "how much of module M does entry point X actually touch?" in one number, plus a
breakdown of which specific helper functions are (or are not) reached. Reuses Shape 1's `collect`
verbatim; the only addition is resolving each reached constant's OWN module via
`env.getModuleIdxFor?` and comparing it against a target module's index.

```lean
import YourProject.SomeModule

open Lean
namespace DepTrace2

partial def collect (env : Environment) (visited : Std.HashSet Name) (n : Name) :
    Std.HashSet Name :=
  if visited.contains n then visited
  else
    let visited := visited.insert n
    match env.find? n with
    | none => visited
    | some ci =>
      let deps := (ci.type.getUsedConstants ++ (ci.value?.map Expr.getUsedConstants).getD #[])
      deps.foldl (fun acc d => collect env acc d) visited

end DepTrace2

open DepTrace2 in
run_cmd do
  let env ← Lean.getEnv
  let cl := collect env {} `YourProject.entryPoint
  -- which specific helper functions does the entry point actually reach?
  let helpers : List Name := [ `YourProject.helperOne, `YourProject.helperTwo ]
  for h in helpers do
    logInfo m!"entryPoint reaches {h}? {cl.contains h}  (exists: {(env.find? h).isSome})"
  -- how many constants FROM a specific target module does the entry point reach at all?
  let targetModuleIdx := env.header.moduleNames.findIdx? (· == `YourProject.TargetModule)
  match targetModuleIdx with
  | none => logInfo "target module not in header"
  | some i =>
    let inModule := cl.toList.filter (fun n =>
      match env.getModuleIdxFor? n with
      | some j => j.toNat == i
      | none => false)
    logInfo m!"constants from TargetModule reached by entryPoint: {inModule.length}"
```

A `constants from TargetModule reached: 0` result strengthens Shape 1's "not these specific
suspect names" to "not this module at all" — the stronger, more legible claim. When the count is
non-zero, the per-helper breakdown usually explains WHY mechanically (e.g. the entry point calls
a sibling function at the same conceptual layer but never the specific helper the suspects are
about) rather than leaving the reader to re-derive it.

### Shape 3: Whole-Environment Reverse-Dependency Scan

Answers: "what would break if I deleted this?" — the question a retirement decision actually
needs, and the converse direction from Shapes 1-2 (which start from a known entry point and ask
what it reaches; this one starts from the suspects and asks what, anywhere in the whole
environment, reaches THEM). Iterates every non-internal declaration in the environment and
reports any whose type or value closure contains a suspect.

```lean
import YourProject  -- the root aggregator that transitively imports everything relevant

open Lean
namespace RevDep
def suspects : List Name := [ `YourProject.candidateForRetirement ]
end RevDep

open RevDep in
run_cmd do
  let env ← Lean.getEnv
  let sset := suspects.foldl (fun (s : Std.HashSet Name) n => s.insert n) {}
  let mut hits : Array (Name × Name) := #[]
  for (n, ci) in env.constants.toList do
    if sset.contains n then continue
    if n.isInternal then continue
    let deps := (ci.type.getUsedConstants ++ (ci.value?.map Expr.getUsedConstants).getD #[])
    for d in deps do
      if sset.contains d then hits := hits.push (n, d)
  logInfo m!"direct reverse-dependents across the whole environment: {hits.size}"
  for h in hits do logInfo m!"  {h.1}  ->  {h.2}"
```

Zero hits is a MUCH stronger result than Shapes 1-2's "the specific entry points I checked don't
reach it" — it means NOTHING anywhere in the (imported) library depends on the candidate, which
is exactly what makes a retirement decision cheap and safe.

### Shape 4: Import-Closure Check

Answers a different, prior question: is the target even REACHABLE from a given import at all,
before asking whether anything actually uses it? Distinguishes "unused" (present in the
environment, nothing depends on it — Shape 3's question) from "unavailable" (not even resolvable
under this import — a meaningfully stronger and different finding, e.g. the wrong module was
imported, or the declaration lives behind a namespace this import does not bring in).

```lean
import YourProject  -- the specific import whose reach you are checking

open Lean
run_cmd do
  let env ← Lean.getEnv
  for n in [`YourProject.nameOne, `YourProject.nameTwo, `YourProject.knownGoodName] do
    logInfo m!"{n} exists under this import: {(env.find? n).isSome}"
```

Run this FIRST, before Shapes 1-3: if a target or suspect name comes back `false` here, every
later "zero hits" result from Shapes 1-3 is ambiguous between "genuinely no dependency" and "the
name never resolved in the first place, so the traversal never had anything to find" — silently
the same failure mode Shape 1's own existence pre-check exists to rule out. Including at least
one name KNOWN to exist and be correctly spelled (`knownGoodName` above) also rules out a broken
import or a stale build producing a uniformly-false result that would otherwise look like a real
answer.

## Two Operational Notes

- **Run against existing oleans, not a full rebuild.** `lake env lean <probe-file>.lean` (or
  `lake env lean --` piping the file) elaborates the probe against the project's ALREADY-BUILT
  `.olean` artifacts. A trace that only reads the existing environment (every shape above) needs
  no `lake build` at all — the motivating trace ran all four shapes end to end with zero rebuild.
- **Resolve declarations by NAME, never by line number.** A prior research report's cited line
  numbers for the target declarations had already gone stale by the time the trace ran (a large
  file had grown/shifted between the report and the trace) — exactly the failure mode that would
  silently corrupt a line-number-based probe. Every shape above takes fully-qualified `Name`
  literals and resolves them via `env.find?`, never a source position.

## Usability Without the Originating Repository

Every code block above is a complete, standalone template with placeholder names
(`YourProject.*`) rather than a pointer into any specific repository's source tree — replace the
import and the name lists with your own project's targets/suspects/entry points and the probes
run as written. No path outside this file is the sole carrier of a probe's content.
