# Adversarial Verification Contract (H4) — TypeScript Narrowing

This contract narrows the generic `adversarial-verification.md` contract for TypeScript
implementation work. The generic contract governs how a RESEARCH claim earns a confidence tag
(claim quoted, source cited, verification method named, confidence assigned) — it says nothing
about verifying a TYPE-SAFETY change against a compiler, which is the distinct failure mode this
narrowing closes. Its single demand: **the compiler, not the author, is the oracle.**

## The Compiler Is the Oracle

A claimed type-safety fix is **unverified** until `tsc --noEmit` (or the project's own declared
typecheck command — see `tools/package-manager-detection.md`) has been RUN in this dispatch and
observed green. "The edit looks correct" or "this narrows the type as intended" are not
verification — they are the claim, not its check. Every type-safety claim in a phase's
verification notes must name the exact command run and its exit code.

## Call-Site Exercising

A narrowed, re-typed, or newly-validated value must be exercised at the call sites that
motivated the change, not only checked at its own declaration site. A type annotation can be
locally correct and still leave a call site silently relying on the old, wider type (for
example, a call site that still performs its own redundant narrowing the new type makes
unnecessary, or one that was never type-checking the value at all because it flowed through an
`any` upstream). `grep` for the symbol across the codebase and name, in the verification notes,
which call sites were actually checked — not merely "all call sites," which is the research
contract's own forbidden "sources agree"-shaped non-answer applied to code.

## Claim-Weakening Constructs Must Be Named

`any`, `as`-casts, `@ts-expect-error`, and `@ts-ignore` each silence the compiler at exactly the
point where its judgment was supposed to apply. Introducing any one of them is not forbidden
outright, but it IS a claim-weakening act that must be named explicitly in the phase's
verification notes together with the reason no typed alternative was available (e.g. "the
third-party library's own types do not express this discriminated-union narrowing, so an
`as`-cast is used at line N, scoped to the single call site that needs it"). An unnamed `any` or
`as`-cast is a contract violation regardless of whether the surrounding code otherwise type-checks.

## Subset Honesty

A green typecheck against a subset of the program — one project reference, one workspace
package, one `tsconfig.json` among several in a monorepo — is reported as the subset it was,
never generalized to a whole-repository pass. State explicitly which project reference or
package was checked and which, if any, were not reached by that invocation. This mirrors the
generic contract's own Confidence Level Taxonomy in spirit (a single, uncross-checked source
earns Medium, not High) applied to build/typecheck scope instead of citation scope.

## Domain Specialization

- "Verification Method" (element 3 of the generic contract's Claim Verification Bar, where this
  narrowing's claims are implementation-stage rather than research-stage) is satisfied for a
  TypeScript type-safety claim by naming the exact `tsc`/package-manager-script invocation run
  and its exit code — never by a description of what the edit is expected to do.
- This file is the TypeScript-extension override, additive to the generic
  `@.claude/context/contracts/adversarial-verification.md` baseline (not a `replace:` form) —
  both are injected together into a `--hard` dispatch for `task_type: "typescript"`, since the
  generic contract's research-claim obligations and this contract's compiler-oracle obligations
  govern non-overlapping claim shapes within the same task.
