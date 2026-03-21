import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/generated/app_localizations.dart';
import '../screens/ai_food_camera_screen.dart';
import '../theme/app_theme.dart';

class EditFoodAnalysisSheet extends StatefulWidget {
  final EditableFoodResult result;
  final int remainingRequests;
  final VoidCallback onSaveEdits;
  final Function(String correctionHint) onReAnalyze;

  const EditFoodAnalysisSheet({
    super.key,
    required this.result,
    required this.remainingRequests,
    required this.onSaveEdits,
    required this.onReAnalyze,
  });

  @override
  State<EditFoodAnalysisSheet> createState() => _EditFoodAnalysisSheetState();
}

class _EditFoodAnalysisSheetState extends State<EditFoodAnalysisSheet> {
  bool _autoScaleEnabled = true;
  bool _isValid = true;
  final _formKey = GlobalKey<FormState>();

  // Store listeners for proper cleanup
  late final VoidCallback _portionListener;
  late final VoidCallback _validationListener;

  @override
  void initState() {
    super.initState();
    _setupPortionListener();
    _setupValidationListeners();
  }

  @override
  void dispose() {
    // Remove listeners to prevent memory leaks
    widget.result.portionController.removeListener(_portionListener);

    final controllers = [
      widget.result.nameController,
      widget.result.portionController,
      widget.result.caloriesController,
      widget.result.proteinController,
      widget.result.carbsController,
      widget.result.fatController,
    ];

    for (final controller in controllers) {
      controller.removeListener(_validationListener);
    }

    super.dispose();
  }

  void _setupPortionListener() {
    _portionListener = () {
      if (!_autoScaleEnabled) return;

      final newPortion = double.tryParse(widget.result.portionController.text);
      if (newPortion == null || newPortion <= 0) return;

      final scaled = widget.result.originalAnalysis.scaledToPortion(newPortion);

      // Update macro controllers without triggering infinite loop
      widget.result.caloriesController.text =
          scaled.calories.toStringAsFixed(0);
      widget.result.proteinController.text = scaled.protein.toStringAsFixed(1);
      widget.result.carbsController.text = scaled.carbs.toStringAsFixed(1);
      widget.result.fatController.text = scaled.fat.toStringAsFixed(1);
    };

    widget.result.portionController.addListener(_portionListener);
  }

  void _setupValidationListeners() {
    _validationListener = () {
      setState(() {
        _isValid = _formKey.currentState?.validate() ?? false;
      });
    };

    final controllers = [
      widget.result.nameController,
      widget.result.portionController,
      widget.result.caloriesController,
      widget.result.proteinController,
      widget.result.carbsController,
      widget.result.fatController,
    ];

    for (final controller in controllers) {
      controller.addListener(_validationListener);
    }
  }

  void _resetToOriginal() {
    final original = widget.result.originalAnalysis;
    widget.result.nameController.text = original.name;
    widget.result.portionController.text =
        original.portionGrams.toStringAsFixed(0);
    widget.result.caloriesController.text =
        original.calories.toStringAsFixed(0);
    widget.result.proteinController.text = original.protein.toStringAsFixed(1);
    widget.result.carbsController.text = original.carbs.toStringAsFixed(1);
    widget.result.fatController.text = original.fat.toStringAsFixed(1);
    setState(() {});
  }

  void _saveChanges() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSaveEdits();
  }

  void _showReAnalyzeConfirmation() {
    if (widget.remainingRequests <= 3) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(ctx)!.confirmReanalysis),
          content: Text(
            AppLocalizations.of(ctx)!.reanalysisConfirmation(widget.remainingRequests),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(ctx)!.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _reAnalyze();
              },
              child: Text(AppLocalizations.of(ctx)!.continueAction),
            ),
          ],
        ),
      );
    } else {
      _reAnalyze();
    }
  }

  void _reAnalyze() {
    final hint = widget.result.generateCorrectionHint();
    widget.onReAnalyze(hint);
  }

  bool get _hasChanges {
    final original = widget.result.originalAnalysis;
    return widget.result.nameController.text.trim() != original.name ||
        widget.result.portionController.text !=
            original.portionGrams.toStringAsFixed(0) ||
        widget.result.caloriesController.text !=
            original.calories.toStringAsFixed(0) ||
        widget.result.proteinController.text !=
            original.protein.toStringAsFixed(1) ||
        widget.result.carbsController.text !=
            original.carbs.toStringAsFixed(1) ||
        widget.result.fatController.text != original.fat.toStringAsFixed(1);
  }

  String? _validatePositiveNumber(String? value, String fieldName) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) {
      return l10n.fieldRequired(fieldName);
    }
    final number = double.tryParse(value);
    if (number == null) {
      return l10n.enterValidNumber;
    }
    if (number < 0) {
      return l10n.fieldCannotBeNegative(fieldName);
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.foodNameRequired;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final showLowRequestWarning =
        widget.remainingRequests < 5 && widget.remainingRequests > 0;
    final canReAnalyze = widget.remainingRequests > 0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.editFoodAnalysis,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
                IconButton(
                  icon: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                    ),
                    child: const Icon(Icons.close, size: 18),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Low request warning
          if (showLowRequestWarning)
            Container(
              margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              padding: const EdgeInsets.all(AppTheme.spaceSM),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                border:
                    Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.warning,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spaceSM),
                  Expanded(
                    child: Text(
                      l10n.aiRequestsWarning(widget.remainingRequests),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Content (scrollable)
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Food name
                    TextFormField(
                      controller: widget.result.nameController,
                      decoration: InputDecoration(
                        labelText: l10n.foodName,
                        hintText: l10n.foodNameHint,
                        prefixIcon: const Icon(Icons.restaurant, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMD,
                          vertical: 14,
                        ),
                      ),
                      validator: _validateName,
                    ),
                    const SizedBox(height: 16),

                    // Portion size
                    TextFormField(
                      controller: widget.result.portionController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,1}'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.portionSize,
                        hintText: '100',
                        prefixIcon: const Icon(Icons.scale, size: 20),
                        suffixText: 'g',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMD,
                          vertical: 14,
                        ),
                      ),
                      validator: (v) => _validatePositiveNumber(v, l10n.portionSize),
                    ),
                    const SizedBox(height: 16),

                    // Auto-scale toggle
                    SwitchListTile(
                      value: _autoScaleEnabled,
                      onChanged: (value) =>
                          setState(() => _autoScaleEnabled = value),
                      title: Text(l10n.autoScaleNutrition),
                      subtitle:
                          Text(l10n.autoScaleNutritionSubtitle),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),

                    // Macros section header
                    Text(
                      l10n.nutritionValues,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSM2),

                    // Calories
                    TextFormField(
                      controller: widget.result.caloriesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,1}'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.calories,
                        hintText: '200',
                        prefixIcon: const Icon(
                          Icons.local_fire_department_outlined,
                          size: 20,
                        ),
                        suffixText: 'kcal',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMD,
                          vertical: 14,
                        ),
                      ),
                      validator: (v) => _validatePositiveNumber(v, l10n.calories),
                    ),
                    const SizedBox(height: 16),

                    // Macros row
                    Row(
                      children: [
                        // Protein
                        Expanded(
                          child: TextFormField(
                            controller: widget.result.proteinController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,1}'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.protein,
                              hintText: '20',
                              suffixText: 'g',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceSM,
                                vertical: 14,
                              ),
                            ),
                            validator: (v) =>
                                _validatePositiveNumber(v, l10n.protein),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Carbs
                        Expanded(
                          child: TextFormField(
                            controller: widget.result.carbsController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,1}'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.carbs,
                              hintText: '30',
                              suffixText: 'g',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceSM,
                                vertical: 14,
                              ),
                            ),
                            validator: (v) =>
                                _validatePositiveNumber(v, l10n.carbs),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Fat
                        Expanded(
                          child: TextFormField(
                            controller: widget.result.fatController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,1}'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.fat,
                              hintText: '10',
                              suffixText: 'g',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceSM,
                                vertical: 14,
                              ),
                            ),
                            validator: (v) => _validatePositiveNumber(v, l10n.fat),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        // Reset button
                        TextButton.icon(
                          onPressed: _hasChanges ? _resetToOriginal : null,
                          icon: const Icon(Icons.restore, size: 18),
                          label: Text(l10n.resetAction),
                        ),
                        const Spacer(),
                        // Save button
                        ElevatedButton.icon(
                          onPressed: _isValid ? _saveChanges : null,
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(l10n.saveChanges),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceLG,
                              vertical: AppTheme.spaceSM,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Re-analyze button (conditional)
                    if (canReAnalyze && _hasChanges) ...[
                      const SizedBox(height: AppTheme.spaceSM2),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showReAnalyzeConfirmation,
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: Text(
                            l10n.askAiReanalyze(widget.remainingRequests),
                            style: theme.textTheme.bodySmall,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceLG,
                              vertical: AppTheme.spaceSM,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // No requests left message
                    if (!canReAnalyze)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(AppTheme.spaceSM),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer
                              .withValues(alpha: 0.3),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusXS),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: AppTheme.spaceSM),
                            Expanded(
                              child: Text(
                                l10n.noAiRequestsMessage,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
