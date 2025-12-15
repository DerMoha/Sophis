import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/gemini_food_service.dart';
import '../services/nutrition_provider.dart';
import '../services/settings_provider.dart';
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
  final _geminiService = GeminiFoodService();
  
  File? _imageFile;
  List<FoodAnalysis>? _results;
  bool _isLoading = false;
  String? _error;
  bool _serviceInitialized = false;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    final apiKey = context.read<SettingsProvider>().geminiApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      setState(() => _error = 'Please set your Gemini API key in Settings');
      return;
    }

    try {
      await _geminiService.initialize(apiKey);
      if (mounted) setState(() => _serviceInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to initialize: $e');
    }
  }

  @override
  void dispose() {
    _geminiService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (picked == null) return;
      
      setState(() {
        _imageFile = File(picked.path);
        _results = null;
        _error = null;
      });
      
      await _analyzeFood();
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to pick image: $e');
    }
  }

  Future<void> _analyzeFood() async {
    if (_imageFile == null) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _geminiService.analyzeFood(_imageFile!);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Analysis failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _addFood(FoodAnalysis food) {
    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${food.name} (${food.portionDisplay})',
      calories: food.calories,
      protein: food.protein,
      carbs: food.carbs,
      fat: food.fat,
      timestamp: DateTime.now(),
      meal: widget.meal,
    );
    
    context.read<NutritionProvider>().addFoodEntry(entry);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${food.name}')),
    );
  }

  void _addAllFoods() {
    if (_results == null || _results!.isEmpty) return;
    
    for (final food in _results!) {
      _addFood(food);
    }
    
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Food Recognition'),
        actions: [
          if (_results != null && _results!.isNotEmpty)
            TextButton(
              onPressed: _addAllFoods,
              child: const Text('Add All'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Image preview
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
                            'Take or select a photo of your food',
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
          
          // Results
          Expanded(
            flex: 2,
            child: _buildResultsArea(l10n, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsArea(AppLocalizations l10n, ThemeData theme) {
    if (_error != null) {
      final isApiKeyError = _error!.contains('API key');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              if (isApiKeyError) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go to Settings'),
                ),
              ],
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
            Text('Analyzing your food with AI...'),
          ],
        ),
      );
    }
    
    if (_results == null) {
      return Center(
        child: Text(
          _serviceInitialized 
              ? 'Take a photo to identify food'
              : 'Initializing AI...',
          style: TextStyle(color: theme.disabledColor),
        ),
      );
    }
    
    if (_results!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_food, size: 48, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              'No food detected in image',
              style: TextStyle(color: theme.disabledColor),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results!.length,
      itemBuilder: (context, index) {
        final food = _results![index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(food.displayName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${food.portionDisplay} • ${food.caloriesDisplay}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  food.macrosDisplay,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.add_circle, color: AppTheme.accent),
              onPressed: () => _addFood(food),
            ),
          ),
        );
      },
    );
  }
}
