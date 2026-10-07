import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Inject generated FirebaseOptions from the actual registered Android/iOS app.
/// Never initialize this from guest startup. Emulator configuration is explicit
/// and is rejected in release builds; no production project is inferred.
final class SocialFirebaseConfiguration {
  final FirebaseOptions options;
  final String? emulatorHost;

  const SocialFirebaseConfiguration({required this.options, this.emulatorHost});

  Uri get endpoint => emulatorHost == null
      ? Uri.https(
          'us-central1-${options.projectId}.cloudfunctions.net',
          '/social',
        )
      : Uri.http(
          '$emulatorHost:5001',
          '/${options.projectId}/us-central1/social',
        );

  Future<SocialFirebaseServices> initialize() async {
    if (emulatorHost != null &&
        (kReleaseMode || !options.projectId.startsWith('demo-'))) {
      throw StateError('Emulators require a demo project and a debug build');
    }
    final app =
        await Firebase.initializeApp(name: 'sophis-social', options: options);
    final auth = FirebaseAuth.instanceFor(app: app);
    FirebaseAppCheck? check;
    if (emulatorHost != null) {
      await auth.useAuthEmulator(emulatorHost!, 9099);
    } else {
      check = FirebaseAppCheck.instanceFor(app: app);
      await check.activate(
        providerAndroid: const AndroidPlayIntegrityProvider(),
        providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
    }
    return SocialFirebaseServices(app: app, auth: auth, appCheck: check);
  }
}

final class SocialFirebaseServices {
  final FirebaseApp app;
  final FirebaseAuth auth;
  final FirebaseAppCheck? appCheck;

  const SocialFirebaseServices({
    required this.app,
    required this.auth,
    this.appCheck,
  });
}
