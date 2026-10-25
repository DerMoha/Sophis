import 'package:flutter/material.dart';
import 'package:sophis/ui/screens/partner/partner_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/components/partner_card.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/screens/dashboard_settings_screen.dart';
import 'package:sophis/ui/screens/home/shared/dashboard_slot.dart';
import 'package:sophis/ui/screens/home/shared/home_dashboard_vm.dart';

class HomeScreenModern extends StatefulWidget {
  const HomeScreenModern({super.key});

  @override
  State<HomeScreenModern> createState() => _HomeScreenModernState();
}

class _HomeScreenModernState extends State<HomeScreenModern> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBurnedCalories(context);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshBurnedCalories(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final nutrition = context.read<NutritionProvider>();
    await nutrition.refreshBurnedCalories(
      enabled: settings.healthSyncEnabled,
    );
    if (settings.healthWeightSyncEnabled) {
      await nutrition.syncWeightFromHealth();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final baseTheme = Theme.of(context);
    // Bold, tightly tracked sans headings keep the dashboard calm and legible.
    TextStyle? heading(TextStyle? style) => style?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        );
    final theme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.copyWith(
        headlineMedium: heading(baseTheme.textTheme.headlineMedium),
        headlineSmall: heading(baseTheme.textTheme.headlineSmall),
        displaySmall: heading(baseTheme.textTheme.displaySmall),
        titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        body: Consumer<NutritionProvider>(
          builder: (context, nutrition, _) =>
              _buildDashboard(context, l10n, theme),
        ),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final vm = readHomeDashboardVM(context);
    final slots = buildDashboardSlots(context, vm);
    final children = dashboardSlotsToWidgets(context, slots);
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 104;

    return RefreshIndicator(
      onRefresh: () => _refreshBurnedCalories(context),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.appTitle,
                            style: theme.textTheme.headlineMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.partnerSharingLabel,
                          onPressed: () => Navigator.push(
                            context,
                            AppTheme.slideRoute(const PartnerScreen()),
                          ),
                          icon: const Icon(Icons.favorite_outline),
                        ),
                        IconButton(
                          tooltip: l10n.customizeDashboard,
                          onPressed: () => Navigator.push(
                            context,
                            AppTheme.slideRoute(
                              const DashboardSettingsScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.tune_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.yMMMMEEEEd(
                        Localizations.localeOf(context).toString(),
                      ).format(DateTime.now()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const PartnerCard(),
                ...children,
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
