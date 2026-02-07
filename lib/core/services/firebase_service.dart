import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final _db = FirebaseFirestore.instance;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> upsertUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      await _db.collection('users').doc(user.uid).set(
        {
          'uid': user.uid,
          'phone': user.phoneNumber,
          'fcmToken': token,
          'lastActiveAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'upsertUserProfile failed');
    }
  }

  void listenForTokenUpdates() {
    _tokenSubscription?.cancel();
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        await _db.collection('users').doc(user.uid).set(
          {
            'fcmToken': token,
            'lastActiveAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (e, stack) {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'tokenRefresh failed');
      }
    });
  }

  Future<void> createEmergencyEvent({
    required String title,
    required String message,
    required double? lat,
    required double? lng,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _db.collection('emergencies').add({
        'userId': user.uid,
        'title': title,
        'message': message,
        'lat': lat,
        'lng': lng,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'createEmergencyEvent failed');
    }
  }

  Future<void> updateLocation({
    required double lat,
    required double lng,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _db.collection('locations').doc(user.uid).set(
        {
          'lat': lat,
          'lng': lng,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'updateLocation failed');
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
        'type': type,
        'title': title,
        'description': description ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'logActivity failed');
    }
  }

  void dispose() {
    _tokenSubscription?.cancel();
  }
}
