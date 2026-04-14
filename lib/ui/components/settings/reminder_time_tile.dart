import 'package:flutter/material.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/utils/time_utils.dart';
import 'package:sophis/ui/theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = time != null;
    final currentTime = TimeUtils.parseStoredTimeOrDefault(time, defaultTime);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: currentTime,
          );
          if (picked != null) {
            onChanged(TimeUtils.formatStoredTime(picked));
          }
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Container(
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
                    Text(title, style: theme.textTheme.titleSmall),
                    Text(
                      isEnabled
                          ? TimeUtils.formatTimeOfDay(context, currentTime)
                          : AppLocalizations.of(context)!.notSet,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isEnabled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: isEnabled ? FontWeight.w500 : null,
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
              Icon(
                isEnabled ? Icons.edit_outlined : Icons.add,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
