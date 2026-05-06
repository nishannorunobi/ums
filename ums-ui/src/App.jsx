import { useState } from 'react';
import { Dashboard } from './pages/Dashboard';
import { Users }     from './pages/Users';
import { ToastProvider } from './components/Toast';

const NAV = [
  { id: 'dashboard', icon: '📊', label: 'Dashboard' },
  { id: 'users',     icon: '👥', label: 'Users'     },
];

const PAGE_TITLE = {
  dashboard: { title: 'Dashboard',    sub: 'Overview & stats'          },
  users:     { title: 'Users',        sub: 'Search, manage & support'  },
};

export default function App() {
  const [page, setPage] = useState('dashboard');
  const { title, sub }  = PAGE_TITLE[page];

  return (
    <div className="shell">
      {/* Sidebar */}
      <aside className="sidebar">
        <div className="sidebar-logo">
          <div className="sidebar-logo-mark">U</div>
          <div>
            <div className="sidebar-logo-text">UMS Admin</div>
            <div className="sidebar-logo-sub">Customer Support</div>
          </div>
        </div>

        <div className="sidebar-section">Menu</div>
        <nav>
          {NAV.map(n => (
            <button key={n.id} className={`nav-item ${page === n.id ? 'active' : ''}`}
              onClick={() => setPage(n.id)}>
              <span className="nav-icon">{n.icon}</span>
              {n.label}
            </button>
          ))}
        </nav>

        <div className="sidebar-footer">
          UMS v1.0 · Admin Panel
        </div>
      </aside>

      {/* Main */}
      <div className="main">
        <header className="topbar">
          <div>
            <span className="topbar-title">{title}</span>
            {sub && <span className="topbar-sub"> — {sub}</span>}
          </div>
          <div className="topbar-actions">
            <span style={{ fontSize: 12, color: 'var(--text3)' }}>
              {new Date().toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}
            </span>
          </div>
        </header>

        <main className="content">
          {page === 'dashboard' && <Dashboard />}
          {page === 'users'     && <Users />}
        </main>
      </div>

      <ToastProvider />
    </div>
  );
}
