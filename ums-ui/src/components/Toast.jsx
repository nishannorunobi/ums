import { useState, useCallback, useRef } from 'react';

let _push = null;

export function useToast() {
  return { toast: (msg, type = 'info') => _push?.(msg, type) };
}

export function ToastProvider() {
  const [toasts, setToasts] = useState([]);
  const id = useRef(0);

  _push = useCallback((message, type = 'info') => {
    const key = ++id.current;
    setToasts(t => [...t, { key, message, type }]);
    setTimeout(() => setToasts(t => t.filter(x => x.key !== key)), 4000);
  }, []);

  if (!toasts.length) return null;

  return (
    <div className="toast-root">
      {toasts.map(t => (
        <div key={t.key} className={`toast toast-${t.type}`}>
          <span className="toast-msg">{t.message}</span>
          <button className="toast-close" onClick={() => setToasts(ts => ts.filter(x => x.key !== t.key))}>✕</button>
        </div>
      ))}
    </div>
  );
}
