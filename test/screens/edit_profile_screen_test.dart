import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EditProfileScreen simplification', () {
    late String source;

    setUp(() {
      source = File('lib/screens/edit_profile_screen.dart').readAsStringSync();
    });

    test('does not contain email field', () {
      expect(
        source.contains('emailController') ||
            source.contains('prefixIcon: const Icon(Icons.email'),
        isFalse,
        reason: 'E-posta alanı kaldırılmış olmalı',
      );
    });

    test('does not contain blood type field', () {
      expect(
        source.contains('bloodtype') || source.contains('bloodType') ||
            source.contains('_bloodTypes'),
        isFalse,
        reason: 'Kan grubu alanı kaldırılmış olmalı',
      );
    });

    test('does not contain allergies field', () {
      expect(
        source.contains('allergies') || source.contains('_allergiesController'),
        isFalse,
        reason: 'Alerjiler alanı kaldırılmış olmalı',
      );
    });

    test('does not contain medical conditions field', () {
      expect(
        source.contains('_medicalController') ||
            source.contains('medicalConditions'),
        isFalse,
        reason: 'Kronik hastalıklar alanı kaldırılmış olmalı',
      );
    });

    test('does not contain emergency notes field', () {
      expect(
        source.contains('_emergencyNotesController') ||
            source.contains('emergencyNotes'),
        isFalse,
        reason: 'Acil durum notu alanı kaldırılmış olmalı',
      );
    });
  });
}
