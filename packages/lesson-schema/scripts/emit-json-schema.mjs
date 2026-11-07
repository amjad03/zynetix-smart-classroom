// Writes schema/*.schema.json from the Zod types, for tools that are not TypeScript.
import { writeFileSync, mkdirSync } from 'node:fs';
import { zodToJsonSchema } from 'zod-to-json-schema';
import * as s from '../dist/index.js';

mkdirSync(new URL('../schema/', import.meta.url), { recursive: true });
for (const name of ['Lesson', 'Block', 'Question', 'Chapter', 'PackManifest', 'AudioPackManifest', 'SessionLog', 'FormulaSheet', 'MockPattern']) {
  const json = zodToJsonSchema(s[name], { name, $refStrategy: 'none' });
  writeFileSync(new URL(`../schema/${name}.schema.json`, import.meta.url), JSON.stringify(json, null, 2) + '\n');
}
console.log('schema/*.schema.json written');
