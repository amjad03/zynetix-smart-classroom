export const NAV: [string, string][] = [
  ['/', 'Usage'],
  ['/outcomes', 'Outcomes'],
  ['/readiness', 'Exam readiness'],
  ['/league', 'Section league'],
  ['/report', 'Monthly report'],
  ['/self-learning', 'Self-learning scheduler'],
  ['/timetable', 'Timetable'],
  ['/syllabus', 'Syllabus progress'],
  ['/boards', 'Boards'],
];
export const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
export type Section = { id: string; label: string; year: string; board: string; rollCount: number; periodMinutes: number; subjects: string[] };
export type Chapter = { id: string; subject: string; year: string; number: number; title: { en: string }; topics: { id: string; title: { en: string } }[]; hasPack: boolean; boards: string[] };
