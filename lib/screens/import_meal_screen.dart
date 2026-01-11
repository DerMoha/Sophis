import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/shareable_meal.dart';
import '../services/nutrition_provider.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/organic_components.dart';

class ImportMealScreen extends StatefulWidget {
  final ShareableMeal meal;

  const ImportMealScreen({super.key, required this.meal});

  @override
  State<ImportMealScreen> createState() => _ImportMealScreenState();
}

class _ImportMealScreenState extends State<ImportMealScreen> {
  String _selectedMeal = 'lunch';

  void _importMeal() {
    final entries = widget.meal.toFoodEntries(_selectedMeal);
    final provider = context.read<NutritionProvider>();

    for (final entry in entries) {
      provider.addFoodEntry(entry);
    }

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${entries.length} ${entries.length == 1 ? 'item' : 'items'} imported',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final meal = widget.meal;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 52, bottom: 16),
              title: Text(
                l10n.importMeal,
                style: theme.appBarTheme.titleTextStyle,
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Shared meal header
                OrganicCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceMD),
                    child: Column(
                      children: [
                        Icon(
                          Icons.restaurant_menu_rounded,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: AppTheme.spaceSM),
                        Text(
                          meal.title ?? l10n.sharedMeal,
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spaceXS),
                        Text(
                          '${meal.items.length} ${meal.items.length == 1 ? 'item' : 'items'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppTheme.spaceMD),

                // Items list
                OrganicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppTheme.spaceMD),
                        child: Text(
                          l10n.foods,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const Divider(height: 1),
                      ...meal.items.map((item) => _buildItemTile(theme, item)),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spaceMD),

                // Totals
                OrganicCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceMD),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.total,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppTheme.spaceSM),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMacroChip(
                              theme,
                              '${meal.totalCalories.round()}',
                              'kcal',
                              theme.colorScheme.primary,
                            ),
                            _buildMacroChip(
                              theme,
                              '${meal.totalProtein.round()}g',
                              l10n.proteinShort,
                              AppTheme.protein,
                            ),
                            _buildMacroChip(
                              theme,
                              '${meal.totalCarbs.round()}g',
                              l10n.carbsShort,
                              AppTheme.carbs,
                            ),
                            _buildMacroChip(
                              theme,
                              '${meal.totalFat.round()}g',
                              l10n.fatShort,
                              AppTheme.fat,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppTheme.spaceMD),

                // Meal selector
                OrganicCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceMD),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.importAs,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppTheme.spaceSM),
                        Wrap(
                          spacing: AppTheme.spaceSM,
                          children: context.read<SettingsProvider>().mealTypes
                              .map((mealType) => ChoiceChip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          mealType.icon,
                                          size: 18,
                                          color: _selectedMeal == mealType.id
                                              ? Colors.white
                                              : theme.colorScheme.onSurface,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(mealType.name),
                                      ],
                                    ),
                                    selected: _selectedMeal == mealType.id,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() => _selectedMeal = mealType.id);
                                      }
                                    },
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppTheme.spaceLG),

                // Import button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _importMeal,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(l10n.importAll),
                  ),
                ),

                const SizedBox(height: AppTheme.space2XL),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(ThemeData theme, SharedFoodItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceSM,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.bodyLarge,
                ),
                if (item.portionGrams != null)
                  Text(
                    '${item.portionGrams!.round()}g',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          Text(
            '${item.calories.round()} kcal',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroChip(
    ThemeData theme,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
