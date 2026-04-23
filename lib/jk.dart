// Backend API base URL.
//
// Override at build/run time with --dart-define=API_URL=... for deploys that
// point at a different backend. Default is the placeholder Render service
// name from `backend/flask/render.yaml` — rename/replace after you deploy.
//
//   flutter build web --dart-define=API_URL=https://grade-calc-api-xxxx.onrender.com/api
//
// If you are running the backend locally:
//   flutter run -d chrome --dart-define=API_URL=http://localhost:5000/api
String url = const String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://grade-calc-api.onrender.com/api',
);
