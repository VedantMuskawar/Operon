# Deploy Firebase Functions

To deploy the Firebase Functions (including the new employee wages handlers), run:

```bash
cd functions
npm run build && firebase deploy --only functions
```

Or use the npm script directly:

```bash
cd functions
npm run deploy
```

This will:
1. Build the TypeScript code to JavaScript
2. Deploy all functions to Firebase

## Note

Make sure you have:
- Firebase CLI installed (`npm install -g firebase-tools`)
- Logged in to Firebase (`firebase login`)
- Selected the correct project (`firebase use <project-id>`)

