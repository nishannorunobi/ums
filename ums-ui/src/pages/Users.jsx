import { useState, useEffect, useCallback, useRef } from 'react';
import { api } from '../api/adminApi';
import { UserModal } from '../components/UserModal';
import { ResetPasswordModal } from '../components/ResetPasswordModal';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { useToast } from '../components/Toast';

function Avatar({ user }) {
  const initials = [user.firstName, user.lastName]
    .filter(Boolean).map(s => s[0].toUpperCase()).join('') || user.username[0].toUpperCase();
  return <div className="avatar">{initials}</div>;
}

const PAGE_SIZE = 20;

export function Users() {
  const { toast } = useToast();

  const [data, setData]           = useState({ users: [], total: 0, totalPages: 0 });
  const [loading, setLoading]     = useState(true);
  const [search, setSearch]       = useState('');
  const [page, setPage]           = useState(0);
  const [sortBy, setSortBy]       = useState('createdAt');
  const [sortDir, setSortDir]     = useState('desc');

  const [modal, setModal]         = useState(null); // null | 'create' | 'edit' | 'reset' | 'delete' | 'toggle'
  const [selected, setSelected]   = useState(null);

  const searchTimer = useRef(null);

  const load = useCallback(async (p = page, q = search, sb = sortBy, sd = sortDir) => {
    setLoading(true);
    try {
      const res = await api.listUsers({ page: p, size: PAGE_SIZE, search: q, sortBy: sb, sortDir: sd });
      setData(res);
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setLoading(false);
    }
  }, [page, search, sortBy, sortDir]);  // eslint-disable-line

  useEffect(() => { load(page, search, sortBy, sortDir); }, [page, sortBy, sortDir]); // eslint-disable-line

  function handleSearch(v) {
    setSearch(v);
    clearTimeout(searchTimer.current);
    searchTimer.current = setTimeout(() => { setPage(0); load(0, v, sortBy, sortDir); }, 350);
  }

  function toggleSort(col) {
    if (sortBy === col) { const d = sortDir === 'asc' ? 'desc' : 'asc'; setSortDir(d); load(page, search, col, d); }
    else { setSortBy(col); setSortDir('asc'); load(page, search, col, 'asc'); }
  }

  function sortIcon(col) {
    if (sortBy !== col) return <span style={{ color: 'var(--border2)', marginLeft: 4 }}>⇅</span>;
    return <span style={{ color: 'var(--primary)', marginLeft: 4 }}>{sortDir === 'asc' ? '↑' : '↓'}</span>;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  async function handleCreate(form) {
    try {
      await api.createUser(form);
      toast('User created', 'success');
      setModal(null);
      load(0, search, sortBy, sortDir);
      setPage(0);
    } catch (e) { toast(e.message, 'error'); throw e; }
  }

  async function handleUpdate(form) {
    try {
      await api.updateUser(selected.id, form);
      toast('User updated', 'success');
      setModal(null);
      load(page, search, sortBy, sortDir);
    } catch (e) { toast(e.message, 'error'); throw e; }
  }

  async function handleResetPassword(pw) {
    try {
      await api.resetPassword(selected.id, pw);
      toast('Password reset', 'success');
      setModal(null);
    } catch (e) { toast(e.message, 'error'); throw e; }
  }

  async function handleToggle() {
    const action = selected.enabled ? api.disableUser : api.enableUser;
    try {
      await action(selected.id);
      toast(`User ${selected.enabled ? 'disabled' : 'enabled'}`, 'success');
      setModal(null);
      load(page, search, sortBy, sortDir);
    } catch (e) { toast(e.message, 'error'); }
  }

  async function handleDelete() {
    try {
      await api.deleteUser(selected.id);
      toast('User deleted', 'success');
      setModal(null);
      const newPage = data.users.length === 1 && page > 0 ? page - 1 : page;
      setPage(newPage);
      load(newPage, search, sortBy, sortDir);
    } catch (e) { toast(e.message, 'error'); }
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  const start = page * PAGE_SIZE + 1;
  const end   = Math.min((page + 1) * PAGE_SIZE, data.total);

  return (
    <div>
      {/* Toolbar */}
      <div className="toolbar">
        <div className="search-wrap">
          <span className="search-icon">🔍</span>
          <input className="input search-input" placeholder="Search by name, email or username…"
            value={search} onChange={e => handleSearch(e.target.value)} />
        </div>
        <button className="btn btn-primary" onClick={() => { setSelected(null); setModal('create'); }}>
          + New user
        </button>
      </div>

      {/* Table */}
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th className="sortable" onClick={() => toggleSort('username')}>User {sortIcon('username')}</th>
              <th className="sortable" onClick={() => toggleSort('phoneNumber')}>Phone {sortIcon('phoneNumber')}</th>
              <th className="sortable" onClick={() => toggleSort('enabled')}>Status {sortIcon('enabled')}</th>
              <th className="sortable" onClick={() => toggleSort('createdAt')}>Created {sortIcon('createdAt')}</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr className="empty-row">
                <td colSpan={5}><div style={{ display: 'flex', justifyContent: 'center' }}><div className="spinner" /></div></td>
              </tr>
            ) : data.users.length === 0 ? (
              <tr className="empty-row"><td colSpan={5}>No users found</td></tr>
            ) : data.users.map(u => (
              <tr key={u.id}>
                <td>
                  <div className="td-user">
                    <Avatar user={u} />
                    <div>
                      <div className="user-name">{[u.firstName, u.lastName].filter(Boolean).join(' ') || u.username}</div>
                      <div className="user-email">{u.email}</div>
                      <div style={{ fontSize: 11, color: 'var(--text4)' }}>@{u.username}</div>
                    </div>
                  </div>
                </td>
                <td style={{ color: u.phoneNumber ? 'var(--text2)' : 'var(--text4)' }}>
                  {u.phoneNumber || '—'}
                </td>
                <td>
                  <span className={`badge ${u.enabled ? 'badge-green' : 'badge-red'}`}>
                    {u.enabled ? 'Active' : 'Disabled'}
                  </span>
                </td>
                <td style={{ color: 'var(--text3)', fontSize: 13 }}>
                  {u.createdAt ? new Date(u.createdAt).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : '—'}
                </td>
                <td>
                  <div className="actions-cell">
                    <button className="btn btn-ghost btn-sm btn-icon" title="Edit"
                      onClick={() => { setSelected(u); setModal('edit'); }}>✏️</button>
                    <button className="btn btn-ghost btn-sm btn-icon" title="Reset password"
                      onClick={() => { setSelected(u); setModal('reset'); }}>🔑</button>
                    <button className="btn btn-ghost btn-sm btn-icon"
                      title={u.enabled ? 'Disable' : 'Enable'}
                      onClick={() => { setSelected(u); setModal('toggle'); }}>
                      {u.enabled ? '🚫' : '✅'}
                    </button>
                    <button className="btn btn-ghost btn-sm btn-icon" title="Delete"
                      onClick={() => { setSelected(u); setModal('delete'); }}>🗑️</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        {/* Pagination */}
        {data.total > 0 && (
          <div className="pagination">
            <span className="pag-info">
              {data.total === 0 ? 'No results' : `${start}–${end} of ${data.total} users`}
            </span>
            <div className="pag-controls">
              <button className="pag-btn" disabled={page === 0} onClick={() => setPage(0)}>«</button>
              <button className="pag-btn" disabled={page === 0} onClick={() => setPage(p => p - 1)}>‹</button>
              {Array.from({ length: Math.min(data.totalPages, 7) }, (_, i) => {
                const p = Math.max(0, Math.min(page - 3, data.totalPages - 7)) + i;
                return (
                  <button key={p} className={`pag-btn ${p === page ? 'active' : ''}`}
                    onClick={() => setPage(p)}>{p + 1}</button>
                );
              })}
              <button className="pag-btn" disabled={page >= data.totalPages - 1} onClick={() => setPage(p => p + 1)}>›</button>
              <button className="pag-btn" disabled={page >= data.totalPages - 1} onClick={() => setPage(data.totalPages - 1)}>»</button>
            </div>
          </div>
        )}
      </div>

      {/* Modals */}
      {modal === 'create' && (
        <UserModal onSave={handleCreate} onClose={() => setModal(null)} />
      )}
      {modal === 'edit' && selected && (
        <UserModal user={selected} onSave={handleUpdate} onClose={() => setModal(null)} />
      )}
      {modal === 'reset' && selected && (
        <ResetPasswordModal user={selected} onSave={handleResetPassword} onClose={() => setModal(null)} />
      )}
      {modal === 'toggle' && selected && (
        <ConfirmDialog
          title={selected.enabled ? 'Disable user' : 'Enable user'}
          message={<>Are you sure you want to <strong>{selected.enabled ? 'disable' : 'enable'}</strong> the account for <strong>{selected.username}</strong>?</>}
          confirmLabel={selected.enabled ? 'Disable' : 'Enable'}
          danger={selected.enabled}
          onConfirm={handleToggle}
          onCancel={() => setModal(null)}
        />
      )}
      {modal === 'delete' && selected && (
        <ConfirmDialog
          title="Delete user"
          message={<>This will permanently delete <strong>{selected.username}</strong>. This action cannot be undone.</>}
          confirmLabel="Delete"
          danger
          onConfirm={handleDelete}
          onCancel={() => setModal(null)}
        />
      )}
    </div>
  );
}
