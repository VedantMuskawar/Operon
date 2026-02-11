OPERON Project Context & Coding Standards
1. Tech Stack & Architecture

Primary Frameworks: Flutter (Mobile) and React/Next.js (Web).

Backend: Firebase (Firestore, Auth, Cloud Functions, Storage).

Design Pattern: Prefer modular, reusable components. For Flutter, use Bloc or Provider for state management.

Database: Firestore. Always prioritize efficient indexing and minimize document reads/writes.

2. Business Domain: Fly Ash Brick Manufacturing

Core Entity: OPERON is an operations management suite for a fly ash brick manufacturing unit (Lakshmee Intelligent Technologies).

Key Modules: * Orders: Managing client orders and payments.

Logistics: Driver app integration for delivery tracking.

Inventory: Tracking raw materials (fly ash, cement, sand) and finished brick pallets.

Employee Management: Daily attendance and production output logs.

3. UI/UX "Vibes"

Clean & Industrial: The UI should be professional, high-contrast (readable in sunlight for drivers), and utilitarian.

Mobile First: The Driver App must be optimized for one-handed use.

Call Overlays: For the Client App, implement non-intrusive Android overlays that surface customer order history during incoming calls.

4. Technical Constraints

Lactose Intolerance/Health Apps: If building any internal health/cafeteria features, strictly avoid dairy-based options in suggestions.

No Soda/Fast Food: Any logic related to employee perks or site meals should prioritize healthy, local Chandrapur cuisine.

Performance: Code must be lightweight to run on mid-range Android devices used by staff.

5. Coding Style

Clean Code: Use descriptive variable names (e.g., brickInventoryCount instead of count).

Error Handling: Always include try-catch blocks for Firebase calls and provide user-friendly error messages.

Comments: Use JSDoc or Dart Doc style for complex business logic.