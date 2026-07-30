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

/// A phone contact returned by the native picker.
class PickedPhoneContact {
  const PickedPhoneContact({required this.name, required this.number});
  final String name;
  final String number;
}

/// Why a pick attempt produced no contact.
///
/// Cancelling is a normal outcome and must stay silent; an unavailable picker is
/// a failure the caller should surface, so the two are not collapsed into a
/// single null.
enum ContactPickStatus { picked, cancelled, unavailable }

class NativeContactPickResult {
  const NativeContactPickResult._(this.status, this.contact);

  const NativeContactPickResult.picked(PickedPhoneContact contact)
    : this._(ContactPickStatus.picked, contact);

  const NativeContactPickResult.cancelled()
    : this._(ContactPickStatus.cancelled, null);

  const NativeContactPickResult.unavailable()
    : this._(ContactPickStatus.unavailable, null);

  final ContactPickStatus status;
  final PickedPhoneContact? contact;

  bool get isUnavailable => status == ContactPickStatus.unavailable;
}

/// Parses the {name, number} map returned by the picker channel. Returns null
/// when the user cancelled or no usable number came back.
PickedPhoneContact? parsePickedPhoneContact(Map<dynamic, dynamic>? raw) {
  if (raw == null) return null;
  final number = (raw['number'] as String?)?.trim() ?? '';
  if (number.isEmpty) return null;
  final name = (raw['name'] as String?)?.trim() ?? '';
  return PickedPhoneContact(name: name, number: number);
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
      final picked = parsePickedPhoneContact(raw is Map ? raw : null);
      return picked == null
          ? const NativeContactPickResult.cancelled()
          : NativeContactPickResult.picked(picked);
    } on PlatformException catch (e) {
      debugPrint('Contact picker channel error: ${e.code}');
      return const NativeContactPickResult.unavailable();
    } on MissingPluginException catch (e) {
      debugPrint('Contact picker channel missing: ${e.message}');
      return const NativeContactPickResult.unavailable();
    }
  }
}
