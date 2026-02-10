import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const XLSX = require('xlsx');

interface TemplateConfig {
  outputPath: string;
}

function resolveConfig(): TemplateConfig {
  const resolvePath = (value?: string) => {
    if (!value) return undefined;
    return path.isAbsolute(value) ? value : path.join(process.cwd(), value);
  };

  const outputPath =
    resolvePath(process.env.OUTPUT_PATH) ??
    path.join(process.cwd(), 'templates', 'delivery-zones-template.xlsx');

  return { outputPath };
}

function generateTemplate() {
  const config = resolveConfig();

  const rows = [
    {
      zone_id: '',
      city_name: 'Chennai',
      region: 'Central',
      is_active: 'true',
      roundtrip_km: '12.5',
      product_id: 'PRODUCT_001',
      product_name: 'Cement 50kg',
      unit_price: '450.00',
      deliverable: 'true',
    },
  ];

  const worksheet = XLSX.utils.json_to_sheet(rows, {
    header: [
      'zone_id',
      'city_name',
      'region',
      'is_active',
      'roundtrip_km',
      'product_id',
      'product_name',
      'unit_price',
      'deliverable',
    ],
  });

  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, 'DELIVERY_ZONES');

  const outputDir = path.dirname(config.outputPath);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  XLSX.writeFile(workbook, config.outputPath);
  console.log(`Template written to: ${config.outputPath}`);
}

generateTemplate();
