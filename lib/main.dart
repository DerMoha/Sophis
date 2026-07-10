import 'dart:async';

import 'package:home_widget/home_widget.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';

import 'package:sophis/models/shareable_meal.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/services/meal_sharing_service.dart';
import 'package:sophis/services/barcode_lookup_service.dart';
import 'package:sophis/services/food_intake_controller.dart';
import 'package:sophis/services/app_runtime.dart';
import 'package:sophis/providers/supplements_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/screens/home_screen.dart';
import 'package:sophis/ui/screens/import_meal_screen.dart';

/// Global navigator key for deep link navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HomeWidget.setAppGroupId('group.sophis.sophis');

  runApp(const SophisBootstrapApp());
}

class SophisBootstrapApp extends StatefulWidget {
  const SophisBootstrapApp({super.key});

  @override
  State<SophisBootstrapApp> createState() => _SophisBootstrapAppState();
}

class _SophisBootstrapAppState extends State<SophisBootstrapApp> {
  late Future<AppRuntime> _runtimeFuture;
  AppRuntime? _runtime;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _runtimeFuture = AppRuntime.initialize().then((runtime) {
      _runtime = runtime;
      return runtime;
    });
  }

  void _retry() {
    setState(_start);
  }

  @override
  void dispose() {
    final runtime = _runtime;
    if (runtime != null) unawaited(runtime.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppRuntime>(
      future: _runtimeFuture,
      builder: (context, snapshot) {
        final runtime = snapshot.data;
        if (runtime != null) {
          return MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(
                value: runtime.settings,
              ),
              ChangeNotifierProvider<NutritionProvider>.value(
                value: runtime.nutrition,
              ),
              ChangeNotifierProvider<SupplementsProvider>.value(
                value: runtime.supplements,
              ),
              Provider<FoodIntakeController>(
                create: (context) => FoodIntakeController(
                  context.read<NutritionProvider>(),
                ),
              ),
              Provider<BarcodeLookupService>.value(
                value: runtime.barcodeLookup,
              ),
            ],
            child: const SophisApp(),
          );
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: Scaffold(
            body: SafeArea(
              child: Center(
                child: snapshot.hasError
                    ? _StartupError(onRetry: _retry)
                    : const CircularProgressIndicator.adaptive(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StartupError extends StatelessWidget {
  final VoidCallback onRetry;

  const _StartupError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 16),
          Text(
            'Sophis could not load your data.',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your existing data has not been changed. Please try again.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class SophisApp extends StatefulWidget {
  const SophisApp({super.key});

  @override
  State<SophisApp> createState() => _SophisAppState();
}

class _SophisAppState extends State<SophisApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle link when app is started from a link
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      _handleDeepLink(initialLink.toString());
    }

    // Handle links when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri.toString());
    });
  }

  void _handleDeepLink(String url) {
    if (!MealSharingService.isShareLink(url)) return;

    final meal = ShareableMeal.fromDeepLink(url);
    if (meal == null) return;

    // Navigate to import screen
    // Use a slight delay to ensure the navigator is ready
    Future.delayed(const Duration(milliseconds: 100), () {
      navigatorKey.currentState?.push(
        AppTheme.slideRoute(ImportMealScreen(meal: meal)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Sophis',
          debugShowCheckedModeBanner: false,

          // Theme with dynamic accent color
          themeMode: settings.themeMode,
          theme: AppTheme.lightThemeWithAccent(settings.accentColor),
          darkTheme: AppTheme.darkThemeWithAccent(settings.accentColor),

          // Localization
          locale: settings.locale,
          supportedLocales: const [
            Locale('en'),
            Locale('de'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          home: const HomeScreen(),
        );
      },
    );
  }
}
