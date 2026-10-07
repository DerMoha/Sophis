import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/ui/screens/social/social_publish_screen.dart';
import 'package:sophis/ui/theme/app_theme.dart';

/// Choosing private content does not upload it. The next screen is the explicit
/// audience/content preview and publication boundary.
class SocialSourceScreen extends StatefulWidget {
  const SocialSourceScreen({super.key});
  @override
  State<SocialSourceScreen> createState() => _SocialSourceScreenState();
}

class _SocialSourceScreenState extends State<SocialSourceScreen> {
  DateTime _date = DateTime.now();
  int? _sessionVersion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sessionVersion ??= context.read<SocialProvider>().sessionVersion;
  }

  Future<void> _selectDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value != null && mounted) setState(() => _date = value);
  }

  void _preview(SocialSnapshot Function() snapshot, {required bool isRecipe}) {
    try {
      Navigator.push(
        context,
        AppTheme.slideRoute(
          SocialPublishScreen(snapshot: snapshot(), isRecipe: isRecipe),
        ),
      );
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This meal needs valid items and portions before it can be shared.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    if (social.sessionVersion != _sessionVersion || social.profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Choose what to share')),
        body: const Center(child: Text('Sign in to People to share.')),
      );
    }
    final nutrition = context.watch<NutritionProvider>();
    final settings = context.watch<SettingsProvider>();
    final groups = <String, List<FoodEntry>>{};
    for (final entry in nutrition.getEntriesForDate(_date)) {
      groups.putIfAbsent(entry.meal, () => []).add(entry);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Choose what to share')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Choose a meal or recipe for a separate social snapshot. You will review its audience, title, caption and nutrition before publishing.',
          ),
          const SizedBox(height: 16),
          Text('Logged meals', style: Theme.of(context).textTheme.titleLarge),
          TextButton.icon(
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
            ),
          ),
          if (groups.isEmpty) const Text('No meals logged on this date.'),
          for (final group in groups.entries)
            ListTile(
              title:
                  Text(settings.getMealType(group.key)?.name ?? 'Logged meal'),
              subtitle: Text(group.value.map((entry) => entry.name).join(', ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _preview(
                () => SocialSnapshot.fromEntries(
                  group.value,
                  title: settings.getMealType(group.key)?.name ?? 'Shared meal',
                ),
                isRecipe: false,
              ),
            ),
          const SizedBox(height: 24),
          Text('Recipes', style: Theme.of(context).textTheme.titleLarge),
          if (nutrition.recipes.isEmpty) const Text('No saved recipes yet.'),
          for (final recipe in nutrition.recipes)
            ListTile(
              title: Text(recipe.name),
              subtitle: Text('${recipe.servings} servings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _preview(
                () => SocialSnapshot.fromRecipe(recipe),
                isRecipe: true,
              ),
            ),
        ],
      ),
    );
  }
}
