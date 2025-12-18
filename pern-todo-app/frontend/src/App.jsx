import { useEffect, useState } from "react";
import axios from "axios";
import { MdModeEditOutline, MdOutlineDone } from "react-icons/md";
import { FaTrash } from "react-icons/fa6";
import { IoClose } from "react-icons/io5";
import { API_URL } from "./api.js";

function App() {
  const [description, setDescription] = useState("");
  const [todos, setTodos] = useState([]); // Initialized as array
  const [editingTodo, setEditingTodo] = useState(null);
  const [editedText, setEditedText] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const getTodos = async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await axios.get(`${API_URL}/todos`);
      
      // CRITICAL FIX: Ensure res.data is actually an array before setting state
      if (Array.isArray(res.data)) {
        setTodos(res.data);
      } else {
        console.error("Data received is not an array:", res.data);
        setError("Invalid data format received from server.");
        setTodos([]); // Reset to empty array to prevent .map crash
      }
    } catch (err) {
      console.error("Fetch error:", err.message);
      setError("Cannot connect to the server. Is the backend running on port 5000?");
      setTodos([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    getTodos();
  }, []);

  // ... (Rest of your functions: onSubmitForm, saveEdit, deleteTodo, toggleCompleted remain the same)
  const onSubmitForm = async (e) => {
    e.preventDefault();
    if (!description.trim()) return;
    try {
      setError(null);
      const res = await axios.post(`${API_URL}/todos`, {
        description: description.trim(),
        completed: false,
      });
      setTodos([...todos, res.data]);
      setDescription("");
    } catch (err) {
      console.error(err.message);
      setError("Failed to add todo.");
    }
  };

  const saveEdit = async (id) => {
    try {
      setError(null);
      const trimmedText = editedText.trim();
      await axios.put(`${API_URL}/todos/${id}`, { description: trimmedText });
      setEditingTodo(null);
      setTodos(todos.map((todo) => todo.todo_id === id ? { ...todo, description: trimmedText } : todo));
    } catch (err) { setError("Failed to update."); }
  };

  const deleteTodo = async (id) => {
    try {
      await axios.delete(`${API_URL}/todos/${id}`);
      setTodos(todos.filter((todo) => todo.todo_id !== id));
    } catch (err) { setError("Failed to delete."); }
  };

  const toggleCompleted = async (id) => {
    try {
      const todo = todos.find((t) => t.todo_id === id);
      await axios.put(`${API_URL}/todos/${id}`, { ...todo, completed: !todo.completed });
      setTodos(todos.map((t) => t.todo_id === id ? { ...t, completed: !t.completed } : t));
    } catch (err) { setError("Failed to toggle status."); }
  };

  return (
    <div className="min-h-screen bg-gray-800 flex justify-center items-center p-4">
      <div className="bg-gray-50 rounded-2xl shadow-xl w-full max-w-lg p-8">
        <h1 className="text-4xl font-bold text-gray-800 mb-8 text-center">PERN TODO</h1>
        
        {error && (
          <div className="bg-red-100 border-l-4 border-red-500 text-red-700 p-4 mb-4 shadow-sm rounded">
            <strong>Error:</strong> {error}
          </div>
        )}

        <form onSubmit={onSubmitForm} className="flex items-center gap-2 border p-2 rounded-lg mb-6 bg-white shadow-sm">
          <input
            className="flex-1 outline-none px-3 py-2 text-gray-700"
            type="text"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Add a new task..."
            required
          />
          <button className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md transition-colors">
            Add
          </button>
        </form>

        <div>
          {loading ? (
            <p className="text-center text-gray-500 italic">Loading tasks...</p>
          ) : !Array.isArray(todos) || todos.length === 0 ? (
            <p className="text-center text-gray-400">No tasks found. Get started by adding one!</p>
          ) : (
            <div className="space-y-4">
              {todos.map((todo) => (
                <div key={todo.todo_id} className="group border-b border-gray-100 pb-3 last:border-0">
                  {editingTodo === todo.todo_id ? (
                    <div className="flex gap-2">
                      <input
                        className="flex-1 p-2 border rounded outline-blue-500"
                        value={editedText}
                        onChange={(e) => setEditedText(e.target.value)}
                        autoFocus
                      />
                      <button onClick={() => saveEdit(todo.todo_id)} className="p-2 bg-green-500 text-white rounded"><MdOutlineDone /></button>
                      <button onClick={() => setEditingTodo(null)} className="p-2 bg-gray-400 text-white rounded"><IoClose /></button>
                    </div>
                  ) : (
                    <div className="flex justify-between items-center">
                      <div className="flex items-center gap-3">
                        <button 
                          onClick={() => toggleCompleted(todo.todo_id)}
                          className={`h-5 w-5 rounded-full border-2 flex items-center justify-center transition-all ${todo.completed ? 'bg-green-500 border-green-500' : 'border-gray-300'}`}
                        >
                          {todo.completed && <MdOutlineDone className="text-white text-xs" />}
                        </button>
                        <span className={`${todo.completed ? "line-through text-gray-400" : "text-gray-700"}`}>
                          {todo.description}
                        </span>
                      </div>
                      <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                        <button onClick={() => { setEditingTodo(todo.todo_id); setEditedText(todo.description); }} className="p-2 text-blue-500 hover:bg-blue-50 rounded"><MdModeEditOutline /></button>
                        <button onClick={() => deleteTodo(todo.todo_id)} className="p-2 text-red-500 hover:bg-red-50 rounded"><FaTrash /></button>
                      </div>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default App;