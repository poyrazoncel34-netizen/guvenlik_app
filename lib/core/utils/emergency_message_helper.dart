import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../services/consent_gate_service.dart';
import '../services/emergency_core_service.dart';

class EmergencyMessagePayload {
  final String message;
  final String locationStatusMessage;
  final String? mapsUrl;
  final LocationSource locationSource;
  final int? locationAgeMinutes;

  const EmergencyMessagePayload({
    required this.message,
    required this.locationStatusMessage,
    required this.locationSource,
    this.mapsUrl,
    this.locationAgeMinutes,
  });

  bool get hasLocation => mapsUrl != null;
}

class EmergencyMessageHelper {
  EmergencyMessageHelper._();

  /// Görev 7: Acil durum SMS şablonu — hukuki feragatname içerir (TBK Md. 50)
  /// [userName]: Gönderen kişinin adı (profil adı)
  /// [locationUrl]: Google Maps linki veya konum bilgisi yoksa açıklama metni
  static String buildEmergencyMessage(String userName, String locationUrl) {
    return '⚠️ ACİL DURUM — KoruBeni\n\n'
        '$userName yardıma ihtiyaç duyuyor olabilir.\n\n'
        '📍 Son bilinen konum:\n'
        '$locationUrl\n\n'
        'Bu mesaj KoruBeni uygulaması tarafından otomatik gönderilmiştir.\n'
        'Uygulama acil servislerin yerini tutmaz.\n'
        'Gerekirse 112\'yi arayın.\n\n'
        'Saat: ${DateTime.now().toString()}';
  }

  /// Feragatname metni — tüm SMS mesajlarının sonuna eklenir
  static const String _legalDisclaimer =
      '\n\nBu mesaj KoruBeni uygulaması tarafından otomatik gönderilmiştir. '
      'Uygulama acil servislerin yerini tutmaz. Gerekirse 112\'yi arayın.';

  static Future<EmergencyMessagePayload> buildCountdownMessage({
    String? customTemplate,
  }) async {
    final locationResult = await _resolveLocation();
    final mapsUrl = _buildMapsUrl(locationResult);
    final baseMessage = _buildCountdownBaseMessage(
      locationResult: locationResult,
      mapsUrl: mapsUrl,
      customTemplate: customTemplate,
    );

    return _payloadFromLocation(
      locationResult: locationResult,
      baseMessage: baseMessage,
      mapsUrl: mapsUrl,
    );
  }

  static Future<EmergencyMessagePayload> buildPanicButtonMessage() async {
    final locationResult = await _resolveLocation();
    final mapsUrl = _buildMapsUrl(locationResult);
    final baseMessage = (mapsUrl != null
        ? 'countdown_emergency_msg'.tr(
            namedArgs: {
              'lat': locationResult.position!.latitude.toStringAsFixed(6),
              'lng': locationResult.position!.longitude.toStringAsFixed(6),
            },
          )
        : 'countdown_emergency_msg_no_loc'.tr()) +
        _legalDisclaimer;

    return _payloadFromLocation(
      locationResult: locationResult,
      baseMessage: baseMessage,
      mapsUrl: mapsUrl,
    );
  }

  static Future<EmergencyMessagePayload> buildCheckInMessage() async {
    final locationResult = await _resolveLocation();
    final mapsUrl = _buildMapsUrl(locationResult);
    final baseMessage = mapsUrl == null
        ? 'check_in_emergency_msg'.tr()
        : '${'check_in_emergency_msg'.tr()}\n$mapsUrl';

    return _payloadFromLocation(
      locationResult: locationResult,
      baseMessage: baseMessage,
      mapsUrl: mapsUrl,
    );
  }

  static Future<LocationResultWithSource> _resolveLocation() async {
    // KVKK m.5: Konum rızası kontrolü — rıza yoksa konum işlenmez
    if (!ConsentGateService.isLocationAllowed()) {
      return LocationResultWithSource(
        position: null,
        source: LocationSource.none,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final locationEnabled = prefs.getBool(AppConstants.prefLocation) ?? true;
    if (!locationEnabled) {
      return LocationResultWithSource(
        position: null,
        source: LocationSource.none,
      );
    }

    return EmergencyCoreService.instance.getLocationWithFallback(gpsTimeout: const Duration(seconds: 3));
  }

  static EmergencyMessagePayload _payloadFromLocation({
    required LocationResultWithSource locationResult,
    required String baseMessage,
    required String? mapsUrl,
  }) {
    final locationStatusMessage = _describeLocation(locationResult);
    final message = locationStatusMessage.isEmpty
        ? baseMessage
        : '$baseMessage\n$locationStatusMessage';

    return EmergencyMessagePayload(
      message: message,
      locationStatusMessage: locationStatusMessage,
      mapsUrl: mapsUrl,
      locationSource: locationResult.source,
      locationAgeMinutes: locationResult.ageMinutes,
    );
  }

  static String _buildCountdownBaseMessage({
    required LocationResultWithSource locationResult,
    required String? mapsUrl,
    String? customTemplate,
  }) {
    if (customTemplate != null && customTemplate.isNotEmpty) {
      return customTemplate.replaceAll(
        '{konum}',
        mapsUrl ?? 'countdown_location_unavailable'.tr(),
      );
    }

    if (mapsUrl == null) {
      return 'countdown_emergency_msg_no_loc'.tr();
    }

    return 'countdown_emergency_msg'.tr(
      namedArgs: {
        'lat': locationResult.position!.latitude.toStringAsFixed(6),
        'lng': locationResult.position!.longitude.toStringAsFixed(6),
      },
    );
  }

  static String? _buildMapsUrl(LocationResultWithSource locationResult) {
    final position = locationResult.position;
    if (position == null) {
      return null;
    }

    return 'https://www.google.com/maps/search/?api=1&query='
        '${position.latitude.toStringAsFixed(6)},'
        '${position.longitude.toStringAsFixed(6)}';
  }

  static String _describeLocation(LocationResultWithSource locationResult) {
    switch (locationResult.source) {
      case LocationSource.gps:
        return 'emergency_location_status_gps'.tr();
      case LocationSource.cached:
        final minutes = (locationResult.ageMinutes ?? 0).clamp(0, 9999);
        return 'emergency_location_status_cached'.tr(
          namedArgs: {'minutes': '$minutes'},
        );
      case LocationSource.system:
        return 'emergency_location_status_system'.tr();
      case LocationSource.ip:
        return 'emergency_location_status_system'.tr();
      case LocationSource.none:
        return 'emergency_location_status_unavailable'.tr();
    }
  }
}
