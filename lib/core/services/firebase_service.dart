import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import '../../domain/models/user_profile.dart';
import 'network_retry_service.dart';
import 'breadcrumb_service.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final _db = FirebaseFirestore.instance;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> upsertUserProfile() async {
    BreadcrumbService.instance.add('Firebase: upsertUserProfile');
    
    final result = await NetworkRetryService.instance.executeWithRetry(
      operation: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not authenticated');

        final token = await FirebaseMessaging.instance.getToken();
        await _db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'phone': user.phoneNumber,
          'fcmToken': token,
          'lastActiveAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        return true;
      },
      operationName: 'upsertUserProfile',
      timeout: Duration(seconds: 10),
    );
    
    if (!result.success) {
      throw Exception('Failed to upsert user profile: ${result.errorMessage}');
    }
  }

  void listenForTokenUpdates() {
    _tokenSubscription?.cancel();
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        await _db.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastActiveAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e, stack) {
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'tokenRefresh failed',
        );
      }
    });
  }

  Future<void> createEmergencyEvent({
    required String title,
    required String message,
    required double? lat,
    required double? lng,
  }) async {
    BreadcrumbService.instance.add('Firebase: createEmergencyEvent - $title');
    
    final result = await NetworkRetryService.instance.executeWithRetry(
      operation: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not authenticated');

        // Data validation
        final validTitle = _sanitizeString(title, maxLength: 200);
        final validMessage = _sanitizeString(message, maxLength: 1000);
        final validLat = _clampLatitude(lat);
        final validLng = _clampLongitude(lng);

        await _db.collection('emergencies').add({
          'userId': user.uid,
          'title': validTitle,
          'message': validMessage,
          'lat': validLat,
          'lng': validLng,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'active',
        });
        
        return true;
      },
      operationName: 'createEmergencyEvent',
      timeout: Duration(seconds: 10),
      maxAttempts: 5, // Critical operation - more retries
    );
    
    if (!result.success) {
      throw Exception('Failed to create emergency event: ${result.errorMessage}');
    }
  }

  Future<void> updateLocation({
    required double lat,
    required double lng,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final validLat = _clampLatitude(lat) ?? lat;
      final validLng = _clampLongitude(lng) ?? lng;

      await _db.collection('locations').doc(user.uid).set({
        'lat': validLat,
        'lng': validLng,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'updateLocation failed',
      );
    }
  }

  Future<void> logActivity({
    required String type,
    required String title,
    String? description,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _db.collection('users').doc(user.uid).collection('activities').add({
        'type': _sanitizeString(type, maxLength: 50),
        'title': _sanitizeString(title, maxLength: 200),
        'description': _sanitizeString(description ?? '', maxLength: 500),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'logActivity failed',
      );
    }
  }

  // =========================================================================
  // Profile Management
  // =========================================================================

  /// Kullanıcı profilini Firestore'dan getirir.
  Future<UserProfile?> getUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) return null;

      return UserProfile.fromJson(doc.data()!);
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'getUserProfile failed',
      );
      return null;
    }
  }

  /// Kullanıcı profilini günceller (displayName, email).
  Future<void> updateUserProfile({String? displayName, String? email}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final updates = <String, dynamic>{
        'lastActiveAt': FieldValue.serverTimestamp(),
      };
      if (displayName != null) {
        updates['displayName'] = _sanitizeString(displayName, maxLength: 100);
      }
      if (email != null) {
        updates['email'] = _sanitizeString(email, maxLength: 254);
      }

      await _db.collection('users').doc(user.uid).set(
            updates,
            SetOptions(merge: true),
          );
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'updateUserProfile failed',
      );
    }
  }

  /// Kullanıcı hesabını ve Firestore verilerini siler.
  Future<void> deleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Firestore verilerini sil
      final batch = _db.batch();

      // users/{uid} dokümanını sil
      batch.delete(_db.collection('users').doc(user.uid));

      // locations/{uid} dokümanını sil
      batch.delete(_db.collection('locations').doc(user.uid));

      await batch.commit();

      // Firebase Auth hesabını sil
      await user.delete();
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'deleteAccount failed',
      );
      rethrow;
    }
  }

  // =========================================================================
  // Emergency Queries
  // =========================================================================

  /// Kullanıcının acil durum geçmişini getirir.
  Future<List<Map<String, dynamic>>> getEmergencyHistory({
    int limit = 20,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final snapshot = await _db
          .collection('emergencies')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'getEmergencyHistory failed',
      );
      return [];
    }
  }

  /// Kullanıcının aktif acil durumlarını getirir.
  Future<List<Map<String, dynamic>>> getActiveEmergencies() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final snapshot = await _db
          .collection('emergencies')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'getActiveEmergencies failed',
      );
      return [];
    }
  }

  // =========================================================================
  // Validation Helpers
  // =========================================================================

  /// String'i sanitize eder — boş string ve max uzunluk kontrolü.
  String _sanitizeString(String value, {int maxLength = 500}) {
    final trimmed = value.trim();
    if (trimmed.length > maxLength) return trimmed.substring(0, maxLength);
    return trimmed;
  }

  /// Latitude değerini [-90, 90] aralığına sınırlar.
  double? _clampLatitude(double? lat) {
    if (lat == null) return null;
    return lat.clamp(-90.0, 90.0);
  }

  /// Longitude değerini [-180, 180] aralığına sınırlar.
  double? _clampLongitude(double? lng) {
    if (lng == null) return null;
    return lng.clamp(-180.0, 180.0);
  }

  void dispose() {
    _tokenSubscription?.cancel();
  }
}
