import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Empty catch blocks in critical services', () {
    test('local_logger_service should log errors in catch blocks', () {
      final source = File('lib/core/services/local_logger_service.dart').readAsStringSync();
      final catches = RegExp(r'catch\s*\([^)]*\)\s*\{(\s*)\}').allMatches(source);
      expect(catches.length, 0,
          reason: 'local_logger_service should not have empty catch blocks');
    });
  });

  group('Empty catch blocks in battery_optimization_service', () {
    test('battery_optimization_service should log errors in catch blocks', () {
      final source = File('lib/core/services/battery_optimization_service.dart').readAsStringSync();
      final catches = RegExp(r'catch\s*\([^)]*\)\s*\{(\s*)\}').allMatches(source);
      expect(catches.length, 0,
          reason: 'battery_optimization_service should not have empty catch blocks');
    });
  });
}
