import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/food_item.dart';
import '../../../services/food_entry_factory.dart';
import '../../../services/openfoodfacts_service.dart';
import '../../../services/nutrition_provider.dart';
import '../../../services/service_result.dart';
import '../components/food_search_result_tile.dart';
import '../components/portion_picker_sheet.dart';
import '../theme/app_theme.dart';

class FoodSearchScreen extends StatefulWidget {
  final String meal;
  final String? initialQuery;

  const FoodSearchScreen({super.key, required this.meal, this.initialQuery});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _searchController = TextEditingController();
  final _service = OpenFoodFactsService();

  List<FoodItem> _results = [];
  bool _isSearchingApi = false;
  String? _error;
  String? _apiNotice;
  Timer? _debounce;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    // Listen to text changes for live search
    _searchController.addListener(_onSearchChanged);
    // Pre-fill search query if provided
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
    }
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
    } else {
      _searchRequestId++;
      setState(() {
        _results = [];
        _error = null;
        _apiNotice = null;
        _isSearchingApi = false;
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) return;

    final requestId = ++_searchRequestId;
    final provider = context.read<NutritionProvider>();
    final customMatches = provider.searchCustomFoods(query);

    // 1. Instant Local Search
    try {
      setState(() {
        _results = customMatches; // Show local results immediately
        _isSearchingApi = true; // Start showing API loading indicator
        _error = null;
        _apiNotice = null;
      });
    } catch (e) {
      debugPrint('Local search error: $e');
    }

    // 2. Background API Search
    final result = await _service.search(query);

    // Only update if query hasn't changed and widget is still mounted
    if (mounted &&
        requestId == _searchRequestId &&
        _searchController.text.trim() == query) {
      final latestCustomMatches = provider.searchCustomFoods(query);
      final l10n = AppLocalizations.of(context)!;

      setState(() {
        switch (result) {
          case Success<List<FoodItem>>():
            _results = _mergeResults(latestCustomMatches, result.value);
            _error = null;
            _apiNotice = null;
          case Failure<List<FoodItem>>():
            _results = latestCustomMatches;
            final message = _searchMessageFor(result.errorType, l10n);
            if (latestCustomMatches.isEmpty) {
              _error = message;
              _apiNotice = null;
            } else {
              _error = null;
              _apiNotice = message;
            }
        }
        _isSearchingApi = false;
      });
    }
  }

  List<FoodItem> _mergeResults(List<FoodItem> local, List<FoodItem> remote) {
    final merged = <FoodItem>[];
    final seenKeys = <String>{};

    for (final item in [...local, ...remote]) {
      final key = item.barcode ?? item.id;
      if (seenKeys.add(key)) {
        merged.add(item);
      }
    }

    return merged;
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

  Widget _buildApiNotice(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _apiNotice!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
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
    final entry = FoodEntryFactory.fromFoodItem(
      item: item,
      grams: grams,
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
    final favoriteFoods = provider.favoriteFoods;
    final customFoods = provider.customFoods;
    final recentFoods = provider.recentFoods;

    if (favoriteFoods.isEmpty && customFoods.isEmpty && recentFoods.isEmpty) {
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
        // Favorites section
        if (favoriteFoods.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: AppTheme.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.favorites,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          ...favoriteFoods.map(
            (item) => FoodSearchResultTile(
              item: item,
              onTap: () => _showPortionPicker(item),
              isFavorite: true,
              onFavoriteToggle: () => provider.toggleFavorite(item),
            ),
          ),
        ],
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
          ...customFoods.map(
            (item) => FoodSearchResultTile(
              item: item,
              onTap: () => _showPortionPicker(item),
              isCustomFood: true,
              onLongPress: () => _showDeleteCustomFoodDialog(item),
              isFavorite: provider.isFavorite(item.id),
              onFavoriteToggle: () => provider.toggleFavorite(item),
            ),
          ),
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
          ...recentFoods.map(
            (item) => FoodSearchResultTile(
              item: item,
              onTap: () => _showPortionPicker(item),
              isFavorite: provider.isFavorite(item.id),
              onFavoriteToggle: () => provider.toggleFavorite(item),
            ),
          ),
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
        child: Text(_error!, style: const TextStyle(color: AppTheme.error)),
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

    final provider = context.watch<NutritionProvider>();

    return Column(
      children: [
        if (_apiNotice != null) _buildApiNotice(context),
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            itemBuilder: (context, index) {
              final item = _results[index];
              return FoodSearchResultTile(
                item: item,
                onTap: () => _showPortionPicker(item),
                isFavorite: provider.isFavorite(item.id),
                onFavoriteToggle: () => provider.toggleFavorite(item),
              );
            },
          ),
        ),
      ],
    );
  }
}
