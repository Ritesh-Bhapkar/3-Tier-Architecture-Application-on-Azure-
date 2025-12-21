import pkg from 'pg';
const { Pool } = pkg;
import dotenv from "dotenv";
dotenv.config();

// Ensure we identify production for SSL requirements
const isProduction = process.env.NODE_ENV === "production";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: isProduction 
    ? { rejectUnauthorized: false } // Mandatory for Azure PostgreSQL Flexible Server
    : false,
});

// AUTO-SCHEMA CREATION
const initDb = async () => {
  const queryText = `
    CREATE TABLE IF NOT EXISTS todos (
      todo_id SERIAL PRIMARY KEY,
      description TEXT NOT NULL,
      completed BOOLEAN DEFAULT false
    );
  `;
  try {
    const client = await pool.connect();
    await client.query(queryText);
    console.log("✅ Database Schema Verified/Created (Table: todos)");
    client.release();
  } catch (err) {
    console.error("❌ Error initializing database:", err);
  }
};

// Run the initialization on startup
initDb();

pool.on('connect', () => {
  console.log("✅ Database Connected successfully");
});

pool.on('error', (err) => {
  console.error("❌ Unexpected error on idle client", err);
});

export default pool;