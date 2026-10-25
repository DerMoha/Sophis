import 'package:flutter/material.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/ui/components/common/app_surface.dart';
import 'package:sophis/utils/time_utils.dart';

class ReminderTimeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? time;
  final TimeOfDay defaultTime;
  final ValueChanged<String?> onChanged;
  final bool showDivider;

  const ReminderTimeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.time,
    required this.defaultTime,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = time != null;
    final currentTime = TimeUtils.parseStoredTimeOrDefault(time, defaultTime);

    return AppRow(
      title: title,
      icon: icon,
      subtitle: isEnabled
          ? TimeUtils.formatTimeOfDay(context, currentTime)
          : AppLocalizations.of(context)!.notSet,
      showDivider: showDivider,
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: currentTime,
        );
        if (picked != null) {
          onChanged(TimeUtils.formatStoredTime(picked));
        }
      },
      trailing: isEnabled
          ? IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: () => onChanged(null),
              visualDensity: VisualDensity.compact,
            )
          : Icon(Icons.add, size: 20, color: theme.colorScheme.primary),
    );
  }
}
