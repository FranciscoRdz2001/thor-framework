import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Whether [e] is a data class: a class (of the app or of a package, never
/// the SDK's) with a `toJson()` that takes nothing and a `factory
/// fromJson(…)` that takes the decoded value. The one definition the
/// builder's registry (`registerJsonModel`, query types) and the lite
/// translator (how a `state(...)` field is read back) share.
bool isJsonDataClass(Element? e) {
  if (e is! ClassElement || e.library.uri.scheme == 'dart') return false;
  final toJson = e.getMethod('toJson');
  final fromJson = e.getNamedConstructor('fromJson');
  return toJson != null &&
      toJson.formalParameters.isEmpty &&
      fromJson != null &&
      fromJson.isFactory &&
      fromJson.formalParameters.length == 1;
}

/// The data class (see [isJsonDataClass]) a `state(...)` field of value
/// type [t] holds: the class itself, or the element of a `List` or the
/// value of a String-keyed `Map` (nullable or not), else null.
InterfaceType? jsonStateModel(DartType t) {
  if (t is! InterfaceType) return null;
  if (t.isDartCoreList) return jsonStateModel(t.typeArguments.single);
  if (t.isDartCoreMap) {
    return t.typeArguments.first.isDartCoreString
        ? jsonStateModel(t.typeArguments.last)
        : null;
  }
  return isJsonDataClass(t.element) ? t : null;
}
