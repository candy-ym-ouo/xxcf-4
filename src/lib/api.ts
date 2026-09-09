const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:8787/api/v1';

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const response = await fetch(`${API_BASE}${path}`, { credentials: 'include', headers: { 'content-type': 'application/json', ...(init.headers || {}) }, ...init });
  if (!response.ok) throw new Error((await response.json().catch(() => null))?.error?.message || `API ${response.status}`);
  return response.json();
}

export const api = {
  login: (email: string, password: string) => request<{ user: { id: string; name: string; email: string } }>('/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) }),
  items: () => request<{ data: any[] }>('/items'),
  createItem: (body: any) => request<any>('/items', { method: 'POST', body: JSON.stringify(body) }),
  createRecord: (itemId: string, body: any) => request<any>(`/items/${itemId}/records`, { method: 'POST', body: JSON.stringify(body) }),
  reminders: () => request<any[]>('/reminders'),
  completeReminder: (id: string) => request<any>(`/reminders/${id}/complete`, { method: 'POST', body: JSON.stringify({ createRecord: true }) }),
};
