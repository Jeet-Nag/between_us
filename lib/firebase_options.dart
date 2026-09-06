import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
/// Generated via `flutterfire configure`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDemoPlaceholderWebKeyForBetweenUsApp',
    appId: '1:100000000000:web:abcdef1234567890',
    messagingSenderId: '100000000000',
    projectId: 'between-us-couple',
    authDomain: 'between-us-couple.firebaseapp.com',
    storageBucket: 'between-us-couple.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBwmr7wDhPZswd6DSOdd3jPQTo0vMmTyAw',
    appId: '1:69731259237:android:f3b92ad3e86d5a525fc78c',
    messagingSenderId: '69731259237',
    projectId: 'between-us-eda3b',
    storageBucket: 'between-us-eda3b.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAR98nQ_CKzoGPruAseP0nqzXJmxEbbsJI',
    appId: '1:69731259237:ios:a7655538a63466035fc78c',
    messagingSenderId: '69731259237',
    projectId: 'between-us-eda3b',
    storageBucket: 'between-us-eda3b.firebasestorage.app',
    iosBundleId: 'com.betweenus.app',
  );
}
