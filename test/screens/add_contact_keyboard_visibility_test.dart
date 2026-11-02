import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// D3: in the "Yeni Kişi Ekle" sheet the keyboard could cover the phone field.
/// The sheet already uses isScrollControlled + viewInsets padding; additionally
/// the focused phone field must be scrolled above the keyboard via
/// Scrollable.ensureVisible on focus.
void main() {
  test('add-contact sheet lifts the focused phone field above the keyboard',
      () {
    final page = File('lib/screens/contacts_page.dart').readAsStringSync();
    // The sheet's tree and its focus node live in AddContactSheet; the page
    // keeps the showModalBottomSheet call.
    final src = File('lib/core/widgets/add_contact_sheet.dart').readAsStringSync();
    // sheet keeps the proven keyboard-aware base
    expect(page.contains('isScrollControlled: true'), isTrue);
    expect(src.contains('MediaQuery.of(context).viewInsets.bottom'), isTrue);
    // phone field has a focus node that drives ensure-visible
    expect(src.contains('_phoneFocusNode'), isTrue);
    expect(src.contains('focusNode: _phoneFocusNode'), isTrue);
    expect(src.contains('Scrollable.ensureVisible'), isTrue);
    // focus node is disposed
    expect(src.contains('_phoneFocusNode.dispose()'), isTrue);
  });
}
