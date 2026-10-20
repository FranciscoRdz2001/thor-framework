// ignore_for_file: thor_lints/avoid_raw_css
// (the Conduit theme of the RealWorld spec, ported rule for rule)
import 'package:thor_ui/html.dart';

/// The article module's sheet: the article body, HTML rendered from
/// markdown. Only the pages under `/article` link it.
final styles = <StyleRule>[
  css(
    '.article-content h1, .article-content h2, .article-content h3, .article-content h4',
  ).styles(
    raw: {
      'font-weight': '500',
      'margin': '1.6rem 0 1rem 0',
      'line-height': '1.1',
    },
  ),
  css('.article-content h1').styles(raw: {'font-size': '2.5rem'}),
  css('.article-content h2').styles(raw: {'font-size': '2rem'}),
  css('.article-content h3').styles(raw: {'font-size': '1.75rem'}),
  css('.article-content p').styles(
    raw: {
      'font-family': "'Lora', serif",
      'font-size': '1.2rem',
      'line-height': '1.8rem',
      'margin-bottom': '2rem',
    },
  ),
  css(
    '.article-content ul, .article-content ol',
  ).styles(raw: {'margin-bottom': '1rem', 'padding-left': '2.5rem'}),
  css('.article-content ul').styles(raw: {'list-style': 'disc'}),
  css('.article-content ol').styles(raw: {'list-style': 'decimal'}),
  css(
    '.article-content pre',
  ).styles(raw: {'margin': '0', 'overflow': 'auto', 'max-width': '100%'}),
  css('.article-content code').styles(raw: {'font-size': '1rem'}),
  // The markdown block may shrink (a long code line scrolls instead).
  css('.article-body').styles(raw: {'min-width': '0'}),
];
