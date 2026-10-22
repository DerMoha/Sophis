import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:sophis/services/service_result.dart';

enum ScanModel { ocr, barcode }

/// Android downloads models through Play services; recognition stays on device.
class ScanModelService {
  static const _channel = MethodChannel('sophis/scan_models');

  const ScanModelService();

  Future<ServiceResult<void>> ensureAvailable(ScanModel model) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const Success(null);
    }
    try {
      await _channel.invokeMethod<void>(
        'ensureAvailable',
        {'model': model.name},
      ).timeout(const Duration(seconds: 65));
      return const Success(null);
    } on PlatformException catch (error) {
      if (error.code == 'play_services_unavailable') {
        return const Failure(
          ServiceErrorType.unknown,
          'Scanning requires up-to-date Google Play services on this device.',
        );
      }
      return const Failure(
        ServiceErrorType.network,
        'Connect to the internet to finish preparing the scanner, then try again.',
      );
    } on TimeoutException {
      return const Failure(
        ServiceErrorType.network,
        'Scanner preparation timed out. Check your connection and try again.',
      );
    }
  }
}
