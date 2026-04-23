"""Fuzzy column matching.

Maps raw column headers in an uploaded Excel to the set of division names
the instructor defined, handling common synonyms and typos.

Two layers:
1. Canonical synonym groups — ``mid_term``, ``mids``, ``mse`` etc. all resolve
   to the same canonical token, so a target division called "Mid Sem" matches
   an Excel column called "mids" even though neither equals the other.
2. Fuzzy string similarity (``rapidfuzz``) as a fallback for anything that
   the synonym table doesn't cover.
"""

from __future__ import annotations

import re
from typing import Dict, Iterable, List, Optional, Tuple

from rapidfuzz import fuzz, process

# ---------------------------------------------------------------------------
# Synonym groups — every form in a group maps to the group's canonical key.
# Keep the keys lowercase / alnum-only; _normalize() enforces this.
# ---------------------------------------------------------------------------
_SYNONYM_GROUPS: List[List[str]] = [
    # Mid-semester examinations
    ["mids", "mid", "midterm", "midterms", "midsem", "midsems",
     "midterm1", "midterm2", "mid1", "mid2",
     "mse", "mse1", "mse2", "mids1", "mids2",
     "midsemester", "midsemexam", "midtermexam"],
    # End-semester examinations
    ["endsem", "endsems", "finalexam", "final", "finals", "ese",
     "endterm", "endsemester", "endsemexam", "endexam", "eseexam",
     "semfinal", "finalsem"],
    # Labs / practicals
    ["lab", "labs", "practical", "practicals", "laboratory",
     "labexam", "labtest", "labinternal", "labext", "labexternal",
     "labrecord", "labassignment"],
    # Quizzes / class tests
    ["quiz", "quizzes", "q1", "q2", "q3", "classtest", "classtests",
     "ct", "ct1", "ct2", "classquiz"],
    # Assignments / homework
    ["assignment", "assignments", "hw", "homework", "assn",
     "assgn", "hwk", "homeassignment"],
    # Projects
    ["project", "projects", "proj", "miniproject", "mainproject",
     "capstone", "capstoneproject", "teamproject", "groupproject"],
    # Attendance
    ["attendance", "attn", "att", "present", "classattendance"],
    # Viva / orals
    ["viva", "voce", "vivavoce", "oral", "orals"],
    # Seminar / presentation
    ["seminar", "seminars", "presentation", "presentations",
     "techseminar", "ppt"],
    # Internal (generic bucket — "internal assessment")
    ["internal", "internals", "iat", "ia", "continuousassessment", "cca", "ca"],
    # External
    ["external", "externals", "endexam", "endexternal"],
]


def _normalize(text: str) -> str:
    """Lower-case, strip everything that isn't alphanumeric."""
    return re.sub(r"[^a-z0-9]", "", (text or "").lower())


def _canonicalize(text: str) -> str:
    """Return the canonical token for ``text`` via the synonym table.

    If no synonym matches, the normalized form of ``text`` is returned so
    exact-match lookups still work.
    """
    norm = _normalize(text)
    if not norm:
        return ""
    for group in _SYNONYM_GROUPS:
        if norm in group:
            return group[0]  # first entry = canonical
        # also allow partial match: "mids1" → any "mids*" group containing it
    # sometimes a header is "Mid Term (out of 30)" etc.; after normalize that
    # becomes "midtermoutof30" — try to find a synonym as a prefix
    for group in _SYNONYM_GROUPS:
        for alias in group:
            if norm.startswith(alias) or alias in norm:
                return group[0]
    return norm


def match_columns(
    candidate_headers: Iterable[str],
    division_names: Iterable[str],
    cutoff: int = 70,
) -> Tuple[Dict[str, Optional[str]], Dict[str, float]]:
    """Map each division name to the best-fit Excel header.

    Returns
    -------
    mapping : dict[division_name -> header_in_excel | None]
    scores  : dict[division_name -> confidence 0..100]
    """
    divisions = [d for d in division_names if d and d.strip()]
    headers = [h for h in candidate_headers if h and str(h).strip()]

    # Pre-canonicalize both sides
    header_canon = {h: _canonicalize(h) for h in headers}
    division_canon = {d: _canonicalize(d) for d in divisions}

    mapping: Dict[str, Optional[str]] = {}
    scores: Dict[str, float] = {}
    used_headers: set[str] = set()

    # Pass 1: exact canonical match
    for div in divisions:
        want = division_canon[div]
        for h in headers:
            if h in used_headers:
                continue
            if header_canon[h] == want and want:
                mapping[div] = h
                scores[div] = 100.0
                used_headers.add(h)
                break

    # Pass 2: fuzzy match on the canonicalized tokens
    remaining_divs = [d for d in divisions if d not in mapping]
    remaining_headers = [h for h in headers if h not in used_headers]

    for div in remaining_divs:
        if not remaining_headers:
            mapping[div] = None
            scores[div] = 0.0
            continue
        want = division_canon[div] or _normalize(div)
        choices = {h: header_canon[h] or _normalize(h) for h in remaining_headers}
        # rapidfuzz wants a list; use token_set_ratio for resilience
        result = process.extractOne(
            want,
            list(choices.values()),
            scorer=fuzz.token_set_ratio,
        )
        if result is None:
            mapping[div] = None
            scores[div] = 0.0
            continue
        best_canon, score, idx = result
        best_header = list(choices.keys())[idx]
        if score >= cutoff:
            mapping[div] = best_header
            scores[div] = float(score)
            used_headers.add(best_header)
            remaining_headers.remove(best_header)
        else:
            mapping[div] = None
            scores[div] = float(score)

    return mapping, scores


def detect_header_row(rows: List[List[object]], max_scan: int = 5) -> int:
    """Heuristic: pick the row most likely to be the header.

    A header row typically has the most non-empty string cells among the
    first few rows.
    """
    best_idx = 0
    best_score = -1
    for i, row in enumerate(rows[:max_scan]):
        score = sum(1 for c in row if isinstance(c, str) and c.strip())
        if score > best_score:
            best_score = score
            best_idx = i
    return best_idx


def detect_max_marks_row(
    rows: List[List[object]],
    header_idx: int,
    max_scan: int = 3,
) -> Optional[int]:
    """Find the row that contains max marks, i.e. mostly numbers after the header."""
    for offset in range(1, max_scan + 1):
        idx = header_idx + offset
        if idx >= len(rows):
            break
        row = rows[idx]
        label_cell = next((c for c in row if isinstance(c, str) and c.strip()), "")
        if _normalize(label_cell) in {"maxmarks", "outof", "max", "maxmark", "totalmarks"}:
            return idx
    return None


def detect_weight_row(
    rows: List[List[object]],
    header_idx: int,
    max_scan: int = 4,
) -> Optional[int]:
    """Find the row that contains weight % values (same heuristic as max marks)."""
    for offset in range(1, max_scan + 1):
        idx = header_idx + offset
        if idx >= len(rows):
            break
        row = rows[idx]
        label_cell = next((c for c in row if isinstance(c, str) and c.strip()), "")
        norm = _normalize(label_cell)
        if norm in {"weight", "weightage", "weights", "weightpercent", "weightpct", "percent", "percentage"}:
            return idx
    return None
