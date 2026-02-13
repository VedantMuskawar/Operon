const admin = require('firebase-admin');
const ExcelJS = require('exceljs');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccount = require('../../creds/service-account.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

async function exportEmployeesToExcel() {
  const employeesRef = db.collection('EMPLOYEES');
  const snapshot = await employeesRef.get();

  if (snapshot.empty) {
    console.log('No employees found.');
    return;
  }

  const workbook = new ExcelJS.Workbook();
  const worksheet = workbook.addWorksheet('Employees');

  // Get all unique field names for header
  const allFields = new Set();
  snapshot.forEach(doc => {
    Object.keys(doc.data()).forEach(key => allFields.add(key));
  });
  const headers = ['id', ...Array.from(allFields)];
  worksheet.addRow(headers);

  // Add employee data
  snapshot.forEach(doc => {
    const data = doc.data();
    const row = [doc.id, ...headers.slice(1).map(field => data[field] || '')];
    worksheet.addRow(row);
  });

  // Save to file
  const filePath = path.join(__dirname, 'employees_export.xlsx');
  await workbook.xlsx.writeFile(filePath);
  console.log(`Exported ${snapshot.size} employees to ${filePath}`);
}

exportEmployeesToExcel().catch(console.error);
