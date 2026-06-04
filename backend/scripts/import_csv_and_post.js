// backend/scripts/import_csv_and_post.js
// Usage: node import_csv_and_post.js <csv_path> [concurrency=20]
// Env: TARGET=https://... (optional)

const fs = require('fs');
const path = require('path');

const csvPath = process.argv[2] || path.join(process.env.USERPROFILE || '.', 'Downloads', 'dummy_products_100.csv');
const concurrency = parseInt(process.argv[3] || '20', 10);
const TARGET = process.env.TARGET || 'https://pos-backend.posai.workers.dev/api/products';

if (!fs.existsSync(csvPath)) {
  console.error('CSV file not found:', csvPath);
  process.exit(1);
}

function parseCSVLine(line) {
  const res = [];
  let cur = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      // peek next char to handle double quotes inside quoted field
      if (inQuotes && line[i+1] === '"') {
        cur += '"';
        i++; // skip next
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (ch === ',' && !inQuotes) {
      res.push(cur);
      cur = '';
      continue;
    }
    cur += ch;
  }
  res.push(cur);
  return res;
}

function safeParseArray(s) {
  if (!s) return [];
  try {
    // CSV used doubled quotes; replace "" with " then parse
    const fixed = s.replace(/""/g, '"');
    return JSON.parse(fixed);
  } catch (e) {
    // fallback: split on semicolon or pipe or comma
    return s.split(/[,;|]/).map(x => x.trim()).filter(Boolean);
  }
}

function toBool(s) {
  if (s === undefined || s === null) return false;
  const v = String(s).trim().toLowerCase();
  return v === 'true' || v === '1' || v === 'yes';
}

async function postJSON(obj, attempt = 1) {
  try {
    const res = await fetch(TARGET, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(obj),
    });
    if (!res.ok) {
      const txt = await res.text().catch(()=>'<no-body>');
      throw new Error(`status=${res.status} body=${txt}`);
    }
    return true;
  } catch (e) {
    if (attempt <= 3) {
      await new Promise(r => setTimeout(r, 500 * attempt));
      return postJSON(obj, attempt + 1);
    }
    console.error('POST failed:', e.message, 'obj:', obj.product_key || obj.sku || obj.name || '<no-key>');
    return false;
  }
}

async function main(){
  const text = fs.readFileSync(csvPath, 'utf8');
  const lines = text.split(/\r?\n/).filter(l => l.trim() !== '');
  const header = parseCSVLine(lines.shift());
  const rows = lines.map(l => parseCSVLine(l));
  const items = rows.map(cols => {
    const rec = {};
    for (let i = 0; i < header.length; i++) {
      rec[header[i]] = cols[i] === undefined ? '' : cols[i];
    }
    return rec;
  });

  console.log(`Loaded ${items.length} rows, posting to ${TARGET} with concurrency=${concurrency}`);

  let idx = 0;
  let success = 0;

  async function worker() {
    while (true) {
      const i = idx++;
      if (i >= items.length) break;
      const r = items[i];

      // map CSV columns to API payload
      const payload = {
        name: r.title || r.name || (`Imported ${r.sku||i+1}`),
        product_key: r.sku || r.product_key || undefined,
        description: r.description || undefined,
        barcode: r.barcode || undefined,
        category: r.category || undefined,
        images: safeParseArray(r.images),
        product_url: (safeParseArray(r.images)[0]) || r.product_url || undefined,
        retail_value: r.retail_value ? parseFloat(r.retail_value) : (r.price ? parseFloat(r.price) : undefined),
        selling_value: r.selling_value ? parseFloat(r.selling_value) : (r.price ? parseFloat(r.price) : undefined),
        cost_price: r.cost_price ? parseFloat(r.cost_price) : undefined,
        quantity: r.quantity ? parseInt(r.quantity, 10) : undefined,
        unit: r.unit || undefined,
        tags: safeParseArray(r.tags),
        metadata: {
          supplier: r.metadata_supplier || undefined,
          sku_family: r.metadata_sku_family || undefined,
        },
        skip_vectorize: toBool(r.skip_vectorize),
        vectorize_status: r.vectorize_status || undefined,
        vector_id: r.vector_id || undefined,
        created_at: r.created_at || undefined,
        updated_at: r.updated_at || undefined,
      };

      const ok = await postJSON(payload);
      if (ok) {
        success++;
        if (success % 50 === 0) console.log(`posted ${success}/${items.length}`);
      }
    }
  }

  const workers = [];
  for (let i = 0; i < concurrency; i++) workers.push(worker());
  await Promise.all(workers);
  console.log(`done: posted ${success}/${items.length}`);
}

main().catch(err => { console.error(err); process.exit(1); });
