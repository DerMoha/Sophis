import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/services/gemini/models/models.dart';
import 'package:sophis/services/gemini_food_service.dart';
import 'package:sophis/services/nutrition_provider.dart';
import 'package:sophis/services/openfoodfacts_service.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/planned_meal_factory.dart';
import 'package:sophis/services/settings_provider.dart';
import 'package:sophis/ui/components/add_planned_meal_extracted_recipe_view.dart';
import 'package:sophis/ui/components/add_planned_meal_manual_entry_form.dart';
import 'package:sophis/ui/components/modal_sheet.dart';
import 'package:sophis/ui/components/organic/primitives.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class AddPlannedMealSheet extends StatefulWidget {
  final DateTime date;
  final String? initialMealType;

  const AddPlannedMealSheet({
    super.key,
    required this.date,
    this.initialMealType,
  });

  @override
  State<AddPlannedMealSheet> createState() => _AddPlannedMealSheetState();
}

class _AddPlannedMealSheetState extends State<AddPlannedMealSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedMealType = 'breakfast';
  final TextEditingController _searchController = TextEditingController();
  final OpenFoodFactsService _foodService = OpenFoodFactsService();
  final ImagePicker _imagePicker = ImagePicker();
  GeminiFoodService? _geminiService;

  List<FoodItem> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  int _searchRequestId = 0;

  // Recipe scan state
  File? _scannedImage;
  RecipeExtraction? _extractedRecipe;
  bool _isScanning = false;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final mealTypes = context.read<SettingsProvider>().mealTypes;
    final initialMealType = widget.initialMealType;
    _selectedMealType =
        mealTypes.any((mealType) => mealType.id == initialMealType)
            ? initialMealType!
            : mealTypes.first.id;
    _initGemini();
  }

  Future<void> _initGemini() async {
    final settings = context.read<SettingsProvider>();
    final apiKey = settings.geminiApiKey;
    if (apiKey != null && apiKey.isNotEmpty) {
      _geminiService = GeminiFoodService();
      await _geminiService!.initialize(apiKey);
      if (!mounted) return;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final mealTypes = context.watch<SettingsProvider>().mealTypes;

    return ModalSheetSurface(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            ModalSheetHandle(color: theme.dividerColor),
            ModalSheetHeader(
              title: l10n.addMeal,
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedMealType,
                    isDense: true,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    items: mealTypes
                        .map(
                          (mealType) => DropdownMenuItem(
                            value: mealType.id,
                            child: Text(mealType.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMealType = value!;
                      });
                    },
                  ),
                ),
              ),
            ),

            // Tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                ),
                child: TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: l10n.recipes),
                    Tab(text: l10n.searchFood),
                    Tab(text: '📷 ${l10n.scan}'),
                    Tab(text: l10n.manualEntry),
                  ],
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  labelStyle: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  isScrollable: true,
                ),
              ),
            ),

            // Tab content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRecipesTab(context, theme, isDark, l10n),
                    _buildSearchTab(context, theme, isDark, l10n),
                    _buildScanRecipeTab(context, theme, isDark, l10n),
                    _buildManualTab(context, theme, isDark, l10n),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipesTab(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final recipes = context.watch<NutritionProvider>().recipes;

    if (recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 48,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noRecipes,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.noRecipesSubtitle,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return _buildRecipeCard(context, theme, isDark, l10n, recipe);
      },
    );
  }

  Widget _buildRecipeCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AppLocalizations l10n,
    Recipe recipe,
  ) {
    final nutrients = recipe.nutrientsPerServing;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: isDark
              ? CachedColors.surfaceTintDark06
              : CachedColors.surfaceTintLight04,
        ),
      ),
      child: InkWell(
        onTap: () => _showServingsDialog(context, l10n, recipe),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${nutrients.calories.toStringAsFixed(0)} kcal • ${recipe.servings} ${l10n.servings}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.add_circle_outline,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTab(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        // Search field
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchFoodHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchRequestId++;
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                              _searchError = null;
                              _isSearching = false;
                            });
                          },
                        )
                      : null,
            ),
            onSubmitted: (_) => _performSearch(),
            textInputAction: TextInputAction.search,
          ),
        ),

        // Results
        Expanded(
          child: _searchError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 40,
                          color: theme.colorScheme.error.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchError!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : _isSearching
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            l10n.searching,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _searchResults.isEmpty && _searchController.text.isNotEmpty
                      ? Center(
                          child: Text(
                            l10n.noResultsFound,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : _searchResults.isEmpty
                          ? Center(
                              child: Text(
                                l10n.searchForFood,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final food = _searchResults[index];
                                return _buildFoodResultCard(
                                  context,
                                  theme,
                                  isDark,
                                  l10n,
                                  food,
                                );
                              },
                            ),
        ),
      ],
    );
  }

  Widget _buildScanRecipeTab(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AppLocalizations l10n,
  ) {
    // Check if API key is set
    if (_geminiService == null || !_geminiService!.hasApiKey) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.key_outlined,
                size: 48,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.errorApiKey,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.getApiKeyHelper,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Show extracted recipe results
    if (_extractedRecipe != null && _extractedRecipe!.isNotEmpty) {
      return AddPlannedMealExtractedRecipeView(
        recipe: _extractedRecipe!,
        isDark: isDark,
        onScanAgain: () {
          setState(() {
            _extractedRecipe = null;
          });
        },
        onAddToMeal: () => _addExtractedRecipeAsMeal(_extractedRecipe!),
      );
    }

    // Show scanning state
    if (_isScanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppTheme.spaceLG2),
            Text(
              l10n.scanningRecipe,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    // Show error
    if (_scanError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _scanError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _scanError = null),
                child: Text(l10n.tryAgain),
              ),
            ],
          ),
        ),
      );
    }

    // Show image picker options
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.scanRecipeDescription,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Image preview or placeholder
          if (_scannedImage != null)
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                child: Image.file(
                  _scannedImage!,
                  fit: BoxFit.contain,
                ),
              ),
            )
          else
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.selectRecipeImage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickRecipeImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l10n.gallery),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickRecipeImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(l10n.camera),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          if (_scannedImage != null) ...[
            const SizedBox(height: AppTheme.spaceSM2),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _scanRecipe,
                icon: const Icon(Icons.auto_awesome),
                label: Text(l10n.extractIngredients),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickRecipeImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        if (source == ImageSource.camera) {
          try {
            await Gal.putImage(image.path);
          } catch (e) {
            debugPrint('Failed to save to gallery: $e');
          }
        }

        if (!mounted) return;
        setState(() {
          _scannedImage = File(image.path);
          _scanError = null;
        });
      }
    } catch (e) {
      setState(() {
        _scanError = e.toString();
      });
    }
  }

  Future<void> _scanRecipe() async {
    if (_scannedImage == null || _geminiService == null) return;

    setState(() {
      _isScanning = true;
      _scanError = null;
    });

    try {
      final result =
          await _geminiService!.extractRecipeFromImage(_scannedImage!);
      if (!mounted) return;
      setState(() {
        _extractedRecipe = result;
        _isScanning = false;
        if (result.isEmpty) {
          _scanError = AppLocalizations.of(context)!.noRecipeFoundInImage;
          _extractedRecipe = null;
        }
      });
    } catch (e) {
      setState(() {
        _scanError = e.toString();
        _isScanning = false;
      });
    }
  }

  void _addExtractedRecipeAsMeal(RecipeExtraction recipe) {
    final nutrition = context.read<NutritionProvider>();
    final l10n = AppLocalizations.of(context)!;

    final plannedMeal = PlannedMealFactory.fromExtractedRecipe(
      recipe: recipe,
      date: widget.date,
      meal: _selectedMealType,
      fallbackName: l10n.scannedRecipeName,
    );

    nutrition.addPlannedMeal(plannedMeal);
    Navigator.pop(context);
    HapticFeedback.mediumImpact();
  }

  Widget _buildFoodResultCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AppLocalizations l10n,
    FoodItem food,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark
              ? CachedColors.surfaceTintDark06
              : CachedColors.surfaceTintLight04,
        ),
      ),
      child: InkWell(
        onTap: () => _addFoodAsPlannedMeal(food),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${food.caloriesPer100g.toStringAsFixed(0)} kcal/100g',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.add_circle_outline,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualTab(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return AddPlannedMealManualEntryForm(
      date: widget.date,
      mealType: _selectedMealType,
      onSaved: () => Navigator.pop(context),
    );
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      _searchRequestId++;
      setState(() {
        _searchResults = [];
        _searchError = null;
        _isSearching = false;
      });
      return;
    }

    final requestId = ++_searchRequestId;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchResults = [];
    });

    final result = await _foodService.search(query);
    if (!mounted ||
        requestId != _searchRequestId ||
        _searchController.text.trim() != query) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isSearching = false;
      switch (result) {
        case Success<List<FoodItem>>():
          _searchResults = result.value;
          _searchError = null;
        case Failure<List<FoodItem>>():
          _searchResults = [];
          _searchError = _searchMessageFor(result.errorType, l10n);
      }
    });
  }

  String _searchMessageFor(
    ServiceErrorType errorType,
    AppLocalizations l10n,
  ) {
    return switch (errorType) {
      ServiceErrorType.network => l10n.networkError,
      _ => l10n.searchFailed,
    };
  }

  void _showServingsDialog(
    BuildContext context,
    AppLocalizations l10n,
    Recipe recipe,
  ) {
    int servings = 1;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final nutrients = recipe.nutrientsPerServing;
          final totalCal = nutrients.calories * servings;

          return AlertDialog(
            title: Text(recipe.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.howManyServings),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: servings > 1
                          ? () => setDialogState(() => servings--)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Text(
                        '$servings',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setDialogState(() => servings++),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSM2),
                Text(
                  '${totalCal.toStringAsFixed(0)} kcal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  _addRecipeAsPlannedMeal(recipe, servings);
                  Navigator.pop(context);
                },
                child: Text(l10n.add),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addRecipeAsPlannedMeal(Recipe recipe, int servings) {
    final nutrition = context.read<NutritionProvider>();

    final plannedMeal = PlannedMealFactory.fromRecipe(
      recipe: recipe,
      servings: servings,
      date: widget.date,
      meal: _selectedMealType,
    );

    nutrition.addPlannedMeal(plannedMeal);
    Navigator.pop(context);
    HapticFeedback.mediumImpact();
  }

  void _addFoodAsPlannedMeal(FoodItem food) {
    final nutrition = context.read<NutritionProvider>();

    final plannedMeal = PlannedMealFactory.fromFoodItem(
      food: food,
      date: widget.date,
      meal: _selectedMealType,
    );

    nutrition.addPlannedMeal(plannedMeal);
    Navigator.pop(context);
    HapticFeedback.mediumImpact();
  }
}
