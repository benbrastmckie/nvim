# Comparator Trust Model

This file is the operator-facing companion to
`agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md` (the
clean-room runner's design record). That file explains how `lean-comparator-run.sh` invokes
Comparator; this one explains, in plain language and without overclaiming, what a Comparator
verdict does and does not mean. Reach for this document when deciding how much weight a
Comparator result should carry, or when explaining that weight to someone else.

Comparator (Apache-2.0, `github.com/leanprover/comparator`) is a trustworthy judge for Lean
proofs from untrusted sources, built by Lean FRO with AIMO feedback. An operator reaches for it
when a proof was produced by an untrusted process — most relevantly here, an LLM implementation
agent — and a stronger-than-`lake build` guarantee is wanted before trusting the result.

## What a Green Result Certifies

Quoted verbatim from the upstream README. A `verified` verdict means the named theorems:

- "Prove the same statement as provided in `Challenge`"
- "Use no more axioms than listed in `permitted_axioms`"
- "Be accepted by the Lean kernel"

These three properties are exactly what Comparator's four build/export/statement-check/axiom-check
steps and its final kernel replay establish — no more, no less.

## What This Does NOT Certify

This is the important section. Read it before treating any Comparator verdict as a blanket
stamp of approval.

- **It does not certify that the Challenge asked the right question.** Comparator's guarantee is
  relative to `Challenge.lean` — the statements it was given to check against. If the Challenge
  itself states the wrong theorem, states a weaker theorem than intended, or omits hypotheses
  that matter, a `verified` Solution proves exactly that wrong, weak, or incomplete statement.
  Comparator has no way to know what the Challenge *should* have said.
- **It does not certify definition-hole solutions.** Upstream is explicit: "all definition hole
  solutions **must** always be checked with an additional (potentially human) verifier."
  Comparator's structural comparison of a `definition_names` entry only confirms that the
  Challenge and Solution definitions match each other and that the kernel accepts the replay — it
  does not confirm the filled-in definition is a *legitimate* answer to the problem. Upstream's
  own example: a `RiemannHypothesis` definition can be gamed by making it a false or degenerate
  proposition that is trivially provable, while still passing every structural check. Any task
  whose plan involves a `definition_names` check needs a human (or separately-trusted) reviewer
  in the loop; Comparator alone is not sufficient there.
- **The guarantee is conditional, not absolute.** It holds only when every one of upstream's six
  assumptions holds — see the next section. A `verified` verdict from a run where an assumption
  was silently violated is not the guarantee it appears to be.

## The Six Assumptions

Quoted verbatim from the upstream README:

1. **Trusted imports**: "The transitive closure of imports of `Challenge.lean` as well as
   `lakefile.toml`/`lakefile.lean` are controlled by you or trustworthy."
2. **No prior compilation** — a live concern here: "You have not previously tried to compile the
   `Solution` file or any other potentially adversarial files (as that might compromise your
   `Challenge` file to make it seem like you are looking for a different proof than you actually
   are)". This is violated by this system's *normal* workflow: `lean-implementation-agent`
   compiles continuously as it works. The mitigation is the clean-room worktree design in
   `comparator-integration.md` — a fresh `git worktree` populated via `lake exe cache get` before
   the Solution module is ever written into it — but that mitigation depends on the worktree
   genuinely never having seen the Solution file before Comparator runs. A caller that reuses a
   worktree the agent already built in violates this assumption silently.
3. **Binaries available**: "You have the `landrun` and `lean4export` binary in `PATH`"
4. **Landrun correctness** — a live concern here: "`landrun` works correctly on your system and
   `Solution.lean` does not exploit any bugs in `landrun` that allow a process to escape its
   sandbox". This system has no independent way to verify landrun's sandboxing correctness on any
   given host; it is taken on trust in the same way any other security-relevant system dependency
   is.
5. **Kernel correctness**: "The Lean kernel is correct (with `external_kernels` this can be
   reduced to 'At least one of the Lean kernel or the `external_kernels` is correct')"
6. **Privilege level**: "You are not running this under a privileged user"

## Trusted Computing Base

Quoted verbatim from the upstream README: "The Trusted Code Base of Landrun naturally includes
the operating system and hardware it is running on, plus its sandboxing mechanism." A Comparator
verdict is therefore only as trustworthy as the OS, the hardware, and landrun's own sandboxing —
none of which Comparator (or this integration) independently verifies.

## Version Coupling (C3)

Quoted verbatim from the upstream README, Comparator's own binary requirement: "lean4export, at a
version that is compatible with whatever Lean version your project is targeting, present in
`PATH`." This is a constraint on the *checking environment*, not on Comparator's own toolchain —
`lean4export` must be built against the target project's Lean version, not Comparator's own
pinned `lean-toolchain`.

Run `/lean doctor` to check this. The doctor's version verdict for `lean4export` is one of four
values: `matched`, `mismatched`, a not-applicable note when `lean4export` is absent, or
`UNKNOWN (cannot verify)` when no `lean-toolchain` file can be found by walking up from the
resolved binary's path. **`UNKNOWN (cannot verify)` is not a pass.** It means the doctor could not
determine version compatibility one way or the other — treat it as a reason to check manually,
never as evidence that lean4export is correctly matched.

## Current Gate Strength

`--compare` is **advisory only** today. A Comparator rejection is recorded and surfaced
prominently in the implementation summary, but it does not set `verification_passed` false, does
not downgrade task status to partial, and does not block completion. Promotion to a hard gate is
a separate, later decision to be made on evidence from real runs — nothing in this document or in
`--compare`'s current wiring should be read as though that promotion has already happened. See
`context/project/lean4/standards/proof-debt-policy.md` for how this interacts with the zero-debt
completion requirement, which today is still enforced by its own greps, not by Comparator.

## See Also

`context/project/lean4/domain/comparator-integration.md` covers the implementation detail this
document deliberately omits: the clean-room worktree trust chain, the verdict-string vocabulary,
sandbox/guard nesting, and the runner's CLI flags.
