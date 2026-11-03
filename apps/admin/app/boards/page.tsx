'use client';
import { useState } from 'react';
import { Shell, api, errorText, useApi } from '@zynetix/web-ui';
import { NAV, Section } from '../../lib/nav';

type Board = { id: string; name: string; sectionId: string; section: string; activatedAt: string; lastSeenAt: string | null; sessions: number };

/** Boards: activation codes for new boards, and PIN resets. */
export default function Boards() {
  const { data: boards, reload } = useApi<Board[]>('/v1/admin/boards');
  const { data: sections } = useApi<Section[]>('/v1/admin/sections');
  const [msg, setMsg] = useState('');
  return (
    <Shell product="College Admin" nav={NAV}>
      <h1>Boards</h1>
      <div className="card">
        <h2>Set up a new board</h2>
        <p className="muted">Generate a code, then on the board: long-press the clock, enter the PIN (1234 on a new board), Activate board.</p>
        <div className="row">
          {sections?.map((s) => (
            <button key={s.id} className="secondary" onClick={async () => {
              try { const r = await api(`/v1/admin/sections/${s.id}/activation-code`, { method: 'POST' }); setMsg(`Code for ${r.section}: ${r.code} (valid ${r.expiresInDays} days)`); }
              catch (e) { setMsg(errorText(e)); }
            }}>Code for {s.label}</button>
          ))}
        </div>
        {msg && <p><b>{msg}</b></p>}
      </div>
      <div className="card table-wrap">
        <table>
          <thead><tr><th>Board</th><th>Section</th><th>Last seen</th><th>Lessons</th><th /></tr></thead>
          <tbody>{boards?.map((b) => (
            <tr key={b.id}>
              <td>{b.name}<div className="muted">{b.id}</div></td>
              <td>{b.section}</td>
              <td>{b.lastSeenAt ? new Date(b.lastSeenAt).toLocaleString() : 'never'}</td>
              <td>{b.sessions}</td>
              <td><button className="secondary" onClick={async () => {
                const pin = prompt('New teacher PIN (4–6 digits)');
                if (!pin) return;
                try { await api(`/v1/admin/boards/${b.id}/pin`, { method: 'PUT', body: { pin } }); setMsg(`PIN changed for ${b.name}. It applies at the board's next sync.`); reload(); }
                catch (e) { setMsg(errorText(e)); }
              }}>Reset PIN</button></td>
            </tr>
          ))}</tbody>
        </table>
        {boards?.length === 0 && <p className="muted">No boards yet.</p>}
      </div>
    </Shell>
  );
}
