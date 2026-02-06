#!/usr/bin/env bash
# Operon monorepo: Flutter web deploy prep for Operon_Client_web
# Run from repo root: ./deploy_prep.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="${REPO_ROOT}/apps/Operon_Client_web"
BUILD_OUT="${APP_PATH}/build/web"

echo "==> Repo root: ${REPO_ROOT}"
echo "==> Web app:  ${APP_PATH}"
echo ""

# 1) Clean
echo "==> Cleaning..."
(cd "${APP_PATH}" && flutter clean)
echo ""

# 2) Get dependencies (path packages resolved from app dir)
echo "==> Getting dependencies..."
(cd "${APP_PATH}" && flutter pub get)
echo ""

# 3) Build web release (dart2js; --no-wasm required while using dart:html/dart:js)
# --base-href "/" ensures assets/AssetManifest.bin.json etc. resolve correctly (avoids 404).
# If deploying to a subpath (e.g. /client/), use: --base-href "/client/"
echo "==> Building web (release, canvaskit)..."
(cd "${APP_PATH}" && flutter build web --release --no-wasm-dry-run --base-href "/")
echo ""

# 4) Validate build output
echo "==> Validating build output..."
if [[ ! -d "${BUILD_OUT}" ]]; then
  echo "ERROR: build/web not found at ${BUILD_OUT}"
  exit 1
fi

# Expect index.html and at least one main JS
if [[ ! -f "${BUILD_OUT}/index.html" ]]; then
  echo "ERROR: index.html not found in build/web"
  exit 1
fi
if [[ ! -f "${BUILD_OUT}/main.dart.js" ]] && [[ ! -f "${BUILD_OUT}/main.dart.wasm.js" ]]; then
  echo "WARN: main.dart.js / main.dart.wasm.js not found; listing:"
  ls -la "${BUILD_OUT}"
fi

# Asset manifest (required for asset loading; avoids 404 in browser)
if [[ ! -f "${BUILD_OUT}/assets/AssetManifest.bin" ]] && [[ ! -f "${BUILD_OUT}/assets/AssetManifest.bin.json" ]]; then
  echo "WARN: assets/AssetManifest.bin or AssetManifest.bin.json not found; asset loading may 404"
  ls -la "${BUILD_OUT}/assets" 2>/dev/null || true
fi

echo "SUCCESS: build/web ready at ${BUILD_OUT}"
ls -la "${BUILD_OUT}"
