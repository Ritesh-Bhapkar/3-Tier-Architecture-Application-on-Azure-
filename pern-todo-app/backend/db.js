import pkg from 'pg';
const { Pool } = pkg;
import dotenv from "dotenv";
dotenv.config();

// Use the connection string provided by Azure Bicep
const isProduction = process.env.NODE_ENV === "production";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: isProduction 
    ? { rejectUnauthorized: false } // Required for Azure Flexible Server
    : false,
});

// Log connection status for Azure Log Analytics
pool.on('connect', () => {
  console.log("✅ Database Connected successfully");
});

pool.on('error', (err) => {
  console.error("❌ Unexpected error on idle client", err);
});

export default pool;