import 'package:flutter/material.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/ui/theme/app_theme.dart';

/// Shows a modal bottom sheet that previews the values parsed from a nutrition
/// label photo. Returns `true` if the user confirms ("Looks good") and `false`
/// (or null) if they want to rescan. The caller retains ownership of the
/// constructed FoodItem — the sheet is presentational only.
Future<bool> showLabelPreviewSheet({
  required BuildContext context,
  required NutritionLabelResult label,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (bottomSheetContext) => LabelPreviewSheet(
      label: label,
      onLooksGood: () => Navigator.pop(bottomSheetContext, true),
      onRescan: () => Navigator.pop(bottomSheetContext, false),
      l10n: l10n,
      theme: theme,
    ),
  );

  return result == true;
}

class LabelPreviewSheet extends StatelessWidget {
  final NutritionLabelResult label;
  final VoidCallback onLooksGood;
  final VoidCallback onRescan;
  final AppLocalizations l10n;
  final ThemeData theme;

  const LabelPreviewSheet({
    super.key,
    required this.label,
    required this.onLooksGood,
    required this.onRescan,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DragHandle(theme: theme),
          _Header(theme: theme, l10n: l10n),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.15),
                ),
              ),
              child: _ValueList(theme: theme, l10n: l10n, label: label),
            ),
          ),
          const SizedBox(height: 20),
          _Actions(theme: theme, l10n: l10n, onLooksGood: onLooksGood, onRescan: onRescan),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  final ThemeData theme;
  const _DragHandle({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ThemeData theme;
  final AppLocalizations l10n;
  const _Header({required this.theme, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Icon(
              Icons.checklist_outlined,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.nutritionLabelPreview,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.nutritionLabelPreviewSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ValueList extends StatelessWidget {
  final ThemeData theme;
  final AppLocalizations l10n;
  final NutritionLabelResult label;

  const _ValueList({
    required this.theme,
    required this.l10n,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.productName != null) ...[
          Text(
            label.productName!,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (label.brand != null)
            Text(
              label.brand!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          const SizedBox(height: 16),
          Divider(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
        ],
        Center(
          child: Text(
            l10n.per100gLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _LabelRow(
          label: l10n.calories,
          value: label.caloriesPer100g.toStringAsFixed(0),
          unit: 'kcal',
          color: theme.colorScheme.primary,
          theme: theme,
        ),
        const SizedBox(height: 10),
        _LabelRow(
          label: l10n.protein,
          value: label.proteinPer100g.toStringAsFixed(1),
          unit: 'g',
          color: AppTheme.protein,
          theme: theme,
        ),
        const SizedBox(height: 10),
        _LabelRow(
          label: l10n.carbs,
          value: label.carbsPer100g.toStringAsFixed(1),
          unit: 'g',
          color: AppTheme.carbs,
          theme: theme,
        ),
        const SizedBox(height: 10),
        _LabelRow(
          label: l10n.fat,
          value: label.fatPer100g.toStringAsFixed(1),
          unit: 'g',
          color: AppTheme.fat,
          theme: theme,
        ),
        if (label.fiberPer100g > 0) ...[
          const SizedBox(height: 10),
          _LabelRow(
            label: l10n.fiber,
            value: label.fiberPer100g.toStringAsFixed(1),
            unit: 'g',
            color: AppTheme.fiber,
            theme: theme,
          ),
        ],
        if (label.servingSizeG != null && label.servingSizeG! > 0) ...[
          const SizedBox(height: 16),
          Divider(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.restaurant_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '${l10n.servingInfo}: ${label.servingName ?? l10n.portion} = ${label.servingSizeG!.toStringAsFixed(0)}g',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  final ThemeData theme;
  final AppLocalizations l10n;
  final VoidCallback onLooksGood;
  final VoidCallback onRescan;

  const _Actions({
    required this.theme,
    required this.l10n,
    required this.onLooksGood,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onRescan,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.rescanLabel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: onLooksGood,
              icon: const Icon(Icons.check, size: 18),
              label: Text(l10n.looksGood),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final ThemeData theme;

  const _LabelRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          unit,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
