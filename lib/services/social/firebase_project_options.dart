import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public client identifiers from the registered Sophis Firebase apps. These
/// identify the project; Auth and Firestore Rules authorize access to its data.
/// https://firebase.google.com/docs/projects/learn-more#config-files-objects
final class FirebaseProjectOptions {
  static FirebaseOptions? get currentPlatform =>
      switch (defaultTargetPlatform) {
        TargetPlatform.iOS => ios,
        TargetPlatform.android => android,
        _ => null,
      };

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyAP4TopMeLTPGsHlswIsl4ufrtbYYSet9Q',
    appId: '1:657623134154:ios:23417f8213e19b7d86a933',
    messagingSenderId: '657623134154',
    projectId: 'sophis-d2953',
  );
  static const android = FirebaseOptions(
    apiKey: 'AIzaSyB3M7ZLCZrgNqIq00FKjjalzWos8RIJNgc',
    appId: '1:657623134154:android:63c8bd942f9fd2d486a933',
    messagingSenderId: '657623134154',
    projectId: 'sophis-d2953',
  );
}
