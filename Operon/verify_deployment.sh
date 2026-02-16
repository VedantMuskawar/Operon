#!/bin/bash
# Operon v1.0.1 Deployment Verification Script
# Checks if all components are ready for deployment

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Operon Client v1.0.1 - Deployment Verification            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILURES=0
PASSES=0

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
  echo -e "${GREEN}✓${NC} $1"
  ((PASSES++))
}

check_fail() {
  echo -e "${RED}✗${NC} $1"
  ((FAILURES++))
}

check_warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

echo "📋 Checking version configuration..."
if grep -q "version: 1.0.1+2" "${REPO_ROOT}/apps/Operon_Client_android/pubspec.yaml"; then
  check_pass "pubspec.yaml version updated to 1.0.1+2"
else
  check_fail "pubspec.yaml version not updated"
fi

echo ""
echo "📦 Checking APK build..."
APK_PATH="${REPO_ROOT}/apps/Operon_Client_android/build/app/outputs/flutter-apk/app-release.apk"
if [[ -f "$APK_PATH" ]]; then
  APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
  check_pass "Release APK exists ($APK_SIZE)"
  
  APK_CHECKSUM=$(md5 "$APK_PATH" | awk '{print $NF}')
  if [[ "$APK_CHECKSUM" == "b75af6dcc164b8ad45164b2bfbed42ea" ]]; then
    check_pass "APK checksum verified: $APK_CHECKSUM"
  else
    check_warn "APK checksum mismatch (might be rebuilt): $APK_CHECKSUM"
  fi
else
  check_fail "Release APK not found at $APK_PATH"
fi

echo ""
echo "🔧 Checking distribution server..."
if [[ -d "${REPO_ROOT}/distribution-server" ]]; then
  check_pass "Distribution server directory exists"
  
  if [[ -f "${REPO_ROOT}/distribution-server/server.js" ]]; then
    check_pass "server.js found"
  else
    check_fail "server.js not found"
  fi
  
  if [[ -f "${REPO_ROOT}/distribution-server/package.json" ]]; then
    check_pass "package.json found"
  else
    check_fail "package.json not found"
  fi
  
  if [[ -d "${REPO_ROOT}/distribution-server/apks" ]]; then
    check_pass "APKs directory exists"
    
    if [[ -f "${REPO_ROOT}/distribution-server/apks/operon-client-v1.0.1.apk" ]]; then
      SERVER_APK_SIZE=$(du -h "${REPO_ROOT}/distribution-server/apks/operon-client-v1.0.1.apk" | cut -f1)
      check_pass "APK deployed to server ($SERVER_APK_SIZE)"
    else
      check_fail "APK not deployed to server"
    fi
  else
    check_fail "APKs directory not found"
  fi
else
  check_fail "Distribution server directory not found"
fi

echo ""
echo "🌐 Checking server status..."
HEALTH_RESPONSE=$(curl -s http://localhost:3000/api/health 2>&1)
if echo "$HEALTH_RESPONSE" | grep -q "\"status\":\"online\""; then
  check_pass "Distribution server is online"
  
  # Check version endpoint
  VERSION_RESPONSE=$(curl -s "http://localhost:3000/api/version/operon-client?currentBuild=1" 2>&1)
  if echo "$VERSION_RESPONSE" | grep -q "\"version\":\"1.0.1\""; then
    check_pass "Version endpoint returns v1.0.1"
  else
    check_fail "Version endpoint not working correctly"
  fi
  
  # Check changelog endpoint
  CHANGELOG_RESPONSE=$(curl -s "http://localhost:3000/api/changelog/operon-client" 2>&1)
  if echo "$CHANGELOG_RESPONSE" | grep -q "1.0.1"; then
    check_pass "Changelog endpoint working"
  else
    check_fail "Changelog endpoint not working"
  fi
else
  check_fail "Distribution server is offline (http://localhost:3000)"
  check_warn "Start server with: npm start (in distribution-server/)"
fi

echo ""
echo "📄 Checking documentation..."
DOCS=(
  "ANDROID_CLIENT_V1.0.1_RELEASE_PREP.md"
  "ANDROID_RELEASE_QUICK_GUIDE.md"
  "V1.0.1_BUILD_DEPLOYMENT_RECORD.md"
  "DISTRIBUTION_SERVER_INTEGRATION.md"
  "V1.0.1_DEPLOYMENT_COMPLETE.md"
)

for doc in "${DOCS[@]}"; do
  if [[ -f "${REPO_ROOT}/${doc}" ]]; then
    check_pass "Found: $doc"
  else
    check_fail "Missing: $doc"
  fi
done

echo ""
echo "════════════════════════════════════════════════════════════"
echo ""
echo -e "Results: ${GREEN}$PASSES passed${NC}, ${RED}$FAILURES failed${NC}"
echo ""

if [[ $FAILURES -eq 0 ]]; then
  echo -e "${GREEN}✓ All checks passed! Ready for deployment.${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Test installation: adb install <APK_PATH>"
  echo "  2. Verify app works and shows v1.0.1"
  echo "  3. Integrate update check into Flutter app"
  echo "  4. Deploy to users"
  echo ""
  exit 0
else
  echo -e "${RED}✗ Some checks failed. Review above and fix issues.${NC}"
  echo ""
  echo "Common fixes:"
  echo "  • Server not running? → npm start (in distribution-server/)"
  echo "  • APK not deployed? → cp app-release.apk distribution-server/apks/"
  echo "  • Version not updated? → Update pubspec.yaml and rebuild"
  echo ""
  exit 1
fi
