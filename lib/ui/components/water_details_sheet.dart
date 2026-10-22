import 'package:flutter/material.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/ui/components/modal_sheet.dart';
import 'package:sophis/ui/screens/water_screen.dart';

/// Uses the same validated entry and undo flows as the full water screen.
class WaterDetailsSheet extends StatelessWidget {
  const WaterDetailsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: ModalSheetSurface(
        child: Column(
          children: [
            const ModalSheetHandle(),
            ModalSheetHeader(title: AppLocalizations.of(context)!.water),
            const Expanded(child: WaterScreen(embedded: true)),
          ],
        ),
      ),
    );
  }
}
