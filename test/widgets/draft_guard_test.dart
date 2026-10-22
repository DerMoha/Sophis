import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/ui/components/draft_guard.dart';
import 'package:sophis/ui/components/modal_sheet.dart';

import '../helpers/test_services.dart';

void main() {
  for (final dismissal in ['close', 'outside', 'drag', 'back']) {
    testWidgets('preserved dirty sheet on $dismissal until discard',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final guard = GlobalKey<DraftGuardState>();
      await pumpTestApp(
        tester,
        Scaffold(
          body: Builder(builder: (context) {
            return TextButton(
              onPressed: () => showDraftBottomSheet<void>(
                context: context,
                builder: (_) => DraftGuard(
                  controllers: const [],
                  child: DraftGuard(
                  key: guard,
                  controllers: [controller],
                  child: ModalSheetSurface(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ModalSheetHandle(),
                        const ModalSheetHeader(title: 'Draft'),
                        TextField(controller: controller),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
              ),
              child: const Text('Open'),
            );
          },),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Keep this');
      await tester.pump();
      switch (dismissal) {
        case 'close':
          await tester.tap(find.byTooltip('Close'));
        case 'outside':
          await tester.tapAt(const Offset(10, 10));
        case 'drag':
          await tester.flingFrom(
              tester.getBottomLeft(find.byType(ModalSheetHandle)) +
                  const Offset(20, -2),
              const Offset(0, 500),
              1500,);
        case 'back':
          await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Keep this'), findsOneWidget);
      expect(find.byTooltip('Close').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('untouched, reverted and saved drafts closed without prompting',
      (tester) async {
    final controller = TextEditingController(text: 'Original');
    addTearDown(controller.dispose);
    final guard = GlobalKey<DraftGuardState>();
    await pumpTestApp(tester, Scaffold(body: Builder(builder: (context) {
      return TextButton(
        onPressed: () => showDraftBottomSheet<void>(
          context: context,
          builder: (sheetContext) => DraftGuard(
            key: guard,
            controllers: [controller],
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const ModalSheetHeader(title: 'Draft'),
              TextField(controller: controller),
              TextButton(
                  onPressed: () {
                    guard.currentState!.markSaved();
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('Save'),),
            ],),
          ),
        ),
        child: const Text('Open'),
      );
    },),),);
    for (final mode in ['untouched', 'reverted', 'saved']) {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      if (mode != 'untouched') {
        await tester.enterText(find.byType(TextField), 'Changed');
        if (mode == 'reverted') {
          await tester.enterText(find.byType(TextField), 'Original');
        }
      }
      if (mode == 'saved') {
        await tester.tap(find.text('Save'));
      } else {
        await tester.tap(find.byTooltip('Close'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TextField), findsNothing);
    }
  });
}
