import express from "express";
import cors from "cors";
import todoRoutes from "./routes/todos.js";
import dotenv from "dotenv";
dotenv.config();

const PORT = process.env.PORT || 5000;
const app = express();

// --- DYNAMIC CORS FOR AZURE & LOCAL ---
const allowedOrigins = [
  "http://localhost:5173",            // Local Vite
  process.env.FRONTEND_URL            // This will be your Azure App URL
].filter(Boolean); // Removes undefined if FRONTEND_URL isn't set yet

app.use(cors({
  origin: function (origin, callback) {
    if (!origin) return callback(null, true);
    if (allowedOrigins.indexOf(origin) !== -1 || process.env.NODE_ENV !== "production") {
      callback(null, true);
    } else {
      callback(new Error("CORS Error: Origin not allowed"));
    }
  }
}));

app.use(express.json());
app.use("/todos", todoRoutes);

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});