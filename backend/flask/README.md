# Grade Calculator — Flask Backend

A lightweight Flask API that:

* Stores uploaded Excel workbooks.
* Uses **fuzzy column matching** (`matching.py`) to align arbitrary column
  headers (e.g. `Mids`, `mid_term`, `MSE`) with the division names the
  instructor entered in the Flutter app.
* Reads both **individual** and **team** sheets and merges team scores into
  per-student percentages via reg-no membership.
* Computes weighted totals and letter grades using μ ± σ boundaries parsed
  from either a preset curve or a user-defined manual curve.
* Writes an Excel results workbook the user can download.

## Endpoints

| Method | Path                     | Purpose                                    |
| ------ | ------------------------ | ------------------------------------------ |
| GET    | `/api/health`            | liveness probe                             |
| GET    | `/api/templates`         | list preset grading curves                 |
| POST   | `/api/upload`            | upload one or more `.xlsx` workbooks       |
| POST   | `/api/detect`            | AI column-mapping preview (for UI confirm) |
| POST   | `/api/calculate-grades`  | compute weighted totals + letter grades    |
| GET    | `/download/<file_id>`    | download the generated results workbook    |

### `/api/calculate-grades` request body

```json
{
  "file_id": "abc123...",
  "divisions": {"Mid Sem": 30, "End Sem": 50, "Lab": 20},
  "template_id": "strict",
  "manual_boundaries": {"A Grade": "μ+1σ", ...},
  "mapping_override": {"Sheet1": {"Mid Sem": "mids"}}
}
```

If `divisions` weights are all `0`, the backend will read the
`Weight %` row from the uploaded Excel. If that row is also absent,
equal weights are used.

## Local development

```bash
cd backend/flask
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python app.py                 # starts on :5000
# or:
gunicorn --bind 0.0.0.0:5000 --workers 2 app:app
```

Smoke-test:

```bash
curl http://localhost:5000/api/templates
```

## Deploy to Render

`render.yaml` in this folder declares the service. On Render:

1. New → Blueprint → pick this repo.
2. Render will detect `backend/flask/render.yaml` and create the
   `grade-calculator-api` service.
3. Point the Flutter app at the service URL by editing
   [`lib/jk.dart`](../../lib/jk.dart) — change `url` to
   `https://<your-service>.onrender.com/api`.

## Project layout

```
backend/flask/
├── app.py              Flask app + route handlers
├── matching.py         Fuzzy column-name matching + synonym table
├── sheet_parser.py     openpyxl workbook reading / per-student scores
├── grading.py          Cutoff parsing + μ±σ grade assignment
├── excel_writer.py     Results workbook generator
├── requirements.txt
├── Procfile            Render / Heroku start command
└── render.yaml         Render blueprint
```
