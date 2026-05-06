import { useState, useEffect } from 'react';
import { api } from '../api/adminApi';

function StatCard({ icon, label, value, sub, accent }) {
  return (
    <div className="card stat-card">
      <div className="stat-icon">{icon}</div>
      <div className="stat-label">{label}</div>
      <div className="stat-value" style={accent ? { color: accent } : {}}>{value ?? '—'}</div>
      {sub && <div className="stat-sub">{sub}</div>}
    </div>
  );
}

export function Dashboard() {
  const [stats, setStats]   = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError]   = useState('');

  useEffect(() => {
    api.getStats()
      .then(setStats)
      .catch(e => setError(e.message))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <div className="page-loading"><div className="spinner" /> Loading…</div>;
  if (error)   return <div className="page-error">Failed to load stats: {error}</div>;

  return (
    <div>
      <div className="stats-grid">
        <StatCard icon="👥" label="Total Users"    value={stats.total}        />
        <StatCard icon="✅" label="Active"          value={stats.enabled}      accent="var(--green)"  sub={`${stats.total ? Math.round(stats.enabled / stats.total * 100) : 0}% of total`} />
        <StatCard icon="🚫" label="Disabled"        value={stats.disabled}     accent="var(--red)"    />
        <StatCard icon="📅" label="New Today"       value={stats.newToday}     accent="var(--primary)" />
        <StatCard icon="📆" label="This Week"       value={stats.newThisWeek}  />
        <StatCard icon="🗓" label="This Month"      value={stats.newThisMonth} />
      </div>

      <div className="card" style={{ padding: '20px 24px' }}>
        <h2 style={{ marginBottom: 8 }}>Quick actions</h2>
        <p style={{ color: 'var(--text3)', fontSize: 13, lineHeight: 1.6 }}>
          Go to <strong>Users</strong> to search, create, edit or disable accounts.
          Use the search bar to find a user by name, email or username instantly.
        </p>
      </div>
    </div>
  );
}
