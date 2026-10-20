// ignore_for_file: thor_lints/avoid_raw_css
// (the Conduit theme of the RealWorld spec, ported rule for rule)
import 'package:thor_ui/html.dart';
import 'package:thor_ui/thor_ui.dart' show thorResetStyles;

/// What no widget covers: the theme's page basics (font, links) and the
/// small semantic lists (tag pills, pagination, error messages). The
/// article body has its own module sheet (`routes/article/styles.dart`).
final List<StyleRule> conduitStyles = [
  ...thorResetStyles,
  css('body').styles(
    raw: {
      'font-family': "'Source Sans Pro', sans-serif",
      'font-size': '16px',
      'line-height': '1.5',
      'color': '#373a3c',
      'background-color': '#fff',
    },
  ),
  // Unlayered app rules beat the widgets' (layered) CSS: only classes and
  // the page basics here, never a reset of margins or link colors.
  css(
    'ol, ul',
  ).styles(raw: {'list-style': 'none', 'margin': '0', 'padding': '0'}),
  css('.article-content a').styles(raw: {'color': '#33aa44'}),
  css('h1, h4, p').styles(raw: {'margin': '0'}),
  css(
    '.author a:hover, .comment-author:hover',
  ).styles(raw: {'text-decoration': 'underline'}),
  css('img').styles(raw: {'vertical-align': 'middle'}),
  css('img.avatar').styles(
    raw: {
      'border-radius': '50%',
      'display': 'inline-block',
      'object-fit': 'cover',
    },
  ),
  // Tag pills.
  css('.tag-default').styles(
    raw: {
      'background-color': 'transparent',
      'color': '#222',
      'border': '1px solid #eee',
      'border-radius': '100px',
      'font-size': '0.8rem',
      'line-height': '1.1rem',
      'padding': '0.35rem 0.75rem',
      'white-space': 'nowrap',
      'margin-right': '0.5rem',
      'margin-bottom': '0.5rem',
      'display': 'inline-block',
      'text-decoration': 'none',
      'transition': 'background 300ms ease',
    },
  ),
  // `.tag-default` comes after `.tag-pill` in the theme: its padding wins.
  css('.tag-pill').styles(raw: {'border-radius': '10rem'}),
  css('a.tag-default:hover').styles(
    raw: {
      'text-decoration': 'none',
      'background-color': '#eee',
      'color': '#222',
    },
  ),
  css('.tag-default.tag-outline').styles(
    raw: {
      'border': '1px solid #eee',
      'color': '#aaa',
      'background': 'none',
      'font-weight': '300',
      'padding-top': '0',
      'padding-bottom': '0',
    },
  ),
  css(
    '.preview-link .tag-list',
  ).styles(raw: {'max-width': '50%', 'text-align': 'right'}),
  // Pagination.
  css(
    '.pagination',
  ).styles(raw: {'display': 'inline-block', 'margin': '1rem 0'}),
  css('.page-item').styles(raw: {'display': 'inline'}),
  css('.page-link').styles(
    raw: {
      'position': 'relative',
      'float': 'left',
      'padding': '0.5rem 0.75rem',
      'margin-left': '-1px',
      'color': '#33aa44',
      'background-color': '#fff',
      'border': '1px solid #eee',
    },
  ),
  css('.page-link:hover').styles(
    raw: {
      'color': '#237630',
      'background-color': '#eceeef',
      'text-decoration': 'none',
    },
  ),
  css('.page-item:first-child .page-link').styles(
    raw: {
      'margin-left': '0',
      'border-top-left-radius': '0.5rem',
      'border-bottom-left-radius': '0.5rem',
    },
  ),
  css('.page-item:last-child .page-link').styles(
    raw: {
      'border-top-right-radius': '0.5rem',
      'border-bottom-right-radius': '0.5rem',
    },
  ),
  css('.page-item.active .page-link').styles(
    raw: {
      'z-index': '2',
      'color': '#222',
      'cursor': 'default',
      'background-color': '#eee',
      'border-color': '#eee',
    },
  ),
  // Validation messages.
  css('.error-messages').styles(
    raw: {
      'color': '#b85c5c',
      'font-weight': 'bold',
      'padding-left': '2.5rem',
      'margin-bottom': '1rem',
      'list-style': 'disc',
    },
  ),
  css('ul.tag-list').styles(raw: {'display': 'inline-block'}),
  // The comment card's text keeps line breaks.
  css(
    '.card-text',
  ).styles(raw: {'white-space': 'pre-wrap', 'overflow-wrap': 'anywhere'}),
];
