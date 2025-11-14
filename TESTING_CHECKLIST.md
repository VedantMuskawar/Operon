# 🧪 OPERON Onboarding Testing Checklist

## ✅ **Pre-Testing Setup**
- [ ] Firebase Functions deployed successfully
- [ ] SuperAdmin user exists (`+919876543210`)
- [ ] Test phone numbers available
- [ ] Firebase Console access ready
- [ ] OPERON app running on device/emulator

## 🎯 **Quick Test Flow (15 minutes)**

### **1. SuperAdmin Login** ⏱️ 2 min
- [ ] Open OPERON app
- [ ] Enter phone: `+919876543210`
- [ ] Send OTP → Verify: `123456`
- [ ] Navigate to Organization Select
- [ ] Select SuperAdmin → Dashboard loads

### **2. Create Test Organization** ⏱️ 5 min
- [ ] Click "Add Organization"
- [ ] Fill form:
  ```
  Name: Test Company Pvt Ltd
  GST: 27ABCDE1234F1Z5
  Email: admin@testcompany.com
  Industry: Technology
  Location: Mumbai
  Admin Name: John Doe
  Admin Phone: +919876543211
  Admin Email: john@testcompany.com
  Tier: Premium, Limit: 50, Duration: 30 days
  Amount: 999.00, Currency: INR, Auto Renew: Yes
  ```
- [ ] Click "Create Organization"
- [ ] Verify success message

### **3. Check Database** ⏱️ 3 min
- [ ] Firebase Console → Firestore
- [ ] Check `organizations` collection → New org created
- [ ] Check `ACTIVITY` collection → `ORGANIZATION_CREATED` log

### **4. Test Admin Invitation** ⏱️ 3 min
- [ ] Check SMS on `+919876543211` (if configured)
- [ ] Or check Firebase Console → Functions → Logs
- [ ] Look for `adminInvitationSendSMS` execution logs

### **5. Admin Verification** ⏱️ 2 min
- [ ] Use admin phone: `+919876543211`
- [ ] Send OTP → Verify: `123456`
- [ ] Check `users` collection → New user created

## 🚨 **Error Scenarios to Test**

### **Invalid Data**
- [ ] Invalid GST number → Error message
- [ ] Duplicate organization name → Error message
- [ ] Invalid phone format → Error message

### **Network Issues**
- [ ] No internet → Appropriate error handling
- [ ] Slow connection → Loading states work

### **Function Failures**
- [ ] Check Firebase Console → Functions → Logs for errors
- [ ] Verify error messages in app

## 📊 **Expected Results**

### **Database State After Test**
```json
organizations/org_001: {
  "orgName": "Test Company Pvt Ltd",
  "status": "pending",
  "industry": "Technology",
  "location": "Mumbai"
}

users/user_001: {
  "name": "John Doe",
  "phoneNo": "+919876543211",
  "status": "active"
}
```

### **Activity Logs**
- [ ] `ORGANIZATION_CREATED` entry
- [ ] `USER_CREATED` entry
- [ ] `ADMIN_INVITATION_SENT` entry

## 🔧 **Troubleshooting Commands**

```bash
# Check function status
firebase functions:list

# View recent logs
firebase functions:log --limit 50

# Check Firestore data
# Use Firebase Console → Firestore → Data
```

## ⚡ **Quick Fixes**

### **If Functions Not Deployed**
```bash
cd functions
firebase deploy --only functions
```

### **If Database Empty**
- Check Firestore rules
- Verify project selection (`operanapp`)

### **If SMS Not Working**
- Check Firebase Auth test phone numbers
- Verify SMS service configuration

### **If OTP Fails**
- Use test OTP: `123456`
- Check Firebase Auth configuration

---

## 🎉 **Success Criteria**
- [ ] Organization created successfully
- [ ] Admin invitation sent (SMS/logs)
- [ ] Admin can verify OTP
- [ ] Database counters updated
- [ ] Activity logs created
- [ ] No critical errors in logs

**Total Test Time: ~15 minutes** ⏱️

---

**Need Help?** Check the full `TESTING_GUIDE.md` for detailed instructions.
