import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/tflite_food_service.dart';
import '../services/nutrition_provider.dart';
import '../models/food_entry.dart';
import '../theme/app_theme.dart';

class AIFoodCameraScreen extends StatefulWidget {
  final String meal;

  const AIFoodCameraScreen({super.key, required this.meal});

  @override
  State<AIFoodCameraScreen> createState() => _AIFoodCameraScreenState();
}

class _AIFoodCameraScreenState extends State<AIFoodCameraScreen> {
  final _picker = ImagePicker();
  final _tfliteService = TFLiteFoodService();
  
  File? _imageFile;
  List<FoodPrediction>? _predictions;
  bool _isLoading = false;
  String? _error;
  bool _serviceInitialized = false;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    try {
      await _tfliteService.initialize();
      setState(() => _serviceInitialized = true);
    } catch (e) {
      setState(() => _error = 'Failed to load AI model: $e');
    }
  }

  @override
  void dispose() {
    _tfliteService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (picked == null) return;
      
      setState(() {
        _imageFile = File(picked.path);
        _predictions = null;
        _error = null;
      });
      
      await _classify();
    } catch (e) {
      setState(() => _error = 'Failed to pick image: $e');
    }
  }

  Future<void> _classify() async {
    if (_imageFile == null) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final predictions = await _tfliteService.classify(_imageFile!);
      setState(() {
        _predictions = predictions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Classification failed: $e';
        _isLoading = false;
      });
    }
  }

  void _addPrediction(FoodPrediction prediction) {
    final l10n = AppLocalizations.of(context)!;
    final caloriesController = TextEditingController(text: '200');
    final proteinController = TextEditingController(text: '10');
    final carbsController = TextEditingController(text: '20');
    final fatController = TextEditingController(text: '8');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(prediction.displayLabel),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confidence: ${prediction.confidencePercent}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Estimate nutrition values:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Calories',
                  suffixText: 'kcal',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: proteinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Protein',
                        suffixText: 'g',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Carbs',
                        suffixText: 'g',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Fat',
                        suffixText: 'g',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final entry = FoodEntry(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: prediction.displayLabel,
                calories: double.tryParse(caloriesController.text) ?? 200,
                protein: double.tryParse(proteinController.text) ?? 10,
                carbs: double.tryParse(carbsController.text) ?? 20,
                fat: double.tryParse(fatController.text) ?? 8,
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Food Recognition'),
      ),
      body: Column(
        children: [
          // Image preview area
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              color: theme.colorScheme.surfaceContainerHighest,
              child: _imageFile != null
                  ? Image.file(_imageFile!, fit: BoxFit.contain)
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 64,
                            color: theme.disabledColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Take or select a photo',
                            style: TextStyle(color: theme.disabledColor),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          
          // Capture buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _serviceInitialized ? () => _pickImage(ImageSource.camera) : null,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _serviceInitialized ? () => _pickImage(ImageSource.gallery) : null,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
          ),
          
          // Results area
          Expanded(
            flex: 2,
            child: _buildResultsArea(l10n, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsArea(AppLocalizations l10n, ThemeData theme) {
    if (!_serviceInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing food...'),
          ],
        ),
      );
    }
    
    if (_predictions == null || _predictions!.isEmpty) {
      return Center(
        child: Text(
          'Take a photo to identify food',
          style: TextStyle(color: theme.disabledColor),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _predictions!.length,
      itemBuilder: (context, index) {
        final pred = _predictions![index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(pred.displayLabel),
            subtitle: LinearProgressIndicator(
              value: pred.confidence,
              backgroundColor: AppTheme.accent.withAlpha(26),
              valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
            ),
            trailing: Text(
              pred.confidencePercent,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () => _addPrediction(pred),
          ),
        );
      },
    );
  }
}
