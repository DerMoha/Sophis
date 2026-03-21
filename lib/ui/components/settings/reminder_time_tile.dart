import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';

class ReminderTimeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? time;
  final TimeOfDay defaultTime;
  final ValueChanged<String?> onChanged;

  const ReminderTimeTile({
    super.key,
    required this.icon,
    required this.title,
    required this.time,
    required this.defaultTime,
    required this.onChanged,
  });

  TimeOfDay _parseTime(String? timeStr) {
    if (timeStr == null) return defaultTime;
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentTime = _parseTime(time);
    final isEnabled = time != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEnabled
            ? theme.colorScheme.primary.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isEnabled
                  ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : theme.colorScheme.outline.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isEnabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall,
                ),
                if (isEnabled)
                  Text(
                    currentTime.format(context),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Text(
                    AppLocalizations.of(context)!.notSet,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (isEnabled)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => onChanged(null),
              visualDensity: VisualDensity.compact,
            ),
          IconButton(
            icon: Icon(
              isEnabled ? Icons.edit_outlined : Icons.add,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: currentTime,
              );
              if (picked != null) {
                onChanged(_formatTime(picked));
              }
            },
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
