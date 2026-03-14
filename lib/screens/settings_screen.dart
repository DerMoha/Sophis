import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/app_settings.dart';
import '../services/data_export_service.dart';
import '../services/nutrition_provider.dart';
import '../services/settings_provider.dart';
import '../services/log_service.dart';
import '../services/supplements_provider.dart';
import 'log_viewer_screen.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/organic_components.dart';
import '../widgets/settings/settings_tiles.dart';
import '../widgets/settings/reminder_time_tile.dart';
import '../widgets/settings/water_sizes_dialog.dart';
import '../widgets/settings/api_key_guide_dialog.dart';
import 'dashboard_settings_screen.dart';
import 'goals_setup_screen.dart';
import 'meal_macros_settings_screen.dart';
import 'meal_types_screen.dart';
import 'supplements_screen.dart';

enum _SettingsSection {
  appearance,
  nutrition,
  language,
  units,
  dashboard,
  reminders,
  fitness,
  ai,
  data,
  developer,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  final TextEditingController _apiKeyController = TextEditingController();
  final FocusNode _apiKeyFocusNode = FocusNode();
  final Map<_SettingsSection, bool> _expandedSections = {
    for (final section in _SettingsSection.values) section: false,
  };

  bool _isSectionExpanded(_SettingsSection section) =>
      _expandedSections[section] ?? false;

  void _toggleSection(_SettingsSection section) {
    setState(() {
      _expandedSections[section] = !_isSectionExpanded(section);
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiKeyFocusNode.dispose();
    super.dispose();
  }

  void _syncApiKeyController(String apiKey) {
    if (_apiKeyFocusNode.hasFocus || _apiKeyController.text == apiKey) {
      return;
    }

    _apiKeyController.value = TextEditingValue(
      text: apiKey,
      selection: TextSelection.collapsed(offset: apiKey.length),
    );
  }

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
            centerTitle: false,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                l10n.settings,
                style: theme.textTheme.headlineMedium,
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
                        section: _SettingsSection.appearance,
                        title: l10n.appearance,
                        icon: Icons.palette_outlined,
                        children: [
                          SettingRow(
                            title: l10n.theme,
                            child: SegmentedControl<ThemeMode>(
                              value: settings.themeMode,
                              options: const [
                                (ThemeMode.system, Icons.brightness_auto),
                                (ThemeMode.light, Icons.light_mode_outlined),
                                (ThemeMode.dark, Icons.dark_mode_outlined),
                              ],
                              onChanged: settings.setThemeMode,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SettingRow(
                            title: l10n.quickActionsSize,
                            child: SegmentedControl<QuickActionSize>(
                              value: settings.quickActionSize,
                              options: const [
                                (
                                  QuickActionSize.small,
                                  Icons.view_column_rounded
                                ), // Chips
                                (
                                  QuickActionSize.large,
                                  Icons.grid_view_rounded
                                ), // Cards
                              ],
                              onChanged: settings.setQuickActionSize,
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

                    // Nutrition Section
                    FadeInSlide(
                      index: 1,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.nutrition,
                        title: l10n.nutrition,
                        icon: Icons.restaurant_outlined,
                        children: [
                          // Calorie Goals
                          NavigationTile(
                            title: l10n.calorieGoals,
                            subtitle: l10n.calorieGoalsSubtitle,
                            icon: Icons.local_fire_department_outlined,
                            onTap: () {
                              Navigator.push(
                                context,
                                AppTheme.slideRoute(const GoalsSetupScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          // Water Sizes
                          NavigationTile(
                            title: l10n.waterSizes,
                            subtitle: l10n.waterSizesSubtitle,
                            icon: Icons.water_drop_outlined,
                            onTap: () =>
                                _showWaterSizesDialog(context, settings, l10n),
                          ),
                          const SizedBox(height: 12),
                          // Meal Macros
                          NavigationTile(
                            title: l10n.showMealMacros,
                            subtitle: l10n.showMealMacrosSubtitle,
                            icon: Icons.pie_chart_outline,
                            onTap: () => Navigator.push(
                              context,
                              AppTheme.slideRoute(
                                const MealMacrosSettingsScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Supplements Toggle
                          SwitchTile(
                            title: l10n.trackSupplements,
                            subtitle: l10n.trackSupplementsSubtitle,
                            icon: Icons.medication_outlined,
                            value: settings.showSupplements,
                            onChanged: (value) {
                              settings.setShowSupplements(value);
                              // Update notifications
                              context
                                  .read<SupplementsProvider>()
                                  .updateAllNotifications(enable: value);
                            },
                          ),
                          if (settings.showSupplements) ...[
                            const SizedBox(height: 12),
                            // Supplements Management
                            NavigationTile(
                              title: l10n.manageSupplements,
                              subtitle: l10n.manageSupplementsSubtitle,
                              icon: Icons.medication_liquid_rounded,
                              onTap: () => Navigator.push(
                                context,
                                AppTheme.slideRoute(const SupplementsScreen()),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Language Section
                    FadeInSlide(
                      index: 2,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.language,
                        title: l10n.language,
                        icon: Icons.language_outlined,
                        children: [
                          _buildLanguageSelector(context, settings, l10n),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Units Section
                    FadeInSlide(
                      index: 3,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.units,
                        title: l10n.units,
                        icon: Icons.straighten_outlined,
                        children: [
                          _buildUnitSelector(context, settings, l10n),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dashboard Customization Section
                    FadeInSlide(
                      index: 4,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.dashboard,
                        title: l10n.quickActions,
                        icon: Icons.dashboard_customize_outlined,
                        children: [
                          NavigationTile(
                            title: l10n.customizeDashboard,
                            subtitle: l10n.customizeDashboardSubtitle,
                            icon: Icons.grid_view_outlined,
                            onTap: () => Navigator.push(
                              context,
                              AppTheme.slideRoute(
                                const DashboardSettingsScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          NavigationTile(
                            title: l10n.customizeMealTypes,
                            subtitle: l10n.customizeMealTypesSubtitle,
                            icon: Icons.restaurant_menu_outlined,
                            onTap: () => Navigator.push(
                              context,
                              AppTheme.slideRoute(const MealTypesScreen()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Meal Reminders Section
                    FadeInSlide(
                      index: 3,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.reminders,
                        title: l10n.mealReminders,
                        icon: Icons.notifications_outlined,
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
                              defaultTime:
                                  const TimeOfDay(hour: 12, minute: 30),
                              onChanged: settings.setLunchReminder,
                            ),
                            const SizedBox(height: 8),
                            ReminderTimeTile(
                              icon: Icons.nights_stay_rounded,
                              title: l10n.dinner,
                              time: settings.dinnerReminderTime,
                              defaultTime:
                                  const TimeOfDay(hour: 18, minute: 30),
                              onChanged: settings.setDinnerReminder,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fitness Sync Section
                    FadeInSlide(
                      index: 4,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.fitness,
                        title: l10n.fitnessSync,
                        icon: Icons.fitness_center_outlined,
                        children: [
                          SwitchTile(
                            title: l10n.healthSync,
                            subtitle: l10n.healthSyncSubtitle,
                            icon: Icons.favorite_outline,
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
                      index: 5,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.ai,
                        title: l10n.aiSection,
                        icon: Icons.auto_awesome_outlined,
                        children: [
                          _buildApiKeyInput(context, settings, l10n),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Data Section
                    FadeInSlide(
                      index: 6,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.data,
                        title: l10n.dataSection,
                        icon: Icons.folder_outlined,
                        children: [
                          DataActionTile(
                            title: l10n.exportData,
                            subtitle: l10n.exportDataSubtitle,
                            icon: Icons.upload_outlined,
                            isLoading: _isExporting,
                            onTap: () => _handleExport(context, l10n),
                          ),
                          const SizedBox(height: 12),
                          DataActionTile(
                            title: l10n.importData,
                            subtitle: l10n.importDataSubtitle,
                            icon: Icons.download_outlined,
                            isLoading: _isImporting,
                            onTap: () => _handleImport(context, l10n),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.autoRestoreBackupNote,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Developer & Debugging
                    FadeInSlide(
                      index: 7,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.developer,
                        title: 'Developer & Debugging',
                        icon: Icons.bug_report_outlined,
                        children: [
                          SwitchTile(
                            title: 'Enable Debug Logging',
                            subtitle:
                                'Help diagnose issues by recording app activity',
                            icon: Icons.terminal_outlined,
                            value: settings.debugLoggingEnabled,
                            onChanged: settings.setDebugLoggingEnabled,
                          ),
                          const SizedBox(height: 12),
                          NavigationTile(
                            title: 'View Debug Logs',
                            subtitle: 'Export logs for troubleshooting',
                            icon: Icons.list_alt_outlined,
                            onTap: () {
                              Navigator.of(context).push(
                                AppTheme.slideRoute(const LogViewerScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          NavigationTile(
                            title: 'Clear Debug Logs',
                            subtitle: 'Delete all diagnostic logs',
                            icon: Icons.delete_outline,
                            onTap: () => _handleClearLogs(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Version info
                    FadeInSlide(
                      index: 8,
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
    required _SettingsSection section,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final isExpanded = _isSectionExpanded(section);

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleSection(section),
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: AppTheme.animFast,
                      child: Icon(
                        Icons.expand_more,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: AppTheme.animFast,
            curve: Curves.easeOutCubic,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _showWaterSizesDialog(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => WaterSizesDialog(
        settings: settings,
        l10n: l10n,
      ),
    );
  }

  Widget _buildAccentColorPicker(
    BuildContext context,
    SettingsProvider settings,
  ) {
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
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(Icons.check, color: _contrastColor(color), size: 20)
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
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : theme.colorScheme.outline.withValues(alpha: 0.1),
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

  Widget _buildUnitSelector(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final options = [
      (UnitSystem.metric, l10n.metric, l10n.metricSubtitle),
      (UnitSystem.imperial, l10n.imperial, l10n.imperialSubtitle),
    ];

    return Column(
      children: options.map((option) {
        final isSelected = settings.unitSystem == option.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => settings.setUnitSystem(option.$1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      option.$1 == UnitSystem.metric
                          ? Icons.balance_outlined
                          : Icons.scale_outlined,
                      size: 20,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.$2,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          Text(
                            option.$3,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildApiKeyInput(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final hasKey = settings.geminiApiKey?.isNotEmpty == true;
    _syncApiKeyController(settings.geminiApiKey ?? '');

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
          controller: _apiKeyController,
          focusNode: _apiKeyFocusNode,
          onChanged: settings.setGeminiApiKey,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.getApiKeyHelper,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showApiKeyGuide(context),
              icon: const Icon(Icons.help_outline, size: 16),
              label: Text(l10n.howToGetApiKey),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showApiKeyGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ApiKeyGuideDialog(),
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    setState(() => _isExporting = true);

    try {
      final nutritionProvider = context.read<NutritionProvider>();
      final messenger = ScaffoldMessenger.of(context);
      final success = await DataExportService.exportData(nutritionProvider);

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(success ? l10n.exportSuccess : l10n.exportFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleImport(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    // Capture context-dependent values before any async operations
    final nutritionProvider = context.read<NutritionProvider>();
    final messenger = ScaffoldMessenger.of(context);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importData),
        content: Text(l10n.importConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.importData),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isImporting = true);

    try {
      final result = await DataExportService.importData(nutritionProvider);

      if (!mounted) return;

      if (result.success) {
        // Reload the data in the provider
        await nutritionProvider.reloadAll();
      }

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(result.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _handleClearLogs(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearDebugLogs),
        content: Text(
          l10n.clearDebugLogsConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await LogService.instance.clearLogs();

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.debugLogsCleared),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.clearLogsFailed(e.toString())),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
