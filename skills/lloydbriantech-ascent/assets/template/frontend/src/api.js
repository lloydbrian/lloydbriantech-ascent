const API_BASE = '/api';

export async function getItems() {
  const res = await fetch(`${API_BASE}/items`);
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error?.message || `Failed to fetch items (${res.status})`);
  }
  const { data } = await res.json();
  return data;
}

export async function createItem(name) {
  const res = await fetch(`${API_BASE}/items`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name }),
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error?.message || `Failed to create item (${res.status})`);
  }
  const { data } = await res.json();
  return data;
}
