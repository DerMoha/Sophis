import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/food_item.dart';
import '../models/food_entry.dart';
import '../services/openfoodfacts_service.dart';
import '../services/nutrition_provider.dart';
import '../widgets/portion_picker_sheet.dart';

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

  void _showProductDialog(FoodItem product, String barcode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PortionPickerSheet(
        item: product,
        meal: widget.meal,
        onAdd: (grams) => _addFoodEntry(product, grams),
      ),
    ).whenComplete(() {
      // Resume scanning when sheet is closed
      _controller.start();
      setState(() => _isProcessing = false);
    });
  }

  void _addFoodEntry(FoodItem product, double grams) {
    final nutrients = product.calculateFor(grams);
    final displayName = product.brand != null && product.brand!.isNotEmpty
        ? '${product.brand} ${product.name}'
        : product.name;

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
    provider.addRecentFood(product); // Save to recent foods
    Navigator.pop(context); // Close barcode scanner
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
