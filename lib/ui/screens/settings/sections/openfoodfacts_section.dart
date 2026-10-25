import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/components/common/app_surface.dart';
import 'package:sophis/ui/theme/app_theme.dart';

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
    final hasCredentials = widget.settings.hasOffCredentials;
    _syncControllers();

    return AppSection(
      title: l10n.settingsAccount,
      footer: l10n.offAccountOptional,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
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
                autocorrect: false,
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
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: TextButton.icon(
              onPressed: () => _showCreateAccountInfo(context),
              icon: const Icon(Icons.help_outline, size: 16),
              label: Text(l10n.offCreateAccount),
            ),
          ),
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
