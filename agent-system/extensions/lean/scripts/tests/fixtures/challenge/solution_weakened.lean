import Mathlib.Algebra.Group.Basic

theorem comm (n m : Nat) (h : n = m) : n + m = m + n := by
  ring
