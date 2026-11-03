import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/models/app_settings.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/settings/api_key_guide_dialog.dart';
import 'package:sophis/ui/components/common/app_surface.dart';

class AiSection extends StatefulWidget {
  final SettingsProvider settings;

  const AiSection({super.key, required this.settings});

  @override
  State<AiSection> createState() => _AiSectionState();
}

class _AiSectionState extends State<AiSection> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _endpointController = TextEditingController();
  final FocusNode _apiKeyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(AiSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    _endpointController.dispose();
    _apiKeyFocusNode.dispose();
    super.dispose();
  }

  void _syncControllers() {
    final apiKey = widget.settings.apiKeyFor(widget.settings.aiProvider) ?? '';
    if (!_apiKeyFocusNode.hasFocus && _apiKeyController.text != apiKey) {
      _apiKeyController.value = TextEditingValue(
        text: apiKey,
        selection: TextSelection.collapsed(offset: apiKey.length),
      );
    }
    if (_modelController.text != widget.settings.aiModel) {
      _modelController.text = widget.settings.aiModel;
    }
    if (_endpointController.text != widget.settings.aiBaseUrl) {
      _endpointController.text = widget.settings.aiBaseUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasKey = widget.settings.hasActiveAiApiKey;
    _syncControllers();

    return Column(
      children: [
        AppSection(
          title: l10n.cloudAiProviders,
          footer: l10n.aiKeysStayLocalBilling,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: DropdownButtonFormField<AiProvider>(
                isExpanded: true,
                initialValue: widget.settings.aiProvider,
                decoration: InputDecoration(labelText: l10n.aiProviderLabel),
                items: AiProvider.values
                    .map(
                      (provider) => DropdownMenuItem(
                        value: provider,
                        child: Text(
                          _providerName(provider, l10n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (provider) {
                  if (provider != null) {
                    _apiKeyFocusNode.unfocus();
                    widget.settings.setAiProvider(provider);
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: l10n.aiModelIdLabel,
                  hintText: l10n.aiModelDefaultHint,
                ),
                onChanged: widget.settings.setAiModel,
              ),
            ),
            if (widget.settings.aiProvider == AiProvider.custom)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _endpointController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.customAiEndpointLabel,
                    hintText: l10n.customAiEndpointHint,
                  ),
                  onChanged: widget.settings.setAiBaseUrl,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  labelText: l10n.aiProviderKeyLabel(
                    _providerName(widget.settings.aiProvider, l10n),
                  ),
                  hintText: l10n.enterApiKey,
                  suffixIcon: hasKey
                      ? const Icon(Icons.check_circle, color: AppTheme.success)
                      : null,
                ),
                obscureText: true,
                controller: _apiKeyController,
                focusNode: _apiKeyFocusNode,
                onChanged: (key) => widget.settings.setAiApiKey(
                  widget.settings.aiProvider,
                  key,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: TextButton.icon(
                  onPressed: widget.settings.aiProvider == AiProvider.gemini
                      ? () => _showApiKeyGuide(context)
                      : null,
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: Text(l10n.howToGetApiKey),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppSection(
          title: l10n.labelScanning,
          footer: l10n.aiAccuracyDisclaimer,
          children: [
            AppSwitchRow(
              title: l10n.labelCloudHelpTitle,
              subtitle: l10n.labelCloudHelpSubtitle,
              icon: Icons.document_scanner_outlined,
              value: widget.settings.labelCloudHelpEnabled,
              onChanged: widget.settings.setLabelCloudHelpEnabled,
              showDivider: false,
            ),
          ],
        ),
      ],
    );
  }

  String _providerName(AiProvider provider, AppLocalizations l10n) =>
      switch (provider) {
        AiProvider.gemini => 'Google Gemini',
        AiProvider.openAi => 'OpenAI',
        AiProvider.openRouter => 'OpenRouter',
        AiProvider.anthropic => 'Anthropic',
        AiProvider.custom => l10n.customAiEndpointName,
      };

  void _showApiKeyGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ApiKeyGuideDialog(),
    );
  }
}
