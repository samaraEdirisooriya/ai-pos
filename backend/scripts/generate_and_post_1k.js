// backend/scripts/generate_and_post_1k.js
// Usage: TARGET=https://... node generate_and_post_1k.js [total=1000] [concurrency=20]

const total = parseInt(process.argv[2] || '1000', 10);
const concurrency = parseInt(process.argv[3] || '20', 10);
const TARGET = process.env.TARGET || 'https://pos-backend.posai.workers.dev/api/products';

let nextId = 1;
let sent = 0;

function makeRecord(i){
  return {
    name: `Auto Product ${i}`,
    product_key: `P-${i}`,
    description: `Generated product ${i}`,
    price: (Math.random()*100).toFixed(2),
    stock: Math.floor(Math.random()*500),
    skip_vectorize: true
  };
}

async function postRecord(rec, attempt=1){
  try{
    const res = await fetch(TARGET, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(rec),
    });
    if(!res.ok){
      const txt = await res.text().catch(()=>'<no-body>');
      throw new Error(`status=${res.status} body=${txt}`);
    }
    sent++;
    if(sent % 100 === 0) console.log(`sent ${sent}/${total}`);
  }catch(e){
    if(attempt<=3){
      console.warn(`retry ${attempt} for ${rec.product_key}: ${e.message}`);
      await new Promise(r=>setTimeout(r, 500 * attempt));
      return postRecord(rec, attempt+1);
    }
    console.error(`failed ${rec.product_key}: ${e.message}`);
  }
}

async function worker(){
  while(true){
    let id;
    if(nextId > total) break;
    id = nextId;
    nextId++;
    const rec = makeRecord(id);
    await postRecord(rec);
  }
}

async function main(){
  console.log(`TARGET=${TARGET} total=${total} concurrency=${concurrency}`);
  const workers = [];
  for(let i=0;i<concurrency;i++) workers.push(worker());
  await Promise.all(workers);
  console.log(`done. sent ${sent} records`);
}

main().catch(err=>{ console.error(err); process.exit(1); });
