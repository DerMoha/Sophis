import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../services/settings_provider.dart';
import '../services/nutrition_provider.dart';
import 'home_screen_modern.dart';
import 'home_screen_legacy.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsProvider, NutritionProvider>(
      builder: (context, settings, nutrition, _) {
        if (nutrition.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (settings.homeLayout == HomeLayoutMode.legacy) {
          return const HomeScreenLegacy();
        }
        return const HomeScreenModern();
      },
    );
  }
}
