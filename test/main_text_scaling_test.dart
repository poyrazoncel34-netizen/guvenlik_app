import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guvenlik_app/main.dart';

void main() {
  test('app preserves system text scaling through 200 percent', () {
    expect(
      appTextScaler(const TextScaler.linear(1.5)).scale(10),
      closeTo(15, 0.01),
    );
    expect(
      appTextScaler(const TextScaler.linear(2)).scale(10),
      closeTo(20, 0.01),
    );
  });

  test('app bounds extreme text scaling at the declared 200 percent', () {
    expect(
      appTextScaler(const TextScaler.linear(3)).scale(10),
      closeTo(20, 0.01),
    );
  });
}
