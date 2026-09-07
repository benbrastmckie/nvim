-- Custom fixture (not vendored from upstream): no upstream tests/projects/ fixture isolates a
-- PURE same-kind statement weakening -- simple_mismatch, simple_axiom_issue, and
-- simple_kind_mismatch all conflate a theorem-vs-axiom KIND mismatch with the statement
-- difference. This fixture keeps the declaration kind (theorem) identical on both sides and
-- only weakens the statement, so it hits Comparator's
-- "Challenge and solution theorem statement do not match" arm without touching the kind-mismatch
-- code path at all. See fixtures/comparator/README.md.

theorem comm (n m : Nat) : n + m = m + n := sorry
