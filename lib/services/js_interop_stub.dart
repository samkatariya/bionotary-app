/// Non-web stub (keeps mobile/other platforms compiling).
dynamic jsify(Map<String, dynamic> map) => map;

dynamic parseJsonToJsObject(String json) =>
    throw UnsupportedError('parseJsonToJsObject is web-only');

