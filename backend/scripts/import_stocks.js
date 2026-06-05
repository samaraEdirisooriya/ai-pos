// backend/scripts/import_stocks.js
// Usage: node import_stocks.js [concurrency=20]
// Env: TARGET=https://... (optional)

const fs = require('fs');
const path = require('path');

const csvPath = path.join(__dirname, 'stocks_100.csv');
const concurrency = parseInt(process.argv[2] || '20', 10);
const TARGET = process.env.TARGET || 'https://pos-backend.posai.workers.dev/api/stocks/add';

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
      if (inQuotes && line[i+1] === '"') {
        cur += '"';
        i++;
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
    console.error('POST failed:', e.message, 'obj:', obj.product_id || '<no-product>');
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

  console.log(`\n🚀 Loading ${items.length} stocks from ${csvPath}`);
  console.log(`📤 Posting to ${TARGET} with concurrency=${concurrency}\n`);

  let idx = 0;
  let success = 0;

  async function worker() {
    while (true) {
      const i = idx++;
      if (i >= items.length) break;
      const r = items[i];

      // Map CSV columns to API payload
      const payload = {
        product_id: r.product_id || undefined,
        supplier_id: r.supplier_id || undefined,
        quantity: r.quantity ? parseInt(r.quantity, 10) : 0,
        retail_price: r.retail_price ? parseFloat(r.retail_price) : 0,
        selling_price: r.selling_price ? parseFloat(r.selling_price) : 0,
      };

      // Remove undefined fields
      Object.keys(payload).forEach(k => payload[k] === undefined && delete payload[k]);

      // Skip rows without product_id
      if (!payload.product_id) {
        console.log(`⏭️  Skipped row ${i+2} (no product_id)`);
        continue;
      }

      const ok = await postJSON(payload);
      if (ok) {
        success++;
        if (success % 10 === 0) console.log(`✅ posted ${success}/${items.length}`);
      }
    }
  }

  const workers = [];
  for (let i = 0; i < concurrency; i++) workers.push(worker());
  await Promise.all(workers);
  
  console.log(`\n✨ Done: posted ${success}/${items.length} stocks`);
  if (success === items.length) {
    console.log('🎉 All stocks imported successfully!');
  } else {
    console.log(`⚠️  ${items.length - success} stocks failed or skipped`);
  }
}

main().catch(err => { console.error(err); process.exit(1); });
