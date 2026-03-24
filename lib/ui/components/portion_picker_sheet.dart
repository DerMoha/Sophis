import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/custom_portion.dart';
import '../../models/food_item.dart';
import '../../models/nutrition_totals.dart';
import '../../models/serving_size.dart';
import '../../services/barcode_lookup_service.dart';
import '../../services/nutrition_provider.dart';

import '../theme/app_theme.dart';
import 'edit_product_sheet.dart';

/// A modal bottom sheet for selecting portion sizes
class PortionPickerSheet extends StatefulWidget {
  final FoodItem item;
  final String meal;
  final Function(double grams) onAdd;
  final String? barcode;
  final dynamic lookupService; // BarcodeLookupService, nullable
  final Function(FoodItem updatedProduct)? onProductUpdated;

  const PortionPickerSheet({
    super.key,
    required this.item,
    required this.meal,
    required this.onAdd,
    this.barcode,
    this.lookupService,
    this.onProductUpdated,
  });

  @override
  State<PortionPickerSheet> createState() => _PortionPickerSheetState();
}

class _PortionPickerSheetState extends State<PortionPickerSheet> {
  static const List<double> _portionMultipliers = <double>[
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
    2.25,
    2.5,
    2.75,
    3.0,
    3.25,
    3.5,
    3.75,
    4.0,
  ];

  double _selectedGrams = 100;
  final _customController = TextEditingController(text: '100');
  final _focusNode = FocusNode(); // For keyboard management
  late final FixedExtentScrollController _portionWheelController;

  String get _productKey => CustomPortion.createProductKey(
        barcode: widget.item.barcode,
        name: widget.item.name,
      );

  ServingSize? get _baseServing {
    if (widget.item.servings.isEmpty) {
      return null;
    }

    for (final serving in widget.item.servings) {
      if ((serving.multiplier - 1.0).abs() < 0.001) {
        return serving;
      }
    }

    return widget.item.servings.first;
  }

  @override
  void initState() {
    super.initState();
    _portionWheelController = FixedExtentScrollController(
      initialItem: _portionMultipliers.indexOf(1.0),
    );

    // Select first serving by default if available
    final defaultServing = _baseServing;
    if (defaultServing != null) {
      _selectedGrams = defaultServing.grams;
      _customController.text = defaultServing.grams.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    _focusNode.dispose();
    _portionWheelController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _addAndClose() {
    _dismissKeyboard();
    widget.onAdd(_selectedGrams);
    Navigator.pop(context);
  }

  NutritionTotals get _calculatedNutrients =>
      widget.item.calculateFor(_selectedGrams);

  void _onPortionMultiplierSelected(double multiplier) {
    final baseServing = _baseServing;
    if (baseServing == null) {
      return;
    }

    setState(() {
      _selectedGrams = baseServing.grams * multiplier;
      _customController.text = _selectedGrams.toStringAsFixed(0);
    });
  }

  void _onCustomAmountChanged(String value) {
    final grams = double.tryParse(value);
    if (grams != null && grams > 0) {
      setState(() {
        _selectedGrams = grams;
      });
      _syncWheelToGrams(grams);
    }
  }

  void _syncWheelToGrams(double grams) {
    final baseServing = _baseServing;
    if (baseServing == null || !_portionWheelController.hasClients) {
      return;
    }

    final multiplier = grams / baseServing.grams;
    final index = _portionMultipliers.indexWhere(
      (option) => (option - multiplier).abs() < 0.001,
    );
    if (index != -1) {
      _portionWheelController.jumpToItem(index);
    }
  }

  void _showSavePresetDialog() {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.saveAsPreset),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l10n.portionName,
            hintText: l10n.portionNameHint,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                final portion = CustomPortion(
                  id: const Uuid().v4(),
                  productKey: _productKey,
                  name: nameController.text.trim(),
                  grams: _selectedGrams,
                  createdAt: DateTime.now(),
                );
                context.read<NutritionProvider>().addCustomPortion(portion);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.portionSaved)),
                );
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final customPortions = context
        .watch<NutritionProvider>()
        .getCustomPortionsForProduct(_productKey);
    final nutrients = _calculatedNutrients;

    // Track keyboard height to adjust layout on iOS
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    return GestureDetector(
      // Dismiss keyboard when tapping outside TextField
      onTap: _dismissKeyboard,
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              _DragHandle(),

              // Product header
              _ProductHeader(
                item: widget.item,
                grams: _selectedGrams,
                nutrients: nutrients,
                onEdit: widget.barcode != null && widget.lookupService != null
                    ? () => _openEditSheet()
                    : null,
              ),

              Expanded(
                child: NotificationListener<ScrollNotification>(
                  // Only dismiss keyboard on user-initiated drag scrolls
                  // (not on programmatic scrolls caused by layout changes)
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification &&
                        notification.dragDetails != null) {
                      _dismissKeyboard();
                    }
                    return false;
                  },
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppTheme.spaceLG),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      // Preset portions from API
                      if (_baseServing != null) ...[
                        _SectionTitle(title: l10n.portion),
                        const SizedBox(height: AppTheme.spaceSM2),
                        _PortionGrid(
                          controller: _portionWheelController,
                          multipliers: _portionMultipliers,
                          baseGrams: _baseServing!.grams,
                          selectedGrams: _selectedGrams,
                          onChanged: (multiplier) {
                            _dismissKeyboard();
                            _onPortionMultiplierSelected(multiplier);
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Custom portions (user-defined)
                      if (customPortions.isNotEmpty) ...[
                        _SectionTitle(
                          title: l10n.myPortions,
                          trailing: TextButton(
                            onPressed: () =>
                                _showEditPortionsSheet(customPortions),
                            child: Text(l10n.edit),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceSM2),
                        _CustomPortionChips(
                          portions: customPortions,
                          selectedGrams: _selectedGrams,
                          onSelect: (portion) {
                            _dismissKeyboard();
                            setState(() {
                              _selectedGrams = portion.grams;
                              _customController.text =
                                  portion.grams.toStringAsFixed(0);
                            });
                            _syncWheelToGrams(portion.grams);
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Custom amount input
                      _SectionTitle(title: l10n.customAmount),
                      const SizedBox(height: AppTheme.spaceSM2),
                      _CustomAmountInput(
                        controller: _customController,
                        focusNode: _focusNode,
                        onChanged: _onCustomAmountChanged,
                        onSubmitted: (_) =>
                            _addAndClose(), // Add directly when pressing Done
                        onSavePreset: _showSavePresetDialog,
                      ),

                      // Extra padding when keyboard is visible to allow scrolling
                      if (isKeyboardVisible)
                        SizedBox(height: keyboardHeight * 0.5),
                    ],
                  ),
                ),
              ),

              // Bottom action bar - with keyboard-aware padding
              _AddButton(
                grams: _selectedGrams,
                calories: nutrients.calories,
                keyboardHeight: keyboardHeight,
                onAdd: _addAndClose,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditSheet() {
    final lookupService = widget.lookupService as BarcodeLookupService;
    final barcode = widget.barcode!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProductSheet(
        barcode: barcode,
        existingProduct: widget.item,
        showSubmitToOff: true,
        onSave: (product) async {
          await lookupService.saveUserCorrection(barcode, product);
          if (widget.onProductUpdated != null) {
            widget.onProductUpdated!(product);
          }
        },
        onReset: () async {
          Navigator.pop(context);
          final result = await lookupService.resetCorrection(barcode);
          if (result.item != null && widget.onProductUpdated != null) {
            widget.onProductUpdated!(result.item!);
          }
        },
      ),
    );
  }

  void _showEditPortionsSheet(List<CustomPortion> portions) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.editPortions,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...portions.map(
              (p) => ListTile(
                title: Text(p.name),
                subtitle: Text('${p.grams.toStringAsFixed(0)}g'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    context.read<NutritionProvider>().removeCustomPortion(p.id);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  final FoodItem item;
  final double grams;
  final NutritionTotals nutrients;
  final VoidCallback? onEdit;

  const _ProductHeader({
    required this.item,
    required this.grams,
    required this.nutrients,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceLG,
        vertical: AppTheme.spaceSM,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          // Product image
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            clipBehavior: Clip.antiAlias,
            child: item.imageUrl != null
                ? Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderIcon(theme),
                  )
                : _placeholderIcon(theme),
          ),
          const SizedBox(width: 12),

          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.brand != null && item.brand!.isNotEmpty)
                  Text(
                    item.brand!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                Text(
                  item.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${grams.toStringAsFixed(0)}g = ${nutrients.calories.toStringAsFixed(0)} kcal',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
        ],
      ),
    );
  }

  Widget _placeholderIcon(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.restaurant_outlined,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        size: 24,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _PortionGrid extends StatelessWidget {
  final FixedExtentScrollController controller;
  final List<double> multipliers;
  final double baseGrams;
  final double selectedGrams;
  final ValueChanged<double> onChanged;

  const _PortionGrid({
    required this.controller,
    required this.multipliers,
    required this.baseGrams,
    required this.selectedGrams,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final currentPortions = selectedGrams / baseGrams;

    return Column(
      children: [
        Container(
          height: 188,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: Container(
                  height: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: controller,
                itemExtent: 60,
                perspective: 0.003,
                diameterRatio: 1.6,
                physics: const FixedExtentScrollPhysics(),
                useMagnifier: true,
                magnification: 1.06,
                overAndUnderCenterOpacity: 0.55,
                onSelectedItemChanged: (index) => onChanged(multipliers[index]),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: multipliers.length,
                  builder: (context, index) {
                    final multiplier = multipliers[index];
                    final grams = baseGrams * multiplier;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_formatPortionValue(context, multiplier)} ${l10n.portion}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${grams.toStringAsFixed(0)}g',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_formatPortionValue(context, currentPortions)} ${l10n.portion} • ${selectedGrams.toStringAsFixed(0)}g',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '1 ${l10n.portion} = ${baseGrams.toStringAsFixed(0)}g',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatPortionValue(BuildContext context, double value) {
    final locale = Localizations.localeOf(context).toString();
    final decimalDigits = (value - value.roundToDouble()).abs() < 0.001
        ? 0
        : ((value * 10) - (value * 10).roundToDouble()).abs() < 0.001
            ? 1
            : 2;

    return NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: decimalDigits,
    ).format(value);
  }
}

class _CustomPortionChips extends StatelessWidget {
  final List<CustomPortion> portions;
  final double selectedGrams;
  final Function(CustomPortion) onSelect;

  const _CustomPortionChips({
    required this.portions,
    required this.selectedGrams,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Wrap(
      spacing: AppTheme.spaceSM,
      runSpacing: AppTheme.spaceSM,
      children: portions.map((p) {
        final isSelected = (selectedGrams - p.grams).abs() < 0.1;

        return Material(
          color: isSelected
              ? theme.colorScheme.secondary
                  .withValues(alpha: isDark ? 0.25 : 0.12)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          child: InkWell(
            onTap: () => onSelect(p),
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceSM,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Custom portion icon
                  Icon(
                    Icons.bookmark_rounded,
                    size: 16,
                    color: isSelected
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  // Portion name
                  Text(
                    p.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Grams badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.secondary.withValues(alpha: 0.2)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                    ),
                    child: Text(
                      '${p.grams.toStringAsFixed(0)}g',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM AMOUNT INPUT - Better layout with inline save button
// ─────────────────────────────────────────────────────────────────────────────

class _CustomAmountInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSavePreset;

  const _CustomAmountInput({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onSavePreset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Gram input - larger and more prominent
            Expanded(
              flex: 2,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  suffixText: 'g',
                  suffixStyle: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                    vertical: AppTheme.spaceMD,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              ),
            ),
            const SizedBox(width: 12),
            // Save preset button - icon only for cleaner look
            IconButton.filled(
              onPressed: onSavePreset,
              icon: const Icon(Icons.bookmark_add_outlined),
              tooltip: l10n.saveAsPreset,
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                padding: const EdgeInsets.all(AppTheme.spaceMD),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Hint text explaining keyboard behavior
        Text(
          l10n.pressEnterToAdd,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD BUTTON - Keyboard-aware with proper padding
// ─────────────────────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final double grams;
  final double calories;
  final double keyboardHeight;
  final VoidCallback onAdd;

  const _AddButton({
    required this.grams,
    required this.calories,
    required this.keyboardHeight,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AnimatedContainer(
      duration: AppTheme.animFaster,
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        // Add extra padding when keyboard is visible
        keyboardHeight > 0 ? keyboardHeight + 12 : 16,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        // Disable bottom safe area when keyboard is visible (we handle it manually)
        bottom: keyboardHeight == 0,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
            ),
            child: Text(
              l10n.addWithAmount(
                grams.toStringAsFixed(0),
                calories.toStringAsFixed(0),
              ),
              style: theme.textTheme.labelLarge,
            ),
          ),
        ),
      ),
    );
  }
}
