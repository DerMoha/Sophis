import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/food_item.dart';
import '../models/food_entry.dart';
import '../services/openfoodfacts_service.dart';
import '../services/nutrition_provider.dart';

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
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _service.search(query);
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showAddDialog(FoodItem item) {
    final amountController = TextEditingController(text: '100');
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Per 100g: ${item.caloriesPer100g.toStringAsFixed(0)} kcal',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (g)',
                suffixText: 'g',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 100;
              final nutrients = item.calculateFor(amount);
              
              final entry = FoodEntry(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: '${item.name} (${amount.toStringAsFixed(0)}g)',
                calories: nutrients['calories']!,
                protein: nutrients['protein']!,
                carbs: nutrients['carbs']!,
                fat: nutrients['fat']!,
                timestamp: DateTime.now(),
                meal: widget.meal,
              );
              
              context.read<NutritionProvider>().addFoodEntry(entry);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(l10n.add),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Food'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search OpenFoodFacts...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            )
          else if (_results.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  l10n.noEntries,
                  style: TextStyle(color: Theme.of(context).disabledColor),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final item = _results[index];
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.caloriesPer100g.toStringAsFixed(0)} kcal/100g | '
                      'P: ${item.proteinPer100g.toStringAsFixed(1)}g | '
                      'C: ${item.carbsPer100g.toStringAsFixed(1)}g | '
                      'F: ${item.fatPer100g.toStringAsFixed(1)}g',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () => _showAddDialog(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
