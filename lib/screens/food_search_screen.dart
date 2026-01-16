import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/food_item.dart';
import '../models/food_entry.dart';
import '../services/openfoodfacts_service.dart';
import '../services/nutrition_provider.dart';
import '../widgets/food_search_result_tile.dart';
import '../widgets/portion_picker_sheet.dart';

class FoodSearchScreen extends StatefulWidget {
  final String meal;

  const FoodSearchScreen({super.key, required this.meal});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _searchController = TextEditingController();
  final _service = OpenFoodFactsService();
  
  List<FoodItem> _results = [];
  bool _isSearchingApi = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Listen to text changes for live search
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Cancel previous timer
    _debounce?.cancel();
    
    final query = _searchController.text.trim();
    
    // Start searching after 2+ characters with 300ms debounce
    if (query.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 300), () {
        _search(query);
      });
    } else if (query.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _isSearchingApi = false;
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    
    // 1. Instant Local Search
    try {
      final customMatches = context
          .read<NutritionProvider>()
          .searchCustomFoods(query);
      
      setState(() {
        _results = customMatches; // Show local results immediately
        _isSearchingApi = true;   // Start showing API loading indicator
        _error = null;
      });
    } catch (e) {
      debugPrint('Local search error: $e');
    }

    // 2. Background API Search
    try {
      final apiResults = await _service.search(query);
      
      // Only update if query hasn't changed and widget is still mounted
      if (mounted && _searchController.text.trim() == query) {
        setState(() {
          // Re-fetch local to be safe (in case user added something while waiting
          // technically unlikely in this flow, but good practice to keep consistent)
          final customMatches = context.read<NutritionProvider>().searchCustomFoods(query);
          _results = [...customMatches, ...apiResults];
          _isSearchingApi = false;
        });
      }
    } catch (e) {
      if (mounted && _searchController.text.trim() == query) {
        setState(() {
          _error = e.toString();
          _isSearchingApi = false;
        });
      }
    }
  }

  void _showPortionPicker(FoodItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PortionPickerSheet(
        item: item,
        meal: widget.meal,
        onAdd: (grams) => _addFoodEntry(item, grams),
      ),
    );
  }

  void _addFoodEntry(FoodItem item, double grams) {
    final nutrients = item.calculateFor(grams);
    final displayName = item.brand != null && item.brand!.isNotEmpty
        ? '${item.brand} ${item.name}'
        : item.name;

    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '$displayName (${grams.toStringAsFixed(0)}g)',
      calories: nutrients['calories']!,
      protein: nutrients['protein']!,
      carbs: nutrients['carbs']!,
      fat: nutrients['fat']!,
      timestamp: DateTime.now(),
      meal: widget.meal,
    );

    final provider = context.read<NutritionProvider>();
    provider.addFoodEntry(entry);
    provider.addRecentFood(item); // Save to recent foods
    Navigator.pop(context); // Close search screen
  }

  void _showDeleteCustomFoodDialog(FoodItem item) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteCustomFood),
        content: Text(l10n.deleteCustomFoodConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<NutritionProvider>().removeCustomFood(item.id);
              Navigator.pop(ctx);
            },
            child: Text(
              l10n.delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyFoodsAndRecent(AppLocalizations l10n) {
    final provider = context.watch<NutritionProvider>();
    final customFoods = provider.customFoods;
    final recentFoods = provider.recentFoods;

    if (customFoods.isEmpty && recentFoods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 48,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.searchForFood,
              style: TextStyle(color: Theme.of(context).disabledColor),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      children: [
        // My Foods section
        if (customFoods.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              l10n.myFoods,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ...customFoods.map((item) => FoodSearchResultTile(
                item: item,
                onTap: () => _showPortionPicker(item),
                isCustomFood: true,
                onLongPress: () => _showDeleteCustomFoodDialog(item),
              )),
        ],
        // Recently Used section
        if (recentFoods.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              l10n.recentlyUsed,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ...recentFoods.map((item) => FoodSearchResultTile(
                item: item,
                onTap: () => _showPortionPicker(item),
              )),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.searchFood),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            // Search Input
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.searchFoodHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearchingApi 
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
                            },
                          )
                        : null,
              ),
            ),
          ),
          
          // Progress Indicator (Optional visibility boost)
          if (_isSearchingApi && _results.isNotEmpty)
             const LinearProgressIndicator(minHeight: 2),

          // Content Area
          Expanded(
            child: _buildContent(context, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    final hasQuery = _searchController.text.trim().isNotEmpty;

    if (!hasQuery) {
      return _buildMyFoodsAndRecent(l10n);
    }

    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }

    if (_results.isEmpty) {
      if (_isSearchingApi) {
         // Still searching API, no local results found yet
         return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Text(
          l10n.noEntries,
          style: TextStyle(color: Theme.of(context).disabledColor),
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemBuilder: (context, index) {
        final item = _results[index];
        return FoodSearchResultTile(
          item: item,
          onTap: () => _showPortionPicker(item),
        );
      },
    );
  }
}
