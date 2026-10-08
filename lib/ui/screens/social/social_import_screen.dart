import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/shareable_meal.dart';
import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_repository.dart';
import 'package:sophis/ui/components/organic_components.dart';

/// Review creates a recipient-owned copy; no source IDs or revisions enter it.
class SocialImportScreen extends StatefulWidget {
  final SocialPost post;
  final bool saveRecipe;
  const SocialImportScreen({
    super.key,
    required this.post,
    this.saveRecipe = false,
  });

  @override
  State<SocialImportScreen> createState() => _SocialImportScreenState();
}

class _SocialImportScreenState extends State<SocialImportScreen> {
  final _form = GlobalKey<FormState>();
  final _operationId = const Uuid().v4();
  final _servings = TextEditingController(text: '1');
  late final List<_ItemReview> _items;
  int? _sessionVersion;
  String? _meal;
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _items =
        widget.post.snapshot.items.map((item) => _ItemReview(item)).toList();
    if (widget.saveRecipe) {
      _servings.text = widget.post.snapshot.servings.toString();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sessionVersion ??= context.read<SocialProvider>().sessionVersion;
    final meals = context.read<SettingsProvider>().mealTypes;
    _meal ??= meals.isEmpty ? null : meals.first.id;
  }

  @override
  void dispose() {
    _servings.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  String? _number(
    String? text, {
    bool positive = false,
    double maximum = 10000,
  }) {
    final value = double.tryParse(text?.trim().replaceAll(',', '.') ?? '');
    if (value == null ||
        !value.isFinite ||
        value > maximum ||
        (positive ? value <= 0 : value < 0)) {
      return positive
          ? 'Enter an amount greater than zero'
          : 'Enter a non-negative amount';
    }
    return null;
  }

  double _value(TextEditingController controller) =>
      double.parse(controller.text.trim().replaceAll(',', '.'));

  SocialSnapshot _resolvedSnapshot() => SocialSnapshot(
        title: widget.post.snapshot.title,
        servings: widget.post.snapshot.servings,
        items: [
          for (final review in _items.where((item) => item.selected))
            SharedFoodItem(
              name: review.item.name,
              calories: widget.post.snapshot.nutritionAvailable
                  ? review.item.calories
                  : _value(review.nutrients[0]),
              protein: widget.post.snapshot.nutritionAvailable
                  ? review.item.protein
                  : _value(review.nutrients[1]),
              carbs: widget.post.snapshot.nutritionAvailable
                  ? review.item.carbs
                  : _value(review.nutrients[2]),
              fat: widget.post.snapshot.nutritionAvailable
                  ? review.item.fat
                  : _value(review.nutrients[3]),
              fiber: widget.post.snapshot.nutritionAvailable
                  ? review.item.fiber
                  : _value(review.nutrients[4]),
              portionGrams: review.item.portionGrams,
              portionUnit: review.item.portionUnit,
              portionQuantity: review.item.portionQuantity,
              portionLabel: review.item.portionLabel,
            ),
        ],
      );

  Future<void> _save() async {
    if (_busy) return;
    if (!_items.any((item) => item.selected)) {
      setState(() => _message = 'Choose at least one item to log.');
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (context.read<SocialProvider>().sessionVersion != _sessionVersion) {
      return;
    }
    if (!widget.saveRecipe && _meal == null) return;
    final nutrition = context.read<NutritionProvider>();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final snapshot = _resolvedSnapshot();
      final selected = _value(_servings);
      final NutritionCommand command;
      if (widget.saveRecipe) {
        command = ImportSocialRecipe(
          operationId: _operationId,
          recipe: Recipe(
            id: _operationId,
            name: snapshot.title,
            servings: selected.toInt(),
            notes: widget.post.caption,
            createdAt: DateTime.now(),
            ingredients: [
              for (var index = 0; index < snapshot.items.length; index++)
                RecipeIngredient(
                  id: '$index',
                  name: snapshot.items[index].name,
                  amountGrams: _items[index].needsMass
                      ? _value(_items[index].mass)
                      : snapshot.items[index].portionGrams!,
                  calories: snapshot.items[index].calories,
                  protein: snapshot.items[index].protein,
                  carbs: snapshot.items[index].carbs,
                  fat: snapshot.items[index].fat,
                  fiber: snapshot.items[index].fiber,
                ),
            ],
          ),
        );
      } else {
        command = ImportSocialMeal(
          operationId: _operationId,
          snapshot: snapshot,
          selectedServings: selected,
          timestamp: DateTime(
            _date.year,
            _date.month,
            _date.day,
            _date.hour,
            _date.minute,
          ),
          meal: _meal!,
        );
      }
      final result = await nutrition.store.commit(command);
      if (result is Failure) {
        if (mounted) {
          setState(() => _message = 'Could not save your copy. Try again.');
        }
        return;
      }
      await nutrition.reloadAll();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.saveRecipe
                ? 'Recipe saved as your own copy.'
                : 'Your portion was added to the diary.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not save your copy. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (chosen != null && mounted) setState(() => _date = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    final meals = context.watch<SettingsProvider>().mealTypes;
    if (social.sessionVersion != _sessionVersion) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shared meal')),
        body: const Center(
          child: Text('Your account changed. Open the meal again.'),
        ),
      );
    }
    final selectedMeal = meals.any((meal) => meal.id == _meal) ? _meal : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.saveRecipe ? 'Save recipe' : 'Add to diary'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.post.snapshot.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'This creates your own local copy. Later author edits or deletion will not change it.',
            ),
            const SizedBox(height: 16),
            if (!widget.post.snapshot.nutritionAvailable) ...[
              const GlassCard(
                child: Text(
                  'Nutrition was hidden. Enter nutrition for each item in the shared portion before saving. Unknown nutrition will not be logged as zero.',
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (!widget.saveRecipe)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Select all items or just the ones you ate.'),
              ),
            for (final review in _items) ...[
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.saveRecipe)
                      Material(
                        type: MaterialType.transparency,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(review.item.name),
                          value: review.selected,
                          onChanged: _busy
                              ? null
                              : (value) => setState(() {
                                    review.selected = value ?? false;
                                  }),
                        ),
                      )
                    else
                      Text(
                        review.item.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    if (review.item.portionGrams != null)
                      Text(
                        '${review.item.portionGrams} ${review.item.portionUnit?.symbol ?? ''} in the shared portion',
                      ),
                    if (review.selected &&
                        !widget.post.snapshot.nutritionAvailable)
                      for (var index = 0;
                          index < review.nutrients.length;
                          index++)
                        TextFormField(
                          controller: review.nutrients[index],
                          enabled: !_busy,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: [
                              'Calories (kcal)',
                              'Protein (g)',
                              'Carbs (g)',
                              'Fat (g)',
                              'Fiber (g)',
                            ][index],
                          ),
                          validator: (value) => _number(
                            value,
                            maximum: index == 0 ? 100000 : 10000,
                          ),
                        ),
                    if (widget.saveRecipe && review.needsMass)
                      TextFormField(
                        controller: review.mass,
                        enabled: !_busy,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText:
                              'Ingredient weight for the whole recipe (g)',
                          helperText:
                              'Enter its weight; milliliters are not assumed to be grams.',
                        ),
                        validator: (value) =>
                            _number(value, positive: true, maximum: 100000),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _servings,
              enabled: !_busy,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: widget.saveRecipe
                    ? 'Servings in your recipe'
                    : 'Your servings',
                helperText: widget.saveRecipe
                    ? 'Whole servings; ingredient amounts stay for the entire batch.'
                    : 'Shared portion: ${widget.post.snapshot.servings} servings',
              ),
              validator: (text) {
                final error = _number(text, positive: true, maximum: 1000);
                if (error != null) return error;
                final value = double.parse(text!.replaceAll(',', '.'));
                return widget.saveRecipe && value != value.roundToDouble()
                    ? 'Enter a whole number of recipe servings'
                    : null;
              },
            ),
            if (!widget.saveRecipe) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedMeal,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Meal category'),
                items: [
                  for (final meal in meals)
                    DropdownMenuItem(value: meal.id, child: Text(meal.name)),
                ],
                onChanged:
                    _busy ? null : (value) => setState(() => _meal = value),
                validator: (value) =>
                    value == null ? 'Choose a meal category' : null,
              ),
              TextButton.icon(
                onPressed: _busy ? null : _selectDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  'Date: ${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_message != null) Text(_message!),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(
                _busy
                    ? 'Saving…'
                    : widget.saveRecipe
                        ? 'Save my recipe copy'
                        : 'Add my portion',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemReview {
  final SharedFoodItem item;
  bool selected = true;
  final List<TextEditingController> nutrients =
      List.generate(5, (_) => TextEditingController());
  final TextEditingController mass = TextEditingController();
  _ItemReview(this.item);
  bool get needsMass =>
      item.portionGrams == null || item.portionUnit != NutritionUnit.gram;
  void dispose() {
    mass.dispose();
    for (final controller in nutrients) {
      controller.dispose();
    }
  }
}
