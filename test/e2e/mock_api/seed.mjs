// Seed data for the RealWorld mock: fixed users, articles, comments,
// favorites and follows, generated with a fixed PRNG so every run (and the
// goldens) starts from exactly the same state.

const origin = process.env.MOCK_ORIGIN ?? `http://localhost:${process.env.MOCK_PORT ?? 3001}`;

/** Seed users log in with `password123`; their tokens are fixed too. */
const people = [
  ['johndoe', 'Full-stack developer. Writes about the web platform and performance.', true],
  ['janedoe', 'Designer who codes. CSS, typography and accessible interfaces.', true],
  ['alexchen', null, true],
  ['mariagarcia', 'Backend engineer, databases and distributed systems.', false],
  ['samkim', null, false],
];

const tags = ['webdev', 'performance', 'css', 'dart', 'javascript', 'accessibility', 'design', 'testing', 'devops', 'databases'];

const subjects = [
  'Server rendering without the hydration tax',
  'A practical guide to container queries',
  'Why your bundle is bigger than you think',
  'Designing forms that work without JavaScript',
  'Caching strategies for content sites',
  'Understanding the CSS cascade layers',
  'Measuring interaction latency in the field',
  'Typed routing in a server-first framework',
  'Progressive enhancement is not a fallback',
  'Database indexes explained with a library',
  'Writing end-to-end tests that do not flake',
  'The cost of client-side navigation',
  'Accessible dialogs with native HTML',
  'Color systems with CSS custom properties',
  'Deploying static sites with immutable assets',
  'What a signal really is',
  'Pagination patterns: offset versus cursor',
  'Fonts, layout shift and the swap period',
  'Streaming HTML from the server',
  'Security headers every site should send',
  'Image formats and responsive sources',
  'Error pages that help users recover',
  'The anatomy of a cookie-based session',
  'Reading a performance trace step by step',
];

function prng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function body(rand, title) {
  const pick = (xs) => xs[Math.floor(rand() * xs.length)];
  const sentences = [
    'The browser already knows how to do most of this, so the job is to stop fighting it.',
    'Measure first: the slow part is rarely the one you would guess.',
    'Every kilobyte of script has to be downloaded, parsed and executed before it helps.',
    'A small, boring solution that you understand beats a clever one you have to debug.',
    'Semantic HTML gives you keyboard support and screen reader output for free.',
    'Caching is easy until you need to invalidate something.',
    'Most pages are documents with a few interactive islands.',
    'Latency adds up quickly when requests depend on each other.',
    'Write the test from the point of view of the person using the page.',
    'Defaults matter because almost nobody changes them.',
  ];
  const para = () => Array.from({ length: 3 + Math.floor(rand() * 3) }, () => pick(sentences)).join(' ');
  return [
    `## ${title}`,
    para(),
    para(),
    '### Key points',
    '- Start from the platform',
    '- Keep the critical path short',
    '- Measure on a slow device',
    '',
    '```js',
    "const response = await fetch('/api/articles?limit=10');",
    'const { articles } = await response.json();',
    '```',
    '',
    para(),
    `Read more on [the web platform docs](https://developer.mozilla.org/) and **try it** on a real phone.`,
  ].join('\n\n');
}

export function seed() {
  const rand = prng(20260924);
  const users = people.map(([username, bio, hasImage], i) => ({
    id: i + 1,
    username,
    email: `${username}@example.com`,
    password: 'password123',
    bio,
    image: hasImage ? `${origin}/img/${username}.svg` : null,
    token: `seed-token-${username}`,
  }));

  const start = Date.UTC(2026, 0, 5, 9, 0, 0);
  const articles = subjects.map((title, i) => {
    const at = new Date(start + i * 5 * 86400000 + Math.floor(rand() * 36000000)).toISOString();
    const n = 1 + Math.floor(rand() * 3);
    const tagList = [];
    while (tagList.length < n) {
      const t = tags[Math.floor(rand() * tags.length)];
      if (!tagList.includes(t)) tagList.push(t);
    }
    return {
      id: i + 1,
      slug: title.toLowerCase().replace(/[^\w\s-]/g, '').replace(/\s+/g, '-'),
      title,
      description: `${title.split(' ').slice(0, 4).join(' ')}: notes, examples and trade-offs.`,
      body: body(rand, title),
      tagList,
      createdAt: at,
      updatedAt: at,
      authorId: (i % users.length) + 1,
      favoritedBy: new Set(users.filter(() => rand() < 0.35).map((u) => u.id)),
    };
  });

  const lines = [
    'Great write-up, thanks for sharing.',
    'I measured this on my own project and saw the same thing.',
    'Could you expand on the caching part?',
    'This matches my experience with slow Android phones.',
    'Bookmarked. The examples are really clear.',
  ];
  const comments = [];
  for (const a of articles) {
    const n = Math.floor(rand() * 4);
    for (let k = 0; k < n; k++) {
      const at = new Date(Date.parse(a.createdAt) + (k + 1) * 3600000).toISOString();
      comments.push({
        id: comments.length + 1,
        articleId: a.id,
        authorId: 1 + Math.floor(rand() * users.length),
        body: lines[Math.floor(rand() * lines.length)],
        createdAt: at,
        updatedAt: at,
      });
    }
  }

  const follows = new Set(['1>2', '2>1', '3>1', '4>2']);
  return {
    users,
    articles,
    comments,
    follows,
    ids: { user: users.length, article: articles.length, comment: comments.length },
  };
}

/** Avatar for a seed user: a colored circle with the initial. */
export function avatar(name) {
  const hue = [...name].reduce((h, c) => (h * 31 + c.charCodeAt(0)) % 360, 7);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><circle cx="32" cy="32" r="32" fill="hsl(${hue} 55% 55%)"/><text x="32" y="42" font-family="sans-serif" font-size="28" text-anchor="middle" fill="#fff">${name[0].toUpperCase()}</text></svg>`;
}
