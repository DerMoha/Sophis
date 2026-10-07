import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/nutrition_label_draft.dart';
import 'package:sophis/services/nutrition_label_ai_provider.dart';
import 'package:sophis/services/service_result.dart';

class _FakeProvider implements NutritionLabelAiProvider {
  @override
  final String id;

  const _FakeProvider(this.id);

  @override
  Future<ServiceResult<NutritionLabelDraft>> readLabel({
    required File image,
    String? supportingOcrText,
  }) async =>
      const Failure(
        ServiceErrorType.parseError,
        'fake provider',
      );
}

void main() {
  test('registry selects and replaces the default provider', () {
    const local = _FakeProvider('local-cloud');
    const alternate = _FakeProvider('alternate');
    final registry = AiProviderRegistry(providers: [local]);

    expect(registry.defaultProvider, same(local));
    registry.register(alternate, makeDefault: true);
    expect(registry.defaultProvider, same(alternate));
    expect(
      registry.providers.map((provider) => provider.id),
      containsAll(<String>['local-cloud', 'alternate']),
    );

    registry.remove('alternate');
    expect(registry.defaultProvider, same(local));
  });
}
