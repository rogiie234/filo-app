# filo-app

This repository contains the unified Filo project:

- `frontend/`: Flutter Android app.
- `backend/`: backend configuration and future Supabase implementation. Local `.env` files are ignored.
- `docs/`: requirements, schema, implementation plan, assets, and non-secret project decisions.

The Flutter Android application lives in `frontend/`.

```powershell
cd frontend
flutter pub get
flutter run -d <device-id>
```

See [frontend/README.md](frontend/README.md) for setup and validation details.
