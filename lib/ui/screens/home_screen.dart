import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/nutrition_provider.dart';
import 'home/modern/home_modern_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NutritionProvider>(
      builder: (context, nutrition, _) {
        if (nutrition.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return const HomeScreenModern();
      },
    );
  }
}
