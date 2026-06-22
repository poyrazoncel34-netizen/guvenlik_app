import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// D3: in the "Yeni Kişi Ekle" sheet the keyboard could cover the phone field.
/// The sheet already uses isScrollControlled + viewInsets padding; additionally
/// the focused phone field must be scrolled above the keyboard via
/// Scrollable.ensureVisible on focus.
void main() {
  test('add-contact sheet lifts the focused phone field above the keyboard',
      () {
    final src = File('lib/screens/contacts_page.dart').readAsStringSync();
    // sheet keeps the proven keyboard-aware base
    expect(src.contains('isScrollControlled: true'), isTrue);
    expect(src.contains('MediaQuery.of(sheetContext).viewInsets.bottom'), isTrue);
    // phone field has a focus node that drives ensure-visible
    expect(src.contains('phoneFocusNode'), isTrue);
    expect(src.contains('focusNode: phoneFocusNode'), isTrue);
    expect(src.contains('Scrollable.ensureVisible'), isTrue);
    // focus node is disposed
    expect(src.contains('phoneFocusNode.dispose()'), isTrue);
  });
}
