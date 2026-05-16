import { useState, useEffect } from 'react';
import { getItems, createItem } from './api.js';
import './App.css';

function App() {
  const [items, setItems] = useState([]);
  const [name, setName] = useState('');
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);

  async function loadItems() {
    try {
      const data = await getItems();
      setItems(data);
      setError(null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadItems();
  }, []);

  async function handleSubmit(e) {
    e.preventDefault();
    if (!name.trim()) return;
    try {
      await createItem(name.trim());
      setName('');
      await loadItems();
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <div className="app">
      <h1><<PROJECT_TITLE>></h1>
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="New item name"
          maxLength={200}
        />
        <button type="submit">Add Item</button>
      </form>
      {error && <p className="error">{error}</p>}
      {loading ? (
        <p>Loading...</p>
      ) : (
        <ul className="items-list">
          {items.map((item) => (
            <li key={item.id}>
              <span className="item-name">{item.name}</span>
              <span className="item-date">
                {new Date(item.created_at).toLocaleDateString()}
              </span>
            </li>
          ))}
          {items.length === 0 && (
            <li className="empty">No items yet. Add one above.</li>
          )}
        </ul>
      )}
    </div>
  );
}

export default App;
