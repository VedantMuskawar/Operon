# OPERON Organization & User Onboarding Testing Guide

This guide provides step-by-step instructions for testing the complete organization and user onboarding flow in OPERON.

## 🎯 **Testing Overview**

The onboarding process follows this flow:
1. **SuperAdmin Login** → **Organization Creation** → **Admin Invitation** → **Admin Setup** → **Organization Activation**

## 📋 **Prerequisites**

### **Firebase Setup**
- ✅ Firebase Functions deployed (`operanapp` project)
- ✅ Firestore database configured
- ✅ Firebase Authentication enabled
- ✅ Firebase Storage configured
- ✅ SuperAdmin user created

### **Test Data Requirements**
- Valid phone numbers for testing SMS
- Valid email addresses for testing notifications
- Test organization data (GST, industry, location)

## 🧪 **Testing Scenarios**

### **Scenario 1: Complete Organization Onboarding Flow**

#### **Step 1: SuperAdmin Login**
1. **Open OPERON app**
2. **Enter SuperAdmin phone number**: `+919876543210`
3. **Click "Send OTP"**
4. **Verify OTP**: `123456` (test OTP)
5. **Expected Result**: Navigate to Organization Select page
6. **Select SuperAdmin organization**
7. **Expected Result**: Navigate to SuperAdmin Dashboard

#### **Step 2: Create New Organization**
1. **In SuperAdmin Dashboard, click "Add Organization"**
2. **Fill Organization Details**:
   ```
   Organization Name: Test Company Pvt Ltd
   GST Number: 27ABCDE1234F1Z5
   Organization Email: admin@testcompany.com
   Industry: Technology
   Location: Mumbai, Maharashtra
   ```
3. **Fill Admin Details**:
   ```
   Admin Name: John Doe
   Admin Phone: +919876543211
   Admin Email: john@testcompany.com
   ```
4. **Fill Subscription Details**:
   ```
   Subscription Tier: Premium
   User Limit: 50
   Duration: 30 days
   Amount: 999.00
   Currency: INR
   Auto Renew: Yes
   ```
5. **Click "Create Organization"**
6. **Expected Result**: 
   - Organization created in Firestore
   - Admin invitation SMS sent
   - Dashboard metadata summary updated
   - Activity log created

#### **Step 3: Admin Invitation Process**
1. **Check SMS received on admin phone** (`+919876543211`)
2. **SMS should contain**:
   - Organization name
   - Invitation link/code
   - Setup instructions
3. **Admin clicks invitation link or enters code**
4. **Expected Result**: Navigate to admin setup page

#### **Step 4: Admin Setup & Verification**
1. **Admin enters phone number**: `+919876543211`
2. **Click "Send OTP"**
3. **Verify OTP**: `123456` (test OTP)
4. **Expected Result**: 
   - Firebase Auth user created
   - User document created in Firestore
   - Organization access granted
   - Welcome notification sent

#### **Step 5: Organization Activation**
1. **Admin completes initial setup**:
   - Upload organization logo
   - Set up basic preferences
   - Configure initial settings
2. **Call `onboardingCompleteSetup` function**
3. **Expected Result**:
   - Organization status changed to "active"
   - Subscription activated
   - Dashboard metadata updated
   - Activation notification sent

### **Scenario 2: Error Handling Testing**

#### **Invalid Organization Creation**
1. **Try creating organization with**:
   - Invalid GST number
   - Duplicate organization name
   - Invalid phone number format
2. **Expected Result**: Appropriate error messages displayed

#### **Failed SMS Delivery**
1. **Use invalid phone number**: `+911234567890`
2. **Expected Result**: Error handling for SMS failure

#### **OTP Verification Failure**
1. **Enter wrong OTP**: `000000`
2. **Expected Result**: Error message and retry option

### **Scenario 3: Dashboard Metadata Testing**

#### **Check Dashboard Summary**
1. **Open Firestore → `DASHBOARD_METADATA/CLIENTS`**
2. **Expected Result**:
   ```json
   {
     "totalActiveClients": 18,
     "createdAt": "2024-01-15T10:30:00Z",
     "updatedAt": "2024-01-16T08:45:00Z",
     "lastEventAt": "2024-01-16T08:45:00Z"
   }
   ```

#### **Verify Activity Logs**
1. **Check Firestore `ACTIVITY` collection**
2. **Expected Logs**:
   - `ORGANIZATION_CREATED`
   - `USER_CREATED`
   - `SUBSCRIPTION_UPDATED`
   - `ADMIN_INVITATION_SENT`

### **Scenario 4: Database Triggers Testing**

#### **Automatic Metadata Updates**
1. **Create or delete clients via dashboard or Firestore**
2. **Check `DASHBOARD_METADATA/CLIENTS` summary document**
3. **Expected Result**: `totalActiveClients` reflects active client count

#### **Financial Year Aggregation**
1. **Add clients with `createdAt` values across multiple months**
2. **Check `DASHBOARD_METADATA/CLIENTS/FINANCIAL_YEARS/{financialYearId}`**
3. **Expected Result**: `totalOnboarded` and `monthlyOnboarding` update accordingly

#### **Status Toggle Tracking**
1. **Toggle client status between `active` and `inactive`**
2. **Confirm summary document updates without changing historical onboarding totals**

## 🔧 **Testing Tools & Commands**

### **Firebase Console Testing**
```bash
# Check deployed functions
firebase functions:list

# View function logs
firebase functions:log

# Test function locally
firebase functions:shell
```

### **Firestore Testing**
```javascript
// Check organization document
db.collection('organizations').doc('org_001').get()

// Check user document
db.collection('users').doc('user_001').get()

// Check dashboard metadata summary
db.collection('DASHBOARD_METADATA').doc('CLIENTS').get()

// Check financial year details
db.collection('DASHBOARD_METADATA')
  .doc('CLIENTS')
  .collection('FINANCIAL_YEARS')
  .doc('2024-2025')
  .get()

// Check activity logs
db.collection('ACTIVITY').orderBy('timestamp', 'desc').limit(10).get()
```

### **Function Testing**
```javascript
// Test organization creation
const result = await organizationCreate({
  orgName: 'Test Company',
  email: 'admin@test.com',
  gstNo: '27ABCDE1234F1Z5',
  industry: 'Technology',
  location: 'Mumbai',
  adminName: 'John Doe',
  adminPhone: '+919876543211',
  adminEmail: 'john@test.com',
  tier: 'Premium',
  userLimit: 50,
  duration: '30 days',
  amount: 999.0,
  currency: 'INR',
  autoRenew: true
});
```

## 📊 **Expected Database Structure**

### **Organizations Collection**
```json
{
  "orgId": "org_001",
  "orgName": "Test Company Pvt Ltd",
  "email": "admin@testcompany.com",
  "gstNo": "27ABCDE1234F1Z5",
  "industry": "Technology",
  "location": "Mumbai, Maharashtra",
  "status": "active",
  "createdDate": "2024-01-15T10:30:00Z",
  "createdBy": "superadmin_uid"
}
```

### **Users Collection**
```json
{
  "userId": "user_001",
  "name": "John Doe",
  "phoneNo": "+919876543211",
  "email": "john@testcompany.com",
  "status": "active",
  "organizations": [
    {
      "orgId": "org_001",
      "role": 1,
      "permissions": ["all"],
      "status": "active",
      "isPrimary": true,
      "joinedDate": "2024-01-15T10:30:00Z"
    }
  ],
  "metadata": {
    "primaryOrgId": "org_001",
    "totalOrganizations": 1,
    "notificationPreferences": {
      "email": true,
      "sms": true,
      "push": true
    }
  }
}
```

### **Subscriptions Collection**
```json
{
  "subscriptionId": "sub_001",
  "orgId": "org_001",
  "tier": "Premium",
  "userLimit": 50,
  "duration": "30 days",
  "amount": 999.0,
  "currency": "INR",
  "autoRenew": true,
  "isActive": true,
  "status": "active",
  "startDate": "2024-01-15T10:30:00Z",
  "endDate": "2024-02-14T10:30:00Z"
}
```

## 🚨 **Common Issues & Solutions**

### **Issue 1: SMS Not Received**
- **Check**: Phone number format (+91XXXXXXXXXX)
- **Solution**: Verify SMS service configuration
- **Test**: Use test phone numbers

### **Issue 2: OTP Verification Fails**
- **Check**: Firebase Auth configuration
- **Solution**: Verify test OTP settings
- **Test**: Use `123456` as test OTP

### **Issue 3: Organization Creation Fails**
- **Check**: Required fields validation
- **Solution**: Ensure all mandatory fields filled
- **Test**: Use valid GST and email formats

### **Issue 4: Database Triggers Not Firing**
- **Check**: Function deployment status
- **Solution**: Verify trigger configurations
- **Test**: Check function logs

## 📈 **Performance Testing**

### **Load Testing**
1. **Create multiple organizations simultaneously**
2. **Monitor function execution times**
3. **Check database performance**
4. **Verify SMS delivery rates**

### **Scalability Testing**
1. **Test with 100+ organizations**
2. **Monitor system metadata updates**
3. **Check activity log performance**
4. **Verify scheduled function execution**

## ✅ **Success Criteria**

### **Functional Requirements**
- ✅ Organization creation works end-to-end
- ✅ Admin invitation SMS delivered
- ✅ OTP verification successful
- ✅ User creation in Firebase Auth
- ✅ Database triggers fire correctly
- ✅ System metadata updates automatically
- ✅ Activity logs created properly

### **Non-Functional Requirements**
- ✅ Functions respond within 5 seconds
- ✅ SMS delivery within 30 seconds
- ✅ Database operations atomic
- ✅ Error handling comprehensive
- ✅ Logging detailed and useful

## 🔄 **Regression Testing**

### **After Each Deployment**
1. **Test complete onboarding flow**
2. **Verify all functions work**
3. **Check database integrity**
4. **Validate system metadata**
5. **Test error scenarios**

### **Weekly Testing**
1. **Full system integration test**
2. **Performance benchmarking**
3. **Security validation**
4. **Backup verification**

---

## 📞 **Support & Troubleshooting**

### **Firebase Console**
- **Project**: `operanapp`
- **Console**: https://console.firebase.google.com/project/operanapp/overview

### **Function Logs**
- **Location**: Firebase Console → Functions → Logs
- **Filter**: By function name and timestamp

### **Database Monitoring**
- **Location**: Firebase Console → Firestore → Usage
- **Monitor**: Read/write operations and costs

### **SMS Testing**
- **Test Numbers**: Use Firebase Auth test phone numbers
- **Production**: Configure Twilio or similar service

---

**Happy Testing! 🚀**
