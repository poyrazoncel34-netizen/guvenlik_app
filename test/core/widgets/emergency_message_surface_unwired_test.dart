// The emergency-message surface must stay unwired until someone decides what
// it may contain.
//
// `EmergencyFailureDialog.show` and `EmergencyCallScreen` both accept an
// optional `emergencyMessage`. When it is non-null they render a selectable
// panel AND a "copy message" button that writes the text to the system
// clipboard. No caller passes it today: the affordance is a remnant of the
// removed SMS flow, which is why its translation keys exist while nothing
// reaches them.
//
// Why pin it instead of deleting it
// ---------------------------------
// Deleting it would be a product decision about a prepared surface, and the
// surface is harmless while it is unreachable. What is NOT harmless is wiring
// it back without thinking: the clipboard is readable by the active IME, and
// Android 13+ shows a preview of copied text. A message built from the
// emergency payload would put a contact name, a phone number or coordinates
// there, which the duress model treats as the data an attacker wants most.
//
// So this test is a tripwire, not a prohibition. If you intend to use the
// surface, update this test deliberately and state in the same change what the
// message contains and why the clipboard is an acceptable destination for it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source with `//` line comments removed, so prose about the parameter cannot
/// masquerade as a call site (this file's own header would otherwise match).
String _codeOnly(String source) => source
    .split('\n')
    .map((line) {
      final comment = line.indexOf('//');
      return comment == -1 ? line : line.substring(0, comment);
    })
    .join('\n');

List<File> _libSources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  test('no production call site passes emergencyMessage', () {
    final wired = <String>[];
    for (final file in _libSources()) {
      final lines = _codeOnly(file.readAsStringSync()).split('\n');
      for (var index = 0; index < lines.length; index++) {
        // The named-argument form is the only way to pass an optional named
        // parameter, so this is the complete set of call sites. The constructor
        // declaration (`this.emergencyMessage,`) and the field reads
        // (`widget.emergencyMessage`) do not match.
        if (lines[index].contains('emergencyMessage:')) {
          wired.add('${file.path}:${index + 1}');
        }
      }
    }

    expect(
      wired,
      isEmpty,
      reason:
          'Something now passes emergencyMessage, which puts its text on the '
          'system clipboard behind a "copy" button. Before updating this test, '
          'say what that text contains: a contact name, a phone number or a '
          'location must not reach the clipboard, where the active IME can '
          'read it and Android 13+ previews it.\nWired at:\n  '
          '${wired.join('\n  ')}',
    );
  });
}
