import 'package:flutter/material.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/ui/components/quick_add_sheet.dart';
import 'package:sophis/ui/screens/food_diary_screen.dart';
import 'package:sophis/ui/screens/home/modern/home_modern_screen.dart';
import 'package:sophis/ui/screens/more_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  String get _suggestedMeal {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'breakfast';
    if (hour < 16) return 'lunch';
    if (hour < 22) return 'dinner';
    return 'snack';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showAddAction = _selectedIndex < 2;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeScreenModern(),
          FoodDiaryScreen(),
          MoreScreen(),
        ],
      ),
      floatingActionButton: showAddAction
          ? FloatingActionButton.extended(
              onPressed: () => showQuickAddSheet(
                context,
                mealType: _suggestedMeal,
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.addFood),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today),
            label: l10n.today,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: l10n.foodDiary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view),
            label: l10n.more,
          ),
        ],
      ),
    );
  }
}
