'use client';
/** Shared by apps/admin and apps/cms: API client, sign-in, page shell and a few form helpers. */
import { useEffect, useState, type ReactNode } from 'react';

export const API = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:4000';
const KEY = 'zynetix.token';

export class ApiError extends Error {
  constructor(public status: number, public body: any) {
    super(body?.message ?? body?.code ?? `HTTP ${status}`);
  }
}

export async function api<T = any>(path: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  const token = typeof window === 'undefined' ? null : localStorage.getItem(KEY);
  const r = await fetch(`${API}${path}`, {
    method: init.method ?? (init.body === undefined ? 'GET' : 'POST'),
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
  });
  const body = r.headers.get('content-type')?.includes('json') ? await r.json() : await r.text();
  if (r.status === 401 && typeof window !== 'undefined') {
    localStorage.removeItem(KEY);
    location.href = '/login';
  }
  if (!r.ok) throw new ApiError(r.status, body);
  return body as T;
}

/** Loads data for a page; `reload()` after a change. */
export function useApi<T>(path: string | null) {
  const [data, setData] = useState<T>();
  const [error, setError] = useState<string>();
  const [n, setN] = useState(0);
  useEffect(() => {
    if (!path) return;
    api<T>(path).then(setData, (e) => setError(String(e.message)));
  }, [path, n]);
  return { data, error, reload: () => setN((x) => x + 1) };
}

export function errorText(e: unknown): string {
  if (e instanceof ApiError) {
    const b = e.body ?? {};
    return [b.code, ...(b.issues ?? []), ...(b.missing ? [`missing: ${b.missing.join(', ')}`] : []), b.message].filter(Boolean).join(' · ');
  }
  return String(e);
}

export function LoginPage({ product, role }: { product: string; role: string }) {
  const [email, setEmail] = useState(''), [password, setPassword] = useState(''), [err, setErr] = useState('');
  return (
    <main className="login">
      <h1>Zynetix {product}</h1>
      <form
        onSubmit={async (e) => {
          e.preventDefault();
          try {
            const r = await api<{ token: string; staff: { role: string } }>('/v1/auth/login', { body: { email, password } });
            if (r.staff.role !== role && r.staff.role !== 'super') return setErr(`This app is for ${role} accounts.`);
            localStorage.setItem(KEY, r.token);
            location.href = '/';
          } catch (e) {
            setErr(errorText(e));
          }
        }}
      >
        <label>Email<input value={email} onChange={(e) => setEmail(e.target.value)} type="email" required /></label>
        <label>Password<input value={password} onChange={(e) => setPassword(e.target.value)} type="password" required /></label>
        {err && <p className="error">{err}</p>}
        <button type="submit">Sign in</button>
      </form>
    </main>
  );
}

export function Shell({ product, nav, children }: { product: string; nav: [string, string][]; children: ReactNode }) {
  const [path, setPath] = useState('');
  useEffect(() => {
    if (!localStorage.getItem(KEY)) location.href = '/login';
    setPath(location.pathname);
  }, []);
  return (
    <div className="shell">
      <nav>
        <strong>Zynetix {product}</strong>
        {nav.map(([href, label]) => (
          <a key={href} href={href} className={path === href || (href !== '/' && path.startsWith(href)) ? 'active' : ''}>{label}</a>
        ))}
        <button className="link" onClick={() => { localStorage.removeItem(KEY); location.href = '/login'; }}>Sign out</button>
      </nav>
      <main>{children}</main>
    </div>
  );
}

export type L10n = { en: string; kn?: string };

/** English + Kannada inputs for one bilingual field. */
export function L10nInput({ label, value, onChange, multiline }: { label: string; value?: L10n; onChange: (v: L10n) => void; multiline?: boolean }) {
  const v = value ?? { en: '' };
  const Field = multiline ? 'textarea' : 'input';
  return (
    <fieldset className="l10n">
      <legend>{label}</legend>
      <Field placeholder="English" value={v.en} onChange={(e: any) => onChange({ ...v, en: e.target.value })} />
      <Field placeholder="ಕನ್ನಡ" lang="kn" value={v.kn ?? ''} onChange={(e: any) => onChange({ ...v, kn: e.target.value || undefined })} />
    </fieldset>
  );
}

export const SUBJECTS = ['physics', 'chemistry', 'maths', 'biology'] as const;
export const EXAMS = ['PUC', 'KCET', 'COMEDK', 'NEET', 'JEE'] as const;
