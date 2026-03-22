import 'package:flutter/material.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../../../services/settings_provider.dart';
import '../../../theme/app_theme.dart';

class OpenFoodFactsSection extends StatefulWidget {
  final SettingsProvider settings;

  const OpenFoodFactsSection({super.key, required this.settings});

  @override
  State<OpenFoodFactsSection> createState() => _OpenFoodFactsSectionState();
}

class _OpenFoodFactsSectionState extends State<OpenFoodFactsSection> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.settings.offUserId ?? '';
    _passwordController.text = widget.settings.offPassword ?? '';
  }

  @override
  void didUpdateWidget(OpenFoodFactsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _syncControllers() {
    if (!_usernameFocusNode.hasFocus) {
      _usernameController.value = TextEditingValue(
        text: widget.settings.offUserId ?? '',
        selection: TextSelection.collapsed(
          offset: (widget.settings.offUserId ?? '').length,
        ),
      );
    }
    if (!_passwordFocusNode.hasFocus) {
      _passwordController.value = TextEditingValue(
        text: widget.settings.offPassword ?? '',
        selection: TextSelection.collapsed(
          offset: (widget.settings.offPassword ?? '').length,
        ),
      );
    }
  }

  void _onCredentialsChanged() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    widget.settings.setOffCredentials(
      username.isEmpty ? null : username,
      password.isEmpty ? null : password,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasCredentials = widget.settings.hasOffCredentials;
    _syncControllers();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: l10n.offUsername,
            hintText: l10n.offUsernameHint,
            suffixIcon: hasCredentials
                ? const Icon(Icons.check_circle, color: AppTheme.success)
                : null,
          ),
          controller: _usernameController,
          focusNode: _usernameFocusNode,
          onChanged: (_) => _onCredentialsChanged(),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            labelText: l10n.offPassword,
            hintText: l10n.offPasswordHint,
            suffixIcon: hasCredentials
                ? const Icon(Icons.check_circle, color: AppTheme.success)
                : null,
          ),
          obscureText: true,
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          onChanged: (_) => _onCredentialsChanged(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.offAccountOptional,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showCreateAccountInfo(context),
              icon: const Icon(Icons.help_outline, size: 16),
              label: Text(l10n.offCreateAccount),
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

  void _showCreateAccountInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.offCreateAccount),
        content: Text(l10n.offCreateAccountInfo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}
