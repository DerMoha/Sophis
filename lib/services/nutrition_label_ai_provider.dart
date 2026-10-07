import 'dart:io';

import 'package:sophis/models/nutrition_label_draft.dart';
import 'package:sophis/services/gemini_food_service.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/service_result.dart';

/// Capability-based contract for image nutrition readers.
///
/// The scanner depends on this contract rather than a vendor SDK. Adding a
/// managed backend or another provider later should not require UI changes.
abstract interface class NutritionLabelAiProvider {
  String get id;

  Future<ServiceResult<NutritionLabelDraft>> readLabel({
    required File image,
    String? supportingOcrText,
  });
}

class AiProviderRegistry {
  final Map<String, NutritionLabelAiProvider> _providers = {};
  String? _defaultProviderId;

  AiProviderRegistry({
    Iterable<NutritionLabelAiProvider> providers = const [],
    String? defaultProviderId,
  }) : _defaultProviderId = defaultProviderId {
    for (final provider in providers) {
      register(provider);
    }
  }

  Iterable<NutritionLabelAiProvider> get providers => _providers.values;

  NutritionLabelAiProvider? get defaultProvider =>
      _defaultProviderId == null ? null : _providers[_defaultProviderId];

  void register(
    NutritionLabelAiProvider provider, {
    bool makeDefault = false,
  }) {
    _providers[provider.id] = provider;
    if (makeDefault || _defaultProviderId == null) {
      _defaultProviderId = provider.id;
    }
  }

  void remove(String id) {
    _providers.remove(id);
    if (_defaultProviderId == id) {
      _defaultProviderId = _providers.keys.firstOrNull;
    }
  }
}

/// First adapter for the existing BYO Gemini integration.
class GeminiNutritionLabelAiProvider implements NutritionLabelAiProvider {
  final GeminiFoodService service;

  const GeminiNutritionLabelAiProvider(this.service);

  @override
  String get id => 'gemini';

  @override
  Future<ServiceResult<NutritionLabelDraft>> readLabel({
    required File image,
    String? supportingOcrText,
  }) async {
    final result = await service.parseNutritionImage(
      image,
      ocrText: supportingOcrText,
    );
    return switch (result) {
      Success<NutritionLabelResult?>(value: final label) => label == null
          ? const Failure(
              ServiceErrorType.parseError,
              'The provider could not identify a nutrition label.',
            )
          : Success(
              NutritionLabelDraft.fromResult(label).copyWith(
                analysisSource: NutritionLabelAnalysisSource.gemini,
              ),
            ),
      Failure<NutritionLabelResult?>(
        errorType: final type,
        message: final message,
      ) =>
        Failure(type, message),
    };
  }
}
