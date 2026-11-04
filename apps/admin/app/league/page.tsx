'use client';
import { Shell, useApi } from '@zynetix/web-ui';
import { NAV } from '../../lib/nav';
import { week } from '../../lib/outcomes';

type W = { week: string; points: number; correct: number; stars: number; streakDays: number };
type L = { weeks: string[]; sections: { sectionId: string; label: string; weeks: W[] }[] };

/** Section league: points per week. The boards show this week's table to the class. */
export default function League() {
  const { data, error } = useApi<L>('/v1/admin/outcomes/league?weeks=6');
  const now = data ? [...data.sections].map((s) => ({ ...s, cur: s.weeks[s.weeks.length - 1] })).sort((a, b) => b.cur.points - a.cur.points) : [];
  const max = Math.max(1, ...now.map((s) => s.cur.points));
  return (
    <Shell product="College Admin" nav={NAV}>
      <h1>Section league</h1>
      <p className="muted">Points each week: correct answers plus 2 extra per challenge star, scaled to a class of 40 so big and small sections compete fairly, plus 10 for each day of the week&apos;s teaching streak (consecutive school days with a lesson). Boards get this week&apos;s table on every sync.</p>
      {error && <p className="error">{error}</p>}
      {data && (
        <div className="card">
          <h2 style={{ marginTop: 0 }}>This week (from {week(data.weeks[data.weeks.length - 1])})</h2>
          <div className="lg-bars">
            {now.map((s, i) => (
              <div className="lg-row" key={s.sectionId} title={`${s.cur.correct} correct · ${s.cur.stars} challenge stars · ${s.cur.streakDays}-day streak`}>
                <div><b>{i + 1}.</b> {s.label}</div>
                <div className="bar"><i style={{ width: `${(100 * s.cur.points) / max}%` }} /></div>
                <div className="metric" style={{ textAlign: 'right' }}><b>{s.cur.points}</b></div>
              </div>
            ))}
          </div>
        </div>
      )}
      <div className="card table-wrap">
        <h2 style={{ marginTop: 0 }}>Week by week</h2>
        <table>
          <thead><tr><th>Section</th>{data?.weeks.map((w) => <th key={w}>{week(w)}</th>)}<th>Total</th></tr></thead>
          <tbody>{now.map((s) => (
            <tr key={s.sectionId}>
              <td>{s.label}</td>
              {s.weeks.map((w) => <td key={w.week} className="metric" title={`${w.correct} correct · ${w.stars} stars · ${w.streakDays}-day streak`}><b>{w.points}</b><div className="muted" style={{ fontSize: 12 }}>★ {w.stars} · {w.streakDays}d</div></td>)}
              <td className="metric"><b>{s.weeks.reduce((a, w) => a + w.points, 0)}</b></td>
            </tr>
          ))}</tbody>
        </table>
        <p className="muted">★ challenge stars · d = streak days. The current week is still in progress.</p>
      </div>
    </Shell>
  );
}
