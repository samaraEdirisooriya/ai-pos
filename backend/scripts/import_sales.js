const fs = require('fs');
const path = require('path');

const CONCURRENCY = parseInt(process.argv[2]) || 10;
const API_URL = 'https://pos-backend.posai.workers.dev';

async function importSales() {
  try {
    const filePath = path.join(__dirname, 'sales_100.csv');
    const fileContent = fs.readFileSync(filePath, 'utf-8');
    const lines = fileContent.trim().split('\n');

    // Skip header
    const dataLines = lines.slice(1);

    console.log(`🚀 Loading ${dataLines.length} sales from ${filePath}`);
    console.log(`📤 Posting to ${API_URL}/api/sales with concurrency=${CONCURRENCY}\n`);

    let successCount = 0;
    let failureCount = 0;
    const failed = [];

    // Process with concurrency
    for (let batch = 0; batch < dataLines.length; batch += CONCURRENCY) {
      const batchLines = dataLines.slice(batch, batch + CONCURRENCY);
      
      const promises = batchLines.map(async (line, idx) => {
        try {
          // CSV format: id,invoice_total,profit,num_items,"[{...}]"
          // Find the JSON part - it starts with [ and ends with ]
          const jsonStartIdx = line.indexOf(',"[');
          const jsonEndIdx = line.lastIndexOf(']');
          
          if (jsonStartIdx === -1 || jsonEndIdx === -1) {
            failed.push(`Row ${batch + idx + 2}: Invalid JSON format`);
            failureCount++;
            return;
          }

          // Extract JSON string and unescape double quotes
          let salesJson = line.substring(jsonStartIdx + 2, jsonEndIdx + 1);
          // Replace escaped quotes in JSON: "" -> "
          salesJson = salesJson.replace(/""/g, '"');
          
          const items = JSON.parse(salesJson);

          // POST to API
          const response = await fetch(`${API_URL}/api/sales`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ items, created_user: 'import-script' })
          });

          if (response.ok) {
            successCount++;
          } else {
            const error = await response.text();
            failed.push(`Row ${batch + idx + 2}: ${response.status} ${error}`);
            failureCount++;
          }
        } catch (err) {
          failed.push(`Row ${batch + idx + 2}: ${err.message}`);
          failureCount++;
        }
      });

      await Promise.all(promises);

      const posted = Math.min(batch + CONCURRENCY, dataLines.length);
      console.log(`✅ posted ${posted}/${dataLines.length}`);
    }

    console.log(`\n✨ Done: posted ${successCount}/${dataLines.length} sales`);
    
    if (failureCount > 0) {
      console.log(`\n⚠️  Failed: ${failureCount}`);
      failed.forEach(f => console.log(`   ${f}`));
      process.exit(1);
    } else {
      console.log(`🎉 All sales imported successfully!`);
    }

  } catch (err) {
    console.error('Import error:', err.message);
    process.exit(1);
  }
}

importSales();
