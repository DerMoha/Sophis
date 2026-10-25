import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/custom_meal_type.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/partner_day.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/partner_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/components/edit_food_entry_dialog.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/components/partner_card.dart';

/// The partner's diary for one of the shared days, with one-tap copying.
class PartnerDayScreen extends StatefulWidget {
  const PartnerDayScreen({super.key});

  @override
  State<PartnerDayScreen> createState() => _PartnerDayScreenState();
}

class _PartnerDayScreenState extends State<PartnerDayScreen> {
  static const _uuid = Uuid();
  late DateTime _date;
  late Stream<PartnerDay?> _day;

  /// Partner entry IDs copied while this screen is open.
  final Set<String> _added = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _select(DateTime(now.year, now.month, now.day));
  }

  void _select(DateTime date) {
    _date = date;
    _day = context.read<PartnerProvider>().watchPartnerDay(date);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final partner = context.watch<PartnerProvider>();
    final link = partner.link;
    if (link == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    return Scaffold(
      appBar: AppBar(title: Text(link.partnerName)),
      body: SafeArea(
        child: StreamBuilder<PartnerDay?>(
          stream: _day,
          builder: (context, snapshot) {
            final day = snapshot.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _buildDatePicker(context, l10n),
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: PartnerDaySummary(name: link.partnerName, day: day),
                ),
                if (day != null && day.entries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.partnerAddHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  ..._buildMeals(context, l10n, day),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context, AppLocalizations l10n) {
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toString();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: PartnerProvider.sharedDays,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, offset) {
          final date = DateTime(now.year, now.month, now.day - offset);
          return ChoiceChip(
            label: Text(
              switch (offset) {
                0 => l10n.today,
                1 => l10n.yesterday,
                _ => DateFormat.MMMEd(locale).format(date),
              },
            ),
            selected: date == _date,
            onSelected: (_) => setState(() => _select(date)),
          );
        },
      ),
    );
  }

  List<Widget> _buildMeals(
    BuildContext context,
    AppLocalizations l10n,
    PartnerDay day,
  ) {
    final mealTypes = context.read<SettingsProvider>().mealTypes;
    final groups = <String, List<FoodEntry>>{};
    for (final entry in day.entries) {
      groups.putIfAbsent(entry.meal, () => []).add(entry);
    }
    final known = mealTypes.where((type) => groups.containsKey(type.id));
    final unknown = groups.keys.where(
      (id) => !mealTypes.any((type) => type.id == id),
    );
    return [
      for (final type in known)
        _buildMeal(
          context,
          l10n,
          title: type.displayName(l10n),
          icon: type.icon,
          color: type.color,
          entries: groups[type.id]!,
        ),
      for (final id in unknown)
        _buildMeal(
          context,
          l10n,
          title: id,
          icon: Icons.restaurant_outlined,
          entries: groups[id]!,
        ),
    ];
  }

  Widget _buildMeal(
    BuildContext context,
    AppLocalizations l10n, {
    required String title,
    required IconData icon,
    Color? color,
    required List<FoodEntry> entries,
  }) {
    final theme = Theme.of(context);
    final pending = entries.where((e) => !_added.contains(e.id)).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: MealCard(
        title: title,
        icon: icon,
        color: color,
        calories: entries.fold(0.0, (sum, entry) => sum + entry.calories),
        showHeaderChevron: false,
        addMenu: IconButton(
          tooltip: l10n.partnerAddAll,
          icon: Icon(Icons.playlist_add_rounded, color: color),
          onPressed: pending.isEmpty ? null : () => _copy(pending),
        ),
        entries: [
          for (final entry in entries)
            Row(
              children: [
                Expanded(
                  child: FoodEntryTile(
                    name: entry.name,
                    calories: entry.calories,
                    protein: entry.protein,
                    carbs: entry.carbs,
                    fat: entry.fat,
                    fiber: entry.fiber,
                    onTap: () => _adjust(entry),
                  ),
                ),
                IconButton(
                  tooltip: l10n.addFood,
                  onPressed:
                      _added.contains(entry.id) ? null : () => _copy([entry]),
                  icon: Icon(
                    _added.contains(entry.id)
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    color: _added.contains(entry.id)
                        ? theme.colorScheme.primary
                        : color,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
        ],
      ),
    );
  }

  /// Copies keep the partner's meal when it exists here; otherwise the current
  /// time of day picks one.
  FoodEntry _copyOf(FoodEntry entry, List<CustomMealType> mealTypes) {
    final hour = DateTime.now().hour;
    final fallback = hour < 11
        ? 'breakfast'
        : hour < 16
            ? 'lunch'
            : hour < 22
                ? 'dinner'
                : 'snack';
    final meal = mealTypes.any((type) => type.id == entry.meal)
        ? entry.meal
        : mealTypes.any((type) => type.id == fallback)
            ? fallback
            : mealTypes.first.id;
    return entry.copyWith(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      meal: meal,
    );
  }

  Future<void> _copy(List<FoodEntry> source) async {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final nutrition = context.read<NutritionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final copies = [
      for (final entry in source) _copyOf(entry, settings.mealTypes),
    ];
    setState(() => _added.addAll(source.map((entry) => entry.id)));
    for (final copy in copies) {
      await nutrition.addFoodEntry(copy);
    }
    final meal = settings.getMealType(copies.first.meal)?.displayName(l10n) ??
        copies.first.meal;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            copies.length == 1
                ? l10n.partnerAdded(meal)
                : l10n.partnerAddedCount(copies.length),
          ),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              for (final copy in copies) {
                await nutrition.removeFoodEntry(copy.id);
              }
              if (mounted) {
                setState(
                  () => _added.removeAll(source.map((entry) => entry.id)),
                );
              }
            },
          ),
        ),
      );
  }

  Future<void> _adjust(FoodEntry entry) async {
    final settings = context.read<SettingsProvider>();
    final nutrition = context.read<NutritionProvider>();
    final edited = await showDialog<FoodEntry>(
      context: context,
      builder: (_) => EditFoodEntryDialog(
        entry: _copyOf(entry, settings.mealTypes),
      ),
    );
    if (edited == null || !mounted) return;
    await nutrition.addFoodEntry(edited);
    if (mounted) setState(() => _added.add(entry.id));
  }
}
