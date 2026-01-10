import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_item.dart';
import '../models/serving_size.dart';
import '../models/custom_portion.dart';
import '../services/nutrition_provider.dart';
import '../l10n/generated/app_localizations.dart';

/// A modal bottom sheet for selecting portion sizes
class PortionPickerSheet extends StatefulWidget {
  final FoodItem item;
  final String meal;
  final Function(double grams) onAdd;

  const PortionPickerSheet({
    super.key,
    required this.item,
    required this.meal,
    required this.onAdd,
  });

  @override
  State<PortionPickerSheet> createState() => _PortionPickerSheetState();
}

class _PortionPickerSheetState extends State<PortionPickerSheet> {
  double _selectedGrams = 100;
  ServingSize? _selectedServing;
  final _customController = TextEditingController(text: '100');
  final _focusNode = FocusNode(); // For keyboard management

  String get _productKey => CustomPortion.createProductKey(
        barcode: widget.item.barcode,
        name: widget.item.name,
      );

  @override
  void initState() {
    super.initState();
    // Select first serving by default if available
    if (widget.item.servings.isNotEmpty) {
      // Find the 1x serving (multiplier == 1.0)
      final defaultServing = widget.item.servings.firstWhere(
        (s) => s.multiplier == 1.0,
        orElse: () => widget.item.servings.first,
      );
      _selectedServing = defaultServing;
      _selectedGrams = defaultServing.grams;
      _customController.text = defaultServing.grams.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    _focusNode.dispose();
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

  Map<String, double> get _calculatedNutrients =>
      widget.item.calculateFor(_selectedGrams);

  void _onServingSelected(ServingSize serving) {
    setState(() {
      _selectedServing = serving;
      _selectedGrams = serving.grams;
      _customController.text = serving.grams.toStringAsFixed(0);
    });
  }

  void _onCustomAmountChanged(String value) {
    final grams = double.tryParse(value);
    if (grams != null && grams > 0) {
      setState(() {
        _selectedServing = null;
        _selectedGrams = grams;
      });
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
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
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
              ),

              Expanded(
                child: NotificationListener<ScrollNotification>(
                  // Dismiss keyboard when scrolling
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification) {
                      _dismissKeyboard();
                    }
                    return false;
                  },
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      // Preset portions from API
                      if (widget.item.servings.isNotEmpty) ...[
                        _SectionTitle(title: l10n.portion),
                        const SizedBox(height: 12),
                        _PortionGrid(
                          servings: widget.item.servings,
                          selected: _selectedServing,
                          onSelect: (serving) {
                            _dismissKeyboard();
                            _onServingSelected(serving);
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Custom portions (user-defined)
                      if (customPortions.isNotEmpty) ...[
                        _SectionTitle(
                          title: l10n.myPortions,
                          trailing: TextButton(
                            onPressed: () => _showEditPortionsSheet(customPortions),
                            child: Text(l10n.edit),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _CustomPortionChips(
                          portions: customPortions,
                          selectedGrams: _selectedGrams,
                          onSelect: (portion) {
                            _dismissKeyboard();
                            setState(() {
                              _selectedServing = null;
                              _selectedGrams = portion.grams;
                              _customController.text =
                                  portion.grams.toStringAsFixed(0);
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Custom amount input
                      _SectionTitle(title: l10n.customAmount),
                      const SizedBox(height: 12),
                      _CustomAmountInput(
                        controller: _customController,
                        focusNode: _focusNode,
                        onChanged: _onCustomAmountChanged,
                        onSubmitted: (_) => _addAndClose(), // Add directly when pressing Done
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
                calories: nutrients['calories'] ?? 0,
                keyboardHeight: keyboardHeight,
                onAdd: _addAndClose,
              ),
            ],
          ),
        ),
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
            ...portions.map((p) => ListTile(
                  title: Text(p.name),
                  subtitle: Text('${p.grams.toStringAsFixed(0)}g'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      context.read<NutritionProvider>().removeCustomPortion(p.id);
                      Navigator.pop(ctx);
                    },
                  ),
                )),
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
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  final FoodItem item;
  final double grams;
  final Map<String, double> nutrients;

  const _ProductHeader({
    required this.item,
    required this.grams,
    required this.nutrients,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.5),
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
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
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
                  '${grams.toStringAsFixed(0)}g = ${nutrients['calories']?.toStringAsFixed(0) ?? 0} kcal',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderIcon(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.restaurant_outlined,
        color: theme.colorScheme.onSurface.withOpacity(0.3),
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
  final List<ServingSize> servings;
  final ServingSize? selected;
  final Function(ServingSize) onSelect;

  const _PortionGrid({
    required this.servings,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: servings.map((s) => _PortionChip(
            serving: s,
            isSelected: selected == s,
            onTap: () => onSelect(s),
          )).toList(),
    );
  }
}

class _PortionChip extends StatelessWidget {
  final ServingSize serving;
  final bool isSelected;
  final VoidCallback onTap;

  const _PortionChip({
    required this.serving,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.12)
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Portion name
              Text(
                serving.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              // Grams badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${serving.grams.toStringAsFixed(0)}g',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      spacing: 8,
      runSpacing: 8,
      children: portions.map((p) {
        final isSelected = (selectedGrams - p.grams).abs() < 0.1;

        return Material(
          color: isSelected
              ? theme.colorScheme.secondary.withValues(alpha: isDark ? 0.25 : 0.12)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onSelect(p),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
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
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Grams badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.secondary.withValues(alpha: 0.2)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.all(16),
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
      duration: const Duration(milliseconds: 200),
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
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              l10n.addWithAmount(
                grams.toStringAsFixed(0),
                calories.toStringAsFixed(0),
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
