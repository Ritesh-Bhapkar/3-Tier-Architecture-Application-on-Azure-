import express from "express";
import cors from "cors";
import todoRoutes from "./routes/todos.js";
import dotenv from "dotenv";
import pool from "./db.js"; // Ensure your db.js is imported to trigger initDb()

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

// 1. SIMPLE CORS: Since Nginx handles the proxy, a simple cors() 
// prevents "Origin not allowed" crashes that cause 502 errors.
app.use(cors());

// 2. PARSE JSON: Required to read the "description" from your frontend POST requests.
app.use(express.json());

// 3. ROUTES: This points "/todos" to your routes/todos.js file.
// Because the table you created is "todos" (plural), your routes must match.
app.use("/todos", todoRoutes);

// 4. HEALTH CHECK: Useful for Azure to know your container is healthy.
app.get("/health", (req, res) => {
  res.status(200).send("Backend is healthy and connected");
});

// 5. ERROR HANDLING: Prevents the server from crashing on database errors.
// A crash here results in the "502 Bad Gateway" you are seeing.
app.use((err, req, res, next) => {
  console.error("❌ Server Error:", err.stack);
  res.status(500).json({ error: "Internal Server Error" });
});

app.listen(PORT, () => {
  console.log(`✅ Server is running on port ${PORT}`);
  console.log(`🚀 Database URL is configured: ${process.env.DATABASE_URL ? 'YES' : 'NO'}`);
});