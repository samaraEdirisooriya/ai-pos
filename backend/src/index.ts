export interface Env {
  DB: D1Database;
  SCANNER_KV: KVNamespace;
  VECTORIZE: Vectorize;
  AI: Ai;
  EMBED_QUEUE?: KVNamespace;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

function generateRandomKey(length: number = 8): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

async function enqueueEmbedding(env: Env, eventId: string) {
  try {
    const key = 'embed:queue';
    const raw = env.EMBED_QUEUE ? await env.EMBED_QUEUE.get(key) : null;
    let list: string[] = [];
    if (raw) {
      try { list = JSON.parse(raw); } catch (_) { list = []; }
    }
    list.push(eventId);
    if (env.EMBED_QUEUE) {
      try {
        await env.EMBED_QUEUE.put(key, JSON.stringify(list));
        return;
      } catch (e) {
        console.warn('KV put failed in enqueueEmbedding, falling back to DB', e);
      }
    }

    // KV put failed or not configured -> fallback to D1 table
    try {
      await env.DB.prepare(`CREATE TABLE IF NOT EXISTS EMBED_QUEUE (id INTEGER PRIMARY KEY AUTOINCREMENT, event_id TEXT, queued_at DATETIME DEFAULT CURRENT_TIMESTAMP, processed INTEGER DEFAULT 0)`).run();
      await env.DB.prepare('INSERT INTO EMBED_QUEUE (event_id, processed) VALUES (?, 0)').bind(eventId).run();
      return;
    } catch (dbErr) {
      console.warn('Failed to fallback-insert embed queue to DB', dbErr);
    }
  } catch (e) {
    console.warn('Failed to enqueue embedding', e);
  }
}

async function dequeueEmbeddingBatch(env: Env, batch: number = 50): Promise<string[]> {
  try {
    if (!env.EMBED_QUEUE) return [];
    const key = 'embed:queue';
    const raw = await env.EMBED_QUEUE.get(key);
    let list: string[] = [];
    if (raw) {
      try { list = JSON.parse(raw); } catch (_) { list = []; }
    }
    if (!list.length) return [];
    const take = list.slice(0, batch);
    const remain = list.slice(take.length);
    await env.EMBED_QUEUE.put(key, JSON.stringify(remain));
    return take;
  } catch (e) {
    console.warn('Failed to dequeue embedding batch', e);
    return [];
  }
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }
    
    // GET /api/users
    if (url.pathname === "/api/users" && request.method === "GET") {
      try {
        const { results } = await env.DB.prepare("SELECT * FROM USERS").all();
        return Response.json({ success: true, data: results }, { headers: corsHeaders });
      } catch (error: any) {
        return Response.json({ success: false, error: error.message }, { status: 500, headers: corsHeaders });
      }
    }

    // POST /api/products (Create Product)
    if (url.pathname === "/api/products" && request.method === "POST") {
      try {
        const body: any = await request.json();
        const { name, category, description, retail_value, selling_value, offer_percentage, product_url, created_user } = body;
        
        const productId = crypto.randomUUID();
        const productKey = "PRD-" + generateRandomKey(8);
        const active = 1;
        const offer_percent = offer_percentage ? parseFloat(offer_percentage) : 0;
        const offer_have = offer_percent > 0 ? 1 : 0;

        // Auto-insert user to bypass missing foreign key constraint
        const user = created_user || "admin";
        await env.DB.prepare(
          "INSERT OR IGNORE INTO USERS (user_id, name) VALUES (?, ?)"
        ).bind(user, "System Admin").run();

        await env.DB.prepare(
          `INSERT INTO PRODUCTS (product_id, product_key, name, category, description, retail_value, selling_value, active, offer_have, offer_percentage, product_url, created_user) 
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
        ).bind(
          productId, productKey, name, category || "General", description || name, parseFloat(retail_value), parseFloat(selling_value), 
          active, offer_have, offer_percent, product_url || "", user
        ).run();

        // Initialize Live Stocks
        await env.DB.prepare(
          `INSERT INTO LIVE_STOCKS (product_id, live_stock_count, live_selling_count) VALUES (?, ?, ?)`
        ).bind(productId, 0, 0).run();

        // Initialize Live Profit
        await env.DB.prepare(
          `INSERT INTO LIVE_PROFIT (product_id, total_retail_price, total_selling_price, total_discount_price, total_price, total_profit) VALUES (?, ?, ?, ?, ?, ?)`
        ).bind(productId, 0, 0, 0, 0, 0).run();

        // Generate AI event row for product creation and optionally enqueue embedding
        try {
          const productNarrative = `New product added: "${name}" (${productKey}). Category: ${category || 'General'}. Description: ${description || 'N/A'}. Retail price: ${retail_value}, Selling price: ${selling_value}.`;
          const eventId = crypto.randomUUID();
          const now = new Date();
          const expiresAt = new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000);
          await env.DB.prepare(
            `INSERT INTO AI_EVENTS (event_id, event_type, narrative, metadata, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?)`
          ).bind(eventId, 'product_added', productNarrative, JSON.stringify({product_id: productId, product_key: productKey}), now.toISOString(), expiresAt.toISOString()).run();

          const skip = Boolean(body?.skip_vectorize);
          if (skip) {
            await enqueueEmbedding(env, eventId);
          } else {
            try {
              const embeddingResponse = await (env.AI as any).run('@cf/baai/bge-m3', { text: productNarrative }) as any;
              const embedding = embeddingResponse.result?.data?.[0]?.embedding || embeddingResponse.data?.[0];
              await env.VECTORIZE.upsert([{ id: eventId, values: embedding, metadata: { narrative: productNarrative, event_type: 'product_added', product_id: productId } }]);
            } catch (embedError) {
              console.warn('Embedding error:', embedError);
              await enqueueEmbedding(env, eventId);
            }
          }
        } catch (embedErrorOuter) {
          console.warn('Embedding/event error:', embedErrorOuter);
        }

        const newProduct = await env.DB.prepare("SELECT * FROM PRODUCTS WHERE product_id = ?").bind(productId).first();
        return Response.json({ success: true, data: newProduct }, { status: 201, headers: corsHeaders });
      } catch (error: any) {
        return Response.json({ success: false, error: "DB Error: " + error.message, stack: error.stack }, { status: 500, headers: corsHeaders });
      }
    }

    // GET /api/products (List/Search Products)
    if (url.pathname === "/api/products" && request.method === "GET") {
      try {
        const query = url.searchParams.get("q");
        const page = parseInt(url.searchParams.get('page') || '1');
        const limit = Math.min(100, parseInt(url.searchParams.get('limit') || '50'));
        const offset = (Math.max(1, page) - 1) * limit;

        let results;
        if (query) {
          // Search by name (partial) OR exact product_key
          results = await env.DB.prepare("SELECT * FROM PRODUCTS WHERE name LIKE ? OR product_key = ? ORDER BY createdAt DESC LIMIT ? OFFSET ?").bind(`%${query}%`, query, limit, offset).all();
        } else {
          results = await env.DB.prepare("SELECT * FROM PRODUCTS ORDER BY createdAt DESC LIMIT ? OFFSET ?").bind(limit, offset).all();
        }

        // total count for meta
        let countRes;
        if (query) {
          countRes = await env.DB.prepare("SELECT COUNT(1) as c FROM PRODUCTS WHERE name LIKE ? OR product_key = ?").bind(`%${query}%`, query).first();
        } else {
          countRes = await env.DB.prepare("SELECT COUNT(1) as c FROM PRODUCTS").first();
        }
        const total = countRes?.c || 0;

        return Response.json({ success: true, data: results.results, meta: { total, page, limit } }, { headers: corsHeaders });
      } catch (error: any) {
        return Response.json({ success: false, error: error.message }, { status: 500, headers: corsHeaders });
      }
    }

    // GET /api/products/lookup (Fast lookup by product_key or product_id)
    if (url.pathname === "/api/products/lookup" && request.method === "GET") {
      try {
        const key = url.searchParams.get('key') || url.searchParams.get('product_key');
        const id = url.searchParams.get('product_id');
        if (!key && !id) {
          return Response.json({ success: false, error: 'Missing key or product_id' }, { status: 400, headers: corsHeaders });
        }

        let product;
        if (key) {
          product = await env.DB.prepare('SELECT * FROM PRODUCTS WHERE product_key = ?').bind(key).first();
        } else {
          product = await env.DB.prepare('SELECT * FROM PRODUCTS WHERE product_id = ?').bind(id).first();
        }

        return Response.json({ success: true, data: product }, { headers: corsHeaders });
      } catch (error: any) {
        return Response.json({ success: false, error: error.message }, { status: 500, headers: corsHeaders });
      }
    }

    // GET /api/stocks (Get Live Stocks with Product info)
    if (url.pathname === "/api/stocks" && request.method === "GET") {
      try {
        const query = url.searchParams.get("q");
        const page = parseInt(url.searchParams.get('page') || '1');
        const limit = Math.min(200, parseInt(url.searchParams.get('limit') || '50'));
        const offset = (Math.max(1, page) - 1) * limit;

        let results;
        if (query) {
          results = await env.DB.prepare(`
            SELECT P.product_id, P.name, P.product_key, P.product_url, P.selling_value, LS.live_stock_count, LS.live_selling_count 
            FROM PRODUCTS P 
            JOIN LIVE_STOCKS LS ON P.product_id = LS.product_id 
            WHERE P.name LIKE ? 
            ORDER BY P.createdAt DESC
            LIMIT ? OFFSET ?
          `).bind(`%${query}%`, limit, offset).all();
        } else {
          results = await env.DB.prepare(`
            SELECT P.product_id, P.name, P.product_key, P.product_url, P.selling_value, LS.live_stock_count, LS.live_selling_count 
            FROM PRODUCTS P 
            JOIN LIVE_STOCKS LS ON P.product_id = LS.product_id 
            ORDER BY P.createdAt DESC
            LIMIT ? OFFSET ?
          `).bind(limit, offset).all();
        }

        // total count for meta
        let countRes;
        if (query) {
          countRes = await env.DB.prepare(`
            SELECT COUNT(1) as c FROM PRODUCTS P WHERE P.name LIKE ?
          `).bind(`%${query}%`).first();
        } else {
          countRes = await env.DB.prepare(`SELECT COUNT(1) as c FROM PRODUCTS`).first();
        }
        const total = countRes?.c || 0;

        return Response.json({ success: true, data: results.results, meta: { total, page, limit } }, { headers: corsHeaders });
      } catch (error: any) {
        return Response.json({ success: false, error: "DB Error: " + error.message, stack: error.stack }, { status: 500, headers: corsHeaders });
      }
    }

    // GET /api/suppliers (List Suppliers) - supports ?q=&page=&limit=
    if (url.pathname === "/api/suppliers" && request.method === "GET") {
      try {
        const q = url.searchParams.get('q');
        const page = parseInt(url.searchParams.get('page') || '1');
        const limit = Math.min(100, parseInt(url.searchParams.get('limit') || '20'));
        const offset = (Math.max(1, page) - 1) * limit;

        let results;
        if (q) {
          results = await env.DB.prepare("SELECT supplier_id, name, email, phone_num, total_stock FROM SUPPLIERS WHERE name LIKE ? ORDER BY createdAt DESC LIMIT ? OFFSET ?").bind(`%${q}%`, limit, offset).all();
        } else {
          results = await env.DB.prepare("SELECT supplier_id, name, email, phone_num, total_stock FROM SUPPLIERS ORDER BY createdAt DESC LIMIT ? OFFSET ?").bind(limit, offset).all();
        }

        // total count (simple, may be slower but ok)
        let countRes;
        if (q) {
          countRes = await env.DB.prepare("SELECT COUNT(1) as c FROM SUPPLIERS WHERE name LIKE ?").bind(`%${q}%`).first();
        } else {
          countRes = await env.DB.prepare("SELECT COUNT(1) as c FROM SUPPLIERS").first();
        }
        const total = countRes?.c || 0;

        return Response.json({ success: true, data: results.results, meta: { total, page, limit } }, { headers: corsHeaders });
      } catch (error: any) {
        return Response.json({ success: false, error: "DB Error: " + error.message, stack: error.stack }, { status: 500, headers: corsHeaders });
      }
    }
    
    // POST /api/suppliers (Create Supplier)
    if (url.pathname === "/api/suppliers" && request.method === "POST") {
      try {
        const body: any = await request.json();
        const { name, email, phone_num, address, created_user } = body || {};
        if (!name) return Response.json({ success: false, error: 'Missing name' }, { status: 400, headers: corsHeaders });

        const supplierId = crypto.randomUUID();
        await env.DB.prepare(
          `INSERT INTO SUPPLIERS (supplier_id, name, email, phone_num, address, total_stock, retail_price_total, created_user) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
        ).bind(supplierId, name, email || '', phone_num || '', address || '', 0, 0, created_user || 'admin').run();

        const newSupplier = await env.DB.prepare("SELECT * FROM SUPPLIERS WHERE supplier_id = ?").bind(supplierId).first();
        return Response.json({ success: true, data: newSupplier }, { status: 201, headers: corsHeaders });
      } catch (error: any) {
        return Response.json({ success: false, error: "DB Error: " + error.message }, { status: 500, headers: corsHeaders });
      }
    }

    // GET /api/suppliers/:id (Supplier details + recent stock history)
    if (url.pathname.startsWith('/api/suppliers/') && request.method === 'GET') {
      try {
        const parts = url.pathname.split('/');
        const supplierId = parts[parts.length - 1];
        if (!supplierId) return Response.json({ success: false, error: 'Missing supplierId' }, { status: 400, headers: corsHeaders });

        const supplier = await env.DB.prepare('SELECT * FROM SUPPLIERS WHERE supplier_id = ?').bind(supplierId).first();

        // Fetch recent stock history for this supplier
        const history = await env.DB.prepare(`
          SELECT S.stock_id, S.product_id, S.count, S.retail_price, S.selling_price, S.createdAt, P.name as product_name, P.product_key
          FROM STOCKS S
          LEFT JOIN PRODUCTS P ON S.product_id = P.product_id
          WHERE S.supplier_id = ?
          ORDER BY S.createdAt DESC
          LIMIT 200
        `).bind(supplierId).all();

        return Response.json({ success: true, supplier, history: history.results }, { headers: corsHeaders });
      } catch (error: any) {
        return Response.json({ success: false, error: error.message }, { status: 500, headers: corsHeaders });
      }
    }
    
    // ===== CLIENTS API =====
    // GET /api/clients (List Clients) - supports ?q=&page=&limit=
    if (url.pathname === "/api/clients" && request.method === "GET") {
      try {
        const q = url.searchParams.get('q');
        const page = parseInt(url.searchParams.get('page') || '1');
        const limit = Math.min(100, parseInt(url.searchParams.get('limit') || '20'));
        const offset = (Math.max(1, page) - 1) * limit;

        let results;
        if (q) {
          results = await env.DB.prepare("SELECT client_id, name, email, phone_num, total_price, profit, balance, createdAt FROM CLIENTS WHERE name LIKE ? ORDER BY createdAt DESC LIMIT ? OFFSET ?").bind(`%${q}%`, limit, offset).all();
        } else {
          results = await env.DB.prepare("SELECT client_id, name, email, phone_num, total_price, profit, balance, createdAt FROM CLIENTS ORDER BY createdAt DESC LIMIT ? OFFSET ?").bind(limit, offset).all();
        }

        let countRes;
        if (q) {
          countRes = await env.DB.prepare("SELECT COUNT(1) as c FROM CLIENTS WHERE name LIKE ?").bind(`%${q}%`).first();
        } else {
          countRes = await env.DB.prepare("SELECT COUNT(1) as c FROM CLIENTS").first();
        }
        const total = countRes?.c || 0;

        return Response.json({ success: true, data: results.results, meta: { total, page, limit } }, { headers: corsHeaders });
      } catch (error: any) {
        return Response.json({ success: false, error: "DB Error: " + error.message, stack: error.stack }, { status: 500, headers: corsHeaders });
      }
    }

    // POST /api/clients (Create Client)
    if (url.pathname === "/api/clients" && request.method === "POST") {
      try {
        const body: any = await request.json();
        const { name, email, phone_num, address, created_user } = body || {};
        if (!name) return Response.json({ success: false, error: 'Missing name' }, { status: 400, headers: corsHeaders });

        const clientId = crypto.randomUUID();
        await env.DB.prepare(
          `INSERT INTO CLIENTS (client_id, name, email, phone_num, address, total_price, profit, balance, created_user) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
        ).bind(clientId, name, email || '', phone_num || '', address || '', 0, 0, 0, created_user || 'admin').run();

        const newClient = await env.DB.prepare("SELECT * FROM CLIENTS WHERE client_id = ?").bind(clientId).first();
        return Response.json({ success: true, data: newClient }, { status: 201, headers: corsHeaders });
      } catch (error: any) {
        return Response.json({ success: false, error: "DB Error: " + error.message }, { status: 500, headers: corsHeaders });
      }
    }

    // GET /api/clients/:id (Client details + recent sales history)
    if (url.pathname.startsWith('/api/clients/') && request.method === 'GET') {
      try {
        const parts = url.pathname.split('/');
        const clientId = parts[parts.length - 1];
        if (!clientId) return Response.json({ success: false, error: 'Missing clientId' }, { status: 400, headers: corsHeaders });

        const client = await env.DB.prepare('SELECT * FROM CLIENTS WHERE client_id = ?').bind(clientId).first();

        // Fetch recent sales for this client
        const sales = await env.DB.prepare(`
          SELECT S.sale_id, S.product_id, S.quantity, S.retail_price, S.selling_price, S.discount_price, S.total_price, S.profit, S.live_selling_count, S.createdAt, P.name as product_name, P.product_key
          FROM SALES S
          LEFT JOIN PRODUCTS P ON S.product_id = P.product_id
          WHERE S.client_id = ?
          ORDER BY S.createdAt DESC
          LIMIT 200
        `).bind(clientId).all();

        return Response.json({ success: true, data: client, sales: sales.results }, { headers: corsHeaders });
      } catch (error: any) {
        return Response.json({ success: false, error: error.message }, { status: 500, headers: corsHeaders });
      }
    }

    
    // POST /api/stocks/add (Add quantity to stock)
    if (url.pathname === "/api/stocks/add" && request.method === "POST") {
      try {
        const body: any = await request.json();
        const { product_id, supplier_id, quantity, retail_price, selling_price } = body;
        
        if (!product_id || typeof quantity !== "number") {
          return Response.json({ success: false, error: "Invalid product_id or quantity" }, { status: 400, headers: corsHeaders });
        }

        const validSupplierId = (supplier_id === "guest" || !supplier_id) ? null : supplier_id;

        // Add history record for STOCKS
        const stockId = crypto.randomUUID();
        await env.DB.prepare(
          "INSERT INTO STOCKS (stock_id, product_id, supplier_id, count, retail_price, selling_price, created_user) VALUES (?, ?, ?, ?, ?, ?, ?)"
        ).bind(stockId, product_id, validSupplierId, quantity, retail_price || 0, selling_price || 0, "admin").run();

        // Increment Live Stock Count
        await env.DB.prepare(
          "UPDATE LIVE_STOCKS SET live_stock_count = live_stock_count + ? WHERE product_id = ?"
        ).bind(quantity, product_id).run();

        // Update supplier totals if supplier provided
        if (validSupplierId) {
          try {
            await env.DB.prepare(
              "UPDATE SUPPLIERS SET total_stock = COALESCE(total_stock,0) + ?, retail_price_total = COALESCE(retail_price_total,0) + ? WHERE supplier_id = ?"
            ).bind(quantity, (retail_price || 0) * quantity, validSupplierId).run();
          } catch (e) {
            // ignore supplier update errors
          }
        }

        // Log AI event for stock addition and optionally enqueue embedding
        try {
          const productInfo = await env.DB.prepare("SELECT name FROM PRODUCTS WHERE product_id = ?").bind(product_id).first();
          const productName = (productInfo as any)?.name || product_id;
          const stockNarrative = `Stock restocked: ${quantity} units of "${productName}" added. Retail price per unit: ${retail_price || 0}. Selling price per unit: ${selling_price || 0}.`;
          const eventId = crypto.randomUUID();
          const now = new Date();
          const expiresAt = new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000);
          await env.DB.prepare(
            `INSERT INTO AI_EVENTS (event_id, event_type, narrative, metadata, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?)`
          ).bind(eventId, 'stock_added', stockNarrative, JSON.stringify({product_id, quantity, retail_price, selling_price}), now.toISOString(), expiresAt.toISOString()).run();

          const skip = Boolean(body?.skip_vectorize);
          if (skip) {
            await enqueueEmbedding(env, eventId);
          } else {
            try {
              const embeddingResponse = await (env.AI as any).run('@cf/baai/bge-m3', { text: stockNarrative }) as any;
              const embedding = embeddingResponse.result?.data?.[0]?.embedding || embeddingResponse.data?.[0];
              await env.VECTORIZE.upsert([{ id: eventId, values: embedding, metadata: { narrative: stockNarrative, event_type: 'stock_added', product_id } }]);
            } catch (embedError) {
              console.warn('Embedding error:', embedError);
              await enqueueEmbedding(env, eventId);
            }
          }
        } catch (embedErrorOuter) {
          console.warn('Embedding/event error:', embedErrorOuter);
        }

        return Response.json({ success: true, message: "Stock added successfully" }, { status: 200, headers: corsHeaders });
      } catch (error: any) {
        return Response.json({ success: false, error: "DB Error: " + error.message, stack: error.stack }, { status: 500, headers: corsHeaders });
      }
    }

      // POST /api/sales (Record sales / checkout)
      if (url.pathname === "/api/sales" && request.method === "POST") {
        try {
          const body: any = await request.json();
          const { items, client_id, created_user } = body || {};
          if (!items || !Array.isArray(items) || !items.length) {
            return Response.json({ success: false, error: 'Missing items array' }, { status: 400, headers: corsHeaders });
          }

          const user = created_user || 'admin';
          // ensure user exists to satisfy foreign keys
          await env.DB.prepare("INSERT OR IGNORE INTO USERS (user_id, name) VALUES (?, ?)").bind(user, 'System User').run();

          let totalInvoice = 0;
          let totalProfit = 0;
          const salesRecords: any[] = [];

          for (const it of items) {
            const product_id = it.product_id;
            const quantity = Number(it.quantity || 0);
            let retail_price = Number(it.retail_price || 0);
            let selling_price = Number(it.selling_price || 0);
            const discount_price = Number(it.discount_price || 0);

            if (!product_id || quantity <= 0) continue;

            // If prices not supplied, fallback to latest STOCKS entry for this product
            if ((!retail_price || retail_price <= 0) || (!selling_price || selling_price <= 0)) {
              try {
                const stockRow = await env.DB.prepare(
                  `SELECT retail_price, selling_price FROM STOCKS WHERE product_id = ? ORDER BY createdAt DESC LIMIT 1`
                ).bind(product_id).first();
                if (stockRow) {
                  if (!retail_price || retail_price <= 0) retail_price = Number(stockRow.retail_price || 0);
                  if (!selling_price || selling_price <= 0) selling_price = Number(stockRow.selling_price || 0);
                }
              } catch (e) {
                // ignore and use provided prices (even if zero)
              }
            }

            // Treat discount_price as per-unit discount; total discount is multiplied by quantity
            const totalDiscount = discount_price * quantity;
            const lineTotal = (selling_price - discount_price) * quantity;
            const lineProfit = (selling_price - discount_price - retail_price) * quantity;

            // update live stocks
            await env.DB.prepare(
              "UPDATE LIVE_STOCKS SET live_stock_count = COALESCE(live_stock_count,0) - ?, live_selling_count = COALESCE(live_selling_count,0) + ? WHERE product_id = ?"
            ).bind(quantity, quantity, product_id).run();

            // read current live_selling_count
            const liveRow = await env.DB.prepare("SELECT live_selling_count, live_stock_count FROM LIVE_STOCKS WHERE product_id = ?").bind(product_id).first();
            const live_selling_count = liveRow?.live_selling_count || 0;

            // insert sale record
            const saleId = crypto.randomUUID();
            await env.DB.prepare(
              `INSERT INTO SALES (sale_id, product_id, quantity, retail_price, selling_price, discount_price, total_price, profit, live_selling_count, created_user, client_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
            ).bind(saleId, product_id, quantity, retail_price, selling_price, discount_price, lineTotal, lineProfit, live_selling_count, user, client_id || null).run();

            // update live profit totals (insert if missing)
            await env.DB.prepare(
              `INSERT OR IGNORE INTO LIVE_PROFIT (product_id, total_retail_price, total_selling_price, total_discount_price, total_price, total_profit) VALUES (?, ?, ?, ?, ?, ?)`
            ).bind(product_id, 0, 0, 0, 0, 0).run();

            await env.DB.prepare(
              `UPDATE LIVE_PROFIT SET total_retail_price = COALESCE(total_retail_price,0) + ?, total_selling_price = COALESCE(total_selling_price,0) + ?, total_discount_price = COALESCE(total_discount_price,0) + ?, total_price = COALESCE(total_price,0) + ?, total_profit = COALESCE(total_profit,0) + ? WHERE product_id = ?`
            ).bind(retail_price * quantity, selling_price * quantity, totalDiscount, lineTotal, lineProfit, product_id).run();

            // Log product sale event to AI_EVENTS
            try {
              const productInfo = await env.DB.prepare("SELECT name FROM PRODUCTS WHERE product_id = ?").bind(product_id).first();
              const prodName = (productInfo as any)?.name || product_id;
              const saleNarrative = `Sale: ${quantity} units of "${prodName}" sold. Profit per unit: ${((selling_price - discount_price - retail_price).toFixed(2))}. Total profit: ${lineProfit.toFixed(2)}.`;
              const eventId = crypto.randomUUID();
              const now = new Date();
              const expiresAt = new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000);
              await env.DB.prepare(
                `INSERT INTO AI_EVENTS (event_id, event_type, narrative, metadata, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?)`
              ).bind(eventId, 'sale_completed', saleNarrative, JSON.stringify({product_id, quantity, profit: lineProfit}), now.toISOString(), expiresAt.toISOString()).run();

              const skip = Boolean(body?.skip_vectorize);
              if (skip) {
                await enqueueEmbedding(env, eventId);
              } else {
                try {
                  const embeddingResponse = await (env.AI as any).run('@cf/baai/bge-m3', { text: saleNarrative }) as any;
                  const embedding = embeddingResponse.result?.embeddings?.[0] || embeddingResponse.data?.[0]?.embedding || embeddingResponse.data?.[0];
                  await env.VECTORIZE.upsert([{ id: eventId, values: embedding, metadata: { narrative: saleNarrative, event_type: 'sale_completed', product_id } }]);
                } catch (embedErr) {
                  console.warn('Sale embedding error:', embedErr);
                  await enqueueEmbedding(env, eventId);
                }
              }
            } catch (embedError) {
              console.warn('Sale event embedding error:', embedError);
            }

            totalInvoice += lineTotal;
            totalProfit += lineProfit;

            salesRecords.push({ sale_id: saleId, product_id, quantity, retail_price, selling_price, discount_price, total_price: lineTotal, profit: lineProfit });
          }

          // update client totals if client provided
          if (client_id) {
            await env.DB.prepare(
              `UPDATE CLIENTS SET total_price = COALESCE(total_price,0) + ?, profit = COALESCE(profit,0) + ? WHERE client_id = ?`
            ).bind(totalInvoice, totalProfit, client_id).run();
          }

          return Response.json({ success: true, invoice_total: totalInvoice, profit: totalProfit, sales: salesRecords }, { status: 201, headers: corsHeaders });
        } catch (error: any) {
          return Response.json({ success: false, error: error.message }, { status: 500, headers: corsHeaders });
        }
      }
    
    // POST /api/scanner/submit (Append scan to session list in KV)
    if (url.pathname === "/api/scanner/submit" && request.method === "POST") {
      try {
        const body: any = await request.json();
        const { sessionId, code } = body || {};
        if (!sessionId || !code) {
          return Response.json({ success: false, error: 'Missing sessionId or code' }, { status: 400, headers: corsHeaders });
        }
        const key = 'scan:' + sessionId;
        const item = { id: crypto.randomUUID(), code, ts: Date.now(), bookmarked: false };
        // Try KV first; if KV quota or put fails, fallback to D1 table
        try {
          const raw = await env.SCANNER_KV.get(key);
          let list: any[] = [];
          if (raw) {
            try { list = JSON.parse(raw); } catch (_) { list = []; }
          }
          list.push(item);
          await env.SCANNER_KV.put(key, JSON.stringify(list), { expirationTtl: 3600 });
          return Response.json({ success: true, stored: true, item, storage: 'kv' }, { status: 200, headers: corsHeaders });
        } catch (kvErr) {
          // KV failed (quota etc.) — attempt D1 fallback
          try {
            await env.DB.prepare(`CREATE TABLE IF NOT EXISTS SCANNER_EVENTS (id TEXT PRIMARY KEY, session_id TEXT, code TEXT, ts INTEGER, bookmarked INTEGER)`).run();
            await env.DB.prepare(`INSERT INTO SCANNER_EVENTS (id, session_id, code, ts, bookmarked) VALUES (?, ?, ?, ?, ?)`).bind(item.id, sessionId, code, item.ts, 0).run();
            return Response.json({ success: true, stored: true, item, storage: 'd1' }, { status: 200, headers: corsHeaders });
          } catch (dbErr) {
            return Response.json({ success: false, error: 'KV error: ' + String(kvErr) + ' ; DB fallback error: ' + String(dbErr) }, { status: 500, headers: corsHeaders });
          }
        }
      } catch (error: any) {
        return Response.json({ success: false, error: error.message }, { status: 500, headers: corsHeaders });
      }
    }

    // GET /api/scanner/status/:sessionId (Return list of scans for session)
    if (url.pathname.startsWith('/api/scanner/status/') && request.method === 'GET') {
      try {
        const parts = url.pathname.split('/');
        const sessionId = parts[parts.length - 1];
        if (!sessionId) {
          return Response.json({ success: false, error: 'Missing sessionId' }, { status: 400, headers: corsHeaders });
        }
        const key = 'scan:' + sessionId;
        const raw = await env.SCANNER_KV.get(key);
        let list: any[] = [];
        if (raw) {
          try { list = JSON.parse(raw); } catch (_) { list = []; }
        }
        // If KV empty, try D1 fallback table
        if ((!list || list.length === 0) && env.DB) {
          try {
            const rows = await env.DB.prepare(`SELECT id, code, ts, bookmarked FROM SCANNER_EVENTS WHERE session_id = ? ORDER BY ts DESC LIMIT 1000`).bind(sessionId).all();
            if (rows && (rows.results?.length || 0) > 0) {
              const res = rows.results || [];
              list = (res as any[]).map(r => ({ id: r.id, code: r.code, ts: r.ts, bookmarked: !!r.bookmarked }));
            }
          } catch (e) {
            // ignore DB read errors
          }
        }
        return Response.json({ success: true, scans: list }, { status: 200, headers: corsHeaders });
      } catch (error: any) {
        return Response.json({ success: false, error: error.message }, { status: 500, headers: corsHeaders });
      }
    }

      // GET /api/scanner/pop/:sessionId (Return and remove the oldest scan for session)
      if (url.pathname.startsWith('/api/scanner/pop/') && request.method === 'GET') {
        try {
          const parts = url.pathname.split('/');
          const sessionId = parts[parts.length - 1];
          if (!sessionId) {
            return Response.json({ success: false, error: 'Missing sessionId' }, { status: 400, headers: corsHeaders });
          }
          const key = 'scan:' + sessionId;
          const raw = await env.SCANNER_KV.get(key);
          let list: any[] = [];
          if (raw) {
            try { list = JSON.parse(raw); } catch (_) { list = []; }
          }
          if (list && list.length > 0) {
            const item = list.shift();
            await env.SCANNER_KV.put(key, JSON.stringify(list), { expirationTtl: 3600 });
            return Response.json({ success: true, item }, { status: 200, headers: corsHeaders });
          }
          // KV empty: try D1 fallback (pop oldest)
          if (env.DB) {
            try {
              const row = await env.DB.prepare(`SELECT id, code, ts, bookmarked FROM SCANNER_EVENTS WHERE session_id = ? ORDER BY ts ASC LIMIT 1`).bind(sessionId).first();
              if (!row) return Response.json({ success: true, item: null }, { status: 200, headers: corsHeaders });
              const item = { id: row.id, code: row.code, ts: row.ts, bookmarked: !!row.bookmarked };
              // remove it
              await env.DB.prepare(`DELETE FROM SCANNER_EVENTS WHERE id = ?`).bind(row.id).run();
              return Response.json({ success: true, item }, { status: 200, headers: corsHeaders });
            } catch (e) {
              return Response.json({ success: false, error: String(e) }, { status: 500, headers: corsHeaders });
            }
          }
          return Response.json({ success: true, item: null }, { status: 200, headers: corsHeaders });
        } catch (error: any) {
          return Response.json({ success: false, error: error.message }, { status: 500, headers: corsHeaders });
        }
      }

    // POST /api/ai/chat (AI Chat with semantic search)
    if (url.pathname === "/api/ai/chat" && request.method === "POST") {
      try {
        const body: any = await request.json();
        const { query } = body;
        
        if (!query) {
          return Response.json({ success: false, error: "Missing query" }, { status: 400, headers: corsHeaders });
        }

        // 1. Generate embedding for user query
        const embeddingResponse = await (env.AI as any).run('@cf/baai/bge-m3', {
          text: query
        }) as any;
        const userEmbedding = embeddingResponse.result?.embeddings?.[0] || embeddingResponse.data?.[0]?.embedding || embeddingResponse.data?.[0];

        // 2. Search Vectorize for relevant context (top 5 matches)
        const vectorResults = await env.VECTORIZE.query(userEmbedding, { topK: 5, returnMetadata: true }) as any;
        const context = vectorResults.matches
          .map((m: any) => m.metadata?.narrative || m.metadata?.text || '')
          .filter((text: string) => text.length > 0)
          .join('\n');

        // 3. Query recent AI_EVENTS from D1 as fallback context
        const eventsRes = await env.DB.prepare(
          `SELECT narrative FROM AI_EVENTS WHERE created_at > datetime('now', '-7 days') ORDER BY created_at DESC LIMIT 10`
        ).all();
        const eventContext = (eventsRes.results as any[]).map((e: any) => e.narrative).join('\n');

        // 4. Build comprehensive prompt
        const finalContext = context ? context : eventContext;
        const systemPrompt = `You are a professional POS Assistant for "Lanka AI Super POS" system. 
You help with inventory queries, profit analysis, customer info, and business insights.
Based on this context, provide concise and helpful answers.

Context from system:
${finalContext || 'No specific context available. Answer based on POS system knowledge.'}

Rules:
- Be concise and professional
- Focus on actionable business insights
- If you don't know, say so
- Always think like a store manager`;

        // 5. Try to use latest available LLM
        let aiResponse = {
          response: `I'm the POS AI Assistant. Processing your question...`
        };

        // Try to use latest LLM if available
        try {
          const actualResponse = await (env.AI as any).run('@cf/meta/llama-3.1-8b-instruct', {
            messages: [
              { role: 'system', content: systemPrompt },
              { role: 'user', content: query }
            ],
            max_tokens: 256
          }) as any;
          if (actualResponse?.response) {
            aiResponse = actualResponse;
          }
        } catch (llmError) {
          console.warn('LLM error (using enhanced mock response):', llmError);
        }

        return Response.json({
          success: true,
          query,
          response: aiResponse.response,
          context_used: 'direct'
        }, { headers: corsHeaders });
      } catch (error: any) {
        return Response.json({
          success: false,
          error: error.message
        }, { status: 500, headers: corsHeaders });
      }
    }

    // POST /api/ai/log-event (Log business events for vector DB)
    if (url.pathname === "/api/ai/log-event" && request.method === "POST") {
      try {
        const body: any = await request.json();
        const { event_type, narrative, metadata } = body;

        if (!event_type || !narrative) {
          return Response.json({ success: false, error: "Missing event_type or narrative" }, { status: 400, headers: corsHeaders });
        }

        const eventId = crypto.randomUUID();
        const now = new Date();
        const expiresAt = new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000); // 90 days

        // Store in D1
        await env.DB.prepare(
          `INSERT INTO AI_EVENTS (event_id, event_type, narrative, metadata, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?)`
        ).bind(eventId, event_type, narrative, JSON.stringify(metadata || {}), now.toISOString(), expiresAt.toISOString()).run();

        // Generate embedding and store in Vectorize (allow skip_vectorize)
        const skip = Boolean(body?.skip_vectorize);
        if (skip) {
          await enqueueEmbedding(env, eventId);
        } else {
          try {
            const embeddingResponse = await (env.AI as any).run('@cf/baai/bge-m3', { text: narrative }) as any;
            const embedding = embeddingResponse.result?.data?.[0]?.embedding || embeddingResponse.data?.[0];
            await env.VECTORIZE.upsert([{ id: eventId, values: embedding, metadata: { narrative, event_type, created_at: now.toISOString(), ...metadata } }]);
          } catch (embedErr) {
            console.warn('log-event embedding error:', embedErr);
            await enqueueEmbedding(env, eventId);
          }
        }

        return Response.json({ success: true, event_id: eventId }, { status: 201, headers: corsHeaders });
      } catch (error: any) {
        return Response.json({ success: false, error: error.message }, { status: 500, headers: corsHeaders });
      }
    }

    // DELETE /api/scanner/status/:sessionId/:scanId (Remove a scan from session)
    if (url.pathname.startsWith('/api/scanner/status/') && request.method === 'DELETE') {
      try {
        const parts = url.pathname.split('/');
        const scanId = parts.pop();
        const sessionId = parts[parts.length - 1];
        if (!sessionId || !scanId) {
          return Response.json({ success: false, error: 'Missing sessionId or scanId' }, { status: 400, headers: corsHeaders });
        }
        const key = 'scan:' + sessionId;
        const raw = await env.SCANNER_KV.get(key);
        let list: any[] = [];
        if (raw) {
          try { list = JSON.parse(raw); } catch (_) { list = []; }
        }
        const newList = list.filter((i: any) => i.id !== scanId);
        await env.SCANNER_KV.put(key, JSON.stringify(newList), { expirationTtl: 3600 });
        return Response.json({ success: true, removed: list.length !== newList.length }, { status: 200, headers: corsHeaders });
      } catch (error: any) {
        return Response.json({ success: false, error: error.message }, { status: 500, headers: corsHeaders });
      }
    }

    // POST /api/queue/embed/process (Process queued embeddings)
    if (url.pathname === '/api/queue/embed/process' && request.method === 'POST') {
      try {
        const q = url.searchParams.get('batch') || '10';
        const batch = Math.min(50, parseInt(q));

        // Read raw queue, take a slice, write remaining back
        if (!env.EMBED_QUEUE) return Response.json({ success: false, error: 'EMBED_QUEUE not configured' }, { status: 500, headers: corsHeaders });
        const key = 'embed:queue';
        const raw = await env.EMBED_QUEUE.get(key);
        let list: string[] = [];
        if (raw) {
          try { list = JSON.parse(raw); } catch (_) { list = []; }
        }
        if (!list.length) return Response.json({ success: true, processed: 0, results: [] }, { headers: corsHeaders });
        const take = list.slice(0, batch);
        const remain = list.slice(take.length);
        // Try to update KV; if KV put fails (quota), fallback to processing DB queue instead
        let kvPutOk = false;
        try {
          await env.EMBED_QUEUE.put(key, JSON.stringify(remain));
          kvPutOk = true;
        } catch (putErr) {
          console.warn('KV put failed in processor, will fallback to DB queue', putErr);
          kvPutOk = false;
        }

        const results: any[] = [];
        // If KV update failed, read from DB queue instead
        let processIds: string[] = take;
        if (!kvPutOk) {
          // Read pending items from D1 EMBED_QUEUE
          try {
            await env.DB.prepare(`CREATE TABLE IF NOT EXISTS EMBED_QUEUE (id INTEGER PRIMARY KEY AUTOINCREMENT, event_id TEXT, queued_at DATETIME DEFAULT CURRENT_TIMESTAMP, processed INTEGER DEFAULT 0)`).run();
            const qrows = await env.DB.prepare('SELECT id, event_id FROM EMBED_QUEUE WHERE processed = 0 ORDER BY queued_at ASC LIMIT ?').bind(batch).all();
            const qlist = qrows.results || qrows;
            processIds = qlist.map((r: any) => r.event_id);
            // Mark them processed (so they won't be picked again)
            for (const r of qlist) {
              await env.DB.prepare('UPDATE EMBED_QUEUE SET processed = 1 WHERE id = ?').bind(r.id).run();
            }
            // If DB fallback returned nothing, fall back to the KV 'take' slice so we still make progress
            if (!processIds.length) {
              processIds = take;
            }
          } catch (dbqErr) {
            console.warn('Failed to read from DB EMBED_QUEUE fallback', dbqErr);
            processIds = take;
          }
        }

        for (const eventId of processIds) {
          try {
            const row = await env.DB.prepare('SELECT * FROM AI_EVENTS WHERE event_id = ?').bind(eventId).first();
            if (!row) {
              results.push({ eventId, status: 'missing_event' });
              continue;
            }
            const narrative = row.narrative;
            let metadata: any = {};
            if (row.metadata) {
              if (typeof row.metadata === 'string') {
                try { metadata = JSON.parse(row.metadata); } catch (_) { metadata = {}; }
              } else if (typeof row.metadata === 'object') {
                metadata = row.metadata;
              }
            }
            try {
              const embeddingResponse = await (env.AI as any).run('@cf/baai/bge-m3', { text: narrative }) as any;
              const embedding = embeddingResponse.result?.data?.[0]?.embedding || embeddingResponse.data?.[0];
              await env.VECTORIZE.upsert([{ id: eventId, values: embedding, metadata: { narrative, ...metadata } }]);
              results.push({ eventId, status: 'embedded' });
            } catch (embedErr) {
              console.warn('embed process error for', eventId, embedErr);
              // On embed failure, push back to queue for retry
              await enqueueEmbedding(env, eventId);
              results.push({ eventId, status: 'embed_failed', error: String(embedErr) });
            }
          } catch (e) {
            results.push({ eventId, status: 'error', error: String(e) });
          }
        }
        return Response.json({ success: true, processed: results.length, results }, { headers: corsHeaders });
      } catch (e: any) {
        return Response.json({ success: false, error: e.message }, { status: 500, headers: corsHeaders });
      }
    }

    // GET /api/queue/embed/raw (DEBUG) - return raw queue contents
    if (url.pathname === '/api/queue/embed/raw' && request.method === 'GET') {
      try {
        if (!env.EMBED_QUEUE) return Response.json({ success: false, error: 'EMBED_QUEUE not configured' }, { status: 500, headers: corsHeaders });
        const key = 'embed:queue';
        const raw = await env.EMBED_QUEUE.get(key);
        let list: string[] = [];
        if (raw) {
          try { list = JSON.parse(raw); } catch (_) { list = []; }
        }
        return Response.json({ success: true, count: list.length, items: list.slice(0, 200) }, { headers: corsHeaders });
      } catch (e: any) {
        return Response.json({ success: false, error: e.message }, { status: 500, headers: corsHeaders });
      }
    }

    // POST /api/queue/embed/dequeue_debug (DEBUG) - call dequeueEmbeddingBatch and return its output
    if (url.pathname === '/api/queue/embed/dequeue_debug' && request.method === 'POST') {
      try {
        const body = (await request.json().catch(() => ({}))) as any;
        const batch = (body?.batch as number) || 10;
        const ids = await dequeueEmbeddingBatch(env, batch);
        return Response.json({ success: true, dequeued: ids.length, ids }, { headers: corsHeaders });
      } catch (e: any) {
        return Response.json({ success: false, error: e.message }, { status: 500, headers: corsHeaders });
      }
    }

    // POST /api/queue/embed/reindex (Process AI_EVENTS directly by event_type)
    if (url.pathname === '/api/queue/embed/reindex' && request.method === 'POST') {
      try {
        const q = url.searchParams.get('batch') || '500';
        const batch = Math.min(1000, parseInt(q));
        const body = (await request.json().catch(() => ({}))) as any;
        const filterType = (body?.event_type as string) || 'product_added';

        // Instead of performing many AI/Vectorize subrequests in one Worker invocation (which
        // can hit Cloudflare's subrequest limits), enqueue the matching event IDs into
        // the EMBED_QUEUE KV and let the queue processor handle embedding in safe batches.
        const rows = await env.DB.prepare('SELECT event_id FROM AI_EVENTS WHERE event_type = ? ORDER BY created_at ASC LIMIT ?').bind(filterType, batch).all();
        const list = (rows.results || rows) as any[];
        const results: any[] = [];
        for (const row of list) {
          try {
            if (row.event_id) {
              await enqueueEmbedding(env, String(row.event_id));
              results.push({ eventId: row.event_id, status: 'queued' });
            } else {
              results.push({ eventId: null, status: 'missing_event_id' });
            }
          } catch (e: any) {
            results.push({ eventId: row.event_id, status: 'error', error: String(e) });
          }
        }
        return Response.json({ success: true, processed: results.length, results }, { headers: corsHeaders });
      } catch (e: any) {
        return Response.json({ success: false, error: e.message }, { status: 500, headers: corsHeaders });
      }
    }

    // POST /api/queue/embed/reindex_process (Process AI_EVENTS in small safe batches and mark them)
    if (url.pathname === '/api/queue/embed/reindex_process' && request.method === 'POST') {
      try {
        const body = (await request.json().catch(() => ({}))) as any;
        const filterType = (body?.event_type as string) || 'product_added';
        const batch = Math.max(1, Math.min(20, parseInt(String((body?.batch as string) || '5'))));

        // Ensure AI_EVENTS has embedded_at column
        try {
          await env.DB.prepare('ALTER TABLE AI_EVENTS ADD COLUMN embedded_at DATETIME').run();
        } catch (_) { /* ignore if already exists */ }

        const rows = await env.DB.prepare('SELECT event_id, narrative, metadata FROM AI_EVENTS WHERE event_type = ? AND (embedded_at IS NULL) ORDER BY created_at ASC LIMIT ?').bind(filterType, batch).all();
        const list = rows.results || rows;
        const results: any[] = [];
        for (const row of list) {
          try {
            const narrative = row.narrative;
            let metadata: any = {};
            if (row.metadata) {
              if (typeof row.metadata === 'string') {
                try { metadata = JSON.parse(row.metadata); } catch (_) { metadata = {}; }
              } else if (typeof row.metadata === 'object') metadata = row.metadata;
            }
            try {
              const embeddingResponse = await (env.AI as any).run('@cf/baai/bge-m3', { text: narrative }) as any;
              const embedding = embeddingResponse.result?.data?.[0]?.embedding || embeddingResponse.data?.[0];
              await env.VECTORIZE.upsert([{ id: String(row.event_id), values: embedding, metadata: { narrative, ...metadata } }]);
              // mark embedded
              try { await env.DB.prepare('UPDATE AI_EVENTS SET embedded_at = CURRENT_TIMESTAMP WHERE event_id = ?').bind(row.event_id).run(); } catch (_) {}
              results.push({ eventId: row.event_id, status: 'embedded' });
            } catch (embedErr) {
              console.warn('Reindex_process embed error for', row.event_id, embedErr);
              results.push({ eventId: row.event_id, status: 'error', error: String(embedErr) });
            }
          } catch (e: any) {
            results.push({ eventId: row.event_id, status: 'error', error: String(e) });
          }
        }
        return Response.json({ success: true, processed: results.length, results }, { headers: corsHeaders });
      } catch (e: any) {
        return Response.json({ success: false, error: e.message }, { status: 500, headers: corsHeaders });
      }
    }

    // GET /api/ai_events/unembedded_count - return count and sample IDs
    if (url.pathname === '/api/ai_events/unembedded_count' && request.method === 'GET') {
      try {
        const sampleLimit = parseInt(url.searchParams.get('sample') || '20');
        const countRes = await env.DB.prepare('SELECT COUNT(1) as c FROM AI_EVENTS WHERE embedded_at IS NULL').first();
        const total = countRes?.c || 0;
        const sampleRows = await env.DB.prepare('SELECT event_id, event_type, created_at FROM AI_EVENTS WHERE embedded_at IS NULL ORDER BY created_at ASC LIMIT ?').bind(sampleLimit).all();
        const items = sampleRows?.results || sampleRows || [];
        return Response.json({ success: true, total, sample: items }, { headers: corsHeaders });
      } catch (err: any) {
        return Response.json({ success: false, error: err.message }, { status: 500, headers: corsHeaders });
      }
    }

    // POST /api/vectorize/sample_check - verify an AI_EVENTS event is discoverable in VECTORIZE
    if (url.pathname === '/api/vectorize/sample_check' && request.method === 'POST') {
      try {
        const body: any = await request.json().catch(() => ({}));
        const eventId = body?.event_id;
        if (!eventId) return Response.json({ success: false, error: 'Missing event_id' }, { status: 400, headers: corsHeaders });

        const row = await env.DB.prepare('SELECT narrative FROM AI_EVENTS WHERE event_id = ?').bind(eventId).first();
        if (!row || !row.narrative) return Response.json({ success: false, error: 'Event not found or has no narrative' }, { status: 404, headers: corsHeaders });

        const narrative = row.narrative;
        // compute embedding and query VECTORIZE
        try {
          const embeddingResponse = await (env.AI as any).run('@cf/baai/bge-m3', { text: narrative }) as any;
          const embedding = embeddingResponse.result?.data?.[0]?.embedding || embeddingResponse.data?.[0];
          const vectorResults = await env.VECTORIZE.query(embedding, { topK: 5, returnMetadata: true }) as any;
          return Response.json({ success: true, eventId, narrative, vectorResults }, { headers: corsHeaders });
        } catch (ve: any) {
          return Response.json({ success: false, error: 'Vector check failed: ' + String(ve) }, { status: 500, headers: corsHeaders });
        }
      } catch (e: any) {
        return Response.json({ success: false, error: e.message }, { status: 500, headers: corsHeaders });
      }
    }

    // POST /api/scanner/bookmark (Toggle bookmark for a scan)
    if (url.pathname === '/api/scanner/bookmark' && request.method === 'POST') {
      try {
        const body: any = await request.json();
        const { sessionId, scanId, bookmark } = body || {};
        if (!sessionId || !scanId || typeof bookmark !== 'boolean') {
          return Response.json({ success: false, error: 'Missing sessionId, scanId or bookmark' }, { status: 400, headers: corsHeaders });
        }
        const key = 'scan:' + sessionId;
        const raw = await env.SCANNER_KV.get(key);
        let list: any[] = [];
        if (raw) {
          try { list = JSON.parse(raw); } catch (_) { list = []; }
        }
        let changed = false;
        list = list.map((i: any) => {
          if (i.id === scanId) { i.bookmarked = bookmark; changed = true; }
          return i;
        });
        await env.SCANNER_KV.put(key, JSON.stringify(list), { expirationTtl: 3600 });
        return Response.json({ success: true, changed }, { status: 200, headers: corsHeaders });
      } catch (error: any) {
        return Response.json({ success: false, error: error.message }, { status: 500, headers: corsHeaders });
      }
    }
    
    // POST /api/scanner/submit (Save scan to KV)
    if (url.pathname.startsWith("/scanner/") && request.method === "GET") {
      const sessionId = url.pathname.split("/").pop();
      const html = '<!DOCTYPE html>' +
        '<html lang="en">' +
        '<head>' +
        '<meta charset="UTF-8">' +
        '<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">' +
        '<title>POS Web Scanner</title>' +
        '<script src="https://unpkg.com/html5-qrcode"></script>' +
        '<style>' +
        "body { font-family: 'Segoe UI', sans-serif; display: flex; flex-direction: column; align-items: center; gap: 12px; padding: 18px; margin: 0; background: #0f1720; color: #fff; }" +
        "#reader-container { width: 100%; max-width: 520px; padding: 16px; box-sizing: border-box; background: #111827; border-radius: 12px; box-shadow: 0 8px 32px rgba(0,0,0,0.5); text-align: center; }" +
        "#reader { width: 100%; border-radius: 8px; overflow: hidden; }" +
        "#scanned-list { width: 100%; max-width: 520px; display: flex; flex-direction: column; gap: 8px; }" +
        ".scan-card { background: #111827; border-radius: 8px; padding: 12px; display:flex; justify-content:space-between; align-items:center; border: 1px solid rgba(255,255,255,0.04);}" +
        ".scan-code { font-family: monospace; color: #e5e7eb; font-weight:600; }" +
        ".send-btn { background: #06b6d4; color: #062024; padding: 8px 12px; border-radius: 8px; border:none; font-weight:700; cursor:pointer; }" +
        ".sent-badge { color: #22c55e; font-weight:700; }" +
        "h2{margin:0 0 8px 0;}" +
        '</style>' +
        '</head>' +
        '<body>' +
        '<div id="reader-container">' +
        '<h2>Scan Products</h2>' +
        '<div id="reader"></div>' +
        '<p style="color:#9ca3af; font-size:13px; margin-top:8px;">Scan multiple items. Tap Send to push an item to your system.</p>' +
        '</div>' +
        '<div id="scanned-list"></div>' +
        '<script>' +
        'function playBeep(){ try{ const ctx=new (window.AudioContext||window.webkitAudioContext)(); const o=ctx.createOscillator(); const g=ctx.createGain(); o.type="sine"; o.frequency.value=880; g.gain.value=0.05; o.connect(g); g.connect(ctx.destination); o.start(); g.gain.exponentialRampToValueAtTime(0.00001, ctx.currentTime+0.12); setTimeout(()=>{ o.stop(); ctx.close(); },150);}catch(e){} }' +
        'const seen = new Set();' +
        'const scanned = [];' +
        'const listEl = document.getElementById("scanned-list");' +
        'function renderList() {' +
        '  listEl.innerHTML = "";' +
        '  scanned.forEach((item, idx) => {' +
        '    const div = document.createElement("div");' +
        '    div.className = "scan-card";' +
        '    const left = document.createElement("div");' +
        '    left.innerHTML = `<div class="scan-code">${item.code}</div><div style="font-size:12px;color:#94a3b8">${new Date(item.ts).toLocaleString()}</div>`;' +
        '    const right = document.createElement("div");' +
        '    if (item.sent) {' +
        '      right.innerHTML = `<span class="sent-badge">SENT</span>`;' +
        '    } else {' +
        '      const btn = document.createElement("button");' +
        '      btn.className = "send-btn";' +
        '      btn.textContent = "Send";' +
        '      btn.onclick = () => sendItem(idx);' +
        '      right.appendChild(btn);' +
        '    }' +
        '    div.appendChild(left); div.appendChild(right); listEl.appendChild(div);' +
        '  });' +
        '}' +
        'function addLocal(code) {' +
        '  try{ playBeep(); }catch(e){} if (seen.has(code)) return; seen.add(code); const it = { id: null, code, ts: Date.now(), sent: false }; scanned.unshift(it); renderList(); }' +
        'function sendItem(idx) {' +
        '  const it = scanned[idx]; if (!it) return; fetch("' + url.origin + '/api/scanner/submit", { method:"POST", headers:{"Content-Type":"application/json"}, body: JSON.stringify({ sessionId: "' + sessionId + '", code: it.code }) }).then(r=>r.json()).then(j=>{ if (j && j.success) { it.sent = true; it.id = j.item.id; try{ playBeep(); }catch(e){} renderList(); } else { alert("Failed to send: " + (j && j.error ? j.error : JSON.stringify(j))); } }).catch(e=>{ alert("Error: " + e); }); }' +
        'const html5QrCode = new Html5Qrcode("reader");' +
        'const onScanSuccess = (decodedText) => { addLocal(decodedText); };' +
        'const config = { fps: 10, qrbox: { width: 250, height: 250 }, aspectRatio: 1.0 };' +
        'setTimeout(()=>{ html5QrCode.start({ facingMode: "environment" }, config, onScanSuccess).catch(e=>{ console.error("start error", e); alert("Camera error: " + e); }); }, 300);' +
        '</script>' +
        '</body>' +
        '</html>';
      return new Response(html, { headers: { "Content-Type": "text/html" } });
    }
    

    return Response.json({ success: true, message: "Welcome to POS AI Cloudflare API" }, { headers: corsHeaders });
  },
};
