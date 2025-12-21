import pkg from 'pg';
const { Pool } = pkg;
import dotenv from "dotenv";
dotenv.config();

const isProduction = process.env.NODE_ENV === "production";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: isProduction ? { rejectUnauthorized: false } : false,
});

const initDb = async () => {
  // FIXED: Using 'todos' (plural) to match your frontend network calls
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
    console.log("✅ Database Schema Verified/Created (todos)");
    client.release();
  } catch (err) {
    console.error("❌ Error initializing database:", err);
  }
};

initDb();

pool.on('connect', () => {
  console.log("✅ Database Connected successfully");
});

export default pool;