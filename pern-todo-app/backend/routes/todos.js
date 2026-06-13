import { Router } from "express";
import pool from "../db.js";

const router = Router();

// Create a new todo
router.post("/", async (req, res) => {
  try {
    const { description, completed } = req.body;
    if (!description) {
      return res.status(400).json({ error: "Description is required" });
    }
    // FIXED: Changed table name to 'todos'
    const newTodo = await pool.query(
      "INSERT INTO todos (description, completed) VALUES ($1, $2) RETURNING *",
      [description, completed || false]
    );
    res.json(newTodo.rows[0]);
  } catch (err) {
    console.error("❌ POST Error:", err.message);
    res.status(500).json({ error: "Server Error" });
  }
});

// Get all todos
router.get("/", async (req, res) => {
  try {
    // FIXED: Changed table name to 'todos'
    const allTodos = await pool.query("SELECT * FROM todos ORDER BY todo_id ASC");
    res.json(allTodos.rows);
  } catch (err) {
    console.error("❌ GET Error:", err.message);
    res.status(500).json({ error: "Server Error" });
  }
});

// Update a todo
router.put("/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { description, completed } = req.body;
    
    // FIXED: Changed table name to 'todos'
    const updatedTodo = await pool.query(
      "UPDATE todos SET description = $1, completed = $2 WHERE todo_id = $3 RETURNING *",
      [description, completed || false, id]
    );
    
    if (updatedTodo.rows.length === 0) {
      return res.status(404).json({ error: "Todo not found" });
    }
    res.json({
      message: "Todo was updated!",
      todo: updatedTodo.rows[0],
    });
  } catch (err) {
    console.error("❌ PUT Error:", err.message);
    res.status(500).json({ error: "Server Error" });
  }
});

// Delete a todo
router.delete("/:id", async (req, res) => {
  try {
    const { id } = req.params;
    // FIXED: Changed table name to 'todos'
    const deletedTodo = await pool.query(
      "DELETE FROM todos WHERE todo_id = $1 RETURNING *",
      [id]
    );
    
    if (deletedTodo.rows.length === 0) {
      return res.status(404).json({ error: "Todo not found" });
    }
    res.json({ message: "Todo was deleted!" });
  } catch (err) {
    console.error("❌ DELETE Error:", err.message);
    res.status(500).json({ error: "Server Error" });
  }
});

export default router;