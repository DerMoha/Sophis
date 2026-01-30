import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/shareable_meal.dart';
import '../services/meal_sharing_service.dart';
import '../theme/app_theme.dart';
import '../widgets/organic_components.dart';

class ShareMealScreen extends StatelessWidget {
  final ShareableMeal meal;

  const ShareMealScreen({super.key, required this.meal});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final deepLink = meal.toDeepLink();

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
            centerTitle: false,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                l10n.shareMeal,
                style: theme.appBarTheme.titleTextStyle,
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // QR Code Card
                OrganicCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceLG),
                    child: Column(
                      children: [
                        // QR Code
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spaceMD),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                          ),
                          child: QrImageView(
                            data: deepLink,
                            version: QrVersions.auto,
                            size: 200,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                          ),
                        ),

                        const SizedBox(height: AppTheme.spaceMD),

                        // Meal info
                        Text(
                          meal.title ?? l10n.sharedMeal,
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spaceXS),
                        Text(
                          '${meal.items.length} ${meal.items.length == 1 ? 'item' : 'items'} - ${meal.totalCalories.round()} kcal',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppTheme.spaceMD),

                // Macros summary
                OrganicCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceMD),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMacroColumn(
                          theme,
                          l10n.proteinShort,
                          '${meal.totalProtein.round()}g',
                          AppTheme.protein,
                        ),
                        _buildMacroColumn(
                          theme,
                          l10n.carbsShort,
                          '${meal.totalCarbs.round()}g',
                          AppTheme.carbs,
                        ),
                        _buildMacroColumn(
                          theme,
                          l10n.fatShort,
                          '${meal.totalFat.round()}g',
                          AppTheme.fat,
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
                      ...meal.items.map((item) => ListTile(
                            title: Text(item.name),
                            trailing: Text(
                              '${item.calories.round()} kcal',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          )),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spaceLG),

                // Share buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await MealSharingService.copyToClipboard(meal);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.linkCopied)),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: Text(l10n.copyLink),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSM),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            MealSharingService.shareViaSystem(meal),
                        icon: const Icon(Icons.share_rounded),
                        label: Text(l10n.shareLink),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spaceMD),

                // Instructions
                Text(
                  l10n.shareInstructions,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppTheme.space2XL),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroColumn(
    ThemeData theme,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
