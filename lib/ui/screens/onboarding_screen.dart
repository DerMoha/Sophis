import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/screens/goals_setup_screen.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _lastPage = 3;

  final PageController _pageController = PageController();
  int _page = 0;
  bool _isFinishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int page) async {
    await _pageController.animateToPage(
      page,
      duration: AppTheme.animNormal,
      curve: AppTheme.fluidCurve,
    );
  }

  Future<void> _openGoals() async {
    final saved = await Navigator.of(context).push<bool>(
      AppTheme.slideRoute(const GoalsSetupScreen()),
    );
    if (saved == true && mounted) await _finish();
  }

  Future<void> _finish() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    try {
      await context.read<SettingsProvider>().completeOnboarding();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFinishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.onboardingFinishError,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final pages = [
      _OnboardingPage(
        icon: Icons.spa_outlined,
        eyebrow: l10n.onboardingWelcomeEyebrow,
        title: l10n.onboardingWelcomeTitle,
        body: l10n.onboardingWelcomeBody,
        points: [
          (Icons.person_off_outlined, l10n.onboardingWelcomePointOne),
          (Icons.tune_outlined, l10n.onboardingWelcomePointTwo),
        ],
      ),
      _OnboardingPage(
        icon: Icons.ramen_dining_outlined,
        eyebrow: l10n.onboardingTrackEyebrow,
        title: l10n.onboardingTrackTitle,
        body: l10n.onboardingTrackBody,
        points: [
          (Icons.bolt_outlined, l10n.onboardingTrackPointOne),
          (Icons.qr_code_scanner_outlined, l10n.onboardingTrackPointTwo),
        ],
      ),
      _OnboardingPage(
        icon: Icons.insights_outlined,
        eyebrow: l10n.onboardingProgressEyebrow,
        title: l10n.onboardingProgressTitle,
        body: l10n.onboardingProgressBody,
        points: [
          (Icons.dashboard_customize_outlined, l10n.onboardingProgressPointOne),
          (Icons.phonelink_lock_outlined, l10n.onboardingProgressPointTwo),
        ],
      ),
      _OnboardingPage(
        icon: Icons.flag_outlined,
        eyebrow: l10n.onboardingGoalsEyebrow,
        title: l10n.onboardingGoalsTitle,
        body: l10n.onboardingGoalsBody,
        points: const [],
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 0,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Sophis',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_page < _lastPage)
                    TextButton(
                      key: const Key('onboarding-skip-explanations'),
                      onPressed: () => _goToPage(_lastPage),
                      child: Text(
                        l10n.onboardingSkipExplanations,
                        textAlign: TextAlign.end,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  value: (_page + 1) / (_lastPage + 1),
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _page = page),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: _page == _lastPage
                  ? _buildGoalActions(l10n)
                  : _buildNavigation(l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation(AppLocalizations l10n) {
    return Row(
      children: [
        if (_page > 0)
          TextButton.icon(
            onPressed: () => _goToPage(_page - 1),
            icon: const Icon(Icons.arrow_back),
            label: Text(l10n.onboardingBack),
          )
        else
          const Spacer(),
        const Spacer(),
        FilledButton.icon(
          key: const Key('onboarding-next'),
          onPressed: () => _goToPage(_page + 1),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward),
          label: Text(l10n.onboardingNext),
        ),
      ],
    );
  }

  Widget _buildGoalActions(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('onboarding-set-goals'),
            onPressed: _isFinishing ? null : _openGoals,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(l10n.onboardingSetGoals),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            key: const Key('onboarding-skip-goals'),
            onPressed: _isFinishing ? null : _finish,
            child: Column(
              children: [
                Text(l10n.onboardingTryFirst),
                Text(
                  l10n.onboardingTryFirstHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                l10n.onboardingGoalPrivacy,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final List<(IconData, String)> points;

  const _OnboardingPage({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.tertiary,
                ],
              ),
              borderRadius: AppTheme.blobRadius,
              boxShadow: AppTheme.shadowLG(isDark),
            ),
            child: Icon(icon, color: Colors.white, size: 42),
          ),
          const SizedBox(height: 32),
          Text(
            eyebrow,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 28),
            for (final point in points) ...[
              _OnboardingPoint(icon: point.$1, label: point.$2),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _OnboardingPoint extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OnboardingPoint({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
