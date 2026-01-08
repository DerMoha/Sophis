import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/food_entry.dart';
import '../services/openfoodfacts_service.dart';
import '../services/nutrition_provider.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final String meal;

  const BarcodeScannerScreen({super.key, required this.meal});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final _service = OpenFoodFactsService();
  
  bool _isProcessing = false;
  String? _lastScannedCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode == _lastScannedCode) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = barcode;
    });

    // Pause scanning
    _controller.stop();

    try {
      final product = await _service.lookupBarcode(barcode);
      
      if (!mounted) return;

      if (product == null) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.productNotFound(barcode))),
        );
        _controller.start();
        setState(() => _isProcessing = false);
        return;
      }

      // Show product dialog
      _showProductDialog(product, barcode);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorGeneric(e.toString()))),
        );
        _controller.start();
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showProductDialog(dynamic product, String barcode) {
    final l10n = AppLocalizations.of(context)!;
    final amountController = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Per 100g: ${product.caloriesPer100g.toStringAsFixed(0)} kcal',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'P: ${product.proteinPer100g.toStringAsFixed(1)}g | '
              'C: ${product.carbsPer100g.toStringAsFixed(1)}g | '
              'F: ${product.fatPer100g.toStringAsFixed(1)}g',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.amountGrams,
                suffixText: 'g',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _controller.start();
              setState(() => _isProcessing = false);
            },
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 100;
              final nutrients = product.calculateFor(amount);
              
              final entry = FoodEntry(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: '${product.name} (${amount.toStringAsFixed(0)}g)',
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
        title: Text(l10n.scanBarcode),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, _) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
          ),
          // Scan overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Status indicator
          if (_isProcessing)
            const Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
