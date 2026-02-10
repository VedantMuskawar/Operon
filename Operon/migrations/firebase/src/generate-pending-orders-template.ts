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
    path.join(process.cwd(), 'templates', 'pending-orders-template.xlsx');

  return { outputPath };
}

function generateTemplate() {
  const config = resolveConfig();

  const rows = [
    {
      order_key: 'ORDER-001',
      order_id: '',
      order_number: '',
      organization_id: '',
      client_id: 'CLIENT_001',
      client_name: 'Acme Builders',
      client_phone: '+919999999999',
      priority: 'normal',
      status: 'pending',
      created_by: 'migration',
      created_at: '2026-02-09T10:00:00Z',
      updated_at: '2026-02-09T10:00:00Z',
      advance_amount: '0',
      advance_payment_account_id: '',
      delivery_zone_id: '',
      delivery_zone_city: 'Chennai',
      delivery_zone_region: 'Central',
      product_id: 'PRODUCT_001',
      product_name: 'Cement 50kg',
      estimated_trips: '5',
      fixed_quantity_per_trip: '20',
      unit_price: '450',
      gst_percent: '18',
      gst_amount: '',
    },
    {
      order_key: 'ORDER-001',
      order_id: '',
      order_number: '',
      organization_id: '',
      client_id: 'CLIENT_001',
      client_name: 'Acme Builders',
      client_phone: '+919999999999',
      priority: 'normal',
      status: 'pending',
      created_by: 'migration',
      created_at: '2026-02-09T10:00:00Z',
      updated_at: '2026-02-09T10:00:00Z',
      advance_amount: '0',
      advance_payment_account_id: '',
      delivery_zone_id: '',
      delivery_zone_city: 'Chennai',
      delivery_zone_region: 'Central',
      product_id: 'PRODUCT_002',
      product_name: 'Sand',
      estimated_trips: '3',
      fixed_quantity_per_trip: '10',
      unit_price: '120',
      gst_percent: '',
      gst_amount: '',
    },
  ];

  const header = [
    'order_key',
    'order_id',
    'order_number',
    'organization_id',
    'client_id',
    'client_name',
    'client_phone',
    'priority',
    'status',
    'created_by',
    'created_at',
    'updated_at',
    'advance_amount',
    'advance_payment_account_id',
    'delivery_zone_id',
    'delivery_zone_city',
    'delivery_zone_region',
    'product_id',
    'product_name',
    'estimated_trips',
    'fixed_quantity_per_trip',
    'unit_price',
    'gst_percent',
    'gst_amount',
  ];

  const worksheet = XLSX.utils.json_to_sheet(rows, { header });
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, 'PENDING_ORDERS');

  const outputDir = path.dirname(config.outputPath);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  XLSX.writeFile(workbook, config.outputPath);
  console.log(`Template written to: ${config.outputPath}`);
}

generateTemplate();
