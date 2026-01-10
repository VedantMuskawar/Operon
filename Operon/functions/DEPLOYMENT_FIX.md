# Fixing Eventarc Service Identity Error

## Problem
Error: `Error generating the service identity for eventarc.googleapis.com`

This occurs because Firebase Functions v2 requires Eventarc API and proper IAM permissions.

## Solution 1: Enable APIs and Set Permissions (Recommended)

Run these commands in Google Cloud Shell or locally (requires gcloud CLI):

```bash
# Get your project ID
PROJECT_ID=$(gcloud config get-value project)
echo "Project ID: $PROJECT_ID"

# Enable required APIs
gcloud services enable eventarc.googleapis.com \
  run.googleapis.com \
  pubsub.googleapis.com \
  cloudfunctions.googleapis.com \
  storage.googleapis.com \
  --project=$PROJECT_ID

# Get your project number
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
echo "Project Number: $PROJECT_NUMBER"

# Grant Eventarc service agent role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-eventarc.iam.gserviceaccount.com" \
  --role="roles/eventarc.serviceAgent"

# Also grant the default compute service account permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/eventarc.eventReceiver"
```

## Solution 2: Use Firebase Console

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to **APIs & Services** → **Library**
3. Enable these APIs:
   - Eventarc API
   - Cloud Run Admin API
   - Pub/Sub API
   - Cloud Functions API
4. Go to **IAM & Admin** → **IAM**
5. Find the service account: `service-{PROJECT_NUMBER}@gcp-sa-eventarc.iam.gserviceaccount.com`
6. Add role: **Eventarc Service Agent**

## Solution 3: Use us-central1 Region (Temporary Workaround)

If Eventarc has issues in `asia-south1`, you can temporarily use `us-central1`:

Edit `functions/src/orders/trip-scheduling.ts`:
```typescript
const functionOptions = {
  region: 'us-central1' as const, // Changed from asia-south1
  timeoutSeconds: 60,
  maxInstances: 10,
};
```

Note: This will affect latency if your Firestore is in asia-south1.

## Solution 4: Deploy Functions Individually

Try deploying only the v1 functions first:
```bash
firebase deploy --only functions:onPendingOrderCreated,functions:onOrderCreatedAutoSchedule
```

Then deploy v2 functions:
```bash
firebase deploy --only functions:onScheduledTripCreated,functions:onScheduledTripDeleted
```

## After Fixing

Once the API is enabled and permissions are set, try deploying again:
```bash
cd functions
npm run build
firebase deploy --only functions
```

## Verify Deployment

Check that functions are deployed:
```bash
firebase functions:list
```

Check logs:
```bash
firebase functions:log
```

