/// Compact variant patches: what the export optimizer writes on the live
/// element (`data-tp-1="…"` for variant 1) instead of a `<template>` copy.
///
/// A patch is a list of [PatchOp]s against the live element: records
/// separated by `;`, fields by `|`, values percent-escaped:
/// `path|attr|=value` sets, `path|attr|-` removes. `path` is the chain of
/// element-child indices from the variant root (`0.2`, empty = the root);
/// `attr` `#` is the element's text.
library;

/// Prefix of the live element's attributes holding each variant's patch
/// (`data-tp-<index>`).
const patchAttr = 'data-tp';

/// A single change to apply to the element at [path]: set or remove [attr]
/// (or the element's text, when [attr] is `#`).
class PatchOp {
  /// Creates a patch operation.
  const PatchOp(this.path, this.attr, this.value);

  /// Chain of element-child indices from the variant root; empty is the
  /// root itself.
  final List<int> path;

  /// An attribute name, or `#` for the element's text.
  final String attr;

  /// `null` removes the attribute.
  final String? value;

  @override
  bool operator ==(Object other) =>
      other is PatchOp &&
      other.attr == attr &&
      other.value == value &&
      other.path.join('.') == path.join('.');

  @override
  int get hashCode => Object.hash(path.join('.'), attr, value);
}

String _escape(String v) =>
    v.replaceAll('%', '%25').replaceAll('|', '%7C').replaceAll(';', '%3B');

String _unescape(String v) =>
    v.replaceAll('%3B', ';').replaceAll('%7C', '|').replaceAll('%25', '%');

/// Encodes [ops] as the `data-tp-<index>` attribute value.
String encodePatch(List<PatchOp> ops) => [
  for (final op in ops)
    '${op.path.join('.')}|${op.attr}|${op.value == null ? '-' : '=${_escape(op.value!)}'}',
].join(';');

/// Parses a `data-tp-<index>` attribute value into its [PatchOp]s.
List<PatchOp> decodePatch(String encoded) => [
  if (encoded.isNotEmpty)
    for (final record in encoded.split(';')) _decodeOp(record.split('|')),
];

PatchOp _decodeOp(List<String> f) => PatchOp(
  f[0].isEmpty ? const [] : [for (final i in f[0].split('.')) int.parse(i)],
  f[1],
  f[2] == '-' ? null : _unescape(f[2].substring(1)),
);
