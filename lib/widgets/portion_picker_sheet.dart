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
    super.dispose();
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

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
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
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // Preset portions from API
                  if (widget.item.servings.isNotEmpty) ...[
                    _SectionTitle(title: l10n.portion),
                    const SizedBox(height: 8),
                    _PortionGrid(
                      servings: widget.item.servings,
                      selected: _selectedServing,
                      onSelect: _onServingSelected,
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
                    const SizedBox(height: 8),
                    _CustomPortionChips(
                      portions: customPortions,
                      selectedGrams: _selectedGrams,
                      onSelect: (portion) {
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            suffixText: 'g',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: _onCustomAmountChanged,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _showSavePresetDialog,
                        icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                        label: Text(l10n.saveAsPreset),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom action bar
            _AddButton(
              grams: _selectedGrams,
              calories: nutrients['calories'] ?? 0,
              onAdd: () {
                widget.onAdd(_selectedGrams);
                Navigator.pop(context);
              },
            ),
          ],
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
          ? theme.colorScheme.primary.withOpacity(isDark ? 0.3 : 0.15)
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                serving.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${serving.grams.toStringAsFixed(0)}g',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
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
              ? theme.colorScheme.secondary.withOpacity(isDark ? 0.3 : 0.15)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onSelect(p),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.secondary
                      : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${p.grams.toStringAsFixed(0)}g',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
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

class _AddButton extends StatelessWidget {
  final double grams;
  final double calories;
  final VoidCallback onAdd;

  const _AddButton({
    required this.grams,
    required this.calories,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity(0.5),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
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
