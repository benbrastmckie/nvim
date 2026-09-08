#!/usr/bin/env python3
"""Normalized title similarity helper for zotero-resolve-pdf.sh and literature-ingest-online.sh.

Two modes:

- 2-argv mode (``sim.py TITLE_A TITLE_B``): prints a single float in [0, 1] (difflib
  SequenceMatcher ratio over lowercased, punctuation-stripped titles). Used by
  zotero-resolve-pdf.sh's title_similarity().
- Batch mode (``sim.py --batch CANDIDATE_TITLE``, existing titles on stdin, one per line):
  scores CANDIDATE_TITLE against every stdin title in a single process invocation and prints
  the best match as ``<score>\\t<original-existing-title>``. Short-circuits with score 1.0 on
  the first normalized-equality match, without scoring it. Used by
  literature-ingest-online.sh's check_duplicate_title() to avoid spawning one subprocess per
  index entry.
"""
import re
import sys
from difflib import SequenceMatcher


def normalize(s: str) -> str:
    s = s.lower()
    s = re.sub(r"[^a-z0-9\s]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def run_batch(candidate: str) -> None:
    norm_candidate = normalize(candidate)
    best_sim = 0.0
    best_title = ""
    if not norm_candidate:
        print(f"{best_sim}\t{best_title}")
        return
    for line in sys.stdin:
        existing_title = line.rstrip("\n")
        if not existing_title:
            continue
        norm_existing = normalize(existing_title)
        if not norm_existing:
            continue
        if norm_existing == norm_candidate:
            print(f"1.0\t{existing_title}")
            return
        sim = round(SequenceMatcher(None, norm_candidate, norm_existing).ratio(), 4)
        if sim > best_sim:
            best_sim = sim
            best_title = existing_title
    print(f"{best_sim}\t{best_title}")


def main() -> None:
    if len(sys.argv) == 3 and sys.argv[1] == "--batch":
        run_batch(sys.argv[2])
        return
    if len(sys.argv) != 3:
        print("0.0")
        return
    a, b = normalize(sys.argv[1]), normalize(sys.argv[2])
    if not a or not b:
        print("0.0")
        return
    print(round(SequenceMatcher(None, a, b).ratio(), 4))


if __name__ == "__main__":
    main()
