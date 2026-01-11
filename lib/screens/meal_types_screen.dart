import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/custom_meal_type.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';

class MealTypesScreen extends StatefulWidget {
  const MealTypesScreen({super.key});

  @override
  State<MealTypesScreen> createState() => _MealTypesScreenState();
}

class _MealTypesScreenState extends State<MealTypesScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final mealTypes = settings.mealTypes;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.customizeMealTypes),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditMealTypeSheet(context, null),
            tooltip: l10n.addMealType,
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: mealTypes.length,
        onReorder: (oldIndex, newIndex) {
          settings.reorderMealTypes(oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          final mealType = mealTypes[index];
          return _MealTypeTile(
            key: ValueKey(mealType.id),
            mealType: mealType,
            onEdit: () => _showEditMealTypeSheet(context, mealType),
            onDelete: mealType.isDefault
                ? null
                : () => _confirmDelete(context, mealType),
          );
        },
      ),
    );
  }

  void _showEditMealTypeSheet(BuildContext context, CustomMealType? mealType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _EditMealTypeSheet(mealType: mealType),
    );
  }

  void _confirmDelete(BuildContext context, CustomMealType mealType) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteMealType),
        content: Text(l10n.deleteConfirmation(mealType.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<SettingsProvider>().removeMealType(mealType.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.mealTypeDeleted)),
              );
            },
            child: Text(l10n.delete, style: const TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _MealTypeTile extends StatelessWidget {
  final CustomMealType mealType;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _MealTypeTile({
    super.key,
    required this.mealType,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: mealType.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            mealType.icon,
            color: mealType.color,
          ),
        ),
        title: Text(mealType.name),
        subtitle: mealType.reminderTime != null
            ? Text('${l10n.reminderTime}: ${mealType.reminderTime}')
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                onPressed: onDelete,
              )
            else
              const SizedBox(width: 48), // Placeholder to keep alignment
            ReorderableDragStartListener(
              index: 0, // Index is handled by parent
              child: Icon(
                Icons.drag_handle,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditMealTypeSheet extends StatefulWidget {
  final CustomMealType? mealType;

  const _EditMealTypeSheet({this.mealType});

  @override
  State<_EditMealTypeSheet> createState() => _EditMealTypeSheetState();
}

class _EditMealTypeSheetState extends State<_EditMealTypeSheet> {
  late TextEditingController _nameController;
  late int _selectedIconIndex;
  late int _selectedColorIndex;
  TimeOfDay? _reminderTime;

  bool get isEditing => widget.mealType != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.mealType?.name ?? '');

    // Find selected icon index
    _selectedIconIndex = widget.mealType != null
        ? CustomMealType.availableIcons.indexWhere(
            (icon) => icon.codePoint == widget.mealType!.iconCodePoint)
        : 0;
    if (_selectedIconIndex < 0) _selectedIconIndex = 0;

    // Find selected color index
    _selectedColorIndex = widget.mealType != null
        ? CustomMealType.availableColors.indexWhere(
            (color) => color.toARGB32() == widget.mealType!.colorValue)
        : 0;
    if (_selectedColorIndex < 0) _selectedColorIndex = 0;

    // Parse reminder time
    if (widget.mealType?.reminderTime != null) {
      final parts = widget.mealType!.reminderTime!.split(':');
      if (parts.length == 2) {
        _reminderTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  isEditing ? l10n.editMealType : l10n.addMealType,
                  style: theme.textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Name input
            Text(l10n.mealName, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: l10n.enterMealName,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // Icon selection
            Text(l10n.mealIcon, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                CustomMealType.availableIcons.length,
                (index) {
                  final icon = CustomMealType.availableIcons[index];
                  final isSelected = index == _selectedIconIndex;
                  return InkWell(
                    onTap: () => setState(() => _selectedIconIndex = index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.1)
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: theme.colorScheme.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Icon(
                        icon,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Color selection
            Text(l10n.mealColor, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                CustomMealType.availableColors.length,
                (index) {
                  final color = CustomMealType.availableColors[index];
                  final isSelected = index == _selectedColorIndex;
                  return InkWell(
                    onTap: () => setState(() => _selectedColorIndex = index),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: theme.colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Reminder time
            Text(l10n.reminderTime, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickReminderTime,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _reminderTime != null
                          ? _reminderTime!.format(context)
                          : l10n.notSet,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const Spacer(),
                    if (_reminderTime != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _reminderTime = null),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _reminderTime = time);
    }
  }

  void _save() {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterMealName)),
      );
      return;
    }

    final settings = context.read<SettingsProvider>();
    final selectedIcon = CustomMealType.availableIcons[_selectedIconIndex];
    final selectedColor = CustomMealType.availableColors[_selectedColorIndex];
    final reminderTimeString = _reminderTime != null
        ? '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
        : null;

    if (isEditing) {
      // Update existing meal type
      final updated = widget.mealType!.copyWith(
        name: name,
        iconCodePoint: selectedIcon.codePoint,
        colorValue: selectedColor.toARGB32(),
        reminderTime: reminderTimeString,
        clearReminder: reminderTimeString == null,
      );
      settings.updateMealType(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mealTypeUpdated)),
      );
    } else {
      // Create new meal type
      final newMealType = CustomMealType(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        iconCodePoint: selectedIcon.codePoint,
        colorValue: selectedColor.toARGB32(),
        reminderTime: reminderTimeString,
        sortOrder: settings.mealTypes.length,
        isDefault: false,
      );
      settings.addMealType(newMealType);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mealTypeAdded)),
      );
    }

    Navigator.pop(context);
  }
}
