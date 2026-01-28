import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/meal_plan.dart';
import '../models/recipe.dart';
import '../services/nutrition_provider.dart';
import '../services/openfoodfacts_service.dart';
import '../services/gemini_food_service.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';

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

  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;

  // Recipe scan state
  File? _scannedImage;
  RecipeExtraction? _extractedRecipe;
  bool _isScanning = false;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _selectedMealType = widget.initialMealType ?? 'breakfast';
    _initGemini();
  }

  Future<void> _initGemini() async {
    final settings = context.read<SettingsProvider>();
    final apiKey = settings.geminiApiKey;
    if (apiKey != null && apiKey.isNotEmpty) {
      _geminiService = GeminiFoodService();
      await _geminiService!.initialize(apiKey);
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  l10n.addMeal,
                  style: theme.textTheme.headlineSmall,
                ),
                const Spacer(),
                // Meal type selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMealType,
                      isDense: true,
                      items: [
                        DropdownMenuItem(value: 'breakfast', child: Text(l10n.breakfast)),
                        DropdownMenuItem(value: 'lunch', child: Text(l10n.lunch)),
                        DropdownMenuItem(value: 'dinner', child: Text(l10n.dinner)),
                        DropdownMenuItem(value: 'snack', child: Text(l10n.snacks)),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedMealType = value!;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: l10n.recipes),
              Tab(text: l10n.searchFood),
              Tab(text: '📷 ${l10n.scan}'),
              Tab(text: l10n.manualEntry),
            ],
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            isScrollable: true,
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
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
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
                  borderRadius: BorderRadius.circular(12),
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
                      '${nutrients['calories']!.toStringAsFixed(0)} kcal • ${recipe.servings} ${l10n.servings}',
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
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
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
                  child: Text(
                    _searchError!,
                    style: TextStyle(color: theme.colorScheme.error),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final food = _searchResults[index];
                        return _buildFoodResultCard(
                          context, theme, isDark, l10n, food,
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
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
      return _buildExtractedRecipeView(context, theme, isDark, l10n);
    }

    // Show scanning state
    if (_isScanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
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
              Icon(
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
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
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
            const SizedBox(height: 12),
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

  Widget _buildExtractedRecipeView(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final recipe = _extractedRecipe!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Recipe header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.15),
                theme.colorScheme.primary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recipe.recipeName ?? l10n.extractedRecipe,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      setState(() {
                        _extractedRecipe = null;
                      });
                    },
                    tooltip: l10n.scanAgain,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${recipe.servings} ${l10n.servings} • ${recipe.caloriesPerServing.toStringAsFixed(0)} kcal/${l10n.serving}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              // Macros row
              Row(
                children: [
                  _buildMacroChip(l10n.protein, recipe.proteinPerServing, AppTheme.protein),
                  const SizedBox(width: 8),
                  _buildMacroChip(l10n.carbs, recipe.carbsPerServing, AppTheme.carbs),
                  const SizedBox(width: 8),
                  _buildMacroChip(l10n.fat, recipe.fatPerServing, AppTheme.fat),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Ingredients list
        Text(
          '${l10n.ingredients} (${recipe.ingredients.length})',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          child: Column(
            children: recipe.ingredients.map((ing) {
              final emoji = ShoppingCategory.getIcon(ing.category);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ing.name,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        ing.displayAmount,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),

        // Add button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _addExtractedRecipeAsMeal(recipe),
            icon: const Icon(Icons.add),
            label: Text(l10n.addToMealPlan),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMacroChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            '${value.toStringAsFixed(0)}g',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
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
      final result = await _geminiService!.extractRecipeFromImage(_scannedImage!);
      setState(() {
        _extractedRecipe = result;
        _isScanning = false;
        if (result.isEmpty) {
          _scanError = 'No recipe found in image. Try a clearer photo.';
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

    // Convert extracted ingredients to planned meal ingredients
    final ingredients = recipe.ingredients.map((i) => PlannedMealIngredient(
          name: i.name,
          amount: i.amount,
          unit: i.unit,
          category: i.category,
        )).toList();

    final plannedMeal = PlannedMeal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: widget.date,
      meal: _selectedMealType,
      name: recipe.recipeName ?? 'Scanned Recipe',
      calories: recipe.caloriesPerServing,
      protein: recipe.proteinPerServing,
      carbs: recipe.carbsPerServing,
      fat: recipe.fatPerServing,
      servings: 1,
      ingredients: ingredients,
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
    dynamic food,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
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
    return _ManualEntryForm(
      date: widget.date,
      mealType: _selectedMealType,
      onSaved: () => Navigator.pop(context),
    );
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.length < 2) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final results = await _foodService.search(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchError = e.toString();
        _isSearching = false;
      });
    }
  }

  void _showServingsDialog(BuildContext context, AppLocalizations l10n, Recipe recipe) {
    int servings = 1;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final nutrients = recipe.nutrientsPerServing;
          final totalCal = nutrients['calories']! * servings;

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
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                const SizedBox(height: 12),
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
    final nutrients = recipe.nutrientsPerServing;
    final nutrition = context.read<NutritionProvider>();

    // Convert recipe ingredients to planned meal ingredients
    final ingredients = recipe.ingredients.map((i) => PlannedMealIngredient(
          name: i.name,
          amount: (i.amountGrams * servings) / recipe.servings,
          unit: 'g',
          category: _inferCategory(i.name),
        )).toList();

    final plannedMeal = PlannedMeal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: widget.date,
      meal: _selectedMealType,
      name: '${recipe.name} (${servings}x)',
      calories: nutrients['calories']! * servings,
      protein: nutrients['protein']! * servings,
      carbs: nutrients['carbs']! * servings,
      fat: nutrients['fat']! * servings,
      recipeId: recipe.id,
      servings: servings.toDouble(),
      ingredients: ingredients,
    );

    nutrition.addPlannedMeal(plannedMeal);
    Navigator.pop(context);
    HapticFeedback.mediumImpact();
  }

  void _addFoodAsPlannedMeal(dynamic food) {
    final nutrition = context.read<NutritionProvider>();

    final plannedMeal = PlannedMeal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: widget.date,
      meal: _selectedMealType,
      name: food.name,
      calories: food.caloriesPer100g,
      protein: food.proteinPer100g,
      carbs: food.carbsPer100g,
      fat: food.fatPer100g,
      ingredients: [
        PlannedMealIngredient(
          name: food.name,
          amount: 100,
          unit: 'g',
          category: _inferCategory(food.name),
        ),
      ],
    );

    nutrition.addPlannedMeal(plannedMeal);
    Navigator.pop(context);
    HapticFeedback.mediumImpact();
  }

  String _inferCategory(String name) {
    final lower = name.toLowerCase();
    if (_matchesAny(lower, ['chicken', 'beef', 'pork', 'fish', 'salmon', 'tuna', 'egg', 'meat', 'turkey'])) {
      return ShoppingCategory.protein;
    }
    if (_matchesAny(lower, ['milk', 'cheese', 'yogurt', 'butter', 'cream'])) {
      return ShoppingCategory.dairy;
    }
    if (_matchesAny(lower, ['apple', 'banana', 'orange', 'tomato', 'lettuce', 'carrot', 'onion', 'garlic', 'vegetable', 'fruit'])) {
      return ShoppingCategory.produce;
    }
    if (_matchesAny(lower, ['bread', 'rice', 'pasta', 'oat', 'cereal', 'flour'])) {
      return ShoppingCategory.grains;
    }
    if (_matchesAny(lower, ['frozen', 'ice cream'])) {
      return ShoppingCategory.frozen;
    }
    if (_matchesAny(lower, ['water', 'juice', 'soda', 'coffee', 'tea'])) {
      return ShoppingCategory.beverages;
    }
    return ShoppingCategory.pantry;
  }

  bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }
}

class _ManualEntryForm extends StatefulWidget {
  final DateTime date;
  final String mealType;
  final VoidCallback onSaved;

  const _ManualEntryForm({
    required this.date,
    required this.mealType,
    required this.onSaved,
  });

  @override
  State<_ManualEntryForm> createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends State<_ManualEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.foodName,
              prefixIcon: const Icon(Icons.restaurant_outlined),
            ),
            validator: (v) => v == null || v.isEmpty ? l10n.required : null,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _caloriesController,
            decoration: InputDecoration(
              labelText: l10n.calories,
              prefixIcon: const Icon(Icons.local_fire_department_outlined),
              suffixText: 'kcal',
            ),
            keyboardType: TextInputType.number,
            validator: (v) => v == null || v.isEmpty ? l10n.required : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _proteinController,
                  decoration: InputDecoration(
                    labelText: l10n.protein,
                    suffixText: 'g',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _carbsController,
                  decoration: InputDecoration(
                    labelText: l10n.carbs,
                    suffixText: 'g',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _fatController,
                  decoration: InputDecoration(
                    labelText: l10n.fat,
                    suffixText: 'g',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _submit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l10n.addMeal),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final nutrition = context.read<NutritionProvider>();

    final plannedMeal = PlannedMeal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: widget.date,
      meal: widget.mealType,
      name: _nameController.text,
      calories: double.tryParse(_caloriesController.text) ?? 0,
      protein: double.tryParse(_proteinController.text) ?? 0,
      carbs: double.tryParse(_carbsController.text) ?? 0,
      fat: double.tryParse(_fatController.text) ?? 0,
      ingredients: [
        PlannedMealIngredient(
          name: _nameController.text,
          amount: 1,
          unit: 'portion',
          category: ShoppingCategory.other,
        ),
      ],
    );

    nutrition.addPlannedMeal(plannedMeal);
    widget.onSaved();
    HapticFeedback.mediumImpact();
  }
}
