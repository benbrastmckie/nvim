-- Custom fixture (not vendored from upstream) -- see Challenge.lean and
-- fixtures/comparator/README.md. Same declaration kind (theorem) as Challenge, but the
-- statement is strictly weaker: an added hypothesis `h : n = m` lets `omega` close a claim
-- that is not the one Challenge asked for.

theorem comm (n m : Nat) (h : n = m) : n + m = m + n := by omega
