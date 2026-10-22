import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/ui/components/organic/progress.dart';
import 'package:sophis/ui/theme/animations.dart';

void main() {
  testWidgets('stopped and resumed repeating motion when accessibility changed', (tester) async {
    final reduced = ValueNotifier(false);
    addTearDown(reduced.dispose);
    await tester.pumpWidget(MaterialApp(home: ValueListenableBuilder<bool>(
      valueListenable: reduced,
      builder: (_, value, child) => MediaQuery(
        data: MediaQueryData(disableAnimations: value), child: child!,
      ),
      child: const Column(children: [
        FluidProgressBar(value: 0.5, color: Colors.blue),
        PulseAnimation(child: SizedBox(width: 20, height: 20)),
        ShimmerEffect(child: SizedBox(width: 20, height: 20)),
      ],),
    ),),);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    reduced.value = true;
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    reduced.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('announced German macro value and goal as one label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(const MaterialApp(
      locale: Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: SizedBox(width: 120, child:
        MacroRing(label: 'Eiweiß', value: 12.5, goal: 80, color: Colors.blue),
      ),),),
    ),);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Eiweiß: 12,5 von 80 g'), findsOneWidget);
    semantics.dispose();
  });
}
