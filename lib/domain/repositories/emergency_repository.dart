abstract class EmergencyRepository {
  Future<void> createEmergencyEvent({
    required String title,
    required String message,
    required double? lat,
    required double? lng,
  });

  Future<void> updateLocation({required double lat, required double lng});

  /// Kullanıcının tüm acil durum geçmişini getirir (en yeniden eskiye).
  Future<List<Map<String, dynamic>>> getEmergencyHistory({int limit = 20});

  /// Kullanıcının aktif (status == 'active') acil durumlarını getirir.
  Future<List<Map<String, dynamic>>> getActiveEmergencies();
}
