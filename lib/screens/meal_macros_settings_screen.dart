import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/organic_components.dart';

class MealMacrosSettingsScreen extends StatelessWidget {
  const MealMacrosSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.showMealMacros),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle Card
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.pie_chart_outline,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.showMealMacros,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.showMealMacrosSubtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: settings.showMealMacros,
                        onChanged: settings.setShowMealMacros,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Preview Section
                Text(
                  l10n.preview,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),

                // Preview: Macros OFF
                _buildPreviewCard(
                  context,
                  title: l10n.macrosHidden,
                  isActive: !settings.showMealMacros,
                  child: _buildMealPreview(context, showMacros: false),
                ),
                const SizedBox(height: 12),

                // Preview: Macros ON
                _buildPreviewCard(
                  context,
                  title: l10n.macrosVisible,
                  isActive: settings.showMealMacros,
                  child: _buildMealPreview(context, showMacros: true),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviewCard(
    BuildContext context, {
    required String title,
    required bool isActive,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.05)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.1),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isActive)
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              if (isActive) const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMealPreview(BuildContext context, {required bool showMacros}) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.wb_sunny_outlined,
              color: theme.colorScheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Breakfast',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '450 kcal',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showMacros) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildMiniMacro('P', 25, AppTheme.protein, theme),
                      const SizedBox(width: 8),
                      _buildMiniMacro('C', 45, AppTheme.carbs, theme),
                      const SizedBox(width: 8),
                      _buildMiniMacro('F', 15, AppTheme.fat, theme),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.add_circle_outline,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMacro(String label, double value, Color color, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 2,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ${value.toStringAsFixed(0)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
