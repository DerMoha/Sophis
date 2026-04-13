import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';

class NutritionEntryFields extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController caloriesController;
  final TextEditingController proteinController;
  final TextEditingController carbsController;
  final TextEditingController fatController;
  final String nameLabel;
  final String? Function(String?)? nameValidator;
  final String? Function(String?)? caloriesValidator;
  final String? Function(String?)? macroValidator;
  final TextCapitalization nameTextCapitalization;
  final InputBorder? border;

  const NutritionEntryFields({
    super.key,
    required this.nameController,
    required this.caloriesController,
    required this.proteinController,
    required this.carbsController,
    required this.fatController,
    required this.nameLabel,
    this.nameValidator,
    this.caloriesValidator,
    this.macroValidator,
    this.nameTextCapitalization = TextCapitalization.none,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: nameLabel,
            prefixIcon: const Icon(Icons.restaurant_outlined),
            border: border,
          ),
          validator: nameValidator,
          textCapitalization: nameTextCapitalization,
        ),
        const SizedBox(height: AppTheme.spaceSM2),
        TextFormField(
          controller: caloriesController,
          decoration: InputDecoration(
            labelText: l10n.calories,
            prefixIcon: const Icon(Icons.local_fire_department_outlined),
            suffixText: 'kcal',
            border: border,
          ),
          keyboardType: TextInputType.number,
          validator: caloriesValidator,
        ),
        const SizedBox(height: AppTheme.spaceSM2),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: proteinController,
                decoration: InputDecoration(
                  labelText: l10n.protein,
                  suffixText: 'g',
                  border: border,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: macroValidator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: carbsController,
                decoration: InputDecoration(
                  labelText: l10n.carbs,
                  suffixText: 'g',
                  border: border,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: macroValidator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: fatController,
                decoration: InputDecoration(
                  labelText: l10n.fat,
                  suffixText: 'g',
                  border: border,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: macroValidator,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
