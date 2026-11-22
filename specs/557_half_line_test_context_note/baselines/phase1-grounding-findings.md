# Phase 1 Grounding Findings

## Source (verbatim-grounded) text from the probe

File: `/home/benjamin/Projects/BimodalLogic/specs/evidence/seam-gluing-ray-product/one-sided-count-move-refutation.lean` (414 lines)

- The two questions (from "## The half-line test, which is the reusable product", lines 69-74):
  "which half-line is the COUNTER read from, and which half-line is the FORMULA read from. If
  both answers are 'forward', the proposal is already decided -- `cntAt_eq_of_pend_eq_fwd` kills
  the frozen-future direction and `Probe761S.splice_type_invariance_refuted` kills the
  freed-future direction. Do not restate the refuted shape in a half-line form and call it new."
- Pincer (one sentence, "## The pincer, in one sentence", lines 65-67): "The ladder's counter and
  the closure's eventualities are read from the SAME forward half-line, so freezing the future
  leaves nothing to transport and freeing it loses the type."
- Disclaimer ("## What this probe does NOT settle", lines 76-87): no decidability consequence in
  either direction; no finite-fibre and no finite-width assumption; `not_finite_width_fmp` stands
  untouched; no recorded Challenge statement weakened (`CellLEZeroConstOfKappaEq` /
  `cellLE_zero_const_of_kappa_eq` unchanged); the `LadderChain.lean` tight (doubling) chain gap is
  explicitly NOT a one-sidedness gap.

## Declaration resolution (all resolved; none dropped)

All in `one-sided-count-move-refutation.lean` unless noted, namespace `Probe855O` (opens line
121, closes line 396):
- `cntAt_eq_of_pend_eq_fwd` -- theorem at line 177.
- `cntAt_eq_of_lab_eq_fwd_of_pendFactorsLab` -- theorem at line 205.
- `futAtomPreservingCountMove_refuted` -- cited at line 41 (compiled theorem present in file;
  headline-named variant `futAtomPreservingCountMove_refutedO` is the object-level theorem at
  line 383).
- `atomPreservingCountMove_refuted_via_fwd` -- theorem at line 233.
- `futAtomPreservingCountMove_refutedO` -- theorem at line 383 (THE HEADLINE, no hypotheses).
- `PastAtomPreservingCountMove` -- def at line 131.
- `FutAtomPreservingCountMove` -- def at line 141.
- `Probe855O` -- namespace, confirmed.
- `Probe761S.splice_type_invariance_refuted` -- theorem at line 546 of
  `specs/evidence/seam-gluing-ray-product/ladder-splice-type-refutation.lean`, namespace
  `Probe761S` (opens line 121, closes line 554).
- `PlusLanguage.PlusRayFibre.plusStab_iff_rays` -- named verbatim in the probe's own docstring
  (line 9-10 of the probe) as the biconditional `⊡φ ↔ ▷◁φ ↔ ◁▷φ`; cited as stated by the probe,
  not independently re-resolved against the library in this task.
- `exists_spliced_ladderPath_of_pend_past` -- named verbatim in the probe's own docstring (line
  56) as the landed `▷`-shaped count move the `▷` side attributes.
- `not_finite_width_fmp` -- named verbatim in the probe's own disclaimer (line 79), "What this
  probe does NOT settle" paragraph, as the fact the note's disclaimer section carries forward
  unaltered.

Six-mechanism-table check: `grep -i -c "six" one-sided-count-move-refutation.lean` = 0. Confirms
the plan's citation decision: the probe file itself carries no six-mechanism table; that table
lives in the originating report
(`specs/archive/855_one_sided_open_modal_type_transport_probe/reports/01_one-sided-open-modal-transport.md`
in the BimodalLogic repository), not in the probe `.lean` file the dispatch description named.
The note will cite the probe files, never the archived report path (task-reference exemption
boundary).

## The two "six" sets (confirmed to differ)

Sibling note's six probe-file citations
(`agent-system/extensions/lean/context/project/lean4/domain/ladder-counter-observables.md`,
330 lines, no `half-line`/`half line`/`one-sided` hits -- confirms Phase 2 is authoring, not
duplicating):
- `counter-lift-gates.lean`
- `ladder-cell-index-obstructions.lean`
- `ladder-cell-refutation.lean`
- `ladder-joint-index-refutation.lean`
- `ladder-residue-index-refutation.lean`
- `no-pending-forever-ray.lean`

Originating report's mechanism-by-mechanism table (six rows, each naming one probe):
1. `ladder-cell-refutation.lean`
2. `ladder-cell-index-obstructions.lean`
3. `ladder-residue-index-refutation.lean`
4. `ladder-joint-index-refutation.lean`
5. `ladder-splice-type-refutation.lean`
6. `ladder-cell-agreement-refutation.lean`

Overlap: `ladder-cell-refutation.lean`, `ladder-cell-index-obstructions.lean`,
`ladder-residue-index-refutation.lean`, `ladder-joint-index-refutation.lean` (4 files).
Difference: table-only -- `ladder-splice-type-refutation.lean`, `ladder-cell-agreement-refutation.lean`;
sibling-only -- `counter-lift-gates.lean`, `no-pending-forever-ray.lean`.

Note: the plan's own Risk table characterizes the overlap as "three" files; the measured overlap
here is four. This does not change the governing conclusion (the sets do not coincide, so no
identity is asserted), and the note itself never states an overlap count -- it states only that
the two "six" sets are different enumerations with a different job, without transcribing either
table. Recorded via issue-log as a minor, non-blocking plan/measurement discrepancy.

## Baselines captured (for Phase 4 diff)

- `generate-context-line-counts.sh --check`: exit 0, "CHECK PASSED: all line_count values are
  exact" (see `phase1-line-counts-check.txt`).
- `verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`: exit 0, gate 3
  (doc-lint) PASS, gate 4 (task-reference lint) PASS, both observed RUNNING (not SKIPPED); "PASS
  -- 3 check(s), 0 failure(s)" (see `phase1-verify-deploy-gate34.txt`).
- `wc -l` pre-edit: `EXTENSION.md` = 41, `context/project/lean4/README.md` = 32,
  `domain/ladder-counter-observables.md` = 330 (see `phase1-wc-baseline.txt`).
