const BASE = '/api/admin';

async function request(method, path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ message: res.statusText }));
    throw new Error(err.message || `HTTP ${res.status}`);
  }
  if (res.status === 204) return null;
  return res.json();
}

export const api = {
  getStats: ()                         => request('GET',   '/stats'),
  listUsers: (params = {})             => {
    const q = new URLSearchParams(params).toString();
    return request('GET', `/users${q ? '?' + q : ''}`);
  },
  getUser:   (id)                      => request('GET',   `/users/${id}`),
  createUser: (data)                   => request('POST',  '/users', data),
  updateUser: (id, data)               => request('PUT',   `/users/${id}`, data),
  enableUser: (id)                     => request('PATCH', `/users/${id}/enable`),
  disableUser: (id)                    => request('PATCH', `/users/${id}/disable`),
  resetPassword: (id, newPassword)     => request('PATCH', `/users/${id}/reset-password`, { newPassword }),
  deleteUser: (id)                     => request('DELETE',`/users/${id}`),
};
