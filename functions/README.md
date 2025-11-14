# OPERON Firebase Functions

This directory contains Firebase Cloud Functions for the OPERON organization management system.

## 🚀 **Available Functions**

### **Dashboard Metadata**
- `onClientCreated` - Updates dashboard metadata when a client is created
- `onClientUpdated` - Tracks client status changes for active counts
- `onClientDeleted` - Decrements active client counters when removed

### **Organization Management**
- `organizationCreate` - Creates new organization with admin user
- `organizationUpdate` - Updates organization details
- `organizationActivate` - Activates organization after setup

### **User Management**
- `adminInvitationSendSMS` - Sends SMS invitation to admin
- `adminInvitationVerifyOTP` - Verifies admin OTP and creates Firebase Auth user
- `userCreateInOrganization` - Creates additional users in organization

### **Notification System**
- `adminInvitationSendEmail` - Sends email invitation (optional)
- `notificationSendActivation` - Sends activation notifications
- `notificationSendSMS` - Sends SMS notifications

### **Onboarding Process**
- `onboardingCompleteSetup` - Completes organization setup
- `onboardingValidateSetup` - Validates setup completion

### **Database Triggers**
- `onClientCreated` / `onClientUpdated` / `onClientDeleted` - Maintain dashboard metadata
- `onOrganizationCreated` - Tracks organization lifecycle events
- `onOrganizationUpdated` - Tracks organization changes
- `onOrganizationDeleted` - Handles organization clean-up
- `onUserCreated` - Logs user provisioning
- `onUserUpdated` - Tracks user changes
- `onSubscriptionUpdated` - Tracks subscription changes

### **Scheduled Functions**
- `scheduledCleanupExpiredInvitations` - Cleans expired invitations (24h)
- `scheduledSendSetupReminders` - Sends setup reminders (24h)

## 📊 **Dashboard Metadata Usage**

Client analytics are stored under:

```
DASHBOARD_METADATA/
  CLIENTS (summary document)
    FINANCIAL_YEARS/{financialYearId}
```

- The summary document tracks the global `totalActiveClients`.
- Each financial year document tracks `totalOnboarded`, `totalActiveClientsSnapshot`, and a `monthlyOnboarding` map keyed by `YYYY-MM`.
- Cloud Functions keep these documents in sync whenever clients are created, deleted, or have their status toggled.

## 📱 **Phone Auth Onboarding Flow**

### **1. SuperAdmin Creates Organization**
```javascript
// Call organizationCreate function
const result = await organizationCreate({
  orgName: "Acme Corp",
  email: "contact@acme.com",
  gstNo: "29ABCDE1234F1Z5",
  industry: "Technology",
  location: "Mumbai",
  adminName: "John Doe",
  adminPhone: "+919876543210",
  adminEmail: "john@acme.com", // Optional
  subscription: {
    tier: "premium",
    subscriptionType: "monthly",
    userLimit: 50,
    amount: 999.0,
    currency: "INR",
    autoRenew: true
  }
});
```

### **2. Admin Receives SMS Invitation**
- SMS sent with OTP code
- 24-hour expiry period
- Email notification (if email provided)

### **3. Admin Verifies OTP**
```javascript
// Call adminInvitationVerifyOTP function
const result = await adminInvitationVerifyOTP({
  phoneNumber: "+919876543210",
  otp: "123456"
});
```

### **4. Admin Completes Setup**
```javascript
// Call onboardingCompleteSetup function
const result = await onboardingCompleteSetup({
  orgId: "org_123",
  setupData: {
    preferences: {...},
    teamMembers: [...],
    // other setup data
  }
});
```

## 🔧 **Development**

### **Local Development**
```bash
# Install dependencies
npm install

# Start Firebase emulators
npm run serve

# Deploy functions
npm run deploy
```

### **Testing**
```bash
# Run functions shell
npm run shell

# View logs
npm run logs
```

## 📋 **Database Schema**

### **Collections Used**
- `organizations` - Organization documents
- `users` - User documents
- `admin_invitations` - Temporary OTP storage
- `notification_logs` - Notification tracking

### **Subcollections**
- `organizations/{orgId}/subscriptions` - Subscription data
- `organizations/{orgId}/users` - Organization users

## 🔐 **Security**

### **Authentication Required**
- SuperAdmin token required for organization creation
- User authentication required for setup completion
- OTP verification for admin onboarding

### **Permissions**
- Role-based permissions system
- Organization-scoped access control
- SuperAdmin override capabilities

## 📞 **SMS Integration**

Currently, SMS functions log messages instead of sending actual SMS. To enable SMS:

1. **Add Twilio dependency**:
```bash
npm install twilio
```

2. **Configure Twilio**:
```javascript
const twilio = require('twilio');
const client = twilio(accountSid, authToken);
```

3. **Update SMS functions** to use Twilio client

## 📧 **Email Integration**

Currently, email functions log messages instead of sending actual emails. To enable email:

1. **Add email service dependency** (SendGrid, Mailgun, etc.)
2. **Configure email service**
3. **Update email functions** to use email service

## 🚀 **Deployment**

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:organizationCreate
```

## 📊 **Monitoring**

- Function logs available in Firebase Console
- Error tracking and performance monitoring
- Scheduled function execution logs

## 🔄 **Migration Notes**

### **Removed Functions**
- Old system metadata functions
- Legacy organization triggers
- Outdated user management functions

### **New Features**
- Phone auth onboarding
- SMS/Email notification system
- Setup validation and reminders
- Role-based permissions
- Automated cleanup tasks
Procee