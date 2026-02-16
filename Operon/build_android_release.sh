#!/usr/bin/env bash
# Operon Client Android v1.0.1 Release Build Script
# Run from repo root: ./build_android_release.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="${REPO_ROOT}/apps/Operon_Client_android"
BUILD_DIR="${APP_PATH}/build/app/outputs"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Operon Client Android v1.0.1 Release Build                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Repo root:  ${REPO_ROOT}"
echo "App path:   ${APP_PATH}"
echo ""

# 1) Verify key.properties exists
echo "==> Checking signing configuration..."
if [[ ! -f "${APP_PATH}/android/key.properties" ]]; then
  echo "ERROR: key.properties not found at ${APP_PATH}/android/key.properties"
  echo "Please set up release signing configuration."
  exit 1
fi
echo "✓ Signing configuration found"
echo ""

# 2) Clean
echo "==> Cleaning previous builds..."
(cd "${APP_PATH}" && flutter clean)
echo "✓ Clean complete"
echo ""

# 3) Get dependencies
echo "==> Fetching dependencies..."
(cd "${APP_PATH}" && flutter pub get)
echo "✓ Dependencies fetched"
echo ""

# 4) Run analysis
echo "==> Running code analysis..."
(cd "${APP_PATH}" && flutter analyze)
echo "✓ Analysis complete"
echo ""

# 5) Build APK Release
echo "==> Building release APK..."
(cd "${APP_PATH}" && flutter build apk --release --no-shrink)
echo "✓ Release APK built"
echo ""

# 6) Build App Bundle (for Play Store)
echo "==> Building release App Bundle..."
(cd "${APP_PATH}" && flutter build appbundle --release --no-shrink)
echo "✓ Release App Bundle built"
echo ""

# 7) Verify outputs
echo "==> Verifying build outputs..."
APK_PATH="${BUILD_DIR}/apk/release/app-release.apk"
BUNDLE_PATH="${BUILD_DIR}/bundle/release/app-release.aab"

if [[ ! -f "${APK_PATH}" ]]; then
  echo "ERROR: APK not found at ${APK_PATH}"
  exit 1
fi
echo "✓ APK found: ${APK_PATH}"
APK_SIZE=$(du -h "${APK_PATH}" | cut -f1)
echo "  Size: ${APK_SIZE}"
echo ""

if [[ ! -f "${BUNDLE_PATH}" ]]; then
  echo "ERROR: App Bundle not found at ${BUNDLE_PATH}"
  exit 1
fi
echo "✓ App Bundle found: ${BUNDLE_PATH}"
BUNDLE_SIZE=$(du -h "${BUNDLE_PATH}" | cut -f1)
echo "  Size: ${BUNDLE_SIZE}"
echo ""

# 8) Extract and display version
echo "==> Verifying version in APK..."
cd "${REPO_ROOT}"
VERSION=$(grep "version:" "${APP_PATH}/pubspec.yaml" | cut -d' ' -f2)
echo "✓ Application version: ${VERSION}"
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Build Complete! Ready for Play Store Upload               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Upload app-release.aab to Google Play Console"
echo "  2. Configure release notes and store listing"
echo "  3. Set rollout percentage (recommend 10-25%)"
echo "  4. Monitor Crashlytics for errors"
echo ""
