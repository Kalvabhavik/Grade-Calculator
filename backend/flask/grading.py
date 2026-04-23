"""Compute weighted averages and letter grades based on μ ± σ boundaries."""

from __future__ import annotations

import re
import statistics
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

# Preset grading curves served via /api/templates.
TEMPLATES: List[Dict[str, object]] = [
    {
        "id": "strict",
        "name": "Strict Curve",
        "tag": "Tough grading",
        "boundaries": [
            ("A Grade",  "μ+1.5σ"),
            ("A- Grade", "μ+1σ"),
            ("B Grade",  "μ+0.5σ"),
            ("B- Grade", "μ"),
            ("C Grade",  "μ-0.5σ"),
            ("C- Grade", "μ-1σ"),
            ("D Grade",  "μ-1.5σ"),
            ("F Grade",  "<μ-1.5σ"),
        ],
    },
    {
        "id": "moderate",
        "name": "Moderate Curve",
        "tag": "Balanced grading",
        "boundaries": [
            ("A Grade",  "μ+1σ"),
            ("A- Grade", "μ+0.5σ"),
            ("B Grade",  "μ"),
            ("B- Grade", "μ-0.5σ"),
            ("C Grade",  "μ-1σ"),
            ("C- Grade", "μ-1.5σ"),
            ("D Grade",  "μ-2σ"),
            ("F Grade",  "<μ-2σ"),
        ],
    },
    {
        "id": "lenient",
        "name": "Lenient Curve",
        "tag": "Easy grading",
        "boundaries": [
            ("A Grade",  "μ+2σ"),
            ("A- Grade", "μ+1.5σ"),
            ("B Grade",  "μ+0.8σ"),
            ("B- Grade", "μ+0.2σ"),
            ("C Grade",  "μ-0.5σ"),
            ("C- Grade", "μ-1σ"),
            ("D Grade",  "μ-1.5σ"),
            ("F Grade",  "<μ-1.5σ"),
        ],
    },
    {
        "id": "bellcurve",
        "name": "Bell Curve",
        "tag": "Classic normal distribution",
        "boundaries": [
            ("A Grade",  "μ+2.5σ"),
            ("A- Grade", "μ+2σ"),
            ("B Grade",  "μ+1σ"),
            ("B- Grade", "μ"),
            ("C Grade",  "μ-1σ"),
            ("C- Grade", "μ-2σ"),
            ("D Grade",  "μ-2.5σ"),
            ("F Grade",  "<μ-2.5σ"),
        ],
    },
    {
        "id": "flat",
        "name": "Flat Curve",
        "tag": "Tight grading spread",
        "boundaries": [
            ("A Grade",  "μ+1.5σ"),
            ("A- Grade", "μ+1σ"),
            ("B Grade",  "μ+0.5σ"),
            ("B- Grade", "μ"),
            ("C Grade",  "μ-0.5σ"),
            ("C- Grade", "μ-1σ"),
            ("D Grade",  "μ-1.5σ"),
            ("F Grade",  "<μ-1.5σ"),
        ],
    },
]


@dataclass
class Cutoff:
    grade: str
    lower: float  # inclusive
    upper: Optional[float]  # exclusive; None = +infinity


_FORMULA = re.compile(
    r"^\s*<?\s*[μu]\s*([+\-])\s*([0-9]+(?:\.[0-9]+)?)?\s*[σs]?\s*$"
)


def _parse_formula(formula: str) -> Optional[float]:
    """Parse a boundary formula like ``μ+1.5σ`` into a σ-multiplier (``+1.5``).

    ``μ`` alone returns ``0.0``. Returns ``None`` if unparseable.
    """
    if not formula:
        return None
    f = formula.strip().replace(" ", "")
    if f in {"μ", "u"}:
        return 0.0
    f = f.lstrip("<")
    m = _FORMULA.match(f)
    if not m:
        return None
    sign, mag = m.group(1), m.group(2)
    mag_val = float(mag) if mag else 1.0
    return mag_val if sign == "+" else -mag_val


def build_cutoffs(
    boundaries: List[Tuple[str, str]],
    mean: float,
    stddev: float,
) -> List[Cutoff]:
    """Turn ``[(grade, formula)]`` into sorted descending ``Cutoff`` intervals."""
    parsed: List[Tuple[str, float]] = []
    fail_grade: Optional[str] = None
    for grade, formula in boundaries:
        if formula.strip().startswith("<"):
            fail_grade = grade
            parsed.append((grade, _parse_formula(formula) or 0.0))
            continue
        mult = _parse_formula(formula)
        if mult is None:
            continue
        parsed.append((grade, mult))

    # Sort descending by multiplier so A is on top
    parsed.sort(key=lambda x: -x[1])

    cutoffs: List[Cutoff] = []
    for i, (grade, mult) in enumerate(parsed):
        lower = mean + mult * stddev
        upper = (mean + parsed[i - 1][1] * stddev) if i > 0 else None
        cutoffs.append(Cutoff(grade=grade, lower=lower, upper=upper))
    # Tail: ensure lowest bucket covers everything below
    if cutoffs:
        cutoffs[-1].lower = float("-inf")
    if fail_grade and not any(c.grade == fail_grade for c in cutoffs):
        cutoffs.append(Cutoff(grade=fail_grade, lower=float("-inf"), upper=None))
    return cutoffs


def assign_grade(score: float, cutoffs: List[Cutoff]) -> str:
    for c in cutoffs:
        if score >= c.lower and (c.upper is None or score < c.upper):
            return c.grade
    return cutoffs[-1].grade if cutoffs else "F Grade"


def weighted_totals(
    student_scores: Dict[str, Dict[str, float]],
    weights: Dict[str, float],
) -> Dict[str, float]:
    """Weighted-average percentage per student. Missing divisions treated as 0."""
    total_weight = sum(weights.values()) or 1.0
    out: Dict[str, float] = {}
    for reg, divs in student_scores.items():
        total = 0.0
        for div, w in weights.items():
            total += divs.get(div, 0.0) * (w / total_weight)
        out[reg] = round(total, 2)
    return out


def compute_grades(
    student_scores: Dict[str, Dict[str, float]],
    weights: Dict[str, float],
    template_id: str,
    manual_boundaries: Optional[Dict[str, str]] = None,
) -> Dict[str, object]:
    totals = weighted_totals(student_scores, weights)
    values = list(totals.values())

    if not values:
        return {
            "student_grades": {},
            "chart_data": [],
            "stats": {"mean": 0, "stddev": 0, "min": 0, "max": 0, "count": 0},
            "division_breakdown": {},
        }

    mean = statistics.fmean(values)
    stddev = statistics.pstdev(values) if len(values) > 1 else 0.0

    if template_id == "manual" and manual_boundaries:
        boundaries = list(manual_boundaries.items())
    else:
        tpl = next((t for t in TEMPLATES if t["id"] == template_id), TEMPLATES[0])
        boundaries = list(tpl["boundaries"])  # type: ignore[arg-type]

    cutoffs = build_cutoffs(boundaries, mean, stddev)

    student_grades: Dict[str, Dict[str, object]] = {}
    grade_counts: Dict[str, int] = {c.grade: 0 for c in cutoffs}
    for reg, total in totals.items():
        g = assign_grade(total, cutoffs)
        student_grades[reg] = {"total_percent": total, "grade": g}
        grade_counts[g] = grade_counts.get(g, 0) + 1

    chart_data = [
        {"grade": g, "count": grade_counts.get(g, 0)}
        for g, _ in boundaries
    ]

    # Per-division averages for breakdown
    per_div: Dict[str, Dict[str, float]] = {}
    for div in weights.keys():
        vals = [s.get(div, 0.0) for s in student_scores.values() if div in s]
        if not vals:
            per_div[div] = {"mean": 0.0, "min": 0.0, "max": 0.0, "count": 0}
            continue
        per_div[div] = {
            "mean": round(statistics.fmean(vals), 2),
            "min": round(min(vals), 2),
            "max": round(max(vals), 2),
            "count": len(vals),
        }

    return {
        "student_grades": student_grades,
        "chart_data": chart_data,
        "stats": {
            "mean": round(mean, 2),
            "stddev": round(stddev, 2),
            "min": round(min(values), 2),
            "max": round(max(values), 2),
            "count": len(values),
        },
        "division_breakdown": per_div,
    }
