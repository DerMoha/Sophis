import 'package:flutter/material.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../../../services/settings_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../components/settings/api_key_guide_dialog.dart';

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
    final theme = Theme.of(context);
    final hasKey = widget.settings.geminiApiKey?.isNotEmpty == true;
    _syncApiKeyController(widget.settings.geminiApiKey ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
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
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.getApiKeyHelper,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showApiKeyGuide(context),
              icon: const Icon(Icons.help_outline, size: 16),
              label: Text(l10n.howToGetApiKey),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
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
