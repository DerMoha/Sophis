import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/supplements_provider.dart';
import '../models/supplement.dart';

class SupplementEditSheet extends StatefulWidget {
  final Supplement? supplement;

  const SupplementEditSheet({super.key, this.supplement});

  @override
  State<SupplementEditSheet> createState() => _SupplementEditSheetState();
}

class _SupplementEditSheetState extends State<SupplementEditSheet> {
  static const _emerald = Color(0xFF10B981);

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

    // Parse reminder time or default to 9:00 AM
    if (widget.supplement?.reminderTime != null) {
      final parts = widget.supplement!.reminderTime!.split(':');
      _reminderTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } else {
      _reminderTime = const TimeOfDay(hour: 9, minute: 0);
    }

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
    final mediaQuery = MediaQuery.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _emerald.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.medication_liquid_rounded,
                    color: _emerald,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Title
                Text(
                  isEditing ? 'Edit Supplement' : 'Add Supplement',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
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
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: _hasError
                            ? Colors.red
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: _hasError
                            ? Colors.red
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: _hasError ? Colors.red : _emerald,
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
                        color: Colors.red,
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.alarm_rounded,
                          color: _emerald,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatTime(_reminderTime),
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
                      activeColor: _emerald,
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
                      backgroundColor: _emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isEditing ? 'Save Changes' : 'Add Supplement',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
              hourMinuteTextColor: _emerald,
              dayPeriodTextColor: _emerald,
              dialHandColor: _emerald,
              dialBackgroundColor: _emerald.withOpacity(0.1),
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

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
    final isDuplicate = provider.supplements.any((s) =>
        s.name.toLowerCase() == name.toLowerCase() &&
        s.id != widget.supplement?.id);

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A supplement named "$name" already exists'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final reminderTime = _formatTime(_reminderTime);

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
