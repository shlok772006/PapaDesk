import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBv0Ci3E_1abGccyOsxKL70BQiiHH3xiHw',
    appId: '1:813881301514:web:7c4ad8e72e527f5e139df3',
    messagingSenderId: '813881301514',
    projectId: 'papadesk-dev',
    authDomain: 'papadesk-dev.firebaseapp.com',
    storageBucket: 'papadesk-dev.firebasestorage.app',
    measurementId: null,
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDTU043t4DgN9wuYHHDI7G4M4xAqL2CQ-M',
    appId: '1:813881301514:android:28d1e0d32df83287139df3',
    messagingSenderId: '813881301514',
    projectId: 'papadesk-dev',
    storageBucket: 'papadesk-dev.firebasestorage.app',
  );
}
