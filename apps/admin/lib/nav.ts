export const NAV: [string, string][] = [
  ['/', 'Usage'],
  ['/self-learning', 'Self-learning scheduler'],
  ['/timetable', 'Timetable'],
  ['/syllabus', 'Syllabus progress'],
  ['/boards', 'Boards'],
];
export const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
export type Section = { id: string; label: string; year: string; rollCount: number; periodMinutes: number; subjects: string[] };
export type Chapter = { id: string; subject: string; year: string; number: number; title: { en: string }; topics: { id: string; title: { en: string } }[]; hasPack: boolean };
