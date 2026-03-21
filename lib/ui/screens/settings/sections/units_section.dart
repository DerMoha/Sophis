import 'package:flutter/material.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../../../models/app_settings.dart';
import '../../../../../services/settings_provider.dart';
import '../../../theme/app_theme.dart';

class UnitsSection extends StatelessWidget {
  final SettingsProvider settings;

  const UnitsSection({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final options = [
      (UnitSystem.metric, l10n.metric, l10n.metricSubtitle),
      (UnitSystem.imperial, l10n.imperial, l10n.imperialSubtitle),
    ];

    return Column(
      children: options.map((option) {
        final isSelected = settings.unitSystem == option.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => settings.setUnitSystem(option.$1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      option.$1 == UnitSystem.metric
                          ? Icons.balance_outlined
                          : Icons.scale_outlined,
                      size: 20,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.$2,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          Text(
                            option.$3,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
