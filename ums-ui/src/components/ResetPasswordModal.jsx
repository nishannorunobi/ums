import { useState } from 'react';

export function ResetPasswordModal({ user, onSave, onClose }) {
  const [password, setPassword]   = useState('');
  const [confirm, setConfirm]     = useState('');
  const [error, setError]         = useState('');
  const [saving, setSaving]       = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    if (!password.trim())         { setError('Password is required'); return; }
    if (password !== confirm)     { setError('Passwords do not match'); return; }
    if (password.length < 6)      { setError('Minimum 6 characters'); return; }
    setSaving(true);
    try { await onSave(password); }
    finally { setSaving(false); }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" style={{ maxWidth: 400 }} onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2 className="modal-title">Reset Password</h2>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="modal-body">
            <p style={{ color: 'var(--text3)', fontSize: 13 }}>
              Setting new password for <strong style={{ color: 'var(--text)' }}>{user.username}</strong>
            </p>
            <div className="field">
              <label className="label">New password</label>
              <input className={`input ${error ? 'error' : ''}`} type="password" autoFocus
                value={password} onChange={e => { setPassword(e.target.value); setError(''); }}
                placeholder="Min. 6 characters" />
            </div>
            <div className="field">
              <label className="label">Confirm password</label>
              <input className={`input ${error ? 'error' : ''}`} type="password"
                value={confirm} onChange={e => { setConfirm(e.target.value); setError(''); }}
                placeholder="Repeat password" />
              {error && <span className="field-error">{error}</span>}
            </div>
          </div>
          <div className="modal-footer">
            <button type="button" className="btn btn-secondary" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn btn-primary" disabled={saving}>
              {saving ? 'Saving…' : 'Reset password'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
