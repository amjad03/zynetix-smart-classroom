'use client';
import { useEffect, useState } from 'react';
import { Shell, useApi } from '@zynetix/web-ui';
import { NAV } from '../../lib/nav';
import { Band, College, Delta, DemoBadge, EXAM_NAMES, Readiness, pct, subjectName } from '../../lib/outcomes';

type Report = {
  college: College; month: string; from: string; to: string;
  totals: { lessons: number; selfLearning: number; hours: number; answers: number; accuracy: number | null; rollsAssessed: number; topicsTaught: number };
  sections: {
    id: string; label: string; rollCount: number; rollsAssessed: number;
    subjects: { subject: string; teacher: string | null; taught: number; masteryStart: number | null; masteryEnd: number | null; mastered: number; assessed: number; stuckShare: number | null; answers: number }[];
    weak: { topicId: string; title: string; subject: string | null; p: number; stuck: number }[];
    readiness: Readiness[];
  }[];
  league: { sectionId: string; label: string; points: number }[];
};

const lastMonth = () => {
  const d = new Date();
  d.setDate(1);
  d.setMonth(d.getMonth() - 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
};
const monthName = (ym: string) => new Date(`${ym}-01T00:00:00`).toLocaleDateString('en-IN', { month: 'long', year: 'numeric' });

/** The monthly college report the principal prints for management or a parents' meeting (A4, print CSS). */
export default function ReportPage() {
  const [month, setMonth] = useState<string>('');
  useEffect(() => setMonth(new URLSearchParams(location.search).get('month') ?? lastMonth()), []);
  const { data, error } = useApi<Report>(month ? `/v1/admin/outcomes/report?month=${month}` : null);
  return (
    <Shell product="College Admin" nav={NAV}>
      <div className="toolbar no-print">
        <label>Month<input type="month" value={month} onChange={(e) => setMonth(e.target.value)} /></label>
        <button onClick={() => print()}>Print or save as PDF</button>
      </div>
      {error && <p className="error">{error}</p>}
      {data && (
        <div className="report">
          <h1>{data.college.name} · College report, {monthName(data.month)} <DemoBadge college={data.college} /></h1>
          <p className="muted">{data.college.district ? `${data.college.district} · ` : ''}{data.from} to {data.to} · Zynetix Smart Classroom. Roll numbers only: no student names are stored.</p>

          <div className="card">
            <h2 style={{ marginTop: 0 }}>The month in numbers</h2>
            <div className="kpis">
              <div className="kpi"><b className="metric">{data.totals.lessons}</b>lessons on the boards</div>
              <div className="kpi"><b className="metric">{data.totals.selfLearning}</b>Self-Learning periods (absent lecturer covered)</div>
              <div className="kpi"><b className="metric">{data.totals.hours}</b>hours of board teaching</div>
              <div className="kpi"><b className="metric">{data.totals.topicsTaught}</b>topics taught</div>
              <div className="kpi"><b className="metric">{data.totals.answers.toLocaleString('en-IN')}</b>quiz answers ({pct(data.totals.accuracy)} correct)</div>
              <div className="kpi"><b className="metric">{data.totals.rollsAssessed}</b>roll numbers assessed</div>
            </div>
          </div>

          {data.sections.map((s) => (
            <div className="card sec table-wrap" key={s.id}>
              <h2 style={{ marginTop: 0 }}>{s.label} <span className="tag">{s.rollsAssessed} of {s.rollCount} roll numbers assessed</span></h2>
              {s.subjects.length === 0 ? <p className="muted">No lessons logged this month.</p> : (
                <table>
                  <thead><tr><th>Subject</th><th>Lecturer</th><th>Topics taught</th><th>Class mastery (start → end)</th><th>Change</th><th>Topics mastered</th><th>Roll nos. stuck per topic</th></tr></thead>
                  <tbody>{s.subjects.map((x) => (
                    <tr key={x.subject}>
                      <td><b>{subjectName(x.subject)}</b></td><td>{x.teacher ?? '–'}</td><td className="metric">{x.taught}</td>
                      <td className="metric">{pct(x.masteryStart)} → <b>{pct(x.masteryEnd)}</b></td>
                      <td className="metric"><Delta d={x.masteryStart != null && x.masteryEnd != null ? x.masteryEnd - x.masteryStart : null} /></td>
                      <td className="metric">{x.mastered} of {x.assessed}</td><td className="metric">{pct(x.stuckShare)}</td>
                    </tr>
                  ))}</tbody>
                </table>
              )}
              <p style={{ margin: '10px 0 4px' }}><b>Exam readiness:</b> {s.readiness.map((r) => <span key={r.exam} style={{ marginRight: 10, whiteSpace: 'nowrap' }}>{EXAM_NAMES[r.exam] ?? r.exam} <Band r={r} /></span>)}</p>
              {s.weak.length > 0 && <p style={{ margin: '6px 0 0' }}><b>To re-teach:</b> {s.weak.map((w, i) => <span key={w.topicId}>{i ? '; ' : ''}{w.title} ({subjectName(w.subject)}, {w.stuck} roll nos. stuck)</span>)}</p>}
            </div>
          ))}

          <div className="card sec">
            <h2 style={{ marginTop: 0 }}>Section league, {monthName(data.month)}</h2>
            <table>
              <thead><tr><th>#</th><th>Section</th><th>Points</th></tr></thead>
              <tbody>{data.league.map((l, i) => <tr key={l.sectionId}><td>{i + 1}</td><td>{l.label}</td><td className="metric"><b>{l.points}</b></td></tr>)}</tbody>
            </table>
          </div>
          <p className="muted" style={{ fontSize: 12 }}>
            How to read this: each answer moves a topic&apos;s estimate towards right or wrong, recent answers counting more. A topic is mastered at 75%+, stuck under 50%, judged after 2+ answers.
            Exam readiness uses only questions tagged for that exam: Exam-ready needs 75%+ with 60% of the exam&apos;s topics seen; Not enough data means too few answers to judge.
          </p>
        </div>
      )}
    </Shell>
  );
}
