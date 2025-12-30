// --- SRE MONITORING START (MUST BE FIRST LINE) ---
import appInsights from "applicationinsights";
// This automatically finds the connection string we added in Bicep
appInsights.setup().start(); 
// --- SRE MONITORING END ---

import express from "express";
import cors from "cors";
import todoRoutes from "./routes/todos.js";
import dotenv from "dotenv";
import pool from "./db.js";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

// Points "/todos" to your routes
app.use("/todos", todoRoutes);

// Health Check for Azure
app.get("/health", (req, res) => {
  res.status(200).send("Backend is healthy and connected");
});

// Error Handling to prevent 502 Bad Gateway
app.use((err, req, res, next) => {
  console.error("❌ Server Error:", err.stack);
  res.status(500).json({ error: "Internal Server Error" });
});

app.listen(PORT, () => {
  console.log(`✅ Server is running on port ${PORT}`);
  console.log(`🚀 Database URL configured: ${process.env.DATABASE_URL ? 'YES' : 'NO'}`);
});