# Lean 4 Measurement Harnesses: Force Before You Read the Clock

How to avoid a false "0 ms" reading when timing a staged computation in Lean 4, and why binding
the measured value with a pure `let` is not enough to make it count toward the measured window.
Harvested from one case where several probe rounds chased phantom hangs before the real cause (a
floated-past-the-clock-read computation, not a hang) was identified.

## The Pitfall

A harness shaped like this reports 0 ms for every stage, regardless of how expensive the staged
computation actually is:

```lean
let startedAt ← IO.monoMsNow
let result := expensiveComputation x   -- a pure `let`
let finishedAt ← IO.monoMsNow
IO.println s!"stage took {finishedAt - startedAt}ms"
IO.println s!"{result}"
```

`result` is bound by a pure `let`: nothing in the harness forces its evaluation before the second
clock read, so Lean is free to float the actual computation of `expensiveComputation x` to
whenever it is first demanded — which may be well after `finishedAt` is already read, or may be
interleaved arbitrarily with later stages. The measured interval and the interval in which the
work actually happens are two different things, and nothing in the harness ties them together.
The failure mode this produces is not a crash or a visible error: every stage simply reports
`0ms`, which reads exactly like a bug in the clock calls rather than a sequencing problem, and is
easy to mistake for a hang elsewhere in the pipeline.

## The Fix

Force the value through an `IO` action — e.g. print it, or otherwise consume it in a way that the
`IO` monad's sequencing actually orders — before the second clock read, so evaluation is pulled
inside the measured window:

```lean
let startedAt ← IO.monoMsNow
let result := expensiveComputation x
IO.println s!"{result}"             -- forces `result` here, inside the measured window
let finishedAt ← IO.monoMsNow
IO.println s!"stage took {finishedAt - startedAt}ms"
```

## The General Rule

A pure `let` binding is never itself evidence that a value has been computed — only `IO`
sequencing (or an explicit strict-evaluation primitive) orders work relative to other `IO`
actions, including clock reads. Any measurement harness that reports suspiciously uniform or
suspiciously small durations for stages known to do real work should be checked for exactly this
shape before any other explanation (a hang, a broken clock call, a cache hit) is pursued.
