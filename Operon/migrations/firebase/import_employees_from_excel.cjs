const admin = require('firebase-admin');
const ExcelJS = require('exceljs');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccount = require('../../creds/service-account.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

function parseMaybeJSON(val) {
  if (typeof val !== 'string') return val;
  try {
    return JSON.parse(val);
  } catch {
    return val;
  }
}

function parseMaybeTimestamp(val) {
  if (typeof val === 'string') {
    try {
      const obj = JSON.parse(val);
      if (obj && typeof obj._seconds === 'number' && typeof obj._nanoseconds === 'number') {
        return new admin.firestore.Timestamp(obj._seconds, obj._nanoseconds);
      }
    } catch {}
  }
  return val;
}

async function importEmployeesFromExcel() {
  const filePath = path.join(__dirname, 'employees_export.xlsx');
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.readFile(filePath);
  const worksheet = workbook.getWorksheet('Employees');
  if (!worksheet) {
    console.error('Worksheet "Employees" not found.');
    return;
  }

  // Get headers from the first row
  const headers = worksheet.getRow(1).values.slice(1); // skip first empty value
  const importedIds = new Set();
  let imported = 0;

  for (let rowNumber = 2; rowNumber <= worksheet.rowCount; rowNumber++) {
    const row = worksheet.getRow(rowNumber);
    const values = row.values.slice(1); // skip first empty value
    const docId = values[0];
    if (!docId) continue;
    importedIds.add(docId);
    const data = {};
    for (let i = 1; i < headers.length; i++) {
      let val = values[i];
      const key = headers[i];
      if (key === 'createdAt' || key === 'updatedAt') {
        val = parseMaybeTimestamp(val);
      } else if (key === 'jobRoleIds' || key === 'jobRoles' || key === 'wage') {
        val = parseMaybeJSON(val);
      }
      data[key] = val;
    }
    await db.collection('EMPLOYEES').doc(docId).set(data, { merge: true });
    imported++;
  }

  // Delete docs not in Excel
  const allDocs = await db.collection('EMPLOYEES').listDocuments();
  const toDelete = allDocs.filter(docRef => !importedIds.has(docRef.id));
  for (const docRef of toDelete) {
    await docRef.delete();
    console.log(`Deleted EMPLOYEES/${docRef.id}`);
  }

  console.log(`Imported ${imported} employees and deleted ${toDelete.length} docs not in Excel.`);
}

importEmployeesFromExcel().catch(console.error);
