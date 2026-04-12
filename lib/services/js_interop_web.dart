import 'dart:js_util' as js_util;

/// Plain object from JSON — avoids extra enumerable keys MetaMask rejects
/// (`Received unexpected keys on object parameter`).
dynamic parseJsonToJsObject(String json) =>
    js_util.callMethod(js_util.globalThis, 'JSON.parse', [json]);

/// Web-only JS interop helpers.
///
/// Flutter sometimes passes Dart `Map` objects to JS as wrapper objects
/// that can include extra/internal keys; some wallets reject those.
dynamic jsify(Map<String, dynamic> map) {
  // Build a clean, native JS object from a Dart Map.
  // Using `js_util.jsify()` can leak internal Dart VM keys (e.g. `$ti`)
  // into the resulting JS object, which can cause MetaMask to reject the
  // payload with JSON-RPC -32602.
  final jsObj = js_util.newObject();
  for (final entry in map.entries) {
    js_util.setProperty(jsObj, entry.key, _jsifyValue(entry.value));
  }
  return jsObj;
}

dynamic _jsifyValue(dynamic value) {
  if (value is Map<String, dynamic>) {
    final o = js_util.newObject();
    for (final e in value.entries) {
      js_util.setProperty(o, e.key, _jsifyValue(e.value));
    }
    return o;
  }
  if (value is Map) {
    final o = js_util.newObject();
    value.forEach((k, v) {
      js_util.setProperty(o, k.toString(), _jsifyValue(v));
    });
    return o;
  }
  if (value is List) {
    return js_util.jsify(value.map(_jsifyValue).toList());
  }
  return value;
}

