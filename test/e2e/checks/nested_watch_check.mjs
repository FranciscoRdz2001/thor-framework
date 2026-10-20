// Five Watch and layout cases (a nested Watch, a wrapped list container, a
// date dialog in a form, a position variant, the icons of a field), each
// checked in a real browser on test/fixtures/apps/lab (/nested-watch).
//
//   tool/thor e2e nested-watch                  (builds, serves, runs)
//   node test/e2e/checks/nested_watch_check.mjs [url]
import { e2e, hydrated, settle, trackHydration } from './lib/e2e.mjs';

await e2e('nested-watch', { site: 'test/fixtures/apps/lab/build/site', path: 'nested-watch' }, async (t) => {
  const page = await t.page({ viewport: { width: 1000, height: 1600 } });
  await trackHydration(page);
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(t.url);
  await page.mouse.move(1, 1); // the first pointer event loads the engine
  await page.mouse.down();
  await page.mouse.up();
  t.check('engine hydrates', await hydrated(page).then(() => true, () => false));
  // The lite runtime defines `thor.def`; the dart2js oracle engine (THOR_INTERNAL_ENGINE=dart) passes the same checks.
  const lite = await page.evaluate(() => typeof window.thor?.def === 'function');
  const btn = (n) => page.getByRole('button', { name: n, exact: true });
  const flat = (s) => s.replace(/\s+/g, ' ').trim();

  // --- A Watch inside the variant of another Watch.
  const strip = (x) => flat(x).replace(/^Nested Watch toggle outer toggle inner toggle second /, '');
  const nested = () => page.locator('#nested-watch').innerText().then(strip);
  const expectNested = async (label, want) => {
    const got = await settle(page, (w) => document.querySelector('#nested-watch').innerText.replace(/\s+/g, ' ').trim().replace(/^Nested Watch toggle outer toggle inner toggle second /, '') === w, want);
    t.check(`nested Watch: ${label}`, got === true, got === true ? '' : `${await nested()}, expected ${want}`);
  };
  {
    await expectNested('the page starts with the outer state off', 'outer off');
    await btn('toggle inner').click(); // changes while its Watch is not on screen
    await btn('toggle outer').click();
    await expectNested('the inner Watch shows the value it got while hidden', 'outer on inner on second off');
    await btn('toggle second').click();
    await expectNested('a Watch that came in with the variant reacts', 'outer on inner on second on');
    await btn('toggle inner').click();
    await expectNested('the first one reacts too', 'outer on inner off second on');
    await btn('toggle outer').click();
    await btn('toggle inner').click();
    await btn('toggle second').click();
    await btn('toggle outer').click();
    await expectNested('coming back, the state changed while away', 'outer on inner on second off');
    for (let i = 0; i < 5; i++) {
      await btn('toggle outer').click();
      await btn('toggle inner').click();
      await btn('toggle outer').click();
    }
    await expectNested('five round trips', 'outer on inner off second off');
    await btn('toggle second').click();
    await expectNested('after the round trips a tap still lands once', 'outer on inner off second on');
    await btn('toggle second').click();
  }

  // --- `container:` returning a wrapper of the real container.
  const lists = () => page.evaluate(() => Object.fromEntries([...document.querySelectorAll('[id^=list-]')].map((s) => [s.id, {
    names: [...s.querySelectorAll('[data-tk]')].map((r) => r.textContent),
    direct: [...s.querySelectorAll('[data-tk]')].every((r) => r.parentElement.hasAttribute('data-tl')),
    lists: s.querySelectorAll('[data-tl]').length,
  }])));
  const shapes = ['column', 'wrap', 'padded', 'container', 'semantics', 'sized', 'card', 'center', 'scroll', 'component', 'decorated', 'listview'];
  const every = async (label, names) => {
    const got = await settle(page, (w) => [...document.querySelectorAll('[id^=list-]')].every((s) => [...s.querySelectorAll('[data-tk]')].map((r) => r.textContent).join() === w), names.join());
    const now = await lists();
    const bad = shapes.filter((n) => now[`list-${n}`]?.names.join() !== names.join());
    t.check(`container wrapper: ${label}`, got === true && bad.length === 0, `wrong in: ${bad.join(', ')}`);
  };
  const before = await lists();
  t.check('container wrapper: a row per item, in every container shape', shapes.every((n) => before[`list-${n}`]?.names.join() === 'uno,dos'), JSON.stringify(before));
  t.check('container wrapper: one marked list per section, rows straight under it', shapes.every((n) => before[`list-${n}`].lists === 1 && before[`list-${n}`].direct), JSON.stringify(before));
  await btn('add item').click();
  await every('a row added under a wrapper appears', ['uno', 'dos', 'n2']);
  await btn('clear items').click();
  await every('the empty list leaves no row', []);
  await btn('add item').click();
  await every('a row added to the empty list appears', ['n0']);
  await btn('add item').click();
  await btn('add item').click();
  await every('several more', ['n0', 'n1', 'n2']);

  // --- A date dialog inside a form does not submit it by itself.
  await page.evaluate(() => {
    window.subs = [];
    document.addEventListener('submit', (e) => {
      window.subs.push(e.submitter?.textContent ?? e.target.tagName);
      e.preventDefault(); // stay on the page
    }, true);
  });
  const subs = () => page.evaluate(() => window.subs);
  const due = page.locator('dialog#due');
  await btn('Elegir fecha').click();
  t.check('date in a form: the trigger opens the dialog', await due.evaluate((d) => d.open));
  const day = (n) => due.locator('td', { hasText: new RegExp(`^${n}$`) });
  await day(15).click();
  t.check('date in a form: picking a day does not submit the form', (await subs()).length === 0, JSON.stringify(await subs()));
  await due.locator('[data-t-nav="1"]').click();
  await due.locator('[data-t-years]').click();
  await due.locator('[data-t-year-list] button', { hasText: '2027' }).click();
  await day(10).click();
  await page.keyboard.press('Enter');
  t.check('date in a form: nor do month, year or Enter', (await subs()).length === 0, JSON.stringify(await subs()));
  if (await due.evaluate((d) => d.open)) await due.locator('[data-t-pick-ok]').click();
  const label = await settle(page, () => /^Elegido: 2027-\d+-10/.test(document.querySelector('#date-in-form').innerText.match(/Elegido.*/)?.[0] ?? ''), null);
  t.check('date in a form: OK hands the day to the state', label === true, await page.locator('#date-in-form').innerText().then(flat));
  t.check('date in a form: the dialog closes', !(await due.evaluate((d) => d.open)));
  t.check('date in a form: still no submit', (await subs()).length === 0, JSON.stringify(await subs()));
  // Enter and Space on everything the dialog can focus, in the day view and in the year view.
  await btn('Elegir fecha').click();
  let presses = 0;
  for (const view of ['days', 'years']) {
    if (view === 'years') await due.locator('[data-t-years]').click();
    for (const h of await due.locator('button:visible, td:visible, [tabindex]:visible').elementHandles()) {
      if (!(await due.evaluate((d) => d.open))) break;
      for (const key of ['Enter', 'Space']) {
        await h.evaluate((e) => e.focus()).catch(() => {});
        await page.keyboard.press(key);
        presses++;
      }
    }
  }
  t.check('date in a form: Enter and Space on every control of the dialog do not submit', presses > 10 && (await subs()).length === 0, `${presses} presses, ${JSON.stringify(await subs())}`);
  if (!(await due.evaluate((d) => d.open))) await btn('Elegir fecha').click();
  await page.keyboard.press('Escape');
  await btn('Enviar').click();
  t.check('date in a form: its own button does submit it, once', JSON.stringify(await subs()) === '["Enviar"]', JSON.stringify(await subs()));

  // --- A variant that changes the position resets the base offsets.
  const box = () => page.evaluate(() => {
    const e = [...document.querySelectorAll('#position-variant span')].find((x) => x.textContent === 'position box');
    const c = getComputedStyle(e);
    return { position: c.position, left: c.left, top: c.top };
  });
  let b = await box();
  t.check('position variant: wide (md up): sticky and the left is gone', b.position === 'sticky' && b.left === 'auto', JSON.stringify(b));
  await page.setViewportSize({ width: 500, height: 1600 });
  b = await box();
  t.check('position variant: narrow: fixed with its left', b.position === 'fixed' && b.left === '40px' && b.top === '300px', JSON.stringify(b));
  await page.setViewportSize({ width: 1000, height: 1600 });
  b = await box();
  t.check('position variant: wide again: back to sticky, left gone', b.position === 'sticky' && b.left === 'auto', JSON.stringify(b));

  // --- An icon's box by its constraints.
  const heights = await page.evaluate(() => [...document.querySelectorAll('#field-icons label')].map((l) => Math.round(l.getBoundingClientRect().height)));
  t.check('field icons: three fields', heights.length === 3, JSON.stringify(heights));
  t.check('field icons: by default the icon slot is 48 px (Flutter)', heights[1] === 48 && heights[0] < 48, JSON.stringify(heights));
  t.check('field icons: prefixIconConstraints sizes it by the icon', heights[2] === heights[0], JSON.stringify(heights));

  // --- The same cases, broken on purpose (test/fixtures/apps/lab/lib/nested_watch/adv_*.dart).
  const view = (id) => page.locator(`#${id}`).innerText().then(flat);
  const expectView = async (label, id, want) => {
    const got = await settle(page, ([i, w]) => document.getElementById(i).innerText.replace(/\s+/g, ' ').trim() === w, [id, want]);
    t.check(label, got === true, got === true ? '' : `${await view(id)}, expected ${want}`);
  };
  const press = async (n) => {
    await btn(n).click();
  };
  // Containers with more than the rows in them, and more shapes, on a list that changes.
  const listsOf = () => page.evaluate(() => Object.fromEntries(['x-nest', 'x-headfoot', 'x-head', 'x-after', 'x-listview', 'x-center2'].map((id) => {
    const s = document.getElementById(id);
    return [id, { rows: [...s.querySelectorAll('[data-tk]')].map((r) => r.textContent).join(), text: s.innerText.replace(/\s+/g, ' ').trim(), lists: s.querySelectorAll('[data-tl]').length }];
  })));
  const expectLists = async (label, rows) => {
    const shape = { 'x-nest': (r) => r, 'x-headfoot': (r) => `head ${r} foot`.replace(/  +/g, ' '), 'x-head': (r) => `head ${r}`, 'x-after': (r) => `${r} after`, 'x-listview': (r) => r, 'x-center2': (r) => r };
    const want = (id) => shape[id](rows.join(' ')).trim();
    const ok = await settle(page, (w) => {
      const norm = (id) => document.getElementById(id).innerText.replace(/\s+/g, ' ').trim();
      return Object.entries(w).every(([id, t]) => norm(id) === t);
    }, Object.fromEntries(Object.keys(shape).map((id) => [id, want(id)])));
    const now = await listsOf();
    const bad = Object.entries(now).filter(([id, v]) => v.rows !== rows.join() || v.lists !== 1).map(([id, v]) => `${id}: ${v.rows} (${v.lists} marked)`);
    t.check(`container shapes: ${label}`, ok === true && bad.length === 0, bad.join('; ') || JSON.stringify(now));
  };
  await expectLists('every shape starts with the two items', ['p', 'q']);
  await press('addX');
  await expectLists('a row is added before a footer, in every shape', ['p', 'q', 'n2']);
  await press('reverseX');
  await expectLists('reversed', ['n2', 'q', 'p']);
  await press('dropFirstX');
  await expectLists('the first one dropped', ['q', 'p']);
  await press('clearX');
  await expectLists('emptied', []);
  await press('addX');
  await expectLists('filled again', ['n0']);

  {
    // Three levels of variants; the innermost changes while it is away.
    await expectView('three levels: three levels start closed', 'x-levels', 'A0');
    await press('l3');
    await press('l1');
    await expectView('three levels: level 1 on, the rest closed', 'x-levels', 'A1 B0');
    await press('l2');
    await expectView('three levels: level 3 shows what it got while away', 'x-levels', 'A1 B1 C1');
    await press('l3');
    await expectView('three levels: and reacts', 'x-levels', 'A1 B1 C0');
    await press('l2');
    await press('l1');
    await press('l3');
    await press('l1');
    await press('l2');
    await expectView('three levels: a round trip keeps every level', 'x-levels', 'A1 B1 C1');
    // An enum with five values, two drawing the same, inside a variant.
    await press('o2');
    await expectView('five-value enum: the enum starts at its first value', 'x-five', 'O2 same');
    for (const want of ['same', 'three', 'four', 'five', 'same']) {
      await press('five');
      await expectView(`five-value enum: enum step to ${want}`, 'x-five', `O2 ${want}`);
    }
    await press('o2');
    await press('five');
    await press('o2');
    await expectView('five-value enum: changed while away', 'x-five', 'O2 same');
    // Two watches that draw the same in both states.
    await press('o3');
    await press('same');
    await press('other');
    await expectView('identical markup: identical markup in both states, the other one apart', 'x-same', 'O3 same yes');
    await press('o3');
    await press('other');
    await press('o3');
    await expectView('identical markup: back after a change', 'x-same', 'O3 same no');
    // A keyed list with row states inside a variant. The items changed while it was closed.
    await press('o4');
    await expectView('list in a variant: the list inside the variant shows the items it got while away', 'x-list', 'O4 n0 .');
    await press('addX');
    await expectView('list in a variant: it follows a new item', 'x-list', 'O4 n0 . n1 .');
    await press('resetX');
    await expectView('list in a variant: and the items back', 'x-list', 'O4 p . q *');
    await press('markX');
    await expectView('list in a variant: its row states follow an item that changed', 'x-list', 'O4 q9 * q *');
    await expectView('list in a variant: the same list outside says the same', 'x-marked', 'q9 * q *');
    for (let i = 0; i < 20; i++) await press('o4');
    await press('addX');
    await expectView('list in a variant: after 20 toggles it is still in step', 'x-list', 'O4 q9 * q * n2 .');
    await press('o4');
    await press('o4');
    await expectView('list in a variant: closed and open again, the same', 'x-list', 'O4 q9 * q * n2 .');
    // A thousand Watches in a variant come in, and follow, fast enough.
    await press('o5');
    const ms = await page.evaluate(() => {
      const b = [...document.querySelectorAll('button')].find((x) => x.textContent === 'o5');
      const t0 = performance.now();
      b.click();
      b.click();
      return performance.now() - t0;
    });
    await expectView('a thousand Watches: a thousand inner Watches, still on', 'x-many', `O5 ${Array(1000).fill('0').join(' ')}`);
    t.check('a thousand Watches: two toggles of a thousand Watches under half a second', ms < 500, `${Math.round(ms)} ms`);
    await press('flag');
    await expectView('a thousand Watches: all of them follow', 'x-many', `O5 ${Array(1000).fill('1').join(' ')}`);
  }

  // A Watch of another state inside the rows, rows that come later, a list in a variant in a row.
  await press('resetX');
  await expectView('other state in rows: the rows show the other state', 'other-rows', 'p L0 off q L0 off');
  await press('k-label');
  await press('k-mode');
  await expectView('other state in rows: they follow its text and its variant', 'other-rows', 'p L1 on q L1 on');
  await press('addX');
  await expectView('other state in rows: a row that comes later shows its current value', 'other-rows', 'p L1 on q L1 on n2 L1 on');
  await press('k-label');
  await expectView('other state in rows: and follows it', 'other-rows', 'p L2 on q L2 on n2 L2 on');
  await press('dropFirstX');
  await press('k-label');
  await expectView('other state in rows: a row that left is gone, the others follow', 'other-rows', 'q L3 on n2 L3 on');
  await expectView('list in a row variant: the list in the variant of each row', 'row-lists', 'q n1 L3 n2 L3 n2 n1 L3 n2 L3');
  await press('k-add');
  await press('k-label');
  await expectView('list in a row variant: the nested rows follow their list and the text', 'row-lists', 'q n1 L4 n2 L4 n3 L4 n2 n1 L4 n2 L4 n3 L4');
  await press('k-mode');
  await expectView('list in a row variant: the variant off', 'row-lists', 'q - n2 -');
  await press('k-mode');
  await press('resetX');
  await expectView('list in a row variant: on again, new rows', 'row-lists', 'p n1 L4 n2 L4 n3 L4 q n1 L4 n2 L4 n3 L4');

  t.check('no page errors', errors.length === 0, errors.join('; '));
});
