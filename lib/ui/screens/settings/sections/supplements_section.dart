import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/providers/supplements_provider.dart';
import 'package:sophis/ui/components/common/app_surface.dart';
import 'package:sophis/ui/screens/supplements_screen.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class SupplementsSection extends StatelessWidget {
  final SettingsProvider settings;

  const SupplementsSection({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppSection(
      title: l10n.supplements,
      children: [
        AppSwitchRow(
          title: l10n.trackSupplements,
          subtitle: l10n.trackSupplementsSubtitle,
          icon: Icons.medication_outlined,
          value: settings.showSupplements,
          showDivider: settings.showSupplements,
          onChanged: (value) {
            settings.setShowSupplements(value);
            context
                .read<SupplementsProvider>()
                .updateAllNotifications(enable: value);
          },
        ),
        if (settings.showSupplements)
          AppNavigationRow(
            title: l10n.manageSupplements,
            subtitle: l10n.manageSupplementsSubtitle,
            icon: Icons.medication_liquid_rounded,
            showDivider: false,
            onTap: () => Navigator.push(
              context,
              AppTheme.slideRoute(const SupplementsScreen()),
            ),
          ),
      ],
    );
  }
}
