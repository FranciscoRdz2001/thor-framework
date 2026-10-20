import 'package:thor_ui/thor_ui.dart';

import '../icons.dart' as icons;
import '../theme.dart';
import '../ui.dart';

class Pricing extends StatelessWidget implements ThorElementWidget {
  const Pricing({super.key});

  static const _plans = [
    (
      'Free',
      false,
      0,
      'Start Free Trial',
      [
        '1 team member',
        '1 GB storage',
        'Up to 2 sites',
        'Community support',
        'Shared previews',
      ],
    ),
    (
      'Premium',
      true,
      45,
      'Get Started',
      [
        '4 team members',
        '8 GB storage',
        'Up to 6 sites',
        'Priority support',
        'Shared previews',
      ],
    ),
    (
      'Enterprise',
      false,
      120,
      'Contact Us',
      [
        '10 team members',
        '20 GB storage',
        'Up to 10 sites',
        'Phone & email support',
        'Shared previews',
      ],
    ),
  ];

  static const _description =
      'Everything you need to publish and grow your sites.';

  static Widget _plan(
    String title,
    bool popular,
    int price,
    String button,
    List<String> benefits,
  ) => Styled(
    style: const StyleProps().when(
      hover: StyleProps(scale: popular ? 1.12 : 1.05),
    ),
    duration: const Duration(milliseconds: 200),
    child: Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        ShadCard(
          children: [
            CardHeader(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CardTitle(title, size: 18, smSize: 20),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _description,
                    style: ThemeText.bodySmall
                        .copyWith(color: mutedForeground)
                        .when(medium: text(16)),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '\$$price',
                      style: text(
                        24,
                        weight: FontWeight.w700,
                      ).when(medium: text(30)),
                    ),
                    Text(
                      '\u00a0/month',
                      style: text(
                        14,
                        color: mutedForeground,
                      ).when(medium: text(16)),
                    ),
                  ],
                ),
              ],
            ),
            Padding(
              padding: cardBody,
              child: Column(
                spacing: 12,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final b in benefits)
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Styled(
                            style: const StyleProps().when(
                              medium: const StyleProps(width: 20, height: 20),
                            ),
                            child: const Icon(
                              icons.check,
                              size: 16,
                              color: primary,
                            ),
                          ),
                        ),
                        Text(b, style: text(14).when(medium: text(16))),
                      ],
                    ),
                ],
                layout: const FlexLayout().when(
                  medium: const FlexLayout(spacing: 16),
                ),
              ),
            ),
            Padding(
              padding: cardBody,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: null,
                  href: '#contact',
                  style: popular ? primaryButton : secondaryButton,
                  child: Text(button),
                ),
              ),
            ),
          ],
        ),
        if (popular)
          Positioned(
            top: -16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      offset: Offset(0, 10),
                      blurRadius: 15,
                      spreadRadius: -3,
                    ),
                  ],
                ),
                child: Text(
                  'Most Popular',
                  softWrap: false,
                  style: text(
                    12,
                    weight: FontWeight.w500,
                    color: primaryForeground,
                  ).when(medium: text(14)),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Section(
    id: 'pricing',
    padding: 64,
    children: [
      const SectionHeading(
        eyebrow: 'Pricing',
        title: 'Get unlimited access',
        subtitle: 'Simple plans for every team. Prices are fictional.',
        bottom: 56,
      ),
      // One layout for both sizes: a stack of cards that becomes three
      // columns (no second copy of the list hidden at one size).
      Grid(
        layout: const GridLayout(
          columnGap: 32,
          rowGap: 24,
        ).when(expanded: const GridLayout(columns: 3)),
        children: [
          for (final (title, popular, price, button, benefits) in _plans)
            _plan(title, popular, price, button, benefits),
        ],
      ),
    ],
  );
}

class Contact extends StatelessWidget implements ThorElementWidget {
  const Contact({super.key});

  static const _info = [
    (icons.building2, 'Find Us', ['100 Example Street, Sampletown']),
    (icons.phone, 'Call Us', ['+1 (555) 010-0000']),
    (icons.mail, 'Mail Us', ['hello@example.com']),
    (icons.clock, 'Visit Us', ['Monday - Friday', '8AM - 4PM']),
  ];

  static const _subjects = [
    'Getting Started',
    'Billing',
    'Technical Support',
    'Partnerships',
    'Other',
  ];

  static const _input = InputDecoration(
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(6)),
      borderSide: BorderSide(color: border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(6)),
      borderSide: BorderSide(color: foreground, width: 2),
    ),
    filled: true,
    fillColor: background,
    hintStyle: TextStyle(color: mutedForeground),
  );

  static Widget _field(String label, String id, Widget control) => Column(
    spacing: 6,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      WrapWith(
        WrapData(tag: 'label', attributes: {'for': id}),
        child: Text(label, style: ThemeText.labelLarge),
      ),
      control,
    ],
  );

  static Widget _text(
    String label,
    String id,
    String hint, {
    TextInputType type = TextInputType.text,
  }) => _field(
    label,
    id,
    TextField(
      id: id,
      name: id,
      keyboardType: type,
      style: text(14),
      decoration: _input.copyWith(hintText: hint),
    ),
  );

  @override
  Widget build(BuildContext context) => Section(
    id: 'contact',
    children: [
      Semantics(
        role: SemanticsRole.region,
        child: Grid(
          layout: const GridLayout(
            gap: 32,
          ).when(medium: const GridLayout(columns: 2)),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeading(
                  eyebrow: 'Contact',
                  title: 'Connect With Us',
                  center: false,
                  gap: 0,
                  bottom: 16,
                ),
                Styled(
                  style: const StyleProps().when(
                    expanded: const StyleProps(widthFactor: 5 / 6),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 32),
                    child: Text(
                      'Questions about plans, migrations or a demo? Send us '
                      'a message and the team will get back to you within a '
                      'business day.',
                      style: TextStyle(color: mutedForeground),
                    ),
                  ),
                ),
                Column(
                  spacing: 16,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (icon, title, lines) in _info)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              spacing: 8,
                              children: [
                                Icon(icon),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final l in lines) Text(l),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            ShadCard(
              color: surfaceStrong,
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.all(24),
                  // Without JS the browser opens the mail client with the
                  // fields in the body.
                  child: Form(
                    action: 'mailto:hello@example.com',
                    child: Column(
                      spacing: 16,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Grid(
                          layout: const GridLayout(
                            gap: 32,
                          ).when(medium: const GridLayout(columns: 2)),
                          children: [
                            _text('First Name', 'firstName', 'Jane'),
                            _text('Last Name', 'lastName', 'Doe'),
                          ],
                        ),
                        _text(
                          'Email',
                          'contactEmail',
                          'jane@example.com',
                          type: TextInputType.emailAddress,
                        ),
                        _field(
                          'Subject',
                          'contactSubject',
                          Styled(
                            classes: const ['select'],
                            child: DropdownButton<String>(
                              id: 'contactSubject',
                              name: 'subject',
                              isExpanded: true,
                              value: _subjects.first,
                              items: [
                                for (final s in _subjects)
                                  DropdownMenuItem(value: s, child: Text(s)),
                              ],
                            ),
                          ),
                        ),
                        _field(
                          'Message',
                          'contactMessage',
                          TextField(
                            id: 'contactMessage',
                            name: 'body',
                            maxLines: 5,
                            style: text(14),
                            decoration: _input.copyWith(
                              hintText: 'Your message...',
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: FilledButton(
                            buttonType: ButtonType.submit,
                            onPressed: () {},
                            style: primaryButton,
                            child: const Text('Send message'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class Faq extends StatelessWidget implements ThorElementWidget {
  const Faq({super.key});

  static const _faq = [
    (
      'Is Thor Starter free?',
      'Yes. It is a fictional product: this page only exists to test thor.',
    ),
    (
      'Do I need to know CSS?',
      'No. Layout, spacing and colors come from widgets and the theme; the '
          'CSS is generated for you when the page renders.',
    ),
    (
      'Does the page work without JavaScript?',
      'Yes. Menus, the drawer, the theme switch and this accordion are '
          'native HTML.',
    ),
    (
      'Where can I deploy it?',
      'Any static host, or anywhere a small server can run.',
    ),
    (
      'Can I switch plans later?',
      'Any time. Plans change at the next billing cycle.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Section(
    id: 'faq',
    maxWidth: 700,
    children: [
      const SectionHeading(eyebrow: 'FAQS', title: 'Common Questions', gap: 0),
      // A single-open accordion = native exclusive <details>.
      Styled(
        classes: const ['accordion'],
        child: ExpansionPanelList(
          name: 'faq',
          children: [
            for (final (question, answer) in _faq)
              ExpansionTile(
                title: Text(question),
                childrenPadding: const EdgeInsets.only(bottom: 16),
                children: [Text(answer, style: ThemeText.bodySmall)],
              ),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Row(
          children: [
            Semantics(
              headingLevel: 3,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Still have questions? '),
                    WidgetSpan(
                      child: Link(
                        href: RouteUrl('#contact'),
                        child: Text(
                          'Contact us',
                          style: TextStyle(
                            color: mutedForeground,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class Footer extends StatelessWidget implements ThorElementWidget {
  const Footer({super.key});

  static const _columns = [
    (
      'Contact',
      [
        ('Github', 'https://github.com'),
        ('Twitter', 'https://twitter.com'),
        ('Instagram', 'https://instagram.com'),
      ],
    ),
    ('Platforms', [('iOS', null), ('Android', null), ('Web', null)]),
    (
      'Help',
      [('Contact Us', '#contact'), ('FAQ', '#faq'), ('Feedback', '#contact')],
    ),
    (
      'Socials',
      [
        ('Twitch', 'https://twitch.tv'),
        ('Discord', 'https://discord.com'),
        ('Dribbble', 'https://dribbble.com'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => Section(
    id: 'footer',
    role: SemanticsRole.contentInfo,
    bottom: 64,
    smBottom: 96,
    children: [
      Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Grid(
              layout: const GridLayout(columns: 2, columnGap: 48, rowGap: 32)
                  .when(
                    medium: const GridLayout(columns: 4),
                    large: const GridLayout(columns: 6),
                  ),
              alignItems: CrossAxisAlignment.start,
              children: [
                const Styled(classes: ['footer-brand'], child: Logo(size: 24)),
                for (final (title, links) in _columns)
                  Column(
                    spacing: 8,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        headingLevel: 3,
                        child: Text(
                          title,
                          style: ThemeText.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      for (final (label, href) in links)
                        Styled(
                          style: const StyleProps().when(
                            hover: const StyleProps(opacity: 1),
                          ),
                          child: Opacity(
                            opacity: 0.6,
                            child: href == null
                                ? Text(label)
                                : Link(
                                    href: RouteUrl(href),
                                    child: Text(label),
                                  ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            const Divider(height: 48, color: border),
            Semantics(
              headingLevel: 3,
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: '© 2026 Thor Starter. Made with '),
                    WidgetSpan(
                      child: Styled(
                        style: const StyleProps().when(
                          hover: const StyleProps(
                            // The link is the text's own <a>: a Container
                            // would wrap it in another element.
                            // ignore: thor_lints/widget_props_in_styled
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: primary, width: 2),
                              ),
                            ),
                          ),
                        ),
                        duration: const Duration(milliseconds: 150),
                        child: const Link(
                          href: RouteUrl('#features'),
                          child: Text('thor', style: TextStyle(color: primary)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
