import 'dart:js_util' as js_util;

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
    js_util.setProperty(jsObj, entry.key, entry.value);
  }
  return jsObj;
}

