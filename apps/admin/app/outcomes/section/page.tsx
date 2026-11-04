'use client';
import { Shell, useApi } from '@zynetix/web-ui';
import { NAV } from '../../../lib/nav';
import { LEVEL_LABEL, LevelLegend, levelOf, pct, subjectName, useQuery } from '../../../lib/outcomes';

type Topic = {
  id: string; title: string; chapterId: string; chapterNumber: number; chapterTitle: string; taught: boolean;
  class: { p: number; n: number; level: string } | null; assessed: number; stuck: number[]; learning: number; mastered: number;
};
type Drill = {
  section: { id: string; label: string; subjects: string[]; rollCount: number }; subject: string; teacher: string | null;
  topics: Topic[]; rolls: { roll: number; overall: number | null; stuck: number; cells: Record<string, [number, number]> }[];
};

/** Section drill-down: topics × roll numbers, and who is stuck where. */
export default function SectionOutcomes() {
  const q = useQuery();
  const id = q?.get('id'), subject = q?.get('subject');
  const { data, error } = useApi<Drill>(id ? `/v1/admin/outcomes/sections/${id}${subject ? `?subject=${subject}` : ''}` : null);
  const topics = data?.topics ?? [];
  return (
    <Shell product="College Admin" nav={NAV}>
      <p className="no-print"><a href="/outcomes">← Outcomes</a></p>
      <h1>{data?.section.label ?? 'Section'} · {subjectName(data?.subject)}</h1>
      {data && <p className="muted">{data.teacher ? `Lecturer: ${data.teacher}. ` : ''}{topics.length} topics taught or practised; {data.section.rollCount} roll numbers. Click a roll number for its report.</p>}
      {error && <p className="error">{error}</p>}
      <div className="sub-tabs">
        {data?.section.subjects.map((s) => <button key={s} className={s === data.subject ? '' : 'secondary'} onClick={() => (location.href = `/outcomes/section?id=${data.section.id}&subject=${s}`)}>{subjectName(s)}</button>)}
      </div>

      <div className="card table-wrap">
        <h2 style={{ marginTop: 0 }}>Topics</h2>
        <table>
          <thead><tr><th>Ch.</th><th>Topic</th><th>Class</th><th>Mastered</th><th>Learning</th><th>Stuck roll numbers</th></tr></thead>
          <tbody>{topics.map((t) => (
            <tr key={t.id}>
              <td className="metric">{t.chapterNumber}</td>
              <td><b>{t.title}</b>{!t.taught && <span className="tag" style={{ marginLeft: 6 }}>practised, not taught yet</span>}</td>
              <td>{t.class ? <span className={`chip ${t.class.level === 'mastered' ? 'exam_ready' : t.class.level === 'stuck' ? 'needs_work' : t.class.level === 'learning' ? 'on_track' : 'not_enough_data'}`}>{LEVEL_LABEL[t.class.level]} · {pct(t.class.p)}</span> : <span className="muted">not quizzed</span>}</td>
              <td className="metric">{t.mastered}</td>
              <td className="metric">{t.learning}</td>
              <td>{t.stuck.length ? <span className="metric">{t.stuck.length} of {t.assessed}: {t.stuck.map((r, i) => <span key={r}>{i ? ', ' : ''}<a href={`/outcomes/roll?section=${data!.section.id}&roll=${r}`}>{r}</a></span>)}</span> : <span className="muted">none</span>}</td>
            </tr>
          ))}</tbody>
        </table>
      </div>

      <div className="card table-wrap">
        <h2 style={{ marginTop: 0 }}>Roll numbers × topics</h2>
        <LevelLegend />
        <table className="heat">
          <thead>
            <tr><th />{topics.map((t) => <th key={t.id} title={`${t.chapterNumber}. ${t.chapterTitle} · ${t.title}`}><div>{t.chapterNumber}. {t.title}</div></th>)}<th><div>Overall</div></th></tr>
          </thead>
          <tbody>{data?.rolls.map((r) => (
            <tr key={r.roll}>
              <td className="rl"><a href={`/outcomes/roll?section=${data.section.id}&roll=${r.roll}`}>Roll {r.roll}</a></td>
              {topics.map((t) => {
                const c = r.cells[t.id];
                const lv = c ? levelOf(c[0], c[1]) : 'unknown';
                return <td key={t.id} className={`cell ${lv}`} title={`Roll ${r.roll} · ${t.title}: ${c ? `${pct(c[0])} from ${c[1]} answer${c[1] === 1 ? '' : 's'}` : 'no answers yet'}`} />;
              })}
              <td className="rl metric" style={{ paddingLeft: 8 }}>{pct(r.overall)}</td>
            </tr>
          ))}</tbody>
          <tfoot><tr><td className="rl muted">stuck</td>{topics.map((t) => <td key={t.id}>{t.stuck.length || ''}</td>)}<td /></tr></tfoot>
        </table>
      </div>
    </Shell>
  );
}
