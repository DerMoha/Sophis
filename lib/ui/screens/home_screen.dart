import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/ui/components/common/ui_primitives.dart';
import 'package:sophis/ui/screens/home/modern/home_modern_screen.dart';
import 'package:sophis/ui/screens/app_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<NutritionProvider, bool>(
      (n) => n.isLoading,
    );
    if (isLoading) {
      return const Scaffold(
        body: LoadingState(),
      );
    }

    final hasGoals = context.select<NutritionProvider, bool>(
      (nutrition) => nutrition.goals != null,
    );

    return hasGoals ? const AppShell() : const HomeScreenModern();
  }
}
