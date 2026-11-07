// Step 1 of the Zynetix School import: bundle the quest-academy content modules with esbuild
// (React, framer-motion and the app shell stubbed out) and write their data as one JSON file.
//   node extract.mjs [--src /home/user/quest-academy] [--out work/school.json]
import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync, existsSync, readdirSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const arg = (k, d) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : d; };
const src = resolve(arg('--src', process.env.SCHOOL_SRC ?? '/home/user/quest-academy'));
const out = resolve(arg('--out', join(here, 'work/school.json')));

// esbuild: this package's own, or the one pnpm keeps for the workspace.
const require = createRequire(import.meta.url);
function loadEsbuild() {
  try { return require('esbuild'); } catch {}
  const store = join(here, '../../node_modules/.pnpm');
  const dir = existsSync(store) ? readdirSync(store).filter((d) => d.startsWith('esbuild@')).sort().pop() : undefined;
  if (!dir) throw new Error('esbuild not found: pnpm install in tools/school-import');
  return require(join(store, dir, 'node_modules/esbuild'));
}
const esbuild = loadEsbuild();

const STUB = `
const noop = () => undefined;
const el = () => null;
const proxy = new Proxy(function () { return null; }, { get: (_, k) => (k === '__esModule' ? false : proxy), apply: () => null });
module.exports = new Proxy({ default: proxy, createElement: el, jsx: el, jsxs: el, jsxDEV: el, Fragment: 'f', Children: { map: (c) => c, toArray: (c) => [].concat(c ?? []) },
  isValidElement: () => false, useState: (v) => [typeof v === 'function' ? v() : v, noop], useEffect: noop, useLayoutEffect: noop, useMemo: (f) => f(), useCallback: (f) => f, useRef: (v) => ({ current: v }),
  useContext: noop, createContext: () => ({ Provider: el }), forwardRef: (f) => f, memo: (f) => f, motion: proxy, AnimatePresence: el }, { get: (t, k) => (k in t ? t[k] : proxy) });
`;
const stubbed = /^(react|react-dom|react\/jsx-runtime|react\/jsx-dev-runtime|framer-motion|server-only|next\/.*|zustand.*|@supabase\/.*|lucide-react|clsx|canvas-confetti)$/;
const plugin = {
  name: 'school',
  setup(b) {
    b.onResolve({ filter: stubbed }, (a) => ({ path: a.path, namespace: 'stub' }));
    b.onLoad({ filter: /.*/, namespace: 'stub' }, () => ({ contents: STUB, loader: 'js' }));
    // App shell modules the explainers and lessons reach for (stores, i18n hooks, components).
    const shell = /^@\/(lib\/(store|useMyClass|supabase.*|sound|confetti|ui)|i18n\/.*|components\/.*)$/;
    b.onResolve({ filter: /^@\// }, (a) => (shell.test(a.path) && a.path !== '@/components/widgets/_shared' ? { path: a.path, namespace: 'stub' } : undefined));
    b.onResolve({ filter: /^@\// }, async (a) => b.resolve('./' + a.path.slice(2), { resolveDir: join(src, 'src'), kind: a.kind }));
  },
};

const work = join(here, 'work');
mkdirSync(work, { recursive: true });
const bundle = join(work, 'entry.cjs');
await esbuild.build({
  entryPoints: [join(here, 'src/entry.ts')], bundle: true, platform: 'node', format: 'cjs', outfile: bundle,
  plugins: [plugin], jsx: 'automatic', logLevel: 'warning', loader: { '.json': 'json' }, define: { 'process.env.NODE_ENV': '"production"' },
});
const { dump } = require(bundle);
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(dump));
rmSync(bundle);
console.log(`${out}: ${dump.questions.length} questions, ${dump.formulas.length} formula sheets, ${dump.mocks.length} mock patterns, ${dump.explainers.length} explainers, ${dump.lessons.length} lessons, ${Object.keys(dump.videos).length} lessons with videos`);
