import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/generated/app_localizations.dart';

import 'models/shareable_meal.dart';
import 'services/storage_service.dart';
import 'services/settings_provider.dart';
import 'services/nutrition_provider.dart';
import 'services/notification_service.dart';
import 'services/meal_sharing_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/import_meal_screen.dart';

/// Global navigator key for deep link navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = await StorageService.create();

  // Initialize notification service (without requesting permission yet)
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => NutritionProvider(storageService),
        ),
      ],
      child: const SophisApp(),
    ),
  );
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
