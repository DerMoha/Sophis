import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/app_settings.dart';
import '../services/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Appearance Section
              const _SectionHeader(title: 'Appearance'),
              _SettingsTile(
                icon: Icons.palette_outlined,
                title: l10n.theme,
                trailing: DropdownButton<ThemeMode>(
                  value: settings.themeMode,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text(l10n.systemDefault),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text(l10n.light),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text(l10n.dark),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) settings.setThemeMode(value);
                  },
                ),
              ),
              
              // Accent Color Picker
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Accent Color', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: AccentColors.presets.map((color) {
                        final isSelected = color.toARGB32() == settings.accentColorValue;
                        return GestureDetector(
                          onTap: () => settings.setAccentColor(color.toARGB32()),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected 
                                  ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                                  : null,
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: color.withAlpha(100),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ] : null,
                            ),
                            child: isSelected 
                                ? const Icon(Icons.check, color: Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              
              // Language Section
              _SectionHeader(title: l10n.language),
              _SettingsTile(
                icon: Icons.language_outlined,
                title: l10n.language,
                trailing: DropdownButton<String?>(
                  value: settings.localeOverride,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.systemDefault),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Text(l10n.english),
                    ),
                    DropdownMenuItem(
                      value: 'de',
                      child: Text(l10n.german),
                    ),
                  ],
                  onChanged: (value) => settings.setLocale(value),
                ),
              ),
              const Divider(),
              
              // Meal Reminders Section
              const _SectionHeader(title: 'Meal Reminders'),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('Enable Reminders'),
                subtitle: const Text('Get notified when it\'s time to eat'),
                value: settings.remindersEnabled,
                onChanged: (value) => settings.setRemindersEnabled(value),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              if (settings.remindersEnabled) ...[
                _ReminderTimeTile(
                  icon: Icons.wb_twilight_outlined,
                  title: 'Breakfast',
                  time: settings.breakfastReminderTime,
                  defaultTime: const TimeOfDay(hour: 8, minute: 0),
                  onChanged: (time) => settings.setBreakfastReminder(time),
                ),
                _ReminderTimeTile(
                  icon: Icons.wb_sunny_outlined,
                  title: 'Lunch',
                  time: settings.lunchReminderTime,
                  defaultTime: const TimeOfDay(hour: 12, minute: 30),
                  onChanged: (time) => settings.setLunchReminder(time),
                ),
                _ReminderTimeTile(
                  icon: Icons.nights_stay_outlined,
                  title: 'Dinner',
                  time: settings.dinnerReminderTime,
                  defaultTime: const TimeOfDay(hour: 18, minute: 30),
                  onChanged: (time) => settings.setDinnerReminder(time),
                ),
              ],
              const Divider(),
              
              // AI Section
              const _SectionHeader(title: 'AI'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Gemini API Key',
                    hintText: 'Enter your API key',
                    helperText: 'Get a free key at aistudio.google.com',
                    suffixIcon: settings.geminiApiKey?.isNotEmpty == true
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                  ),
                  obscureText: true,
                  controller: TextEditingController(text: settings.geminiApiKey ?? ''),
                  onChanged: (value) => settings.setGeminiApiKey(value),
                ),
              ),
              const SizedBox(height: 16),
              
              // Version info
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Sophis v1.0.0',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}

class _ReminderTimeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? time;
  final TimeOfDay defaultTime;
  final ValueChanged<String?> onChanged;

  const _ReminderTimeTile({
    required this.icon,
    required this.title,
    required this.time,
    required this.defaultTime,
    required this.onChanged,
  });

  TimeOfDay _parseTime(String? timeStr) {
    if (timeStr == null) return defaultTime;
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentTime = _parseTime(time);
    final isEnabled = time != null;

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: isEnabled 
          ? Text(currentTime.format(context))
          : const Text('Not set'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEnabled)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => onChanged(null),
              tooltip: 'Clear',
            ),
          IconButton(
            icon: Icon(isEnabled ? Icons.edit : Icons.add),
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: currentTime,
              );
              if (picked != null) {
                onChanged(_formatTime(picked));
              }
            },
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
