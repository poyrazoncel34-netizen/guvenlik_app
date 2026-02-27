// Flutter test config - runs before all tests.
// Ensures EasyLocalization and SharedPreferences work in tests.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

Future<void> testExecutable(Future<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  // Suppress "key not found" warnings in tests - keys exist in assets, path can differ in test env
  EasyLocalization.logger.enableLevels = [];
  await testMain();
}
