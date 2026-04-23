# Grade Calculator

Flutter web + Flask backend for computing weighted-average grades from
Excel marksheets. Handles individual and team divisions, fuzzy column
matching, and user-overridable AI column mappings.

## Architecture

- **Frontend** — Flutter (web / desktop / mobile). Entrypoint `lib/main.dart`.
  Backend URL lives in `lib/jk.dart`.
- **Backend** — Flask REST API in `backend/flask/`. See its
  [README](backend/flask/README.md) for endpoints and grading logic.

## Deploying the backend to Render

The backend is designed to deploy as a Render Blueprint.

1. Go to Render → **New +** → **Blueprint**.
2. Connect this repo. Render will auto-detect `render.yaml` at the repo
   root and offer to create a service called `grade-calculator-api`
   with its root at `backend/flask`.
3. Click **Apply**. Render will build with `pip install -r requirements.txt`
   and run `gunicorn --bind 0.0.0.0:$PORT --workers 2 --timeout 120 app:app`.
4. When the service goes live, copy its public URL
   (e.g. `https://grade-calculator-api-abcd.onrender.com`).
5. Rebuild the Flutter app with that URL:

   ```bash
   flutter build web \
     --dart-define=API_URL=https://grade-calculator-api-abcd.onrender.com/api
   ```

   (Note the `/api` suffix — all routes live under `/api/*`.)

## Running locally

### Backend

```bash
cd backend/flask
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python app.py           # serves on :5000
```

### Frontend (pointed at the local backend)

```bash
flutter run -d chrome \
  --dart-define=API_URL=http://localhost:5000/api
```

## Project structure

```
render.yaml       Render Blueprint (at repo root; deploys backend/flask/)

backend/flask/    Flask REST API + grading pipeline
  app.py            endpoints
  matching.py       fuzzy column matcher (synonym table + RapidFuzz)
  sheet_parser.py   reads individual + team sheets, detects Max Marks & Weight %
  grading.py        μ±σ curves (strict/moderate/lenient/bellcurve/flat/manual)
  excel_writer.py   generates graded output workbook

lib/              Flutter app
  dashboard.dart    scope + division name entry
  division.dart    3-step grading flow (template → curve → upload)
  final.dart       analytics + AI mapping preview + override
  excel_service.dart  individual + team template generation
  download_helper*.dart  platform-aware .xlsx download
  jk.dart          backend URL (override with --dart-define=API_URL=...)
```

## Learn more

- [Flutter docs](https://docs.flutter.dev/)
- [Flask docs](https://flask.palletsprojects.com/)
