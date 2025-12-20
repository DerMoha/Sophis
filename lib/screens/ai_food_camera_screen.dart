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
          _error = AppLocalizations.of(context)!.errorAnalysis(e.toString());
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reAnalyzeWithCorrection(EditableFoodResult result) async {
    final correctedName = result.controller.text.trim();
    if (correctedName.isEmpty || correctedName == result.analysis.name) return;

    setState(() => _isLoading = true);

    try {
      final updatedResults = await _geminiService.analyzeFoodMultiple(
        _images,
        correctionHint: 'The food "${result.analysis.name}" is actually "$correctedName". Please update the nutrition estimate.',
      );
      
      if (mounted) {
        setState(() {
          _results = updatedResults.map((r) => EditableFoodResult(analysis: r)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Re-analysis failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _addFood(EditableFoodResult result) {
    final food = result.analysis;
    final customName = result.controller.text.trim();
    
    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: customName.isNotEmpty ? customName : '${food.name} (${food.portionDisplay})',
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
          if (_results != null && _results!.isNotEmpty)
            TextButton(
              onPressed: _addAllFoods,
              child: Text(l10n.addAll),
            ),
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
    final food = result.analysis;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: result.controller,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.foodName,
                      hintText: food.name,
                      isDense: true,
                      suffixIcon: result.controller.text != food.name
                          ? IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              onPressed: () => _reAnalyzeWithCorrection(result),
                              tooltip: 'Re-analyze with this name',
                            )
                          : null,
                    ),
                  ),
                ),
              ],
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
      ),
    );
  }
}

class EditableFoodResult {
  final FoodAnalysis analysis;
  final TextEditingController controller;
  bool isAdded = false;

  EditableFoodResult({required this.analysis})
      : controller = TextEditingController(text: analysis.name);
}
