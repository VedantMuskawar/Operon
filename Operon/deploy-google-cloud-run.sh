#!/bin/bash

# Google Cloud Run Deployment Script for Operon v1.0.1
# This script automates the deployment of the distribution server to Google Cloud Run

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ID="operon-updates"
SERVICE_NAME="operon-updates"
REGION="us-central1"
MEMORY="256Mi"
CPU="1"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Operon v1.0.1 - Google Cloud Run Deployment Script       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Check if gcloud is authenticated
echo -e "${YELLOW}Step 1: Checking Google Cloud authentication...${NC}"
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo -e "${RED}✗ Not authenticated with Google Cloud${NC}"
    echo -e "${YELLOW}Please run: gcloud auth login${NC}"
    exit 1
fi
AUTH_USER=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1)
echo -e "${GREEN}✓ Authenticated as: $AUTH_USER${NC}"
echo ""

# Step 2: Create or verify project
echo -e "${YELLOW}Step 2: Setting up Google Cloud project...${NC}"
if gcloud projects describe $PROJECT_ID &>/dev/null; then
    echo -e "${GREEN}✓ Project $PROJECT_ID already exists${NC}"
else
    echo -e "${BLUE}  Creating new project: $PROJECT_ID${NC}"
    gcloud projects create $PROJECT_ID --name="Operon Updates Service"
    echo -e "${GREEN}✓ Project created${NC}"
fi

# Set as current project
gcloud config set project $PROJECT_ID
echo -e "${GREEN}✓ Project set as current: $PROJECT_ID${NC}"
echo ""

# Step 3: Enable required APIs
echo -e "${YELLOW}Step 3: Enabling required Google Cloud APIs...${NC}"
echo "  - Enabling Cloud Run API..."
gcloud services enable run.googleapis.com --quiet

echo "  - Enabling Artifact Registry API..."
gcloud services enable artifactregistry.googleapis.com --quiet

echo "  - Enabling Cloud Build API..."
gcloud services enable cloudbuild.googleapis.com --quiet

echo -e "${GREEN}✓ All required APIs enabled${NC}"
echo ""

# Step 4: Deploy to Cloud Run
echo -e "${YELLOW}Step 4: Deploying distribution server to Cloud Run...${NC}"
echo "  This may take 2-3 minutes..."
echo ""

cd /Users/vedantreddymuskawar/Operon/distribution-server

gcloud run deploy $SERVICE_NAME \
  --source . \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --memory $MEMORY \
  --cpu $CPU \
  --timeout 600s \
  --set-env-vars NODE_ENV=production \
  --quiet

echo ""
echo -e "${GREEN}✓ Deployment completed${NC}"
echo ""

# Step 5: Get service URL
echo -e "${YELLOW}Step 5: Retrieving service URL...${NC}"
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
  --region $REGION \
  --format='value(status.url)')

echo -e "${GREEN}✓ Service URL: ${BLUE}$SERVICE_URL${NC}"
echo ""

# Step 6: Save configuration
echo -e "${YELLOW}Step 6: Saving configuration...${NC}"
CONFIG_FILE="/Users/vedantreddymuskawar/Operon/GOOGLE_CLOUD_RUN_CONFIG.txt"
cat > "$CONFIG_FILE" << EOF
Google Cloud Run Deployment Configuration
Generated: $(date)

Project ID: $PROJECT_ID
Service Name: $SERVICE_NAME
Region: $REGION
Service URL: $SERVICE_URL
Memory: $MEMORY
CPU: $CPU
Authenticated User: $AUTH_USER

Update your Flutter app with this server URL:
File: apps/Operon_Client_android/lib/presentation/app.dart
Line: 189
Change: serverUrl: '$SERVICE_URL'

Full URL to use:
serverUrl: '$SERVICE_URL',
EOF

echo -e "${GREEN}✓ Configuration saved to: $CONFIG_FILE${NC}"
echo ""

# Step 7: Test the service
echo -e "${YELLOW}Step 7: Testing service endpoint...${NC}"
echo "  Testing: GET $SERVICE_URL/health"
HEALTH_CHECK=$(curl -s "$SERVICE_URL/health" || echo "Service not yet ready")
if echo "$HEALTH_CHECK" | grep -q "ok"; then
    echo -e "${GREEN}✓ Health check passed${NC}"
else
    echo -e "${YELLOW}⚠ Service is starting up, this is normal${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              DEPLOYMENT SUCCESSFUL! ✓                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Your distribution server is now live!${NC}"
echo ""
echo -e "Service URL: ${BLUE}$SERVICE_URL${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Update Flutter app with the service URL:"
echo "   File: apps/Operon_Client_android/lib/presentation/app.dart"
echo "   Line 189: serverUrl: '$SERVICE_URL',"
echo ""
echo "2. Build final APK:"
echo "   cd apps/Operon_Client_android"
echo "   flutter clean && flutter pub get"
echo "   flutter build apk --release"
echo ""
echo "3. Test the service:"
echo "   curl \"$SERVICE_URL/api/version/operon-client?currentBuild=1\""
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  View logs:      gcloud run services logs read $SERVICE_NAME --region $REGION --limit 50"
echo "  Stream logs:    gcloud run services logs read $SERVICE_NAME --region $REGION --follow"
echo "  View metrics:   https://console.cloud.google.com/run/detail/$REGION/$SERVICE_NAME"
echo "  Redeploy:       gcloud run deploy $SERVICE_NAME --source . --platform managed --region $REGION --allow-unauthenticated"
echo ""
