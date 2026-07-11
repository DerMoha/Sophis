import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum ProgressPhotoAuthResult { success, unavailable, failed }

class ProgressPhotoLockService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<ProgressPhotoAuthResult> authenticate({
    required String localizedReason,
  }) async {
    try {
      final isDeviceSupported = await _auth.isDeviceSupported();
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      if (!isDeviceSupported && !canCheckBiometrics) {
        return ProgressPhotoAuthResult.unavailable;
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        persistAcrossBackgrounding: true,
      );

      return didAuthenticate
          ? ProgressPhotoAuthResult.success
          : ProgressPhotoAuthResult.failed;
    } on PlatformException {
      return ProgressPhotoAuthResult.unavailable;
    }
  }
}
