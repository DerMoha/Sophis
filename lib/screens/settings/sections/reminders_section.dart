import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/settings_provider.dart';
import '../../../ui/components/settings/settings_tiles.dart';
import '../../../ui/components/settings/reminder_time_tile.dart';

class RemindersSection extends StatelessWidget {
  final SettingsProvider settings;

  const RemindersSection({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        SwitchTile(
          title: l10n.enableReminders,
          subtitle: l10n.enableRemindersSubtitle,
          icon: Icons.alarm_outlined,
          value: settings.remindersEnabled,
          onChanged: settings.setRemindersEnabled,
        ),
        if (settings.remindersEnabled) ...[
          const SizedBox(height: 16),
          ReminderTimeTile(
            icon: Icons.wb_twilight_rounded,
            title: l10n.breakfast,
            time: settings.breakfastReminderTime,
            defaultTime: const TimeOfDay(hour: 8, minute: 0),
            onChanged: settings.setBreakfastReminder,
          ),
          const SizedBox(height: 8),
          ReminderTimeTile(
            icon: Icons.wb_sunny_rounded,
            title: l10n.lunch,
            time: settings.lunchReminderTime,
            defaultTime: const TimeOfDay(hour: 12, minute: 30),
            onChanged: settings.setLunchReminder,
          ),
          const SizedBox(height: 8),
          ReminderTimeTile(
            icon: Icons.nights_stay_rounded,
            title: l10n.dinner,
            time: settings.dinnerReminderTime,
            defaultTime: const TimeOfDay(hour: 18, minute: 30),
            onChanged: settings.setDinnerReminder,
          ),
        ],
      ],
    );
  }
}
