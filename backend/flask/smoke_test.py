"""End-to-end smoke test for the Flask backend.

Runs the app in-process using Flask's test client so we don't need to
spin up gunicorn. Exercises upload → detect → calculate-grades →
download.
"""

from __future__ import annotations

import io
import json
import sys

import openpyxl

import app as backend


def build_sample_individual_xlsx() -> bytes:
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "CSE-A Individual"
    # Intentionally use weird column names so the fuzzy matcher has to work:
    # "Mids" for Mid Sem, "ESE" for End Sem, "practical" for Lab
    headers = ["Reg No", "Student Name", "Mids", "ESE", "practical"]
    max_marks = ["", "Max Marks", 30, 50, 20]
    weights = ["", "Weight %", 30, 50, 20]
    ws.append(headers)
    ws.append(max_marks)
    ws.append(weights)
    # 10 synthetic students
    for i in range(1, 11):
        ws.append([f"25BCS{i:03d}", f"Student {i}",
                   20 + (i % 10), 30 + (i % 20), 12 + (i % 8)])
    buf = io.BytesIO()
    wb.save(buf)
    buf.seek(0)
    return buf.getvalue()


def build_sample_team_xlsx() -> bytes:
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Team Sheet"
    headers = ["Team ID", "Team Name", "Members Reg Nos", "Project", "Seminar"]
    max_marks = ["", "", "Max Marks", 50, 20]
    weights = ["", "", "Weight %", 70, 30]
    ws.append(headers)
    ws.append(max_marks)
    ws.append(weights)
    ws.append(["T001", "Alpha", "25BCS001,25BCS002,25BCS003", 42, 16])
    ws.append(["T002", "Bravo", "25BCS004,25BCS005", 38, 18])
    ws.append(["T003", "Charlie", "25BCS006,25BCS007,25BCS008,25BCS009,25BCS010", 45, 19])
    buf = io.BytesIO()
    wb.save(buf)
    buf.seek(0)
    return buf.getvalue()


def main() -> int:
    client = backend.app.test_client()

    # --- templates
    r = client.get("/api/templates")
    assert r.status_code == 200, r.data
    assert "templates" in r.get_json()

    # --- upload
    ind = build_sample_individual_xlsx()
    team = build_sample_team_xlsx()
    r = client.post(
        "/api/upload",
        data={
            "files": [
                (io.BytesIO(ind), "individual.xlsx"),
                (io.BytesIO(team), "team.xlsx"),
            ]
        },
        content_type="multipart/form-data",
    )
    assert r.status_code == 200, r.data
    file_id = r.get_json()["file_id"]

    divisions = {
        "Mid Sem": 30,
        "End Sem": 50,
        "Lab": 20,
        "Project": 70,
        "Seminar": 30,
    }

    # --- detect
    r = client.post("/api/detect", json={"file_id": file_id, "divisions": divisions})
    assert r.status_code == 200, r.data
    preview = r.get_json()
    print("=== Detected sheet mapping ===")
    print(json.dumps(preview, indent=2))

    # --- calculate
    r = client.post(
        "/api/calculate-grades",
        json={
            "file_id": file_id,
            "divisions": divisions,
            "template_id": "strict",
        },
    )
    assert r.status_code == 200, (r.status_code, r.data)
    res = r.get_json()
    print("=== Calculation result ===")
    print(json.dumps({
        "stats": res["stats"],
        "chart_data": res["chart_data"],
        "weights_used": res["weights_used"],
        "sample_grades": dict(list(res["student_grades"].items())[:3]),
    }, indent=2))

    # --- download
    dl_url = res["download_url"]
    r = client.get(dl_url)
    assert r.status_code == 200
    assert r.data[:2] == b"PK", "downloaded file should be a zip/xlsx"
    print(f"Download ok ({len(r.data)} bytes)")

    print("\nALL OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
