import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/services/local_ai_food_service.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/settings/api_key_guide_dialog.dart';

class AiSection extends StatefulWidget {
  final SettingsProvider settings;

  const AiSection({super.key, required this.settings});

  @override
  State<AiSection> createState() => _AiSectionState();
}

class _AiSectionState extends State<AiSection> {
  final TextEditingController _apiKeyController = TextEditingController();
  final FocusNode _apiKeyFocusNode = FocusNode();
  final LocalAiFoodService _localAiService = LocalAiFoodService();

  List<String> _installedLocalModels = [];
  String? _localModelError;
  int? _localModelInstallProgress;
  bool _hasActiveLocalModel = false;
  bool _isCheckingLocalModels = false;
  bool _isInstallingLocalModel = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = widget.settings.geminiApiKey ?? '';
    _loadLocalModelState();
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
    _localAiService.dispose();
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

  Future<void> _loadLocalModelState() async {
    if (_isCheckingLocalModels) return;

    setState(() {
      _isCheckingLocalModels = true;
      _localModelError = null;
    });

    final activeResult = await _localAiService.hasActiveModel();
    final modelsResult = await _localAiService.listInstalledModels();

    if (!mounted) return;

    setState(() {
      switch (activeResult) {
        case Success<bool>(value: final hasActiveModel):
          _hasActiveLocalModel = hasActiveModel;
        case Failure<bool>(message: final message):
          _hasActiveLocalModel = false;
          _localModelError = message;
      }

      switch (modelsResult) {
        case Success<List<String>>(value: final models):
          _installedLocalModels = models;
        case Failure<List<String>>(message: final message):
          _installedLocalModels = [];
          _localModelError ??= message;
      }

      _isCheckingLocalModels = false;
    });
  }

  Future<void> _installRecommendedLocalModel() async {
    if (_isInstallingLocalModel) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isInstallingLocalModel = true;
      _localModelInstallProgress = 0;
      _localModelError = null;
    });

    final result = await _localAiService.installRecommendedVisionModel(
      onProgress: (progress) {
        if (!mounted) return;
        setState(() {
          _localModelInstallProgress = progress.clamp(0, 100).toInt();
        });
      },
    );

    if (!mounted) return;

    switch (result) {
      case Success<String>():
        setState(() {
          _isInstallingLocalModel = false;
          _localModelInstallProgress = 100;
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Local Gemma model installed.')),
        );
        await _loadLocalModelState();
      case Failure<String>(message: final message):
        setState(() {
          _isInstallingLocalModel = false;
          _localModelInstallProgress = null;
          _localModelError = message;
        });
        messenger.showSnackBar(SnackBar(content: Text(message)));
    }
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
        const SizedBox(height: 16),
        _buildLocalModelCard(theme),
      ],
    );
  }

  Widget _buildLocalModelCard(ThemeData theme) {
    final statusColor = _isInstallingLocalModel
        ? theme.colorScheme.primary
        : _hasActiveLocalModel
            ? AppTheme.success
            : AppTheme.error;
    final statusLabel = _isInstallingLocalModel
        ? 'Installing'
        : _hasActiveLocalModel
            ? 'Ready'
            : 'Not installed';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                ),
                child: Icon(
                  Icons.phone_iphone_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Local Gemma model',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _localModelDescription(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: _localModelError == null
                  ? theme.colorScheme.onSurfaceVariant
                  : AppTheme.error,
            ),
          ),
          if (_isInstallingLocalModel) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _localModelInstallProgress == null ||
                      _localModelInstallProgress == 0
                  ? null
                  : _localModelInstallProgress! / 100,
              minHeight: 4,
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _isInstallingLocalModel || _hasActiveLocalModel
                    ? null
                    : _installRecommendedLocalModel,
                icon: _isInstallingLocalModel
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : const Icon(Icons.download_outlined, size: 16),
                label: Text(
                  _isInstallingLocalModel
                      ? 'Downloading...'
                      : 'Download Gemma 4 E2B',
                ),
              ),
              TextButton.icon(
                onPressed: _isCheckingLocalModels || _isInstallingLocalModel
                    ? null
                    : _loadLocalModelState,
                icon: _isCheckingLocalModels
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: Text(_isCheckingLocalModels ? 'Checking...' : 'Refresh'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _localModelDescription() {
    if (_isInstallingLocalModel) {
      final progress = _localModelInstallProgress;
      final progressText = progress == null || progress == 0
          ? 'Starting download'
          : 'Downloading $progress%';
      return '$progressText. Keep the app open while the ${LocalAiFoodService.recommendedVisionModelSize} model installs.';
    }

    if (_isCheckingLocalModels) {
      return 'Checking installed on-device models...';
    }

    if (_localModelError != null) {
      return _localModelError!;
    }

    if (_installedLocalModels.isEmpty) {
      return 'No local model found. Download ${LocalAiFoodService.recommendedVisionModelName} (${LocalAiFoodService.recommendedVisionModelSize}) to enable on-device food analysis.';
    }

    return 'Installed: ${_installedLocalModels.join(', ')}';
  }

  void _showApiKeyGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ApiKeyGuideDialog(),
    );
  }
}
