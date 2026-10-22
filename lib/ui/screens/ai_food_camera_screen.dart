import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sophis/ui/components/draft_guard.dart';
import 'package:sophis/ui/components/common/entry_feedback.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:gal/gal.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/services/gemini_food_service.dart';
import 'package:sophis/services/gemini/models/models.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/food_intake_controller.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/models/shareable_meal.dart';
import 'package:sophis/ui/components/ai_food_image_tile.dart';
import 'package:sophis/ui/components/ai_food_result.dart';
import 'package:sophis/ui/components/ai_food_result_card.dart';
import 'package:sophis/ui/components/common/ui_primitives.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/theme/animations.dart';
import 'package:sophis/ui/components/edit_food_analysis_sheet.dart';
import 'package:sophis/ui/screens/share_meal_screen.dart';
import 'package:sophis/ui/screens/settings_screen.dart';

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
  bool _isAddingFood = false;
  bool _showApiKeyAction = false;
  int _remainingRequests = 20;

  bool get _canAnalyze => _serviceInitialized;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initService();
    });
  }

  String _getUserFriendlyError(dynamic error) {
    final l10n = AppLocalizations.of(context)!;
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout')) {
      return l10n.errorNetworkTryAgain;
    }
    if (errorStr.contains('quota') ||
        errorStr.contains('limit') ||
        errorStr.contains('429')) {
      return l10n.errorAiLimitReached;
    }
    if (errorStr.contains('api key') ||
        errorStr.contains('apikey') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('401')) {
      return l10n.errorInvalidApiKey;
    }
    if (errorStr.contains('image') && errorStr.contains('size')) {
      return l10n.errorImageTooLarge;
    }

    return l10n.errorUnableToAnalyzeFood;
  }

  bool _isApiKeyFailure(String message) {
    final errorStr = message.toLowerCase();
    return errorStr.contains('api key') ||
        errorStr.contains('apikey') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('401');
  }

  Future<void> _initService() async {
    final apiKey = context.read<SettingsProvider>().geminiApiKey;

    final remaining = await GeminiFoodService.getRemainingRequests();
    if (mounted) setState(() => _remainingRequests = remaining);
    if (!mounted) return;

    if (apiKey == null || apiKey.isEmpty) {
      if (mounted) {
        setState(() {
          _serviceInitialized = false;
          _error = AppLocalizations.of(context)!.errorApiKey;
          _showApiKeyAction = true;
        });
      }
      return;
    }

    if (_isInitializing) return;

    if (mounted) {
      setState(() {
        _isInitializing = true;
        _error = null;
      });
    }

    final cloudInitResult = _geminiService.initialize(apiKey);

    if (!mounted) return;

    setState(() {
      switch (cloudInitResult) {
        case Success<void>():
          _serviceInitialized = true;
          _showApiKeyAction = false;
        case Failure<void>(message: final message):
          _serviceInitialized = false;
          _error = AppLocalizations.of(context)!.errorInit(message);
          _showApiKeyAction = _isApiKeyFailure(message);
      }
      _isInitializing = false;
    });
  }

  @override
  void dispose() {
    _geminiService.dispose();
    _disposeResults(_results);
    super.dispose();
  }

  void _disposeResults(List<EditableFoodResult>? results) {
    if (results == null) return;

    for (final result in results) {
      result.dispose();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_images.length >= maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.maxImagesReached),
        ),
      );
      return;
    }

    try {
      final List<XFile> picked;
      if (source == ImageSource.gallery) {
        picked = await _picker.pickMultiImage(
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
          limit: maxImages - _images.length,
        );
      } else {
        final photo = await _picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        picked = [if (photo != null) photo];
      }

      if (!mounted || picked.isEmpty) return;

      if (source == ImageSource.camera) {
        try {
          await Gal.putImage(picked.first.path);
        } catch (e) {
          debugPrint('Failed to save to gallery: $e');
        }
      }

      if (!mounted) return;
      _disposeResults(_results);

      setState(() {
        _images.addAll(
          picked
              .take(maxImages - _images.length)
              .map((image) => File(image.path)),
        );
        _results = null;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              AppLocalizations.of(context)!.errorPickImage(e.toString()),
        );
      }
    }
  }

  void _removeImage(int index) {
    _disposeResults(_results);

    setState(() {
      _images.removeAt(index);
      _results = null;
    });
  }

  Future<void> _analyzeFood({String? correctionHint}) async {
    if (_images.isEmpty || _isLoading) return;
    if (!_canAnalyze) {
      setState(() {
        _error = AppLocalizations.of(context)!.errorApiKey;
        _showApiKeyAction = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final analysisResult = await _geminiService.analyzeFoodMultiple(
        _images,
        correctionHint: correctionHint,
      );

      final remaining = await GeminiFoodService.getRemainingRequests();

      if (!mounted) return;

      switch (analysisResult) {
        case Success<List<FoodAnalysis>>(value: final results):
          _disposeResults(_results);
          _results =
              results.map((r) => EditableFoodResult(analysis: r)).toList();
        case Failure<List<FoodAnalysis>>(message: final message):
          _error = _getUserFriendlyError(message);
          _showApiKeyAction = _isApiKeyFailure(message);
      }

      setState(() {
        _remainingRequests = remaining;
        _isLoading = false;
      });
    } on Object catch (error, stackTrace) {
      debugPrint('AI food screen analysis failed: $error\n$stackTrace');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = _getUserFriendlyError(error);
        _showApiKeyAction = _isApiKeyFailure(error.toString());
      });
    }
  }

  Future<void> _reanalyzeAllFoods() async {
    final results = _results;
    if (results == null || _remainingRequests <= 0 || _isLoading) return;
    final hint = buildFoodReanalysisHint(results);
    if (_remainingRequests <= 3) {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.confirmReanalysis),
          content: Text(l10n.reanalysisConfirmation(_remainingRequests)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.aiReanalyzeAction),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    await _analyzeFood(correctionHint: hint);
  }

  void _showEditSheet(
    EditableFoodResult result, {
    required bool allowReAnalyze,
  }) {
    showDraftBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditFoodAnalysisSheet(
        result: result,
        remainingRequests: _remainingRequests,
        allowReAnalyze: allowReAnalyze,
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

    final confirmedFoods = (_results ?? [])
        .where((r) => r != result)
        .map((r) => r.currentAnalysis)
        .toList();

    final reanalysisResult = await _geminiService.reanalyzeSingleFood(
      _images,
      currentFood: result.getEditedAnalysis(),
      correctionHint: correctionHint,
      confirmedFoods: confirmedFoods,
    );

    final remaining = await GeminiFoodService.getRemainingRequests();

    if (!mounted) return;

    switch (reanalysisResult) {
      case Success<FoodAnalysis?>(value: final updatedAnalysis):
        if (updatedAnalysis == null) {
          final l10n = AppLocalizations.of(context)!;
          setState(() {
            _error = l10n.unableToReanalyzeFood;
            _remainingRequests = remaining;
            _isLoading = false;
          });
          return;
        }

        setState(() {
          result.originalAnalysis = updatedAnalysis;
          result.currentAnalysis = updatedAnalysis;
          result.isModified = false;

          result.nameController.text = updatedAnalysis.name;
          result.portionController.text =
              updatedAnalysis.portionGrams.toStringAsFixed(0);
          result.caloriesController.text =
              updatedAnalysis.calories.toStringAsFixed(0);
          result.proteinController.text =
              updatedAnalysis.protein.toStringAsFixed(1);
          result.carbsController.text =
              updatedAnalysis.carbs.toStringAsFixed(1);
          result.fatController.text = updatedAnalysis.fat.toStringAsFixed(1);
          result.fiberController.text =
              updatedAnalysis.fiber.toStringAsFixed(1);

          _remainingRequests = remaining;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.foodReanalyzed),
          ),
        );
      case Failure<FoodAnalysis?>(message: final message):
        setState(() {
          _error = _getUserFriendlyError(message);
          _showApiKeyAction = _isApiKeyFailure(message);
          _isLoading = false;
        });
    }
  }

  Future<void> _openApiKeySettings() async {
    await Navigator.push<void>(
      context,
      AppTheme.slideRoute(const SettingsScreen.ai()),
    );

    if (!mounted || !context.read<SettingsProvider>().hasGeminiApiKey) return;
    await _initService();
  }

  Future<void> _addAllFoods() async {
    if (_isAddingFood) return;
    final results = _results;
    if (results == null || results.isEmpty) return;
    setState(() => _isAddingFood = true);
    final outcome = await addSelectedAiFoods(results, context.read<FoodIntakeController>(), widget.meal);
    if (!mounted) return;
    setState(() => _isAddingFood = false);
    showFoodsAddedFeedback(context, outcome.added.keys.toList(), onUndone: (entry) {
      if (!mounted) return;
      setState(() => outcome.added[entry]!.isAdded = false);
    },);
    if (outcome.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(outcome.error!)));
    }
  }

  void _shareAllFoods() {
    final results = _results;
    if (results == null || results.isEmpty) return;

    final items = results.map((result) {
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

    final hasApiKey =
        context.select<SettingsProvider, bool>((s) => s.hasGeminiApiKey);

    if (hasApiKey && !_serviceInitialized && !_isInitializing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initService();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.photographFood,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 112,
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
                      itemBuilder: (context, index) => AiFoodImageTile(
                        image: _images[index],
                        onRemove: () => _removeImage(index),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${l10n.imagesLeft(_remainingRequests)} · ${_images.length}/$maxImages',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _canAnalyze && _images.length < maxImages
                              ? () => _pickImage(ImageSource.camera)
                              : null,
                          icon: const Icon(Icons.camera_alt),
                          label: Text(l10n.camera),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _canAnalyze && _images.length < maxImages
                              ? () => _pickImage(ImageSource.gallery)
                              : null,
                          icon: const Icon(Icons.photo_library),
                          label: Text(l10n.gallery),
                        ),
                      ),
                    ],
                  ),
                  if (_results?.isNotEmpty != true) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _canAnalyze &&
                                _images.isNotEmpty &&
                                !_isLoading &&
                                !_isAddingFood &&
                                _remainingRequests > 0 &&
                                !(_results?.any((result) => result.isAdded) ??
                                    false)
                            ? _analyzeFood
                            : null,
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(l10n.analyzeWithAI),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(),
            _buildResultsArea(l10n, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsArea(AppLocalizations l10n, ThemeData theme) {
    if (_error != null && _results == null) {
      return FadeInSlide(
        index: 0,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppTheme.error,
                ),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                if (_showApiKeyAction) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _openApiKeySettings,
                    icon: const Icon(Icons.key_outlined),
                    label: Text(l10n.goToSettings),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return LoadingState(label: l10n.analyzingFood);
    }

    final results = _results;

    if (results == null) {
      return FadeInSlide(
        index: 0,
        child: Center(
          child: Text(
            _canAnalyze ? l10n.takePhotosAndAnalyze : l10n.initializingAI,
            style: TextStyle(color: theme.disabledColor),
          ),
        ),
      );
    }

    if (results.isEmpty) {
      return FadeInSlide(
        index: 0,
        child: Center(
          child: Text(
            l10n.noFoodDetected,
            style: TextStyle(color: theme.disabledColor),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          FadeInSlide(
            index: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cloud_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.aiAnalysisResults,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: _shareAllFoods,
                      icon: const Icon(Icons.share_outlined),
                      label: Text(l10n.share),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                ],
                for (final result in results)
                  AiFoodResultCard(
                    result: result,
                    allowComments: true,
                    onEdit: () => _showEditSheet(result, allowReAnalyze: true),
                    onShare: () => _shareSingleFood(result),
                    enabled: !_isAddingFood,
                    onToggleSelection: () => setState(() => result.isSelected = !result.isSelected),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _remainingRequests > 0 &&
                          !_isAddingFood &&
                          !results.any((result) => result.isAdded)
                      ? _reanalyzeAllFoods
                      : null,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(l10n.aiReanalyzeAll),
                ),
                const SizedBox(height: 4),
                Text(
                  results.any((result) => result.isAdded)
                      ? l10n.aiBatchAlreadyAdded
                      : '${l10n.aiReanalyzeCost} · ${l10n.imagesLeft(_remainingRequests)}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: !_isAddingFood && results.any((result) => result.isSelected && !result.isAdded) ? _addAllFoods : null,
                  icon: const Icon(Icons.add),
                  label: Text(results.where((result) => !result.isAdded).every((result) => result.isSelected)
                    ? l10n.addAll : l10n.addSelection,),
                ),),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
