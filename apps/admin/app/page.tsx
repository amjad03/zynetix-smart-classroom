'use client';
import { Shell, useApi } from '@zynetix/web-ui';
import { NAV } from '../lib/nav';

type Usage = {
  daily: { day: string; mode: string; sessions: number; minutes: number }[];
  bySection: { section: string; sessions: number; selfLearning: number; answers: number; correct: number }[];
  boards: { total: number; active: number };
};

/** Usage over the last 30 days. */
export default function UsagePage() {
  const { data, error } = useApi<Usage>('/v1/admin/reports/usage');
  const days = [...new Set(data?.daily.map((d) => d.day))];
  const total = data?.daily.reduce((a, d) => a + d.sessions, 0) ?? 0;
  const self = data?.daily.filter((d) => d.mode === 'self_learning').reduce((a, d) => a + d.sessions, 0) ?? 0;
  const minutes = data?.daily.reduce((a, d) => a + d.minutes, 0) ?? 0;
  const max = Math.max(1, ...days.map((d) => data!.daily.filter((x) => x.day === d).reduce((a, x) => a + x.sessions, 0)));
  return (
    <Shell product="College Admin" nav={NAV}>
      <h1>Usage · last 30 days</h1>
      {error && <p className="error">{error}</p>}
      <div className="kpis">
        <div className="kpi"><b>{total}</b>lessons taught</div>
        <div className="kpi"><b>{self}</b>Self-Learning periods</div>
        <div className="kpi"><b>{Math.round(minutes / 60)}</b>hours on the boards</div>
        <div className="kpi"><b>{data ? `${data.boards.active}/${data.boards.total}` : '–'}</b>boards seen this week</div>
      </div>
      <div className="card">
        <h2>Lessons per day</h2>
        {days.length === 0 && <p className="muted">No lessons synced yet. Boards send their logs whenever they are online.</p>}
        <div style={{ display: 'flex', alignItems: 'end', gap: 4, height: 160, overflowX: 'auto' }}>
          {days.map((d) => {
            const t = data!.daily.filter((x) => x.day === d && x.mode === 'teacher').reduce((a, x) => a + x.sessions, 0);
            const s = data!.daily.filter((x) => x.day === d && x.mode === 'self_learning').reduce((a, x) => a + x.sessions, 0);
            return (
              <div key={d} title={`${d}: ${t} teacher, ${s} self-learning`} style={{ display: 'flex', flexDirection: 'column-reverse', minWidth: 18 }}>
                <div style={{ height: (t / max) * 140, background: 'var(--accent)', borderRadius: 3 }} />
                <div style={{ height: (s / max) * 140, background: '#8e5bb5', borderRadius: 3, marginBottom: 2 }} />
              </div>
            );
          })}
        </div>
        <p className="muted"><span style={{ color: 'var(--accent)' }}>■</span> Teacher Mode <span style={{ color: '#8e5bb5' }}>■</span> Self-Learning</p>
      </div>
      <div className="card table-wrap">
        <h2>By section</h2>
        <table>
          <thead><tr><th>Section</th><th>Lessons</th><th>Self-Learning</th><th>Class answers</th><th>Correct</th></tr></thead>
          <tbody>{data?.bySection.map((s) => (
            <tr key={s.section}><td>{s.section}</td><td>{s.sessions}</td><td>{s.selfLearning}</td><td>{s.answers}</td><td>{s.answers ? `${Math.round((100 * s.correct) / s.answers)}%` : '–'}</td></tr>
          ))}</tbody>
        </table>
      </div>
    </Shell>
  );
}
