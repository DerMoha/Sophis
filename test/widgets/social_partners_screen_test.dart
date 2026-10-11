import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/services/social/social_account_repository.dart';
import 'package:sophis/services/social/social_partner_repository.dart';
import 'package:sophis/ui/screens/social/social_partners_screen.dart';

void main() {
  PartnerConnection connection(String id, {bool accepted = true}) =>
      PartnerConnection.fromJson(
        {
          'id': id,
          'displayName': 'Partner $id',
          'participants': ['alice', 'bob'],
          'inviterId': 'alice',
          'status': accepted ? 'accepted' : 'pending',
          'settings': {
            'alice': {'revision': 0},
            'bob': {'revision': 0},
          },
        },
        'alice',
      );

  Future<void> showPartners(
    WidgetTester tester,
    List<PartnerConnection> connections, {
    bool embedded = false,
  }) async {
    final social = SocialProvider(configured: false)
      ..profile = const SocialProfile(accountId: 'alice', displayName: 'Alice')
      ..partners = connections;
    addTearDown(social.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: social,
        child: MaterialApp(
          home: Scaffold(body: SocialPartnersScreen(embedded: embedded)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opened one accepted partner directly', (tester) async {
    await showPartners(tester, [connection('one')]);
    expect(find.byType(SocialPartnerDetailScreen), findsOneWidget);
    expect(find.text('View today'), findsNothing);
    expect(find.text('Your partners'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('embedded one partner without an extra scaffold', (tester) async {
    await showPartners(tester, [connection('one')], embedded: true);
    expect(
      tester
          .widget<SocialPartnerDetailScreen>(
            find.byType(SocialPartnerDetailScreen),
          )
          .embedded,
      isTrue,
    );
    expect(find.byType(Scaffold), findsOneWidget);
    // The header stays actionable if a partner refresh fails.
    expect(find.byTooltip('Refresh partner'), findsOneWidget);
    expect(find.text('Partner one'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kept a chooser for multiple partners', (tester) async {
    await showPartners(tester, [connection('one'), connection('two')]);
    expect(find.byType(SocialPartnerDetailScreen), findsNothing);
    expect(find.text('Partner one'), findsOneWidget);
    expect(find.text('Partner two'), findsOneWidget);
    expect(find.text('View today'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('offered a direct connection action with no partners',
      (tester) async {
    await showPartners(tester, []);
    expect(find.text('Connect a partner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kept pending invitations out of the daily view', (tester) async {
    await showPartners(tester, [connection('pending', accepted: false)]);
    expect(find.byType(SocialPartnerDetailScreen), findsNothing);
    expect(find.text('Partner invitation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
