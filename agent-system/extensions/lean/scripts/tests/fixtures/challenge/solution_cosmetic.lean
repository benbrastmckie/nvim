import Mathlib.Algebra.Group.Basic

theorem comm
    (n m : Nat) :
    n + m = m + n := by
  -- reformatted, semantically identical statement
  ring
