# Testing the Grade Calculator (Flutter web + Flask backend)

## What this skill covers

End-to-end runtime testing of the Grade Calculator app — log in, build a grading
flow, download the Excel template, upload a filled file, and verify the AI
column-mapping / override / re-grade loop works. Use this whenever the user
asks you to test this app (not for unit tests — those live in
`backend/flask/smoke_test.py`).

## Devin secrets needed

None. OTP is validated client-side and can be bypassed locally.

## Local stack (no Render deploy needed for testing)

There are two processes to run.

### 1. Flask backend on :5000

```bash
cd backend/flask
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python app.py        # NOT gunicorn — app.py binds 0.0.0.0:5000 directly
```

Smoke check: `curl -s http://localhost:5000/api/health` → `{"status":"ok"}`.

### 2. Flutter web on :8080

Flutter SDK is not preinstalled on the VM. If missing:

```bash
git clone --depth 1 -b stable https://github.com/flutter/flutter.git ~/flutter
export PATH="$HOME/flutter/bin:$PATH"
```

Then from the repo root:

```bash
flutter build web --no-tree-shake-icons        # ~75s cold build
cd build/web && python3 -m http.server 8080
```

## Two temporary patches required before `flutter build web`

Both must be **reverted** before reporting — and verified clean with
`git status`.

### a. Point the app at the local backend

`lib/jk.dart` hardcodes the external Render URL. Change its single line to
`http://localhost:5000/api` for the test run, revert afterwards. CORS is
wildcard-enabled on the Flask app (`flask_cors.CORS(app)`) so no other
config needed.

### b. Bypass OTP login

`lib/login.dart` line 28 generates `generatedOtp` with
`Random().nextInt(9000) + 1000` and validates it **client-side** against
the text field (lines ~253, 321, 348). The simplest bypass is to hardcode
it:

```dart
String generatedOtp = "1234";  // TEST BYPASS — revert before merge
```

Then at runtime just type `1234` in the OTP field. Email can be any string.

The real OTP send path uses emailjs which will fail without credentials —
that's fine, the client-side check is what the login button actually
gates on.

## Driving the UI — gotchas you will hit

### 1. The native file picker on Linux

File-selection dialogs are GTK's native picker (not an HTML `<input
type=file>`). To pick a file at a known absolute path like `/tmp/x.xlsx`:

```
computer.act: key ctrl+l   →  type /tmp/x.xlsx   →  key Return
```

Clicking through the Home/Desktop/Downloads shortcuts works but is
fragile; the ctrl+l path box is reliable.

### 2. Full-screen Lottie success overlay

Every time the user taps a grading-curve card in `division.dart`, the
code opens `showAdaptiveDialog` with `Lottie.asset("assets/done.json")`
as a full-screen check-mark. It does **not** auto-dismiss. Press `Escape`
to close it before continuing the flow. Don't assume the animation will
go away on its own — it won't.

### 3. Dashboard sub-chips

CSE shows three sub-chips (`CSE-A`, `CSE-B`, `BOTH`) only after `CSE` is
tapped. The currently-selected chip has the light/blue background; the
darker chips are the unselected ones. It's easy to misread and pick the
wrong section — check the Grading page's title bar (`Grading — CSE-A`
etc.) after clicking Next Step to confirm.

### 4. The Add-Division button moves after you add one

The Flutter layout reflows when the first division is added, so the
coordinates of the `Add Division` button shift down by ~30-40 px. Take a
screenshot after each Add and reselect coordinates; don't try to reuse
the same `[x,y]` across iterations.

### 5. Max Marks + Weight % live in Excel, not the UI

After this PR the dashboard only collects division **names**. A banner
tells the user the weights are in the template. Don't look for a
percentage input field — it's intentionally gone.

## A ready-to-upload sample (headers chosen to exercise fuzzy matching)

```python
# /tmp/make_filled_xlsx.py
import openpyxl, random
random.seed(42)
wb = openpyxl.Workbook(); ws = wb.active
ws.title = "CSE-A Filled"
ws.append(["Reg No", "Student Name", "mid_term", "ESE", "practical"])
ws.append(["",       "Max Marks",    30,          50,    20])
ws.append(["",       "Weight %",     30,          50,    20])
for i in range(1, 21):
    ws.append([f"25BCS{i:03d}", f"Student {i}",
               random.randint(15, 30),
               random.randint(25, 50),
               random.randint(10, 20)])
wb.save("/tmp/filled_sample.xlsx")
```

When uploaded with user-entered divisions `Mid Sem`, `End Sem`, `Lab`,
the backend's fuzzy matcher should map them at 100 % confidence
(`mid_term` → `Mid Sem`, `ESE` → `End Sem`, `practical` → `Lab`). If
confidence drops below ~70 % or any row reads `(no match)`, something
broke the synonym table in `backend/flask/matching.py`.

## End-to-end assertion checklist

1. Web template download: Chrome's download bar shows the `.xlsx` —
   if nothing happens, the `download_helper_web.dart` blob path is
   broken (the very bug this PR fixed).
2. Generated template row 1 = headers, row 2 = `Max Marks` label in
   column B, row 3 = `Weight %` label in column B, row 4 = first Reg No.
3. Reg No ranges (verify in `excel_service.dart::_regRange`):
   - CSE-A → 25BCS001 … 25BCS107 (107 rows)
   - CSE-B → 25BCS108 … 25BCS215 (108 rows, **no overlap**)
   - ECE   → 25BEC001 … 25BEC080
   - DSAI  → 25BDA001 … 25BDA110
4. After upload, the `AI Mapping` button appears in the app bar of the
   results page. Clicking it shows one card per sheet with division →
   detected-header dropdowns and a confidence %.
5. Changing a dropdown enables the blue `Re-grade with overrides`
   button (was grey). Clicking it changes the analytics subtitle to
   `Grades recalculated with your overrides` — that's the signal the
   `mapping_override` payload round-tripped successfully.

## Reporting

- Post exactly one comment on the PR with the 5-bullet pass/fail list,
  embedded screenshots via uploaded attachment URLs, and the session
  link.
- Attach the screen recording (`computer.record_start/stop`) and a
  `test-report.md` with more detail when replying to the user.
- Always list what you did **not** test (team-sheet UI upload, other
  sections, manual curve) — the user wants conservative claims.
