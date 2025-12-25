# Firebase Phone Auth Setup

1. Install the FlutterFire CLI: `dart pub global activate flutterfire_cli`.
2. Run `flutterfire configure --project=dash-superadmin --out=apps/dash_superadmin/lib/config`.
3. Ensure Android SHA-256 fingerprints and Web origins are added to Firebase console.
4. Enable **Phone Authentication** in Firebase Authentication.
5. Create a `super_admins` collection in Firestore where each document ID is a phone number (E.164). Include `{ "isActive": true }`.
6. Add test phone numbers + codes in the Firebase Auth emulator for local development.
7. Update `apps/dash_superadmin/lib/config/firebase_options.dart` with the generated content.
8. For production, store environment configs using `.env` or CI secrets and avoid committing keys to VCS.
