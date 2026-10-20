// The lite date picker part (lib/lite/parts/date_picker.js) in a real
// Chromium with the names, template, first weekday and digits the server
// writes for other locales (French, Hungarian, Arabic-Indic digits): the
// browser must write the same texts without any CLDR data of its own. Pages
// in memory from the real runtime and the part, no app to build.
//
//   node test/e2e/checks/lite_date_locale_check.mjs
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from '../runner/node_modules/playwright/index.mjs';
import { repo } from './lib/e2e.mjs';

const lite = join(repo, 'packages/thor_engine/lib/lite');
const runtime = readFileSync(join(lite, 'runtime.js'), 'utf8');
const part = readFileSync(join(lite, 'parts/date_picker.js'), 'utf8');
const bundle = runtime.replace('// @thor-lite-parts', () => part);

const LATIN = '0123456789';
const num = (n, digits) => `${n}`.replace(/\d/g, (c) => Array.from(digits)[+c]);
const utcDay = (y, m, d) => new Date(Date.UTC(y, m - 1, d)).getUTCDay();

// The markup thor_ui writes for September 2026 (blank cells included).
const calendar = ({ months, shortMonths, shortDays, monthYear, medium, fdw, digits = LATIN, dir = 'ltr' }) => {
  const config = ['2026-01-15', '2027-02-10', '2026-09-20', fdw, months.join(','), shortMonths.join(','), shortDays.join(','), monthYear, medium, 'Date', '', digits].join('|');
  const off = (utcDay(2026, 9, 1) - fdw + 7) % 7;
  let rows = '';
  for (let r = 0; r < 6; r++) {
    rows += '<tr>';
    for (let c = 0; c < 7; c++) {
      const day = r * 7 + c - off + 1;
      rows += day >= 1 && day <= 30 ? `<td tabindex="${day === 25 ? 0 : -1}"${day === 25 ? ' aria-selected="true"' : ''}>${num(day, digits)}</td>` : '<td></td>';
    }
    rows += '</tr>';
  }
  return `<!DOCTYPE html><html dir="${dir}"><head><base href="/"><meta charset="utf-8"></head><body>
<div id="cal" data-t-date="${config}" data-t-month="2026-09" data-t-mode="day">
<button type="button" data-t-years aria-expanded="false"><span>x</span></button>
<button type="button" data-t-nav="-1" id="prev">p</button><button type="button" data-t-nav="1" id="next">n</button>
<table role="grid"><tbody data-t-days>${rows}</tbody></table>
<div data-t-year-list><template><button type="button"></button></template></div>
<input type="hidden" data-t-value value="2026-09-25">
</div><script>${bundle}</script></body></html>`;
};

const FR = {
  months: ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'],
  shortMonths: ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'],
  shortDays: ['dim.', 'lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.'],
  monthYear: '{M} {y}',
  medium: '{w} {d} {m}',
  fdw: 1,
};
const AR = {
  months: ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'],
  shortMonths: ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'],
  shortDays: ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'],
  monthYear: '{M} {y}',
  medium: '{w}، {d} {m}',
  fdw: 6,
  digits: '٠١٢٣٤٥٦٧٨٩',
  dir: 'rtl',
};
const HU = { ...FR, monthYear: '{y}. {M}' };

const pages = { '/fr': calendar(FR), '/ar': calendar(AR), '/hu': calendar(HU) };

const results = [];
const check = (label, ok, detail = '') => {
  results.push(ok);
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${ok ? '' : ` ${detail}`}`);
};

const browser = await chromium.launch();
const open = async (path) => {
  const p = await (await browser.newContext()).newPage();
  p.problems = [];
  p.on('pageerror', (e) => p.problems.push(e.message));
  await p.route('http://lite.test/**', (r) => r.fulfill({ contentType: 'text/html', body: pages[new URL(r.request().url()).pathname] ?? '' }));
  await p.goto(`http://lite.test${path}`);
  await p.waitForFunction(() => typeof thor !== 'undefined');
  await p.waitForTimeout(50);
  return p;
};
const label = (p) => p.locator('#cal [data-t-years] span').textContent();
const cells = (p) => p.locator('#cal td').allTextContents();
const value = (p) => p.locator('#cal [data-t-value]').inputValue();

try {
  {
    const p = await open('/fr');
    await p.locator('#next').click();
    check('fr: the month label uses the server template and names', (await label(p)) === 'octobre 2026', await label(p));
    // 1 Oct 2026 is a Thursday: three blanks with Monday first.
    const c = await cells(p);
    check('fr: Monday-first grid', c.slice(0, 4).join('|') === '|||1', c.slice(0, 4).join('|'));
    await p.locator('#cal td', { hasText: /^10$/ }).click();
    check('fr: picking writes the ISO date', (await value(p)) === '2026-10-10', await value(p));
    check('fr: no page errors', p.problems.length === 0, p.problems.join(' | '));
  }
  {
    const p = await open('/hu');
    await p.locator('#next').click();
    check('hu: a year-first template', (await label(p)) === '2026. octobre', await label(p));
  }
  {
    const p = await open('/ar');
    check('ar: the server cells keep their digits', (await cells(p)).includes('٢٥'));
    await p.locator('#next').click();
    check('ar: the label writes the year with the locale digits', (await label(p)) === 'أكتوبر ٢٠٢٦', await label(p));
    // 1 Oct 2026 is a Thursday: Saturday first, five blanks.
    const c = await cells(p);
    check('ar: Saturday-first grid, locale day numbers', c.slice(0, 6).join('|') === '|||||١', c.slice(0, 6).join('|'));
    check('ar: two-digit days', c.includes('١٠') && c.includes('٣١'), c.join('|'));
    await p.locator('#cal td', { hasText: /^١٠$/ }).click();
    check('ar: picking by position writes the ISO date', (await value(p)) === '2026-10-10', await value(p));
    // Right-to-left: ArrowRight is the previous day.
    await p.keyboard.press('ArrowRight');
    await p.keyboard.press('Enter');
    check('ar: RTL arrow keys (right = the previous day)', (await value(p)) === '2026-10-09', await value(p));
    await p.locator('#cal [data-t-years]').click();
    const years = await p.locator('#cal [data-t-year-list] button').allTextContents();
    check('ar: the year list in locale digits', years.join('|') === '٢٠٢٦|٢٠٢٧', years.join('|'));
    await p.locator('#cal [data-t-year-list] button').nth(1).click();
    check('ar: picking a year by its value', (await label(p)).endsWith('٢٠٢٧'), await label(p));
    check('ar: no page errors', p.problems.length === 0, p.problems.join(' | '));
  }
} finally {
  await browser.close();
}

const failed = results.filter((ok) => !ok).length;
console.log(`\n${results.length - failed}/${results.length} checks passed`);
if (failed > 0 || results.length === 0) process.exit(1);
