# Dash Monorepo

Monorepo that hosts three Flutter apps (Mobile, Web, SuperAdmin) which reuse shared packages for UI, BLoC utilities, services, models, and helpers.

## Structure

```
apps/
  dash_mobile/        # Android-first experience sharing modules with web
  dash_web/           # Web dashboard experience
  dash_superadmin/    # Dedicated SuperAdmin portal with Firebase phone auth
packages/
  core_ui/            # Dash design system + responsive layout primitives
  core_bloc/          # Base blocs, observers, and state utilities
  core_services/      # Abstract repositories for Firebase-backed services
  core_models/        # Shared entities and models
  core_utils/         # Constants, extensions, responsive helpers
configs/              # Environment + setup docs (Firebase, etc.)
melos.yaml            # Workspace definition
```

Use `melos bootstrap` at the repo root to install dependencies for every app/package.
