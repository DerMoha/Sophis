import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sophis/services/nutrition_provider.dart';
import 'package:sophis/ui/screens/home/modern/home_modern_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<NutritionProvider, bool>(
      (n) => n.isLoading,
    );
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return const HomeScreenModern();
  }
}
