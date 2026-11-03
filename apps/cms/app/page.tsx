'use client';
import { useState } from 'react';
import { Shell, api, errorText, useApi } from '@zynetix/web-ui';
import { NAV } from '../lib/nav';

type Pack = { id: string; chapterId: string; title: { en: string }; subject: string; year: string; lessons: number; draftUpdatedAt: string | null; versions: { version: string; bytes: number; notes?: string; publishedAt: string; publishedBy: string }[] };

export default function Packs() {
  const { data, error, reload } = useApi<Pack[]>('/v1/cms/packs');
  return (
    <Shell product="Content CMS" nav={NAV}>
      <h1>Content packs</h1>
      <p className="muted">Each pack is one chapter. Edit its lessons, then publish a new version. Boards download it on their next sync.</p>
      {error && <p className="error">{error}</p>}
      {data?.map((p) => <PackCard key={p.id} p={p} onPublished={reload} />)}
      <NewPack onCreated={reload} />
    </Shell>
  );
}

function PackCard({ p, onPublished }: { p: Pack; onPublished: () => void }) {
  const [bump, setBump] = useState('minor'), [notes, setNotes] = useState(''), [msg, setMsg] = useState('');
  const latest = p.versions[0];
  const dirty = !latest || (p.draftUpdatedAt && p.draftUpdatedAt > latest.publishedAt);
  return (
    <div className="card">
      <div className="row" style={{ justifyContent: 'space-between' }}>
        <div>
          <strong>{p.title.en}</strong> <span className="tag">{p.subject}</span><span className="tag">{p.year === 'puc1' ? '1st PUC' : '2nd PUC'}</span>
          <div className="muted">{p.id} · {p.lessons} lessons · latest {latest ? `v${latest.version}` : 'unpublished'} {dirty && '· drafts changed since'}</div>
        </div>
        <a href={`/packs/${p.id}`}><button className="secondary">Edit lessons</button></a>
      </div>
      <div className="row" style={{ marginTop: 12 }}>
        <label>Release<select value={bump} onChange={(e) => setBump(e.target.value)}><option value="patch">Fix (x.x.+1)</option><option value="minor">Update (x.+1.0)</option><option value="major">Major (+1.0.0)</option></select></label>
        <label style={{ flex: 1 }}>Notes<input value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="What changed" /></label>
        <button
          onClick={async () => {
            try {
              const r = await api(`/v1/cms/packs/${p.id}/versions`, { body: { bump, notes: notes || undefined } });
              setMsg(`Published v${r.version} (${Math.round(r.bytes / 1024)} KB, ${r.lessons} lessons, ${r.questions} questions)`);
              onPublished();
            } catch (e) {
              setMsg(errorText(e));
            }
          }}
        >Publish</button>
      </div>
      {msg && <p className={msg.startsWith('Published') ? '' : 'error'}>{msg}</p>}
      {p.versions.length > 0 && (
        <details><summary className="muted">{p.versions.length} versions</summary>
          <table><tbody>{p.versions.map((v) => <tr key={v.version}><td>v{v.version}</td><td>{new Date(v.publishedAt).toLocaleString()}</td><td>{v.publishedBy}</td><td>{v.notes}</td><td>{Math.round(v.bytes / 1024)} KB</td></tr>)}</tbody></table>
        </details>
      )}
    </div>
  );
}

function NewPack({ onCreated }: { onCreated: () => void }) {
  const { data: chapters } = useApi<{ id: string; title: { en: string }; subject: string; year: string; packId: string | null }[]>('/v1/cms/chapters');
  const [chapterId, setChapterId] = useState(''), [err, setErr] = useState('');
  const free = chapters?.filter((c) => !c.packId) ?? [];
  return (
    <div className="card">
      <h2>Start a chapter</h2>
      <div className="row">
        <label style={{ flex: 1 }}>Chapter<select value={chapterId} onChange={(e) => setChapterId(e.target.value)}>
          <option value="">Choose…</option>
          {free.map((c) => <option key={c.id} value={c.id}>{c.year === 'puc1' ? '1st PUC/11' : '2nd PUC/12'} · {c.subject} · {c.title.en}</option>)}
        </select></label>
        <button disabled={!chapterId} onClick={async () => {
          try {
            await api('/v1/cms/packs', { body: { id: chapterId.replace(/-\d\d-/, '-'), chapterId } });
            onCreated();
          } catch (e) { setErr(errorText(e)); }
        }}>Create pack</button>
      </div>
      {err && <p className="error">{err}</p>}
    </div>
  );
}
