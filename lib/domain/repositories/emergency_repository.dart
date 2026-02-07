abstract class EmergencyRepository {
  Future<void> createEmergencyEvent({
    required String title,
    required String message,
    required double? lat,
    required double? lng,
  });

  Future<void> updateLocation({
    required double lat,
    required double lng,
  });
}
