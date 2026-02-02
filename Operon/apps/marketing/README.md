# LAKSHMEE Marketing Site

Fly Ash Bricks Manufacturing & Delivery landing page.

## Run Commands

**From repo root** (recommended):

```bash
npm run dev:marketing    # Start dev server on port 3001
npm run build:marketing  # Build for production
npm run deploy:marketing # Build and deploy to Firebase Hosting
```

**From this directory**:

```bash
npm run dev
npm run build
```

## Deploy to Firebase Hosting

1. **Prerequisites:** Firebase CLI (`npm install -g firebase-tools`) and login (`firebase login`)

2. **Deploy** from repo root:
   ```bash
   npm run deploy:marketing
   ```
   This builds the static export and deploys to Firebase Hosting.

3. **Custom domain:**
   - Go to [Firebase Console](https://console.firebase.google.com) → Your project → Hosting
   - Click "Add custom domain"
   - Enter your domain (e.g. `lakshmee.com`)
   - Add the DNS records shown (A or CNAME) at your domain registrar
   - SSL is provisioned automatically via Let's Encrypt
