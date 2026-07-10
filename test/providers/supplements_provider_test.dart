import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sophis/models/supplement.dart';
import 'package:sophis/providers/supplements_provider.dart';
import 'package:sophis/services/database_service.dart';

import '../helpers/test_services.dart';

Future<void> _waitForProvider(SupplementsProvider provider) async {
  for (var i = 0; i < 50 && provider.isLoading; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  if (provider.isLoading) {
    throw StateError('SupplementsProvider did not finish loading');
  }
}

void main() {
  group('SupplementsProvider', () {
    test('loaded supplements and toggled today completion', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final notifications = createMockNotificationService();
      final supplement = Supplement(
        id: 'vitamin-d',
        name: 'Vitamin D',
        reminderTime: '09:15',
        createdAt: DateTime(2026),
      );
      await db.insertSupplement(supplement);

      final provider = SupplementsProvider(db, notifications);
      await provider.initialize();
      await _waitForProvider(provider);

      expect(provider.supplements.single.id, 'vitamin-d');
      expect(provider.enabledSupplements.single.id, 'vitamin-d');
      expect(provider.todayCompletedCount, 0);

      await provider.toggleCompletion('vitamin-d');

      expect(provider.isCompletedToday('vitamin-d'), isTrue);
      expect(provider.todayCompletedCount, 1);
      expect(
        (await db.getAllSupplementLogs()).single.supplementId,
        'vitamin-d',
      );
      verify(
        () => notifications.scheduleMealReminder(
          id: 100,
          title: any(named: 'title'),
          body: any(named: 'body'),
          hour: 9,
          minute: 15,
          startTomorrow: true,
        ),
      ).called(1);

      await provider.toggleCompletion('vitamin-d');

      expect(provider.isCompletedToday('vitamin-d'), isFalse);
      expect(provider.todayCompletedCount, 0);
      expect(await db.getAllSupplementLogs(), isEmpty);
    });

    test('added, updated, reordered, and deleted supplements', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final notifications = createMockNotificationService();
      final provider = SupplementsProvider(db, notifications);
      await provider.initialize();
      await _waitForProvider(provider);

      final magnesium = Supplement(
        id: 'magnesium',
        name: 'Magnesium',
        reminderTime: '20:00',
        sortOrder: 1,
        createdAt: DateTime(2026),
      );
      final zinc = Supplement(
        id: 'zinc',
        name: 'Zinc',
        sortOrder: 0,
        createdAt: DateTime(2026),
      );

      expect((await provider.addSupplement(magnesium)).isSuccess, isTrue);
      expect((await provider.addSupplement(zinc)).isSuccess, isTrue);

      expect(provider.supplements.map((s) => s.id), ['zinc', 'magnesium']);
      expect(provider.todayTotalCount, 2);

      final updated = magnesium.copyWith(name: 'Magnesium glycinate');
      expect((await provider.updateSupplement(updated)).isSuccess, isTrue);
      expect(provider.supplements.last.name, 'Magnesium glycinate');

      expect((await provider.reorderSupplements(1, 0)).isSuccess, isTrue);
      expect(provider.supplements.first.id, 'magnesium');
      expect((await db.getAllSupplements()).first.id, 'magnesium');

      expect((await provider.deleteSupplement('magnesium')).isSuccess, isTrue);
      expect(provider.supplements.single.id, 'zinc');
      expect((await provider.deleteSupplement('missing')).isFailure, isTrue);
      expect(provider.lastError, 'Supplement not found');
    });

    test('reported persistence failures instead of false success', () async {
      final db = _FailingSupplementDatabase();
      addTearDown(db.close);
      final provider = SupplementsProvider(db, createMockNotificationService());
      await provider.initialize();
      final supplement = Supplement(
        id: 'failing',
        name: 'Failing supplement',
        createdAt: DateTime(2026),
      );

      final result = await provider.addSupplement(supplement);

      expect(result.isFailure, isTrue);
      expect(provider.supplements, isEmpty);
      expect(provider.lastError, contains('Failed to add supplement'));
    });
  });
}

class _FailingSupplementDatabase extends DatabaseService {
  _FailingSupplementDatabase() : super.inMemory();

  @override
  Future<int> insertSupplement(Supplement supplement) async {
    throw StateError('write failed');
  }
}
