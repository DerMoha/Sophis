import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_callable_client.dart';
import 'package:sophis/services/social/social_local_store.dart';
import 'package:sophis/services/social/social_partner_repository.dart';

class _Client extends Mock implements SocialClient {}

void main() {
  const session = SocialSession(accountId: 'alice', generation: 0);

  test('returned a failure when session capture threw', () async {
    final client = _Client();
    when(() => client.captureSession()).thenThrow(StateError('Store closed'));
    final result =
        await SocialPartnerRepository(client).request('partners', {});
    expect(result, isA<Failure<Map<String, dynamic>>>());
    expect((result as Failure).errorType, ServiceErrorType.unknown);
  });

  test('returned a network failure when a partner action timed out', () async {
    final client = _Client();
    when(() => client.captureSession()).thenAnswer((_) async => session);
    when(() => client.call(session, 'acceptPartner', {}))
        .thenThrow(TimeoutException('Offline'));
    final result =
        await SocialPartnerRepository(client).request('acceptPartner', {});
    expect((result as Failure).errorType, ServiceErrorType.network);
  });
}
