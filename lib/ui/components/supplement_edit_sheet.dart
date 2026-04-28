import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/supplement.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/providers/supplements_provider.dart';
import 'package:sophis/utils/time_utils.dart';
import 'package:sophis/ui/components/modal_sheet.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';
import 'package:sophis/ui/theme/app_theme.dart';

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
    final l10n = AppLocalizations.of(context)!;
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
              title: l10n.supplements,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isEditing ? l10n.saveChanges : l10n.trackSupplementsSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name field
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                      border: Border.all(
                        color:
                            theme.colorScheme.outline.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.name,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nameController,
                          autofocus: !isEditing,
                          decoration: InputDecoration(
                            hintText: 'e.g., Omega-3, Vitamin C',
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMD,
                              ),
                              borderSide: BorderSide(
                                color: _hasError
                                    ? theme.colorScheme.error
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMD,
                              ),
                              borderSide: BorderSide(
                                color: _hasError
                                    ? theme.colorScheme.error
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMD,
                              ),
                              borderSide: BorderSide(
                                color: _hasError
                                    ? theme.colorScheme.error
                                    : accentColor,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Reminder time
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                      child: AnimatedContainer(
                        duration: AppTheme.animFast,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLG,
                          ),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSM,
                                ),
                              ),
                              child: Icon(
                                Icons.alarm_rounded,
                                color: accentColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.reminderTime,
                                    style:
                                        theme.textTheme.labelMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    TimeUtils.formatTimeOfDay(
                                      context,
                                      _reminderTime,
                                    ),
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Enabled switch
                  SwitchTile(
                    title: 'Enable Reminder',
                    subtitle: 'Get daily notifications',
                    icon: _enabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    value: _enabled,
                    onChanged: (value) {
                      setState(() => _enabled = value);
                    },
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spaceMD,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMD,
                              ),
                            ),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.18,
                              ),
                            ),
                          ),
                          child: Text(l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spaceMD,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusMD,
                              ),
                            ),
                          ),
                          child: Text(
                            isEditing ? l10n.saveChanges : l10n.save,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                      ),
                    ],
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
      final result = provider.addSupplement(supplement);
      if (result.isFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((result as Failure).message)),
        );
        return;
      }
    }

    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }
}
