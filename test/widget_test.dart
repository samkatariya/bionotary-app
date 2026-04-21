import 'package:flutter_test/flutter_test.dart';
import 'package:bionotary/app_config.dart';

void main() {
  test('AppConfig resolves API base URL', () {
    expect(AppConfig.resolvedApiBaseUrl.isNotEmpty, true);
  });
}
