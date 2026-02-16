// File generated for Firebase Web + Android + iOS.
//
// WEB: Firebase Auth on web will fail until you add a Web app in Firebase Console and set the real appId below.
// Steps: Firebase Console > Project Settings > Your apps > Add app (Web </>) > copy the appId into web.appId.
// If you do not target web builds, you can leave REPLACE_WITH_WEB_APP_ID; only Android/iOS are used for store release.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        return web;
    }
  }

  /// Web: Replace REPLACE_WITH_WEB_APP_ID with the appId from Firebase Console (Add Web app). Required for web Auth.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA_5bRCYDDXZMBHhSAOn8psPeir9Pg-TFU',
    appId: '1:826866882826:web:REPLACE_WITH_WEB_APP_ID', // Set real Web appId from Firebase Console for web builds
    messagingSenderId: '826866882826',
    projectId: 'korubeni-prod',
    authDomain: 'korubeni-prod.firebaseapp.com',
    storageBucket: 'korubeni-prod.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA_5bRCYDDXZMBHhSAOn8psPeir9Pg-TFU',
    appId: '1:826866882826:android:bf364851aaa042623342f3',
    messagingSenderId: '826866882826',
    projectId: 'korubeni-prod',
    storageBucket: 'korubeni-prod.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDNhyDfoyyvck9pNDZ9-2oXX-owjEFgLhk',
    appId: '1:826866882826:ios:75a29b10cab916203342f3',
    messagingSenderId: '826866882826',
    projectId: 'korubeni-prod',
    storageBucket: 'korubeni-prod.firebasestorage.app',
    iosBundleId: 'com.poyrazoncel.korubeni',
  );
}
