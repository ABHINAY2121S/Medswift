// File generated based on Firebase project: medswift-8a930
// Project ID: medswift-8a930
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS not configured yet. Add GoogleService-Info.plist.');
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAh4H-zJrKm5f6NcmTmZaq4zoYoTvgnKr0',
    authDomain: 'medswift-8a930.firebaseapp.com',
    projectId: 'medswift-8a930',
    storageBucket: 'medswift-8a930.firebasestorage.app',
    messagingSenderId: '36625808600',
    appId: '1:36625808600:web:95d13d60209542738c6bad',
    measurementId: 'G-5C0FFRW95C',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAyJSJP9UCWdoOal0aofVUQ41YdPV_ILk4',
    appId: '1:36625808600:android:dd94709b951f44918c6bad',
    messagingSenderId: '36625808600',
    projectId: 'medswift-8a930',
    storageBucket: 'medswift-8a930.firebasestorage.app',
  );
}
