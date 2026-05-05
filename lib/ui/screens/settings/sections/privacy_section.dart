import 'package:flutter/material.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/services/progress_photo_lock_service.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';
import 'package:sophis/ui/screens/progress_photo_lock_guard.dart';

class PrivacySection extends StatelessWidget {
  final SettingsProvider settings;

  const PrivacySection({super.key, required this.settings});

  Future<void> _setProgressPhotoLock(
    BuildContext context,
    bool enabled,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    if (!enabled) {
      ProgressPhotoLockGuard.lock();
      await settings.setProgressPhotoLockEnabled(false);
      return;
    }

    final result = await ProgressPhotoLockService.authenticate(
      localizedReason: l10n.progressPhotoAuthReason,
    );

    if (!context.mounted) return;

    switch (result) {
      case ProgressPhotoAuthResult.success:
        ProgressPhotoLockGuard.markUnlocked();
        await settings.setProgressPhotoLockEnabled(true);
        return;
      case ProgressPhotoAuthResult.unavailable:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.progressPhotoLockUnavailable)),
        );
        return;
      case ProgressPhotoAuthResult.failed:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.progressPhotoUnlockFailed)),
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SwitchTile(
      title: l10n.progressPhotoLock,
      subtitle: l10n.progressPhotoLockSubtitle,
      icon: Icons.lock_outline,
      value: settings.progressPhotoLockEnabled,
      onChanged: (value) => _setProgressPhotoLock(context, value),
    );
  }
}
