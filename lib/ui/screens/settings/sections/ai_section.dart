import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/settings_provider.dart';
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
  final FocusNode _apiKeyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = widget.settings.geminiApiKey ?? '';
  }

  @override
  void didUpdateWidget(AiSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncApiKeyController(widget.settings.geminiApiKey ?? '');
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiKeyFocusNode.dispose();
    super.dispose();
  }

  void _syncApiKeyController(String apiKey) {
    if (_apiKeyFocusNode.hasFocus || _apiKeyController.text == apiKey) {
      return;
    }
    _apiKeyController.value = TextEditingValue(
      text: apiKey,
      selection: TextSelection.collapsed(offset: apiKey.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasKey = widget.settings.geminiApiKey?.isNotEmpty == true;
    _syncApiKeyController(widget.settings.geminiApiKey ?? '');

    return Column(
      children: [
        AppSection(
          title: 'Google Gemini',
          footer: l10n.getApiKeyHelper,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  labelText: l10n.geminiApiKey,
                  hintText: l10n.enterApiKey,
                  suffixIcon: hasKey
                      ? const Icon(Icons.check_circle, color: AppTheme.success)
                      : null,
                ),
                obscureText: true,
                controller: _apiKeyController,
                focusNode: _apiKeyFocusNode,
                onChanged: widget.settings.setGeminiApiKey,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: TextButton.icon(
                  onPressed: () => _showApiKeyGuide(context),
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

  void _showApiKeyGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ApiKeyGuideDialog(),
    );
  }
}
