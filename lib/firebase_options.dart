import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (identical(defaultTargetPlatform, TargetPlatform.android)) {
      return android;
    }
    if (identical(defaultTargetPlatform, TargetPlatform.iOS)) {
      return ios;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCNqq-dFTSLz1iMdnPWAiXYNxbWQgCytBw',
    appId: '1:590395345046:android:3b1c8d5e9f2a7c6b',
    messagingSenderId: '590395345046',
    projectId: 'tekneck-support',
    storageBucket: 'tekneck-support.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCNqq-dFTSLz1iMdnPWAiXYNxbWQgCytBw',
    appId: '1:590395345046:ios:5a3b2c9d8f1e7a4c',
    messagingSenderId: '590395345046',
    projectId: 'tekneck-support',
    storageBucket: 'tekneck-support.firebasestorage.app',
    databaseURL: 'https://tekneck-support.firebaseio.com',
  );
}
