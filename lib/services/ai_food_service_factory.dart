import 'package:sophis/models/app_settings.dart';
import 'package:sophis/services/ai_food_service.dart';
import 'package:sophis/services/gemini_food_service.dart';
import 'package:sophis/services/remote_ai_food_service.dart';

class AiFoodServiceFactory {
  const AiFoodServiceFactory._();

  static AiFoodService create({
    required AiProvider provider,
    required String model,
    String baseUrl = '',
  }) {
    if (provider == AiProvider.gemini) {
      return GeminiFoodService(selectedModel: model);
    }
    return RemoteAiFoodService(
      provider: provider,
      model: model.isEmpty ? defaultModel(provider) : model,
      baseUrl: baseUrl.isEmpty ? defaultBaseUrl(provider) : baseUrl,
    );
  }

  static String defaultModel(AiProvider provider) => switch (provider) {
        AiProvider.gemini => GeminiFoodService.modelName,
        AiProvider.openAi => 'gpt-4o-mini',
        AiProvider.openRouter => 'openai/gpt-4o-mini',
        AiProvider.anthropic => 'claude-3-5-haiku-latest',
        AiProvider.custom => '',
      };

  static String defaultBaseUrl(AiProvider provider) => switch (provider) {
        AiProvider.openAi => 'https://api.openai.com/v1',
        AiProvider.openRouter => 'https://openrouter.ai/api/v1',
        AiProvider.anthropic => 'https://api.anthropic.com',
        AiProvider.custom => '',
        AiProvider.gemini => '',
      };
}
