import 'dart:io';

import 'package:drift/native.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sophis/services/social/callable_social_repository.dart';
import 'package:sophis/services/social/firebase_social_auth.dart';
import 'package:sophis/services/social/social_account_repository.dart';
import 'package:sophis/services/social/social_callable_client.dart';
import 'package:sophis/services/social/social_firebase_configuration.dart';
import 'package:sophis/services/social/social_local_store.dart';
import 'package:sophis/services/social/social_queue_runner.dart';
import 'package:sophis/services/social/social_partner_repository.dart';

final class SocialRuntime {
  SocialPartnerRepository get partners =>
      SocialPartnerRepository(accounts.client);

  final FirebaseSocialAuth auth;
  final CallableSocialRepository repository;
  final SocialAccountRepository accounts;
  final SocialQueueRunner queue;
  final SocialLocalStore store;
  final http.Client _http;

  SocialRuntime({
    required this.auth,
    required this.repository,
    required this.accounts,
    required this.queue,
    required this.store,
    required http.Client httpClient,
  }) : _http = httpClient;

  static SocialFirebaseConfiguration? configuration() {
    const host = String.fromEnvironment('SOCIAL_EMULATOR_HOST');
    if (host.isNotEmpty && !kReleaseMode) {
      return const SocialFirebaseConfiguration(
        options: FirebaseOptions(
          apiKey: 'demo-api-key',
          appId: '1:123456789:ios:0123456789abcdef',
          messagingSenderId: '123456789',
          projectId: 'demo-sophis',
        ),
        emulatorHost: host,
      );
    }
    const project = String.fromEnvironment('SOCIAL_PROJECT_ID');
    const key = String.fromEnvironment('SOCIAL_API_KEY');
    const sender = String.fromEnvironment('SOCIAL_SENDER_ID');
    const iosId = String.fromEnvironment('SOCIAL_IOS_APP_ID');
    const androidId = String.fromEnvironment('SOCIAL_ANDROID_APP_ID');
    final appId =
        defaultTargetPlatform == TargetPlatform.iOS ? iosId : androidId;
    if (project.isEmpty || key.isEmpty || sender.isEmpty || appId.isEmpty) {
      return null;
    }
    return SocialFirebaseConfiguration(
      options: FirebaseOptions(
        apiKey: key,
        appId: appId,
        messagingSenderId: sender,
        projectId: project,
      ),
    );
  }

  static Future<SocialRuntime> open() async {
    final config = configuration();
    if (config == null) throw StateError('Partner sharing is not configured');
    final directory = await getApplicationSupportDirectory();
    final store = SocialLocalStore(
      NativeDatabase.createInBackground(
        File(path.join(directory.path, 'social.sqlite')),
      ),
    );
    final httpClient = http.Client();
    FirebaseSocialAuth? auth;
    try {
      final services = await config.initialize();
      auth = FirebaseSocialAuth(
        auth: services.auth,
        appCheck: services.appCheck,
        store: store,
      );
      await auth.ready();
      await store.retirePublishing();
      final client = SocialCallableClient(
        credentials: auth,
        store: store,
        endpoint: config.endpoint,
        client: httpClient,
        requireAppCheck: config.emulatorHost == null,
      );
      return SocialRuntime(
        auth: auth,
        repository: CallableSocialRepository(
          client: client,
          store: store,
          signOut: auth.signOut,
        ),
        accounts: SocialAccountRepository(client: client, store: store),
        queue: SocialQueueRunner(store: store, transport: client),
        store: store,
        httpClient: httpClient,
      );
    } catch (_) {
      await auth?.close();
      httpClient.close();
      await store.close();
      rethrow;
    }
  }

  Future<void> close() async {
    await auth.close();
    _http.close();
    await store.close();
  }
}
