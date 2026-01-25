import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/gemini_food_service.dart';
import '../services/nutrition_provider.dart';
import '../services/settings_provider.dart';
import '../models/food_entry.dart';
import '../models/shareable_meal.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_food_analysis_sheet.dart';
import 'share_meal_screen.dart';

class AIFoodCameraScreen extends StatefulWidget {
  final String meal;

  const AIFoodCameraScreen({super.key, required this.meal});

  @override
  State<AIFoodCameraScreen> createState() => _AIFoodCameraScreenState();
}

class _AIFoodCameraScreenState extends State<AIFoodCameraScreen> {
  static const int maxImages = 5;
  
  final _picker = ImagePicker();
  final _geminiService = GeminiFoodService();
  
  final List<File> _images = [];
  List<EditableFoodResult>? _results;
  bool _isLoading = false;
  String? _error;
  bool _serviceInitialized = false;
  bool _isInitializing = false;
  int _remainingRequests = 20;

  @override
  void initState() {
    super.initState();
    // Initial load attempt
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initService();
    });
  }

  /// Convert technical exceptions to user-friendly error messages
  String _getUserFriendlyError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') || errorStr.contains('connection') || errorStr.contains('timeout')) {
      return 'Network error. Please check your internet connection and try again.';
    }
    if (errorStr.contains('quota') || errorStr.contains('limit') || errorStr.contains('429')) {
      return 'Daily AI limit reached. Please try again tomorrow.';
    }
    if (errorStr.contains('api key') || errorStr.contains('apikey') || errorStr.contains('unauthorized') || errorStr.contains('401')) {
      return 'Invalid API key. Please check your settings.';
    }
    if (errorStr.contains('image') && errorStr.contains('size')) {
      return 'Image file is too large. Please use a smaller image.';
    }

    // Fallback to generic message for unknown errors
    return 'Unable to analyze food. Please try again.';
  }

  Future<void> _initService() async {
    // Read API key before any async operation
    final apiKey = context.read<SettingsProvider>().geminiApiKey;
    
    // Load remaining requests
    final remaining = await GeminiFoodService.getRemainingRequests();
    if (mounted) setState(() => _remainingRequests = remaining);
    
    if (apiKey == null || apiKey.isEmpty) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.errorApiKey);
      return;
    }

    if (_isInitializing) return;

    if (mounted) {
      setState(() {
        _isInitializing = true;
        _error = null; // Clear previous errors
      });
    }

    try {
      await _geminiService.initialize(apiKey);
      if (mounted) setState(() => _serviceInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.errorInit(e.toString()));
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    _geminiService.dispose();
    if (_results != null) {
      for (final result in _results!) {
        result.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_images.length >= maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.maxImagesReached)),
      );
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (picked == null) return;
      
      setState(() {
        _images.add(File(picked.path));
        _results = null;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.errorPickImage(e.toString()));
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      _results = null;
    });
  }

  Future<void> _analyzeFood({String? correctionHint}) async {
    if (_images.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _geminiService.analyzeFoodMultiple(
        _images,
        correctionHint: correctionHint,
      );
      
      // Update remaining requests count
      final remaining = await GeminiFoodService.getRemainingRequests();
      
      if (mounted) {
        setState(() {
          _results = results.map((r) => EditableFoodResult(analysis: r)).toList();
          _remainingRequests = remaining;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _getUserFriendlyError(e);
          _isLoading = false;
        });
      }
    }
  }

  void _showEditSheet(EditableFoodResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditFoodAnalysisSheet(
        result: result,
        remainingRequests: _remainingRequests,
        onSaveEdits: () {
          setState(() {
            result.currentAnalysis = result.getEditedAnalysis();
            result.isModified = true;
          });
          Navigator.pop(ctx);
        },
        onReAnalyze: (correctionHint) async {
          Navigator.pop(ctx);
          await _analyzeSpecificFood(result, correctionHint);
        },
      ),
    );
  }

  Future<void> _analyzeSpecificFood(
    EditableFoodResult result,
    String correctionHint,
  ) async {
    setState(() => _isLoading = true);

    try {
      final updatedResults = await _geminiService.analyzeFoodMultiple(
        _images,
        correctionHint: correctionHint,
      );

      // Find best match in new results (use first result for simplicity)
      final updatedAnalysis = updatedResults.isNotEmpty ? updatedResults.first : null;

      // Update remaining requests count
      final remaining = await GeminiFoodService.getRemainingRequests();

      if (mounted && updatedAnalysis != null) {
        setState(() {
          result.originalAnalysis = updatedAnalysis;
          result.currentAnalysis = updatedAnalysis;
          result.isModified = false;

          // Update all controllers with new values
          result.nameController.text = updatedAnalysis.name;
          result.portionController.text = updatedAnalysis.portionGrams.toStringAsFixed(0);
          result.caloriesController.text = updatedAnalysis.calories.toStringAsFixed(0);
          result.proteinController.text = updatedAnalysis.protein.toStringAsFixed(1);
          result.carbsController.text = updatedAnalysis.carbs.toStringAsFixed(1);
          result.fatController.text = updatedAnalysis.fat.toStringAsFixed(1);

          _remainingRequests = remaining;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Food re-analyzed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _getUserFriendlyError(e);
          _isLoading = false;
        });
      }
    }
  }


  void _addFood(EditableFoodResult result) {
    final food = result.currentAnalysis; // Use edited values!

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

    setState(() {
      result.isAdded = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.addedSnack(entry.name))),
    );
  }

  void _addAllFoods() {
    if (_results == null || _results!.isEmpty) return;

    for (final result in _results!) {
      _addFood(result);
    }

    Navigator.pop(context);
  }

  void _shareAllFoods() {
    if (_results == null || _results!.isEmpty) return;

    final items = _results!.map((result) {
      final customName = result.controller.text.trim();
      return SharedFoodItem.fromFoodAnalysis(
        result.analysis,
        customName: customName.isNotEmpty ? customName : null,
      );
    }).toList();

    final meal = ShareableMeal(items: items);
    Navigator.push(
      context,
      AppTheme.slideRoute(ShareMealScreen(meal: meal)),
    );
  }

  void _shareSingleFood(EditableFoodResult result) {
    final customName = result.controller.text.trim();
    final item = SharedFoodItem.fromFoodAnalysis(
      result.analysis,
      customName: customName.isNotEmpty ? customName : null,
    );

    final meal = ShareableMeal(items: [item]);
    Navigator.push(
      context,
      AppTheme.slideRoute(ShareMealScreen(meal: meal)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Watch only for API key changes to avoid unnecessary rebuilds
    final hasApiKey = context.select<SettingsProvider, bool>((s) => s.hasGeminiApiKey);

    // Retry initialization if key becomes available and we failed previously
    if (hasApiKey && !_serviceInitialized && !_isInitializing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initService();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiFoodRecognition),
        actions: [
          // Remaining requests badge
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _remainingRequests <= 3 
                      ? AppTheme.warning.withAlpha(26)
                      : AppTheme.success.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt,
                      size: 14,
                      color: _remainingRequests <= 3 
                          ? AppTheme.warning 
                          : AppTheme.success,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      l10n.imagesLeft(_remainingRequests),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _remainingRequests <= 3 
                            ? AppTheme.warning 
                            : AppTheme.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Images count
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_images.length}/$maxImages',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          if (_results != null && _results!.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: _shareAllFoods,
              tooltip: l10n.share,
            ),
            TextButton(
              onPressed: _addAllFoods,
              child: Text(l10n.addAll),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 140,
            child: _images.isEmpty
                ? Center(
                    child: Text(
                      l10n.takePhotosPrompt,
                      style: TextStyle(color: theme.disabledColor),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    itemCount: _images.length,
                    itemBuilder: (context, index) => _buildImageTile(index),
                  ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _serviceInitialized && _images.length < maxImages
                            ? () => _pickImage(ImageSource.camera)
                            : null,
                        icon: const Icon(Icons.camera_alt),
                        label: Text(l10n.camera),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _serviceInitialized && _images.length < maxImages
                            ? () => _pickImage(ImageSource.gallery)
                            : null,
                        icon: const Icon(Icons.photo_library),
                        label: Text(l10n.gallery),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _serviceInitialized && _images.isNotEmpty && !_isLoading
                        ? () => _analyzeFood()
                        : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(l10n.analyzeWithAI),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(),
          
          Expanded(
            child: _buildResultsArea(l10n, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildImageTile(int index) {
    return Stack(
      children: [
        Container(
          width: 120,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: FileImage(_images[index]),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 12,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
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
                  child: Text(l10n.goToSettings),
                ),
              ],
            ],
          ),
        ),
      );
    }
    
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.analyzingFood),
          ],
        ),
      );
    }
    
    if (_results == null) {
      return Center(
        child: Text(
          _serviceInitialized 
              ? l10n.takePhotosAndAnalyze
              : l10n.initializingAI,
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
            Text(l10n.noFoodDetected, style: TextStyle(color: theme.disabledColor)),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results!.length,
      itemBuilder: (context, index) {
        final result = _results![index];
        return _buildFoodResultCard(result, theme);
      },
    );
  }

  Widget _buildFoodResultCard(EditableFoodResult result, ThemeData theme) {
    final food = result.currentAnalysis;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food name with edit button
            Row(
              children: [
                Expanded(
                  child: Text(
                    food.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    result.isModified ? Icons.edit : Icons.edit_outlined,
                    size: 20,
                    color: result.isModified
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => _showEditSheet(result),
                  tooltip: 'Edit values',
                ),
              ],
            ),

            // Modified badge
            if (result.isModified)
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 12, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Modified',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${food.portionDisplay} • ${food.caloriesDisplay}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(food.macrosDisplay, style: theme.textTheme.bodySmall),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Share button
                    IconButton(
                      icon: Icon(
                        Icons.share_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () => _shareSingleFood(result),
                      tooltip: AppLocalizations.of(context)!.share,
                    ),
                    // Add button or Added indicator
                    result.isAdded
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check, color: Colors.white, size: 18),
                                const SizedBox(width: 4),
                                Text(AppLocalizations.of(context)!.added, style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _addFood(result),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(AppLocalizations.of(context)!.add),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EditableFoodResult {
  FoodAnalysis originalAnalysis; // Keep for reset functionality
  FoodAnalysis currentAnalysis; // Current (possibly edited) values

  // Controllers for all editable fields
  final TextEditingController nameController;
  final TextEditingController portionController;
  final TextEditingController caloriesController;
  final TextEditingController proteinController;
  final TextEditingController carbsController;
  final TextEditingController fatController;

  bool isAdded = false;
  bool isModified = false; // Track if user made edits

  EditableFoodResult({required FoodAnalysis analysis})
      : originalAnalysis = analysis,
        currentAnalysis = analysis,
        nameController = TextEditingController(text: analysis.name),
        portionController =
            TextEditingController(text: analysis.portionGrams.toStringAsFixed(0)),
        caloriesController =
            TextEditingController(text: analysis.calories.toStringAsFixed(0)),
        proteinController =
            TextEditingController(text: analysis.protein.toStringAsFixed(1)),
        carbsController =
            TextEditingController(text: analysis.carbs.toStringAsFixed(1)),
        fatController = TextEditingController(text: analysis.fat.toStringAsFixed(1));

  // Backward compatibility - map to nameController
  TextEditingController get controller => nameController;
  FoodAnalysis get analysis => currentAnalysis;

  /// Apply controller values to create edited analysis
  FoodAnalysis getEditedAnalysis() {
    return FoodAnalysis(
      name: nameController.text.trim(),
      portionGrams: double.tryParse(portionController.text) ?? currentAnalysis.portionGrams,
      calories: double.tryParse(caloriesController.text) ?? currentAnalysis.calories,
      protein: double.tryParse(proteinController.text) ?? currentAnalysis.protein,
      carbs: double.tryParse(carbsController.text) ?? currentAnalysis.carbs,
      fat: double.tryParse(fatController.text) ?? currentAnalysis.fat,
    );
  }

  /// Generate correction hint for AI re-analysis
  String generateCorrectionHint() {
    final parts = <String>[];

    if (nameController.text.trim() != originalAnalysis.name) {
      parts.add('The food is actually "${nameController.text.trim()}"');
    }

    final portion = double.tryParse(portionController.text);
    if (portion != null && (portion - originalAnalysis.portionGrams).abs() > 5) {
      parts.add('portion should be ${portion.toStringAsFixed(0)}g');
    }

    if (parts.isEmpty) {
      parts.add('Re-evaluate the nutrition values for "${nameController.text.trim()}"');
    }

    return '${parts.join(', ')}.';
  }

  /// Dispose all controllers
  void dispose() {
    nameController.dispose();
    portionController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
  }
}
