// The order of the search page's results (`web/search.js`, `rank`).
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import test from 'node:test';

const { rank, plain } = createRequire(import.meta.url)('../web/search.js');

const hit = (title, section, score, url = `/es/${title}`) => ({
  url,
  meta: { title, section },
  score,
});

test('plain ignores case, accents and code marks', () => {
  assert.equal(plain(' `Row` '), 'row');
  assert.equal(plain('Diálogos'), 'dialogos');
});

test('a page titled like the query is the best match, whatever its score', () => {
  const { best, groups } = rank(
    [
      hit('Layout', 'Aprender', 0.9),
      hit('Estado', 'Datos y estado', 0.8),
      hit('Row', 'Widget · Layout', 0.1),
    ],
    'row',
  );
  assert.deepEqual(best.map((h) => h.meta.title), ['Row']);
  assert.deepEqual(groups.map((g) => g.name), ['Aprender', 'Datos y estado']);
});

test('sections follow their best hit, and hits follow their score', () => {
  const { best, groups } = rank(
    [
      hit('A1', 'Guía', 0.2),
      hit('B1', 'API', 0.7),
      hit('A2', 'Guía', 0.9),
      hit('B2', 'API', 0.3),
    ],
    'zzz',
  );
  assert.equal(best.length, 0);
  assert.deepEqual(groups.map((g) => g.name), ['Guía', 'API']);
  assert.deepEqual(groups[0].hits.map((h) => h.meta.title), ['A2', 'A1']);
  assert.deepEqual(groups[1].hits.map((h) => h.meta.title), ['B1', 'B2']);
});

test('equal scores keep Pagefind order', () => {
  const { groups } = rank(
    [hit('X', 'S1', 0.5), hit('Y', 'S2', 0.5), hit('Z', 'S1', 0.5)],
    'q',
  );
  assert.deepEqual(groups.map((g) => g.name), ['S1', 'S2']);
  assert.deepEqual(groups[0].hits.map((h) => h.meta.title), ['X', 'Z']);
});
