'use client';
import { useState } from 'react';
import { SUBJECTS, Shell, useApi } from '@zynetix/web-ui';
import { NAV } from '../../lib/nav';

type Heat = {
  sections: { id: string; label: string; year: string }[];
  chapters: { id: string; subject: string; year: string; number: number; title: string; topics: number }[];
  cells: { sectionId: string; chapterId: string; taught: number; topics: number; share: number | null }[];
};

/** Syllabus heatmap: sections down, chapters across, share of topics taught. */
export default function Syllabus() {
  const { data, error } = useApi<Heat>('/v1/admin/reports/syllabus');
  const [subject, setSubject] = useState<string>('physics');
  const cell = (s: string, c: string) => data?.cells.find((x) => x.sectionId === s && x.chapterId === c);
  return (
    <Shell product="College Admin" nav={NAV}>
      <h1>Syllabus progress</h1>
      <div className="row" style={{ marginBottom: 12 }}>
        {SUBJECTS.map((s) => <button key={s} className={s === subject ? '' : 'secondary'} onClick={() => setSubject(s)}>{s}</button>)}
      </div>
      {error && <p className="error">{error}</p>}
      {data?.sections.map((sec) => {
        const chs = data.chapters.filter((c) => c.subject === subject && c.year === sec.year);
        return (
          <div className="card" key={sec.id}>
            <h2>{sec.label}</h2>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))', gap: 6 }}>
              {chs.map((c) => {
                const x = cell(sec.id, c.id);
                const share = x?.share;
                const bg = share == null ? 'transparent' : `color-mix(in srgb, var(--accent) ${Math.round(15 + share * 85)}%, transparent)`;
                return (
                  <div key={c.id} title={`${c.title}: ${x?.taught ?? 0}/${c.topics || '?'} topics`} style={{ background: bg, border: '1px solid var(--line)', borderRadius: 8, padding: 8, fontSize: 13, color: share && share > 0.5 ? '#fff' : undefined }}>
                    <b>{c.number}.</b> {c.title}
                    <div>{share == null ? <span className="muted">no topics yet</span> : `${Math.round(share * 100)}%`}</div>
                  </div>
                );
              })}
            </div>
          </div>
        );
      })}
    </Shell>
  );
}
