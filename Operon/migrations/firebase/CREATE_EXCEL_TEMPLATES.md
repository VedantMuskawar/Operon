# Creating Excel Import Templates

## Overview

The CSV templates in `data/` folder can be opened directly in Excel. However, if you need proper Excel files (.xlsx), follow these instructions.

## Option 1: Open CSV in Excel (Recommended)

1. Open Excel
2. File → Open → Select the CSV file (e.g., `clients-import-template.csv`)
3. Excel will import the CSV with proper formatting
4. Save as `.xlsx` if needed

## Option 2: Use Python Script

Run this script to create Excel files from CSV templates:

```python
import pandas as pd
import os

templates = [
    'clients-import-template.csv',
    'sch-orders-import-template.csv',
    'transactions-import-template.csv',
    'delivery-memos-import-template.csv'
]

for template in templates:
    if os.path.exists(template):
        df = pd.read_csv(template)
        excel_file = template.replace('.csv', '.xlsx')
        df.to_excel(excel_file, index=False, engine='openpyxl')
        print(f'Created: {excel_file}')
```

**Requirements**: `pip install pandas openpyxl`

## Option 3: Use Node.js Script

```javascript
const XLSX = require('xlsx');
const fs = require('fs');
const path = require('path');

const templates = [
    'clients-import-template.csv',
    'sch-orders-import-template.csv',
    'transactions-import-template.csv',
    'delivery-memos-import-template.csv'
];

templates.forEach(template => {
    const csvPath = path.join(__dirname, 'data', template);
    if (fs.existsSync(csvPath)) {
        const csv = fs.readFileSync(csvPath, 'utf8');
        const workbook = XLSX.utils.book_new();
        const worksheet = XLSX.utils.aoa_to_sheet(
            csv.split('\n').map(row => row.split(','))
        );
        XLSX.utils.book_append_sheet(workbook, worksheet, 'Sheet1');
        
        const excelFile = csvPath.replace('.csv', '.xlsx');
        XLSX.writeFile(workbook, excelFile);
        console.log(`Created: ${excelFile}`);
    }
});
```

**Requirements**: `npm install xlsx`

## Template Files Location

All templates are in: `migrations/firebase/data/`

- `clients-import-template.csv` → `clients-import-template.xlsx`
- `sch-orders-import-template.csv` → `sch-orders-import-template.xlsx`
- `transactions-import-template.csv` → `transactions-import-template.xlsx`
- `delivery-memos-import-template.csv` → `delivery-memos-import-template.xlsx`

## Notes

- CSV files work perfectly fine in Excel - no conversion needed
- Excel will automatically format dates and numbers when opening CSV
- For best results, use UTF-8 encoding (already set in templates)
