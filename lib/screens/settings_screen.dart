import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/app_settings.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/organic_components.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: Text(
                l10n.settings,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                return SliverList(
                  delegate: SliverChildListDelegate([
                    // Appearance Section
                    FadeInSlide(
                      index: 0,
                      child: _buildSectionCard(
                        context,
                        title: l10n.appearance,
                        icon: Icons.palette_outlined,
                        children: [
                          _buildSettingRow(
                            context,
                            title: l10n.theme,
                            child: _buildSegmentedControl<ThemeMode>(
                              context,
                              value: settings.themeMode,
                              options: [
                                (ThemeMode.system, Icons.brightness_auto),
                                (ThemeMode.light, Icons.light_mode_outlined),
                                (ThemeMode.dark, Icons.dark_mode_outlined),
                              ],
                              onChanged: settings.setThemeMode,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.accentColor,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 12),
                          _buildAccentColorPicker(context, settings),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Language Section
                    FadeInSlide(
                      index: 1,
                      child: _buildSectionCard(
                        context,
                        title: l10n.language,
                        icon: Icons.language_outlined,
                        children: [
                          _buildLanguageSelector(context, settings, l10n),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Meal Reminders Section
                    FadeInSlide(
                      index: 2,
                      child: _buildSectionCard(
                        context,
                        title: l10n.mealReminders,
                        icon: Icons.notifications_outlined,
                        children: [
                          _buildSwitchTile(
                            context,
                            title: l10n.enableReminders,
                            subtitle: l10n.enableRemindersSubtitle,
                            value: settings.remindersEnabled,
                            onChanged: settings.setRemindersEnabled,
                          ),
                          if (settings.remindersEnabled) ...[
                            const SizedBox(height: 16),
                            _ReminderTimeTile(
                              icon: Icons.wb_twilight_rounded,
                              title: l10n.breakfast,
                              time: settings.breakfastReminderTime,
                              defaultTime: const TimeOfDay(hour: 8, minute: 0),
                              onChanged: settings.setBreakfastReminder,
                            ),
                            const SizedBox(height: 8),
                            _ReminderTimeTile(
                              icon: Icons.wb_sunny_rounded,
                              title: l10n.lunch,
                              time: settings.lunchReminderTime,
                              defaultTime: const TimeOfDay(hour: 12, minute: 30),
                              onChanged: settings.setLunchReminder,
                            ),
                            const SizedBox(height: 8),
                            _ReminderTimeTile(
                              icon: Icons.nights_stay_rounded,
                              title: l10n.dinner,
                              time: settings.dinnerReminderTime,
                              defaultTime: const TimeOfDay(hour: 18, minute: 30),
                              onChanged: settings.setDinnerReminder,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fitness Sync Section
                    FadeInSlide(
                      index: 3,
                      child: _buildSectionCard(
                        context,
                        title: l10n.fitnessSync,
                        icon: Icons.fitness_center_outlined,
                        children: [
                          _buildSwitchTile(
                            context,
                            title: l10n.healthSync,
                            subtitle: l10n.healthSyncSubtitle,
                            value: settings.healthSyncEnabled,
                            onChanged: (value) async {
                              final success =
                                  await settings.setHealthSyncEnabled(value);
                              if (!success && value && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.healthPermissionError),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.burnedCaloriesDisclaimer,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // AI Section
                    FadeInSlide(
                      index: 4,
                      child: _buildSectionCard(
                        context,
                        title: l10n.aiSection,
                        icon: Icons.auto_awesome_outlined,
                        children: [
                          _buildApiKeyInput(context, settings, l10n),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Version info
                    FadeInSlide(
                      index: 5,
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              'Sophis',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'v1.0.0',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildSegmentedControl<T>(
    BuildContext context, {
    required T value,
    required List<(T, IconData)> options,
    required void Function(T) onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Row(
        children: options.map((option) {
          final isSelected = option.$1 == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option.$1),
              child: AnimatedContainer(
                duration: AppTheme.animFast,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(
                  option.$2,
                  size: 20,
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAccentColorPicker(
      BuildContext context, SettingsProvider settings) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: AccentColors.presets.map((color) {
        final isSelected = color.toARGB32() == settings.accentColorValue;
        return GestureDetector(
          onTap: () => settings.setAccentColor(color.toARGB32()),
          child: AnimatedContainer(
            duration: AppTheme.animFast,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                  : Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2)),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(Icons.check,
                    color: _contrastColor(color), size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Color _contrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Widget _buildLanguageSelector(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final options = [
      (null, l10n.systemDefault, Icons.phone_android_outlined),
      ('en', l10n.english, Icons.language_outlined),
      ('de', l10n.german, Icons.language_outlined),
    ];

    return Column(
      children: options.map((option) {
        final isSelected = settings.localeOverride == option.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => settings.setLocale(option.$1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary.withOpacity(0.3)
                        : theme.colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      option.$3,
                      size: 20,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      option.$2,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildApiKeyInput(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final hasKey = settings.geminiApiKey?.isNotEmpty == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: l10n.geminiApiKey,
            hintText: l10n.enterApiKey,
            suffixIcon: hasKey
                ? const Icon(Icons.check_circle, color: AppTheme.success)
                : null,
          ),
          obscureText: true,
          controller:
              TextEditingController(text: settings.geminiApiKey ?? ''),
          onChanged: settings.setGeminiApiKey,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.getApiKeyHelper,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
    final theme = Theme.of(context);
    final currentTime = _parseTime(time);
    final isEnabled = time != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEnabled
            ? theme.colorScheme.primary.withOpacity(0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isEnabled
                  ? theme.colorScheme.primary.withOpacity(0.1)
                  : theme.colorScheme.outline.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
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
