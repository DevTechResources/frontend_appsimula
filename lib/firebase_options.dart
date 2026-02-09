import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA_akW-eOZutB3T3BuZrHG6tER-8-AUh2U',
    appId: '1:634308057874:android:daeebdb868df8e669731cb',
    messagingSenderId: '634308057874',
    projectId: 'appventas-39a7c',
    storageBucket: 'appventas-39a7c.firebasestorage.app',
  );
}
