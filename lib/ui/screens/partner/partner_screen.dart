import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/partner_provider.dart';
import 'package:sophis/services/partner/partner_backend.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';
import 'package:sophis/ui/screens/partner/partner_day_screen.dart';
import 'package:sophis/ui/theme/app_theme.dart';

String partnerErrorMessage(AppLocalizations l10n, PartnerError error) =>
    switch (error) {
      PartnerError.network => l10n.partnerErrorNetwork,
      PartnerError.invalidCredentials => l10n.partnerErrorCredentials,
      PartnerError.emailInUse => l10n.partnerErrorEmailInUse,
      PartnerError.weakPassword => l10n.partnerErrorWeakPassword,
      PartnerError.invalidEmail => l10n.partnerErrorInvalidEmail,
      PartnerError.tooManyRequests => l10n.partnerErrorTooManyRequests,
      PartnerError.requiresRecentLogin => l10n.partnerErrorRecentLogin,
      PartnerError.inviteInvalid => l10n.partnerErrorInviteInvalid,
      PartnerError.ownInvite => l10n.partnerErrorOwnInvite,
      PartnerError.alreadyPaired => l10n.partnerErrorAlreadyPaired,
      PartnerError.unknown => l10n.partnerErrorUnknown,
    };

/// Account, invitation and connection management for the single partner.
class PartnerScreen extends StatefulWidget {
  final String? inviteCode;

  const PartnerScreen({super.key, this.inviteCode});

  @override
  State<PartnerScreen> createState() => _PartnerScreenState();
}

class _PartnerScreenState extends State<PartnerScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  late final _code = TextEditingController(text: widget.inviteCode ?? '');
  bool _creating = false;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PartnerProvider>().clearError();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final partner = context.watch<PartnerProvider>();
    final theme = Theme.of(context);
    final error = partner.error;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.partnerSharingLabel)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (error != null) ...[
              Text(
                partnerErrorMessage(l10n, error),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],
            ...switch (partner.status) {
              PartnerStatus.unavailable => [Text(l10n.partnerUnavailable)],
              PartnerStatus.loading => [
                  const Center(child: CircularProgressIndicator.adaptive()),
                ],
              PartnerStatus.signedOut => _buildAccountForm(l10n, partner),
              PartnerStatus.needsName => _buildNameForm(l10n, partner),
              PartnerStatus.single => [
                  ..._buildInvite(l10n, partner),
                  const SizedBox(height: 24),
                  ..._buildCodeEntry(l10n, partner),
                  const SizedBox(height: 32),
                  ..._buildAccountActions(l10n, partner),
                ],
              PartnerStatus.paired => [
                  ..._buildConnected(l10n, partner),
                  const SizedBox(height: 32),
                  ..._buildAccountActions(l10n, partner),
                ],
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAccountForm(
    AppLocalizations l10n,
    PartnerProvider partner,
  ) {
    final theme = Theme.of(context);
    return [
      Text(l10n.partnerIntro, style: theme.textTheme.bodyLarge),
      const SizedBox(height: 24),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        autocorrect: false,
        decoration: InputDecoration(labelText: l10n.partnerEmail),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _password,
        obscureText: _hidePassword,
        autofillHints: [
          _creating ? AutofillHints.newPassword : AutofillHints.password,
        ],
        decoration: InputDecoration(
          labelText: l10n.partnerPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _hidePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _hidePassword = !_hidePassword),
          ),
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: partner.busy
            ? null
            : () => _creating
                ? partner.createAccount(_email.text, _password.text)
                : partner.signIn(_email.text, _password.text),
        child: Text(
          _creating ? l10n.partnerCreateAccount : l10n.partnerSignIn,
        ),
      ),
      TextButton(
        onPressed: () => setState(() => _creating = !_creating),
        child: Text(
          _creating ? l10n.partnerSwitchToSignIn : l10n.partnerSwitchToCreate,
        ),
      ),
      if (!_creating)
        TextButton(
          onPressed: partner.busy ? null : () => _resetPassword(l10n, partner),
          child: Text(l10n.partnerForgotPassword),
        ),
    ];
  }

  Future<void> _resetPassword(
    AppLocalizations l10n,
    PartnerProvider partner,
  ) async {
    if (!await partner.resetPassword(_email.text) || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.partnerResetSent)));
  }

  List<Widget> _buildNameForm(AppLocalizations l10n, PartnerProvider partner) {
    return [
      Text(
        l10n.partnerNameTitle,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _name,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: l10n.partnerNameLabel),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: partner.busy || _name.text.trim().isEmpty
            ? null
            : () => partner.saveName(_name.text),
        child: Text(l10n.save),
      ),
    ];
  }

  List<Widget> _buildInvite(AppLocalizations l10n, PartnerProvider partner) {
    final theme = Theme.of(context);
    final invite = partner.invite;
    return [
      Text(l10n.partnerInviteTitle, style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(
        l10n.partnerInviteBody,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 16),
      if (invite == null)
        FilledButton.icon(
          onPressed: partner.busy ? null : partner.createInvite,
          icon: const Icon(Icons.favorite_outline),
          label: Text(l10n.partnerCreateInvite),
        )
      else
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  invite.code,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    letterSpacing: 4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).copyButtonLabel,
                icon: const Icon(Icons.copy_rounded),
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: invite.code)),
              ),
              IconButton.filledTonal(
                tooltip: l10n.share,
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: l10n.partnerInviteShareText(
                      invite.link.toString(),
                      invite.code,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _buildCodeEntry(AppLocalizations l10n, PartnerProvider partner) {
    return [
      Text(
        l10n.partnerEnterCodeTitle,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: InputDecoration(labelText: l10n.partnerCodeLabel),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: partner.busy ||
                    PartnerInvite.normalize(_code.text) == null
                ? null
                : () =>
                    partner.acceptInvite(PartnerInvite.normalize(_code.text)!),
            child: Text(l10n.partnerConnect),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildConnected(AppLocalizations l10n, PartnerProvider partner) {
    final theme = Theme.of(context);
    final link = partner.link!;
    return [
      Text(
        l10n.partnerConnectedWith(link.partnerName),
        style: theme.textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        l10n.partnerSharedNote,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 16),
      NavigationTile(
        title: l10n.partnerViewDay,
        icon: Icons.restaurant_outlined,
        onTap: () => Navigator.push(
          context,
          AppTheme.slideRoute(const PartnerDayScreen()),
        ),
      ),
      const SizedBox(height: 8),
      NavigationTile(
        title: l10n.partnerDisconnect,
        icon: Icons.link_off_rounded,
        onTap: () => _confirm(
          l10n.partnerDisconnectConfirm(link.partnerName),
          l10n.partnerDisconnect,
          partner.disconnect,
        ),
      ),
    ];
  }

  List<Widget> _buildAccountActions(
    AppLocalizations l10n,
    PartnerProvider partner,
  ) {
    return [
      if (partner.profile != null)
        Text(
          partner.profile!.displayName,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: partner.busy ? null : partner.signOut,
            child: Text(l10n.partnerSignOut),
          ),
          TextButton(
            onPressed: partner.busy
                ? null
                : () => _confirm(
                      l10n.partnerDeleteConfirm,
                      l10n.delete,
                      partner.deleteAccount,
                    ),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.partnerDeleteAccount),
          ),
        ],
      ),
    ];
  }

  Future<void> _confirm(
    String message,
    String action,
    Future<bool> Function() onConfirm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed == true) await onConfirm();
  }
}
