-- schema.sql
CREATE TABLE IF NOT EXISTS USERS (
  user_id TEXT PRIMARY KEY,
  name TEXT,
  address TEXT,
  phone_num INTEGER,
  position TEXT,
  team_role TEXT
);

CREATE TABLE IF NOT EXISTS PRODUCTS (
  product_id TEXT PRIMARY KEY,
  product_key TEXT,
  name TEXT,
  category TEXT, -- For semantic search & AI recommendations
  description TEXT, -- For AI embeddings & vector search
  retail_value REAL,
  selling_value REAL,
  active INTEGER, -- 1 for true, 0 for false
  offer_have INTEGER, -- 1 for true, 0 for false
  offer_percentage REAL,
  product_url TEXT,
  created_user TEXT,
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (created_user) REFERENCES USERS(user_id)
);

CREATE TABLE IF NOT EXISTS SUPPLIERS (
  supplier_id TEXT PRIMARY KEY,
  name TEXT,
  email TEXT,
  phone_num TEXT,
  address TEXT,
  total_stock REAL,
  retail_price_total REAL,
  created_user TEXT,
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (created_user) REFERENCES USERS(user_id)
);

CREATE TABLE IF NOT EXISTS STOCKS (
  stock_id TEXT PRIMARY KEY,
  product_id TEXT,
  supplier_id TEXT,
  count INTEGER,
  retail_price REAL,
  selling_price REAL,
  created_user TEXT,
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES PRODUCTS(product_id),
  FOREIGN KEY (supplier_id) REFERENCES SUPPLIERS(supplier_id),
  FOREIGN KEY (created_user) REFERENCES USERS(user_id)
);

CREATE TABLE IF NOT EXISTS LIVE_STOCKS (
  product_id TEXT PRIMARY KEY,
  live_stock_count INTEGER,
  live_selling_count INTEGER,
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES PRODUCTS(product_id)
);

CREATE TABLE IF NOT EXISTS LIVE_PROFIT (
  product_id TEXT PRIMARY KEY,
  total_retail_price REAL,
  total_selling_price REAL,
  total_discount_price REAL,
  total_price REAL,
  total_profit REAL,
  FOREIGN KEY (product_id) REFERENCES PRODUCTS(product_id)
);

CREATE TABLE IF NOT EXISTS CLIENTS (
  client_id TEXT PRIMARY KEY,
  name TEXT,
  email TEXT,
  phone_num TEXT,
  address TEXT,
  total_price REAL,
  profit REAL,
  balance REAL,
  created_user TEXT,
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (created_user) REFERENCES USERS(user_id)
);

CREATE TABLE IF NOT EXISTS SALES (
  sale_id TEXT PRIMARY KEY,
  product_id TEXT,
  quantity INTEGER,
  retail_price REAL,
  selling_price REAL,
  discount_price REAL,
  total_price REAL,
  profit REAL,
  live_selling_count INTEGER,
  created_user TEXT,
  createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
  client_id TEXT,
  FOREIGN KEY (product_id) REFERENCES PRODUCTS(product_id),
  FOREIGN KEY (client_id) REFERENCES CLIENTS(client_id),
  FOREIGN KEY (created_user) REFERENCES USERS(user_id)
);

CREATE TABLE IF NOT EXISTS AI_EVENTS (
  event_id TEXT PRIMARY KEY,
  event_type TEXT, -- 'stock_added', 'daily_profit', 'client_payment', 'low_stock_alert'
  narrative TEXT, -- The human-readable story for AI embeddings
  metadata TEXT, -- JSON: {product_id, amount, date, etc}
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  expires_at DATETIME -- For cleanup of old events
);
