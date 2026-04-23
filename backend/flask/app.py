"""Flask API for the Grade Calculator Flutter app.

Endpoints (kept backwards compatible with the previous deployment):

* ``GET  /api/templates``          list preset grading curves
* ``POST /api/upload``             upload one or more .xlsx workbooks
* ``POST /api/detect``             return AI-detected column mapping (preview)
* ``POST /api/calculate-grades``   compute weighted totals + letter grades
* ``GET  /download/<file_id>``     download the generated results workbook
* ``GET  /api/health``             liveness probe
"""

from __future__ import annotations

import os
import tempfile
import uuid
from typing import Dict, List

from flask import Flask, abort, jsonify, request, send_file
from flask_cors import CORS

from excel_writer import build_results_workbook
from grading import TEMPLATES, compute_grades
from sheet_parser import build_student_scores, parse_workbooks, preview_workbook

UPLOAD_DIR = os.environ.get("UPLOAD_DIR") or os.path.join(tempfile.gettempdir(), "gc_uploads")
OUTPUT_DIR = os.environ.get("OUTPUT_DIR") or os.path.join(tempfile.gettempdir(), "gc_outputs")
os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)

app = Flask(__name__)
CORS(app)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _store_upload(file_id: str, files) -> List[str]:
    paths: List[str] = []
    base = os.path.join(UPLOAD_DIR, file_id)
    os.makedirs(base, exist_ok=True)
    for i, f in enumerate(files):
        name = f.filename or f"upload_{i}.xlsx"
        safe = name.replace("/", "_").replace("\\", "_")
        path = os.path.join(base, safe)
        f.save(path)
        paths.append(path)
    return paths


def _resolve_upload(file_id: str) -> List[str]:
    base = os.path.join(UPLOAD_DIR, file_id)
    if not os.path.isdir(base):
        abort(404, description=f"file_id '{file_id}' not found")
    return [os.path.join(base, n) for n in sorted(os.listdir(base))
            if n.lower().endswith((".xlsx", ".xls", ".xlsm"))]


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
@app.get("/api/health")
def health() -> object:
    return jsonify({"status": "ok"})


@app.get("/api/templates")
def templates() -> object:
    return jsonify({
        "templates": [
            {"id": t["id"], "name": t["name"], "tag": t["tag"]}
            for t in TEMPLATES
        ]
    })


@app.post("/api/upload")
def upload() -> object:
    files = request.files.getlist("files")
    if not files:
        return jsonify({"error": "no files uploaded"}), 400
    file_id = uuid.uuid4().hex
    paths = _store_upload(file_id, files)
    return jsonify({
        "file_id": file_id,
        "files": [os.path.basename(p) for p in paths],
    })


@app.post("/api/detect")
def detect() -> object:
    """Return the AI-detected structure so the UI can preview + confirm."""
    data = request.get_json(silent=True) or {}
    file_id = data.get("file_id")
    divisions: Dict[str, float] = data.get("divisions") or {}
    if not file_id:
        return jsonify({"error": "file_id is required"}), 400
    paths = _resolve_upload(file_id)
    preview = preview_workbook(paths, list(divisions.keys()))
    return jsonify(preview)


@app.post("/api/calculate-grades")
def calculate_grades() -> object:
    data = request.get_json(silent=True) or {}
    file_id = data.get("file_id")
    divisions: Dict[str, float] = data.get("divisions") or {}
    template_id = data.get("template_id") or "strict"
    manual_boundaries = data.get("manual_boundaries")
    mapping_override = data.get("mapping_override")  # {sheet: {division: header}}
    # legacy flag (no-op, kept for compatibility)
    _ = data.get("auto_detect", False)
    _ = data.get("distribution_type")

    if not file_id:
        return jsonify({"error": "file_id is required"}), 400
    if not divisions:
        return jsonify({"error": "divisions is required"}), 400

    paths = _resolve_upload(file_id)
    division_names = list(divisions.keys())
    sheets = parse_workbooks(paths, division_names)
    student_scores, detected_max, mapping_used = build_student_scores(
        sheets, division_names, mapping_override=mapping_override,
    )

    # weights: prefer what the user supplied in the /calculate-grades request;
    # if they sent nothing / zeros, fall back to the weights declared in the
    # uploaded Excel; and if those are absent too, fall back to equal weights.
    weights: Dict[str, float] = {d: float(divisions.get(d) or 0) for d in division_names}
    if sum(weights.values()) == 0:
        # pull from any sheet that has a "Weight %" row
        for s in sheets:
            for div, header in mapping_used.get(s.sheet_name, {}).items():
                w = s.weights.get(header)
                if w:
                    weights[div] = max(weights.get(div, 0.0), float(w))
    if sum(weights.values()) == 0:
        weights = {d: 1.0 for d in division_names}

    result = compute_grades(
        student_scores=student_scores,
        weights=weights,
        template_id=template_id,
        manual_boundaries=manual_boundaries,
    )

    # Write results workbook
    xlsx = build_results_workbook(
        student_grades=result["student_grades"],
        student_scores=student_scores,
        weights=weights,
        chart_data=result["chart_data"],
        stats=result["stats"],
    )
    out_id = uuid.uuid4().hex
    out_path = os.path.join(OUTPUT_DIR, f"{out_id}.xlsx")
    with open(out_path, "wb") as fh:
        fh.write(xlsx)

    return jsonify({
        "student_grades": result["student_grades"],
        "chart_data": result["chart_data"],
        "stats": result["stats"],
        "division_breakdown": result["division_breakdown"],
        "weights_used": weights,
        "max_marks_detected": detected_max,
        "mapping_used": mapping_used,
        "download_url": f"/download/{out_id}",
    })


@app.get("/download/<file_id>")
def download(file_id: str):
    path = os.path.join(OUTPUT_DIR, f"{file_id}.xlsx")
    if not os.path.isfile(path):
        abort(404)
    return send_file(
        path,
        as_attachment=True,
        download_name="grades.xlsx",
        mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    )


@app.get("/")
def root() -> object:
    return jsonify({"service": "grade-calculator-api", "status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)), debug=True)
