import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void initState() {
    super.initState();
    _setupPortionListener();
    _setupValidationListeners();
  }

  void _setupPortionListener() {
    widget.result.portionController.addListener(() {
      if (!_autoScaleEnabled) return;

      final newPortion = double.tryParse(widget.result.portionController.text);
      if (newPortion == null || newPortion <= 0) return;

      final scaled = widget.result.originalAnalysis.scaledToPortion(newPortion);

      // Update macro controllers without triggering infinite loop
      widget.result.caloriesController.text = scaled.calories.toStringAsFixed(0);
      widget.result.proteinController.text = scaled.protein.toStringAsFixed(1);
      widget.result.carbsController.text = scaled.carbs.toStringAsFixed(1);
      widget.result.fatController.text = scaled.fat.toStringAsFixed(1);
    });
  }

  void _setupValidationListeners() {
    final controllers = [
      widget.result.nameController,
      widget.result.portionController,
      widget.result.caloriesController,
      widget.result.proteinController,
      widget.result.carbsController,
      widget.result.fatController,
    ];

    for (final controller in controllers) {
      controller.addListener(() {
        setState(() {
          _isValid = _formKey.currentState?.validate() ?? false;
        });
      });
    }
  }

  void _resetToOriginal() {
    final original = widget.result.originalAnalysis;
    widget.result.nameController.text = original.name;
    widget.result.portionController.text = original.portionGrams.toStringAsFixed(0);
    widget.result.caloriesController.text = original.calories.toStringAsFixed(0);
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
          title: const Text('Confirm Re-analysis'),
          content: Text(
            'You have ${widget.remainingRequests} request(s) remaining today. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _reAnalyze();
              },
              child: const Text('Continue'),
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
        widget.result.portionController.text != original.portionGrams.toStringAsFixed(0) ||
        widget.result.caloriesController.text != original.calories.toStringAsFixed(0) ||
        widget.result.proteinController.text != original.protein.toStringAsFixed(1) ||
        widget.result.carbsController.text != original.carbs.toStringAsFixed(1) ||
        widget.result.fatController.text != original.fat.toStringAsFixed(1);
  }

  String? _validatePositiveNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final number = double.tryParse(value);
    if (number == null) {
      return 'Enter a valid number';
    }
    if (number < 0) {
      return '$fieldName cannot be negative';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Food name is required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final showLowRequestWarning = widget.remainingRequests < 5 && widget.remainingRequests > 0;
    final canReAnalyze = widget.remainingRequests > 0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withAlpha(77),
              borderRadius: BorderRadius.circular(2),
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
                        color: theme.colorScheme.primary.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Edit Food Analysis',
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
                          ? Colors.white.withAlpha(26)
                          : Colors.black.withAlpha(13),
                      borderRadius: BorderRadius.circular(8),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warning.withAlpha(77)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only ${widget.remainingRequests} AI request(s) left today',
                      style: TextStyle(
                        color: AppTheme.warning,
                        fontSize: 12,
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
                        labelText: 'Food name',
                        hintText: 'e.g., Chicken Breast',
                        prefixIcon: const Icon(Icons.restaurant, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: _validateName,
                    ),
                    const SizedBox(height: 16),

                    // Portion size
                    TextFormField(
                      controller: widget.result.portionController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))],
                      decoration: InputDecoration(
                        labelText: 'Portion size',
                        hintText: '100',
                        prefixIcon: const Icon(Icons.scale, size: 20),
                        suffixText: 'g',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (v) => _validatePositiveNumber(v, 'Portion'),
                    ),
                    const SizedBox(height: 16),

                    // Auto-scale toggle
                    SwitchListTile(
                      value: _autoScaleEnabled,
                      onChanged: (value) => setState(() => _autoScaleEnabled = value),
                      title: const Text('Auto-scale nutrition'),
                      subtitle: const Text('Adjust macros when portion changes'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),

                    // Macros section header
                    Text(
                      'NUTRITION VALUES',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Calories
                    TextFormField(
                      controller: widget.result.caloriesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))],
                      decoration: InputDecoration(
                        labelText: 'Calories',
                        hintText: '200',
                        prefixIcon: const Icon(Icons.local_fire_department_outlined, size: 20),
                        suffixText: 'kcal',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (v) => _validatePositiveNumber(v, 'Calories'),
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
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))],
                            decoration: InputDecoration(
                              labelText: 'Protein',
                              hintText: '20',
                              suffixText: 'g',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            validator: (v) => _validatePositiveNumber(v, 'Protein'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Carbs
                        Expanded(
                          child: TextFormField(
                            controller: widget.result.carbsController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))],
                            decoration: InputDecoration(
                              labelText: 'Carbs',
                              hintText: '30',
                              suffixText: 'g',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            validator: (v) => _validatePositiveNumber(v, 'Carbs'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Fat
                        Expanded(
                          child: TextFormField(
                            controller: widget.result.fatController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))],
                            decoration: InputDecoration(
                              labelText: 'Fat',
                              hintText: '10',
                              suffixText: 'g',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            validator: (v) => _validatePositiveNumber(v, 'Fat'),
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
                          label: const Text('Reset'),
                        ),
                        const Spacer(),
                        // Save button
                        ElevatedButton.icon(
                          onPressed: _isValid ? _saveChanges : null,
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Save Changes'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),

                    // Re-analyze button (conditional)
                    if (canReAnalyze && _hasChanges) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showReAnalyzeConfirmation,
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: Text(
                            'Ask AI to Re-evaluate (uses 1 of ${widget.remainingRequests} requests)',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ),
                    ],

                    // No requests left message
                    if (!canReAnalyze)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withAlpha(77),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No AI requests remaining today. You can still manually edit values.',
                                style: TextStyle(
                                  fontSize: 11,
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
