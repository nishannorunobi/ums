import { useState, useEffect } from 'react';

const EMPTY = { username: '', email: '', password: '', firstName: '', lastName: '', phoneNumber: '' };

export function UserModal({ user, onSave, onClose }) {
  const isEdit = Boolean(user);
  const [form, setForm]     = useState(isEdit ? {
    email: user.email || '', firstName: user.firstName || '',
    lastName: user.lastName || '', phoneNumber: user.phoneNumber || '',
  } : { ...EMPTY });
  const [errors, setErrors] = useState({});
  const [saving, setSaving] = useState(false);

  const set = (k, v) => { setForm(f => ({ ...f, [k]: v })); setErrors(e => ({ ...e, [k]: '' })); };

  function validate() {
    const e = {};
    if (!isEdit) {
      if (!form.username?.trim())  e.username = 'Required';
      if (!form.password?.trim())  e.password = 'Required';
    }
    if (!form.email?.trim())       e.email    = 'Required';
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) e.email = 'Invalid email';
    return e;
  }

  async function handleSubmit(e) {
    e.preventDefault();
    const errs = validate();
    if (Object.keys(errs).length) { setErrors(errs); return; }
    setSaving(true);
    try { await onSave(form); }
    finally { setSaving(false); }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <h2 className="modal-title">{isEdit ? 'Edit User' : 'Create User'}</h2>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="modal-body">
            {!isEdit && (
              <div className="form-row">
                <div className="field">
                  <label className="label">Username <span style={{color:'var(--red)'}}>*</span></label>
                  <input className={`input ${errors.username ? 'error' : ''}`} value={form.username}
                    onChange={e => set('username', e.target.value)} placeholder="john_doe" autoFocus />
                  {errors.username && <span className="field-error">{errors.username}</span>}
                </div>
                <div className="field">
                  <label className="label">Password <span style={{color:'var(--red)'}}>*</span></label>
                  <input className={`input ${errors.password ? 'error' : ''}`} type="password"
                    value={form.password} onChange={e => set('password', e.target.value)} placeholder="••••••••" />
                  {errors.password && <span className="field-error">{errors.password}</span>}
                </div>
              </div>
            )}

            <div className="field">
              <label className="label">Email <span style={{color:'var(--red)'}}>*</span></label>
              <input className={`input ${errors.email ? 'error' : ''}`} type="email"
                value={form.email} onChange={e => set('email', e.target.value)} placeholder="john@example.com" />
              {errors.email && <span className="field-error">{errors.email}</span>}
            </div>

            <div className="form-row">
              <div className="field">
                <label className="label">First name</label>
                <input className="input" value={form.firstName}
                  onChange={e => set('firstName', e.target.value)} placeholder="John" />
              </div>
              <div className="field">
                <label className="label">Last name</label>
                <input className="input" value={form.lastName}
                  onChange={e => set('lastName', e.target.value)} placeholder="Doe" />
              </div>
            </div>

            <div className="field">
              <label className="label">Phone number</label>
              <input className="input" value={form.phoneNumber}
                onChange={e => set('phoneNumber', e.target.value)} placeholder="+1 555 000 0000" />
            </div>
          </div>

          <div className="modal-footer">
            <button type="button" className="btn btn-secondary" onClick={onClose}>Cancel</button>
            <button type="submit" className="btn btn-primary" disabled={saving}>
              {saving ? 'Saving…' : (isEdit ? 'Save changes' : 'Create user')}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
