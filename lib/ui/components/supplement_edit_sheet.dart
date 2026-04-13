import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/supplement.dart';
import '../../services/supplements_provider.dart';
import '../../utils/time_utils.dart';
import 'modal_sheet.dart';
import '../theme/app_theme.dart';

class SupplementEditSheet extends StatefulWidget {
  final Supplement? supplement;

  const SupplementEditSheet({super.key, this.supplement});

  @override
  State<SupplementEditSheet> createState() => _SupplementEditSheetState();
}

class _SupplementEditSheetState extends State<SupplementEditSheet> {
  late TextEditingController _nameController;
  late TimeOfDay _reminderTime;
  late bool _enabled;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.supplement?.name ?? '',
    );

    _reminderTime = TimeUtils.parseStoredTimeOrDefault(
      widget.supplement?.reminderTime,
      const TimeOfDay(hour: 9, minute: 0),
    );

    _enabled = widget.supplement?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get isEditing => widget.supplement != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    return ModalSheetSurface(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ModalSheetHandle(),
            ModalSheetHeader(
              icon: Icons.medication_liquid_rounded,
              iconColor: accentColor,
              iconBoxSize: 48,
              iconSize: 24,
              title: isEditing ? 'Edit Supplement' : 'Add Supplement',
            ),
            const SizedBox(height: 24),

            // Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name field
                  Text(
                    'Name',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    autofocus: !isEditing,
                    decoration: InputDecoration(
                      hintText: 'e.g., Omega-3, Vitamin C',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        borderSide: BorderSide(
                          color: _hasError
                              ? theme.colorScheme.error
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        borderSide: BorderSide(
                          color: _hasError
                              ? theme.colorScheme.error
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        borderSide: BorderSide(
                          color:
                              _hasError ? theme.colorScheme.error : accentColor,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      if (_hasError && value.isNotEmpty) {
                        setState(() => _hasError = false);
                      }
                    },
                  ),
                  if (_hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 12),
                      child: Text(
                        'Name cannot be empty',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Reminder time
                  Text(
                    'Reminder Time',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spaceMD),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.alarm_rounded,
                            color: accentColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            TimeUtils.formatTimeOfDay(
                              context,
                              _reminderTime,
                            ),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.edit_rounded,
                            color: theme.textTheme.bodySmall?.color,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Enabled switch
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enable Reminder',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Get daily notifications',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _enabled,
                        onChanged: (value) {
                          setState(() => _enabled = value);
                        },
                        activeThumbColor: accentColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spaceMD,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMD),
                        ),
                      ),
                      child: Text(
                        isEditing ? 'Save Changes' : 'Add Supplement',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cancel button
                  if (!isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: safeAreaBottom + 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
              hourMinuteTextColor: accentColor,
              dayPeriodTextColor: accentColor,
              dialHandColor: accentColor,
              dialBackgroundColor: accentColor.withValues(alpha: 0.1),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _reminderTime = picked);
    }
  }

  void _save() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _hasError = true);
      HapticFeedback.heavyImpact();
      return;
    }

    final provider = context.read<SupplementsProvider>();

    // Check for duplicate names (excluding current supplement when editing)
    final isDuplicate = provider.supplements.any(
      (s) =>
          s.name.toLowerCase() == name.toLowerCase() &&
          s.id != widget.supplement?.id,
    );

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A supplement named "$name" already exists'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final reminderTime = TimeUtils.formatStoredTime(_reminderTime);

    if (isEditing) {
      // Update existing supplement
      final updated = widget.supplement!.copyWith(
        name: name,
        reminderTime: reminderTime,
        enabled: _enabled,
      );
      provider.updateSupplement(updated);
    } else {
      // Add new supplement
      final supplement = Supplement(
        id: const Uuid().v4(),
        name: name,
        reminderTime: reminderTime,
        enabled: _enabled,
        sortOrder: provider.supplements.length,
        createdAt: DateTime.now(),
      );
      provider.addSupplement(supplement);
    }

    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }
}
