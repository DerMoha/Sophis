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
        points: [(Icons.lock_outline, l10n.onboardingGoalPrivacy)],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sophis'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: _page > 0
            ? IconButton(
                tooltip: l10n.onboardingBack,
                onPressed: () => _goToPage(_page - 1),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(child: Text('${_page + 1}/${_lastPage + 1}')),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('onboarding-next'),
            onPressed: () => _goToPage(_page + 1),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward),
            label: Text(l10n.onboardingNext),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('onboarding-skip-explanations'),
          onPressed: () => _goToPage(_lastPage),
          child: Text(
            l10n.onboardingSkipExplanations,
            textAlign: TextAlign.center,
          ),
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
            child: Text(l10n.onboardingTryFirst, textAlign: TextAlign.center),
          ),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
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
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 24),
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
