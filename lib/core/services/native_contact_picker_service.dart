// ============================================================================
// NATIVE CONTACT PICKER SERVICE
// ============================================================================
// Single access path to the permissionless native contact picker.
//
// The picker uses Intent.ACTION_PICK on the phone data URI, which grants the
// app temporary read access to just the picked row -- no READ_CONTACTS runtime
// permission and no broad address-book access.
//
// This lived inline in contacts_page.dart. Onboarding now needs the same
// picker, and a second inline channel call would be a second access path to one
// platform capability (a known anti-pattern in this repo), so the channel, the
// payload parsing and the outcome classification live here instead.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/emergency_number_validator.dart';

/// A phone contact returned by the native picker.
class PickedPhoneContact {
  const PickedPhoneContact({required this.name, required this.number});
  final String name;
  final String number;
}

/// Why a pick attempt produced no callable contact.
///
/// Cancelling is a normal outcome and must stay silent; an unavailable picker is
/// a failure the caller should surface, so the two are not collapsed into a
/// single null. A contact without a number and a number that cannot be called
/// are told apart as well: reporting the second as "no number" sent users
/// looking for a number that was right there.
enum ContactPickStatus { picked, cancelled, unavailable, noNumber, invalidNumber }

class NativeContactPickResult {
  const NativeContactPickResult._(this.status, this.contact, [this.rejected]);

  const NativeContactPickResult.picked(PickedPhoneContact contact)
    : this._(ContactPickStatus.picked, contact);

  const NativeContactPickResult.cancelled()
    : this._(ContactPickStatus.cancelled, null);

  const NativeContactPickResult.unavailable()
    : this._(ContactPickStatus.unavailable, null);

  const NativeContactPickResult.noNumber()
    : this._(ContactPickStatus.noNumber, null);

  const NativeContactPickResult.invalidNumber(PickedPhoneContact rejected)
    : this._(ContactPickStatus.invalidNumber, null, rejected);

  final ContactPickStatus status;

  /// Non-null only for [ContactPickStatus.picked]; its number is the canonical
  /// callable target, ready to store.
  final PickedPhoneContact? contact;

  /// Non-null only for [ContactPickStatus.invalidNumber]: the number as the
  /// contact book holds it, sanitized, so a form can offer it for correction.
  final PickedPhoneContact? rejected;

  bool get isUnavailable => status == ContactPickStatus.unavailable;

  /// The message both screens show when a pick produced nothing callable.
  String? get failureMessageKey => switch (status) {
    ContactPickStatus.noNumber => 'contacts_no_phone',
    ContactPickStatus.invalidNumber => 'contacts_picked_invalid_phone',
    ContactPickStatus.picked ||
    ContactPickStatus.cancelled ||
    ContactPickStatus.unavailable => null,
  };
}

/// Parses the {name, number} map returned by the picker channel. Returns null
/// when the user cancelled or no usable number came back.
PickedPhoneContact? parsePickedPhoneContact(Map<dynamic, dynamic>? raw) {
  if (raw == null) return null;
  // Channel data is checked, not cast: a cast TypeError would escape
  // pickPhoneContact, which only catches the channel's own exceptions.
  final rawNumber = raw['number'];
  final number = rawNumber is String ? rawNumber.trim() : '';
  if (number.isEmpty) return null;
  final rawName = raw['name'];
  final name = rawName is String ? rawName.trim() : '';
  return PickedPhoneContact(name: name, number: number);
}

/// Classifies one picker reply through the same boundary as manual entry.
///
/// A null reply is the user backing out. A number that is empty once
/// contact-book formatting is removed is [ContactPickStatus.noNumber]; one that
/// is present but not callable is [ContactPickStatus.invalidNumber].
NativeContactPickResult classifyPickedPhoneContact(Object? raw) {
  if (raw is! Map) return const NativeContactPickResult.cancelled();
  final parsed = parsePickedPhoneContact(raw);
  if (parsed == null) return const NativeContactPickResult.noNumber();
  final shown = EmergencyNumberValidator.sanitizeContactInput(
    parsed.number,
  ).trim();
  if (shown.isEmpty) return const NativeContactPickResult.noNumber();
  final callable = EmergencyNumberValidator.normalizedContactInputOrNull(shown);
  if (callable == null) {
    return NativeContactPickResult.invalidNumber(
      PickedPhoneContact(name: parsed.name, number: shown),
    );
  }
  return NativeContactPickResult.picked(
    PickedPhoneContact(name: parsed.name, number: callable),
  );
}

class NativeContactPickerService {
  NativeContactPickerService._();

  static const MethodChannel channel = MethodChannel(
    'com.poyrazoncel.korubeni/contacts_picker',
  );

  /// Launches the native single-contact picker.
  ///
  /// Never throws: a missing channel (web, iOS, a stripped build) and a
  /// platform-side failure both resolve to [ContactPickStatus.unavailable] so
  /// the calling screen can degrade to manual entry instead of crashing.
  static Future<NativeContactPickResult> pickPhoneContact() async {
    if (kIsWeb) return const NativeContactPickResult.unavailable();
    try {
      final raw = await channel.invokeMethod<dynamic>('pickPhoneContact');
      return classifyPickedPhoneContact(raw);
    } on PlatformException catch (e) {
      debugPrint('Contact picker channel error: ${e.code}');
      return const NativeContactPickResult.unavailable();
    } on MissingPluginException catch (e) {
      debugPrint('Contact picker channel missing: ${e.message}');
      return const NativeContactPickResult.unavailable();
    }
  }
}
