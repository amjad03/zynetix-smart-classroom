'use client';
/** Shared bits of the Outcomes pages: formats, the readiness chip, the weekly sparkline. Roll numbers only. */
import { useEffect, useState } from 'react';
import { SUBJECT_NAMES } from '@zynetix/web-ui';

export type BandKey = 'exam_ready' | 'on_track' | 'needs_work' | 'not_enough_data';
export type Readiness = { exam: string; band: BandKey; label: string; score: number | null; coverage: number | null; answered: number; topicsSeen: number; topics: number };
export type College = { id: string; name: string; district: string | null; demo: boolean };

export const EXAM_NAMES: Record<string, string> = { PUC: 'PUC board', CBSE: 'CBSE board', KCET: 'KCET', COMEDK: 'COMEDK', NEET: 'NEET', JEE: 'JEE Main', JEE_ADV: 'JEE Advanced', CUET: 'CUET' };
export const subjectName = (s: string | null | undefined) => (s ? SUBJECT_NAMES[s] ?? s : '');
export const pct = (x: number | null | undefined) => (x == null ? '–' : `${Math.round(x * 100)}%`);
export const week = (d: string) => new Date(`${d}T00:00:00`).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });

/** The query string, read once on the client (keeps pages static-exportable without Suspense). */
export function useQuery() {
  const [q, setQ] = useState<URLSearchParams | null>(null);
  useEffect(() => setQ(new URLSearchParams(location.search)), []);
  return q;
}

export function DemoBadge({ college }: { college?: College | null }) {
  return college?.demo ? <span className="demo-badge" title="Generated demo data for this demo college, not real students">Demo data</span> : null;
}

export function Band({ r }: { r: Readiness }) {
  const tip = r.band === 'not_enough_data'
    ? `${r.answered} tagged answers, ${r.topicsSeen} of ${r.topics} topics seen: too little to judge yet`
    : `Mastery ${pct(r.score)} over ${r.topicsSeen} of ${r.topics} exam topics seen (${pct(r.coverage)}), from ${r.answered} answers`;
  return <span className={`chip ${r.band}`} title={tip}>{r.label}</span>;
}

export function Delta({ d }: { d: number | null }) {
  if (d == null) return <span className="muted">–</span>;
  const v = Math.round(d * 100);
  return <span className={`delta ${v > 0 ? 'up' : v < 0 ? 'down' : ''}`}>{v > 0 ? '▲ +' : v < 0 ? '▼ ' : ''}{v} pts</span>;
}

export function Bar({ value, kind }: { value: number | null; kind?: 'stuck' }) {
  return <div className="bar" role="img" aria-label={pct(value)}><i className={kind} style={{ width: `${Math.round((value ?? 0) * 100)}%` }} /></div>;
}

/** Class mastery by week: one 2px line on a 0–100% scale with a dashed 75% "mastered" guide; hover a week for its value. */
export function Spark({ values, weeks, width = 150, height = 36 }: { values: (number | null)[]; weeks: string[]; width?: number; height?: number }) {
  const n = values.length, pad = 4;
  const x = (i: number) => pad + (i * (width - 2 * pad)) / Math.max(1, n - 1);
  const y = (v: number) => height - pad - v * (height - 2 * pad);
  const pts = values.map((v, i) => (v == null ? null : [x(i), y(v)] as const));
  const d = pts.reduce((acc, p, i) => (p ? `${acc}${acc && pts[i - 1] ? 'L' : 'M'}${p[0].toFixed(1)},${p[1].toFixed(1)}` : acc), '');
  const lastI = values.map((v, i) => (v == null ? -1 : i)).reduce((a, b) => Math.max(a, b), -1);
  if (lastI < 0) return <span className="muted">no answers yet</span>;
  return (
    <svg className="spark" width={width} height={height} role="img" aria-label={`Class mastery by week, latest ${pct(values[lastI])}`}>
      <line className="gd" x1={pad} x2={width - pad} y1={y(0.75)} y2={y(0.75)} />
      <path className="ln" d={d} />
      <circle r={3.5} cx={x(lastI)} cy={y(values[lastI]!)} />
      {values.map((v, i) => (
        <rect key={i} className="hit" x={x(i) - (width / n) / 2} y={0} width={width / n} height={height}>
          <title>{`Week of ${week(weeks[i])}: ${v == null ? 'no answers yet' : pct(v)}`}</title>
        </rect>
      ))}
    </svg>
  );
}

export const LEVEL_LABEL: Record<string, string> = { mastered: 'Mastered', learning: 'Learning', stuck: 'Stuck', unknown: 'Not enough answers' };
export const levelOf = (p: number, n: number) => (n < 2 ? 'unknown' : p >= 0.75 ? 'mastered' : p >= 0.5 ? 'learning' : 'stuck');

export function LevelLegend() {
  return (
    <div className="legend" aria-label="Legend">
      <span className="mastered">Mastered (75%+)</span><span className="learning">Learning (50–74%)</span><span className="stuck">Stuck (under 50%)</span><span className="unknown">Fewer than 2 answers</span>
    </div>
  );
}
