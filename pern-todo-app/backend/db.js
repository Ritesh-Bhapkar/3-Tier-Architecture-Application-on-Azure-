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

// AUTO-SCHEMA CREATION: Fixes Add, Update, and Delete automatically
const initDb = async () => {
  const queryText = `
    CREATE TABLE IF NOT EXISTS todo (
      todo_id SERIAL PRIMARY KEY,
      description TEXT NOT NULL,
      completed BOOLEAN DEFAULT false
    );
  `;
  try {
    const client = await pool.connect();
    await client.query(queryText);
    console.log("✅ Database Schema Verified/Created");
    client.release();
  } catch (err) {
    console.error("❌ Error initializing database:", err);
  }
};

// Run the initialization
initDb();

// Log connection status for Azure Log Analytics
pool.on('connect', () => {
  console.log("✅ Database Connected successfully");
});

pool.on('error', (err) => {
  console.error("❌ Unexpected error on idle client", err);
});

export default pool;